//
//  BridgedTransactionFilterTests.swift
//  YalaTests
//
//  Pure-logic tests para `BridgedTransactionFilter.shouldInclude`.
//

import Foundation
import Testing

@testable import Yala

@Suite("Bridge opt-out — bridged TX filter (stats)")
struct BridgedTransactionFilterTests {

    @Test
    func toggleOn_includesAllTransactions() {
        #expect(BridgedTransactionFilter.shouldInclude(
            splitExpenseID: "abc", splitSettlementID: nil, includeGroupsToggle: true
        ) == true)
        #expect(BridgedTransactionFilter.shouldInclude(
            splitExpenseID: nil, splitSettlementID: "xyz", includeGroupsToggle: true
        ) == true)
        #expect(BridgedTransactionFilter.shouldInclude(
            splitExpenseID: nil, splitSettlementID: nil, includeGroupsToggle: true
        ) == true)
    }

    @Test
    func toggleOff_includesOnlyNonBridged() {
        #expect(BridgedTransactionFilter.shouldInclude(
            splitExpenseID: nil, splitSettlementID: nil, includeGroupsToggle: false
        ) == true)
    }

    @Test
    func toggleOff_excludesExpenseBridged() {
        #expect(BridgedTransactionFilter.shouldInclude(
            splitExpenseID: "abc", splitSettlementID: nil, includeGroupsToggle: false
        ) == false)
    }

    @Test
    func toggleOff_excludesSettlementBridged() {
        #expect(BridgedTransactionFilter.shouldInclude(
            splitExpenseID: nil, splitSettlementID: "xyz", includeGroupsToggle: false
        ) == false)
    }
}
