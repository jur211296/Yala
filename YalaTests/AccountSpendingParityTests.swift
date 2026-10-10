//
//  AccountSpendingParityTests.swift
//  YalaTests
//
//  Ticket `panel-spent-per-account-counts-refunds-as-spending` (2026-10-10): una devolución (importe a favor en una
//  categoría de gasto) BAJA lo gastado por cuenta, en la tarjeta del Panel (`AccountSpendingLogic.spentByAccount`, la
//  función que llama `PanelViewModel.calculateAccountPeriodExpenses`) y en la vista de cuenta
//  (`AccountDetailCalculator`: «En qué se fue» y la curva del modo «solo gastos»). Las dos leen la misma regla.
//
//  Sin `ModelContext`: `@Model` en memoria, como `ChatContextGroupsToggleTests`.
//

import Foundation
import SwiftData
import Testing
@testable import Yala

@MainActor
@Suite("AccountSpendingParity")
struct AccountSpendingParityTests {

    private static var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Lima") ?? .current
        return c
    }

    private static func day(_ d: Int, month: Int = 10) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: d, hour: 12)) ?? .distantPast
    }

    /// Octubre entero, cerrado en 23:59:59 del 31 como `DetailPeriod.dateInterval`.
    private static var october: DateInterval {
        let start = calendar.date(from: DateComponents(year: 2026, month: 10, day: 1)) ?? .distantPast
        let end = calendar.date(byAdding: DateComponents(month: 1, second: -1), to: start) ?? start
        return DateInterval(start: start, end: end)
    }

    private let checking = Account(
        name: "Checking", currencyCode: "PEN", colorHex: "#000", iconName: "creditcard", type: "bank",
        excludeFromStatistics: false, isSystemAccount: false
    )
    private let super_ = YalaCategory(name: "Super", colorHex: "#000", isIncome: false)
    private let taxi = YalaCategory(name: "Taxi", colorHex: "#000", isIncome: false)
    private let salary = YalaCategory(name: "Sueldo", colorHex: "#000", isIncome: true)

    private func tx(_ amount: Double, _ category: YalaCategory?, day: Int, month: Int = 10) -> TransactionItem {
        let tx = TransactionItem(
            date: Self.day(day, month: month), amount: amount, currencyCode: "PEN", category: category,
            amountInPreferredCurrency: amount, preferredCurrencyCode: "PEN"
        )
        tx.account = checking
        return tx
    }

    /// Lo que enseña la tarjeta del Panel en modo «solo gastos».
    private func panelSpent(_ txs: [TransactionItem]) -> Double {
        AccountSpendingLogic.spentByAccount(txs, accounts: [checking.name], in: Self.october, key: \.name)[checking.name]
            ?? .nan
    }

    /// Los movimientos tal como los arma `AccountDetailSheet.recompute`.
    private func entries(_ txs: [TransactionItem]) -> [AccountDetailCalculator.Entry] {
        txs.enumerated().map { index, tx in
            AccountDetailCalculator.Entry(
                id: "\(index)", date: tx.date, amount: tx.amount, adjustmentType: tx.balanceAdjustmentType,
                categoryKey: tx.category?.name, categoryName: tx.category?.name, categoryColorHex: nil,
                categoryIsIncome: tx.category?.isIncome, title: "\(index)"
            )
        }
    }

    /// El último punto de la curva de lo gastado de la vista de cuenta.
    private func detailSpent(_ txs: [TransactionItem]) -> Double {
        AccountDetailCalculator.dailySpending(
            entries: entries(txs), interval: Self.october, now: Self.day(20), calendar: Self.calendar
        ).last?.balance ?? .nan
    }

    /// «En qué se fue» de la vista de cuenta, con el período aplicado como lo aplica `summary`.
    private func topCategories(_ txs: [TransactionItem]) -> [AccountDetailCalculator.CategoryTotal] {
        AccountDetailCalculator.summary(
            entries: entries(txs), interval: Self.october, now: Self.day(20), calendar: Self.calendar
        ).topCategories
    }

    // MARK: - El caso del ticket

    @Test func refund_lowersTheSpent_inThePanelAndInTheAccountView() {
        let txs = [tx(-100, super_, day: 2), tx(30, super_, day: 5)]

        #expect(panelSpent(txs) == 70)
        #expect(detailSpent(txs) == 70)
        let top = topCategories(txs)
        #expect(top.map(\.name) == ["Super"])
        #expect(top.first?.amount == 70)
    }

    @Test func withoutRefunds_theSpentIsWhatItWas() {
        let txs = [
            tx(-100, super_, day: 2), tx(-50, taxi, day: 3), tx(3000, salary, day: 1),
            tx(-40, super_, day: 30, month: 9), tx(-700, nil, day: 4),
        ]

        #expect(panelSpent(txs) == 150)
        #expect(detailSpent(txs) == 150)
        #expect(topCategories(txs).map(\.amount) == [100, 50])
    }

    // MARK: - Bordes de la regla

    /// Más devuelto que gastado: el neto se enseña negativo, y «En qué se fue» no pinta una categoría sin gasto.
    @Test func refundLargerThanSpending_isNegative_andLeavesNoCategory() {
        let txs = [tx(-20, super_, day: 2), tx(50, super_, day: 5), tx(-10, taxi, day: 6)]

        #expect(panelSpent(txs) == -20)
        #expect(detailSpent(txs) == -20)
        #expect(topCategories(txs).map(\.name) == ["Taxi"])
    }

    /// Un ingreso en categoría de ingreso y un ajuste no son devoluciones: no tocan lo gastado.
    @Test func incomeAndAdjustments_doNotCountAsRefunds() {
        let adjustment = tx(500, super_, day: 4)
        adjustment.balanceAdjustmentType = "transfer"
        let txs = [tx(-100, super_, day: 2), tx(3000, salary, day: 3), adjustment]

        #expect(panelSpent(txs) == 100)
        #expect(detailSpent(txs) == 100)
    }

    // MARK: - Paridad

    @Test func panelAndAccountView_agreeOnEveryScenario() {
        let scenarios: [[TransactionItem]] = [
            [],
            [tx(-100, super_, day: 2), tx(30, super_, day: 5)],
            [tx(-20, super_, day: 2), tx(50, super_, day: 5)],
            [tx(-100, super_, day: 2), tx(-50, taxi, day: 3), tx(25, taxi, day: 9), tx(3000, salary, day: 1)],
        ]
        for txs in scenarios {
            #expect(panelSpent(txs) == detailSpent(txs))
        }
    }

    // MARK: - Cableado del Panel

    /// La tarjeta del Panel no tiene un camino de test sin `ModelContext` ni `SessionState`, así que el cableado se fija
    /// por el fuente: el cuerpo ENTERO de `calculateAccountPeriodExpenses`, normalizado, para que volver a sumar a mano
    /// (con `abs` o sin él) o llamar a otra cosa lo ponga en rojo.
    @Test func panelCard_readsTheSharedRule() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(
            contentsOf: root.appendingPathComponent("Yala/App/ViewModels/PanelViewModel.swift"), encoding: .utf8
        )
        let lines = source.split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("//") }
        let start = try #require(lines.firstIndex(of: "private func calculateAccountPeriodExpenses() {"))
        let end = try #require(lines[start...].firstIndex(of: "}"))
        #expect(lines[start...end].joined(separator: " ") == [
            "private func calculateAccountPeriodExpenses() {",
            "let newExpenses = AccountSpendingLogic.spentByAccount(",
            "transactions,",
            "accounts: accounts.map(\\.persistentModelID),",
            "in: panelDateInterval,",
            "key: \\.persistentModelID",
            ")",
            "if newExpenses != accountPeriodExpenses { accountPeriodExpenses = newExpenses }",
            "}",
        ].joined(separator: " "))
    }
}
