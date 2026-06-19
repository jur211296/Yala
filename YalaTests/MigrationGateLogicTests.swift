//
//  MigrationGateLogicTests.swift
//  YalaTests
//
//  Pure-logic tests for `MigrationGateLogic.shouldWaitForCloudKit(...)`.
//  No SwiftData, no iCloud — covers the full state matrix.
//

import Foundation
import Testing

@testable import Yala

@Suite("Migration Gate Logic")
struct MigrationGateLogicTests {

    @Test func localOnly_runsImmediately() {
        let decision = MigrationGateLogic.shouldWaitForCloudKit(
            isAccountAvailable: false,
            hasCompletedFirstImport: false
        )
        #expect(decision == .runNow)
    }

    @Test func iCloudReady_runsImmediately() {
        let decision = MigrationGateLogic.shouldWaitForCloudKit(
            isAccountAvailable: true,
            hasCompletedFirstImport: true
        )
        #expect(decision == .runNow)
    }

    @Test func iCloudPending_waitsForHook() {
        let decision = MigrationGateLogic.shouldWaitForCloudKit(
            isAccountAvailable: true,
            hasCompletedFirstImport: false
        )
        #expect(decision == .waitForHook)
    }

    @Test func iCloudUnavailableButFlagSet_runsImmediately() {
        // Defensive edge — flag should never be true without account, but the
        // logic must remain robust against stale state.
        let decision = MigrationGateLogic.shouldWaitForCloudKit(
            isAccountAvailable: false,
            hasCompletedFirstImport: true
        )
        #expect(decision == .runNow)
    }
}
