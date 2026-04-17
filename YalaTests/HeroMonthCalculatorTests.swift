//
//  HeroMonthCalculatorTests.swift
//  YalaTests
//
//  Contract covered:
//   • `daysElapsed <= 7` → `.monthStart` regardless of spending.
//   • No monthly budget (`totalMonthlyBudget == 0`) → `.neutral` fallback.
//   • Ratio ≥ 1.0 → `.overBudget`; ≥ 0.8 → `.tight`.
//   • Below 0.8, compare vs projection (`daysElapsed / daysTotal`):
//     diff < -0.10 → `.onTrack`; diff > +0.10 → `.tight`; else `.neutral`.
//   • Day convention: first day of month → daysElapsed == 1,
//     last day of month → daysRemaining == 0.
//

import Foundation
import Testing

@testable import Yala

struct HeroMonthCalculatorTests {

    // MARK: - Fixtures

    private let calendar: Calendar = Calendar.current

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    // MARK: - State: .monthStart

    @Test func day1_empty_returnsMonthStart() {
        let data = HeroMonthCalculator.calculate(
            monthIncome: 0,
            monthExpense: 0,
            totalMonthlyBudget: 0,
            now: date(2026, 4, 1),
            calendar: calendar
        )
        #expect(data.state == .monthStart)
        #expect(data.daysElapsed == 1)
    }

    @Test func day7_boundary_stillMonthStart() {
        let data = HeroMonthCalculator.calculate(
            monthIncome: 0,
            monthExpense: 800,
            totalMonthlyBudget: 1000,
            now: date(2026, 4, 7),
            calendar: calendar
        )
        // Even at 80% spent, day ≤ 7 forces monthStart (too early to judge).
        #expect(data.state == .monthStart)
    }

    // MARK: - State: fallbacks without budget

    @Test func day8_noBudget_returnsNeutral() {
        let data = HeroMonthCalculator.calculate(
            monthIncome: 0,
            monthExpense: 500,
            totalMonthlyBudget: 0,
            now: date(2026, 4, 8),
            calendar: calendar
        )
        #expect(data.state == .neutral)
    }

    @Test func day25_zeroBudget_returnsNeutral() {
        let data = HeroMonthCalculator.calculate(
            monthIncome: 0,
            monthExpense: 9000,
            totalMonthlyBudget: 0,
            now: date(2026, 4, 25),
            calendar: calendar
        )
        #expect(data.state == .neutral)
    }

    // MARK: - State: projection-based

    @Test func day10_budgetAt10Pct_whenExpected33Pct_returnsOnTrack() {
        // April has 30 days. Day 10 → expected = 10/30 ≈ 0.333.
        // ratio = 100 / 1000 = 0.10 → diff = -0.233 < -0.10 → onTrack.
        let data = HeroMonthCalculator.calculate(
            monthIncome: 0,
            monthExpense: 100,
            totalMonthlyBudget: 1000,
            now: date(2026, 4, 10),
            calendar: calendar
        )
        #expect(data.state == .onTrack)
    }

    @Test func day10_budgetAt40Pct_whenExpected33Pct_returnsNeutral() {
        // ratio = 0.40, expected ≈ 0.333, diff ≈ 0.066 (inside ±0.10) → neutral.
        let data = HeroMonthCalculator.calculate(
            monthIncome: 0,
            monthExpense: 400,
            totalMonthlyBudget: 1000,
            now: date(2026, 4, 10),
            calendar: calendar
        )
        #expect(data.state == .neutral)
    }

    @Test func day15_budgetAt85Pct_returnsTight() {
        // ratio = 0.85 >= tightRatio (0.8) → tight, no matter the projection.
        let data = HeroMonthCalculator.calculate(
            monthIncome: 0,
            monthExpense: 850,
            totalMonthlyBudget: 1000,
            now: date(2026, 4, 15),
            calendar: calendar
        )
        #expect(data.state == .tight)
    }

    @Test func day20_budgetAt110Pct_returnsOverBudget() {
        let data = HeroMonthCalculator.calculate(
            monthIncome: 0,
            monthExpense: 1100,
            totalMonthlyBudget: 1000,
            now: date(2026, 4, 20),
            calendar: calendar
        )
        #expect(data.state == .overBudget)
    }

    @Test func day20_budgetAt50Pct_whenExpected66Pct_returnsOnTrack() {
        // April day 20 → expected = 20/30 ≈ 0.666.
        // ratio = 0.50, diff = -0.166 < -0.10 → onTrack.
        let data = HeroMonthCalculator.calculate(
            monthIncome: 0,
            monthExpense: 500,
            totalMonthlyBudget: 1000,
            now: date(2026, 4, 20),
            calendar: calendar
        )
        #expect(data.state == .onTrack)
    }

    @Test func day15_budgetRatioEqualsExpectedPlusToleranceEdge_returnsNeutral() {
        // April day 15 → expected = 15/30 = 0.5.
        // ratio = 0.6, diff = 0.1, NOT > 0.10 (strict) → neutral edge.
        let data = HeroMonthCalculator.calculate(
            monthIncome: 0,
            monthExpense: 600,
            totalMonthlyBudget: 1000,
            now: date(2026, 4, 15),
            calendar: calendar
        )
        #expect(data.state == .neutral)
    }

    // MARK: - Day convention

    @Test func daysElapsed_firstDayOfMonth_returnsOne() {
        let data = HeroMonthCalculator.calculate(
            monthIncome: 0, monthExpense: 0, totalMonthlyBudget: 0,
            now: date(2026, 4, 1), calendar: calendar
        )
        #expect(data.daysElapsed == 1)
    }

    @Test func daysRemaining_firstDayOf31DayMonth_returns30() {
        // March has 31 days. Day 1 → 30 days remaining.
        let data = HeroMonthCalculator.calculate(
            monthIncome: 0, monthExpense: 0, totalMonthlyBudget: 0,
            now: date(2026, 3, 1), calendar: calendar
        )
        #expect(data.daysRemaining == 30)
        #expect(data.daysElapsed == 1)
    }

    @Test func daysRemaining_lastDayOfMonth_returnsZero() {
        // April 30 → last day, 0 days remaining.
        let data = HeroMonthCalculator.calculate(
            monthIncome: 0, monthExpense: 0, totalMonthlyBudget: 0,
            now: date(2026, 4, 30), calendar: calendar
        )
        #expect(data.daysRemaining == 0)
        #expect(data.daysElapsed == 30)
    }

    @Test func daysRemaining_februaryNonLeap_returns28Total() {
        // 2026 is not a leap year — February has 28 days.
        let data = HeroMonthCalculator.calculate(
            monthIncome: 0, monthExpense: 0, totalMonthlyBudget: 0,
            now: date(2026, 2, 1), calendar: calendar
        )
        #expect(data.daysElapsed == 1)
        #expect(data.daysRemaining == 27)
    }

    @Test func daysRemaining_februaryLeapYear_returns29Total() {
        // 2028 is a leap year — February has 29 days.
        let data = HeroMonthCalculator.calculate(
            monthIncome: 0, monthExpense: 0, totalMonthlyBudget: 0,
            now: date(2028, 2, 1), calendar: calendar
        )
        #expect(data.daysElapsed == 1)
        #expect(data.daysRemaining == 28)
    }

    // MARK: - Data propagation

    @Test func dataContainsRawIncomeAndExpense() {
        let data = HeroMonthCalculator.calculate(
            monthIncome: 3200.50,
            monthExpense: 1875.25,
            totalMonthlyBudget: 0,
            now: date(2026, 4, 15),
            calendar: calendar
        )
        #expect(data.income == 3200.50)
        #expect(data.expense == 1875.25)
    }

    // MARK: - Derived KPIs (P20-04b)

    @Test func derived_available_equalsMaxZeroIncomeMinusExpense() {
        // income > expense → income - expense
        let positive = HeroMonthCalculator.calculate(
            monthIncome: 3000, monthExpense: 1200, totalMonthlyBudget: 0,
            now: date(2026, 4, 15), calendar: calendar
        )
        #expect(positive.available == 1800)

        // income < expense → clamped to 0 (never negative on the hero)
        let negative = HeroMonthCalculator.calculate(
            monthIncome: 500, monthExpense: 2000, totalMonthlyBudget: 0,
            now: date(2026, 4, 15), calendar: calendar
        )
        #expect(negative.available == 0)
    }

    @Test func derived_dailyAverage_dividesByElapsedClampedToOne() {
        // April day 10 → daysElapsed = 10. 1500 / 10 = 150.
        let data = HeroMonthCalculator.calculate(
            monthIncome: 0, monthExpense: 1500, totalMonthlyBudget: 0,
            now: date(2026, 4, 10), calendar: calendar
        )
        #expect(data.dailyAverage == 150)

        // Day 1 with no expense yet → average is 0, never a div-by-zero crash.
        let day1 = HeroMonthCalculator.calculate(
            monthIncome: 0, monthExpense: 0, totalMonthlyBudget: 0,
            now: date(2026, 4, 1), calendar: calendar
        )
        #expect(day1.dailyAverage == 0)
    }

    @Test func derived_projection_scalesDailyAverageToMonthTotal() {
        // April has 30 days; day 10, spent 1500 → avg 150 → projection 4500.
        let data = HeroMonthCalculator.calculate(
            monthIncome: 0, monthExpense: 1500, totalMonthlyBudget: 0,
            now: date(2026, 4, 10), calendar: calendar
        )
        #expect(data.daysTotal == 30)
        #expect(data.projection == 4500)
    }
}
