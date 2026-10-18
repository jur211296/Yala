//
//  UXAudit22Lote9BudgetsTests.swift
//  YalaTests
//
//  Auditoría UX 2.2 · lote 9 (presupuestos): lo que se prueba sin pantalla.
//  - Lo que queda y lo que toca por día (L9-1, L9-6, L9-10).
//  - El período con nombre propio del detalle (L9-6) y el mes con su «de» (L9-8).
//  - La alerta lleva el id del presupuesto y vuelve a él (L9-5).
//  - «Mostrar en el widget» respeta el orden de favoritos (L9-12).
//  - Las semanas de la rueda nativa (L9-8).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

// MARK: - Lo que queda (L9-1)

struct BudgetRemainingLogicTests {

    @Test func remaining_isLimitMinusSpent_andNegativeWhenOver() {
        #expect(BudgetRemainingLogic.remaining(limit: 1_800, spent: 1_408) == 392)
        #expect(BudgetRemainingLogic.remaining(limit: 1_800, spent: 2_737) == -937)
        #expect(BudgetRemainingLogic.remaining(limit: 500, spent: 500) == 0)
    }

    /// Gastar justo el límite no es pasarse, y medio céntimo de una conversión tampoco.
    @Test func isOver_onlyWhenSpentExceedsTheLimit() {
        #expect(!BudgetRemainingLogic.isOver(limit: 1_800, spent: 1_800))
        #expect(!BudgetRemainingLogic.isOver(limit: 1_800, spent: 1_800.004))
        #expect(BudgetRemainingLogic.remaining(limit: 1_800, spent: 1_800.004) == 0)
        #expect(BudgetRemainingLogic.isOver(limit: 1_800, spent: 1_800.01))
    }

    /// «Al día» = lo que queda entre los días que faltan, hoy incluido; solo en curso y con algo por gastar.
    @Test func perDay_onlyWhileRunningAndWithSomethingLeft() {
        #expect(BudgetRemainingLogic.perDay(remaining: 392, daysRemaining: 18) == 392.0 / 18.0)
        #expect(BudgetRemainingLogic.perDay(remaining: 100, daysRemaining: 1) == 100)
        // Cerrado (-1) y aún no empieza (0): no hay «al día».
        #expect(BudgetRemainingLogic.perDay(remaining: 392, daysRemaining: -1) == nil)
        #expect(BudgetRemainingLogic.perDay(remaining: 392, daysRemaining: 0) == nil)
        // Pasado del límite o justo en él: nada que repartir.
        #expect(BudgetRemainingLogic.perDay(remaining: -10, daysRemaining: 5) == nil)
        #expect(BudgetRemainingLogic.perDay(remaining: 0, daysRemaining: 5) == nil)
    }

    /// El período cerrado dice «Cerrado» (antes «Pasado») y el futuro, que aún no empieza.
    @Test func shortDays_saysClosedAndNotStarted() {
        #expect(L10n.UXL9.shortDays(-1) == NSLocalizedString("budgets.period.past", comment: ""))
        #expect(L10n.UXL9.shortDays(0) != L10n.UXL9.shortDays(-1))
        #expect(L10n.UXL9.shortDays(1) != L10n.UXL9.shortDays(2))
        #expect(L10n.UXL9.shortDays(18).contains("18"))
    }
}

// MARK: - Período con nombre (L9-6, L9-8)

struct BudgetPeriodTitleLogicTests {

    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Lima") ?? .current
        c.firstWeekday = 2
        return c
    }()

    private let es = Locale(identifier: "es_PE")

    private func date(_ y: Int, _ m: Int, _ d: Int) throws -> Date {
        try #require(calendar.date(from: DateComponents(year: y, month: m, day: d)))
    }

    /// El mes lleva el «de» de la plantilla localizada: «Octubre de 2026», no «Octubre 2026».
    @Test func monthly_saysMonthOfYear() throws {
        let title = BudgetPeriodTitleLogic.title(
            periodType: .monthly, week: .now, month: try date(2026, 10, 1), year: 2026,
            uniqueStart: nil, uniqueEnd: nil, calendar: calendar, locale: es)
        #expect(title == "Octubre de 2026")
    }

    @Test func yearly_saysTheYear() {
        let title = BudgetPeriodTitleLogic.title(
            periodType: .yearly, week: .now, month: .now, year: 2025,
            uniqueStart: nil, uniqueEnd: nil, calendar: calendar, locale: es)
        #expect(title == "2025")
    }

    @Test func weekly_saysTheRange() throws {
        let title = BudgetPeriodTitleLogic.title(
            periodType: .weekly, week: try date(2026, 10, 12), month: .now, year: 2026,
            uniqueStart: nil, uniqueEnd: nil, calendar: calendar, locale: es)
        #expect(title.contains("12"))
        #expect(title.contains("18"))
        #expect(title.contains("–"))
    }

    @Test func unique_saysItsDates_orNothingWithoutThem() throws {
        let withDates = BudgetPeriodTitleLogic.title(
            periodType: .unique, week: .now, month: .now, year: 2026,
            uniqueStart: try date(2026, 3, 1), uniqueEnd: try date(2026, 3, 20), calendar: calendar, locale: es)
        #expect(withDates.contains("2026"))
        #expect(withDates.contains("20"))
        let without = BudgetPeriodTitleLogic.title(
            periodType: .unique, week: .now, month: .now, year: 2026,
            uniqueStart: nil, uniqueEnd: nil, calendar: calendar, locale: es)
        #expect(without.isEmpty)
    }

    /// La rueda semanal: una opción por semana, la actual marcada, ordenadas y sin huecos.
    @Test func weekOptions_coverEveryWeek_andMarkThisWeek() throws {
        let now = try date(2026, 10, 15)
        let options = BudgetPeriodWheelSheet.weekOptions(
            from: try date(2026, 9, 1), to: try date(2026, 11, 30), now: now, calendar: calendar, locale: es)
        #expect(options.count >= 13)
        for (a, b) in zip(options, options.dropFirst()) {
            #expect(calendar.dateComponents([.day], from: a.start, to: b.start).day == 7)
        }
        let current = try #require(options.first { calendar.isDate($0.start, equalTo: now, toGranularity: .weekOfYear) })
        #expect(current.label.hasPrefix(L10n.Period.thisWeek))
    }
}

// MARK: - Tocar una alerta (L9-5)

@MainActor
struct BudgetAlertRoutingTests {

    @Test func deepLink_roundTrips_theBudgetID() {
        let id = UUID()
        let link = BudgetAlertRouting.deepLink(for: id)
        #expect(link == "budgets/\(id.uuidString)")
        #expect(BudgetAlertRouting.budgetID(fromDeepLink: link) == id)
    }

    @Test func plainBudgetsLink_hasNoBudget_andStillRoutesToBudgets() {
        #expect(BudgetAlertRouting.budgetID(fromDeepLink: "budgets") == nil)
        #expect(BudgetAlertRouting.budgetID(fromDeepLink: "budgets/no-es-un-uuid") == nil)
        #expect(NotificationService.parseDestination("budgets/\(UUID().uuidString)") == .budgets)
        #expect(NotificationService.parseDestination("budgets") == .budgets)
    }

    /// El toque apunta el presupuesto; Presupuestos lo consume UNA vez.
    @Test func routeTap_requestsTheBudget_andConsumeIsOneShot() {
        let routing = BudgetAlertRouting.shared
        _ = routing.consume()
        let id = UUID()
        NotificationService.routeTap(deepLink: BudgetAlertRouting.deepLink(for: id), targetSessionID: nil)
        #expect(routing.pendingBudgetID == id)
        #expect(routing.consume() == id)
        #expect(routing.consume() == nil)
    }

    /// Un aviso que nadie recogió (el intent se descartó) no abre un detalle horas después.
    @Test func consume_dropsAStaleRequest() {
        let routing = BudgetAlertRouting.shared
        _ = routing.consume()
        let now = Date(timeIntervalSince1970: 1_000_000)
        routing.request(UUID(), now: now)
        #expect(routing.consume(now: now.addingTimeInterval(BudgetAlertRouting.maxAge + 1)) == nil)
        let id = UUID()
        routing.request(id, now: now)
        #expect(routing.consume(now: now.addingTimeInterval(BudgetAlertRouting.maxAge)) == id)
    }

    @Test func notificationTitle_isBudgets_notTheName() {
        #expect(BudgetAlertService.notificationTitle == L10n.Planning.budgets)
    }
}

// MARK: - Mostrar en el widget (L9-12)

@Suite(.serialized)
@MainActor
struct BudgetWidgetFavoriteLogicTests {

    private func makeBudgets(_ context: ModelContext) -> (a: Budget, b: Budget, c: Budget) {
        let a = Budget(currencyCode: "PEN", limitAmount: 100, name: "A", isFavorite: true, favoriteOrder: 0)
        let b = Budget(currencyCode: "PEN", limitAmount: 100, name: "B", isFavorite: true, favoriteOrder: 1)
        let c = Budget(currencyCode: "PEN", limitAmount: 100, name: "C")
        [a, b, c].forEach { context.insert($0) }
        return (a, b, c)
    }

    @Test func showing_appendsAtTheEnd() throws {
        let context = try makeTestContext()
        let (a, b, c) = makeBudgets(context)
        try context.save()
        BudgetWidgetFavoriteLogic.setShownInWidget(true, for: c, among: [a, b, c])
        #expect(c.isFavorite)
        #expect(c.favoriteOrder == 2)
        #expect(a.favoriteOrder == 0 && b.favoriteOrder == 1)
    }

    @Test func hiding_reindexesTheRest_withoutGaps() throws {
        let context = try makeTestContext()
        let (a, b, c) = makeBudgets(context)
        try context.save()
        BudgetWidgetFavoriteLogic.setShownInWidget(false, for: a, among: [a, b, c])
        #expect(!a.isFavorite)
        #expect(a.favoriteOrder == 0)
        #expect(b.favoriteOrder == 0)
        #expect(!c.isFavorite)
    }

    @Test func sameState_changesNothing() throws {
        let context = try makeTestContext()
        let (a, b, c) = makeBudgets(context)
        try context.save()
        BudgetWidgetFavoriteLogic.setShownInWidget(true, for: b, among: [a, b, c])
        #expect(b.favoriteOrder == 1)
        BudgetWidgetFavoriteLogic.setShownInWidget(false, for: c, among: [a, b, c])
        #expect(c.favoriteOrder == 0 && !c.isFavorite)
    }
}

// MARK: - ¿Qué gastos cuenta? (L9-2)

struct BudgetCountsAllExpensesTests {

    @Test func withoutFilters_countsAll_andAnyFilterMakesItPartial() {
        #expect(Budget(currencyCode: "PEN", limitAmount: 1).countsAllExpenses)
        #expect(!Budget(currencyCode: "PEN", limitAmount: 1, natures: "essential").countsAllExpenses)
        #expect(!Budget(currencyCode: "PEN", limitAmount: 1, subcategoryIDs: UUID().uuidString).countsAllExpenses)
        #expect(!Budget(currencyCode: "PEN", limitAmount: 1, accountIDs: UUID().uuidString).countsAllExpenses)
        #expect(!Budget(currencyCode: "PEN", limitAmount: 1, tagIDs: UUID().uuidString).countsAllExpenses)
    }
}

// MARK: - Cifras cortas de las gráficas (L9-7)

struct BudgetChartsShortKTests {

    /// Con un decimal por debajo de 10K: 1.450 y 1.600 ya no salen igual que un límite de 1.500.
    @Test func shortK_keepsOneDecimalUnderTenThousand() {
        #expect(BudgetChartsView.shortK(1_450) == "1.4K" || BudgetChartsView.shortK(1_450) == "1.5K")
        #expect(BudgetChartsView.shortK(1_600) == "1.6K")
        #expect(BudgetChartsView.shortK(1_500) == "1.5K")
        #expect(BudgetChartsView.shortK(2_000) == "2K")
        #expect(BudgetChartsView.shortK(12_400) == "12K")
        #expect(BudgetChartsView.shortK(850) == "850")
    }
}
