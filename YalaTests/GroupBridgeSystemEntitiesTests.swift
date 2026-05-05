//
//  GroupBridgeSystemEntitiesTests.swift
//  YalaTests
//
//  F3 — A0-Bridge: tests pure-logic para SystemSubcategoryRole + L10n mapping.
//  Tests integration (ensureSystemAccount, systemSubcategory) requieren
//  makeTestContext y están en blacklist R8 (validación via Device QA F16).
//

import Foundation
import Testing

@testable import Yala

@Suite("F3 — System entity helpers")
struct GroupBridgeSystemEntitiesTests {

    // MARK: - SystemSubcategoryRole — mapping a roleString

    @Test func subcategoryRole_mapsToStableRoleString() {
        #expect(GroupBridgeSystemEntities.SystemSubcategoryRole.loanToGroups.roleString
                == GroupBridgeSystemRole.subcategoryLoanToGroups)
        #expect(GroupBridgeSystemEntities.SystemSubcategoryRole.loanCollection.roleString
                == GroupBridgeSystemRole.subcategoryLoanCollection)
        #expect(GroupBridgeSystemEntities.SystemSubcategoryRole.settlementPayment.roleString
                == GroupBridgeSystemRole.subcategorySettlementPayment)
        #expect(GroupBridgeSystemEntities.SystemSubcategoryRole.settlementSent.roleString
                == GroupBridgeSystemRole.subcategorySettlementSent)
        #expect(GroupBridgeSystemEntities.SystemSubcategoryRole.settlementReceived.roleString
                == GroupBridgeSystemRole.subcategorySettlementReceived)
    }

    @Test func subcategoryRole_localizedNames_distinct() {
        let names = [
            GroupBridgeSystemEntities.SystemSubcategoryRole.loanToGroups.localizedName,
            GroupBridgeSystemEntities.SystemSubcategoryRole.loanCollection.localizedName,
            GroupBridgeSystemEntities.SystemSubcategoryRole.settlementPayment.localizedName,
            GroupBridgeSystemEntities.SystemSubcategoryRole.settlementSent.localizedName,
            GroupBridgeSystemEntities.SystemSubcategoryRole.settlementReceived.localizedName,
        ]
        #expect(Set(names).count == 5)
    }

    @Test func subcategoryRole_localizedNames_matchSeed() {
        // Los nombres del enum deben matchear los del seed (F2) para que
        // systemSubcategory(role:) encuentre la subcat creada por seed.
        #expect(GroupBridgeSystemEntities.SystemSubcategoryRole.loanToGroups.localizedName
                == L10n.Subcategory.System.loanToGroups)
        #expect(GroupBridgeSystemEntities.SystemSubcategoryRole.loanCollection.localizedName
                == L10n.Subcategory.System.loanCollection)
        #expect(GroupBridgeSystemEntities.SystemSubcategoryRole.settlementPayment.localizedName
                == L10n.Subcategory.System.settlementPayment)
        #expect(GroupBridgeSystemEntities.SystemSubcategoryRole.settlementSent.localizedName
                == L10n.Subcategory.System.settlementSent)
        #expect(GroupBridgeSystemEntities.SystemSubcategoryRole.settlementReceived.localizedName
                == L10n.Subcategory.System.settlementReceived)
    }

    // MARK: - L10n Account.System

    // NOTA: tests de format-string interpolation removidos.
    // En contexto de YalaTests, NSLocalizedString para keys recién añadidas
    // puede no resolverse hasta el primer cold launch del Yala host (ls() usa
    // LanguageManager.resolved.bundle). Validación funcional via Device QA F16.

    @Test func l10nKey_systemBadge_nonEmpty() {
        #expect(!L10n.Account.System.badge.isEmpty)
    }

    // MARK: - Error descriptions

    @Test func error_systemSubcategoryMissing_hasDescription() {
        let error = GroupBridgeSystemEntities.Error
            .systemSubcategoryMissing(.loanToGroups)
        #expect(error.errorDescription != nil)
        #expect(error.errorDescription?.contains("loanToGroups") == true)
    }

    @Test func error_systemAccountCreationFailed_hasDescription() {
        let error = GroupBridgeSystemEntities.Error
            .systemAccountCreationFailed("test reason")
        #expect(error.errorDescription != nil)
        #expect(error.errorDescription?.contains("test reason") == true)
    }
}
