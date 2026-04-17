//
//  FinancialScoreCalculatorTests.swift
//  YalaTests
//
//  Contract covered:
//   • Sub-scores are `Int?`. `nil` does not dilute the total — remaining
//     sub-scores are re-weighted. All-nil → total nil.
//   • Total soft floor: 50. Sub-scores unfloored.
//   • Penalties: budget exceeded −8, near+late −3, under-75 bonus +2 (cap +10).
//                bills overdue −5, upcoming −3.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
struct FinancialScoreCalculatorTests {

    // MARK: - Fixtures

    /// Uses the same calendar/timezone as `Calendar.current`, which is what
    /// `ScheduledPayment.isDateSkipped` and `ScheduledPaymentDateCalculator`
    /// consult in production. Fixing to UTC would produce timezone-mismatched
    /// day-keys when the simulator runs in a non-UTC zone (e.g. PDT).
    private let calendar: Calendar = Calendar.current

    /// Reference date: Tuesday, March 17, 2026 12:00.
    /// Day 17 of 31 → second half of the month, 14 days remaining (≈45% remaining).
    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 3, day: 17, hour: 12))!
    }

    /// Late-month reference date: Sunday, March 29, 2026 12:00.
    /// 3 days remaining (~10% of 31) — inside the "≥90% + <30% days remaining" window.
    private var lateMonthNow: Date {
        calendar.date(from: DateComponents(year: 2026, month: 3, day: 29, hour: 12))!
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    // MARK: - Factories

    private func makeBudget(
        limit: Double = 1000,
        name: String = "B",
        periodType: String = "monthly"
    ) -> Budget {
        Budget(
            currencyCode: "USD",
            limitAmount: limit,
            name: name,
            periodType: periodType
        )
    }

    private func makeTx(
        amount: Double,
        date: Date,
        category: YalaCategory? = nil,
        balanceAdjustmentType: String? = nil
    ) -> TransactionItem {
        let cat = category ?? YalaCategory(name: "Food", colorHex: "#FF0000", isIncome: false)
        let tx = TransactionItem(
            date: date,
            amount: amount,
            currencyCode: "USD",
            note: nil,
            category: cat,
            tags: [],
            amountInPreferredCurrency: amount,
            preferredCurrencyCode: "USD"
        )
        tx.balanceAdjustmentType = balanceAdjustmentType
        return tx
    }

    private func makeScheduledPayment(
        name: String = "Rent",
        amount: Double = 500,
        nextDueDate: Date,
        isActive: Bool = true
    ) -> ScheduledPayment {
        let payment = ScheduledPayment(
            name: name,
            amount: amount,
            currencyCode: "USD",
            isRecurring: false,
            nextDueDate: nextDueDate,
            isActive: isActive
        )
        // ScheduledPaymentDateCalculator.applyPostFilters drops occurrences
        // earlier than `createdAt`. The model init sets `createdAt = .now`
        // (today's wall-clock date), which would mask our March 2026 fixtures
        // whenever the test suite runs on a later date. Pin createdAt to a
        // moment clearly before all our fixture dates so occurrences survive.
        payment.createdAt = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        return payment
    }

    private func makePaidInfo(payment: ScheduledPayment, count: Int, date: Date) -> [String: [PaidOccurrenceInfo]] {
        let infos = (0..<count).map { _ in
            PaidOccurrenceInfo(amount: payment.amount, currencyCode: payment.currencyCode, date: date)
        }
        return [payment.id.uuidString: infos]
    }

    // MARK: - Budget sub-score

    @Test func budget_noBudgets_returnsNil() {
        let score = FinancialScoreCalculator.calculate(
            transactions: [],
            budgets: [],
            scheduledPayments: [],
            paidAmounts: [:],
            now: now,
            calendar: calendar
        )
        #expect(score.budget == nil)
    }

    @Test func budget_oneExceeded_softPenalty8_returns92() {
        let budget = makeBudget(limit: 1000)
        let txs = [makeTx(amount: 1100, date: date(2026, 3, 10))]
        let score = FinancialScoreCalculator.calculate(
            transactions: txs,
            budgets: [budget],
            scheduledPayments: [],
            paidAmounts: [:],
            now: now,
            calendar: calendar
        )
        #expect(score.budget == 92)
    }

    @Test func budget_twoExceeded_softPenalty_returns84() {
        let b1 = makeBudget(limit: 1000, name: "B1")
        let b2 = makeBudget(limit: 500, name: "B2")
        let txs = [
            makeTx(amount: 1100, date: date(2026, 3, 10)),
            makeTx(amount: 600, date: date(2026, 3, 12))
        ]
        let score = FinancialScoreCalculator.calculate(
            transactions: txs,
            budgets: [b1, b2],
            scheduledPayments: [],
            paidAmounts: [:],
            now: now,
            calendar: calendar
        )
        #expect(score.budget == 84)
    }

    @Test func budget_threeExceeded_softPenalty_returns76() {
        let budgets = (1...3).map { makeBudget(limit: 100, name: "B\($0)") }
        let txs = (1...3).map { _ in makeTx(amount: 150, date: date(2026, 3, 10)) }
        let score = FinancialScoreCalculator.calculate(
            transactions: txs,
            budgets: budgets,
            scheduledPayments: [],
            paidAmounts: [:],
            now: now,
            calendar: calendar
        )
        #expect(score.budget == 76)
    }

    @Test func budget_over90pct_lateMonth_softPenalty3_returns97() {
        // At day 29 of 31 (≈10% remaining, <30%), with ratio ≥ 90% but < 100%.
        let budget = makeBudget(limit: 1000)
        let txs = [makeTx(amount: 950, date: date(2026, 3, 20))]
        let score = FinancialScoreCalculator.calculate(
            transactions: txs,
            budgets: [budget],
            scheduledPayments: [],
            paidAmounts: [:],
            now: lateMonthNow,
            calendar: calendar
        )
        #expect(score.budget == 97)
    }

    @Test func budget_under75pct_secondHalf_bonusClampsTo100() {
        // Day 17 is second half. Two budgets, each seeing 60% usage → +2 × 2 = +4
        // clamped to 100.
        let b1 = makeBudget(limit: 1000, name: "B1")
        let b2 = makeBudget(limit: 1000, name: "B2")
        let txs = [
            makeTx(amount: 300, date: date(2026, 3, 5)),
            makeTx(amount: 300, date: date(2026, 3, 6))
        ]
        let score = FinancialScoreCalculator.calculate(
            transactions: txs,
            budgets: [b1, b2],
            scheduledPayments: [],
            paidAmounts: [:],
            now: now,
            calendar: calendar
        )
        #expect(score.budget == 100)
    }

    @Test func budget_bonusCap10_sixBudgetsUnder75() {
        // 6 budgets under 75% → bonus would be +12 but cap is +10 → 110 clamp 100.
        let budgets = (1...6).map { makeBudget(limit: 1000, name: "B\($0)") }
        let txs = [makeTx(amount: 100, date: date(2026, 3, 5))]
        let score = FinancialScoreCalculator.calculate(
            transactions: txs,
            budgets: budgets,
            scheduledPayments: [],
            paidAmounts: [:],
            now: now,
            calendar: calendar
        )
        #expect(score.budget == 100)
    }

    // MARK: - Activity sub-score

    @Test func activity_noTransactions_returnsNil() {
        let score = FinancialScoreCalculator.calculate(
            transactions: [],
            budgets: [],
            scheduledPayments: [],
            paidAmounts: [:],
            now: now,
            calendar: calendar
        )
        #expect(score.activity == nil)
    }

    @Test func activity_onlyBalanceAdjustments_returnsNil() {
        // User has tx history but only balance adjustments → still counts as
        // "no real activity" for the activity metric.
        let txs = [
            makeTx(amount: 10, date: date(2026, 3, 15), balanceAdjustmentType: "manual"),
            makeTx(amount: 10, date: date(2026, 3, 16), balanceAdjustmentType: "manual")
        ]
        let score = FinancialScoreCalculator.calculate(
            transactions: txs,
            budgets: [],
            scheduledPayments: [],
            paidAmounts: [:],
            now: now,
            calendar: calendar
        )
        #expect(score.activity == nil)
    }

    @Test func activity_sevenDistinctDays_returns100() {
        let txs = (11...17).map { day in makeTx(amount: 10, date: date(2026, 3, day)) }
        let score = FinancialScoreCalculator.calculate(
            transactions: txs,
            budgets: [],
            scheduledPayments: [],
            paidAmounts: [:],
            now: now,
            calendar: calendar
        )
        #expect(score.activity == 100)
    }

    @Test func activity_threeDistinctDays_returns43() {
        // 3/7 × 100 = 42.857 → 43.
        let txs = [
            makeTx(amount: 10, date: date(2026, 3, 15)),
            makeTx(amount: 10, date: date(2026, 3, 16)),
            makeTx(amount: 10, date: date(2026, 3, 17))
        ]
        let score = FinancialScoreCalculator.calculate(
            transactions: txs,
            budgets: [],
            scheduledPayments: [],
            paidAmounts: [:],
            now: now,
            calendar: calendar
        )
        #expect(score.activity == 43)
    }

    @Test func activity_multipleTxSameDay_countAsOne() {
        let day = date(2026, 3, 17)
        let txs = (0..<3).map { _ in makeTx(amount: 10, date: day) }
        let score = FinancialScoreCalculator.calculate(
            transactions: txs,
            budgets: [],
            scheduledPayments: [],
            paidAmounts: [:],
            now: now,
            calendar: calendar
        )
        #expect(score.activity == 14) // 1/7 × 100 = 14.28 → 14
    }

    @Test func activity_hasTxButNoneInLast7Days_returns0NotNil() {
        // Distinguish "no data ever" (nil) from "no data in the last week" (0).
        let txs = [makeTx(amount: 10, date: date(2026, 2, 1))]
        let score = FinancialScoreCalculator.calculate(
            transactions: txs,
            budgets: [],
            scheduledPayments: [],
            paidAmounts: [:],
            now: now,
            calendar: calendar
        )
        #expect(score.activity == 0)
    }

    // MARK: - Bills sub-score

    @Test func bills_noActivePayments_returnsNil() {
        let score = FinancialScoreCalculator.calculate(
            transactions: [],
            budgets: [],
            scheduledPayments: [],
            paidAmounts: [:],
            now: now,
            calendar: calendar
        )
        #expect(score.bills == nil)
    }

    @Test func bills_allInactivePayments_returnsNil() {
        let payment = makeScheduledPayment(nextDueDate: date(2026, 3, 14), isActive: false)
        let score = FinancialScoreCalculator.calculate(
            transactions: [],
            budgets: [],
            scheduledPayments: [payment],
            paidAmounts: [:],
            now: now,
            calendar: calendar
        )
        #expect(score.bills == nil)
    }

    @Test func bills_oneOverdueInWindow_softPenalty5_returns95() {
        let payment = makeScheduledPayment(nextDueDate: date(2026, 3, 14))
        let score = FinancialScoreCalculator.calculate(
            transactions: [],
            budgets: [],
            scheduledPayments: [payment],
            paidAmounts: [:],
            now: now,
            calendar: calendar
        )
        #expect(score.bills == 95)
    }

    @Test func bills_overduePaid_returns100() {
        let payment = makeScheduledPayment(nextDueDate: date(2026, 3, 14))
        let paidAmounts = makePaidInfo(payment: payment, count: 1, date: date(2026, 3, 14))
        let score = FinancialScoreCalculator.calculate(
            transactions: [],
            budgets: [],
            scheduledPayments: [payment],
            paidAmounts: paidAmounts,
            now: now,
            calendar: calendar
        )
        #expect(score.bills == 100)
    }

    @Test func bills_overdueSkipped_returns100() {
        let payment = makeScheduledPayment(nextDueDate: date(2026, 3, 14))
        payment.skipDate(date(2026, 3, 14))
        let score = FinancialScoreCalculator.calculate(
            transactions: [],
            budgets: [],
            scheduledPayments: [payment],
            paidAmounts: [:],
            now: now,
            calendar: calendar
        )
        #expect(score.bills == 100)
    }

    @Test func bills_twoUpcoming_softPenalty3_returns94() {
        let p1 = makeScheduledPayment(name: "A", nextDueDate: date(2026, 3, 18))
        let p2 = makeScheduledPayment(name: "B", nextDueDate: date(2026, 3, 19))
        let score = FinancialScoreCalculator.calculate(
            transactions: [],
            budgets: [],
            scheduledPayments: [p1, p2],
            paidAmounts: [:],
            now: now,
            calendar: calendar
        )
        #expect(score.bills == 94)
    }

    @Test func bills_mixOverdueAndUpcoming_softPenalty_returns92() {
        let overduePayment = makeScheduledPayment(name: "Overdue", nextDueDate: date(2026, 3, 14))
        let upcomingPayment = makeScheduledPayment(name: "Upcoming", nextDueDate: date(2026, 3, 19))
        let score = FinancialScoreCalculator.calculate(
            transactions: [],
            budgets: [],
            scheduledPayments: [overduePayment, upcomingPayment],
            paidAmounts: [:],
            now: now,
            calendar: calendar
        )
        #expect(score.bills == 92)
    }

    @Test func bills_overdueOutsideWindow_noPenalty() {
        // Payment due March 5 (12 days ago) + an extra active payment far away
        // so the `active.isEmpty` guard does not kick in and return nil.
        let overdueOld = makeScheduledPayment(name: "Old", nextDueDate: date(2026, 3, 5))
        let farAway = makeScheduledPayment(name: "Far", nextDueDate: date(2026, 3, 28))
        let score = FinancialScoreCalculator.calculate(
            transactions: [],
            budgets: [],
            scheduledPayments: [overdueOld, farAway],
            paidAmounts: [:],
            now: now,
            calendar: calendar
        )
        #expect(score.bills == 100)
    }

    // MARK: - Total score — reweighting + soft floor

    @Test func total_allNil_returnsNil() {
        let score = FinancialScoreCalculator.calculate(
            transactions: [],
            budgets: [],
            scheduledPayments: [],
            paidAmounts: [:],
            now: now,
            calendar: calendar
        )
        #expect(score.total == nil)
    }

    @Test func total_onlyActivityPresent_equalsActivity() {
        // 3 distinct days → activity 43. Budget/bills nil → reweight to 100%.
        // Floor 50 kicks in: 43 → 50.
        let txs = [
            makeTx(amount: 10, date: date(2026, 3, 15)),
            makeTx(amount: 10, date: date(2026, 3, 16)),
            makeTx(amount: 10, date: date(2026, 3, 17))
        ]
        let score = FinancialScoreCalculator.calculate(
            transactions: txs,
            budgets: [],
            scheduledPayments: [],
            paidAmounts: [:],
            now: now,
            calendar: calendar
        )
        #expect(score.activity == 43)
        #expect(score.total == 50) // floor
    }

    @Test func total_budgetMissing_reweightsActivityAndBillsEvenly() {
        // No budgets → weights 0.5 / 0.5. activity=100, bills=100 → total=100.
        let txs = (11...17).map { day in makeTx(amount: 10, date: date(2026, 3, day)) }
        let farAway = makeScheduledPayment(nextDueDate: date(2026, 3, 28))
        let score = FinancialScoreCalculator.calculate(
            transactions: txs,
            budgets: [],
            scheduledPayments: [farAway],
            paidAmounts: [:],
            now: now,
            calendar: calendar
        )
        #expect(score.budget == nil)
        #expect(score.activity == 100)
        #expect(score.bills == 100)
        #expect(score.total == 100)
    }

    @Test func total_weightedFormula_40_30_30() {
        // Construct budget=100 (second half + under 75% caps to 100), activity=86
        // (6/7 days), bills=100 (far-away payment). Total = 100*0.4 + 86*0.3 + 100*0.3 = 95.8 → 96.
        let budget = makeBudget(limit: 10000) // huge limit so 100 spent ≪ 75%
        let txs = (12...17).map { day in makeTx(amount: 10, date: date(2026, 3, day)) }
        let farAway = makeScheduledPayment(nextDueDate: date(2026, 3, 28))
        let score = FinancialScoreCalculator.calculate(
            transactions: txs,
            budgets: [budget],
            scheduledPayments: [farAway],
            paidAmounts: [:],
            now: now,
            calendar: calendar
        )
        #expect(score.budget == 100)
        #expect(score.activity == 86)
        #expect(score.bills == 100)
        #expect(score.total == 96)
    }

    @Test func total_softFloor50_appliesInExtremeScenarios() {
        // Three budgets exceeded (−24 → 76), 0 activity (tx outside last 7
        // days), many overdue bills → bills floored at 0 internally.
        // Raw = 76*0.4 + 0*0.3 + 0*0.3 = 30.4 → floor to 50.
        let budgets = (1...3).map { makeBudget(limit: 100, name: "B\($0)") }
        let exceedingTxs = (1...3).map { _ in makeTx(amount: 150, date: date(2026, 3, 10)) }
        let activityTx = [makeTx(amount: 10, date: date(2026, 2, 1))]
        let overduePayments = (1...25).map { i in
            makeScheduledPayment(name: "O\(i)", nextDueDate: date(2026, 3, 14))
        }
        let score = FinancialScoreCalculator.calculate(
            transactions: exceedingTxs + activityTx,
            budgets: budgets,
            scheduledPayments: overduePayments,
            paidAmounts: [:],
            now: now,
            calendar: calendar
        )
        #expect(score.budget == 76)
        #expect(score.activity == 0)
        #expect(score.bills == 0)
        #expect(score.total == 50) // soft floor
    }

    @Test func total_clampsTo100_inEmptyPositiveCase() {
        // budget missing, activity 100, bills missing → total 100.
        let txs = (11...17).map { day in makeTx(amount: 10, date: date(2026, 3, day)) }
        let score = FinancialScoreCalculator.calculate(
            transactions: txs,
            budgets: [],
            scheduledPayments: [],
            paidAmounts: [:],
            now: now,
            calendar: calendar
        )
        #expect(score.budget == nil)
        #expect(score.activity == 100)
        #expect(score.bills == nil)
        #expect(score.total == 100)
    }
}
