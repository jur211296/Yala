//
//  DuplicateDetectionLogicTests.swift
//  YalaTests
//

import Foundation
import Testing

@testable import Yala

@Suite("Bridge opt-out — duplicate detection (F5)")
struct DuplicateDetectionLogicTests {

    private let day = TimeInterval(86400)

    @Test
    func sameDate_sameAmount_sameCurrency_noNote_hardMatchLowConfidence() {
        let date = Date()
        let expense = DuplicateDetectionLogic.ExpenseCandidate(
            amount: 100, date: date, currencyCode: "PEN", note: nil, payerName: nil
        )
        let tx = DuplicateDetectionLogic.TransactionCandidate(
            amount: 100, date: date, currencyCode: "PEN", note: nil, splitExpenseID: nil
        )
        let match = DuplicateDetectionLogic.findPotentialDuplicate(forExpense: expense, in: [tx])
        #expect(match?.confidence == .low)
    }

    @Test
    func differentCurrency_noMatch() {
        let date = Date()
        let expense = DuplicateDetectionLogic.ExpenseCandidate(
            amount: 100, date: date, currencyCode: "PEN", note: nil, payerName: nil
        )
        let tx = DuplicateDetectionLogic.TransactionCandidate(
            amount: 100, date: date, currencyCode: "USD", note: nil, splitExpenseID: nil
        )
        let match = DuplicateDetectionLogic.findPotentialDuplicate(forExpense: expense, in: [tx])
        #expect(match == nil)
    }

    @Test
    func dateBeyondTolerance_noMatch() {
        let now = Date()
        let expense = DuplicateDetectionLogic.ExpenseCandidate(
            amount: 100, date: now, currencyCode: "PEN", note: nil, payerName: nil
        )
        let tx = DuplicateDetectionLogic.TransactionCandidate(
            amount: 100, date: now.addingTimeInterval(day * 5),
            currencyCode: "PEN", note: nil, splitExpenseID: nil
        )
        let match = DuplicateDetectionLogic.findPotentialDuplicate(forExpense: expense, in: [tx])
        #expect(match == nil)
    }

    @Test
    func amountBeyondTolerance_noMatch() {
        let date = Date()
        let expense = DuplicateDetectionLogic.ExpenseCandidate(
            amount: 100, date: date, currencyCode: "PEN", note: nil, payerName: nil
        )
        let tx = DuplicateDetectionLogic.TransactionCandidate(
            amount: 120, date: date, currencyCode: "PEN", note: nil, splitExpenseID: nil
        )
        let match = DuplicateDetectionLogic.findPotentialDuplicate(forExpense: expense, in: [tx])
        #expect(match == nil)
    }

    @Test
    func amountWithinFivePercent_matches() {
        let date = Date()
        let expense = DuplicateDetectionLogic.ExpenseCandidate(
            amount: 100, date: date, currencyCode: "PEN", note: nil, payerName: nil
        )
        let tx = DuplicateDetectionLogic.TransactionCandidate(
            amount: 104, date: date, currencyCode: "PEN", note: nil, splitExpenseID: nil
        )
        let match = DuplicateDetectionLogic.findPotentialDuplicate(forExpense: expense, in: [tx])
        #expect(match?.confidence == .low)
    }

    @Test
    func alreadyBridgedTx_skipped() {
        let date = Date()
        let expense = DuplicateDetectionLogic.ExpenseCandidate(
            amount: 100, date: date, currencyCode: "PEN", note: nil, payerName: nil
        )
        let tx = DuplicateDetectionLogic.TransactionCandidate(
            amount: 100, date: date, currencyCode: "PEN", note: nil, splitExpenseID: "abc"
        )
        let match = DuplicateDetectionLogic.findPotentialDuplicate(forExpense: expense, in: [tx])
        #expect(match == nil)
    }

    @Test
    func payerNameInTxNote_softScoreOne_highConfidence() {
        let date = Date()
        let expense = DuplicateDetectionLogic.ExpenseCandidate(
            amount: 50, date: date, currencyCode: "USD", note: nil, payerName: "Sofia"
        )
        let tx = DuplicateDetectionLogic.TransactionCandidate(
            amount: 50, date: date, currencyCode: "USD",
            note: "Pagué a Sofia en el restaurante", splitExpenseID: nil
        )
        let match = DuplicateDetectionLogic.findPotentialDuplicate(forExpense: expense, in: [tx])
        #expect(match?.confidence == .high)
    }

    @Test
    func wordOverlapThreshold_threePlus_highConfidence() {
        let date = Date()
        let expense = DuplicateDetectionLogic.ExpenseCandidate(
            amount: 80, date: date, currencyCode: "EUR",
            note: "Cena restaurante Belmond noche viernes", payerName: nil
        )
        let tx = DuplicateDetectionLogic.TransactionCandidate(
            amount: 80, date: date, currencyCode: "EUR",
            note: "Cena Belmond Restaurante viernes", splitExpenseID: nil
        )
        let match = DuplicateDetectionLogic.findPotentialDuplicate(forExpense: expense, in: [tx])
        #expect(match?.confidence == .high)
    }

    @Test
    func stopWords_doNotCountInOverlap() {
        let words = DuplicateDetectionLogic.significantWords("la cena de el restaurante en la noche")
        // "la", "de", "el", "en" deben filtrarse.
        #expect(words == ["cena", "restaurante", "noche"])
    }

    @Test
    func bulkPartition_importAll_keepsAll() {
        let plan = BulkImportDecisionLogic.partition(
            candidates: ["a", "b", "c"],
            highConfidenceMatchIDs: ["b"],
            strategy: .importAll
        )
        #expect(plan.toImport == ["a", "b", "c"])
        #expect(plan.toSkip.isEmpty)
    }

    @Test
    func bulkPartition_skipAllMatches_filtersHighConfidence() {
        let plan = BulkImportDecisionLogic.partition(
            candidates: ["a", "b", "c", "d"],
            highConfidenceMatchIDs: ["b", "d"],
            strategy: .skipAllMatches
        )
        #expect(plan.toImport == ["a", "c"])
        #expect(plan.toSkip == ["b", "d"])
    }

    @Test
    func bulkPartition_reviewOneByOne_keepsAll() {
        let plan = BulkImportDecisionLogic.partition(
            candidates: ["a", "b"],
            highConfidenceMatchIDs: ["a"],
            strategy: .reviewOneByOne
        )
        #expect(plan.toImport == ["a", "b"])
        #expect(plan.toSkip.isEmpty)
    }
}
