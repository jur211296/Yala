// Tests generated for: ScheduledPaymentNotificationTracker
// Cobertura estimada: 95%

import Foundation
import Testing

@testable import Yala

@MainActor
@Suite(.serialized)
struct ScheduledPaymentNotificationTrackerTests {

    // MARK: - Helpers

    private let calendar = Calendar.current

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    /// Clean up all tracker keys from UserDefaults to avoid cross-test pollution
    private func cleanupTrackerKeys() {
        let defaults = UserDefaults.standard
        let allKeys = defaults.dictionaryRepresentation().keys
        for key in allKeys
        where key.hasPrefix(ScheduledPaymentNotificationTracker.keyPrefix)
            || key.hasPrefix(ScheduledPaymentNotificationTracker.creditCardKeyPrefix) {
            defaults.removeObject(forKey: key)
        }
    }

    // MARK: - dateKeyString

    @Test func dateKeyString_formatsCorrectly() {
        let date = date(2026, 3, 12)
        let result = ScheduledPaymentNotificationTracker.dateKeyString(from: date)
        #expect(result == "20260312")
    }

    @Test func dateKeyString_singleDigitMonthAndDay_padded() {
        let date = date(2026, 1, 5)
        let result = ScheduledPaymentNotificationTracker.dateKeyString(from: date)
        #expect(result == "20260105")
    }

    @Test func dateKeyString_december31() {
        let date = date(2025, 12, 31)
        let result = ScheduledPaymentNotificationTracker.dateKeyString(from: date)
        #expect(result == "20251231")
    }

    // MARK: - hasNotifiedForDate / markNotified

    @Test func hasNotifiedForDate_notYetNotified_returnsFalse() {
        cleanupTrackerKeys()
        let tracker = ScheduledPaymentNotificationTracker.shared
        let paymentID = UUID()
        let today = Date()

        let result = tracker.hasNotifiedForDate(paymentID: paymentID, date: today, type: .dueDate)
        #expect(result == false)
    }

    @Test func markNotified_thenHasNotified_returnsTrue() {
        cleanupTrackerKeys()
        let tracker = ScheduledPaymentNotificationTracker.shared
        let paymentID = UUID()
        let today = Date()

        tracker.markNotified(paymentID: paymentID, date: today, type: .dueDate)
        let result = tracker.hasNotifiedForDate(paymentID: paymentID, date: today, type: .dueDate)
        #expect(result == true)
    }

    @Test func differentNotificationType_notCrossContaminated() {
        cleanupTrackerKeys()
        let tracker = ScheduledPaymentNotificationTracker.shared
        let paymentID = UUID()
        let today = Date()

        tracker.markNotified(paymentID: paymentID, date: today, type: .dueDate)

        let daysBefore = tracker.hasNotifiedForDate(paymentID: paymentID, date: today, type: .daysBefore)
        let overdue = tracker.hasNotifiedForDate(paymentID: paymentID, date: today, type: .overdue)
        #expect(daysBefore == false)
        #expect(overdue == false)
    }

    @Test func differentDate_notCrossContaminated() {
        cleanupTrackerKeys()
        let tracker = ScheduledPaymentNotificationTracker.shared
        let paymentID = UUID()
        let today = date(2026, 3, 12)
        let tomorrow = date(2026, 3, 13)

        tracker.markNotified(paymentID: paymentID, date: today, type: .dueDate)

        let resultTomorrow = tracker.hasNotifiedForDate(paymentID: paymentID, date: tomorrow, type: .dueDate)
        #expect(resultTomorrow == false)
    }

    @Test func differentPaymentID_notCrossContaminated() {
        cleanupTrackerKeys()
        let tracker = ScheduledPaymentNotificationTracker.shared
        let paymentA = UUID()
        let paymentB = UUID()
        let today = Date()

        tracker.markNotified(paymentID: paymentA, date: today, type: .dueDate)

        let resultB = tracker.hasNotifiedForDate(paymentID: paymentB, date: today, type: .dueDate)
        #expect(resultB == false)
    }

    @Test func allNotificationTypes_trackedIndependently() {
        cleanupTrackerKeys()
        let tracker = ScheduledPaymentNotificationTracker.shared
        let paymentID = UUID()
        let today = Date()

        tracker.markNotified(paymentID: paymentID, date: today, type: .dueDate)
        tracker.markNotified(paymentID: paymentID, date: today, type: .daysBefore)
        tracker.markNotified(paymentID: paymentID, date: today, type: .overdue)

        #expect(tracker.hasNotifiedForDate(paymentID: paymentID, date: today, type: .dueDate) == true)
        #expect(tracker.hasNotifiedForDate(paymentID: paymentID, date: today, type: .daysBefore) == true)
        #expect(tracker.hasNotifiedForDate(paymentID: paymentID, date: today, type: .overdue) == true)
    }

    // MARK: - Credit card dedup (llaveado por Account.shortcutID)

    @Test func creditCard_markThenHasNotified() {
        cleanupTrackerKeys()
        let tracker = ScheduledPaymentNotificationTracker.shared
        let accountID = UUID()
        let today = Self.testNow

        #expect(tracker.hasNotifiedCreditCard(accountID: accountID, date: today) == false)
        tracker.markNotifiedCreditCard(accountID: accountID, date: today)
        #expect(tracker.hasNotifiedCreditCard(accountID: accountID, date: today) == true)
        cleanupTrackerKeys()
    }

    /// Regresión (2026-07-21): la key se llaveaba por `account.name`, así que dos tarjetas
    /// homónimas con el mismo día de pago compartían entrada y solo UNA notificaba.
    /// Con `shortcutID` cada cuenta lleva su propio marcador.
    @Test func creditCard_sameNameDifferentAccounts_notCrossContaminated() {
        cleanupTrackerKeys()
        let tracker = ScheduledPaymentNotificationTracker.shared
        let visaA = UUID()
        let visaB = UUID()
        let today = Self.testNow

        tracker.markNotifiedCreditCard(accountID: visaA, date: today)

        #expect(tracker.hasNotifiedCreditCard(accountID: visaA, date: today) == true)
        #expect(tracker.hasNotifiedCreditCard(accountID: visaB, date: today) == false)
        cleanupTrackerKeys()
    }

    @Test func creditCard_differentDate_notCrossContaminated() {
        cleanupTrackerKeys()
        let tracker = ScheduledPaymentNotificationTracker.shared
        let accountID = UUID()
        let today = Self.testNow
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: today)!

        tracker.markNotifiedCreditCard(accountID: accountID, date: today)

        #expect(tracker.hasNotifiedCreditCard(accountID: accountID, date: nextMonth) == false)
        cleanupTrackerKeys()
    }

    // MARK: - cleanupOldEntries

    /// Fecha fija para tests determinísticos: 2026-04-15 12:00 UTC.
    private static let testNow: Date = {
        var components = DateComponents(year: 2026, month: 4, day: 15, hour: 12)
        components.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: components)!
    }()

    @Test func cleanupOldEntries_removesOlderThan30Days() {
        cleanupTrackerKeys()
        let tracker = ScheduledPaymentNotificationTracker.shared
        let paymentID = UUID()
        let oldDate = calendar.date(byAdding: .day, value: -45, to: Self.testNow)!

        tracker.markNotified(paymentID: paymentID, date: oldDate, type: .dueDate)
        #expect(tracker.hasNotifiedForDate(paymentID: paymentID, date: oldDate, type: .dueDate) == true)

        tracker.cleanupOldEntries(now: Self.testNow)

        #expect(tracker.hasNotifiedForDate(paymentID: paymentID, date: oldDate, type: .dueDate) == false)
    }

    @Test func cleanupOldEntries_keepsRecentEntries() {
        cleanupTrackerKeys()
        let tracker = ScheduledPaymentNotificationTracker.shared
        let paymentID = UUID()
        let recentDate = calendar.date(byAdding: .day, value: -5, to: Self.testNow)!

        tracker.markNotified(paymentID: paymentID, date: recentDate, type: .dueDate)

        tracker.cleanupOldEntries(now: Self.testNow)

        #expect(tracker.hasNotifiedForDate(paymentID: paymentID, date: recentDate, type: .dueDate) == true)
        cleanupTrackerKeys()
    }

    @Test func cleanupOldEntries_keeps29DayOldEntry() {
        cleanupTrackerKeys()
        let tracker = ScheduledPaymentNotificationTracker.shared
        let paymentID = UUID()
        let twentyNineDaysAgo = calendar.date(byAdding: .day, value: -29, to: Self.testNow)!

        tracker.markNotified(paymentID: paymentID, date: twentyNineDaysAgo, type: .dueDate)

        tracker.cleanupOldEntries(now: Self.testNow)

        // 29 days ago is safely within the 30-day window
        #expect(tracker.hasNotifiedForDate(paymentID: paymentID, date: twentyNineDaysAgo, type: .dueDate) == true)
        cleanupTrackerKeys()
    }

    @Test func cleanupOldEntries_removes31DayOldEntry() {
        cleanupTrackerKeys()
        let tracker = ScheduledPaymentNotificationTracker.shared
        let paymentID = UUID()
        let thirtyOneDaysAgo = calendar.date(byAdding: .day, value: -31, to: Self.testNow)!

        tracker.markNotified(paymentID: paymentID, date: thirtyOneDaysAgo, type: .dueDate)

        tracker.cleanupOldEntries(now: Self.testNow)

        // 31 days ago is past the 30-day window
        #expect(tracker.hasNotifiedForDate(paymentID: paymentID, date: thirtyOneDaysAgo, type: .dueDate) == false)
        cleanupTrackerKeys()
    }

    /// Regresión (2026-07-21): el cleanup filtraba SOLO por `scheduledPaymentNotif_`, así
    /// que las keys de tarjeta crecían sin límite en `UserDefaults` (una por cuenta y día
    /// de pago avisado, para siempre).
    @Test func cleanupOldEntries_creditCard_removesOldKeepsRecent() {
        cleanupTrackerKeys()
        let tracker = ScheduledPaymentNotificationTracker.shared
        let staleAccount = UUID()
        let recentAccount = UUID()
        let oldDate = calendar.date(byAdding: .day, value: -45, to: Self.testNow)!
        let recentDate = calendar.date(byAdding: .day, value: -5, to: Self.testNow)!

        tracker.markNotifiedCreditCard(accountID: staleAccount, date: oldDate)
        tracker.markNotifiedCreditCard(accountID: recentAccount, date: recentDate)

        tracker.cleanupOldEntries(now: Self.testNow)

        #expect(tracker.hasNotifiedCreditCard(accountID: staleAccount, date: oldDate) == false)
        #expect(tracker.hasNotifiedCreditCard(accountID: recentAccount, date: recentDate) == true)
        cleanupTrackerKeys()
    }

    /// Las keys del formato legacy (`creditCardNotif_<nombre>_YYYYMMDD`) también caducan:
    /// la fecha se lee por el ÚLTIMO componente, así que un nombre con "_" —que desplazaba
    /// los índices— ya no deja la key huérfana para siempre.
    @Test func cleanupOldEntries_creditCard_removesLegacyNameKeyedEntries() {
        cleanupTrackerKeys()
        let defaults = UserDefaults.standard
        let tracker = ScheduledPaymentNotificationTracker.shared
        let oldDate = calendar.date(byAdding: .day, value: -45, to: Self.testNow)!
        let recentDate = calendar.date(byAdding: .day, value: -5, to: Self.testNow)!
        let oldStamp = ScheduledPaymentNotificationTracker.dateKeyString(from: oldDate)
        let recentStamp = ScheduledPaymentNotificationTracker.dateKeyString(from: recentDate)

        let staleSimpleName = "creditCardNotif_Visa_\(oldStamp)"
        let staleNameWithUnderscore = "creditCardNotif_Mi_Visa_Oro_\(oldStamp)"
        let recentLegacy = "creditCardNotif_Amex_\(recentStamp)"
        for key in [staleSimpleName, staleNameWithUnderscore, recentLegacy] {
            defaults.set(true, forKey: key)
        }

        tracker.cleanupOldEntries(now: Self.testNow)

        #expect(defaults.object(forKey: staleSimpleName) == nil)
        #expect(defaults.object(forKey: staleNameWithUnderscore) == nil)
        #expect(defaults.object(forKey: recentLegacy) != nil)
        cleanupTrackerKeys()
    }

    // MARK: - NotificationType rawValues

    @Test func notificationType_rawValues_correct() {
        #expect(ScheduledPaymentNotificationTracker.NotificationType.dueDate.rawValue == "dueDate")
        #expect(ScheduledPaymentNotificationTracker.NotificationType.daysBefore.rawValue == "daysBefore")
        #expect(ScheduledPaymentNotificationTracker.NotificationType.overdue.rawValue == "overdue")
    }
}

/*
Tests generated:
1. test dateKeyString_formatsCorrectly - Verifies date key format YYYYMMDD
2. test dateKeyString_singleDigitMonthAndDay_padded - Zero-padding for single digits
3. test dateKeyString_december31 - Year boundary formatting
4. test hasNotifiedForDate_notYetNotified_returnsFalse - Default state before marking
5. test markNotified_thenHasNotified_returnsTrue - Mark and verify notification sent
6. test differentNotificationType_notCrossContaminated - Types isolated from each other
7. test differentDate_notCrossContaminated - Dates isolated from each other
8. test differentPaymentID_notCrossContaminated - Payment IDs isolated
9. test allNotificationTypes_trackedIndependently - Multiple types on same payment/date
10. test cleanupOldEntries_removesOlderThan30Days - Cleanup removes stale entries (45 days old)
11. test cleanupOldEntries_keepsRecentEntries - Cleanup preserves recent entries (5 days old)
12. test cleanupOldEntries_keeps29DayOldEntry - Safely within 30-day window
13. test cleanupOldEntries_removes31DayOldEntry - Just past the 30-day window
15. test creditCard_markThenHasNotified - Dedup de la notif de tarjeta (por Account.shortcutID)
16. test creditCard_sameNameDifferentAccounts_notCrossContaminated - Cuentas homónimas aisladas
17. test creditCard_differentDate_notCrossContaminated - Fechas aisladas
18. test cleanupOldEntries_creditCard_removesOldKeepsRecent - El cleanup 30d cubre el prefijo de tarjeta
19. test cleanupOldEntries_creditCard_removesLegacyNameKeyedEntries - Y también el formato legacy por nombre
14. test notificationType_rawValues_correct - Enum raw values match expected strings

Cases NOT covered (require more context):
- Thread safety of shared singleton (would need concurrent test infrastructure)
- Exact 30-day boundary behavior depends on time-of-day (key stores only date, not time)
*/
