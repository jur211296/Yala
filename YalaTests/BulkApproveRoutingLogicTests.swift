//
//  BulkApproveRoutingLogicTests.swift
//  YalaTests
//
//  Pure-logic tests para `BulkApproveRoutingLogic`. Sin SwiftData (R8).
//

import Foundation
import Testing

@testable import Yala

@Suite("BulkApprove routing — group drafts delegate to approveDraft")
struct BulkApproveRoutingLogicTests {

    @Test
    func groupDraft_delegatesToIndividual() {
        // Drafts de grupo NO deben pasar por el path genérico inline (insertaría una TX nueva
        // sin splitExpenseID → doble conteo). Se delegan a approveDraft (SSOT del ruteo).
        #expect(BulkApproveRoutingLogic.destination(isFromGroup: true) == .delegateToIndividual)
    }

    @Test
    func personalDraft_genericInline() {
        // Drafts personales se finalizan en el path genérico inline de bulkApprove.
        #expect(BulkApproveRoutingLogic.destination(isFromGroup: false) == .genericInline)
    }
}
