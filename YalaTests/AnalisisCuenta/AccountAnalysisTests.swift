//
//  AccountAnalysisTests.swift
//  YalaTests
//
//  La ficha de una cuenta rediseñada con las gráficas de los widgets del Panel (2026-11-16, ticket `analisis-por-cuenta`):
//  lo que `AccountAnalysisBuilder` les da de comer y los gastos más grandes de `AccountDetailCalculator`. Fija:
//  - que la curva acaba en la cifra de la tarjeta también con el suavizado de los períodos largos;
//  - que una tarjeta de crédito con saldo negativo dibuja la deuda bajo cero, sin recortarla;
//  - que la tarta suma lo gastado de la tarjeta en «solo gastos», con «Sin categoría», devoluciones y transferencias;
//  - que con varias monedas la línea en dólares suma en dólares, no lo guardado en la divisa preferida;
//  - que la comparación es contra el período anterior HASTA HOY, y que «Todo el tiempo» no compara.
//
//  Sin `ModelContext`: `@Model` en memoria, como `TopSpendingCategoriesCalculatorTests`. El «ahora» es fijo (Lima).
//

import Foundation
import Testing
@testable import Yala

@MainActor
@Suite("AccountAnalysis")
struct AccountAnalysisTests {

    private static var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Lima") ?? .current
        return c
    }

    private static func day(_ d: Int, month: Int = 11, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: d, hour: hour)) ?? .distantPast
    }

    /// 16 de noviembre de 2026 a las 15:00 en Lima.
    private static let now = day(16, hour: 15)

    private static func interval(_ period: DetailPeriod) -> DateInterval {
        period.dateInterval(customRange: nil, now: now, calendar: calendar)
    }

    private let checking = Account(
        name: "Banco", currencyCode: "PEN", colorHex: "#000", iconName: "building.columns", type: "bank",
        excludeFromStatistics: false, isSystemAccount: false
    )
    private let super_ = YalaCategory(name: "Super", colorHex: "#111", isIncome: false)
    private let taxi = YalaCategory(name: "Taxi", colorHex: "#222", isIncome: false)
    private let salary = YalaCategory(name: "Sueldo", colorHex: "#333", isIncome: true)

    private func tx(
        _ amount: Double, _ category: YalaCategory?, _ date: Date, account: Account? = nil,
        currency: String = "PEN", stored: Double? = nil, storedCurrency: String = "PEN", adjustment: String? = nil
    ) -> TransactionItem {
        let tx = TransactionItem(
            date: date, amount: amount, currencyCode: currency, category: category,
            amountInPreferredCurrency: stored ?? amount, preferredCurrencyCode: storedCurrency
        )
        tx.account = account ?? checking
        tx.balanceAdjustmentType = adjustment
        return tx
    }

    /// Los movimientos tal como los arma `AccountDetailSheet.recompute`.
    private func entries(_ txs: [TransactionItem]) -> [AccountDetailCalculator.Entry] {
        txs.enumerated().map { index, tx in
            AccountDetailCalculator.Entry(
                id: String(format: "%03d", index), date: tx.date, amount: tx.amount,
                adjustmentType: tx.balanceAdjustmentType, categoryKey: tx.category?.name,
                categoryName: tx.category?.name, categoryColorHex: nil, categoryIsIncome: tx.category?.isIncome,
                title: "\(index)"
            )
        }
    }

    private func build(
        _ txs: [TransactionItem], period: DetailPeriod, currency: String = "PEN", expensesOnly: Bool = false,
        converter: CurrencyConverting? = nil
    ) -> AccountAnalysis {
        let interval = Self.interval(period)
        let rows = entries(txs)
        let series = expensesOnly
            ? AccountDetailCalculator.dailySpending(entries: rows, interval: interval, now: Self.now, calendar: Self.calendar)
            : AccountDetailCalculator.dailyBalances(entries: rows, interval: interval, now: Self.now, calendar: Self.calendar)
        return AccountAnalysisBuilder.build(
            transactions: txs, entries: rows, series: series, period: period, customRange: nil,
            interval: interval, currencyCode: currency, isExpensesOnlyMode: expensesOnly,
            now: Self.now, calendar: Self.calendar, converter: converter ?? MockCurrencyConverter()
        )
    }

    // MARK: - La curva

    @Test("Con el suavizado de un año, el último punto sigue siendo la cifra de la tarjeta")
    func trend_longPeriod_lastPointIsTheCardBalance() {
        var txs = [tx(1_000, nil, Self.day(2, month: 1), adjustment: InitialBalanceService.typeInitialBalance)]
        for month in 1...11 {
            txs.append(tx(-Double(40 * month), super_, Self.day(5, month: month)))
            txs.append(tx(-Double(15 * month), taxi, Self.day(20, month: month)))
        }
        let analysis = build(txs, period: .thisYear)
        let card = AccountBalanceLike.sum(txs, until: Self.now)

        #expect(analysis.trend.rawPoints.count > TrendDataProcessor.smoothingThreshold)
        #expect(analysis.trend.points != analysis.trend.rawPoints, "En un año la curva se suaviza, como en el Panel.")
        #expect(analysis.trend.points.last?.value == card)
        #expect(analysis.trend.rawPoints.last?.value == card)
        #expect(analysis.trend.type == .balance)
    }

    @Test("Una tarjeta de crédito con saldo negativo dibuja la deuda bajo cero, sin recortarla")
    func trend_creditCard_negativeBalanceStaysInsideTheAxis() {
        let card = Account(
            name: "Visa", currencyCode: "PEN", colorHex: "#000", iconName: "creditcard",
            type: AccountType.creditCard.rawValue, excludeFromStatistics: false, isSystemAccount: false
        )
        let txs = [
            tx(-300, super_, Self.day(3), account: card),
            tx(-450, taxi, Self.day(8), account: card),
            tx(200, nil, Self.day(10), account: card, adjustment: TransactionItem.adjustmentTypeTransfer),
        ]
        let analysis = build(txs, period: .thisMonth)

        #expect(analysis.trend.rawPoints.last?.value == -550)
        #expect(analysis.trend.yDomain.lowerBound <= -750, "El punto más bajo (−750) quedaría fuera del eje.")
        #expect(analysis.trend.yDomain.upperBound >= -300)
        // Lo gastado no cuenta el pago a la tarjeta (una transferencia).
        #expect(analysis.categories.reduce(0) { $0 + $1.amount } == 750)
    }

    @Test("En «solo gastos» la curva es lo gastado acumulado")
    func trend_expensesOnly_isTheSpendingCurve() {
        let txs = [tx(-100, super_, Self.day(2)), tx(30, super_, Self.day(4)), tx(500, salary, Self.day(5))]
        let analysis = build(txs, period: .thisMonth, expensesOnly: true)
        #expect(analysis.trend.type == .expense)
        #expect(analysis.trend.rawPoints.last?.value == 70)
    }

    // MARK: - La tarta y el flujo

    /// Un gasto, una devolución, uno sin categoría, un ingreso, una transferencia y un ajuste.
    private func mixedMonth() -> [TransactionItem] {
        [
            tx(-200, super_, Self.day(3)),
            tx(50, super_, Self.day(6)),
            tx(-80, taxi, Self.day(7)),
            tx(-40, nil, Self.day(9)),
            tx(3_000, salary, Self.day(1)),
            tx(-500, nil, Self.day(10), adjustment: TransactionItem.adjustmentTypeTransfer),
            tx(-25, nil, Self.day(11), adjustment: InitialBalanceService.typeAdjustment),
        ]
    }

    @Test("La tarta suma lo gastado de la tarjeta en «solo gastos», con «Sin categoría»")
    func categories_sumWhatTheCardShowsAsSpent() {
        let txs = mixedMonth()
        let analysis = build(txs, period: .thisMonth)
        let cardSpent = AccountSpendingLogic.spentByAccount(
            txs, accounts: [checking.name], in: Self.interval(.thisMonth), key: \.name
        )[checking.name]

        #expect(cardSpent == 270)
        #expect(analysis.categories.reduce(0) { $0 + $1.amount } == cardSpent)
        #expect(analysis.categories.contains { $0.isUncategorized && $0.amount == 40 })
        #expect(analysis.categories.first { $0.name == "Super" }?.amount == 150, "La devolución resta.")
    }

    @Test("El flujo deja fuera transferencias y ajustes, como el widget del Panel")
    func cashFlow_excludesTransfersAndAdjustments() {
        let analysis = build(mixedMonth(), period: .thisMonth)
        #expect(analysis.cashFlow.totalIncome == 3_000)
        #expect(analysis.cashFlow.totalExpense == 270)
        #expect(analysis.cashFlow.netFlow == 2_730)
        #expect(analysis.cashFlowGrouping == .day)
    }

    @Test("El flujo cuenta solo el período: lo de meses anteriores no entra")
    func cashFlow_onlyCountsThePeriod() {
        let txs = mixedMonth() + [tx(9_000, salary, Self.day(5, month: 10)), tx(-700, super_, Self.day(20, month: 9))]
        let analysis = build(txs, period: .thisMonth)
        #expect(analysis.cashFlow.totalIncome == 3_000)
        #expect(analysis.cashFlow.totalExpense == 270)
        #expect(analysis.categories.reduce(0) { $0 + $1.amount } == 270)
    }

    @Test("Con varias monedas, la línea en dólares suma en dólares y no lo guardado en la preferida")
    func multiCurrency_usdLine_sumsInDollars() {
        let usd = Account(
            name: "Visa USD", currencyCode: "USD", colorHex: "#000", iconName: "creditcard",
            type: AccountType.creditCard.rawValue, excludeFromStatistics: false, isSystemAccount: false
        )
        // Guardados en soles (la divisa preferida) a 3,7: leerlos daría 370 y 185.
        let txs = [
            tx(-100, super_, Self.day(3), account: usd, currency: "USD", stored: -370, storedCurrency: "PEN"),
            tx(-50, nil, Self.day(4), account: usd, currency: "USD", stored: -185, storedCurrency: "PEN"),
        ]
        let analysis = build(txs, period: .thisMonth, currency: "USD", converter: MockCurrencyConverter(fixedRate: 3.7))
        #expect(analysis.categories.reduce(0) { $0 + $1.amount } == 150)
        #expect(analysis.cashFlow.totalExpense == 150)
        #expect(analysis.cashFlow.currencyCode == "USD")
        #expect(analysis.trend.rawPoints.last?.value == -150)
    }

    // MARK: - Comparación con el período anterior

    @Test("Este mes se compara con el mes anterior hasta el mismo día")
    func comparison_thisMonth_isLastMonthUntilTheSameDay() {
        let txs = [
            tx(-100, super_, Self.day(5)),
            tx(-60, super_, Self.day(10, month: 10)),
            tx(-999, taxi, Self.day(25, month: 10)),
        ]
        let analysis = build(txs, period: .thisMonth)
        #expect(analysis.previousSpent == 60, "El 25 de octubre cae después del 16: no entra.")
        #expect(analysis.previousCashFlowAmount == -60)
    }

    @Test("En «solo gastos» el flujo se compara con lo gastado, no con el neto")
    func comparison_expensesOnly_comparesSpending() {
        let txs = [tx(-60, super_, Self.day(10, month: 10)), tx(900, salary, Self.day(2, month: 10))]
        let analysis = build(txs, period: .thisMonth, expensesOnly: true)
        #expect(analysis.previousCashFlowAmount == 60)
    }

    @Test("«Todo el tiempo» no compara")
    func comparison_allTime_hasNone() {
        let analysis = build(mixedMonth(), period: .allTime)
        #expect(analysis.previousSpent == nil)
        #expect(analysis.previousCashFlowAmount == nil)
        #expect(analysis.cashFlowGrouping == .month)
    }

    // MARK: - Los gastos más grandes

    @Test("Los tres gastos más grandes, de mayor a menor, sin ingresos, devoluciones ni transferencias")
    func largestExpenses_topThreeBySpent() {
        let txs = mixedMonth() + [tx(-120, taxi, Self.day(12)), tx(-15, super_, Self.day(13))]
        let largest = build(txs, period: .thisMonth).largestExpenses
        #expect(largest.map(\.amount) == [-200, -120, -80])
    }

    @Test("Un gasto fuera del período no entra entre los más grandes")
    func largestExpenses_onlyInThePeriod() {
        let txs = [tx(-5_000, super_, Self.day(2, month: 10)), tx(-10, taxi, Self.day(2))]
        #expect(build(txs, period: .thisMonth).largestExpenses.map(\.amount) == [-10])
    }
}

/// La suma de la tarjeta de una cuenta (`AccountBalanceCalculator`) para filas de su divisa: todo lo fechado hasta hoy.
private enum AccountBalanceLike {
    static func sum(_ txs: [TransactionItem], until now: Date) -> Double {
        txs.filter { $0.date <= now }.reduce(0) { $0 + $1.amount }
    }
}
