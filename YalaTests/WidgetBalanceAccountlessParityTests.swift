//
//  WidgetBalanceAccountlessParityTests.swift
//  YalaTests
//
//  Card `tablero-la-cifra-y-la-curva-del-widget-de-saldo-zyah`: la cifra del widget de saldo
//  (`WidgetDataCache.buildPeriodSummary`, `periodBalance`) contaba las filas sin cuenta, y el último punto de su curva
//  —el saldo vivo— no. Desde el 2026-10-23 las dos leen `LiveBalanceCalculator.entersBalance`.
//
//  Discriminante: con la regla vieja la cifra sale 500 por encima (la fila sin cuenta).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Widget de saldo · cifra y curva cuentan las mismas filas")
struct WidgetBalanceAccountlessParityTests {

    private let account = Account(name: "Main", currencyCode: "PEN", colorHex: "#000", iconName: "x", type: "bank")

    private func tx(_ amount: Double, account: Account?, date: Date) -> TransactionItem {
        TransactionItem(
            date: date, amount: amount, currencyCode: "PEN", account: account,
            amountInPreferredCurrency: amount, preferredCurrencyCode: "PEN"
        )
    }

    @Test("La cifra del período en curso es el saldo vivo, el último punto de la curva")
    func currentPeriodBalance_equalsTheLiveBalance() {
        let now = Date.now
        let earlier = now.addingTimeInterval(-2 * 86_400)  // dos días atrás: la curva tiene un punto de ayer
        let txs = [
            tx(1_000, account: account, date: earlier),
            tx(-200, account: account, date: earlier),
            tx(500, account: nil, date: earlier),  // movimiento sin cuenta
        ]
        let converter = MockCurrencyConverter()
        let interval = DetailPeriod.thisMonth.dateInterval(now: now)

        let live = LiveBalanceCalculator.liveBalance(
            accounts: [account], transactions: txs, preferredCurrencyCode: "PEN", converter: converter
        )
        let summary = WidgetDataCache.buildPeriodSummary(
            transactions: txs, periodStart: interval.start, periodEnd: interval.end, currencyCode: "PEN",
            allTransactionsForBalance: txs, converter: converter
        )
        let trend = WidgetDataCache.buildTrendData(
            transactions: txs, totalBalance: live, currencyCode: "PEN", converter: converter
        )

        #expect(live == 800)
        #expect(summary.periodBalance == 800, "cifra: \(String(describing: summary.periodBalance)) (1.300 con la fila sin cuenta)")
        #expect(trend.dailyPoints.last?.balance == summary.periodBalance)
        // Y el punto de ayer, que la curva calcula ella sola, no salta respecto a hoy.
        #expect(trend.dailyPoints.dropLast().last?.balance == 800)
    }

    @Test("Un período cerrado tampoco cuenta la fila sin cuenta")
    func closedPeriodBalance_skipsAccountlessRows() {
        let now = Date.now
        let lastMonth = DetailPeriod.lastMonth.dateInterval(now: now)
        let inLastMonth = lastMonth.start.addingTimeInterval(86_400)
        let txs = [
            tx(1_000, account: account, date: inLastMonth),
            tx(500, account: nil, date: inLastMonth),
        ]
        let summary = WidgetDataCache.buildPeriodSummary(
            transactions: txs, periodStart: lastMonth.start, periodEnd: lastMonth.end, currencyCode: "PEN",
            allTransactionsForBalance: txs, converter: MockCurrencyConverter()
        )
        #expect(summary.periodBalance == 1_000)
    }

    /// El movimiento sin cuenta tampoco entra en los ingresos y gastos de los widgets: la app lo deja fuera con su filtro de
    /// cuentas elegibles (Panel, Registros, Estadísticas), y hasta el 2026-10-23 los widgets lo contaban.
    @Test("Los widgets dejan fuera el movimiento sin cuenta, como la app")
    func accountlessRow_isNotInTheWidgets() {
        let excluded = Account(
            name: "Fuera", currencyCode: "PEN", colorHex: "#000", iconName: "x", type: "bank", excludeFromStatistics: true
        )
        let now = Date.now
        let withAccount = tx(100, account: account, date: now)
        let accountless = tx(500, account: nil, date: now)
        let inExcluded = tx(70, account: excluded, date: now)
        let excludedIDs: Set<PersistentIdentifier> = [excluded.persistentModelID]

        #expect(WidgetDataCache.countsForWidgets(withAccount, excludedAccountIDs: excludedIDs))
        #expect(!WidgetDataCache.countsForWidgets(accountless, excludedAccountIDs: excludedIDs))
        #expect(!WidgetDataCache.countsForWidgets(inExcluded, excludedAccountIDs: excludedIDs))
    }
}
