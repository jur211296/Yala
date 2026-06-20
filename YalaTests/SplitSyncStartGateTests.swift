//
//  SplitSyncStartGateTests.swift
//  YalaTests
//
//  Pure-logic tests for `SplitSyncStartGate`. No SwiftData, no iCloud, no engines —
//  covers the decision matrix that gates group CKSyncEngine startup against the
//  personal CloudKit first import (crash-loop fix on iCloud restore).
//

import Foundation
import Testing

@testable import Yala

@Suite("Split Sync Start Gate")
struct SplitSyncStartGateTests {

    // MARK: - decideStart

    @Test func localOnly_startsImmediately() {
        let decision = SplitSyncStartGate.decideStart(
            isAccountAvailable: false,
            hasCompletedFirstImport: false
        )
        #expect(decision == .startNow)
    }

    @Test func localOnly_staleFlag_startsImmediately() {
        // Defensive edge — flag should never be true without account, but the logic
        // must stay robust against stale in-memory state.
        let decision = SplitSyncStartGate.decideStart(
            isAccountAvailable: false,
            hasCompletedFirstImport: true
        )
        #expect(decision == .startNow)
    }

    @Test func iCloudReady_startsImmediately() {
        let decision = SplitSyncStartGate.decideStart(
            isAccountAvailable: true,
            hasCompletedFirstImport: true
        )
        #expect(decision == .startNow)
    }

    @Test func iCloudPending_defersUntilImport() {
        let decision = SplitSyncStartGate.decideStart(
            isAccountAvailable: true,
            hasCompletedFirstImport: false
        )
        #expect(decision == .deferUntilImport)
    }

    // MARK: - resolveWait

    @Test func resolveWait_importCompleted_starts() {
        let r = SplitSyncStartGate.resolveWait(hasCompletedFirstImport: true, reachedHardCap: false)
        #expect(r == .start)
    }

    @Test func resolveWait_hardCapReached_starts() {
        let r = SplitSyncStartGate.resolveWait(hasCompletedFirstImport: false, reachedHardCap: true)
        #expect(r == .start)
    }

    @Test func resolveWait_completedAndHardCap_starts() {
        let r = SplitSyncStartGate.resolveWait(hasCompletedFirstImport: true, reachedHardCap: true)
        #expect(r == .start)
    }

    @Test func resolveWait_pendingAndNoCap_keepsWaiting() {
        // The normal "slow restore in progress" case: do not start, wait for the import
        // (the .iCloudFirstImportCompleted observer is the fast path).
        let r = SplitSyncStartGate.resolveWait(hasCompletedFirstImport: false, reachedHardCap: false)
        #expect(r == .keepWaiting)
    }

    // MARK: - startedOnIncompleteImport

    @Test func startedOnIncompleteImport_trueWhenImportPending() {
        #expect(SplitSyncStartGate.startedOnIncompleteImport(hasCompletedFirstImport: false) == true)
    }

    @Test func startedOnIncompleteImport_falseWhenImportComplete() {
        #expect(SplitSyncStartGate.startedOnIncompleteImport(hasCompletedFirstImport: true) == false)
    }

    // MARK: - shouldDeferDelegateSave

    @Test func deferDelegateSave_whenNotAutoSync() {
        // Export-only window (import pending): every delegate save() must be deferred.
        #expect(SplitSyncStartGate.shouldDeferDelegateSave(autoSyncActive: false) == true)
    }

    @Test func deferDelegateSave_allowedAfterPromotion() {
        // After promotion to auto-sync the personal import has settled → saves are safe.
        #expect(SplitSyncStartGate.shouldDeferDelegateSave(autoSyncActive: true) == false)
    }

    // MARK: - needsZoneRecovery

    @Test func zoneRecovery_ownerWithoutSystemFields_needsRecovery() {
        // Group created while engines were deferred → zone never uploaded.
        #expect(SplitSyncStartGate.needsZoneRecovery(isOwner: true, hasSystemFields: false) == true)
    }

    @Test func zoneRecovery_ownerWithSystemFields_skipped() {
        // Already synced (GroupMeta uploaded) → no re-enqueue (avoids sync storm).
        #expect(SplitSyncStartGate.needsZoneRecovery(isOwner: true, hasSystemFields: true) == false)
    }

    @Test func zoneRecovery_nonOwner_skipped() {
        // Shared zones are owned by someone else — never re-enqueue their zone.
        #expect(SplitSyncStartGate.needsZoneRecovery(isOwner: false, hasSystemFields: false) == false)
        #expect(SplitSyncStartGate.needsZoneRecovery(isOwner: false, hasSystemFields: true) == false)
    }
}
