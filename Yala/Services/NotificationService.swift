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
    func scheduleNotification(for item: NotificationItem) async {
        guard item.isActive else {
            await cancelNotification(for: item)
            return
        }

        // Check permission first
        guard await isAuthorized() else { return }

        // Cancel existing notifications for this item first
        await cancelNotification(for: item)

        // Create content
        let content = UNMutableNotificationContent()
        content.title = "Yala"
        content.body = item.displayText
        content.sound = .default

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

    /// Send a test notification immediately (for preview)
    func sendTestNotification(title: String, body: String) async {
        // Check permission first
        guard await isAuthorized() else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        // Trigger in 1 second
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        let request = UNNotificationRequest(
            identifier: "test-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        do {
            try await notificationCenter.add(request)
        } catch {
            #if DEBUG
            print("Error sending test notification: \(error)")
            #endif
        }
    }

    /// Cancel all notifications
    func cancelAllNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
    }

    /// Reschedule all active notifications
    func rescheduleAllNotifications(items: [NotificationItem]) async {
        // Cancel all existing
        cancelAllNotifications()

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

        case .announcements:
            // One-time notification (will be rescheduled when there's an announcement)
            return UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)

        default:
            // Daily at specified time (endOfDay, lunchTime, dailyReport, scheduledPayments, custom)
            return UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        }
    }

    // MARK: - Seed Default Notifications

    /// Create default notifications if none exist
    @MainActor
    func seedDefaultNotificationsIfNeeded(context: ModelContext) {
        // Check if notifications already exist
        let descriptor = FetchDescriptor<NotificationItem>()

        let existingCount: Int
        do {
            existingCount = try context.fetchCount(descriptor)
        } catch {
            #if DEBUG
            print("NotificationService: Error checking existing notifications: \(error)")
            #endif
            return
        }

        guard existingCount == 0 else { return }

        // Create defaults
        let defaults = NotificationItem.createDefaults()
        for item in defaults {
            context.insert(item)
        }

        do {
            try context.save()
        } catch {
            #if DEBUG
            print("NotificationService: Error saving default notifications: \(error)")
            #endif
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

// MARK: - Report Content Generation

extension NotificationService {
    /// Generate report notification content with actual data
    func generateReportContent(
        config: ReportConfig,
        balance: Double,
        expenses: Double,
        income: Double,
        topCategory: String?,
        currencySymbol: String
    ) -> String {
        switch config.dataType {
        case .balance:
            return "Saldo: \(currencySymbol)\(String(format: "%.2f", balance))"
        case .expenses:
            return "Gastos: \(currencySymbol)\(String(format: "%.2f", expenses))"
        case .income:
            return "Ingresos: \(currencySymbol)\(String(format: "%.2f", income))"
        case .topCategory:
            if let category = topCategory {
                return "Tu mayor gasto: \(category)"
            } else {
                return "No hay gastos este período"
            }
        }
    }
}
