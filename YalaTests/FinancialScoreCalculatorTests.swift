//
//  FinancialScoreCalculatorTests.swift
//  YalaTests
//
//  Contract covered:
//   • Sub-scores are `Int?`. `nil` does not dilute the total — remaining
//     sub-scores are re-weighted. All-nil → total nil.
//   • Sin suelo: el total va de 0 a 100 (lote 1 de la nota de salud, 11-nov-2026).
//   • Presupuestos: pasarse resta 70 × exceso² (suelo 30 por presupuesto); rozar el límite al final −3.
//   • Ritmo: 3 días de gracia y 8 puntos por día; en un período en curso cuenta el hueco hasta hoy.
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

    @Test func budget_oneExceededByTenPercent_barelyCounts_returns99() {
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
        // 110 %: 100 − 70 × 0,1² = 99,3 → 99.
        #expect(score.budget == 99)
    }

    @Test func budget_twoExceeded_perBucketAverage_returns48() {
        // Sin categoría, los dos presupuestos ven los 1.700 gastados: 170 % del de 1.000 → 66 y 340 % del de 500 → 30
        // (su suelo). Promedio entero de [66, 30] = 48.
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
        #expect(score.budget == 48)
    }

    @Test func budget_threeExceededByHalf_returns83() {
        // Tres presupuestos de 300 que ven los 450 gastados (150 %): 100 − 70 × 0,5² = 82,5 → 83 cada uno.
        let budgets = (1...3).map { makeBudget(limit: 300, name: "B\($0)") }
        let txs = (1...3).map { _ in makeTx(amount: 150, date: date(2026, 3, 10)) }
        let score = calculate(
            transactions: txs,
            budgets: budgets,
            now: now
        )
        #expect(score.budget == 83)
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
    // Curva: score = max(0, 100 − max(0, gap − 3) × 8).
    // Gap = mayor racha de días consecutivos sin registrar, incluido el hueco hasta hoy en un período en curso.
    // 0-3 días → 100, 4 → 92, 7 → 68, 10 → 44, 15 → 4, 16+ → 0.

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

    @Test func rhythm_threeDaysGap_isGrace_returns100() {
        // Tx 13 y 17 → gap = 3, dentro de la gracia.
        let txs = [
            makeTx(amount: 10, date: date(2026, 3, 13)),
            makeTx(amount: 10, date: date(2026, 3, 17))
        ]
        let score = calculate(transactions: txs, now: now)
        #expect(score.activity == 100)
    }

    @Test func rhythm_sevenDaysGap_returns68() {
        // Tx 9 y 17 → gap = 7. Score = 100 - (7-3)*8 = 68.
        let txs = [
            makeTx(amount: 10, date: date(2026, 3, 9)),
            makeTx(amount: 10, date: date(2026, 3, 17))
        ]
        let score = calculate(transactions: txs, now: now)
        #expect(score.activity == 68)
    }

    @Test func rhythm_elevenDaysGap_returns36() {
        // Tx 1 y 13 → gap = 11; hasta hoy (17) quedan 3, en la gracia. Score = 100 - 8*8 = 36.
        let txs = [
            makeTx(amount: 10, date: date(2026, 3, 1)),
            makeTx(amount: 10, date: date(2026, 3, 13))
        ]
        let score = calculate(transactions: txs, now: now)
        #expect(score.activity == 36)
    }

    @Test func rhythm_thisYear_usesMonthlyAverage() {
        // Multi-mes ⇒ promedio de gaps mensuales. Enero: solo el 5 (0). Febrero: 5 y 6 (0). Marzo: el 16, y hoy es 17
        // (hueco hasta hoy 0). Promedio = 0 → 100.
        let txs = [
            makeTx(amount: 10, date: date(2026, 1, 5)),
            makeTx(amount: 10, date: date(2026, 2, 5)),
            makeTx(amount: 10, date: date(2026, 2, 6)),
            makeTx(amount: 10, date: date(2026, 3, 16))
        ]
        let score = calculate(
            transactions: txs, period: .thisYear, now: now
        )
        #expect(score.activity == 100)
    }

    @Test func rhythm_thisYear_oneOldGap_doesNotDestroyAverage() {
        // Enero gap=10 (1 y 12), febrero 0 (5,6,7), marzo 0 (16, hoy 17). Promedio = 3,33 → 100 − 0,33 × 8 = 97.
        let txs = [
            makeTx(amount: 10, date: date(2026, 1, 1)),
            makeTx(amount: 10, date: date(2026, 1, 12)),
            makeTx(amount: 10, date: date(2026, 2, 5)),
            makeTx(amount: 10, date: date(2026, 2, 6)),
            makeTx(amount: 10, date: date(2026, 2, 7)),
            makeTx(amount: 10, date: date(2026, 3, 16))
        ]
        let score = calculate(
            transactions: txs, period: .thisYear, now: now
        )
        #expect(score.activity == 97)
    }

    // MARK: - Ritmo: el hueco hasta hoy (lote 1 de la nota de salud, 11-nov-2026)

    @Test func rhythm_fourDaysGap_firstDayPastGrace_returns92() {
        // Tx 12 y 17 → gap = 4: el primer día que resta.
        let txs = [makeTx(amount: 10, date: date(2026, 3, 12)), makeTx(amount: 10, date: date(2026, 3, 17))]
        #expect(calculate(transactions: txs, now: now).activity == 92)
    }

    @Test func rhythm_trailingGap_tenDaysWithoutRecording_returns44() {
        // Registró del 1 al 6 cada día y nada más; hoy es 17 → del 7 al 16 son 10 días sin registrar.
        // Antes daba 100 (no miraba el hueco hasta hoy).
        let txs = (1...6).map { makeTx(amount: 10, date: date(2026, 3, $0)) }
        #expect(calculate(transactions: txs, now: now).activity == 44)
    }

    @Test func rhythm_trailingGap_threeDays_isGrace_fourDaysCounts() {
        // Último registro el 13: 14, 15 y 16 sin registrar (hoy no cuenta) → gracia → 100.
        let threeDays = [makeTx(amount: 10, date: date(2026, 3, 1)), makeTx(amount: 10, date: date(2026, 3, 2)),
                         makeTx(amount: 10, date: date(2026, 3, 3)), makeTx(amount: 10, date: date(2026, 3, 4)),
                         makeTx(amount: 10, date: date(2026, 3, 5)), makeTx(amount: 10, date: date(2026, 3, 6)),
                         makeTx(amount: 10, date: date(2026, 3, 7)), makeTx(amount: 10, date: date(2026, 3, 8)),
                         makeTx(amount: 10, date: date(2026, 3, 9)), makeTx(amount: 10, date: date(2026, 3, 10)),
                         makeTx(amount: 10, date: date(2026, 3, 11)), makeTx(amount: 10, date: date(2026, 3, 12)),
                         makeTx(amount: 10, date: date(2026, 3, 13))]
        #expect(calculate(transactions: threeDays, now: now).activity == 100)
        // Último registro el 12: cuatro días sin registrar → 92.
        #expect(calculate(transactions: Array(threeDays.dropLast()), now: now).activity == 92)
    }

    @Test func rhythm_trailingGap_lastRecordBeforeThePeriod_stillCounts() {
        // Nada en marzo; el último registro fue el 20 de febrero. Del 21-feb al 16-mar son 24 días sin registrar:
        // Ritmo tiene nota (0), no «sin datos».
        let txs = [makeTx(amount: 10, date: date(2026, 2, 20))]
        #expect(calculate(transactions: txs, now: now).activity == 0)
    }

    @Test func rhythm_closedPeriod_hasNoTrailingGap() {
        // Febrero ya cerró: el hueco hasta hoy no es de ese período.
        let txs = [makeTx(amount: 10, date: date(2026, 2, 1)), makeTx(amount: 10, date: date(2026, 2, 2))]
        #expect(calculate(transactions: txs, period: .lastMonth, now: now).activity == 100)
    }

    @Test func rhythm_thisYear_trailingGapEntersTheCurrentMonth() {
        // Enero 0, febrero 0; marzo sin registros y último el 6-feb: del 7-feb al 16-mar, 38 días.
        // Promedio (0 + 0 + 38) / 3 = 12,67 → 100 − 9,67 × 8 = 22,7 → 23.
        let txs = [
            makeTx(amount: 10, date: date(2026, 1, 5)),
            makeTx(amount: 10, date: date(2026, 2, 5)),
            makeTx(amount: 10, date: date(2026, 2, 6))
        ]
        #expect(calculate(transactions: txs, period: .thisYear, now: now).activity == 23)
    }

    @Test func rhythm_balanceAdjustmentDoesNotResetTheGap() {
        // Un ajuste de saldo hoy no es un registro: el hueco desde el 6 sigue contando.
        var txs = (1...6).map { makeTx(amount: 10, date: date(2026, 3, $0)) }
        txs.append(makeTx(amount: 10, date: date(2026, 3, 17), balanceAdjustmentType: "adjustment"))
        #expect(calculate(transactions: txs, now: now).activity == 44)
    }

    @Test func rhythmScore_hasNoJumps() {
        // Gradual: cada día de más resta lo mismo, sin saltos.
        let scores = (0...20).map { FinancialScoreCalculator.rhythmScore(gap: Double($0)) }
        #expect(Array(scores[0...3]) == [100, 100, 100, 100])
        for i in 4...12 { #expect(scores[i - 1] - scores[i] == 8) }
        #expect(scores[16] == 0)
    }

    // MARK: - Presupuestos: la curva (lote 1 de la nota de salud)

    @Test func overspendScore_curve() {
        #expect(FinancialScoreCalculator.overspendScore(ratio: 1.0) == 100)
        #expect(FinancialScoreCalculator.overspendScore(ratio: 1.05) == 100)
        #expect(FinancialScoreCalculator.overspendScore(ratio: 1.1) == 99)
        #expect(FinancialScoreCalculator.overspendScore(ratio: 1.25) == 96)
        #expect(FinancialScoreCalculator.overspendScore(ratio: 1.5) == 83)
        #expect(FinancialScoreCalculator.overspendScore(ratio: 1.8) == 55)
        #expect(FinancialScoreCalculator.overspendScore(ratio: 2.0) == 30)
        #expect(FinancialScoreCalculator.overspendScore(ratio: 5.0) == 30, "suelo de un presupuesto")
        // Decrece de forma monótona.
        let curve = stride(from: 1.0, through: 2.0, by: 0.05).map { FinancialScoreCalculator.overspendScore(ratio: $0) }
        #expect(zip(curve, curve.dropFirst()).allSatisfy { $0 >= $1 })
    }

    @Test func budget_atTheLimit_isNotOver_returns100() {
        let budget = makeBudget(limit: 1000)
        let txs = [makeTx(amount: 1000, date: date(2026, 3, 10))]
        #expect(calculate(transactions: txs, budgets: [budget], now: now).budget == 100)
    }

    @Test func budget_doubled_returnsItsFloor30_andOthersSoften() {
        // Sin categoría, los dos presupuestos ven el mismo gasto (1.000): uno de 500 va al doble (30) y otro de 1.300
        // va holgado (100). Ninguno solo hunde la parte: (30 + 100) / 2 = 65.
        let doubled = makeBudget(limit: 500, name: "Comida")
        let roomy = makeBudget(limit: 1300, name: "Mes")
        let txs = [makeTx(amount: 1000, date: date(2026, 3, 10))]
        #expect(calculate(transactions: txs, budgets: [doubled], now: now).budget == 30)
        #expect(calculate(transactions: txs, budgets: [doubled, roomy], now: now).budget == 65)
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

    @Test func total_onlyRhythmPresent_hasNoScore() {
        // 3 días consecutivos → rhythm 100. Budget/Commitments nil. Hasta la revisión 2.3 (decisión 9, PN-2) la nota era
        // esa parte re-ponderada al 100 % y daba 100 con tres registros; ahora hacen falta dos de las tres partes.
        let txs = [
            makeTx(amount: 10, date: date(2026, 3, 15)),
            makeTx(amount: 10, date: date(2026, 3, 16)),
            makeTx(amount: 10, date: date(2026, 3, 17))
        ]
        let score = calculate(transactions: txs, now: now)
        #expect(score.activity == 100)
        #expect(score.total == nil)
        #expect(score.partsWithoutData == [.budget, .bills])
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

    @Test func total_noFloor_canGoBelow50_whenThingsReallyGoWrong() {
        // Sin suelo (lote 1 de la nota de salud): la nota dice lo que pasa.
        // - Budget: 155 de 100 (155 %) → 100 − 70 × 0,55² = 78,8 → 79.
        // - Rhythm: tx el 1 y el 17 → gap 15 → 100 − 12 × 8 = 4.
        // - Commitments: pendiente sin saldo → cov=0, load=50 → 25.
        // Total = 79*0.4 + 4*0.25 + 25*0.35 = 31.6 + 1 + 8.75 = 41.35 → 41 (antes, 50 por el suelo).
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
        #expect(score.budget == 79)
        #expect(score.activity == 4)
        #expect(score.bills == 25)
        #expect(score.total == 41)
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
