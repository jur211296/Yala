//
//  RecordsViewModelTests.swift
//  YalaTests
//
//  Unit tests for RecordsViewModel pure logic (selection, counting).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

struct RecordsViewModelTests {

    // MARK: - Helpers

    private func makeTransaction(
        amount: Double = -100,
        date: Date = Date()
    ) -> TransactionItem {
        TransactionItem(
            date: date,
            amount: amount,
            currencyCode: "USD",
            note: ""
        )
    }

    private func makeCategory(name: String, isIncome: Bool = false) -> YalaCategory {
        YalaCategory(name: name, colorHex: "#000000", isIncome: isIncome)
    }

    private func makeSubcategory(name: String, category: YalaCategory) -> Subcategory {
        Subcategory(name: name, category: category)
    }

    // MARK: - filteredCount

    @MainActor @Test func filteredCount_empty() {
        let vm = RecordsViewModel()
        vm.groupedRecords = []
        #expect(vm.filteredCount == 0)
    }

    @MainActor @Test func filteredCount_withRecords() {
        let vm = RecordsViewModel()
        let tx1 = makeTransaction()
        let tx2 = makeTransaction()
        let tx3 = makeTransaction()
        vm.groupedRecords = [
            (date: Date(), records: [tx1, tx2]),
            (date: Date(), records: [tx3])
        ]
        #expect(vm.filteredCount == 3)
    }

    // MARK: - Toggle Selection

    @MainActor @Test func toggleSelection_addsID() {
        let vm = RecordsViewModel()
        let tx = makeTransaction()
        let id = tx.persistentModelID

        vm.toggleSelection(id)
        #expect(vm.selectedRecordIDs.contains(id))
    }

    @MainActor @Test func toggleSelection_removesExisting() {
        let vm = RecordsViewModel()
        let tx = makeTransaction()
        let id = tx.persistentModelID

        vm.toggleSelection(id)
        vm.toggleSelection(id)
        #expect(!vm.selectedRecordIDs.contains(id))
    }

    // MARK: - Select All / Deselect All

    @MainActor @Test func selectAll_addsAllIDs() {
        let vm = RecordsViewModel()
        let tx1 = makeTransaction()
        let tx2 = makeTransaction()
        let tx3 = makeTransaction()
        vm.groupedRecords = [
            (date: Date(), records: [tx1, tx2]),
            (date: Date(), records: [tx3])
        ]

        vm.selectAll()
        #expect(vm.selectedRecordIDs.count == 3)
    }

    @MainActor @Test func deselectAll_clearsSelection() {
        let vm = RecordsViewModel()
        let tx = makeTransaction()
        vm.selectedRecordIDs.insert(tx.persistentModelID)

        vm.deselectAll()
        #expect(vm.selectedRecordIDs.isEmpty)
    }

    // MARK: - Selection Mode

    @MainActor @Test func enterSelectionMode_setsFlag() {
        let vm = RecordsViewModel()
        vm.enterSelectionMode()
        #expect(vm.isSelectionMode == true)
    }

    @MainActor @Test func exitSelectionMode_clearsAll() {
        let vm = RecordsViewModel()
        let tx = makeTransaction()
        vm.isSelectionMode = true
        vm.selectedRecordIDs.insert(tx.persistentModelID)

        vm.exitSelectionMode()
        #expect(vm.isSelectionMode == false)
        #expect(vm.selectedRecordIDs.isEmpty)
    }

    // MARK: - editSelectedRecords

    @MainActor @Test func editSelectedRecords_none() {
        let vm = RecordsViewModel()
        let tx = makeTransaction()

        let action = vm.editSelectedRecords(transactions: [tx])
        if case .none = action {
            // Expected
        } else {
            #expect(Bool(false), "Expected .none")
        }
    }

    @MainActor @Test func editSelectedRecords_single() {
        let vm = RecordsViewModel()
        let tx = makeTransaction()
        vm.selectedRecordIDs.insert(tx.persistentModelID)

        let action = vm.editSelectedRecords(transactions: [tx])
        if case .single(let record) = action {
            #expect(record.persistentModelID == tx.persistentModelID)
        } else {
            #expect(Bool(false), "Expected .single")
        }
    }

    @MainActor @Test func editSelectedRecords_multiple() {
        let vm = RecordsViewModel()
        let tx1 = makeTransaction()
        let tx2 = makeTransaction()
        vm.selectedRecordIDs.insert(tx1.persistentModelID)
        vm.selectedRecordIDs.insert(tx2.persistentModelID)

        let action = vm.editSelectedRecords(transactions: [tx1, tx2])
        if case .multiple(let count) = action {
            #expect(count == 2)
        } else {
            #expect(Bool(false), "Expected .multiple")
        }
    }

    // MARK: - getSelectedTransactionType

    @MainActor @Test func getSelectedTransactionType_mixed() {
        let vm = RecordsViewModel()
        let expCat = makeCategory(name: "Food", isIncome: false)
        let incCat = makeCategory(name: "Salary", isIncome: true)
        let expSub = makeSubcategory(name: "Groceries", category: expCat)
        let incSub = makeSubcategory(name: "Job", category: incCat)

        let tx1 = makeTransaction(amount: -100)
        tx1.subcategory = expSub
        let tx2 = makeTransaction(amount: 5000)
        tx2.subcategory = incSub

        vm.groupedRecords = [(date: Date(), records: [tx1, tx2])]
        vm.selectedRecordIDs = [tx1.persistentModelID, tx2.persistentModelID]

        let result = vm.getSelectedTransactionType()
        #expect(result == nil)
    }
}
