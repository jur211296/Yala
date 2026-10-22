//
//  TrendInsightLogicTests.swift
//  YalaTests
//
//  Pure-logic tests para TrendInsightLogic.finding(metric:currentTotal:previousTotal:).
//  Sin SwiftData, sin UI, sin singletons. Cubre los 3 ramos (ONSET / STABILITY /
//  VARIATION) + edge cases (zero previous, negative balance, threshold exacto).
//

import Foundation
import Testing

@testable import Yala

@MainActor
struct TrendInsightLogicTests {

    @Test func finding_nilPrevious_returnsOnset() {
        let result = TrendInsightLogic.finding(
            metric: .expense, currentTotal: 100, previousTotal: nil
        )
        #expect(result == .onset)
    }

    @Test func finding_zeroPrevious_returnsStable() {
        // Edge case: división por cero — sin variation calculable, defaults a stable.
        let result = TrendInsightLogic.finding(
            metric: .expense, currentTotal: 100, previousTotal: 0
        )
        #expect(result == .stable(metric: .expense))
    }

    @Test func finding_variationUnder5Percent_returnsStable() {
        // 102 vs 100 → 2% < 5% threshold → stable.
        let result = TrendInsightLogic.finding(
            metric: .income, currentTotal: 102, previousTotal: 100
        )
        #expect(result == .stable(metric: .income))
    }

    @Test func finding_variationUp10Percent_returnsVariationUp() {
        let result = TrendInsightLogic.finding(
            metric: .expense, currentTotal: 110, previousTotal: 100
        )
        #expect(result == .variationUp(percent: 10, metric: .expense))
    }

    @Test func finding_variationDown15Percent_returnsVariationDown() {
        let result = TrendInsightLogic.finding(
            metric: .expense, currentTotal: 85, previousTotal: 100
        )
        #expect(result == .variationDown(percent: 15, metric: .expense))
    }

    @Test func finding_negativePrevious_handlesCorrectly() {
        // Balance negativo que mejora: -200 → -100. (-100 - (-200)) / 200 = +0.5 → +50%.
        let result = TrendInsightLogic.finding(
            metric: .balance, currentTotal: -100, previousTotal: -200
        )
        #expect(result == .variationUp(percent: 50, metric: .balance))
    }

    @Test func finding_exactly5Percent_returnsVariationUp() {
        // Threshold exacto: |variation| == 0.05 NO < 0.05 → entra a variation, no stable.
        let result = TrendInsightLogic.finding(
            metric: .income, currentTotal: 105, previousTotal: 100
        )
        #expect(result == .variationUp(percent: 5, metric: .income))
    }
}

// MARK: - V2 (trends-insight-card-v2-bullets)

private func point(_ income: Double, _ expense: Double, _ index: Int = 0) -> TrendHistoryPoint {
    TrendHistoryPoint(start: Date(timeIntervalSince1970: Double(index) * 86_400 * 31), income: income, expense: expense)
}

private func expenses(_ values: [Double]) -> [TrendHistoryPoint] {
    values.enumerated().map { point(0, $0.element, $0.offset) }
}

private func cashFlow(income: Double, expense: Double) -> CashFlowSummary {
    CashFlowSummary(
        totalIncome: income,
        totalExpense: expense,
        netFlow: income - expense,
        chartData: [],
        currencyCode: "PEN",
        incomeAmountsAreApproximate: false,
        expenseAmountsAreApproximate: false,
        amountsAreApproximate: false
    )
}

private func weekdays(_ averages: [Int: Double]) -> [WeekdaySpending] {
    (1...7).map { day in
        let avg = averages[day] ?? 0
        return WeekdaySpending(weekday: day, total: avg * 4, count: avg > 0 ? 4 : 0, dayOccurrences: 4)
    }
}

@MainActor
struct TrendInsightTrendRuleTests {

    @Test func expense_threeRisesInARow_isSustainedUp() {
        let result = TrendInsightLogic.findingForTrend(
            metric: .expense, history: expenses([100, 110, 121, 133]), unit: .months
        )
        #expect(result == .sustainedUp(periods: 3, unit: .months, metric: .expense))
    }

    @Test func expense_twoRises_isNotEnough() {
        // Mínimo de racha = 3: dos subidas seguidas no son tendencia sostenida.
        let result = TrendInsightLogic.findingForTrend(
            metric: .expense, history: expenses([100, 100, 110, 121]), unit: .months
        )
        #expect(result == nil)
    }

    @Test func expense_streakCountsOnlyFromTheMostRecentPeriod() {
        // Racha vieja de 4 bajadas, cortada por una subida al final: no hay racha vigente.
        let result = TrendInsightLogic.findingForTrend(
            metric: .expense, history: expenses([200, 180, 160, 140, 120, 150]), unit: .months
        )
        #expect(result == nil)
    }

    @Test func expense_threeFallsInARow_isSustainedDown() {
        let result = TrendInsightLogic.findingForTrend(
            metric: .expense, history: expenses([200, 180, 160, 140]), unit: .weeks
        )
        #expect(result == .sustainedDown(periods: 3, unit: .weeks, metric: .expense))
    }

    @Test func expense_aStableStep_breaksTheStreak() {
        // 133 → 135 es +1,5 %, por debajo del 5 %: corta la racha.
        let result = TrendInsightLogic.findingForTrend(
            metric: .expense, history: expenses([100, 110, 121, 133, 135]), unit: .months
        )
        #expect(result == nil)
    }

    @Test func expense_aStepFromZero_breaksTheStreak() {
        // Un período sin gasto no da porcentaje: la racha empieza después.
        let result = TrendInsightLogic.findingForTrend(
            metric: .expense, history: expenses([0, 100, 110, 121]), unit: .months
        )
        #expect(result == nil)
    }

    @Test func expense_exactlyFivePercentSteps_count() {
        // Umbral inclusivo, como en `finding`: 5 % exacto es variación, no estabilidad.
        let result = TrendInsightLogic.findingForTrend(
            metric: .expense, history: expenses([1000, 1050, 1102.5, 1157.625]), unit: .months
        )
        #expect(result == .sustainedUp(periods: 3, unit: .months, metric: .expense))
    }

    @Test func income_readsTheIncomeSeries_notTheExpenseOne() {
        let history = [point(100, 500, 0), point(110, 400, 1), point(121, 300, 2), point(133, 200, 3)]
        #expect(TrendInsightLogic.findingForTrend(metric: .income, history: history, unit: .months)
            == .sustainedUp(periods: 3, unit: .months, metric: .income))
        #expect(TrendInsightLogic.findingForTrend(metric: .expense, history: history, unit: .months)
            == .sustainedDown(periods: 3, unit: .months, metric: .expense))
    }

    @Test func balance_threePositiveNetsInARow_isSustainedUp() {
        let history = [point(100, 200, 0), point(300, 100, 1), point(300, 200, 2), point(250, 100, 3)]
        #expect(TrendInsightLogic.findingForTrend(metric: .balance, history: history, unit: .months)
            == .sustainedUp(periods: 3, unit: .months, metric: .balance))
    }

    @Test func balance_negativeNets_isSustainedDown() {
        let history = [point(100, 200, 0), point(100, 300, 1), point(50, 300, 2)]
        #expect(TrendInsightLogic.findingForTrend(metric: .balance, history: history, unit: .years)
            == .sustainedDown(periods: 3, unit: .years, metric: .balance))
    }

    @Test func balance_zeroNet_breaksTheStreak() {
        let history = [point(300, 100, 0), point(300, 100, 1), point(100, 100, 2), point(300, 100, 3)]
        #expect(TrendInsightLogic.findingForTrend(metric: .balance, history: history, unit: .months) == nil)
    }

    @Test func withoutUnit_thereIsNoTrendBullet() {
        // Últimos 30 días / Todo el tiempo / Personalizado: no hay palabra exacta para la racha.
        #expect(TrendInsightLogic.findingForTrend(
            metric: .expense, history: expenses([100, 110, 121, 133]), unit: nil
        ) == nil)
    }
}

@MainActor
struct TrendInsightCashFlowAndWeekdayTests {

    @Test func cashFlow_surplus_reportsCoverage() {
        #expect(TrendInsightLogic.findingForCashFlow(summary: cashFlow(income: 1500, expense: 1000))
            == .cashFlowSurplus(ratio: 150))
    }

    @Test func cashFlow_deficit_reportsCoverage() {
        #expect(TrendInsightLogic.findingForCashFlow(summary: cashFlow(income: 600, expense: 1000))
            == .cashFlowDeficit(ratio: 60))
    }

    @Test func cashFlow_smallDeficit_neverSaysOneHundredPercent() {
        // 996 de 1000 redondea a 100: en déficit se trunca para no decir «cubrieron el 100 %».
        #expect(TrendInsightLogic.findingForCashFlow(summary: cashFlow(income: 996, expense: 1000))
            == .cashFlowDeficit(ratio: 99))
        #expect(TrendInsightLogic.findingForCashFlow(summary: cashFlow(income: 999.9, expense: 1000))
            == .cashFlowDeficit(ratio: 99))
    }

    @Test func cashFlow_breakEven_isSurplus() {
        #expect(TrendInsightLogic.findingForCashFlow(summary: cashFlow(income: 1000, expense: 1000))
            == .cashFlowSurplus(ratio: 100))
    }

    @Test func cashFlow_noExpense_hasNoBullet() {
        #expect(TrendInsightLogic.findingForCashFlow(summary: cashFlow(income: 1000, expense: 0)) == nil)
    }

    @Test func cashFlow_expenseWithoutIncome_hasItsOwnCase() {
        // Sin ingresos el «0 %» no dice nada: tiene frase propia.
        #expect(TrendInsightLogic.findingForCashFlow(summary: cashFlow(income: 0, expense: 1000))
            == .cashFlowNoIncome)
    }

    @Test func weekday_picksTheHighestAverage() {
        let result = TrendInsightLogic.findingForWeekday(
            spending: weekdays([2: 100, 7: 682.75, 1: 333]), currencyCode: "PEN"
        )
        #expect(result == .weekdayPeak(weekday: 7, average: 682.75, currencyCode: "PEN"))
    }

    @Test func weekday_noSpending_hasNoBullet() {
        #expect(TrendInsightLogic.findingForWeekday(spending: weekdays([:]), currencyCode: "PEN") == nil)
        #expect(TrendInsightLogic.findingForWeekday(spending: [], currencyCode: "PEN") == nil)
    }
}

@MainActor
struct TrendInsightBulletsTests {

    private func bullets(
        metric: TrendMetric = .expense,
        previous: Double? = 100,
        comparable: Bool = true,
        history: [TrendHistoryPoint] = [],
        unit: TrendHistoryUnit? = .months,
        cashFlow summary: CashFlowSummary? = cashFlow(income: 1500, expense: 1000),
        weekday: [WeekdaySpending] = weekdays([7: 50])
    ) -> [TrendInsightBullet] {
        TrendInsightLogic.bullets(
            metric: metric,
            currentTotal: 110,
            previousTotal: previous,
            comparisonAvailable: comparable,
            history: history,
            historyUnit: unit,
            cashFlowSummary: summary,
            weekdaySpending: weekday,
            currencyCode: "PEN"
        )
    }

    @Test func allFourCharts_produceFourBulletsInChartOrder() {
        // V2-01: tendencia, comparativa, flujo, día — en el orden de las gráficas.
        let result = bullets(history: expenses([100, 110, 121, 133]))
        #expect(result.map(\.id) == [.trend, .comparison, .cashFlow, .weekday])
        #expect(result[1].finding == .variationUp(percent: 10, metric: .expense))
    }

    @Test func allTime_dropsTheComparisonBullet() {
        // V2-02: en Todo el tiempo no hay gráfica de Comparativa, ni su bullet.
        let result = bullets(previous: nil, comparable: false)
        #expect(result.map(\.id) == [.cashFlow, .weekday])
    }

    @Test func comparablePeriodWithoutHistory_isOnset() {
        let result = bullets(previous: nil)
        #expect(result.first { $0.id == .comparison }?.finding == .onset)
    }

    @Test func withoutData_chartsAreOmitted() {
        let result = bullets(cashFlow: nil, weekday: [])
        #expect(result.map(\.id) == [.comparison])
    }

    @Test func neverMoreThanFour() {
        let result = bullets(history: expenses([100, 110, 121, 133, 146]))
        #expect(result.count == 4)
        #expect(Set(result.map(\.id)).count == 4)
    }
}
