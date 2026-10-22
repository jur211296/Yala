//
//  PanelBalanceScopeTests.swift
//  YalaTests
//
//  Ticket `hoja-del-saldo-vivo-ignora-los-filtros-de-sesion`, decisión de Jürgen del 2026-10-22: el saldo de arriba
//  del Panel, la curva de saldo y la hoja «¿Cuánto tienes hoy?» suman lo mismo. Las mismas cuentas —con el
//  interruptor de Grupos— y todos sus movimientos, sin los chips de filtro.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Panel · el saldo de arriba y la hoja «¿Cuánto tienes hoy?» suman lo mismo")
struct PanelBalanceScopeTests {

    private let banco = Account(name: "Banco", currencyCode: "PEN", colorHex: "#6366F1", iconName: "creditcard", type: "bank")
    private let grupos: Account = {
        let cuenta = Account(name: "Grupos PEN", currencyCode: "PEN", colorHex: "#999999", iconName: "person.3", type: "system")
        cuenta.isSystemAccount = true
        return cuenta
    }()

    private func tx(_ amount: Double, _ account: Account, note: String) -> TransactionItem {
        let tx = TransactionItem(
            date: Date(timeIntervalSinceNow: -86_400 * 3), amount: amount, currencyCode: "PEN", note: note,
            category: nil, account: account, tags: [], amountInPreferredCurrency: amount
        )
        tx.preferredCurrencyCode = "PEN"
        return tx
    }

    /// Banco: 3.800 (de ellos 500 «etiquetados»). Grupos PEN: 1.900. Con el interruptor apagado, arriba dice 3.800.
    private var movimientos: [TransactionItem] {
        [tx(3300, banco, note: "sueldo"), tx(500, banco, note: "viaje"), tx(1900, grupos, note: "grupo")]
    }

    /// El número grande de arriba, como lo calcula `PanelViewModel.displayedBalanceInDefaultCurrency`.
    private func arriba(includeGroups: Bool, selected: Set<PersistentIdentifier> = [], exclude: Bool = false) -> Double {
        let cuentas = PanelTotalAccountsLogic.accountsForTotal(
            [banco, grupos], includeGroups: includeGroups,
            hasSelectedAccount: PanelTotalAccountsLogic.hasAccountFilter(selectedAccountIDs: selected, isExcludeMode: exclude))
        let breakdown = LiveBalanceCalculator.liveBalanceBreakdown(
            accounts: cuentas, transactions: movimientos, preferredCurrencyCode: "PEN",
            selectedAccountIDs: selected, isExcludeMode: exclude)
        return NSDecimalNumber(decimal: breakdown.convertedTotal).doubleValue
    }

    /// La hoja: el ancla viva de la curva de saldo, con las cuentas y los movimientos del alcance del saldo.
    private func hoja(includeGroups: Bool, eligible: [Account], selected: Set<PersistentIdentifier> = [],
                      exclude: Bool = false) -> Double? {
        let cuentas = PanelBalanceScopeLogic.accounts(
            eligible: eligible, includeGroups: includeGroups, selectedAccountIDs: selected, isExcludeMode: exclude)
        let filas = PanelBalanceScopeLogic.transactions(movimientos, accountIDs: Set(cuentas.map(\.persistentModelID)))
        return LiveBalanceCalculator.liveBalanceOverride(
            for: .balance, interval: DateInterval(start: .distantPast, end: .distantFuture),
            accounts: cuentas, transactions: filas, preferredCurrencyCode: "PEN")?.value
    }

    @Test("Interruptor de Grupos apagado: la hoja dice 3.800, como arriba (antes 5.700)")
    func groupsToggleOff() {
        #expect(arriba(includeGroups: false) == 3800)
        #expect(hoja(includeGroups: false, eligible: [banco, grupos]) == 3800)
    }

    @Test("Interruptor encendido: los dos 5.700")
    func groupsToggleOn() {
        #expect(arriba(includeGroups: true) == 5700)
        #expect(hoja(includeGroups: true, eligible: [banco, grupos]) == 5700)
    }

    @Test("Con un filtro de cuentas el interruptor no aplica, en los dos")
    func accountFilter() {
        let soloGrupos: Set = [grupos.persistentModelID]
        #expect(arriba(includeGroups: false, selected: soloGrupos) == 1900)
        #expect(hoja(includeGroups: false, eligible: [grupos], selected: soloGrupos) == 1900)
    }

    @Test("Excluir una cuenta sigue siendo un agregado: el interruptor sigue aplicando")
    func excludeMode() {
        let sinBanco: Set = [banco.persistentModelID]
        #expect(arriba(includeGroups: false, selected: sinBanco, exclude: true) == 0)
        #expect(hoja(includeGroups: false, eligible: [grupos], selected: sinBanco, exclude: true) == 0)
    }

    @Test("Los movimientos del saldo no pasan por los chips: están todos los de las cuentas")
    func chipsDoNotMoveTheBalance() {
        let filas = PanelBalanceScopeLogic.transactions(movimientos, accountIDs: [banco.persistentModelID])
        #expect(filas.count == 2)
        #expect(filas.contains { $0.note == "viaje" } && filas.contains { $0.note == "sueldo" })
    }

    // MARK: - Cableado

    private static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()

    @Test("El Panel arma el saldo con el alcance común y lo pasa a la curva y a la comparativa")
    func wiring() throws {
        let code = try String(
            contentsOf: Self.repoRoot.appendingPathComponent("Yala/App/ViewModels/PanelViewModel.swift"), encoding: .utf8)
        #expect(code.contains("let balanceAccounts = PanelBalanceScopeLogic.accounts("))
        #expect(code.contains("let balanceTransactions = PanelBalanceScopeLogic.transactions("))
        #expect(!code.contains("let balanceCriteria"), "el saldo volvió a pasar por los chips")
        // Las dos llamadas al ancla viva (curva del widget y comparativa) cuentan las cuentas del saldo.
        let anclas = code.components(separatedBy: "LiveBalanceCalculator.liveBalanceOverride(").dropFirst()
        #expect(anclas.count == 2)
        for ancla in anclas {
            let tramo = ancla.prefix(400)
            #expect(tramo.contains("accounts: calcContext.balanceAccounts") || tramo.contains("accounts: context.balanceAccounts"),
                    "un ancla viva no usa las cuentas del saldo: \(tramo)")
        }
    }
}
