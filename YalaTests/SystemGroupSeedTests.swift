//
//  SystemGroupSeedTests.swift
//  YalaTests
//
//  F2 — A0-Bridge: tests para semilla system groups.
//
//  NOTA (R8): tests que requieren `makeTestContext()` para ejecutar
//  `seedSystemGroupCategoriesIfNeeded` están en lista negra del runner
//  (Swift Testing tiene race con CloudKit en simulador). Se valida via
//  Device QA F16 escenarios 8 y 17. Aquí solo se cubren cosas pure-logic.
//

import Foundation
import Testing

@testable import Yala

@Suite("F2 — System group seed roles")
struct SystemGroupSeedTests {

    // MARK: - GroupBridgeSystemRole — identificadores estables

    @Test func roles_areStableIdentifiers() {
        // Estos identificadores se usan para mapear casos del bridge.
        // No deben cambiar entre versiones (rompen finalize de drafts pendientes).
        #expect(GroupBridgeSystemRole.categoryGroups == "groups")
        #expect(GroupBridgeSystemRole.categoryGroupCollections == "groupCollections")
        #expect(GroupBridgeSystemRole.subcategoryLoanToGroups == "loanToGroups")
        #expect(GroupBridgeSystemRole.subcategoryLoanCollection == "loanCollection")
        #expect(GroupBridgeSystemRole.subcategorySettlementPayment == "settlementPayment")
        #expect(GroupBridgeSystemRole.subcategorySettlementSent == "settlementSent")
        #expect(GroupBridgeSystemRole.subcategorySettlementReceived == "settlementReceived")
    }

    @Test func roles_distinct_noCollisions() {
        let allRoles: [String] = [
            GroupBridgeSystemRole.categoryGroups,
            GroupBridgeSystemRole.categoryGroupCollections,
            GroupBridgeSystemRole.subcategoryLoanToGroups,
            GroupBridgeSystemRole.subcategoryLoanCollection,
            GroupBridgeSystemRole.subcategorySettlementPayment,
            GroupBridgeSystemRole.subcategorySettlementSent,
            GroupBridgeSystemRole.subcategorySettlementReceived,
        ]
        let unique = Set(allRoles)
        #expect(unique.count == allRoles.count, "Todos los roles deben ser únicos")
    }

    // MARK: - L10n keys de Categories/Subcategories sistema

    @Test func l10nKeys_systemCategories_existAndNonEmpty() {
        #expect(!L10n.Category.System.groups.isEmpty)
        #expect(!L10n.Category.System.groupCollections.isEmpty)
    }

    @Test func l10nKeys_systemSubcategories_existAndNonEmpty() {
        #expect(!L10n.Subcategory.System.loanToGroups.isEmpty)
        #expect(!L10n.Subcategory.System.loanCollection.isEmpty)
        #expect(!L10n.Subcategory.System.settlementPayment.isEmpty)
        #expect(!L10n.Subcategory.System.settlementSent.isEmpty)
        #expect(!L10n.Subcategory.System.settlementReceived.isEmpty)
    }

    @Test func l10nKeys_systemSubcategories_distinct() {
        let names = [
            L10n.Subcategory.System.loanToGroups,
            L10n.Subcategory.System.loanCollection,
            L10n.Subcategory.System.settlementPayment,
            L10n.Subcategory.System.settlementSent,
            L10n.Subcategory.System.settlementReceived,
        ]
        #expect(Set(names).count == names.count, "Todas las subcats sistema deben tener nombre único")
    }

    @Test func l10nKeys_systemCategories_distinct() {
        #expect(L10n.Category.System.groups != L10n.Category.System.groupCollections)
    }
}
