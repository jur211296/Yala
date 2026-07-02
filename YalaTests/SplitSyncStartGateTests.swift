//
//  SplitSyncStartGateTests.swift
//  YalaTests
//
//  Pure-logic tests for `SplitSyncStartGate`. No SwiftData, no iCloud, no engines —
//  covers the decision matrix that gates group CKSyncEngine startup against the
//  personal CloudKit first import (crash-loop fix on iCloud restore).
//

import CloudKit
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

    // MARK: - resolveWaitByQuiescence (promote on QUIESCENCE + observed import activity)

    @Test func resolveByQuiescence_settledAndQuiet_starts() {
        let r = SplitSyncStartGate.resolveWaitByQuiescence(
            hasCompletedFirstImport: true, hasObservedImportActivity: true, isQuiescent: true,
            noImportGraceElapsed: false, reachedHardCap: false
        )
        #expect(r == .start)
    }

    @Test func resolveByQuiescence_firstImportButNotQuiet_keepsWaiting() {
        // First import fired but the multi-batch restore is still active → must NOT promote
        // (promoting before quiescence is what re-crashed the saga).
        let r = SplitSyncStartGate.resolveWaitByQuiescence(
            hasCompletedFirstImport: true, hasObservedImportActivity: true, isQuiescent: false,
            noImportGraceElapsed: false, reachedHardCap: false
        )
        #expect(r == .keepWaiting)
    }

    @Test func resolveByQuiescence_quietButNoImportYet_beforeGrace_keepsWaiting() {
        // THE GAP CASE: at cold launch `isQuiescent` is true BEFORE any import starts (lastImportDate == nil)
        // and the grace has NOT elapsed → must keep waiting (a populated restore's import may be imminent;
        // promoting here is exactly the premature-promotion crash). Empty stores promote only AFTER the grace.
        let r = SplitSyncStartGate.resolveWaitByQuiescence(
            hasCompletedFirstImport: false, hasObservedImportActivity: false, isQuiescent: true,
            noImportGraceElapsed: false, reachedHardCap: false
        )
        #expect(r == .keepWaiting)
    }

    @Test func resolveByQuiescence_hardCap_startsRegardless() {
        let r = SplitSyncStartGate.resolveWaitByQuiescence(
            hasCompletedFirstImport: false, hasObservedImportActivity: false, isQuiescent: false,
            noImportGraceElapsed: false, reachedHardCap: true
        )
        #expect(r == .start)
    }

    @Test func resolveByQuiescence_pendingNoCap_keepsWaiting() {
        let r = SplitSyncStartGate.resolveWaitByQuiescence(
            hasCompletedFirstImport: false, hasObservedImportActivity: false, isQuiescent: false,
            noImportGraceElapsed: false, reachedHardCap: false
        )
        #expect(r == .keepWaiting)
    }

    // MARK: - resolveWaitByQuiescence — EMPTY store (no import ever observed)

    @Test func resolveByQuiescence_emptyStore_graceElapsedNoActivityQuiet_starts() {
        // THE FIX: an empty personal store never fires `.import`, so `hasCompletedFirstImport` stays false
        // forever. After the grace with NO import activity observed + quiet → promote.
        let r = SplitSyncStartGate.resolveWaitByQuiescence(
            hasCompletedFirstImport: false, hasObservedImportActivity: false, isQuiescent: true,
            noImportGraceElapsed: true, reachedHardCap: false
        )
        #expect(r == .start)
    }

    @Test func resolveByQuiescence_emptyStoreBranch_butActivityObserved_keepsWaiting() {
        // THE CRITICAL SAFETY CASE: a populated restore whose import has STARTED (activity observed) but is
        // momentarily quiescent must NOT be promoted by the empty-store branch — it has real data importing.
        // Keying on `hasObservedImportActivity` (not onboarding mode) is what makes this safe.
        let r = SplitSyncStartGate.resolveWaitByQuiescence(
            hasCompletedFirstImport: false, hasObservedImportActivity: true, isQuiescent: true,
            noImportGraceElapsed: true, reachedHardCap: false
        )
        #expect(r == .keepWaiting)
    }

    @Test func resolveByQuiescence_emptyStoreBranch_graceElapsedNoActivityButNotQuiet_keepsWaiting() {
        // Empty-store branch still ANDs with quiescence → an active (non-quiet) state keeps waiting.
        let r = SplitSyncStartGate.resolveWaitByQuiescence(
            hasCompletedFirstImport: false, hasObservedImportActivity: false, isQuiescent: false,
            noImportGraceElapsed: true, reachedHardCap: false
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

    // MARK: - needsRecordRecovery

    @Test func recordRecovery_noSystemFields_needsRecovery() {
        // Never round-tripped (e.g. dropped by CKSyncEngine after a definitive rejection — the
        // isOpeningBalance schema incident) → re-enqueue on launch.
        #expect(SplitSyncStartGate.needsRecordRecovery(hasSystemFields: false) == true)
    }

    @Test func recordRecovery_withSystemFields_skipped() {
        // Uploaded OR applied from a remote fetch (both populate ckSystemFieldsData) → leave alone.
        // This is what keeps the recovery from re-uploading other members' records (no sync storm).
        #expect(SplitSyncStartGate.needsRecordRecovery(hasSystemFields: true) == false)
    }

    // MARK: - classifyFailedSave

    @Test func classifyFailedSave_preHardeningCasesUnchanged() {
        // The first four dispositions must mirror the pre-hardening switch exactly.
        #expect(SplitSyncStartGate.classifyFailedSave(code: .serverRecordChanged) == .conflict)
        #expect(SplitSyncStartGate.classifyFailedSave(code: .zoneNotFound) == .zoneNotFound)
        #expect(SplitSyncStartGate.classifyFailedSave(code: .unknownItem) == .unknownItem)
        #expect(SplitSyncStartGate.classifyFailedSave(code: .quotaExceeded) == .quota)
    }

    @Test func classifyFailedSave_schemaAndPermissionErrors_areDefinitive() {
        // The server rejected the record itself — CKSyncEngine drops it from its queue and won't
        // retry. Re-enqueueing inline would loop forever on a schema error; the launch-time
        // recovery is the bounded retry. An un-deployed schema field surfaces as .invalidArguments.
        #expect(SplitSyncStartGate.classifyFailedSave(code: .invalidArguments) == .definitiveRejection)
        #expect(SplitSyncStartGate.classifyFailedSave(code: .serverRejectedRequest) == .definitiveRejection)
        #expect(SplitSyncStartGate.classifyFailedSave(code: .permissionFailure) == .definitiveRejection)
    }

    @Test func classifyFailedSave_transportErrors_areTransient() {
        // CKSyncEngine retries these on its own — log only, no special handling.
        #expect(SplitSyncStartGate.classifyFailedSave(code: .networkUnavailable) == .transient)
        #expect(SplitSyncStartGate.classifyFailedSave(code: .networkFailure) == .transient)
        #expect(SplitSyncStartGate.classifyFailedSave(code: .requestRateLimited) == .transient)
        #expect(SplitSyncStartGate.classifyFailedSave(code: .zoneBusy) == .transient)
        #expect(SplitSyncStartGate.classifyFailedSave(code: .serviceUnavailable) == .transient)
        #expect(SplitSyncStartGate.classifyFailedSave(code: .batchRequestFailed) == .transient)
    }
}
