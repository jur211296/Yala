//
//  BudgetPeriodIntervalTests.swift
//  YalaTests
//
//  Tickets `budget-interval-counts-next-period-midnight` y `budget-days-left-counts-today`.
//
//  1. `DateInterval` es cerrado en los dos extremos: con el `end` de un periodo en la medianoche
//     del siguiente, un gasto del día 1 a las 00:00 contaba en los dos presupuestos. Se fija en
//     cada sitio que construye el periodo, no solo en el helper: el bug estaba repetido en siete.
//  2. Decisión de Jürgen (2026-09-06): el último día de un presupuesto todavía cuenta, así que
//     le queda 1 día. Se fija con el mismo caso en Presupuestos, Panel, chat y el helper.
//

import Foundation
import Testing

@testable import Yala

@MainActor
struct BudgetPeriodIntervalTests {

    private let calendar = userConfiguredCalendar()

    private func makeBudget(periodType: BudgetPeriodType, start: Date? = nil, end: Date? = nil) -> Budget {
        Budget(
            currencyCode: "USD",
            limitAmount: 100,
            name: "Comida",
            periodType: periodType.rawValue,
            startDate: start,
            endDate: end
        )
    }

    /// Inicio del periodo en curso y del siguiente, calculados aquí sin pasar por el código bajo test.
    private func currentAndNext(_ periodType: BudgetPeriodType, now: Date) -> (start: Date, next: Date) {
        let component: Calendar.Component
        switch periodType {
        case .weekly: component = .weekOfYear
        case .monthly: component = .month
        case .yearly, .unique: component = .year
        }
        let start = calendar.dateInterval(of: component, for: now)!.start
        let next = calendar.date(byAdding: component, value: 1, to: start)!
        return (start, next)
    }

    private func vmOnCurrentPeriod(now: Date) -> BudgetsViewModel {
        let vm = BudgetsViewModel()
        vm.selectedWeek = calendar.startOfWeek(for: now)
        vm.selectedMonth = calendar.startOfMonth(for: now)
        vm.selectedYear = calendar.component(.year, from: now)
        return vm
    }

    // MARK: - 1. La medianoche del periodo siguiente no entra en el anterior

    static let recurring: [BudgetPeriodType] = [.weekly, .monthly, .yearly]

    @Test("Presupuestos: el periodo elegido no se come la medianoche del siguiente", arguments: recurring)
    func budgetsScreen_excludesNextPeriodMidnight(_ periodType: BudgetPeriodType) {
        let now = Date.now
        let (start, next) = currentAndNext(periodType, now: now)
        let interval = vmOnCurrentPeriod(now: now).getBudgetDateInterval(budget: makeBudget(periodType: periodType))

        #expect(interval.start == start)
        #expect(!interval.contains(next))
        #expect(interval.contains(next.addingTimeInterval(-1)))
    }

    @Test("Panel: el periodo en curso no se come la medianoche del siguiente", arguments: recurring)
    func panel_excludesNextPeriodMidnight(_ periodType: BudgetPeriodType) {
        let now = Date.now
        let (start, next) = currentAndNext(periodType, now: now)
        let interval = PanelViewModel().getBudgetDateInterval(budget: makeBudget(periodType: periodType))

        #expect(interval.start == start)
        #expect(!interval.contains(next))
        #expect(interval.contains(next.addingTimeInterval(-1)))
    }

    @Test("Insights y chat: el periodo en curso no se come la medianoche del siguiente", arguments: recurring)
    func insights_excludesNextPeriodMidnight(_ periodType: BudgetPeriodType) {
        let now = Date.now
        let (start, next) = currentAndNext(periodType, now: now)
        let interval = InsightsCalculator.currentBudgetInterval(for: makeBudget(periodType: periodType), now: now)

        #expect(interval.start == start)
        #expect(!interval.contains(next))
        #expect(interval.contains(next.addingTimeInterval(-1)))
    }

    @Test("Avisos de umbral: el periodo en curso no se come la medianoche del siguiente", arguments: recurring)
    func alerts_excludesNextPeriodMidnight(_ periodType: BudgetPeriodType) {
        let now = Date.now
        let (_, next) = currentAndNext(periodType, now: now)
        let service = BudgetAlertService(tracker: BudgetAlertTracker(defaults: makeIsolatedDefaults()))
        let interval = service.getCurrentPeriodInterval(for: makeBudget(periodType: periodType), now: now)

        #expect(!interval.contains(next))
        #expect(interval.contains(next.addingTimeInterval(-1)))
    }

    /// El historial es donde más mordía: mira periodos PASADOS, y ahí la medianoche que se comía
    /// el periodo anterior ya había pasado y tenía gastos.
    @Test("Historial: el gasto de la medianoche del día 1 cuenta solo en su barra", arguments: recurring)
    func history_midnightOfPeriodStartCountsOnlyInItsBar(_ periodType: BudgetPeriodType) throws {
        let now = Date.now
        let (start, _) = currentAndNext(periodType, now: now)
        let midnight = start  // primer instante del periodo elegido

        let previous = BudgetsViewModel.historyInterval(
            periodType: periodType,
            offset: -1,
            selectedWeek: calendar.startOfWeek(for: now),
            selectedMonth: calendar.startOfMonth(for: now),
            selectedYear: calendar.component(.year, from: now),
            calendar: calendar
        )
        let current = BudgetsViewModel.historyInterval(
            periodType: periodType,
            offset: 0,
            selectedWeek: calendar.startOfWeek(for: now),
            selectedMonth: calendar.startOfMonth(for: now),
            selectedYear: calendar.component(.year, from: now),
            calendar: calendar
        )

        let prev = try #require(previous)
        let cur = try #require(current)
        #expect(!prev.contains(midnight))
        #expect(cur.contains(midnight))
        #expect(prev.contains(midnight.addingTimeInterval(-1)))
    }

    @Test("Único: los dos días cuentan enteros, guarde la hora que guarde")
    func unique_countsWholeDays() {
        let base = calendar.date(from: DateComponents(year: 2026, month: 10, day: 1, hour: 14, minute: 23))!
        let endDay = calendar.date(from: DateComponents(year: 2026, month: 10, day: 31))!  // 00:00, como el selector
        let interval = BudgetPeriodInterval.unique(start: base, end: endDay, calendar: calendar)

        let firstMorning = calendar.date(from: DateComponents(year: 2026, month: 10, day: 1, hour: 8))!
        let lastEvening = calendar.date(from: DateComponents(year: 2026, month: 10, day: 31, hour: 22))!
        let nextMidnight = calendar.date(from: DateComponents(year: 2026, month: 11, day: 1))!

        #expect(interval.contains(firstMorning))
        #expect(interval.contains(lastEvening))
        #expect(!interval.contains(nextMidnight))
    }

    /// El bucket del score es `Calendar.dateInterval(of:)` (semiabierto). Un gasto que llena el
    /// presupuesto el 1 de marzo a las 00:00 excedía también febrero: 94 en vez de 97.
    @Test("Score: el gasto del día 1 a medianoche no excede el mes anterior")
    func financialScore_midnightSpendStaysInItsBucket() {
        let cal = Calendar.current
        let now = cal.date(from: DateComponents(year: 2026, month: 3, day: 17, hour: 12))!
        let budget = Budget(currencyCode: "USD", limitAmount: 100, name: "B", periodType: "monthly")
        budget.createdAt = cal.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let tx = TransactionItem(
            date: cal.date(from: DateComponents(year: 2026, month: 3, day: 1))!,
            amount: -100,
            currencyCode: "USD",
            note: nil,
            category: YalaCategory(name: "Food", colorHex: "#FF0000", isIncome: false),
            tags: [],
            amountInPreferredCurrency: -100,
            preferredCurrencyCode: "USD"
        )

        let score = FinancialScoreCalculator.calculate(
            transactions: [tx],
            budgets: [budget],
            scheduledPayments: [],
            accounts: [],
            paidAmounts: [:],
            period: .thisYear,
            preferredCurrencyCode: "USD",
            converter: MockCurrencyConverter(),
            now: now,
            calendar: cal
        )

        // Enero 100 · febrero 100 · marzo 92 (excedido) → 97. Con el bug, febrero también 92 → 94.
        #expect(score.budget == 97)
    }

    // MARK: - 2. Días que quedan: hoy cuenta

    /// `endOffset` en días respecto de hoy; el fin se guarda a las 00:00, como lo deja el selector.
    struct DaysCase: Sendable, CustomTestStringConvertible {
        let endOffset: Int
        let summary: Int   // Presupuestos y Panel: −1 = «Finalizado»
        let chat: Int      // chat y helper: 0 si ya acabó
        var testDescription: String { "fin en hoy\(endOffset >= 0 ? "+" : "")\(endOffset)" }
    }

    static let daysCases: [DaysCase] = [
        DaysCase(endOffset: 0, summary: 1, chat: 1),
        DaysCase(endOffset: 1, summary: 2, chat: 2),
        DaysCase(endOffset: -1, summary: -1, chat: 0),
    ]

    private func uniqueBudget(endOffset: Int, now: Date) -> Budget {
        let today = calendar.startOfDay(for: now)
        return makeBudget(
            periodType: .unique,
            start: calendar.date(byAdding: .day, value: -5, to: today)!,
            end: calendar.date(byAdding: .day, value: endOffset, to: today)!
        )
    }

    @Test("Días que quedan: mismo resultado en Presupuestos, Panel, chat y el helper", arguments: daysCases)
    func daysLeft_agreeEverywhere(_ c: DaysCase) {
        let now = Date.now
        let budget = uniqueBudget(endOffset: c.endOffset, now: now)

        let budgetsScreen = vmOnCurrentPeriod(now: now).getDaysRemaining(budget: budget)

        let panel = PanelViewModel()
        let panelDays = panel.getBudgetDaysRemaining(budget: budget, interval: panel.getBudgetDateInterval(budget: budget))

        let context = FullFinancialContextBuilder().buildFromArrays(
            transactions: [],
            budgets: [budget],
            accounts: [],
            tags: [],
            scheduledPayments: [],
            currencyCode: "USD",
            currencyDisplay: "$",
            converter: MockCurrencyConverter(fixedRate: 1.0),
            language: "es",
            country: "US",
            includeAnomalies: false,
            now: now
        )
        let chatDays = context.budgets.first?.daysLeft

        let helper = BudgetPeriodInterval.daysLeft(
            now: now,
            in: InsightsCalculator.currentBudgetInterval(for: budget, now: now),
            calendar: calendar
        )

        #expect(budgetsScreen == c.summary)
        #expect(panelDays == c.summary)
        #expect(chatDays == c.chat)
        #expect(helper == c.chat)
    }

    @Test("Días que quedan en un mes recurrente: el último día queda 1, nunca 0")
    func daysLeft_monthly_lastDayIsOne() {
        let cal = Calendar.current
        let month = BudgetPeriodInterval.month(
            startingAt: cal.date(from: DateComponents(year: 2026, month: 10, day: 1))!,
            calendar: cal
        )
        // Cada hora de cada día del mes: el promedio diario disponible nunca divide entre cero.
        var day = month.start
        while day <= month.end {
            #expect(BudgetPeriodInterval.daysLeft(now: day, in: month, calendar: cal) >= 1)
            day = day.addingTimeInterval(3600)
        }
        let lastNight = cal.date(from: DateComponents(year: 2026, month: 10, day: 31, hour: 23, minute: 30))!
        let firstMorning = cal.date(from: DateComponents(year: 2026, month: 10, day: 1, hour: 9))!
        let afterwards = cal.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 0))!
        #expect(BudgetPeriodInterval.daysLeft(now: lastNight, in: month, calendar: cal) == 1)
        #expect(BudgetPeriodInterval.daysLeft(now: firstMorning, in: month, calendar: cal) == 31)
        #expect(BudgetPeriodInterval.daysLeft(now: afterwards, in: month, calendar: cal) == 0)
    }

    @Test("Copy: con un día que queda, la key en singular; con más, la de siempre")
    func copy_singularForOneDay() {
        // Contra el bundle que resuelve `ls()` (respeta el idioma elegido en la app), no el principal.
        let bundle = LanguageManager.bundle
        #expect(L10n.Budgets.daysRemaining(1)
            == NSLocalizedString("budgets.days.remaining.one", bundle: bundle, comment: ""))
        #expect(L10n.Budgets.daysRemaining(3)
            == String(format: NSLocalizedString("budgets.days.remaining", bundle: bundle, comment: ""), "3"))
    }
}
