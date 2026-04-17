//
//  HeroMonthCalculator.swift
//  Yala
//
//  Pure state calculator for the Panel 2.0 "Hero del mes" card.
//
//  Design choices:
//  - Pure enum (no @MainActor, no singletons): the VM does the sum + currency
//    conversion where it has CurrencyConverter injected; the calculator only
//    classifies and packages. Tests run with zero mocks.
//  - Always measures the current calendar month; the Panel period selector
//    does not change the hero (same contract as FinancialScoreCalculator).
//  - Budget ratio uses only the sum of MONTHLY budgets. Weekly/yearly budgets
//    are ignored here — mixing periodicities would poison the ratio. If UX
//    feedback asks for it later, we can pro-rate weekly × 4.33 and yearly ÷ 12.
//  - Day convention (fixed by tests): first day of month → daysElapsed == 1,
//    last day of month → daysRemaining == 0.
//

import Foundation

// MARK: - Public model

enum HeroMonthState: Equatable {
    case monthStart
    case onTrack
    case neutral
    case tight
    case overBudget
}

struct HeroMonthData: Equatable {
    let state: HeroMonthState
    let income: Double
    let expense: Double
    let daysRemaining: Int
    let daysElapsed: Int
}

// MARK: - Calculator

enum HeroMonthCalculator {

    /// Threshold (in calendar days) below which the month is classified as
    /// `.monthStart` regardless of spending — the first week of a month is
    /// not a reliable signal to encourage or warn yet.
    static let monthStartDayThreshold = 7

    /// Budget ratio at or above which we flag `.tight`.
    static let tightRatio = 0.8

    /// Budget ratio at or above which we flag `.overBudget`.
    static let overBudgetRatio = 1.0

    /// How far from the expected projection (`daysElapsed / daysTotal`) the
    /// actual ratio must diverge to exit `.neutral` into `.onTrack` or `.tight`.
    static let projectionTolerance = 0.10

    /// Classifies the current calendar month and packages the values the view
    /// needs. `totalMonthlyBudget == 0` means "no monthly budgets available"
    /// and falls back to `.neutral` (we don't have a projection to compare to).
    static func calculate(
        monthIncome: Double,
        monthExpense: Double,
        totalMonthlyBudget: Double,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> HeroMonthData {
        let (daysElapsed, daysTotal) = dayContext(now: now, calendar: calendar)
        let daysRemaining = max(0, daysTotal - daysElapsed)

        let state = classify(
            daysElapsed: daysElapsed,
            daysTotal: daysTotal,
            monthExpense: monthExpense,
            totalMonthlyBudget: totalMonthlyBudget
        )

        return HeroMonthData(
            state: state,
            income: monthIncome,
            expense: monthExpense,
            daysRemaining: daysRemaining,
            daysElapsed: daysElapsed
        )
    }

    // MARK: - Helpers

    private static func dayContext(now: Date, calendar: Calendar) -> (elapsed: Int, total: Int) {
        guard let monthInterval = calendar.dateInterval(of: .month, for: now) else {
            return (1, 30)
        }
        let startDay = calendar.startOfDay(for: monthInterval.start)
        let today = calendar.startOfDay(for: now)
        let elapsedRaw = calendar.dateComponents([.day], from: startDay, to: today).day ?? 0
        let elapsed = max(1, elapsedRaw + 1)

        // `dateInterval(of: .month, ...).end` is the first moment of the next
        // month. The component diff therefore equals the month's day count.
        let total = calendar.dateComponents([.day], from: monthInterval.start, to: monthInterval.end).day ?? 30
        return (elapsed, max(total, elapsed))
    }

    private static func classify(
        daysElapsed: Int,
        daysTotal: Int,
        monthExpense: Double,
        totalMonthlyBudget: Double
    ) -> HeroMonthState {
        if daysElapsed <= monthStartDayThreshold { return .monthStart }
        guard totalMonthlyBudget > 0 else { return .neutral }

        let ratio = monthExpense / totalMonthlyBudget
        if ratio >= overBudgetRatio { return .overBudget }
        if ratio >= tightRatio { return .tight }

        let expected = Double(daysElapsed) / Double(max(daysTotal, 1))
        let diff = ratio - expected
        if diff < -projectionTolerance { return .onTrack }
        if diff >  projectionTolerance { return .tight }
        return .neutral
    }
}
