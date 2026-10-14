//
//  PanelTotalAccountsLogicTests.swift
//  YalaTests
//
//  Tests pure-logic para PanelTotalAccountsLogic.accountsForTotal.
//  Sin ModelContext — crea Account directos (solo se lee isSystemAccount).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
struct PanelTotalAccountsLogicTests {

    private func makeAccount(_ name: String, isSystem: Bool) -> Account {
        Account(
            name: name,
            currencyCode: "PEN",
            colorHex: "#000000",
            iconName: "creditcard",
            type: "checking",
            isSystemAccount: isSystem
        )
    }

    @Test func includeGroups_total_returnsAll() {
        let accts = [makeAccount("BCP", isSystem: false), makeAccount("Grupos PEN", isSystem: true)]
        let r = PanelTotalAccountsLogic.accountsForTotal(accts, includeGroups: true, hasSelectedAccount: false)
        #expect(r.count == 2)
    }

    @Test func excludeGroups_total_dropsSystemAccounts() {
        let accts = [makeAccount("BCP", isSystem: false), makeAccount("Grupos PEN", isSystem: true)]
        let r = PanelTotalAccountsLogic.accountsForTotal(accts, includeGroups: false, hasSelectedAccount: false)
        #expect(r.count == 1)
        #expect(r.allSatisfy { !$0.isSystemAccount })
    }

    @Test func excludeGroups_butAccountSelected_returnsAll() {
        // Con una cuenta seleccionada el toggle no aplica (se muestra esa cuenta).
        let accts = [makeAccount("BCP", isSystem: false), makeAccount("Grupos PEN", isSystem: true)]
        let r = PanelTotalAccountsLogic.accountsForTotal(accts, includeGroups: false, hasSelectedAccount: true)
        #expect(r.count == 2)
    }

    @Test func includeGroups_withSelectedAccount_returnsAll() {
        let accts = [makeAccount("BCP", isSystem: false), makeAccount("Grupos PEN", isSystem: true)]
        let r = PanelTotalAccountsLogic.accountsForTotal(accts, includeGroups: true, hasSelectedAccount: true)
        #expect(r.count == 2)
    }

    @Test func emptyAccounts_returnsEmpty() {
        let r = PanelTotalAccountsLogic.accountsForTotal([], includeGroups: false, hasSelectedAccount: false)
        #expect(r.isEmpty)
    }

    @Test func noSystemAccounts_excludeOff_unchanged() {
        let accts = [makeAccount("BCP", isSystem: false), makeAccount("Efectivo", isSystem: false)]
        let r = PanelTotalAccountsLogic.accountsForTotal(accts, includeGroups: false, hasSelectedAccount: false)
        #expect(r.count == 2)
    }

    // MARK: - countableAccounts (archived-accounts-still-count-in-the-panel-total)

    private func makeAccount(_ name: String, excluded: Bool, archived: Bool) -> Account {
        Account(name: name, currencyCode: "PEN", colorHex: "#000000", iconName: "creditcard",
                type: "checking", excludeFromStatistics: excluded, isArchived: archived)
    }

    /// El conteo «en N cuentas» lo decide el toggle de excluir, igual que el saldo: una archivada
    /// que el usuario volvió a incluir cuenta; una activa excluida, no.
    @Test func countable_followsExcludeToggle_notArchive() {
        let accts = [
            makeAccount("Activa", excluded: false, archived: false),
            makeAccount("Archivada excluida", excluded: true, archived: true),
            makeAccount("Archivada re-incluida", excluded: false, archived: true),
            makeAccount("Activa excluida", excluded: true, archived: false),
        ]
        let names = PanelTotalAccountsLogic.countableAccounts(accts).map(\.name)
        #expect(names == ["Activa", "Archivada re-incluida"])
    }

    /// Las cuentas de Grupos que archiva la propia app no son del usuario ni se auto-excluyen:
    /// no cuentan, igual que antes del cambio.
    @Test func countable_dropsArchivedSystemAccounts() {
        let live = Account(name: "Grupos PEN", currencyCode: "PEN", colorHex: "#000000", iconName: "person.3",
                           type: "system", isSystemAccount: true)
        let archived = Account(name: "Grupos USD", currencyCode: "USD", colorHex: "#000000", iconName: "person.3",
                               type: "system", isArchived: true, isSystemAccount: true)
        let names = PanelTotalAccountsLogic.countableAccounts([live, archived]).map(\.name)
        #expect(names == ["Grupos PEN"])
    }

    // MARK: - summedAccountsCount (auditoría UX 2.2, lote 3, B2)

    /// «Tienes S/ 1.800 en 3 cuentas» junto al saldo de UNA cuenta filtrada: el conteo tiene que
    /// salir de las cuentas que sumó el saldo, no de las activas.
    private func summedCount(
        _ accounts: [Account], selected: Set<PersistentIdentifier> = [], excludeMode: Bool = false
    ) -> Int {
        let breakdown = LiveBalanceCalculator.liveBalanceBreakdown(
            accounts: accounts,
            transactions: [],
            preferredCurrencyCode: "PEN",
            selectedAccountIDs: selected,
            isExcludeMode: excludeMode,
            converter: MockCurrencyConverter()
        )
        return PanelTotalAccountsLogic.summedAccountsCount(
            accounts, summedAccountIDs: breakdown.eligibleAccountIDs
        )
    }

    @Test func summed_sinFiltro_cuentaTodas() {
        let accts = ["A", "B", "C"].map { makeAccount($0, excluded: false, archived: false) }
        #expect(summedCount(accts) == 3)
    }

    @Test func summed_filtroDeUnaCuenta_cuentaUna() {
        let accts = ["A", "B", "C"].map { makeAccount($0, excluded: false, archived: false) }
        #expect(summedCount(accts, selected: [accts[0].persistentModelID]) == 1)
    }

    @Test func summed_modoExcluir_cuentaElResto() {
        let accts = ["A", "B", "C"].map { makeAccount($0, excluded: false, archived: false) }
        #expect(summedCount(accts, selected: [accts[0].persistentModelID], excludeMode: true) == 2)
    }

    /// La elegida está excluida de las estadísticas: el saldo vuelve al total (fallback heredado) y
    /// el conteo lo acompaña.
    @Test func summed_seleccionSoloExcluida_sigueElFallbackDelSaldo() {
        let a = makeAccount("A", excluded: false, archived: false)
        let b = makeAccount("B", excluded: false, archived: false)
        let fuera = makeAccount("Fuera", excluded: true, archived: false)
        #expect(summedCount([a, b, fuera], selected: [fuera.persistentModelID]) == 2)
    }
}
