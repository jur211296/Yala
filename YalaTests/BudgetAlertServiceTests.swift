//
//  BudgetAlertServiceTests.swift
//  YalaTests
//
//  Unit tests for BudgetAlertService.getCurrentPeriodInterval logic.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite(.serialized)
struct BudgetAlertServiceTests {

    // MARK: - Helpers

    /// Fecha fija para tests determinísticos: 2026-04-15 12:00 UTC.
    /// Evita flakiness por transición de medianoche, DST, o timezone del CI.
    private static let testNow: Date = {
        var components = DateComponents(year: 2026, month: 4, day: 15, hour: 12)
        components.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: components)!
    }()

    // MARK: - Period Interval Tests

    @MainActor @Test func weeklyPeriod_7dayDuration() {
        let service = BudgetAlertService.shared
        let budget = makeBudget(periodType: "weekly")
        let interval = service.getCurrentPeriodInterval(for: budget, now: Self.testNow)

        let days = Calendar.current.dateComponents([.day], from: interval.start, to: interval.end).day!
        #expect(days == 7)
    }

    @MainActor @Test func monthlyPeriod_containsNow() {
        let service = BudgetAlertService.shared
        let budget = makeBudget(periodType: "monthly")
        let interval = service.getCurrentPeriodInterval(for: budget, now: Self.testNow)

        #expect(interval.contains(Self.testNow))
    }

    @MainActor @Test func monthlyPeriod_startIsFirstOfMonth() {
        let service = BudgetAlertService.shared
        let budget = makeBudget(periodType: "monthly")
        let interval = service.getCurrentPeriodInterval(for: budget, now: Self.testNow)

        let day = Calendar.current.component(.day, from: interval.start)
        #expect(day == 1)
    }

    @MainActor @Test func yearlyPeriod_startsJan1() {
        let service = BudgetAlertService.shared
        let budget = makeBudget(periodType: "yearly")
        let interval = service.getCurrentPeriodInterval(for: budget, now: Self.testNow)

        let components = Calendar.current.dateComponents([.month, .day], from: interval.start)
        #expect(components.month == 1)
        #expect(components.day == 1)
    }

    @MainActor @Test func uniquePeriod_usesExactDates() {
        let start = Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: 1))!
        let end = Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 30))!
        let service = BudgetAlertService.shared
        let budget = makeBudget(periodType: "unique", startDate: start, endDate: end)
        let interval = service.getCurrentPeriodInterval(for: budget, now: Self.testNow)

        #expect(interval.start == start)
        #expect(interval.end == end)
    }

    @MainActor @Test func uniquePeriod_noDates_fallbackMonthly() {
        let service = BudgetAlertService.shared
        let budget = makeBudget(periodType: "unique")
        let interval = service.getCurrentPeriodInterval(for: budget, now: Self.testNow)

        // Falls back to monthly — should contain `now` and start on day 1
        #expect(interval.contains(Self.testNow))
        let day = Calendar.current.component(.day, from: interval.start)
        #expect(day == 1)
    }

    // MARK: - notifyCrossedThresholds — dedup del threshold ENVIADO solo con entrega confirmada
    // (ticket pagos-planificados-notifs-incoherentes-y-dedup-sin-entrega, D3: superficie hermana).
    // Instancia aislada (`init(tracker:)`) + tracker con UserDefaults propio ⇒ el singleton
    // `.shared` no se toca y no hay dependencia de `ModelContext`/`Date.now`.

    private static let notifyPeriodKey = "2026-04"

    @MainActor @Test func notify_sendFails_maxThresholdNotMarked_othersMarked() async {
        let tracker = BudgetAlertTracker(defaults: makeIsolatedDefaults())
        let service = BudgetAlertService(tracker: tracker)
        service.sendOverride = { _, _, _, _, _ in false }   // iOS rechaza el request

        let id = UUID()
        await service.notifyCrossedThresholds(
            budgetID: id, budgetName: "Comida", periodKey: Self.notifyPeriodKey,
            newThresholds: [50, 75, 90], spent: 90, limit: 100, currencyCode: "USD"
        )

        // 90 = el ENVIADO (falló) ⇒ NO marcado (se reintenta); 50/75 = supresión intencional.
        #expect(tracker.notifiedThresholds(budgetID: id, periodKey: Self.notifyPeriodKey) == [50, 75])
    }

    @MainActor @Test func notify_sendSucceeds_allThresholdsMarked() async {
        let tracker = BudgetAlertTracker(defaults: makeIsolatedDefaults())
        let service = BudgetAlertService(tracker: tracker)
        service.sendOverride = { _, _, _, _, _ in true }

        let id = UUID()
        await service.notifyCrossedThresholds(
            budgetID: id, budgetName: "Comida", periodKey: Self.notifyPeriodKey,
            newThresholds: [50, 75, 90], spent: 90, limit: 100, currencyCode: "USD"
        )

        #expect(tracker.notifiedThresholds(budgetID: id, periodKey: Self.notifyPeriodKey) == [50, 75, 90])
    }

    @MainActor @Test func notify_singleThreshold_sendFails_notMarked() async {
        let tracker = BudgetAlertTracker(defaults: makeIsolatedDefaults())
        let service = BudgetAlertService(tracker: tracker)
        service.sendOverride = { _, _, _, _, _ in false }

        let id = UUID()
        await service.notifyCrossedThresholds(
            budgetID: id, budgetName: "Comida", periodKey: Self.notifyPeriodKey,
            newThresholds: [50], spent: 55, limit: 100, currencyCode: "USD"
        )

        // Único threshold cruzado y no entregado ⇒ nada marcado (retry en el próximo check).
        #expect(tracker.notifiedThresholds(budgetID: id, periodKey: Self.notifyPeriodKey).isEmpty)
    }

    @MainActor @Test func notify_emptyThresholds_noSendNoMark() async {
        let tracker = BudgetAlertTracker(defaults: makeIsolatedDefaults())
        let service = BudgetAlertService(tracker: tracker)
        service.sendOverride = { _, _, _, _, _ in true }

        let id = UUID()
        await service.notifyCrossedThresholds(
            budgetID: id, budgetName: "Comida", periodKey: Self.notifyPeriodKey,
            newThresholds: [], spent: 0, limit: 100, currencyCode: "USD"
        )

        // Sin thresholds cruzados: el guard `max()` sale temprano ⇒ nada enviado ni marcado.
        // (Caza un mutante que sustituya el guard por `?? 0`: enviaría/marcaría un 0 espurio.)
        #expect(tracker.notifiedThresholds(budgetID: id, periodKey: Self.notifyPeriodKey).isEmpty)
    }
}
