//
//  WidgetTrendFutureOnlyLedgerTests.swift
//  YalaTests
//
//  Un libro cuyo primer movimiento es futuro no tumba la curva del widget de inicio (card
//  `tablero-el-widget-revienta-si-todos-tus-movimien-ba87`). `buildTrendData` contaba los días desde el movimiento más
//  antiguo hasta hoy; con todo en el futuro la cuenta salía negativa y `0..<días` cerraba la app al guardar
//  (`DraftService.approveDraft → WidgetDataCache.updateCache`). Acotada a 0, la curva empieza hoy, como un libro vacío.
//

import Foundation
import Testing

@testable import Yala

@MainActor
struct WidgetTrendFutureOnlyLedgerTests {

    private let calendar = Calendar.current

    private func tx(_ amount: Double, daysFromToday days: Int, _ account: Account) -> TransactionItem {
        let startOfToday = calendar.startOfDay(for: .now)
        let date = calendar.date(byAdding: .day, value: days, to: startOfToday)!
        return TransactionItem(
            date: date, amount: amount, currencyCode: account.currencyCode, account: account,
            amountInPreferredCurrency: amount, preferredCurrencyCode: "PEN"
        )
    }

    private func account() -> Account {
        Account(name: "Cuenta", currencyCode: "PEN", colorHex: "#6366F1", iconName: "creditcard", type: "bank")
    }

    /// Lo más antiguo es de mañana: la curva tiene el punto de hoy (el saldo vivo), como un libro vacío. Sin el tope,
    /// la cuenta de días era -1 y la curva diaria salía sin ningún punto.
    @Test func firstMovementTomorrow_curveStartsToday() {
        let acc = account()
        let trend = WidgetDataCache.buildTrendData(
            transactions: [tx(-50, daysFromToday: 1, acc)], totalBalance: 0, currencyCode: "PEN",
            converter: MockCurrencyConverter()
        )
        #expect(trend.dailyPoints.count == 1)
        #expect(trend.dailyPoints.last?.balance == 0)
        #expect(trend.weeklyPoints.count == 1)
        #expect(trend.monthlyPoints.count == 1)
    }

    /// Lo más antiguo es de dentro de una semana: sin el tope, `0..<-6` cerraba el proceso.
    @Test func allMovementsWeeksAhead_doesNotCrash() {
        let acc = account()
        let rows = [tx(-80, daysFromToday: 7, acc), tx(1200, daysFromToday: 40, acc)]
        let trend = WidgetDataCache.buildTrendData(
            transactions: rows, totalBalance: 0, currencyCode: "PEN", converter: MockCurrencyConverter()
        )
        #expect(trend.dailyPoints.count == 1)
        #expect(trend.weeklyPoints.count == 1)
        #expect(trend.monthlyPoints.count == 1)
    }
}
