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

    private let defaults: UserDefaults

    /// Prefijos de las keys de dedup en `UserDefaults`. Expuestos porque
    /// `DataWipeService.removeUserPreferenceKeys` los barre POR PREFIJO al resetear la
    /// cuenta: llevan UUID + fecha, así que su lista explícita de keys no puede nombrarlas.
    static let keyPrefix = "scheduledPaymentNotif_"
    static let creditCardKeyPrefix = "creditCardNotif_"
    /// Prefijo de las marcas de summary diaria (`scheduledPaymentNotif_summary_<yyyyMMdd>`).
    /// Derivado de `keyPrefix` para heredar el barrido del wipe; único punto de verdad
    /// del literal `summary_` (lección L1 del repo: literales duplicados se desincronizan).
    static let summaryKeyPrefix = keyPrefix + "summary_"

    private static let dateKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        return f
    }()

    private init() {
        self.defaults = .standard
    }

    /// Init de test — UserDefaults aislado (`makeIsolatedDefaults()`); jamás en producción.
    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

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

    // MARK: - Daily Summary Tracking (canal agendado)

    /// Marca "hay summary agendada para el día X" — key `scheduledPaymentNotif_summary_<yyyyMMdd>`
    /// (bajo el prefijo EXISTENTE: hereda gratis el barrido por prefijo del wipe y el cleanup).
    /// Guarda el INSTANTE de agendado (no un bool): la rama dueToday oportunista suprime solo
    /// los pagos que ya existían a esa hora — un pago creado DESPUÉS de la summary del día no
    /// estuvo en su conteo y debe poder avisar. Se pone SOLO con el request verificado en
    /// pending (contrato de entrega confirmada).
    func markSummaryScheduled(dayKey: String, at date: Date = .now) {
        defaults.set(date, forKey: summaryKey(dayKey: dayKey))
    }

    func hasSummaryScheduled(dayKey: String) -> Bool {
        summaryScheduledDate(dayKey: dayKey) != nil
    }

    /// Instante en que se agendó la summary del día (nil = sin marca).
    func summaryScheduledDate(dayKey: String) -> Date? {
        defaults.object(forKey: summaryKey(dayKey: dayKey)) as? Date
    }

    /// Reconciliación post-replan:
    /// - marca los días agendados con éxito (verificados en pending);
    /// - desmarca los INTENTADOS cuyo add falló o iOS no retuvo (marca huérfana = supresión
    ///   de la oportunista sin summary — la clase exacta del bug de dedup-sin-entrega);
    /// - desmarca HOY si su pending fue RETIRADO sin disparar y no se re-agendó (toggle OFF
    ///   antes de la hora, hora movida hacia atrás cruzando el now…): esa marca miente y
    ///   silenciaría el día entero;
    /// - limpia marcas FUTURAS (`dayKey > todayKey`) que salieron del plan.
    ///   Fuera de esos casos, HOY/pasado no se tocan: a media mañana "hoy" sale del plan
    ///   porque la hora ya pasó, y limpiar su marca re-abriría la oportunista → doble banner.
    func reconcileSummaryMarks(
        scheduledDayKeys: [String],
        attemptedDayKeys: [String],
        removedPendingDayKeys: [String],
        todayKey: String,
        now: Date = .now
    ) {
        let scheduled = Set(scheduledDayKeys)
        let attempted = Set(attemptedDayKeys)

        for dayKey in scheduled {
            markSummaryScheduled(dayKey: dayKey, at: now)
        }
        for dayKey in attempted.subtracting(scheduled) {
            defaults.removeObject(forKey: summaryKey(dayKey: dayKey))
        }
        if removedPendingDayKeys.contains(todayKey) && !scheduled.contains(todayKey) {
            defaults.removeObject(forKey: summaryKey(dayKey: todayKey))
        }

        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(Self.summaryKeyPrefix) {
            let dayKey = String(key.dropFirst(Self.summaryKeyPrefix.count))
            // yyyyMMdd compara bien lexicográficamente.
            if dayKey > todayKey && !attempted.contains(dayKey) {
                defaults.removeObject(forKey: key)
            }
        }
    }

    private func summaryKey(dayKey: String) -> String {
        Self.summaryKeyPrefix + dayKey
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
                // Formatos: scheduledPaymentNotif_UUID_YYYYMMDD_type (4 componentes)
                // y scheduledPaymentNotif_summary_YYYYMMDD (3 componentes, canal agendado).
                // En AMBOS la fecha es components[2] — el guard histórico `>= 4` habría
                // saltado las summary para siempre (acumulación sin límite).
                let components = key.split(separator: "_")
                guard components.count >= 3 else { continue }
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
