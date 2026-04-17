//
//  FinancialScoreCalculator.swift
//  Yala
//
//  Financial Score for the Panel 2.0 "Salud Financiera" section.
//
//  Invariants:
//  - Sub-scores are `Int?`. `nil` means "N/A" and does NOT dilute the total;
//    the remaining sub-scores are re-weighted proportionally. If all three
//    are `nil`, the total is also `nil`.
//  - Activity is `nil` only when the user has never registered a transaction.
//    With any history, 0 is a valid signal ("no activity in the last 7 days").
//  - Bills skips occurrences marked paid (`paidAmounts`) or skipped
//    (`isDateSkipped`) so the responsible user is never punished. `paidAmounts`
//    is injected so a single `ScheduledPaymentPaidStatusHelper` fetch is
//    shared with `.planificacion` when both sections target the same month.
//  - Brand-voice guardrail: the composite total is clamped to a soft floor
//    of 50. Sub-scores are not floored — their detail sheet speaks to the
//    real value.
//  - Always measures the current calendar month; the Panel period selector
//    does not change this score.
//

import Foundation

struct FinancialScore: Equatable {
    /// Composite score (0–100) or `nil` when every sub-score is `nil`.
    let total: Int?

    /// Budget sub-score (0–100) or `nil` when the user has no active budgets.
    let budget: Int?

    /// Activity sub-score (0–100) or `nil` when the user has never registered
    /// a transaction.
    let activity: Int?

    /// Bills sub-score (0–100) or `nil` when the user has no active scheduled
    /// payments.
    let bills: Int?
}

@MainActor
enum FinancialScoreCalculator {

    // MARK: - Tuning

    /// Soft floor for the total score so we never show a deeply discouraging
    /// number. Realistic scenarios stay well above this; the floor only bites
    /// in extreme compound cases (many exceeded budgets + several overdue bills).
    private static let totalSoftFloor = 50

    // Budget penalties (softer than raw: realistic scenarios stay ≥ 70).
    private static let budgetPenaltyExceeded     = 8
    private static let budgetPenaltyNearAndLate  = 3
    private static let budgetBonusUnder75        = 2
    private static let budgetBonusCap            = 10

    // Bills penalties (softer than raw).
    private static let billsPenaltyOverdue       = 5
    private static let billsPenaltyUpcoming      = 3

    // MARK: - Public API

    /// Computes the composite financial score for the current calendar month.
    ///
    /// - Parameters:
    ///   - transactions: All transactions loaded by `PanelViewModel`.
    ///   - budgets: Active budgets (already filtered by `isActive` at fetch time).
    ///   - scheduledPayments: All scheduled payments — filtered by `isActive` here.
    ///   - paidAmounts: Map `[paymentID: [PaidOccurrenceInfo]]` from
    ///     `ScheduledPaymentPaidStatusHelper.loadPaidAmounts` for the current month.
    ///   - now: Reference date (defaults to `.now`, injected for tests).
    ///   - calendar: Calendar used for month/day boundaries.
    static func calculate(
        transactions: [TransactionItem],
        budgets: [Budget],
        scheduledPayments: [ScheduledPayment],
        paidAmounts: [String: [PaidOccurrenceInfo]],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> FinancialScore {
        // Compute the month interval once and reuse it across sub-scores.
        let monthInterval = calendar.dateInterval(of: .month, for: now)
        let monthTransactions: [TransactionItem]
        if let monthInterval {
            monthTransactions = transactions.filter { monthInterval.contains($0.date) }
        } else {
            monthTransactions = transactions
        }

        let budget = calculateBudget(
            budgets: budgets,
            monthTransactions: monthTransactions,
            monthInterval: monthInterval,
            now: now,
            calendar: calendar
        )
        let activity = calculateActivity(
            transactions: transactions,
            now: now,
            calendar: calendar
        )
        let bills = calculateBills(
            scheduledPayments: scheduledPayments,
            paidAmounts: paidAmounts,
            monthInterval: monthInterval,
            now: now,
            calendar: calendar
        )
        let total = computeTotal(budget: budget, activity: activity, bills: bills)

        return FinancialScore(total: total, budget: budget, activity: activity, bills: bills)
    }

    // MARK: - Weighted total with dynamic re-weighting

    /// Weighted average of the sub-scores present. Weights re-normalize when
    /// any sub-score is `nil` (e.g. user without budgets → activity and bills
    /// split 50/50). Returns `nil` if every sub-score is `nil`.
    private static func computeTotal(budget: Int?, activity: Int?, bills: Int?) -> Int? {
        var weightedSum: Double = 0
        var totalWeight: Double = 0

        if let budget {
            weightedSum += Double(budget) * 0.4
            totalWeight += 0.4
        }
        if let activity {
            weightedSum += Double(activity) * 0.3
            totalWeight += 0.3
        }
        if let bills {
            weightedSum += Double(bills) * 0.3
            totalWeight += 0.3
        }

        guard totalWeight > 0 else { return nil }

        let raw = weightedSum / totalWeight
        let floored = max(Double(totalSoftFloor), raw)
        return clamp(Int(floored.rounded()))
    }

    // MARK: - Budget sub-score

    private static func calculateBudget(
        budgets: [Budget],
        monthTransactions: [TransactionItem],
        monthInterval: DateInterval?,
        now: Date,
        calendar: Calendar
    ) -> Int? {
        guard !budgets.isEmpty else { return nil }
        guard let monthInterval else { return 100 }

        let totalDays = calendar.dateComponents([.day], from: monthInterval.start, to: monthInterval.end).day ?? 30
        let daysElapsed = max(0, calendar.dateComponents([.day], from: monthInterval.start, to: now).day ?? 0)
        let daysRemaining = max(0, totalDays - daysElapsed)
        let remainingRatio = Double(daysRemaining) / Double(max(1, totalDays))
        let isSecondHalf = daysElapsed >= totalDays / 2

        var score = 100
        var bonusAccumulated = 0

        for budget in budgets {
            let limit = budget.limitAmount
            guard limit > 0 else { continue }

            let spending = BudgetsViewModel.calculateSpending(
                budget: budget,
                transactions: monthTransactions,
                interval: monthInterval
            )
            let ratio = spending / limit

            if ratio >= 1.0 {
                score -= budgetPenaltyExceeded
            } else if ratio >= 0.9, remainingRatio < 0.3 {
                score -= budgetPenaltyNearAndLate
            } else if ratio < 0.75, isSecondHalf, bonusAccumulated < budgetBonusCap {
                let add = min(budgetBonusUnder75, budgetBonusCap - bonusAccumulated)
                score += add
                bonusAccumulated += add
            }
        }

        return clamp(score)
    }

    // MARK: - Activity sub-score

    private static func calculateActivity(
        transactions: [TransactionItem],
        now: Date,
        calendar: Calendar
    ) -> Int? {
        // No transactions ever → N/A (brand-new user, no data to learn from).
        let nonAdjustment = transactions.filter { $0.balanceAdjustmentType == nil }
        guard !nonAdjustment.isEmpty else { return nil }

        let today = calendar.startOfDay(for: now)
        guard let weekAgo = calendar.date(byAdding: .day, value: -6, to: today) else { return 0 }

        var daysWithTx: Set<Date> = []
        for tx in nonAdjustment {
            let day = calendar.startOfDay(for: tx.date)
            if day >= weekAgo && day <= today {
                daysWithTx.insert(day)
            }
        }

        let score = Double(daysWithTx.count) / 7.0 * 100.0
        return clamp(Int(score.rounded()))
    }

    // MARK: - Bills sub-score

    private static func calculateBills(
        scheduledPayments: [ScheduledPayment],
        paidAmounts: [String: [PaidOccurrenceInfo]],
        monthInterval: DateInterval?,
        now: Date,
        calendar: Calendar
    ) -> Int? {
        let active = scheduledPayments.filter { $0.isActive }
        guard !active.isEmpty else { return nil }
        guard let monthInterval else { return 100 }

        let month = monthInterval.start
        let today = calendar.startOfDay(for: now)
        guard let overdueWindowStart = calendar.date(byAdding: .day, value: -7, to: today),
              let upcomingWindowEnd = calendar.date(byAdding: .day, value: 3, to: today) else {
            return 100
        }

        var score = 100

        for payment in active {
            var paidRemaining = paidAmounts[payment.id.uuidString]?.count ?? 0
            let occurrences = ScheduledPaymentDateCalculator.paymentDatesInMonth(
                params: payment.dateCalculatorParams,
                month: month,
                calendar: calendar
            ).sorted()

            var hasOverdue = false
            var hasUpcoming = false

            for date in occurrences {
                let day = calendar.startOfDay(for: date)

                if payment.isDateSkipped(date) { continue }

                if paidRemaining > 0 {
                    paidRemaining -= 1
                    continue
                }

                if day < today && day >= overdueWindowStart {
                    hasOverdue = true
                } else if day >= today && day <= upcomingWindowEnd {
                    hasUpcoming = true
                }
            }

            if hasOverdue { score -= billsPenaltyOverdue }
            if hasUpcoming { score -= billsPenaltyUpcoming }
        }

        return clamp(score)
    }

    // MARK: - Utilities

    private static func clamp(_ value: Int, min: Int = 0, max: Int = 100) -> Int {
        Swift.max(min, Swift.min(max, value))
    }
}
