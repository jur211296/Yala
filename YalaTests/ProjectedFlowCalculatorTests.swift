//
//  ProjectedFlowCalculatorTests.swift
//  YalaTests
//
//  «Ver proyectado» (card «Flujo proyectado en Tendencias y Panel», 2026-11-06): la aritmética pura
//  (`ProjectedFlowCalculator`) y de dónde sale cada importe (`ProjectedFlowBuilder`). El «hoy» es fijo: 6 de noviembre
//  de 2026 a las 15:00, en Lima.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
struct ProjectedFlowCalculatorTests {

    private static var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Lima") ?? .current
        calendar.firstWeekday = 2
        return calendar
    }()

    private var calendar: Calendar { Self.calendar }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0, second: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, second: second))!
    }

    private var today: Date { date(2026, 11, 6, hour: 15) }

    /// «Este mes» en curso: del 1 al 30 de noviembre a las 23:59:59 (como `DetailPeriod.dateInterval`).
    private var thisMonth: DateInterval {
        DateInterval(start: date(2026, 11, 1), end: date(2026, 11, 30, hour: 23).addingTimeInterval(59 * 60 + 59))
    }

    // MARK: - Días por delante

    @Test func futureDays_runFromTomorrowToTheLastDayOfThePeriod() {
        let days = ProjectedFlowCalculator.futureDays(in: thisMonth, today: today, calendar: calendar)
        #expect(days.count == 24)
        #expect(days.first == date(2026, 11, 7))
        #expect(days.last == date(2026, 11, 30))
    }

    /// `DateInterval` es cerrado: un rango que acaba justo en la medianoche del 1 de diciembre no tiene el 1 de
    /// diciembre como día (regla de `CLAUDE.md`, «Cálculos con fechas»).
    @Test func futureDays_anIntervalEndingAtMidnight_doesNotAddTheNextDay() {
        let interval = DateInterval(start: date(2026, 11, 1), end: date(2026, 12, 1))
        let days = ProjectedFlowCalculator.futureDays(in: interval, today: today, calendar: calendar)
        #expect(days.last == date(2026, 11, 30))
    }

    /// Los períodos en curso cierran hoy a las 23:59:59 (`DetailPeriod.dateInterval`): sin alargarlos al período entero,
    /// «Este mes» no tendría nunca días por delante. Medido el 2026-11-06 en el simulador: la píldora no salía.
    @Test func horizon_stretchesThePeriodsInProgressToTheirWholeLength() {
        let monthToDate = DateInterval(start: date(2026, 11, 1), end: date(2026, 11, 6, hour: 23).addingTimeInterval(3_599))
        let month = ProjectedFlowCalculator.horizon(for: .thisMonth, interval: monthToDate, calendar: calendar)
        #expect(ProjectedFlowCalculator.futureDays(in: month, today: today, calendar: calendar).last == date(2026, 11, 30))

        let weekToDate = DateInterval(start: date(2026, 11, 2), end: date(2026, 11, 6, hour: 23))
        let week = ProjectedFlowCalculator.horizon(for: .thisWeek, interval: weekToDate, calendar: calendar)
        #expect(ProjectedFlowCalculator.futureDays(in: week, today: today, calendar: calendar).last == date(2026, 11, 8))

        let yearToDate = DateInterval(start: date(2026, 1, 1), end: date(2026, 11, 6, hour: 23))
        let year = ProjectedFlowCalculator.horizon(for: .thisYear, interval: yearToDate, calendar: calendar)
        #expect(ProjectedFlowCalculator.futureDays(in: year, today: today, calendar: calendar).last == date(2026, 12, 31))

        let last30 = DateInterval(start: date(2026, 10, 8), end: date(2026, 11, 6, hour: 23))
        #expect(ProjectedFlowCalculator.horizon(for: .last30Days, interval: last30, calendar: calendar) == last30)
    }

    @Test func futureDays_aPeriodEndingToday_hasNoDaysAndNoControl() {
        let last7 = DateInterval(start: date(2026, 10, 31), end: date(2026, 11, 6, hour: 23))
        #expect(ProjectedFlowCalculator.futureDays(in: last7, today: today, calendar: calendar).isEmpty)
        #expect(!ProjectedFlowCalculator.hasDaysAhead(last7, today: today, calendar: calendar))
        #expect(ProjectedFlowCalculator.hasDaysAhead(thisMonth, today: today, calendar: calendar))
    }

    // MARK: - Pagos: dónde se dibujan (6A)

    @Test func drawingDay_aPaymentAheadKeepsItsDay_anOverdueOrTodayOneGoesTomorrow() {
        #expect(ProjectedFlowCalculator.drawingDay(forOccurrence: date(2026, 11, 20), today: today, calendar: calendar)
            == date(2026, 11, 20))
        #expect(ProjectedFlowCalculator.drawingDay(forOccurrence: date(2026, 11, 2), today: today, calendar: calendar)
            == date(2026, 11, 7))
        #expect(ProjectedFlowCalculator.drawingDay(forOccurrence: date(2026, 11, 6), today: today, calendar: calendar)
            == date(2026, 11, 7))
    }

    // MARK: - Plan (1A, 5A)

    @Test func lineRemaining_subtractsSpentAndPendingPayments_andNeverGoesNegative() {
        #expect(ProjectedFlowCalculator.lineRemaining(planned: 500, real: 300, pendingScheduled: 100) == 100)
        #expect(ProjectedFlowCalculator.lineRemaining(planned: 500, real: 650, pendingScheduled: 0) == 0)
        #expect(ProjectedFlowCalculator.lineRemaining(planned: 500, real: 300, pendingScheduled: 400) == 0)
    }

    @Test func spread_dividesEachMonthAmongItsDaysAhead() {
        let novemberDays = ProjectedFlowCalculator.futureDays(in: thisMonth, today: today, calendar: calendar)
        let decemberDays = [date(2026, 12, 1), date(2026, 12, 2), date(2026, 12, 3)]
        let spread = ProjectedFlowCalculator.spread(
            remainingByMonth: [
                date(2026, 11, 1): .init(income: 48, expense: 240),
                date(2026, 12, 1): .init(income: 0, expense: 310),
            ],
            over: novemberDays + decemberDays,
            today: today,
            calendar: calendar
        )
        // Noviembre: 24 días por delante (7 al 30). Diciembre aún no empezó: sus 31 días.
        #expect(spread[date(2026, 11, 7)] == .init(income: 2, expense: 10))
        #expect(spread[date(2026, 11, 30)] == .init(income: 2, expense: 10))
        #expect(spread[date(2026, 12, 2)] == .init(income: 0, expense: 10))
        let novemberTotal = novemberDays.reduce(0.0) { $0 + (spread[$1]?.expense ?? 0) }
        #expect(abs(novemberTotal - 240) < 0.0001, "Lo que falta del mes se reparte entero en los días que quedan")
    }

    // MARK: - Ritmo

    @Test func rhythm_needsTwoWeeksOfHistory_andNeverInventsRefunds() {
        #expect(ProjectedFlowCalculator.rhythm(incomeTotal: 1_000, expenseTotal: 1_000, historyDays: 13) == nil)
        #expect(ProjectedFlowCalculator.rhythm(incomeTotal: 900, expenseTotal: 300, historyDays: 30)
            == .init(income: 30, expense: 10))
        #expect(ProjectedFlowCalculator.rhythm(incomeTotal: 0, expenseTotal: -60, historyDays: 30)
            == .init(income: 0, expense: 0))
    }

    // MARK: - Acumular por métrica

    @Test func accumulate_eachMetricAddsItsSide_andStartsAtTheAnchor() {
        let days = [date(2026, 11, 7), date(2026, 11, 8)]
        let flows: [Date: ProjectedFlowCalculator.DayFlow] = [
            date(2026, 11, 7): .init(income: 100, expense: 30),
            date(2026, 11, 8): .init(income: 0, expense: 20),
        ]
        func values(_ metric: TrendType, anchor: Double) -> [Double] {
            ProjectedFlowCalculator.accumulate(
                metric: metric, anchorValue: anchor, today: today, days: days, flows: flows, calendar: calendar
            ).map(\.value)
        }
        #expect(values(.expense, anchor: 500) == [500, 530, 550])
        #expect(values(.income, anchor: 1_000) == [1_000, 1_100, 1_100])
        #expect(values(.balance, anchor: 2_000) == [2_000, 2_070, 2_050])
        let first = ProjectedFlowCalculator.accumulate(
            metric: .expense, anchorValue: 0, today: today, days: days, flows: flows, calendar: calendar
        ).first
        #expect(first?.date == date(2026, 11, 6), "El primer punto es hoy: la línea punteada arranca donde acaba la real")
    }

    @Test func bucketed_byWeek_keepsTheAnchorWeekAndTheLastValueOfEachWeek() {
        // Hoy es viernes 6; la semana empieza el lunes 2.
        let daily = [
            BarPoint(date: date(2026, 11, 6), value: 100),
            BarPoint(date: date(2026, 11, 7), value: 110),
            BarPoint(date: date(2026, 11, 8), value: 120),
            BarPoint(date: date(2026, 11, 9), value: 130),
            BarPoint(date: date(2026, 11, 15), value: 190),
        ]
        let weekly = ProjectedFlowCalculator.bucketed(daily, grouping: .week, calendar: calendar)
        #expect(weekly.map(\.date) == [date(2026, 11, 2), date(2026, 11, 9)])
        #expect(weekly.map(\.value) == [100, 190])
    }

    @Test func anchorAndCut_dropWhatComesAfterToday() {
        let points = [
            BarPoint(date: date(2026, 11, 5), value: 40),
            BarPoint(date: date(2026, 11, 6), value: 90),
            BarPoint(date: date(2026, 11, 20), value: 140),
        ]
        #expect(ProjectedFlowCalculator.anchorValue(in: points, today: today, grouping: .day, calendar: calendar) == 90)
        #expect(ProjectedFlowCalculator.pointsUpToToday(points, today: today, grouping: .day, calendar: calendar).count == 2)
        #expect(ProjectedFlowCalculator.anchorValue(in: [], today: today, grouping: .day, calendar: calendar) == 0)
    }

    // MARK: - Builder sin plan: pagos, movimientos futuros y ritmo

    private struct IdentityConverter: CurrencyConverting {
        func convert(_ amount: Decimal, from: String, to: String, on date: Date) -> Decimal { amount }
        func convertWithLatestRate(_ amount: Decimal, from: String, to: String) -> Decimal { amount }
        func convertChecked(_ amount: Decimal, from: String, to: String, on date: Date)
            -> (amount: Decimal, quality: RateQuality) { (amount, .exact) }
        func convertCheckedWithLatestRate(_ amount: Decimal, from: String, to: String)
            -> (amount: Decimal, quality: RateQuality) { (amount, .exact) }
    }

    private func inputs(
        transactions: [TransactionItem],
        payments: [ScheduledPayment] = [],
        days: [Date]? = nil
    ) -> ProjectedFlowBuilder.Inputs {
        ProjectedFlowBuilder.Inputs(
            today: today,
            calendar: calendar,
            overdueWindowStart: date(2026, 11, 1),
            days: days ?? ProjectedFlowCalculator.futureDays(in: thisMonth, today: today, calendar: calendar),
            allTransactions: transactions,
            countedTransactions: transactions,
            hasSessionFilters: false,
            scheduledPayments: payments,
            paymentFilter: .none,
            currencyCode: "PEN",
            adjustment: .none,
            converter: IdentityConverter()
        )
    }

    private func tx(_ amount: Double, on day: Date, category: YalaCategory? = nil) -> TransactionItem {
        TransactionItem(date: day, amount: amount, currencyCode: "PEN", category: category)
    }

    private func payment(_ amount: Double, due: Date, isIncome: Bool = false) -> ScheduledPayment {
        let sp = ScheduledPayment(
            name: "Alquiler",
            amount: amount,
            currencyCode: "PEN",
            transactionType: isIncome ? "income" : "expense",
            isRecurring: true,
            recurrenceType: "monthly",
            recurrenceInterval: 1,
            nextDueDate: due,
            paymentCategory: "recurring",
            isActive: true
        )
        sp.createdAt = date(2026, 1, 1)
        return sp
    }

    @Test func builder_drawsAPaymentOnItsDay_andAnOverdueOneTomorrow_unlessItWasPaid() {
        let ahead = payment(800, due: date(2026, 11, 20))
        let overdue = payment(50, due: date(2026, 11, 3))
        let paidOverdue = payment(70, due: date(2026, 11, 4))
        let paidTx = tx(-70, on: date(2026, 11, 4, hour: 9))
        paidTx.scheduledPaymentID = paidOverdue.id.uuidString
        let lastPaid = payment(90, due: date(2026, 11, 5))
        lastPaid.lastPaidDate = date(2026, 11, 5)

        let built = ProjectedFlowBuilder.build(
            inputs(transactions: [paidTx], payments: [ahead, overdue, paidOverdue, lastPaid]), context: nil
        )
        #expect(built.flows[date(2026, 11, 20)]?.expense == 800)
        #expect(built.flows[date(2026, 11, 7)]?.expense == 50, "Vencido sin registrar: sigue pendiente, se dibuja mañana")
    }

    /// Un alquiler del 20 pagado el 5: pagar avanza la próxima fecha al 20 de diciembre, y la ocurrencia del 20 de
    /// noviembre ya está en la curva real. Sin la frontera de `nextDueDate` se contaba dos veces (review del 2026-11-06).
    @Test func builder_aPaymentPaidAhead_isNotDrawnAgain() {
        let rent = payment(1_000, due: date(2026, 11, 20))
        rent.nextDueDate = date(2026, 12, 20)
        rent.lastPaidDate = date(2026, 11, 5)
        let built = ProjectedFlowBuilder.build(inputs(transactions: [], payments: [rent]), context: nil)
        #expect(built.flows[date(2026, 11, 20)] == nil)
    }

    /// Un pago de grupo se guarda por el importe entero y la curva cuenta «mi parte»: no se proyecta.
    @Test func builder_groupPayments_stayOut() {
        let shared = payment(300, due: date(2026, 11, 20))
        shared.groupZoneID = "zona"
        let built = ProjectedFlowBuilder.build(inputs(transactions: [], payments: [shared]), context: nil)
        #expect(built.flows[date(2026, 11, 20)] == nil)
    }

    @Test func overdueWindow_isTheCurrentMonth_whateverThePeriod() {
        #expect(ProjectedFlowBuilder.overdueWindowStart(today: today, calendar: calendar) == date(2026, 11, 1))
    }

    @Test func builder_futureDatedMovementsEnterOnTheirDay() {
        let groceries = YalaCategory(name: "Comida", colorHex: "#000", isIncome: false)
        let built = ProjectedFlowBuilder.build(
            inputs(transactions: [tx(-45, on: date(2026, 11, 15, hour: 10), category: groceries)]), context: nil
        )
        #expect(built.flows[date(2026, 11, 15)]?.expense == 45)
        #expect(built.expenseSource == .scheduledOnly, "Sin historia no hay ritmo")
    }

    /// El fixture de paridad de `ingreso-gasto.md`: un movimiento sin categoría de cada signo y uno de signo contrario a
    /// su categoría (una devolución). Con la regla del signo el ritmo daría otra cifra.
    @Test func builder_rhythm_followsTheIncomeExpenseRule_andSkipsPaymentLinkedRows() {
        let groceries = YalaCategory(name: "Comida", colorHex: "#000", isIncome: false)
        let salary = YalaCategory(name: "Sueldo", colorHex: "#000", isIncome: true)
        let start = date(2026, 10, 7, hour: 12)   // 30 días de historia
        let linked = tx(-1_000, on: date(2026, 10, 20), category: groceries)
        linked.scheduledPaymentID = UUID().uuidString
        let history = [
            tx(-300, on: start, category: groceries),
            tx(60, on: date(2026, 10, 12), category: groceries),     // devolución: resta del gasto
            tx(-90, on: date(2026, 10, 14)),                         // sin categoría y negativo: gasto
            tx(900, on: date(2026, 10, 30), category: salary),
            tx(30, on: date(2026, 11, 2)),                           // sin categoría y positivo: ingreso
            linked,
        ]
        let built = ProjectedFlowBuilder.build(inputs(transactions: history), context: nil)
        let day = date(2026, 11, 7)
        #expect(built.expenseSource == .rhythm)
        #expect(abs((built.flows[day]?.expense ?? 0) - 11) < 0.0001, "(300 − 60 + 90) / 30")
        #expect(abs((built.flows[day]?.income ?? 0) - 31) < 0.0001, "(900 + 30) / 30")
    }

    @Test func builder_balanceSource_prefersPlanThenRhythm() {
        let result = ProjectedFlowBuilder.Result(flows: [:], incomeSource: .rhythm, expenseSource: .plan, isApproximate: false)
        #expect(result.source(for: .balance) == .plan)
        #expect(result.source(for: .income) == .rhythm)
        let none = ProjectedFlowBuilder.Result(flows: [:], incomeSource: .scheduledOnly, expenseSource: .scheduledOnly,
                                               isApproximate: false)
        #expect(none.source(for: .balance) == .scheduledOnly)
    }

    @Test func filtersNarrowData_ignoresTheMetricChip() {
        var criteria = FilterCriteria()
        criteria.selectedTransactionNatures = [.expense]
        #expect(!ProjectedFlowBuilder.filtersNarrowData(criteria), "El chip de gastos elige la métrica, no acota datos")
        criteria.searchText = "uber"
        #expect(ProjectedFlowBuilder.filtersNarrowData(criteria))
    }

    @Test func chartProjection_balanceAnchorsOnTheLiveBalance() {
        let days = [date(2026, 11, 7)]
        let result = ProjectedFlowBuilder.Result(
            flows: [date(2026, 11, 7): .init(income: 0, expense: 25)],
            incomeSource: .rhythm, expenseSource: .rhythm, isApproximate: true
        )
        let projection = ProjectedFlowBuilder.chartProjection(
            metric: .balance, grouping: .day,
            realPoints: [BarPoint(date: date(2026, 11, 6), value: 999)],
            liveAnchorValue: 1_000, result: result, days: days, today: today, calendar: calendar
        )
        #expect(projection?.points.map(\.value) == [1_000, 975])
        #expect(projection?.closingValue == 975)
        #expect(projection?.isApproximate == true)
        #expect(ProjectedFlowBuilder.chartProjection(
            metric: .balance, grouping: .day, realPoints: [], liveAnchorValue: nil, result: result, days: [],
            today: today, calendar: calendar
        ) == nil)
    }
}

/// El plan de flujo de caja lee el reloj por dentro (`CashFlowProjectionCalculator.calculate` usa `Date.now`), así que
/// este caso usa el «hoy» real y solo mira el mes que viene, que siempre está entero por delante.
@MainActor
@Suite(.serialized)
struct ProjectedFlowBuilderPlanTests {

    @Test func plan_aManualLineSpreadsItsMonthAmongTheDaysOfTheMonth() throws {
        let context = try makeTestContext()
        let plan = CashFlowPlan(name: "Plan")
        context.insert(plan)
        let line = CashFlowLine(name: "Gastos", isIncome: false, estimationMethod: .manual, manualAmount: 600)
        line.plan = plan
        context.insert(line)
        try context.save()

        let calendar = Calendar.current
        let now = Date.now
        let nextMonth = try #require(calendar.date(byAdding: .month, value: 1, to: now))
        let nextMonthInterval = try #require(calendar.dateInterval(of: .month, for: nextMonth))
        let horizon = DateInterval(start: nextMonthInterval.start, end: nextMonthInterval.end.addingTimeInterval(-1))
        let days = ProjectedFlowCalculator.futureDays(in: horizon, today: now, calendar: calendar)
            .filter { $0 >= nextMonthInterval.start }

        let built = ProjectedFlowBuilder.build(
            ProjectedFlowBuilder.Inputs(
                today: now, calendar: calendar, overdueWindowStart: now, days: days,
                allTransactions: [], countedTransactions: [], hasSessionFilters: false,
                scheduledPayments: [], paymentFilter: .none, currencyCode: "PEN", adjustment: .none,
                converter: CurrencyConverter.shared
            ),
            context: context
        )
        #expect(built.expenseSource == .plan)
        #expect(built.incomeSource == .scheduledOnly, "Sin líneas de ingreso ni historia, el ingreso no se estima")
        let total = days.reduce(0.0) { $0 + (built.flows[$1]?.expense ?? 0) }
        #expect(abs(total - 600) < 0.001, "El mes entero por delante lleva su plan entero")

        let filtered = ProjectedFlowBuilder.build(
            ProjectedFlowBuilder.Inputs(
                today: now, calendar: calendar, overdueWindowStart: now, days: days,
                allTransactions: [], countedTransactions: [], hasSessionFilters: true,
                scheduledPayments: [], paymentFilter: .none, currencyCode: "PEN", adjustment: .none,
                converter: CurrencyConverter.shared
            ),
            context: context
        )
        #expect(filtered.expenseSource == .scheduledOnly, "Con filtros manda el ritmo (10A); sin historia, nada")
    }
}
