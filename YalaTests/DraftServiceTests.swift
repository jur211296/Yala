//
//  DraftServiceTests.swift
//  YalaTests
//
//  Tests for DraftServiceError descriptions.
//

import Foundation
import Testing

@testable import Yala

struct DraftServiceTests {

    // MARK: - DraftServiceError descriptions

    @Test func errorNoContext_hasDescription() {
        let error = DraftServiceError.noContext
        #expect(error.errorDescription != nil)
        #expect(error.errorDescription?.contains("No ModelContext") == true)
    }

    @Test func errorMissingAccount_hasDescription() {
        let error = DraftServiceError.missingAccount
        #expect(error.errorDescription != nil)
    }

    @Test func errorMissingAmount_hasDescription() {
        let error = DraftServiceError.missingAmount
        #expect(error.errorDescription != nil)
    }

    @Test func errorMissingSubcategory_hasDescription() {
        let error = DraftServiceError.missingSubcategory
        #expect(error.errorDescription != nil)
    }

    @Test func errorFutureDateNotAllowed_hasDescription() {
        let error = DraftServiceError.futureDateNotAllowed
        #expect(error.errorDescription != nil)
    }

    @Test func errorSaveFailed_includesUnderlying() {
        let underlying = NSError(domain: "test", code: 42, userInfo: [NSLocalizedDescriptionKey: "disk full"])
        let error = DraftServiceError.saveFailed(underlying)
        #expect(error.errorDescription != nil)
        #expect(error.errorDescription?.contains("Save failed") == true)
    }
}
