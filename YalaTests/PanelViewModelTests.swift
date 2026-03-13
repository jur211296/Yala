//
//  PanelViewModelTests.swift
//  YalaTests
//
//  Unit tests for PanelViewModel pure logic (account sorting, sort order consistency).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

struct PanelViewModelTests {

    // MARK: - Helpers

    private func makeAccount(name: String, isArchived: Bool = false) -> Account {
        let account = Account(
            name: name,
            currencyCode: "PEN",
            colorHex: "#000000",
            iconName: "creditcard",
            type: "bank"
        )
        account.isArchived = isArchived
        return account
    }

    // MARK: - orderedActiveAccounts

    @MainActor @Test func orderedActiveAccounts_excludesArchived() {
        let vm = PanelViewModel()
        let active = makeAccount(name: "Checking")
        let archived = makeAccount(name: "Old", isArchived: true)

        let result = vm.orderedActiveAccounts(
            from: [active, archived],
            sortOrderNames: ["Checking", "Old"]
        )
        #expect(result.count == 1)
        #expect(result[0].name == "Checking")
    }

    @MainActor @Test func orderedActiveAccounts_respectsSortOrder() {
        let vm = PanelViewModel()
        let a = makeAccount(name: "Alpha")
        let b = makeAccount(name: "Beta")
        let c = makeAccount(name: "Charlie")

        let result = vm.orderedActiveAccounts(
            from: [a, b, c],
            sortOrderNames: ["Charlie", "Alpha", "Beta"]
        )
        #expect(result[0].name == "Charlie")
        #expect(result[1].name == "Alpha")
        #expect(result[2].name == "Beta")
    }

    @MainActor @Test func orderedActiveAccounts_unknownFallsToEnd() {
        let vm = PanelViewModel()
        let known = makeAccount(name: "Checking")
        let unknown = makeAccount(name: "NewAccount")

        let result = vm.orderedActiveAccounts(
            from: [unknown, known],
            sortOrderNames: ["Checking"]
        )
        #expect(result[0].name == "Checking")
        #expect(result[1].name == "NewAccount")
    }

    @MainActor @Test func orderedActiveAccounts_bothUnknown_sortByName() {
        let vm = PanelViewModel()
        let z = makeAccount(name: "Zeta")
        let a = makeAccount(name: "Alpha")

        let result = vm.orderedActiveAccounts(
            from: [z, a],
            sortOrderNames: []
        )
        #expect(result[0].name == "Alpha")
        #expect(result[1].name == "Zeta")
    }

    // MARK: - ensureAccountsSortOrderConsistency

    @MainActor @Test func sortOrderConsistency_removesDeleted() {
        let vm = PanelViewModel()
        let a = makeAccount(name: "Checking")

        let result = vm.ensureAccountsSortOrderConsistency(
            accounts: [a],
            currentOrderRaw: "Checking|Savings"
        )
        #expect(result == "Checking")
    }

    @MainActor @Test func sortOrderConsistency_addsNew() {
        let vm = PanelViewModel()
        let a = makeAccount(name: "Checking")
        let b = makeAccount(name: "NewAccount")

        let result = vm.ensureAccountsSortOrderConsistency(
            accounts: [a, b],
            currentOrderRaw: "Checking"
        )
        #expect(result == "Checking|NewAccount")
    }

    @MainActor @Test func sortOrderConsistency_preservesExisting() {
        let vm = PanelViewModel()
        let a = makeAccount(name: "Alpha")
        let b = makeAccount(name: "Beta")
        let c = makeAccount(name: "Charlie")

        let result = vm.ensureAccountsSortOrderConsistency(
            accounts: [a, b, c],
            currentOrderRaw: "Charlie|Alpha|Beta"
        )
        #expect(result == "Charlie|Alpha|Beta")
    }

    @MainActor @Test func sortOrderConsistency_emptyAccounts() {
        let vm = PanelViewModel()

        let result = vm.ensureAccountsSortOrderConsistency(
            accounts: [],
            currentOrderRaw: "Checking|Savings"
        )
        #expect(result == "")
    }

    @MainActor @Test func sortOrderConsistency_emptyCurrentOrder() {
        let vm = PanelViewModel()
        let a = makeAccount(name: "Alpha")
        let b = makeAccount(name: "Beta")

        let result = vm.ensureAccountsSortOrderConsistency(
            accounts: [a, b],
            currentOrderRaw: ""
        )
        // Both are new → appended in array order
        #expect(result.contains("Alpha"))
        #expect(result.contains("Beta"))
    }

    @MainActor @Test func sortOrderConsistency_roundTrip() {
        let vm = PanelViewModel()
        let a = makeAccount(name: "Alpha")
        let b = makeAccount(name: "Beta")
        let c = makeAccount(name: "Charlie")

        // First, get consistency output
        let consistent = vm.ensureAccountsSortOrderConsistency(
            accounts: [a, b, c],
            currentOrderRaw: "Beta|Charlie|Alpha"
        )

        // Use that output as sortOrderNames for orderedActiveAccounts
        let sortOrderNames = consistent.split(separator: "|").map(String.init)
        let ordered = vm.orderedActiveAccounts(from: [a, b, c], sortOrderNames: sortOrderNames)

        #expect(ordered[0].name == "Beta")
        #expect(ordered[1].name == "Charlie")
        #expect(ordered[2].name == "Alpha")
    }
}
