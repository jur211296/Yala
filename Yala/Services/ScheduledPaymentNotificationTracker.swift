//
//  ScheduledPaymentNotificationTracker.swift
//  Yala
//
//  Tracks which scheduled payment notifications have been sent to avoid duplicates.
//  Uses UserDefaults for persistence.
//

import Foundation

/// Tracks which scheduled payment notifications have been sent per date
@MainActor
final class ScheduledPaymentNotificationTracker {
    static let shared = ScheduledPaymentNotificationTracker()

    private let defaults = UserDefaults.standard
    private let keyPrefix = "scheduledPaymentNotif_"

    private static let dateKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        return f
    }()

    private init() {}

    /// Public accessor for date key formatting (used by credit card notifications)
    static func dateKeyString(from date: Date) -> String {
        dateKeyFormatter.string(from: date)
    }

    // MARK: - Notification Types

    enum NotificationType: String {
        case dueDate    // Payment due today
        case daysBefore // Payment due in X days
        case overdue    // Payment past due
    }

    // MARK: - Tracking

    /// Check if notification was already sent for this payment/date/type combination
    func hasNotifiedForDate(paymentID: UUID, date: Date, type: NotificationType) -> Bool {
        let key = makeKey(paymentID: paymentID, date: date, type: type)
        return defaults.bool(forKey: key)
    }

    /// Mark notification as sent for this payment/date/type combination
    func markNotified(paymentID: UUID, date: Date, type: NotificationType) {
        let key = makeKey(paymentID: paymentID, date: date, type: type)
        defaults.set(true, forKey: key)
    }

    // MARK: - Cleanup

    /// Clean up old entries (> 30 days). `now` se inyecta opcionalmente en tests
    /// para que el cutoff sea determinístico (sin depender de `Date.now`).
    func cleanupOldEntries(now: Date = .now) {
        let allKeys = defaults.dictionaryRepresentation().keys
        let trackerKeys = allKeys.filter { $0.hasPrefix(keyPrefix) }

        let calendar = Calendar.current
        let cutoffDate = calendar.date(byAdding: .day, value: -30, to: now) ?? now

        for key in trackerKeys {
            // Key format: scheduledPaymentNotif_UUID_YYYYMMDD_type
            let components = key.split(separator: "_")
            guard components.count >= 4 else { continue }

            // Date is the third component (index 2, after prefix split)
            let dateString = String(components[2])
            guard let keyDate = Self.dateKeyFormatter.date(from: dateString) else { continue }

            if keyDate < cutoffDate {
                defaults.removeObject(forKey: key)
            }
        }
    }

    // MARK: - Private

    private func makeKey(paymentID: UUID, date: Date, type: NotificationType) -> String {
        let dateStr = Self.dateKeyFormatter.string(from: date)
        return "\(keyPrefix)\(paymentID.uuidString)_\(dateStr)_\(type.rawValue)"
    }
}
