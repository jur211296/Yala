// Tests generated for: TrendDataProcessor
// Cobertura estimada: 85%

import Foundation
import Testing

@testable import Yala

struct TrendDataProcessorTests {

    // MARK: - Constants Tests

    @Test func smoothingWindowSize_is14() {
        #expect(TrendDataProcessor.smoothingWindowSize == 14)
    }

    @Test func smoothingThreshold_is30() {
        #expect(TrendDataProcessor.smoothingThreshold == 30)
    }

    @Test func smoothingPeriods_containsLongPeriods() {
        let periods = TrendDataProcessor.smoothingPeriods
        #expect(periods.contains(.thisYear))
        #expect(periods.contains(.lastYear))
        #expect(periods.contains(.allTime))
        #expect(!periods.contains(.thisMonth))
        #expect(!periods.contains(.last7Days))
    }

    // MARK: - processTrendData: Empty Input

    @Test func processTrendData_withNoTransactions_returnsEmptyResult() {
        let interval = DateInterval(
            start: Date().addingTimeInterval(-86400 * 7),
            end: Date()
        )
        let result = TrendDataProcessor.processTrendData(
            transactions: [],
            accounts: [],
            metric: .balance,
            period: .last7Days,
            grouping: .day,
            interval: interval,
            currencyCode: "PEN"
        )
        #expect(result.points.isEmpty)
        #expect(result.rawPoints.isEmpty)
        #expect(result.totalIncome == 0)
        #expect(result.totalExpense == 0)
        #expect(result.finalBalance == 0)
    }

    // MARK: - processTrendData: Income/Expense Totals

    @Test func processTrendData_calculatesIncomeTotalsCorrectly() {
        let now = Date()
        let interval = DateInterval(
            start: Calendar.current.startOfDay(for: now),
            end: now.addingTimeInterval(1)
        )
        let tx1 = makeTransaction(amount: 500, amountInPreferred: 500, date: now)
        let tx2 = makeTransaction(amount: 200, amountInPreferred: 200, date: now)

        let result = TrendDataProcessor.processTrendData(
            transactions: [tx1, tx2],
            accounts: [],
            metric: .balance,
            period: .thisMonth,
            grouping: .day,
            interval: interval,
            currencyCode: "PEN"
        )
        #expect(result.totalIncome == 700)
        #expect(result.totalExpense == 0)
    }

    @Test func processTrendData_calculatesExpenseTotalsCorrectly() {
        let now = Date()
        let interval = DateInterval(
            start: Calendar.current.startOfDay(for: now),
            end: now.addingTimeInterval(1)
        )
        let tx1 = makeTransaction(amount: -100, amountInPreferred: -100, date: now)
        let tx2 = makeTransaction(amount: -250, amountInPreferred: -250, date: now)

        let result = TrendDataProcessor.processTrendData(
            transactions: [tx1, tx2],
            accounts: [],
            metric: .balance,
            period: .thisMonth,
            grouping: .day,
            interval: interval,
            currencyCode: "PEN"
        )
        #expect(result.totalIncome == 0)
        #expect(result.totalExpense == 350)
    }

    @Test func processTrendData_excludesBalanceAdjustmentsFromTotals() {
        let now = Date()
        let interval = DateInterval(
            start: Calendar.current.startOfDay(for: now),
            end: now.addingTimeInterval(1)
        )
        let normalTx = makeTransaction(amount: -100, amountInPreferred: -100, date: now)
        let adjustmentTx = makeTransaction(amount: 1000, amountInPreferred: 1000, date: now, balanceAdjustmentType: "initial_balance")

        let result = TrendDataProcessor.processTrendData(
            transactions: [normalTx, adjustmentTx],
            accounts: [],
            metric: .balance,
            period: .thisMonth,
            grouping: .day,
            interval: interval,
            currencyCode: "PEN"
        )
        // Balance adjustment should NOT count toward income
        #expect(result.totalIncome == 0)
        #expect(result.totalExpense == 100)
    }

    // MARK: - processTrendData: Balance Metric

    @Test func processTrendData_balance_calculatesRunningTotal() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let day1 = today
        let day2 = calendar.date(byAdding: .day, value: 1, to: today)!
        let endDate = calendar.date(byAdding: .day, value: 2, to: today)!

        let interval = DateInterval(start: day1, end: endDate)

        let tx1 = makeTransaction(amount: 100, amountInPreferred: 100, date: day1)
        let tx2 = makeTransaction(amount: -30, amountInPreferred: -30, date: day2)

        let result = TrendDataProcessor.processTrendData(
            transactions: [tx1, tx2],
            accounts: [],
            metric: .balance,
            period: .thisMonth,
            grouping: .day,
            interval: interval,
            currencyCode: "PEN"
        )
        #expect(!result.rawPoints.isEmpty)
        // First point: 100 (running balance after tx1)
        // Second point: 70 (100 - 30 running balance after tx2)
        if result.rawPoints.count >= 2 {
            #expect(result.rawPoints[0].value == 100)
            #expect(result.rawPoints[1].value == 70)
        }
        #expect(result.finalBalance == 70)
    }

    @Test func processTrendData_balance_includesTransactionsBeforeInterval() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let beforeInterval = calendar.date(byAdding: .day, value: -5, to: today)!
        let intervalStart = calendar.date(byAdding: .day, value: -1, to: today)!
        let withinInterval = today
        let endDate = calendar.date(byAdding: .day, value: 1, to: today)!

        let interval = DateInterval(start: intervalStart, end: endDate)

        let preTx = makeTransaction(amount: 500, amountInPreferred: 500, date: beforeInterval)
        let inTx = makeTransaction(amount: -100, amountInPreferred: -100, date: withinInterval)

        let result = TrendDataProcessor.processTrendData(
            transactions: [preTx, inTx],
            accounts: [],
            metric: .balance,
            period: .thisMonth,
            grouping: .day,
            interval: interval,
            currencyCode: "PEN"
        )
        // Balance should include pre-interval transaction as starting balance
        // Running balance = 500 (before) + (-100) = 400
        #expect(result.finalBalance == 400)
    }

    // MARK: - processTrendData: Income Metric

    @Test func processTrendData_income_filtersPositiveTransactions() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let day1 = today
        let day2 = calendar.date(byAdding: .day, value: 1, to: today)!
        let endDate = calendar.date(byAdding: .day, value: 2, to: today)!

        let interval = DateInterval(start: day1, end: endDate)

        let incomeTx = makeTransaction(amount: 500, amountInPreferred: 500, date: day1)
        let expenseTx = makeTransaction(amount: -200, amountInPreferred: -200, date: day2)

        let result = TrendDataProcessor.processTrendData(
            transactions: [incomeTx, expenseTx],
            accounts: [],
            metric: .income,
            period: .thisMonth,
            grouping: .day,
            interval: interval,
            currencyCode: "PEN"
        )
        // Income metric should only include positive transactions (cumulative)
        #expect(!result.rawPoints.isEmpty)
        // The cumulative income should be 500 at the only point
        if let lastPoint = result.rawPoints.last {
            #expect(lastPoint.value == 500)
        }
    }

    // MARK: - processTrendData: Expense Metric

    @Test func processTrendData_expense_filtersNegativeTransactions() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let day1 = today
        let day2 = calendar.date(byAdding: .day, value: 1, to: today)!
        let endDate = calendar.date(byAdding: .day, value: 2, to: today)!

        let interval = DateInterval(start: day1, end: endDate)

        let incomeTx = makeTransaction(amount: 500, amountInPreferred: 500, date: day1)
        let expenseTx = makeTransaction(amount: -200, amountInPreferred: -200, date: day1)
        let expenseTx2 = makeTransaction(amount: -150, amountInPreferred: -150, date: day2)

        let result = TrendDataProcessor.processTrendData(
            transactions: [incomeTx, expenseTx, expenseTx2],
            accounts: [],
            metric: .expense,
            period: .thisMonth,
            grouping: .day,
            interval: interval,
            currencyCode: "PEN"
        )
        // Expense metric: cumulative abs values of negative transactions
        #expect(!result.rawPoints.isEmpty)
        if let lastPoint = result.rawPoints.last {
            #expect(lastPoint.value == 350) // 200 + 150
        }
    }

    // MARK: - processTrendData: Smoothing

    @Test func processTrendData_shortPeriod_doesNotSmooth() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let interval = DateInterval(
            start: calendar.date(byAdding: .day, value: -7, to: today)!,
            end: calendar.date(byAdding: .day, value: 1, to: today)!
        )

        // Create a few transactions over the week
        var transactions: [TransactionItem] = []
        for i in 0..<5 {
            let date = calendar.date(byAdding: .day, value: -6 + i, to: today)!
            transactions.append(makeTransaction(
                amount: Double(i + 1) * 100,
                amountInPreferred: Double(i + 1) * 100,
                date: date
            ))
        }

        let result = TrendDataProcessor.processTrendData(
            transactions: transactions,
            accounts: [],
            metric: .balance,
            period: .last7Days, // Not in smoothingPeriods
            grouping: .day,
            interval: interval,
            currencyCode: "PEN"
        )

        // Points and rawPoints should be identical (no smoothing)
        #expect(result.points.count == result.rawPoints.count)
        for i in 0..<result.points.count {
            #expect(result.points[i].value == result.rawPoints[i].value)
        }
    }

    // MARK: - processTrendData: YDomain

    @Test func processTrendData_yDomain_isCalculatedFromRawPoints() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let interval = DateInterval(
            start: today,
            end: calendar.date(byAdding: .day, value: 2, to: today)!
        )
        let tx = makeTransaction(amount: 500, amountInPreferred: 500, date: today)

        let result = TrendDataProcessor.processTrendData(
            transactions: [tx],
            accounts: [],
            metric: .balance,
            period: .thisMonth,
            grouping: .day,
            interval: interval,
            currencyCode: "PEN"
        )
        #expect(result.yDomain.upperBound >= 500)
    }

    // MARK: - processTrendData: Leading Zeros Removal

    @Test func processTrendData_removesLeadingZeros() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let day3 = calendar.date(byAdding: .day, value: 2, to: today)!
        let endDate = calendar.date(byAdding: .day, value: 4, to: today)!

        let interval = DateInterval(start: today, end: endDate)

        // Transaction only on day3 - day1 and day2 should be leading zeros removed
        let tx = makeTransaction(amount: 100, amountInPreferred: 100, date: day3)

        let result = TrendDataProcessor.processTrendData(
            transactions: [tx],
            accounts: [],
            metric: .balance,
            period: .thisMonth,
            grouping: .day,
            interval: interval,
            currencyCode: "PEN"
        )
        // Leading zero buckets should be removed
        // Only the bucket containing day3 should remain
        #expect(!result.rawPoints.isEmpty)
        if let firstPoint = result.rawPoints.first {
            #expect(firstPoint.value != 0)
        }
    }

    // MARK: - processTrendData: liveBalanceOverride / liveAnchor

    @Test func processTrendData_withLiveBalanceOverride_returnsLiveAnchor() {
        // Curva histórica conserva sus puntos sin override; el saldo vivo se
        // expone como liveAnchor separado. finalBalance refleja el saldo vivo
        // (KPI bajo el chart sigue correcto).
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let day1 = today
        let day2 = calendar.date(byAdding: .day, value: 1, to: today)!
        let endDate = calendar.date(byAdding: .day, value: 2, to: today)!
        let interval = DateInterval(start: day1, end: endDate)

        let tx1 = makeTransaction(amount: 100, amountInPreferred: 100, date: day1)
        let tx2 = makeTransaction(amount: -30, amountInPreferred: -30, date: day2)

        let liveBalance = 9999.0
        let result = TrendDataProcessor.processTrendData(
            transactions: [tx1, tx2],
            accounts: [],
            metric: .balance,
            period: .thisMonth,
            grouping: .day,
            interval: interval,
            currencyCode: "PEN",
            liveBalanceOverride: .init(value: liveBalance, nativeBalances: [:])
        )

        #expect(result.liveAnchor != nil)
        #expect(result.liveAnchor?.value == liveBalance)
        // rawPoints/chartPoints sin override: la curva queda histórica.
        if let lastRaw = result.rawPoints.last {
            #expect(lastRaw.value == 70)  // running balance histórico (100 - 30)
        }
        if let lastChart = result.points.last {
            #expect(lastChart.value == 70)
        }
        // finalBalance ahora deriva del liveAnchor para el KPI.
        #expect(result.finalBalance == liveBalance)
    }

    @Test func processTrendData_withoutOverride_returnsNilLiveAnchor() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let interval = DateInterval(
            start: today,
            end: calendar.date(byAdding: .day, value: 1, to: today)!
        )
        let tx = makeTransaction(amount: 100, amountInPreferred: 100, date: today)

        let result = TrendDataProcessor.processTrendData(
            transactions: [tx],
            accounts: [],
            metric: .balance,
            period: .thisMonth,
            grouping: .day,
            interval: interval,
            currencyCode: "PEN",
            liveBalanceOverride: nil
        )
        #expect(result.liveAnchor == nil)
        #expect(result.finalBalance == 100)  // último histórico
    }

    @Test func processTrendData_liveAnchorAboveYDomain_expandsDomainUpper() {
        // Si el saldo vivo está MUY por encima del rango histórico, el yDomain
        // se extiende para incluirlo (sino el dot quedaría clipped).
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let interval = DateInterval(
            start: today,
            end: calendar.date(byAdding: .day, value: 1, to: today)!
        )
        let tx = makeTransaction(amount: 100, amountInPreferred: 100, date: today)

        let liveBalance = 5000.0
        let result = TrendDataProcessor.processTrendData(
            transactions: [tx],
            accounts: [],
            metric: .balance,
            period: .thisMonth,
            grouping: .day,
            interval: interval,
            currencyCode: "PEN",
            liveBalanceOverride: .init(value: liveBalance, nativeBalances: [:])
        )
        #expect(result.yDomain.upperBound >= liveBalance)
    }

    @Test func processTrendData_liveAnchorBelowYDomain_expandsDomainLower() {
        // Caso simétrico: liveBalance negativo muy por debajo del rango.
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let interval = DateInterval(
            start: today,
            end: calendar.date(byAdding: .day, value: 1, to: today)!
        )
        let tx = makeTransaction(amount: 100, amountInPreferred: 100, date: today)

        let liveBalance = -2000.0
        let result = TrendDataProcessor.processTrendData(
            transactions: [tx],
            accounts: [],
            metric: .balance,
            period: .thisMonth,
            grouping: .day,
            interval: interval,
            currencyCode: "PEN",
            liveBalanceOverride: .init(value: liveBalance, nativeBalances: [:])
        )
        #expect(result.yDomain.lowerBound <= liveBalance)
    }

    @Test func processTrendData_liveAnchor_dateIsStartOfToday() {
        // El liveAnchor.date es startOfDay(Date.now): estabilizado para que
        // PanelTrendData Equatable mantenga su cache entre renders (Date.now
        // a microsegundos invalidaría la struct cada vez).
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let interval = DateInterval(
            start: today,
            end: calendar.date(byAdding: .day, value: 1, to: today)!
        )
        let tx = makeTransaction(amount: 100, amountInPreferred: 100, date: today)

        let result = TrendDataProcessor.processTrendData(
            transactions: [tx],
            accounts: [],
            metric: .balance,
            period: .thisMonth,
            grouping: .day,
            interval: interval,
            currencyCode: "PEN",
            liveBalanceOverride: .init(value: 500, nativeBalances: [:])
        )
        let expectedDate = calendar.startOfDay(for: Date.now)
        #expect(result.liveAnchor?.date == expectedDate)
    }

    @Test func processTrendData_liveAnchor_dateIsStableAcrossCalls() {
        // Dos llamadas consecutivas con el mismo input deben producir el mismo
        // liveAnchor.date — invariante necesaria para que el guard
        // `if result.liveAnchor != trendLiveAnchor` filtre no-ops.
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let interval = DateInterval(
            start: today,
            end: calendar.date(byAdding: .day, value: 1, to: today)!
        )
        let tx = makeTransaction(amount: 100, amountInPreferred: 100, date: today)

        let r1 = TrendDataProcessor.processTrendData(
            transactions: [tx], accounts: [], metric: .balance,
            period: .thisMonth, grouping: .day, interval: interval,
            currencyCode: "PEN", liveBalanceOverride: .init(value: 500, nativeBalances: [:])
        )
        let r2 = TrendDataProcessor.processTrendData(
            transactions: [tx], accounts: [], metric: .balance,
            period: .thisMonth, grouping: .day, interval: interval,
            currencyCode: "PEN", liveBalanceOverride: .init(value: 500, nativeBalances: [:])
        )
        #expect(r1.liveAnchor == r2.liveAnchor)
    }

    @Test func processTrendData_emptyRawPoints_noLiveAnchor() {
        // Sin transacciones, no hay liveAnchor aunque se pase override —
        // construir el dot sin curva histórica de fondo no aporta señal.
        let interval = DateInterval(
            start: Date().addingTimeInterval(-86400),
            end: Date()
        )
        let result = TrendDataProcessor.processTrendData(
            transactions: [],
            accounts: [],
            metric: .balance,
            period: .last7Days,
            grouping: .day,
            interval: interval,
            currencyCode: "PEN",
            liveBalanceOverride: .init(value: 1000, nativeBalances: [:])
        )
        #expect(result.liveAnchor == nil)
    }

    @Test func processTrendData_incomeMetric_ignoresOverride() {
        // El liveAnchor solo aplica a métrica .balance — income/expense lo ignoran.
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let interval = DateInterval(
            start: today,
            end: calendar.date(byAdding: .day, value: 1, to: today)!
        )
        let tx = makeTransaction(amount: 100, amountInPreferred: 100, date: today)

        let result = TrendDataProcessor.processTrendData(
            transactions: [tx],
            accounts: [],
            metric: .income,
            period: .thisMonth,
            grouping: .day,
            interval: interval,
            currencyCode: "PEN",
            liveBalanceOverride: .init(value: 9999, nativeBalances: [:])
        )
        #expect(result.liveAnchor == nil)
    }

    // MARK: - Clasificación por categoría + signed (p20-14 Fase 2)

    @Test func totals_classifyByCategory_notSign() {
        // La categoría manda: income+monto negativo reduce income; expense+monto
        // positivo (reembolso) reduce expense. NO clasifica por signo.
        let now = Date()
        let interval = DateInterval(
            start: Calendar.current.startOfDay(for: now),
            end: now.addingTimeInterval(1)
        )
        let incomeCat = makeCategory(isIncome: true)
        let expenseCat = makeCategory(isIncome: false)
        let salary = makeTransaction(amount: 500, amountInPreferred: 500, date: now, category: incomeCat)
        let incomeRefund = makeTransaction(amount: -40, amountInPreferred: -40, date: now, category: incomeCat)
        let groceries = makeTransaction(amount: -100, amountInPreferred: -100, date: now, category: expenseCat)
        let expenseRefund = makeTransaction(amount: 30, amountInPreferred: 30, date: now, category: expenseCat)

        let result = TrendDataProcessor.processTrendData(
            transactions: [salary, incomeRefund, groceries, expenseRefund],
            accounts: [],
            metric: .balance,
            period: .thisMonth,
            grouping: .day,
            interval: interval,
            currencyCode: "PEN"
        )
        // income: 500 + (-40) = 460 ; expense: -(-100) + -(30) = 70
        #expect(result.totalIncome == 460)
        #expect(result.totalExpense == 70)
    }

    @Test func incomeKPI_matchesEndOfCurve_withDesyncedTx() {
        // AC-a: con una TX desincronizada (categoría income + monto negativo), el
        // KPI (totalIncome) coincide con el fin de la curva cumulativa .income.
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let day1 = today
        let day2 = calendar.date(byAdding: .day, value: 1, to: today)!
        let endDate = calendar.date(byAdding: .day, value: 2, to: today)!
        let interval = DateInterval(start: day1, end: endDate)
        let incomeCat = makeCategory(isIncome: true)

        let salary = makeTransaction(amount: 500, amountInPreferred: 500, date: day1, category: incomeCat)
        let refund = makeTransaction(amount: -120, amountInPreferred: -120, date: day2, category: incomeCat)

        let result = TrendDataProcessor.processTrendData(
            transactions: [salary, refund],
            accounts: [],
            metric: .income,
            period: .thisMonth,
            grouping: .day,
            interval: interval,
            currencyCode: "PEN"
        )
        #expect(result.totalIncome == 380)  // 500 - 120
        #expect(result.rawPoints.last?.value == 380)
        #expect(result.totalIncome == result.rawPoints.last?.value)
    }

    @Test func expenseCurve_refundLowersCurve() {
        // La curva .expense es signed: un reembolso (monto positivo en categoría
        // de gasto) baja la curva acumulada; el KPI coincide con el fin.
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let day1 = today
        let day2 = calendar.date(byAdding: .day, value: 1, to: today)!
        let endDate = calendar.date(byAdding: .day, value: 2, to: today)!
        let interval = DateInterval(start: day1, end: endDate)
        let expenseCat = makeCategory(isIncome: false)

        let spend = makeTransaction(amount: -100, amountInPreferred: -100, date: day1, category: expenseCat)
        let refund = makeTransaction(amount: 30, amountInPreferred: 30, date: day2, category: expenseCat)

        let result = TrendDataProcessor.processTrendData(
            transactions: [spend, refund],
            accounts: [],
            metric: .expense,
            period: .thisMonth,
            grouping: .day,
            interval: interval,
            currencyCode: "PEN"
        )
        #expect(result.rawPoints.first?.value == 100)      // gasto sube
        #expect(result.rawPoints.last?.value == 70)        // reembolso baja: 100 - 30
        #expect(result.totalExpense == 70)
        #expect(result.totalExpense == result.rawPoints.last?.value)
    }

    @Test func expenseCurve_refundDominant_yDomainIncludesNegative() {
        // Reembolsos > gastos → la curva .expense va negativa; el yDomain debe
        // incluir el valor negativo (no clipearlo al piso 0).
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let day1 = today
        let day2 = calendar.date(byAdding: .day, value: 1, to: today)!
        let endDate = calendar.date(byAdding: .day, value: 2, to: today)!
        let interval = DateInterval(start: day1, end: endDate)
        let expenseCat = makeCategory(isIncome: false)

        let spend = makeTransaction(amount: -50, amountInPreferred: -50, date: day1, category: expenseCat)
        let refund = makeTransaction(amount: 200, amountInPreferred: 200, date: day2, category: expenseCat)

        let result = TrendDataProcessor.processTrendData(
            transactions: [spend, refund],
            accounts: [],
            metric: .expense,
            period: .thisMonth,
            grouping: .day,
            interval: interval,
            currencyCode: "PEN"
        )
        // Curva: día1 = 50 ; día2 = 50 - 200 = -150.
        #expect(result.rawPoints.last?.value == -150)
        #expect(result.yDomain.lowerBound <= -150)
    }

    @Test func balanceInvariant_totalIncomeMinusExpense_equalsSignedSum() {
        // AC-b: income − expense == Σ montos con signo (excl. balance adjustments).
        let now = Date()
        let interval = DateInterval(
            start: Calendar.current.startOfDay(for: now),
            end: now.addingTimeInterval(1)
        )
        let incomeCat = makeCategory(isIncome: true)
        let expenseCat = makeCategory(isIncome: false)
        let txs = [
            makeTransaction(amount: 500, amountInPreferred: 500, date: now, category: incomeCat),
            makeTransaction(amount: -40, amountInPreferred: -40, date: now, category: incomeCat),
            makeTransaction(amount: -100, amountInPreferred: -100, date: now, category: expenseCat),
            makeTransaction(amount: 30, amountInPreferred: 30, date: now, category: expenseCat),
        ]
        let result = TrendDataProcessor.processTrendData(
            transactions: txs,
            accounts: [],
            metric: .balance,
            period: .thisMonth,
            grouping: .day,
            interval: interval,
            currencyCode: "PEN"
        )
        let signedSum = txs.reduce(0.0) { $0 + $1.amountInPreferredCurrency }  // 390
        #expect(result.totalIncome - result.totalExpense == signedSum)
    }

    // MARK: - Helper

    private func makeCategory(isIncome: Bool) -> YalaCategory {
        YalaCategory(name: isIncome ? "Salario" : "Comida", colorHex: "#000000", isIncome: isIncome)
    }

    private func makeTransaction(
        amount: Double,
        amountInPreferred: Double,
        date: Date,
        category: YalaCategory? = nil,
        balanceAdjustmentType: String? = nil
    ) -> TransactionItem {
        let tx = TransactionItem(
            date: date,
            amount: amount,
            currencyCode: "PEN",
            note: nil,
            category: category,
            amountInPreferredCurrency: amountInPreferred,
            preferredCurrencyCode: "PEN"
        )
        tx.balanceAdjustmentType = balanceAdjustmentType
        return tx
    }
}

/*
Tests generated:
1. smoothingWindowSize_is14 - Constant verification
2. smoothingThreshold_is30 - Constant verification
3. smoothingPeriods_containsLongPeriods - Smoothing period configuration
4. processTrendData_withNoTransactions_returnsEmptyResult - Empty input
5. processTrendData_calculatesIncomeTotalsCorrectly - Income total
6. processTrendData_calculatesExpenseTotalsCorrectly - Expense total
7. processTrendData_excludesBalanceAdjustmentsFromTotals - Balance adj exclusion
8. processTrendData_balance_calculatesRunningTotal - Running balance
9. processTrendData_balance_includesTransactionsBeforeInterval - Pre-interval carry
10. processTrendData_income_filtersPositiveTransactions - Income filtering
11. processTrendData_expense_filtersNegativeTransactions - Expense filtering
12. processTrendData_shortPeriod_doesNotSmooth - No smoothing on short periods
13. processTrendData_yDomain_isCalculatedFromRawPoints - Y domain calculation
14. processTrendData_removesLeadingZeros - Leading zero removal

Casos NO cubiertos:
- Smoothing behavior for long periods (requires >30 data points, complex to set up)
- Multi-currency conversion within processTrendData (uses amountInPreferredCurrency)
- Weekly/Monthly grouping buckets (tested indirectly via TrendGroupingTests)
*/
