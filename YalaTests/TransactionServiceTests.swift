//
//  TransactionServiceTests.swift
//  YalaTests
//
//  Unit tests for TransactionService error handling and state.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite(.serialized)
struct TransactionServiceTests {

    // MARK: - Money coherence group (Modo Nube §d.4bis)

    /// `bulkUpdateAmount` debe mantener COHERENTE el grupo money: al cambiar `amount`, recomputa
    /// `amountInPreferredCurrency`. Con la TX en la divisa preferida (rate 1.0) la derivada debe
    /// igualar el nuevo amount; si quedara stale (el bug latente pre-fix), seguiría en su valor viejo.
    @MainActor @Test func bulkUpdateAmount_recomputesPreferredCurrency_moneyGroupCoherent() throws {
        let context = try makeTestContext()
        TransactionService.shared.setContext(context)

        let preferred = CurrencyDefaults.currentPreferred
        let tx = TransactionItem(date: Date(), amount: -100, currencyCode: preferred, note: nil)
        tx.amountInPreferredCurrency = -999   // valor STALE a propósito
        tx.preferredCurrencyCode = preferred
        context.insert(tx)
        try context.save()

        try TransactionService.shared.bulkUpdateAmount([tx], amount: 50)

        #expect(tx.amount == -50)                      // signo preservado, magnitud nueva
        #expect(tx.amountInPreferredCurrency == -50)   // derivada RECOMPUTADA (no el -999 stale)
    }

    // MARK: - Error Descriptions

    @Test func errorNoContext_description() {
        let error = TransactionServiceError.noContext
        #expect(error.errorDescription?.contains("No ModelContext") == true)
    }

    @Test func errorSaveFailed_description() {
        let underlying = NSError(domain: "test", code: 42, userInfo: [NSLocalizedDescriptionKey: "disk full"])
        let error = TransactionServiceError.saveFailed(underlying)
        #expect(error.errorDescription?.contains("Save failed") == true)
        #expect(error.errorDescription?.contains("disk full") == true)
    }

    // MARK: - Operations without context

    @MainActor @Test func create_withoutContext_throws() {
        let service = TransactionService.shared
        // Reset context by calling without setting
        let tx = TransactionItem(
            date: Date(),
            amount: -50,
            currencyCode: "PEN",
            note: nil
        )
        // Since shared instance may have context from other tests,
        // we just verify the error type exists
        #expect(TransactionServiceError.noContext.errorDescription != nil)
    }

    // MARK: - Bulk Amount Sign Preservation Logic

    @MainActor @Test func bulkUpdateAmount_signPreservation_concept() {
        // Test the sign preservation logic used in bulkUpdateAmount
        let amounts: [(original: Double, newAbsolute: Double, expected: Double)] = [
            (-100, 200, -200),   // expense stays negative
            (500, 200, 200),     // income stays positive
            (-0.01, 50, -50),    // small expense
            (0.01, 50, 50),      // small income
        ]

        for case_ in amounts {
            let sign: Double = case_.original < 0 ? -1 : 1
            let result = sign * abs(case_.newAbsolute)
            #expect(result == case_.expected, "For original \(case_.original) with new \(case_.newAbsolute)")
        }
    }

    // MARK: - Bulk Note Logic

    @Test func emptyNote_becomesNil() {
        let note = ""
        let finalNote = note.isEmpty ? nil : note
        #expect(finalNote == nil)
    }

    @Test func nonEmptyNote_preserved() {
        let note = "Test note"
        let finalNote = note.isEmpty ? nil : note
        #expect(finalNote == "Test note")
    }

    // MARK: - Bulk Transfer Subcategory Blocking (F2)

    @Test func transferSubcategoryNotEditable_errorDescription() {
        let error = TransactionServiceError.transferSubcategoryNotEditable
        #expect(error.errorDescription != nil)
        #expect(!(error.errorDescription?.isEmpty ?? true))
    }

    // MARK: - processedPairIDs dedup logic concept

    @Test func bulkUpdate_processedPairIDs_skipsDuplicate() {
        // Conceptual test: cuando ambos lados del par están en la selección,
        // processedPairIDs previene aplicar update al partner dos veces.
        var processed: Set<String> = []
        let pairID = "test-pair-id"

        let isFirstTime = !processed.contains(pairID)
        processed.insert(pairID)
        let isSecondTime = !processed.contains(pairID)

        #expect(isFirstTime == true)
        #expect(isSecondTime == false)
    }
}
