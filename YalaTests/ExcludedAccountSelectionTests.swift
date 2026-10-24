//
//  ExcludedAccountSelectionTests.swift
//  YalaTests
//
//  Ticket `saldo-con-seleccion-no-contable-diverge-entre-panel-y-estadisticas` (card shhm). Decisión A de Jürgen
//  (2026-10-08): con el Panel filtrado por una cuenta excluida de estadísticas, el saldo grande, los widgets y el KPI de
//  Distribución dicen 0 los tres. Hasta el 2026-10-23 el saldo grande caía al total agregado.
//
//  Y borrar una cuenta filtrada la quita del filtro de sesión: antes su ID sobrevivía y el Panel se quedaba en 0 sin
//  chip que lo explicara.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Cuenta excluida filtrada · las tres piezas dicen 0", .serialized)
struct ExcludedAccountSelectionTests {

    private func account(_ name: String, excluded: Bool = false) -> Account {
        Account(
            name: name, currencyCode: "PEN", colorHex: "#000", iconName: "creditcard", type: "bank",
            excludeFromStatistics: excluded
        )
    }

    private func tx(_ amount: Double, _ account: Account) -> TransactionItem {
        TransactionItem(
            date: Date.now.addingTimeInterval(-60), amount: amount, currencyCode: "PEN", account: account,
            amountInPreferredCurrency: amount, preferredCurrencyCode: "PEN"
        )
    }

    /// La regla de elegibilidad que comparten `PanelViewModel.computeEligibleAccounts` (widgets del Panel) y
    /// `StatisticsViewModel.computeEligibleAccounts` (KPI de Distribución), las dos `private`; `BalanceKPIParityTests`
    /// la copia igual y fija que no divergen.
    private func eligible(_ accounts: [Account], selected: Set<PersistentIdentifier>) -> [Account] {
        accounts.filter { account in
            guard !account.excludeFromStatistics else { return false }
            if selected.isEmpty { return true }
            return selected.contains(account.persistentModelID)
        }
    }

    @Test("Saldo grande, widgets y Distribución dan 0 con una cuenta excluida filtrada")
    func excludedSelection_allThreePiecesAreZero() {
        let included = account("Sueldo")
        let excluded = account("Ahorro fuera", excluded: true)
        let accounts = [included, excluded]
        let txs = [tx(200, included), tx(999, excluded)]
        let selected: Set<PersistentIdentifier> = [excluded.persistentModelID]
        let converter = MockCurrencyConverter()

        // Saldo grande del Panel: todas las cuentas + el filtro.
        let bigBalance = LiveBalanceCalculator.liveBalance(
            accounts: accounts, transactions: txs, preferredCurrencyCode: "PEN",
            selectedAccountIDs: selected, converter: converter
        )
        // Widgets del Panel y KPI de Distribución: las cuentas elegibles, ya filtradas.
        let eligibleAccounts = eligible(accounts, selected: selected)
        let distribution = LiveBalanceCalculator.liveBalance(
            accounts: eligibleAccounts, transactions: txs, preferredCurrencyCode: "PEN", converter: converter
        )

        #expect(eligibleAccounts.isEmpty)
        #expect(bigBalance == 0, "saldo grande: \(bigBalance) (200 era el fallback al total)")
        #expect(distribution == 0)
        #expect(bigBalance == distribution)
    }

    @Test("Borrar la cuenta filtrada la quita del filtro; borrar otra no lo toca")
    func deletingAFilteredAccount_clearsItFromTheSessionFilter() throws {
        let session = SessionState.shared
        let previousSelection = session.selectedAccountIDs
        let previousExclude = session.isExcludeMode
        defer {
            session.selectedAccountIDs = previousSelection
            session.isExcludeMode = previousExclude
            EntityDeletionService.shared.setContext(nil)
        }

        let context = try makeTestContext()
        let filtered = makeTestAccount(context: context, name: "Filtrada")
        let other = makeTestAccount(context: context, name: "Otra")
        let kept = makeTestAccount(context: context, name: "Se queda")
        try context.save()
        EntityDeletionService.shared.setContext(context)

        session.selectedAccountIDs = [filtered.persistentModelID, kept.persistentModelID]

        try EntityDeletionService.shared.deleteAccount(other)
        #expect(session.selectedAccountIDs == [filtered.persistentModelID, kept.persistentModelID])

        let filteredID = filtered.persistentModelID
        try EntityDeletionService.shared.deleteAccount(filtered)
        #expect(!session.selectedAccountIDs.contains(filteredID))
        #expect(session.selectedAccountIDs == [kept.persistentModelID])
    }
}
