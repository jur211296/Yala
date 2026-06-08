//
//  PanelTotalAccountsLogicTests.swift
//  YalaTests
//
//  Tests pure-logic para PanelTotalAccountsLogic.accountsForTotal.
//  Sin ModelContext — crea Account directos (solo se lee isSystemAccount).
//

import Foundation
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
}
