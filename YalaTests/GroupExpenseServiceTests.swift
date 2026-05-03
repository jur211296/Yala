//
//  GroupExpenseServiceTests.swift
//  YalaTests
//
//  Unit tests for GroupExpenseService validation logic and error types.
//

import Foundation
import Testing

@testable import Yala

struct GroupExpenseServiceTests {

    // MARK: - Error Descriptions

    @Test func error_noContext_hasDescription() {
        let error = GroupExpenseServiceError.noContext
        #expect(error.errorDescription != nil)
        #expect(error.errorDescription!.contains("No ModelContext"))
    }

    @Test func error_invalidAmount_hasDescription() {
        let error = GroupExpenseServiceError.invalidAmount
        #expect(error.errorDescription != nil)
        #expect(error.errorDescription!.contains("greater than zero"))
    }

    @Test func error_noShares_hasDescription() {
        let error = GroupExpenseServiceError.noShares
        #expect(error.errorDescription != nil)
        #expect(error.errorDescription!.contains("share"))
    }

    @Test func error_noPayer_hasDescription() {
        let error = GroupExpenseServiceError.noPayer
        #expect(error.errorDescription != nil)
        #expect(error.errorDescription!.contains("Payer"))
    }

    @Test func error_selfSettlement_hasDescription() {
        let error = GroupExpenseServiceError.selfSettlement
        #expect(error.errorDescription != nil)
        #expect(error.errorDescription!.contains("yourself"))
    }

    @Test func error_inactiveMember_hasDescription() {
        let error = GroupExpenseServiceError.inactiveMember
        #expect(error.errorDescription != nil)
        #expect(error.errorDescription!.contains("Inactive"))
    }

    @Test func error_saveFailed_includesUnderlyingError() {
        let underlying = NSError(domain: "test", code: 42)
        let error = GroupExpenseServiceError.saveFailed(underlying)
        #expect(error.errorDescription != nil)
        #expect(error.errorDescription!.contains("Save failed"))
    }

    // MARK: - Singleton

    @Test func singleton_exists() {
        let service = GroupExpenseService.shared
        #expect(service != nil)
    }

    @Test func singleton_isSameInstance() {
        let a = GroupExpenseService.shared
        let b = GroupExpenseService.shared
        #expect(a === b)
    }

    @Test func error_sharesSumMismatch_hasDescription() {
        let error = GroupExpenseServiceError.sharesSumMismatch
        #expect(error.errorDescription != nil)
        #expect(error.errorDescription!.contains("shares"))
    }

    // MARK: - Shares Sum Validation

    @Test func sharesSum_withinTolerance_isAccepted() {
        let amount = 100.0
        let shares: [(memberID: String, amount: Double)] = [
            ("A", 33.33), ("B", 33.33), ("C", 33.34)
        ]
        let sum = shares.reduce(0.0) { $0 + $1.amount }
        #expect(abs(sum - amount) < 0.02)
    }

    @Test func sharesSum_outsideTolerance_isRejected() {
        let amount = 100.0
        let shares: [(memberID: String, amount: Double)] = [
            ("A", 30.0), ("B", 30.0), ("C", 30.0)
        ]
        let sum = shares.reduce(0.0) { $0 + $1.amount }
        #expect(abs(sum - amount) >= 0.02)
    }

    // MARK: - Bridge Error Types

    @Test func bridgeError_noContext_hasDescription() {
        let error = GroupTransactionBridgeError.noContext
        #expect(error.errorDescription != nil)
        #expect(error.errorDescription!.contains("No ModelContext"))
    }

    @Test func bridge_isSameInstance() {
        let a = GroupTransactionBridge.shared
        let b = GroupTransactionBridge.shared
        #expect(a === b)
    }
}
