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

    // MARK: - resolveWaitByQuiescence (promote on QUIESCENCE, not first import)

    @Test func resolveByQuiescence_settledAndQuiet_starts() {
        let r = SplitSyncStartGate.resolveWaitByQuiescence(
            hasCompletedFirstImport: true, isQuiescent: true, reachedHardCap: false
        )
        #expect(r == .start)
    }

    @Test func resolveByQuiescence_firstImportButNotQuiet_keepsWaiting() {
        // The KEY case: first import fired but the multi-batch restore is still active →
        // must NOT promote (promoting on the first event, before quiescence, is what re-crashed).
        let r = SplitSyncStartGate.resolveWaitByQuiescence(
            hasCompletedFirstImport: true, isQuiescent: false, reachedHardCap: false
        )
        #expect(r == .keepWaiting)
    }

    @Test func resolveByQuiescence_quietButNoImportYet_keepsWaiting() {
        // `isQuiescent` is true BEFORE any import starts (lastImportDate == nil). Promoting there
        // would be premature on a restore where the import is still pending → keep waiting.
        let r = SplitSyncStartGate.resolveWaitByQuiescence(
            hasCompletedFirstImport: false, isQuiescent: true, reachedHardCap: false
        )
        #expect(r == .keepWaiting)
    }

    @Test func resolveByQuiescence_hardCap_startsRegardless() {
        let r = SplitSyncStartGate.resolveWaitByQuiescence(
            hasCompletedFirstImport: false, isQuiescent: false, reachedHardCap: true
        )
        #expect(r == .start)
    }

    @Test func resolveByQuiescence_pendingNoCap_keepsWaiting() {
        let r = SplitSyncStartGate.resolveWaitByQuiescence(
            hasCompletedFirstImport: false, isQuiescent: false, reachedHardCap: false
        )
        #expect(r == .keepWaiting)
    }

    // MARK: - promotedWhileNotQuiescent

    @Test func promotedWhileNotQuiescent_falseWhenSettledAndQuiet() {
        #expect(SplitSyncStartGate.promotedWhileNotQuiescent(hasCompletedFirstImport: true, isQuiescent: true) == false)
    }

    @Test func promotedWhileNotQuiescent_trueWhenNotQuiet() {
        #expect(SplitSyncStartGate.promotedWhileNotQuiescent(hasCompletedFirstImport: true, isQuiescent: false) == true)
    }

    @Test func promotedWhileNotQuiescent_trueWhenImportNotDone() {
        #expect(SplitSyncStartGate.promotedWhileNotQuiescent(hasCompletedFirstImport: false, isQuiescent: true) == true)
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
