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
        let budget = Budget(
            currencyCode: "USD",
            limitAmount: limit,
            name: name,
            periodType: periodType
        )
        // Pin createdAt to before March 2026 fixtures so bucketIsValid passes.
        // Sin esto, `bucket.start (marzo 2026) < createdAt (.now real)` y el
        // bucket queda skipped → score = nil.
        budget.createdAt = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        return budget
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

    /// Wrapper sobre la nueva firma del calculator con defaults para los tests
    /// existentes (period: .thisMonth replica la semántica monthly anterior;
    /// `accounts: []` y `preferredCurrencyCode: "USD"` son inertes para tests
    /// que no tocan Compromisos.Cobertura/Carga).
    private func calculate(
        transactions: [TransactionItem] = [],
        budgets: [Budget] = [],
        scheduledPayments: [ScheduledPayment] = [],
        accounts: [Account] = [],
        paidAmounts: [String: [PaidOccurrenceInfo]] = [:],
        period: DetailPeriod = .thisMonth,
        customRange: DateInterval? = nil,
        preferredCurrencyCode: String = "USD",
        now: Date,
        calendar: Calendar = .current
    ) -> FinancialScore {
        FinancialScoreCalculator.calculate(
            transactions: transactions,
            budgets: budgets,
            scheduledPayments: scheduledPayments,
            accounts: accounts,
            paidAmounts: paidAmounts,
            period: period,
            customRange: customRange,
            preferredCurrencyCode: preferredCurrencyCode,
            converter: MockCurrencyConverter(),
            now: now,
            calendar: calendar
        )
    }

    // MARK: - Budget sub-score

    @Test func budget_noBudgets_returnsNil() {
        let score = calculate(
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
        let score = calculate(
            transactions: txs,
            budgets: [budget],
            scheduledPayments: [],
            paidAmounts: [:],
            now: now,
            calendar: calendar
        )
        #expect(score.budget == 92)
    }

    @Test func budget_twoExceeded_perBucketAverage_returns92() {
        // Nueva semántica: cada bucket se evalúa independiente (penalty 8 → 92).
        // Promedio de [92, 92] = 92 (antes era acumulado global = 84).
        let b1 = makeBudget(limit: 1000, name: "B1")
        let b2 = makeBudget(limit: 500, name: "B2")
        let txs = [
            makeTx(amount: 1100, date: date(2026, 3, 10)),
            makeTx(amount: 600, date: date(2026, 3, 12))
        ]
        let score = calculate(
            transactions: txs,
            budgets: [b1, b2],
            now: now
        )
        #expect(score.budget == 92)
    }

    @Test func budget_threeExceeded_perBucketAverage_returns92() {
        // Idem 3 budgets cada uno exceeded → cada bucket 92 → promedio 92.
        let budgets = (1...3).map { makeBudget(limit: 100, name: "B\($0)") }
        let txs = (1...3).map { _ in makeTx(amount: 150, date: date(2026, 3, 10)) }
        let score = calculate(
            transactions: txs,
            budgets: budgets,
            now: now
        )
        #expect(score.budget == 92)
    }

    @Test func budget_over90pct_lateMonth_softPenalty3_returns97() {
        // At day 29 of 31 (≈10% remaining, <30%), with ratio ≥ 90% but < 100%.
        let budget = makeBudget(limit: 1000)
        let txs = [makeTx(amount: 950, date: date(2026, 3, 20))]
        let score = calculate(
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
        let score = calculate(
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
        let score = calculate(
            transactions: txs,
            budgets: budgets,
            scheduledPayments: [],
            paidAmounts: [:],
            now: now,
            calendar: calendar
        )
        #expect(score.budget == 100)
    }

    // MARK: - Rhythm sub-score (antes "Activity")
    // Curva: score = max(0, 100 − max(0, gap − 2) × 12).
    // Gap = mayor racha de días consecutivos sin registrar.
    // 0-2 días → 100, 3 → 88, 4 → 76, 5 → 64, 6 → 52, 7 → 40, 10+ → 0.

    @Test func rhythm_noTransactions_returnsNil() {
        let score = calculate(
            transactions: [],
            now: now
        )
        #expect(score.activity == nil)
    }

    @Test func rhythm_onlyBalanceAdjustments_returnsNil() {
        let txs = [
            makeTx(amount: 10, date: date(2026, 3, 15), balanceAdjustmentType: "manual"),
            makeTx(amount: 10, date: date(2026, 3, 16), balanceAdjustmentType: "manual")
        ]
        let score = calculate(transactions: txs, now: now)
        #expect(score.activity == nil)
    }

    @Test func rhythm_consecutiveDays_zeroGap_returns100() {
        // Tx en días 15, 16, 17 → gap = 0. Score = 100.
        let txs = [
            makeTx(amount: 10, date: date(2026, 3, 15)),
            makeTx(amount: 10, date: date(2026, 3, 16)),
            makeTx(amount: 10, date: date(2026, 3, 17))
        ]
        let score = calculate(transactions: txs, now: now)
        #expect(score.activity == 100)
    }

    @Test func rhythm_twoDaysGap_stillReturns100() {
        // Tx en días 14 y 17 → gap = 2 (días 15-16 vacíos). Tolerancia incluye 2.
        let txs = [
            makeTx(amount: 10, date: date(2026, 3, 14)),
            makeTx(amount: 10, date: date(2026, 3, 17))
        ]
        let score = calculate(transactions: txs, now: now)
        #expect(score.activity == 100)
    }

    @Test func rhythm_threeDaysGap_returns88() {
        // Tx 13 y 17 → gap = 3. Score = 100 - (3-2)*12 = 88.
        let txs = [
            makeTx(amount: 10, date: date(2026, 3, 13)),
            makeTx(amount: 10, date: date(2026, 3, 17))
        ]
        let score = calculate(transactions: txs, now: now)
        #expect(score.activity == 88)
    }

    @Test func rhythm_sevenDaysGap_returns40() {
        // Tx 9 y 17 → gap = 7. Score = 100 - (7-2)*12 = 40.
        let txs = [
            makeTx(amount: 10, date: date(2026, 3, 9)),
            makeTx(amount: 10, date: date(2026, 3, 17))
        ]
        let score = calculate(transactions: txs, now: now)
        #expect(score.activity == 40)
    }

    @Test func rhythm_tenPlusDaysGap_returns0() {
        // Tx 1 y 12 → gap = 10. Score = 100 - 8*12 = 4. Pero gap 11 → 0.
        let txs = [
            makeTx(amount: 10, date: date(2026, 3, 1)),
            makeTx(amount: 10, date: date(2026, 3, 13))
        ]
        let score = calculate(transactions: txs, now: now)
        #expect(score.activity == 0)
    }

    @Test func rhythm_thisYear_usesMonthlyAverage() {
        // Multi-mes ⇒ promedio de gaps mensuales. Mes 1: tx solo el día 5 (gap 0).
        // Mes 2: tx 5 y 6 (gap 0). Promedio = 0 → score 100.
        let txs = [
            makeTx(amount: 10, date: date(2026, 1, 5)),
            makeTx(amount: 10, date: date(2026, 2, 5)),
            makeTx(amount: 10, date: date(2026, 2, 6))
        ]
        let score = calculate(
            transactions: txs, period: .thisYear, now: now
        )
        #expect(score.activity == 100)
    }

    @Test func rhythm_thisYear_oneOldGap_doesNotDestroyAverage() {
        // Mes 1 gap=10 (1 y 12), Mes 2 gap=0 (5,6,7). Promedio = 5 → score = 64.
        let txs = [
            makeTx(amount: 10, date: date(2026, 1, 1)),
            makeTx(amount: 10, date: date(2026, 1, 12)),
            makeTx(amount: 10, date: date(2026, 2, 5)),
            makeTx(amount: 10, date: date(2026, 2, 6)),
            makeTx(amount: 10, date: date(2026, 2, 7))
        ]
        let score = calculate(
            transactions: txs, period: .thisYear, now: now
        )
        // Avg gap = 5 → 100 - (5-2)*12 = 64.
        #expect(score.activity == 64)
    }

    // MARK: - Commitments sub-score (antes "Bills")
    // Composición Cobertura (50%) + Carga (50%).
    // Cobertura: liveBalance vs pendientes. Carga: % de ingresos.

    @Test func commitments_noActivePayments_returnsNil() {
        let score = calculate(scheduledPayments: [], now: now)
        #expect(score.bills == nil)
    }

    @Test func commitments_allInactivePayments_returnsNil() {
        let payment = makeScheduledPayment(nextDueDate: date(2026, 3, 14), isActive: false)
        let score = calculate(scheduledPayments: [payment], now: now)
        #expect(score.bills == nil)
    }

    @Test func commitments_shortPeriodLast7Days_returnsNil() {
        let payment = makeScheduledPayment(nextDueDate: date(2026, 3, 14))
        let score = calculate(
            scheduledPayments: [payment], period: .last7Days, now: now
        )
        #expect(score.bills == nil)
    }

    @Test func commitments_thisWeek_returnsNil() {
        let payment = makeScheduledPayment(nextDueDate: date(2026, 3, 14))
        let score = calculate(
            scheduledPayments: [payment], period: .thisWeek, now: now
        )
        #expect(score.bills == nil)
    }

    @Test func commitments_noIncome_neutralLoad_butCoverageStillCounts() {
        // Sin ingresos → load = 50 (neutral). Sin saldo (accounts vacío) +
        // 1 pendiente $500 → projected = -500, ratio = -1, coverage = 0.
        // Composite = (0 + 50) / 2 = 25.
        let payment = makeScheduledPayment(nextDueDate: date(2026, 3, 25))
        let score = calculate(
            scheduledPayments: [payment], now: now
        )
        #expect(score.bills == 25)
    }

    @Test func commitments_pendingPaid_excludedFromTotal() {
        // El pago marcado como pagado no cuenta como pendiente.
        let payment = makeScheduledPayment(nextDueDate: date(2026, 3, 14))
        let paidAmounts = makePaidInfo(payment: payment, count: 1, date: date(2026, 3, 14))
        let score = calculate(
            scheduledPayments: [payment], paidAmounts: paidAmounts, now: now
        )
        // pendingTotal = 0 → coverage = 100, load = 50 (no income) → composite = 75.
        #expect(score.bills == 75)
    }

    @Test func commitments_pendingSkipped_excludedFromTotal() {
        let payment = makeScheduledPayment(nextDueDate: date(2026, 3, 14))
        payment.skipDate(date(2026, 3, 14))
        let score = calculate(
            scheduledPayments: [payment], now: now
        )
        // skipped → pendingTotal 0 → coverage 100, load 50 → composite 75.
        #expect(score.bills == 75)
    }

    @Test func commitments_incomeScheduled_excluded() {
        // Pagos con transactionType=income NO entran en pendientes ni carga.
        let income = makeScheduledPayment(nextDueDate: date(2026, 3, 25))
        income.transactionType = "income"
        let score = calculate(
            scheduledPayments: [income], now: now
        )
        // active.isEmpty tras filtro → nil.
        #expect(score.bills == nil)
    }

    // MARK: - Total — pesos 40/25/35 + soft floor

    @Test func total_allNil_returnsNil() {
        let score = calculate(now: now)
        #expect(score.total == nil)
    }

    @Test func total_onlyRhythmPresent_appliesSoftFloor() {
        // 3 días consecutivos → rhythm 100. Budget/Commitments nil → reweight 100%.
        // Total = 100 → no aplica floor.
        let txs = [
            makeTx(amount: 10, date: date(2026, 3, 15)),
            makeTx(amount: 10, date: date(2026, 3, 16)),
            makeTx(amount: 10, date: date(2026, 3, 17))
        ]
        let score = calculate(transactions: txs, now: now)
        #expect(score.activity == 100)
        #expect(score.total == 100)
    }

    @Test func total_weights_40_25_35() {
        // Budget=100 (under 75% en segunda mitad), Rhythm=100 (3 días seguidos),
        // Commitments=75 (no pendientes, no income → cov 100 + load 50 / 2).
        // Total = 100*0.4 + 100*0.25 + 75*0.35 = 40 + 25 + 26.25 = 91.25 → 91.
        let budget = makeBudget(limit: 10000)
        let txs = [
            makeTx(amount: 10, date: date(2026, 3, 15)),
            makeTx(amount: 10, date: date(2026, 3, 16)),
            makeTx(amount: 10, date: date(2026, 3, 17))
        ]
        let payment = makeScheduledPayment(nextDueDate: date(2026, 3, 28))
        let paidAmounts = makePaidInfo(payment: payment, count: 1, date: date(2026, 3, 28))
        let score = calculate(
            transactions: txs,
            budgets: [budget],
            scheduledPayments: [payment],
            paidAmounts: paidAmounts,
            now: now
        )
        #expect(score.budget == 100)
        #expect(score.activity == 100)
        #expect(score.bills == 75)
        #expect(score.total == 91)
    }

    @Test func total_softFloor50_appliesInExtremeScenarios() {
        // Forzar piso 50: budget bajo + commitments bajo + rhythm bajo.
        // - Budget: 1 budget exceeded → 92.
        // - Rhythm: tx separadas por gap grande (>10 días) → 0.
        // - Commitments: pendiente sin saldo → cov=0, load=50 → 25.
        // Total = 92*0.4 + 0*0.25 + 25*0.35 = 36.8 + 0 + 8.75 = 45.55 → floor 50.
        let budget = makeBudget(limit: 100, name: "B")
        let txs = [
            makeTx(amount: 150, date: date(2026, 3, 1)),  // exceed budget
            makeTx(amount: 5, date: date(2026, 3, 17))    // gap = 15 días → rhythm 0
        ]
        let payment = makeScheduledPayment(nextDueDate: date(2026, 3, 25))
        let score = calculate(
            transactions: txs,
            budgets: [budget],
            scheduledPayments: [payment],
            now: now
        )
        #expect(score.budget == 92)
        #expect(score.activity == 0)
        #expect(score.bills == 25)
        #expect(score.total == 50)  // soft floor — raw 45.55 < 50.
    }

    @Test func total_budgetMissing_reweightsRhythmAndCommitments() {
        // No budgets → pesos rhythm 0.25 + commitments 0.35 = 0.60.
        // Rhythm 100, Commitments 75 → (100*0.25 + 75*0.35) / 0.60 = 85.41 → 85.
        let txs = [
            makeTx(amount: 10, date: date(2026, 3, 15)),
            makeTx(amount: 10, date: date(2026, 3, 16)),
            makeTx(amount: 10, date: date(2026, 3, 17))
        ]
        let payment = makeScheduledPayment(nextDueDate: date(2026, 3, 28))
        let paidAmounts = makePaidInfo(payment: payment, count: 1, date: date(2026, 3, 28))
        let score = calculate(
            transactions: txs,
            scheduledPayments: [payment],
            paidAmounts: paidAmounts,
            now: now
        )
        #expect(score.budget == nil)
        #expect(score.activity == 100)
        #expect(score.bills == 75)
        #expect(score.total == 85)
    }
}
