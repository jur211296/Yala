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
        // Schedule next refresh
        scheduleWidgetRefresh()

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
        // Schedule next report check
        scheduleNextReportTask()

        // Set expiration handler
        task.expirationHandler = {
            #if DEBUG
            print("BackgroundTaskManager: Report notification task expired")
            #endif
            task.setTaskCompleted(success: false)
        }

        // Perform the report check
        guard let container = modelContainer else {
            #if DEBUG
            print("BackgroundTaskManager: No model container for report task")
            #endif
            task.setTaskCompleted(success: false)
            return
        }

        Task {
            await ReportNotificationService.shared.sendDueReports(context: container.mainContext)

            #if DEBUG
            print("BackgroundTaskManager: Report notifications processed in background")
            #endif

            task.setTaskCompleted(success: true)
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
                after: Date(),
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
        let now = Date()
        var nextTime: Date?

        for report in reports {
            guard let candidate = calculateNextFireTime(for: report, after: now, calendar: calendar) else {
                continue
            }

            if nextTime == nil || candidate < nextTime! {
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
}
