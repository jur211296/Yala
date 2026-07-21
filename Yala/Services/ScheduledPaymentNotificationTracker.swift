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

    /// Prefijos de las keys de dedup en `UserDefaults`. Expuestos porque
    /// `DataWipeService.removeUserPreferenceKeys` los barre POR PREFIJO al resetear la
    /// cuenta: llevan UUID + fecha, así que su lista explícita de keys no puede nombrarlas.
    static let keyPrefix = "scheduledPaymentNotif_"
    static let creditCardKeyPrefix = "creditCardNotif_"

    private static let dateKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        return f
    }()

    private init() {}

    /// Public accessor for date key formatting (formato `YYYYMMDD` de todas las keys)
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

    // MARK: - Credit Card Tracking

    /// Check if the credit card payment reminder was already sent for this account/date.
    ///
    /// Se llavea por `Account.shortcutID` (UUID de identidad, `.preserveValueOnDeletion`),
    /// NO por `account.name`: con el nombre, dos tarjetas homónimas con el mismo día de
    /// pago compartían entrada y solo una notificaba, y renombrar la cuenta re-disparaba
    /// el aviso el mismo día.
    func hasNotifiedCreditCard(accountID: UUID, date: Date) -> Bool {
        defaults.bool(forKey: creditCardKey(accountID: accountID, date: date))
    }

    /// Mark the credit card payment reminder as sent for this account/date.
    func markNotifiedCreditCard(accountID: UUID, date: Date) {
        defaults.set(true, forKey: creditCardKey(accountID: accountID, date: date))
    }

    // MARK: - Cleanup

    /// Clean up old entries (> 30 days) de AMBAS familias de keys. `now` se inyecta
    /// opcionalmente en tests para que el cutoff sea determinístico (sin depender de `Date.now`).
    func cleanupOldEntries(now: Date = .now) {
        let allKeys = defaults.dictionaryRepresentation().keys

        let calendar = Calendar.current
        let cutoffDate = calendar.date(byAdding: .day, value: -30, to: now) ?? now

        for key in allKeys {
            let dateString: String
            if key.hasPrefix(Self.keyPrefix) {
                // Key format: scheduledPaymentNotif_UUID_YYYYMMDD_type
                let components = key.split(separator: "_")
                guard components.count >= 4 else { continue }
                // Date is the third component (index 2, after prefix split)
                dateString = String(components[2])
            } else if key.hasPrefix(Self.creditCardKeyPrefix) {
                // Key format: creditCardNotif_UUID_YYYYMMDD — la fecha es el ÚLTIMO
                // componente. Leerla por el final (y no por posición fija) cubre también
                // el formato legacy `creditCardNotif_<nombre>_YYYYMMDD`, donde un nombre
                // con "_" desplazaba los índices y dejaba la key huérfana para siempre.
                let components = key.split(separator: "_")
                guard components.count >= 3, let last = components.last else { continue }
                dateString = String(last)
            } else {
                continue
            }

            guard let keyDate = Self.dateKeyFormatter.date(from: dateString) else { continue }

            if keyDate < cutoffDate {
                defaults.removeObject(forKey: key)
            }
        }
    }

    // MARK: - Private

    private func makeKey(paymentID: UUID, date: Date, type: NotificationType) -> String {
        let dateStr = Self.dateKeyFormatter.string(from: date)
        return "\(Self.keyPrefix)\(paymentID.uuidString)_\(dateStr)_\(type.rawValue)"
    }

    private func creditCardKey(accountID: UUID, date: Date) -> String {
        let dateStr = Self.dateKeyFormatter.string(from: date)
        return "\(Self.creditCardKeyPrefix)\(accountID.uuidString)_\(dateStr)"
    }
}
