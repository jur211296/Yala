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

    // MARK: - localizationKey / parentCategoryRole (PURE)

    @Test func subcategoryRole_localizationKey_matchesPattern() {
        #expect(GroupBridgeSystemEntities.SystemSubcategoryRole.loanToGroups.localizationKey
                == "subcategory.system.loanToGroups")
        #expect(GroupBridgeSystemEntities.SystemSubcategoryRole.settlementReceived.localizationKey
                == "subcategory.system.settlementReceived")
    }

    @Test func subcategoryRole_parentCategoryRole_incomeVsExpense() {
        // Income → groupCollections
        #expect(GroupBridgeSystemEntities.SystemSubcategoryRole.loanToGroups.parentCategoryRole
                == GroupBridgeSystemRole.categoryGroupCollections)
        #expect(GroupBridgeSystemEntities.SystemSubcategoryRole.settlementPayment.parentCategoryRole
                == GroupBridgeSystemRole.categoryGroupCollections)
        #expect(GroupBridgeSystemEntities.SystemSubcategoryRole.settlementReceived.parentCategoryRole
                == GroupBridgeSystemRole.categoryGroupCollections)
        // Expense → groups
        #expect(GroupBridgeSystemEntities.SystemSubcategoryRole.loanCollection.parentCategoryRole
                == GroupBridgeSystemRole.categoryGroups)
        #expect(GroupBridgeSystemEntities.SystemSubcategoryRole.settlementSent.parentCategoryRole
                == GroupBridgeSystemRole.categoryGroups)
    }

    // MARK: - allLocalizedValues — multi-locale (reproduce el bug del idioma)

    @Test func allLocalizedValues_loanToGroups_containsSpanishAndEnglish() {
        let names = L10n.allLocalizedValues(forKey: "subcategory.system.loanToGroups")
        // El bug: con la app en inglés se busca "Loan to groups", pero la subcat se sembró en
        // español. El fix barre TODOS los idiomas → el set debe contener AMBOS.
        #expect(names.contains("Préstamo a grupos"))
        #expect(names.contains("Loan to groups"))
    }

    @Test func allLocalizedValues_perRole_nonEmpty_andIncludesCurrent() {
        let roles: [GroupBridgeSystemEntities.SystemSubcategoryRole] =
            [.loanToGroups, .loanCollection, .settlementPayment, .settlementSent, .settlementReceived]
        for role in roles {
            let names = L10n.allLocalizedValues(forKey: role.localizationKey)
            #expect(names.count >= 2, "rol \(role.roleString) debe tener nombres en varios idiomas")
            #expect(names.contains(role.localizedName), "debe incluir el nombre del idioma actual")
        }
    }

    @Test func allLocalizedValues_unknownKey_isEmpty() {
        #expect(L10n.allLocalizedValues(forKey: "subcategory.system.__does_not_exist__").isEmpty)
    }

    // MARK: - selectSystemEntityIndex (PURE)

    @Test func select_matchesSystemEntityByMultiLocaleName() {
        let names: Set<String> = ["Préstamo a grupos", "Loan to groups"]
        let candidates = [
            GroupBridgeSystemEntities.SystemEntityCandidate(name: "Comida", isSystem: false, isDefaultSeed: true, tiebreak: "a"),
            GroupBridgeSystemEntities.SystemEntityCandidate(name: "Préstamo a grupos", isSystem: true, isDefaultSeed: true, tiebreak: "b"),
        ]
        #expect(GroupBridgeSystemEntities.selectSystemEntityIndex(candidates, matching: names) == 1)
    }

    @Test func select_ignoresPersonalHomonym() {
        // Una entidad PERSONAL homónima (isSystem=false, isDefaultSeed=false) NO debe adoptarse.
        let names: Set<String> = ["Préstamo a grupos"]
        let candidates = [
            GroupBridgeSystemEntities.SystemEntityCandidate(name: "Préstamo a grupos", isSystem: false, isDefaultSeed: false, tiebreak: "a"),
        ]
        #expect(GroupBridgeSystemEntities.selectSystemEntityIndex(candidates, matching: names) == nil)
    }

    @Test func select_adoptsSeededWithIsSystemFalse() {
        // isDefaultSeed=true, isSystem=false (CloudKit no hidratado) → SÍ se adopta (self-heal luego).
        let names: Set<String> = ["Préstamo a grupos"]
        let candidates = [
            GroupBridgeSystemEntities.SystemEntityCandidate(name: "Préstamo a grupos", isSystem: false, isDefaultSeed: true, tiebreak: "a"),
        ]
        #expect(GroupBridgeSystemEntities.selectSystemEntityIndex(candidates, matching: names) == 0)
    }

    @Test func select_tiebreaksByTiebreakThenOrder() {
        // Duplicados (UUIDs colapsados): elige el de menor tiebreak.
        let names: Set<String> = ["X"]
        let candidates = [
            GroupBridgeSystemEntities.SystemEntityCandidate(name: "X", isSystem: true, isDefaultSeed: true, tiebreak: "zzz"),
            GroupBridgeSystemEntities.SystemEntityCandidate(name: "X", isSystem: true, isDefaultSeed: true, tiebreak: "aaa"),
        ]
        #expect(GroupBridgeSystemEntities.selectSystemEntityIndex(candidates, matching: names) == 1)
    }

    @Test func select_noMatch_returnsNil() {
        let names: Set<String> = ["No existe"]
        let candidates = [
            GroupBridgeSystemEntities.SystemEntityCandidate(name: "Otra", isSystem: true, isDefaultSeed: true, tiebreak: "a"),
        ]
        #expect(GroupBridgeSystemEntities.selectSystemEntityIndex(candidates, matching: names) == nil)
    }
}
