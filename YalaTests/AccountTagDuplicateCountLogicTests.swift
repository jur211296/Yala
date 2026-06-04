//
//  AccountTagDuplicateCountLogicTests.swift
//  YalaTests
//
//  Pure-logic tests for AccountTagDuplicateCountLogic. R8-safe.
//

import Foundation
import Testing

@testable import Yala

struct AccountTagDuplicateCountLogicTests {

    @Test func duplicateGroups_emptyArray() {
        let groups = AccountTagDuplicateCountLogic.duplicateGroups([String](), identity: { $0 })
        #expect(groups.isEmpty)
    }

    @Test func duplicateGroups_noDuplicates() {
        let groups = AccountTagDuplicateCountLogic.duplicateGroups(["a", "b", "c"], identity: { $0 })
        #expect(groups.isEmpty)
    }

    @Test func duplicateGroups_countsCopiesSortedByIdentity() {
        let groups = AccountTagDuplicateCountLogic.duplicateGroups(
            ["a", "a", "a", "b", "c", "c"], identity: { $0 }
        )
        #expect(groups == [
            .init(identity: "a", count: 3),
            .init(identity: "c", count: 2),
        ])
    }

    @MainActor @Test func accountIdentity_sameContent_sameIdentity() {
        // Copias: difieren en color/icon (no de contenido), comparten name+type+currency.
        let a1 = Account(name: "Efectivo", currencyCode: "PEN", colorHex: "#fff", iconName: "banknote", type: "cash")
        let a2 = Account(name: "Efectivo", currencyCode: "PEN", colorHex: "#000", iconName: "wallet", type: "cash")
        #expect(AccountTagDuplicateCountLogic.accountIdentity(a1) == AccountTagDuplicateCountLogic.accountIdentity(a2))
    }

    @MainActor @Test func accountIdentity_differentCurrency_differentIdentity() {
        let a1 = Account(name: "Efectivo", currencyCode: "PEN", colorHex: "#fff", iconName: "banknote", type: "cash")
        let a2 = Account(name: "Efectivo", currencyCode: "USD", colorHex: "#fff", iconName: "banknote", type: "cash")
        #expect(AccountTagDuplicateCountLogic.accountIdentity(a1) != AccountTagDuplicateCountLogic.accountIdentity(a2))
    }

    @MainActor @Test func tagDuplicateGroups_withModels() {
        let t1 = Tag(name: "Trabajo", colorHex: "#FF0000", iconName: "tag.fill")
        let t2 = Tag(name: "Trabajo", colorHex: "#FF0000", iconName: "tag.fill")
        let t3 = Tag(name: "Personal", colorHex: "#00FF00", iconName: "tag.fill")
        let groups = AccountTagDuplicateCountLogic.duplicateGroups(
            [t1, t2, t3], identity: AccountTagDuplicateCountLogic.tagIdentity
        )
        #expect(groups.count == 1)
        #expect(groups.first?.count == 2)
    }
}
