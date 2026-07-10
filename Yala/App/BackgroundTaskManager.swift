//
//  BackgroundTaskManager.swift
//  Yala
//
//  Manages background tasks including widget cache refresh.
//

import BackgroundTasks
import SwiftData
import WidgetKit

/// Manages background task registration and execution
@MainActor
final class BackgroundTaskManager {

    // MARK: - Singleton

    static let shared = BackgroundTaskManager()

    // MARK: - Task Identifiers

    /// Background task identifier for widget refresh
    /// Must match the identifier in Info.plist BGTaskSchedulerPermittedIdentifiers
    static let widgetRefreshTaskID = "com.jurgenschmidt.yala.widget-refresh"

    /// Background task identifier for report notifications
    /// Must match the identifier in Info.plist BGTaskSchedulerPermittedIdentifiers
    static let reportNotificationTaskID = "com.jurgenschmidt.yala.report-notification"

    /// Backup task identifier (runs 1 hour after main task as fallback)
    static let reportBackupTaskID = "com.jurgenschmidt.yala.report-backup"

    // MARK: - Properties

    private var modelContainer: ModelContainer?

    // MARK: - Init

    private init() {}

    // MARK: - Setup

    /// Sets the model container for background operations
    func setModelContainer(_ container: ModelContainer) {
        self.modelContainer = container
        // §i.9 (I10-wiring w6): conecta el journal real al SSOT de fase que consultan los gates de los
        // BGTasks + deriva el gate permanente de captura de identidad al boot. Aquí (no en AppBootstrapper)
        // porque este manager ya recibe el container temprano en el bootstrap.
        MigrationPhaseStore.shared.configure(container: container)
    }

    /// Registers all background tasks with the system
    /// Call this early in app lifecycle (e.g., in bootstrap)
    func registerTasks() {
        // Register widget refresh task
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.widgetRefreshTaskID,
            using: nil
        ) { [weak self] task in
            Task { @MainActor in
                guard let self else { return }
                guard let refreshTask = task as? BGAppRefreshTask else {
                    #if DEBUG
                    print("BackgroundTaskManager: Task is not BGAppRefreshTask")
                    #endif
                    task.setTaskCompleted(success: false)
                    return
                }
                self.handleWidgetRefreshTask(refreshTask)
            }
        }

        // Register report notification task
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.reportNotificationTaskID,
            using: nil
        ) { [weak self] task in
            Task { @MainActor in
                guard let self else { return }
                guard let appRefreshTask = task as? BGAppRefreshTask else {
                    #if DEBUG
                    print("BackgroundTaskManager: Report task is not BGAppRefreshTask")
                    #endif
                    task.setTaskCompleted(success: false)
                    return
                }
                self.handleReportNotificationTask(appRefreshTask)
            }
        }

        // Register backup report task (fallback if main task doesn't execute)
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.reportBackupTaskID,
            using: nil
        ) { [weak self] task in
            Task { @MainActor in
                guard let self else { return }
                guard let appRefreshTask = task as? BGAppRefreshTask else {
                    #if DEBUG
                    print("BackgroundTaskManager: Backup task is not BGAppRefreshTask")
                    #endif
                    task.setTaskCompleted(success: false)
                    return
                }
                self.handleReportNotificationTask(appRefreshTask)
            }
        }

        #if DEBUG
        print("BackgroundTaskManager: Registered background tasks (including backup)")
        #endif
    }

    // MARK: - Task Scheduling

    /// Schedules the widget refresh background task
    func scheduleWidgetRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.widgetRefreshTaskID)
        // Schedule for 4 hours from now (widgets refresh naturally but this ensures freshness)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 4 * 60 * 60)

        do {
            try BGTaskScheduler.shared.submit(request)
            #if DEBUG
            print("BackgroundTaskManager: Scheduled widget refresh for ~4 hours")
            #endif
        } catch {
            #if DEBUG
            print("BackgroundTaskManager: Failed to schedule widget refresh: \(error)")
            #endif
        }
    }

    // MARK: - Task Handlers

    private func handleWidgetRefreshTask(_ task: BGAppRefreshTask) {
        // Schedule next refresh (esto ES la re-programación — no dupliques submits abajo)
        scheduleWidgetRefresh()

        // §i.9 gate — widget-refresh es el ÚNICO SOLO-LECTURA. En estados ESTABLES corre normal; en un
        // estado TRANSITORIO de migración/reversa SUSPENDE (no toca el mainContext a medio hidratar → no
        // reabre el SIGTRAP de la saga de Grupos). El re-scheduling de arriba hace que iOS lo reintente.
        // HOY la fase real es SIEMPRE .notStarted → .run: comportamiento IDÉNTICO al actual hasta I10-wiring.
        let gateDecision = BGTaskMigrationGate.decide(
            phase: MigrationPhaseStore.shared.currentPhase,
            isImportQuiescent: iCloudSyncService.shared.isImportQuiescent,
            role: .reader
        )
        // `!= .run` (no el case concreto): si un refactor futuro cruzara decisiones de rol, el
        // fallo debe ser CERRADO (no tocar el mainContext en transición), nunca fail-open al crash.
        if gateDecision != .run {
            #if DEBUG
            print("BackgroundTaskManager: widget-refresh SUSPENDED by §i.9 gate (fase transitoria) — re-programado [\(gateDecision)]")
            #endif
            task.setTaskCompleted(success: false)
            return
        }

        // Set expiration handler
        task.expirationHandler = {
            #if DEBUG
            print("BackgroundTaskManager: Widget refresh task expired")
            #endif
        }

        // Perform the refresh
        guard let container = modelContainer else {
            #if DEBUG
            print("BackgroundTaskManager: No model container available")
            #endif
            task.setTaskCompleted(success: false)
            return
        }

        let context = container.mainContext

        // Update widget cache
        WidgetDataCache.updateCache(context: context)

        #if DEBUG
        print("BackgroundTaskManager: Widget cache refreshed in background")
        #endif

        task.setTaskCompleted(success: true)
    }

    /// Handles report notification background task
    private func handleReportNotificationTask(_ task: BGAppRefreshTask) {
        // Schedule next report check (re-programa main + backup — no dupliques submits abajo)
        scheduleNextReportTask()

        // §i.9 gate — ESCRITOR: report-notification Y report-backup comparten este handler (ambos
        // escriben `lastNotifiedDate` + save()). En estados ESTABLES escribe normal; en un estado
        // TRANSITORIO exige QUIESCENCIA del import antes de leer/escribir el mainContext, difiriendo
        // (re-programado arriba) si aún no la hay → nunca un save() sobre grafo a medio hidratar. HOY la
        // fase real es SIEMPRE .notStarted → .run: comportamiento IDÉNTICO al actual hasta I10-wiring.
        let gateDecision = BGTaskMigrationGate.decide(
            phase: MigrationPhaseStore.shared.currentPhase,
            isImportQuiescent: iCloudSyncService.shared.isImportQuiescent,
            role: .writer
        )
        // `!= .run` (no el case concreto) — misma defensa fail-closed que el lector.
        if gateDecision != .run {
            #if DEBUG
            print("BackgroundTaskManager: report task DEFERRED by §i.9 gate (fase transitoria, sin quiescencia) — re-programado [\(gateDecision)]")
            #endif
            task.setTaskCompleted(success: false)
            return
        }

        // Perform the report check
        guard let container = modelContainer else {
            #if DEBUG
            print("BackgroundTaskManager: No model container for report task")
            #endif
            task.setTaskCompleted(success: false)
            return
        }

        let workTask = Task {
            await ReportNotificationService.shared.sendDueReports(context: container.mainContext)

            // Check cancellation — expiration handler may have already completed the task
            guard !Task.isCancelled else { return }

            #if DEBUG
            print("BackgroundTaskManager: Report notifications processed in background")
            #endif

            task.setTaskCompleted(success: true)
        }

        // Cancel work if system expires the task (prevents double setTaskCompleted)
        task.expirationHandler = {
            workTask.cancel()
            task.setTaskCompleted(success: false)
        }
    }

    /// Schedules the next report notification check
    func scheduleNextReportTask() {
        scheduleNextReportTask(context: modelContainer?.mainContext)
    }

    /// Schedules the next report notification check with context for intelligent timing
    /// Schedules both main task and a backup task 1 hour later for redundancy
    /// - Parameter context: ModelContext to fetch notification configurations (optional)
    func scheduleNextReportTask(context: ModelContext?) {
        // Try to find next report notification time from user config
        var targetDate: Date?

        if let context = context {
            targetDate = calculateNextReportTime(context: context)
        }

        // Fallback to tomorrow 6 AM if no active reports or no context
        if targetDate == nil {
            targetDate = Calendar.current.nextDate(
                after: Date.now,
                matching: DateComponents(hour: 6),
                matchingPolicy: .nextTime
            )
        }

        // Schedule main task FOR the configured time
        let mainRequest = BGAppRefreshTaskRequest(identifier: Self.reportNotificationTaskID)
        mainRequest.earliestBeginDate = targetDate

        do {
            try BGTaskScheduler.shared.submit(mainRequest)
            #if DEBUG
            if let date = mainRequest.earliestBeginDate {
                let formatter = DateFormatter()
                formatter.dateStyle = .short
                formatter.timeStyle = .short
                print("BackgroundTaskManager: Scheduled main report task for ~\(formatter.string(from: date))")
            }
            #endif
        } catch {
            #if DEBUG
            print("BackgroundTaskManager: Failed to schedule main report task: \(error)")
            #endif
        }

        // Schedule backup task 1 hour after main task (fallback if main doesn't execute)
        let backupRequest = BGAppRefreshTaskRequest(identifier: Self.reportBackupTaskID)
        if let target = targetDate {
            backupRequest.earliestBeginDate = target.addingTimeInterval(60 * 60) // +1 hour
        }

        do {
            try BGTaskScheduler.shared.submit(backupRequest)
            #if DEBUG
            if let date = backupRequest.earliestBeginDate {
                let formatter = DateFormatter()
                formatter.dateStyle = .short
                formatter.timeStyle = .short
                print("BackgroundTaskManager: Scheduled backup report task for ~\(formatter.string(from: date))")
            }
            #endif
        } catch {
            #if DEBUG
            print("BackgroundTaskManager: Failed to schedule backup report task: \(error)")
            #endif
        }
    }

    /// Calculates the next time a report notification should fire
    private func calculateNextReportTime(context: ModelContext) -> Date? {
        let descriptor = FetchDescriptor<NotificationItem>(
            predicate: #Predicate {
                $0.isActive && (
                    $0.typeRaw == "dailyReport" ||
                    $0.typeRaw == "weeklyReport" ||
                    $0.typeRaw == "monthlyReport"
                )
            }
        )

        let reports: [NotificationItem]
        do {
            reports = try context.fetch(descriptor)
        } catch {
            #if DEBUG
            print("BackgroundTaskManager: Error fetching report notifications: \(error)")
            #endif
            return nil
        }
        guard !reports.isEmpty else {
            return nil
        }

        let calendar = Calendar.current
        let now = Date.now
        var nextTime: Date?

        for report in reports {
            guard let candidate = calculateNextFireTime(for: report, after: now, calendar: calendar) else {
                continue
            }

            if nextTime == nil || candidate < (nextTime ?? .distantFuture) {
                nextTime = candidate
            }
        }

        return nextTime
    }

    /// Calculates the next fire time for a specific report notification
    private func calculateNextFireTime(for report: NotificationItem, after date: Date, calendar: Calendar) -> Date? {
        // Start with today at the configured time
        guard var candidate = calendar.date(
            bySettingHour: report.hour,
            minute: report.minute,
            second: 0,
            of: date
        ) else { return nil }

        // If that time has passed, start from tomorrow
        if candidate <= date {
            guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: candidate) else {
                return nil
            }
            candidate = tomorrow
        }

        // For daily reports, check weekday constraints
        if report.notificationType.rawValue == "dailyReport" {
            let selectedWeekdays = report.selectedWeekdays
            if !selectedWeekdays.isEmpty {
                // Find next matching weekday
                for _ in 0..<7 {
                    let weekday = calendar.component(.weekday, from: candidate)
                    if selectedWeekdays.contains(weekday) {
                        return candidate
                    }
                    guard let next = calendar.date(byAdding: .day, value: 1, to: candidate) else {
                        return nil
                    }
                    candidate = next
                }
            }
        }

        // For weekly reports, find the configured day
        if report.notificationType.rawValue == "weeklyReport" {
            let targetWeekday = report.reportConfig.dayPreference == .sunday ? 1 : 2
            for _ in 0..<7 {
                let weekday = calendar.component(.weekday, from: candidate)
                if weekday == targetWeekday {
                    return candidate
                }
                guard let next = calendar.date(byAdding: .day, value: 1, to: candidate) else {
                    return nil
                }
                candidate = next
            }
        }

        // For monthly reports, find first or last day
        if report.notificationType.rawValue == "monthlyReport" {
            let isFirstDay = report.reportConfig.dayPreference == .firstDay
            for _ in 0..<32 {
                let day = calendar.component(.day, from: candidate)
                if isFirstDay && day == 1 {
                    return candidate
                }
                if !isFirstDay {
                    // Check if it's the last day of month
                    let range = calendar.range(of: .day, in: .month, for: candidate)
                    if day == range?.count {
                        return candidate
                    }
                }
                guard let next = calendar.date(byAdding: .day, value: 1, to: candidate) else {
                    return nil
                }
                candidate = next
            }
        }

        return candidate
    }

    #if DEBUG
    // MARK: - Spike S7 (DEBUG) — ejecución DIRECTA del camino del handler (sin daemon)

    /// HALLAZGO de plataforma (device, iOS 26, spike S7): `_simulateLaunchForTaskWithIdentifier` es NO
    /// CONFIABLE — "No task request … has been scheduled" con el request confirmado en cola (siembra
    /// inmediata sin fecha, con y sin espera de asentamiento; funcionó 1 de 6 veces sin patrón). Estos
    /// runners ejecutan el MISMO camino gate+trabajo del handler real sobre el store real — lo que el
    /// spike debe validar es NUESTRO gate, no el despachador de Apple. Mantener ESPEJADOS con los
    /// handlers de arriba (se retiran junto al resto del harness al cerrar I11).
    func spikeS7RunWidgetPath() {
        let gateDecision = BGTaskMigrationGate.decide(
            phase: MigrationPhaseStore.shared.currentPhase,
            isImportQuiescent: iCloudSyncService.shared.isImportQuiescent,
            role: .reader
        )
        if gateDecision != .run {
            print("BackgroundTaskManager: [S7-directo] widget-refresh SUSPENDED by §i.9 gate [\(gateDecision)]")
            return
        }
        guard let container = modelContainer else {
            print("BackgroundTaskManager: [S7-directo] No model container available")
            return
        }
        WidgetDataCache.updateCache(context: container.mainContext)
        print("BackgroundTaskManager: [S7-directo] Widget cache refreshed (gate .run)")
    }

    func spikeS7RunReportPath() {
        let gateDecision = BGTaskMigrationGate.decide(
            phase: MigrationPhaseStore.shared.currentPhase,
            isImportQuiescent: iCloudSyncService.shared.isImportQuiescent,
            role: .writer
        )
        if gateDecision != .run {
            print("BackgroundTaskManager: [S7-directo] report task DEFERRED by §i.9 gate [\(gateDecision)]")
            return
        }
        guard let container = modelContainer else {
            print("BackgroundTaskManager: [S7-directo] No model container for report task")
            return
        }
        Task {
            await ReportNotificationService.shared.sendDueReports(context: container.mainContext)
            print("BackgroundTaskManager: [S7-directo] Report notifications processed (gate .run)")
        }
    }

    // MARK: - Spike S7 (DEBUG) — siembra INMEDIATA para `_simulateLaunchForTaskWithIdentifier`

    /// Re-somete los 3 requests SIN `earliestBeginDate` (= "cuanto antes"). HALLAZGO de plataforma
    /// (device, iOS 26, spike S7): `_simulateLaunchForTaskWithIdentifier` RESPETA `earliestBeginDate`
    /// — un request con fecha futura responde "No task request … has been scheduled" aunque esté en
    /// cola (antes lo ignoraba). Con fecha nil el simulate dispara. `submit` REEMPLAZA el request
    /// pendiente por identifier → la siguiente pasada real del scheduler de la app restaura las
    /// fechas normales (boot re-siembra reports; el propio handler re-programa widget).
    func seedImmediateForSpikeS7() {
        for id in [Self.widgetRefreshTaskID, Self.reportNotificationTaskID, Self.reportBackupTaskID] {
            let request = BGAppRefreshTaskRequest(identifier: id)
            do {
                try BGTaskScheduler.shared.submit(request)
                print("BackgroundTaskManager: [S7] sembrado INMEDIATO \(id)")
            } catch {
                print("BackgroundTaskManager: [S7] siembra inmediata falló para \(id): \(error)")
            }
        }
    }
    #endif
}
