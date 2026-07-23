//
//  NotificationService.swift
//  Yala
//
//  Servicio para gestionar notificaciones locales.
//

import Foundation
import SwiftData
import UserNotifications

// MARK: - NotificationService

final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()

    private let notificationCenter = UNUserNotificationCenter.current()

    private override init() {
        super.init()
        // Set delegate to show notifications while app is in foreground
        notificationCenter.delegate = self
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Show notifications even when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show banner, sound, and badge even when app is open
        completionHandler([.banner, .sound, .badge])
    }

    /// Handle notification tap - navigate to deep link destination
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        if let destination = userInfo["deepLink"] as? String,
           let dest = Self.parseDestination(destination) {
            Task { @MainActor in
                RouterEntryGate.shared.submit(.navigate(dest))
            }
        }

        completionHandler()
    }

    /// Parse deep link string to DeepLinkDestination
    static func parseDestination(_ destination: String) -> DeepLinkDestination? {
        // Group-specific deep link: "groups/{UUID}"
        if destination.hasPrefix("groups/") {
            let groupID = String(destination.dropFirst("groups/".count))
            return .groupDetail(groupID: groupID)
        }

        switch destination {
        case "statistics": return .statistics
        case "planning": return .planning
        case "budgets": return .budgets
        case "records": return .records
        case "categories": return .categories
        case "inbox": return .inbox
        case "scheduledPayments": return .scheduledPayments
        case "recordsStandalone": return .recordsStandalone
        case "groups": return .groups
        default:
            #if DEBUG
            print("NotificationService: Unknown deep link: \(destination)")
            #endif
            return nil
        }
    }

    // MARK: - Permission

    /// Request notification permission from user
    func requestPermission() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            #if DEBUG
            print("Error requesting notification permission: \(error)")
            #endif
            return false
        }
    }

    /// Check current permission status
    func checkPermissionStatus() async -> UNAuthorizationStatus {
        let settings = await notificationCenter.notificationSettings()
        return settings.authorizationStatus
    }

    /// Check if notifications are authorized
    func isAuthorized() async -> Bool {
        let status = await checkPermissionStatus()
        return status == .authorized || status == .provisional
    }

    // MARK: - Scheduling

    /// Schedule a notification
    /// Note: Dynamic content types (dailyReport, weeklyReport, monthlyReport) are NOT scheduled
    /// here because UNCalendarNotificationTrigger freezes content at schedule time.
    /// They are handled by background tasks and foreground checks instead.
    func scheduleNotification(for item: NotificationItem) async {
        guard item.isActive else {
            await cancelNotification(for: item)
            return
        }

        // Dynamic content types are handled by background tasks, not iOS scheduling
        if item.notificationType.requiresDynamicContent {
            // Cancel any previously scheduled static notifications for this type
            await cancelNotification(for: item)
            #if DEBUG
            print("NotificationService: Skipping iOS scheduling for dynamic type: \(item.notificationType.rawValue)")
            #endif
            return
        }

        // Check permission first
        guard await isAuthorized() else { return }
        // §5.2.1 — choke point: con un wipe personal armado, este `item` pertenece a la cuenta saliente
        // y su fila muere con el store. Reprogramarlo dejaría un repetitivo huérfano. Ver `isPersonalWipeArmed`.
        guard !isPersonalWipeArmed else { return }

        // Cancel existing notifications for this item first
        await cancelNotification(for: item)

        // Create content
        let content = UNMutableNotificationContent()
        content.title = item.localizedName
        content.body = item.displayText
        content.sound = .default

        // Deep link for static reminder notifications
        switch item.notificationType {
        case .endOfDay, .lunchTime, .custom:
            content.userInfo = ["deepLink": "recordsStandalone"]
        default:
            break
        }

        // Check if notification has specific weekdays selected
        let selectedWeekdays = item.selectedWeekdays

        if item.notificationType.supportsWeekdaySelection && !selectedWeekdays.isEmpty {
            // Create separate request for each selected weekday
            for weekday in selectedWeekdays {
                var dateComponents = DateComponents()
                dateComponents.hour = item.hour
                dateComponents.minute = item.minute
                dateComponents.weekday = weekday

                let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
                let request = UNNotificationRequest(
                    identifier: "\(item.id.uuidString)-\(weekday)",
                    content: content,
                    trigger: trigger
                )

                do {
                    try await notificationCenter.add(request)
                } catch {
                    #if DEBUG
                    print("Error scheduling notification for weekday \(weekday): \(error)")
                    #endif
                }
            }
        } else {
            // Standard trigger (daily or based on type)
            let trigger = createTrigger(for: item)

            let request = UNNotificationRequest(
                identifier: item.id.uuidString,
                content: content,
                trigger: trigger
            )

            do {
                try await notificationCenter.add(request)
            } catch {
                #if DEBUG
                print("Error scheduling notification: \(error)")
                #endif
            }
        }
    }

    /// Cancel a scheduled notification
    func cancelNotification(for item: NotificationItem) async {
        // Cancel main request
        var identifiers = [item.id.uuidString]

        // Also cancel any weekday-specific requests (1-7)
        for weekday in 1...7 {
            identifiers.append("\(item.id.uuidString)-\(weekday)")
        }

        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    /// Send an immediate notification with optional deep link
    /// - Parameters:
    ///   - title: Notification title
    ///   - body: Notification body text
    ///   - deepLink: Optional deep link destination (e.g., "statistics", "planning", "budgets")
    /// - Returns: `true` SOLO si iOS aceptó el request (`notificationCenter.add` sin error).
    ///   Todo caller que deduplique por "ya notifiqué" DEBE marcar su dedup únicamente con `true`:
    ///   marcar tras un `false` quema la supresión del día sin banner entregado (bug del ticket
    ///   pagos-planificados-notifs-incoherentes-y-dedup-sin-entrega).
    @discardableResult
    func sendNotification(title: String, body: String, deepLink: String? = nil) async -> Bool {
        let settings = await notificationCenter.notificationSettings()
        let authorized = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
        #if DEBUG
        print("NotifService[#16-debug]: sendNotification title=\"\(title)\" authStatus=\(settings.authorizationStatus.rawValue) authorized=\(authorized) alert=\(settings.alertSetting.rawValue) center=\(settings.notificationCenterSetting.rawValue) lockScreen=\(settings.lockScreenSetting.rawValue)")
        #endif
        guard authorized else { return false }
        // §5.2.1 — choke point: con un wipe personal armado, esta entrega llevaría montos y nombres de
        // la cuenta que acaba de cerrar sesión. Ver `isPersonalWipeArmed`.
        guard !isPersonalWipeArmed else { return false }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        if let deepLink = deepLink {
            content.userInfo = ["deepLink": deepLink]
        }

        // Trigger in 1 second
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        let request = UNNotificationRequest(
            identifier: "notification-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        do {
            try await notificationCenter.add(request)
            #if DEBUG
            print("NotifService[#16-debug]: notificationCenter.add OK identifier=\(request.identifier)")
            #endif
            return true
        } catch {
            #if DEBUG
            print("NotifService[#16-debug]: Error sending notification: \(error)")
            #endif
            return false
        }
    }

    /// Send a test notification immediately (for preview) - wrapper for compatibility
    func sendTestNotification(title: String, body: String) async {
        await sendNotification(title: title, body: body, deepLink: nil)
    }

    // MARK: - Scheduled Payment Daily Summaries (canal AGENDADO del modelo híbrido)

    /// Prefijo de los identifiers de las summaries diarias (`spDailySummary_<yyyyMMdd>`).
    /// Los wipes de frontera de cuenta no necesitan conocerlo: todos pasan por
    /// `cancelAllNotifications()`/`deleteAllNotifications` (removeAll pending).
    static let summaryIdentifierPrefix = "spDailySummary_"

    /// Resultado del replace de summaries — el caller reconcilia sus marcas SOLO con esto.
    struct SummaryReplaceOutcome {
        /// dayKeys VERIFICADOS presentes en pending tras los adds (no basta "add no lanzó":
        /// iOS descarta en silencio sobre el límite de 64 — marcar un día jamás retenido
        /// suprimiría el fallback oportunista, la clase exacta del bug dedup-sin-entrega).
        let scheduledDayKeys: [String]
        /// dayKeys que este replace INTENTÓ agendar (plan efectivo tras el drop de "hoy ya
        /// disparó") — la base correcta para "planificado-pero-fallido" del reconcile.
        let attemptedDayKeys: [String]
        /// dayKeys cuyo pending fue RETIRADO por este replace (estaban vivos ⇒ NO habían
        /// disparado). Si hoy está aquí y no se re-agendó, su marca miente y debe caer.
        let removedPendingDayKeys: [String]
    }

    /// Reemplaza TODAS las summaries agendadas por el plan dado (one-shot por día, a la
    /// hora configurada).
    /// - Parameters:
    ///   - todayKey: dayKey de hoy (`yyyyMMdd`).
    ///   - todayAlreadyMarked: si el tracker tiene marca de summary para hoy — con marca
    ///     puesta y SIN pending vivo, la summary de hoy YA DISPARÓ: re-agendar hoy (cambio
    ///     de hora a más tarde) sería el segundo banner del día.
    func replaceScheduledPaymentSummaries(
        _ plans: [ScheduledPaymentSummaryPlanner.DayPlan],
        todayKey: String,
        todayAlreadyMarked: Bool
    ) async -> SummaryReplaceOutcome {
        let prefix = Self.summaryIdentifierPrefix
        // Siempre retirar las pendientes del prefijo (también con plan vacío: toggle OFF
        // o pagos eliminados deben LIMPIAR lo agendado).
        let removedDayKeys = await pendingSummaryDayKeys()
        let stale = removedDayKeys.map { prefix + $0 }

        // Anti doble-banner: marca de hoy + ningún pending de hoy vivo ⇒ ya disparó.
        var effectivePlans = plans
        if todayAlreadyMarked && !removedDayKeys.contains(todayKey) {
            effectivePlans.removeAll { $0.dayKey == todayKey }
        }
        let attempted = effectivePlans.map(\.dayKey)

        if !stale.isEmpty {
            notificationCenter.removePendingNotificationRequests(withIdentifiers: stale)
        }

        guard !effectivePlans.isEmpty else {
            return SummaryReplaceOutcome(scheduledDayKeys: [], attemptedDayKeys: attempted, removedPendingDayKeys: removedDayKeys)
        }
        guard await isAuthorized() else {
            return SummaryReplaceOutcome(scheduledDayKeys: [], attemptedDayKeys: attempted, removedPendingDayKeys: removedDayKeys)
        }

        var addedKeys: [String] = []
        for plan in effectivePlans {
            // §5.2.1 — mismo choke point que sendNotification, evaluado POR ITERACIÓN (el
            // invariante de `isPersonalWipeArmed`: "en el instante del add"): un arm que
            // aterrice a mitad del loop corta las iteraciones restantes.
            guard !isPersonalWipeArmed else { break }
            // El `now` del planner envejece durante los round-trips al center: un trigger
            // con fecha ya pasada es aceptado por add() pero JAMÁS dispara — no agendarlo
            // (la oportunista dueToday cubre el día como fallback, que es el diseño).
            guard plan.fireDate > Date.now else { continue }

            let content = UNMutableNotificationContent()
            content.title = L10n.Notifications.scheduledPaymentsName
            content.body = L10n.Notifications.scheduledPaymentsSummaryBody(plan.count)
            content.sound = .default
            content.userInfo = ["deepLink": "scheduledPayments"]

            // Componentes CON year: one-shot inequívoco — sin year, un trigger repeats:false
            // podría re-matchear el mismo día/mes de otro año si sobreviviera.
            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute], from: plan.fireDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: prefix + plan.dayKey,
                content: content,
                trigger: trigger
            )

            do {
                try await notificationCenter.add(request)
                addedKeys.append(plan.dayKey)
            } catch {
                #if DEBUG
                print("NotifService: Error scheduling payment summary \(plan.dayKey): \(error)")
                #endif
            }
        }

        // Verificación post-add contra el center (límite 64 silencioso).
        let retained = Set(await pendingSummaryDayKeys())
        let scheduledKeys = addedKeys.filter { retained.contains($0) }

        #if DEBUG
        print("NotifService: payment summaries replaced — removed=\(stale.count) scheduled=\(scheduledKeys.count)/\(effectivePlans.count)")
        #endif
        return SummaryReplaceOutcome(scheduledDayKeys: scheduledKeys, attemptedDayKeys: attempted, removedPendingDayKeys: removedDayKeys)
    }

    /// dayKeys de las summaries actualmente pendientes en el center (identifier = prefijo
    /// + dayKey, biyectivo por construcción).
    private func pendingSummaryDayKeys() async -> [String] {
        let pending = await notificationCenter.pendingNotificationRequests()
        return pending.map(\.identifier)
            .filter { $0.hasPrefix(Self.summaryIdentifierPrefix) }
            .map { String($0.dropFirst(Self.summaryIdentifierPrefix.count)) }
    }

    /// ¿Hay un wipe del store PERSONAL armado (sign-out `.cloud` o salida de sesión secundaria M1)?
    ///
    /// Guard del CHOKE POINT (§5.2.1): cancelar las notificaciones al armar el wipe no basta por sí solo
    /// —`AppBootstrapper.handleBecameActive` lanza un `Task` NO estructurado (`ensureNotificationsScheduled`
    /// + `sendDueReports`) con decenas de puntos de suspensión, y su guard de arm se evalúa AL LANZARLO. Un
    /// background→active durante el push-all (fase `.working`, todavía sin arm) deja esa tarea suspendida;
    /// al reanudar, ya con el wipe armado, reprogramaría los recordatorios de la cuenta saliente y podría
    /// ENTREGAR un banner con montos suyos sobre el cover de relanzamiento. Evaluarlo aquí, en el instante
    /// del `add`, cierra la ventana para CUALQUIER productor —presente o futuro— sin rastrear tareas.
    ///
    /// NO incluye `groupsOnlyWipeArmed`: en ese camino el store personal sobrevive y sus recordatorios
    /// siguen siendo válidos (misma asimetría deliberada que en los boot-hooks).
    private var isPersonalWipeArmed: Bool {
        StorageModePersistence.isSignOutWipeArmed() || SecondarySessionStore.isWipeArmed()
    }

    /// Cancel all notifications
    func cancelAllNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
    }

    /// Retira las notificaciones YA ENTREGADAS del Centro de Notificaciones.
    ///
    /// SEPARADO de `cancelAllNotifications()` A PROPÓSITO — NO fusionar: aquel corre en
    /// `rescheduleAllNotifications` (y por tanto en cada toggle de Ajustes y en cada
    /// `ensureNotificationsScheduled` del foreground), donde borrar el historial entregado del
    /// usuario sería una regresión visible. Este es exclusivo de las FRONTERAS DE CUENTA
    /// (boot-cleanup del sign-out `.cloud`, salida/entrada de sesión secundaria M1): los banners
    /// entregados llevan montos y nombres de comercios de la cuenta saliente y no deben sobrevivirle.
    func clearDeliveredNotifications() {
        notificationCenter.removeAllDeliveredNotifications()
    }

    /// Retira SOLO las notificaciones entregadas del dominio GRUPOS (deep link `groups/<uuid>`,
    /// `GroupNotificationService`), dejando intactas las personales.
    ///
    /// Existe porque el cierre de sesión SOLO-GRUPOS borra el store `YalaGroups` pero CONSERVA el
    /// personal: un barrido total ahí borraría el historial del usuario que NO se fue. Al tocar una
    /// entregada huérfana, `GroupsContainerView.openPendingGroupIfAvailable` no encuentra el grupo y
    /// retorna sin limpiar `pendingGroupID`, suprimiendo el onboarding del tab in-session.
    ///
    /// Best-effort: `getDeliveredNotifications` es async, así que el call-site del boot lo invoca
    /// desde un `Task` desacoplado (no toca SwiftData ni bloquea el arranque).
    func clearDeliveredGroupNotifications() async {
        let delivered = await notificationCenter.deliveredNotifications()
        let groupIDs = delivered
            .filter { ($0.request.content.userInfo["deepLink"] as? String)?.hasPrefix("groups/") == true }
            .map(\.request.identifier)
        guard !groupIDs.isEmpty else { return }
        notificationCenter.removeDeliveredNotifications(withIdentifiers: groupIDs)
    }

    /// Cancel any previously scheduled dynamic notifications (reports)
    /// Called during bootstrap to clean up old scheduled notifications that would have static content
    @MainActor
    func cancelDynamicNotifications(context: ModelContext) async {
        let descriptor = FetchDescriptor<NotificationItem>(
            predicate: #Predicate {
                $0.typeRaw == "dailyReport" ||
                $0.typeRaw == "weeklyReport" ||
                $0.typeRaw == "monthlyReport"
            }
        )

        let items: [NotificationItem]
        do {
            items = try context.fetch(descriptor)
        } catch {
            #if DEBUG
            print("NotificationService: Error fetching notification items: \(error)")
            #endif
            return
        }

        for item in items {
            await cancelNotification(for: item)
        }

        #if DEBUG
        print("NotificationService: Cancelled \(items.count) dynamic notification schedules")
        #endif
    }

    /// Reschedule all active notifications
    ///
    /// Cancela SOLO lo que NO es summary de pagos (`spDailySummary_*`): este método corre en
    /// cada toggle de Ajustes de notificaciones y en el reconciler de foreground — un
    /// `removeAllPendingNotificationRequests` aquí barría el canal agendado de pagos SIN
    /// re-plan, dejando las marcas del tracker mintiendo ("hay summary") y el día en silencio
    /// (hallazgo del review adversarial 2026-07-22). `cancelAllNotifications()` queda para las
    /// FRONTERAS DE CUENTA, que sí deben barrer todo.
    func rescheduleAllNotifications(items: [NotificationItem]) async {
        let pending = await notificationCenter.pendingNotificationRequests()
        let nonSummaryIDs = pending.map(\.identifier).filter { !$0.hasPrefix(Self.summaryIdentifierPrefix) }
        if !nonSummaryIDs.isEmpty {
            notificationCenter.removePendingNotificationRequests(withIdentifiers: nonSummaryIDs)
        }

        // Schedule active ones
        for item in items where item.isActive {
            await scheduleNotification(for: item)
        }
    }

    // MARK: - Trigger Creation

    private func createTrigger(for item: NotificationItem) -> UNNotificationTrigger {
        var dateComponents = DateComponents()
        dateComponents.hour = item.hour
        dateComponents.minute = item.minute

        switch item.notificationType {
        case .weeklyReport:
            // Weekly based on day preference
            let config = item.reportConfig
            // Sunday = 1, Monday = 2 in Calendar
            dateComponents.weekday = config.dayPreference == .sunday ? 1 : 2
            return UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        case .monthlyReport:
            // Monthly based on day preference
            let config = item.reportConfig
            if config.dayPreference == .lastDay {
                // Last day of month - we'll use day 28 as approximation
                // (proper implementation would need to recalculate each month)
                dateComponents.day = 28
            } else {
                // First day of month
                dateComponents.day = 1
            }
            return UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        default:
            // Daily at specified time (endOfDay, lunchTime, dailyReport, scheduledPayments, custom)
            return UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        }
    }

    // MARK: - Seed Default Notifications

    /// Create default notifications if none exist (verified by type to avoid duplicates)
    @MainActor
    func seedDefaultNotificationsIfNeeded(context: ModelContext) {
        // Gate de quiescencia: este `save()` toca el store personal; durante el import del restore
        // de iCloud dispararía el `_assertionFailure` interno de SwiftData. Si no está quieto, salta
        // (idempotente: re-corre en el próximo arranque/quiescencia) y NO deja inserts pendientes.
        guard iCloudSyncService.shared.isImportQuiescent else {
            SaveBreadcrumb.deferred("NotificationService.seedDefaults", "import not quiescent")
            return
        }

        // Fetch existing notifications to check by type
        let descriptor = FetchDescriptor<NotificationItem>()

        let existing: [NotificationItem]
        do {
            existing = try context.fetch(descriptor)
        } catch {
            #if DEBUG
            print("NotificationService: Error checking existing notifications: \(error)")
            #endif
            return
        }

        // Clean up legacy announcements notifications
        let legacyAnnouncements = existing.filter { $0.typeRaw == "announcements" }
        for item in legacyAnnouncements {
            context.delete(item)
        }

        // Build set of existing types
        let existingTypes = Set(existing.map { $0.typeRaw })

        // Create defaults only for missing types
        let defaults = NotificationItem.createDefaults()
        var inserted = 0

        for item in defaults where !existingTypes.contains(item.typeRaw) {
            context.insert(item)
            inserted += 1
        }

        guard inserted > 0 else { return }

        do {
            SaveBreadcrumb.willSave("NotificationService.seedDefaults")
            try context.save()
            SaveBreadcrumb.didSave("NotificationService.seedDefaults")
            #if DEBUG
            print("NotificationService: Seeded \(inserted) missing notification types")
            #endif
        } catch {
            #if DEBUG
            print("NotificationService: Error saving default notifications: \(error)")
            #endif
        }
    }

    /// Remove duplicate NotificationItems by typeRaw, keeping the one with isActive = true preference.
    /// R9: Guards against CloudKit delivering synced notifications between fetch and save in onboarding.
    @MainActor
    func deduplicateNotifications(context: ModelContext) {
        // Gate de quiescencia: save del store personal — diferir durante el import del restore.
        // Dedupe tras la quiescencia ve el estado final del import (mejor que a mitad de camino).
        guard iCloudSyncService.shared.isImportQuiescent else {
            SaveBreadcrumb.deferred("NotificationService.dedupe", "import not quiescent")
            return
        }
        let descriptor = FetchDescriptor<NotificationItem>()
        let all: [NotificationItem]
        do {
            all = try context.fetch(descriptor)
        } catch {
            #if DEBUG
            print("NotificationService: Error fetching notifications: \(error)")
            #endif
            return
        }

        let grouped = Dictionary(grouping: all) { $0.typeRaw }
        var removed = 0
        for (_, group) in grouped where group.count > 1 {
            // Keep the active one (or first if both same)
            let sorted = group.sorted { ($0.isActive ? 1 : 0) > ($1.isActive ? 1 : 0) }
            for dup in sorted.dropFirst() {
                context.delete(dup)
                removed += 1
            }
        }
        if removed > 0 {
            do {
                SaveBreadcrumb.willSave("NotificationService.dedupe")
                try context.save()
                SaveBreadcrumb.didSave("NotificationService.dedupe")
                #if DEBUG
                print("NotificationService: Deduplicated \(removed) notification(s)")
                #endif
            } catch {
                #if DEBUG
                print("NotificationService: Error deduplicating: \(error)")
                #endif
            }
        }
    }

    /// Delete all notifications (used in data wipe)
    @MainActor
    func deleteAllNotifications(context: ModelContext) {
        cancelAllNotifications()

        let descriptor = FetchDescriptor<NotificationItem>()

        let items: [NotificationItem]
        do {
            items = try context.fetch(descriptor)
        } catch {
            #if DEBUG
            print("NotificationService: Error fetching notifications for deletion: \(error)")
            #endif
            return
        }

        for item in items {
            context.delete(item)
        }

        do {
            try context.save()
        } catch {
            #if DEBUG
            print("NotificationService: Error saving after deleting notifications: \(error)")
            #endif
        }
    }
}

