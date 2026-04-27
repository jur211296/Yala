//
//  DraftBuilderTests.swift
//  YalaTests
//
//  Tests para DraftBuilder. Cubre los helpers pure-logic (findAccount con array,
//  computeNeedsUserInput). El overload con `context: ModelContext` y el método
//  `build()` se cubren indirectamente vía VisionDraftFactoryTests (19 tests
//  existentes verdes pre/post refactor) y vía device QA — Swift Testing tiene
//  race condition de CloudKit en simulador con `makeTestContext()` (ver nota
//  en BudgetEditorViewModelTests).
//

import Foundation
import Testing

@testable import Yala

@MainActor
struct DraftBuilderTests {

    // MARK: - Helpers (Account sin SwiftData context)

    private func makeAccount(name: String = "A", currencyCode: String, archived: Bool = false) -> Account {
        let acc = Account(
            name: name,
            currencyCode: currencyCode,
            colorHex: "#000000",
            iconName: "creditcard.fill",
            type: "bank"
        )
        acc.isArchived = archived
        return acc
    }

    // MARK: - findAccount (pure-logic overload)

    @Test func findAccount_singleMatch_returnsAccount() {
        let accounts = [makeAccount(name: "BCP", currencyCode: "PEN")]
        let result = DraftBuilder.findAccount(byCurrency: "PEN", in: accounts)
        #expect(result?.name == "BCP")
    }

    @Test func findAccount_caseInsensitive() {
        let accounts = [makeAccount(currencyCode: "USD")]
        let result = DraftBuilder.findAccount(byCurrency: "usd", in: accounts)
        #expect(result != nil)
    }

    @Test func findAccount_currencyHasWhitespace_trimmed() {
        let accounts = [makeAccount(currencyCode: "EUR")]
        let result = DraftBuilder.findAccount(byCurrency: "  EUR  ", in: accounts)
        #expect(result != nil)
    }

    @Test func findAccount_noMatch_returnsNil() {
        let accounts = [makeAccount(currencyCode: "PEN")]
        let result = DraftBuilder.findAccount(byCurrency: "EUR", in: accounts)
        #expect(result == nil)
    }

    @Test func findAccount_multipleMatches_returnsNil() {
        let accounts = [
            makeAccount(name: "A1", currencyCode: "PEN"),
            makeAccount(name: "A2", currencyCode: "PEN"),
        ]
        let result = DraftBuilder.findAccount(byCurrency: "PEN", in: accounts)
        #expect(result == nil, "2 matches → ambiguo → nil")
    }

    @Test func findAccount_emptyCurrency_returnsNil() {
        let accounts = [makeAccount(currencyCode: "PEN")]
        let result = DraftBuilder.findAccount(byCurrency: "", in: accounts)
        #expect(result == nil)
    }

    @Test func findAccount_archivedExcluded() {
        let accounts = [makeAccount(currencyCode: "EUR", archived: true)]
        let result = DraftBuilder.findAccount(byCurrency: "EUR", in: accounts)
        #expect(result == nil)
    }

    @Test func findAccount_oneArchivedOneActive_returnsActive() {
        let active = makeAccount(name: "active", currencyCode: "PEN")
        let archived = makeAccount(name: "old", currencyCode: "PEN", archived: true)
        let result = DraftBuilder.findAccount(byCurrency: "PEN", in: [active, archived])
        #expect(result?.name == "active")
    }

    @Test func findAccount_emptyAccounts_returnsNil() {
        let result = DraftBuilder.findAccount(byCurrency: "PEN", in: [])
        #expect(result == nil)
    }

    // MARK: - computeNeedsUserInput

    @Test func computeNeedsUserInput_allMissing_returnsAll() {
        let needs = DraftBuilder.computeNeedsUserInput(
            hasAmount: false, hasAccount: false, hasSubcategory: false
        )
        #expect(needs == ["account", "subcategory", "amount"])
    }

    @Test func computeNeedsUserInput_allPresent_returnsEmpty() {
        let needs = DraftBuilder.computeNeedsUserInput(
            hasAmount: true, hasAccount: true, hasSubcategory: true
        )
        #expect(needs.isEmpty)
    }

    @Test func computeNeedsUserInput_onlyAccountMissing() {
        let needs = DraftBuilder.computeNeedsUserInput(
            hasAmount: true, hasAccount: false, hasSubcategory: true
        )
        #expect(needs == ["account"])
    }

    @Test func computeNeedsUserInput_onlySubcategoryMissing() {
        let needs = DraftBuilder.computeNeedsUserInput(
            hasAmount: true, hasAccount: true, hasSubcategory: false
        )
        #expect(needs == ["subcategory"])
    }

    @Test func computeNeedsUserInput_orderIsStable_accountSubcategoryAmount() {
        let needs = DraftBuilder.computeNeedsUserInput(
            hasAmount: false, hasAccount: false, hasSubcategory: true
        )
        #expect(needs == ["account", "amount"])
    }

    @Test func computeNeedsUserInput_amountAndSubcategoryMissing() {
        let needs = DraftBuilder.computeNeedsUserInput(
            hasAmount: false, hasAccount: true, hasSubcategory: false
        )
        #expect(needs == ["subcategory", "amount"])
    }
}
