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
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.widgetRefreshTaskID,
            using: nil
        ) { task in
            Task { @MainActor in
                guard let refreshTask = task as? BGAppRefreshTask else {
                    #if DEBUG
                    print("BackgroundTaskManager: Task is not BGAppRefreshTask")
                    #endif
                    return
                }
                self.handleWidgetRefreshTask(refreshTask)
            }
        }

        #if DEBUG
        print("BackgroundTaskManager: Registered background tasks")
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
}
