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

    // MARK: - decideStart — `.cloud` mirror confirmed OFF (H-2026-07-18, canary sweep)

    @Test func cloudMirrorOff_startsImmediately() {
        // `.cloud`: this process mounted the personal store with the mirror OFF → no
        // NSPersistentCloudKitContainer importer → no half-imported graph, no crash window → start now
        // WITHOUT waiting for a personal import that never comes. `hasCompletedFirstImport` stays false
        // forever in `.cloud` (nothing imports), so pre-fix this deferred → ~60s-late group sync each boot
        // + a spurious `cloudkitGroupSyncPromotedToAuto importSettled=false` canary.
        let decision = SplitSyncStartGate.decideStart(
            isAccountAvailable: true,
            hasCompletedFirstImport: false,
            personalMirrorConfirmedOff: true
        )
        #expect(decision == .startNow)
    }

    @Test func cloudMirrorOff_winsOverDeferUntilImport() {
        // Precedence: the SAME inputs that defer without the flag (account available, import pending)
        // must start immediately once the mirror is confirmed OFF — the new branch is evaluated FIRST.
        let deferred = SplitSyncStartGate.decideStart(
            isAccountAvailable: true, hasCompletedFirstImport: false, personalMirrorConfirmedOff: false
        )
        #expect(deferred == .deferUntilImport)
        let promoted = SplitSyncStartGate.decideStart(
            isAccountAvailable: true, hasCompletedFirstImport: false, personalMirrorConfirmedOff: true
        )
        #expect(promoted == .startNow)
    }

    @Test func mirrorNotConfirmedOff_matrixUnchanged() {
        // Regression: with `personalMirrorConfirmedOff: false` (the default — every `.icloud` device
        // today) the pre-fix decision matrix is byte-identical. The 2-arg calls above exercise the
        // default; this pins all four cells with the flag passed explicitly `false`.
        #expect(SplitSyncStartGate.decideStart(
            isAccountAvailable: false, hasCompletedFirstImport: false, personalMirrorConfirmedOff: false) == .startNow)
        #expect(SplitSyncStartGate.decideStart(
            isAccountAvailable: false, hasCompletedFirstImport: true, personalMirrorConfirmedOff: false) == .startNow)
        #expect(SplitSyncStartGate.decideStart(
            isAccountAvailable: true, hasCompletedFirstImport: true, personalMirrorConfirmedOff: false) == .startNow)
        #expect(SplitSyncStartGate.decideStart(
            isAccountAvailable: true, hasCompletedFirstImport: false, personalMirrorConfirmedOff: false) == .deferUntilImport)
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

// MARK: - BootSaveGateLogic (early-boot personal-store save gate — H-2026-07-18-8)

/// Pure-logic table for the boot-save gate. Same crash-loop invariant as the group gate, but the
/// hard cap must NEVER promote for boot-saves (forcing a mainContext save over a hung import is the
/// restore crash). Reuses `resolveWaitByQuiescence` internally with `reachedHardCap: false`.
@Suite("Boot Save Gate Logic")
struct BootSaveGateLogicTests {

    @Test func noAccount_runsImmediately() {
        // No CloudKit mirror → no half-imported personal graph can exist → save always safe.
        // (The other flags are stale/irrelevant when there's no account.)
        let d = BootSaveGateLogic.decide(
            isAccountAvailable: false, hasCompletedFirstImport: false,
            hasObservedImportActivity: false, isQuiescent: false, noImportGraceElapsed: false,
            isSyncingAnyPhase: false
        )
        #expect(d == .runNoAccount)
        #expect(d.isRun)
    }

    @Test func firstImportSettledAndQuiet_runs() {
        // The real import fired and went quiet → save safe (fast-path, INTACT).
        let d = BootSaveGateLogic.decide(
            isAccountAvailable: true, hasCompletedFirstImport: true,
            hasObservedImportActivity: true, isQuiescent: true, noImportGraceElapsed: false,
            isSyncingAnyPhase: false
        )
        #expect(d == .runImportSettled)
        #expect(d.isRun)
    }

    @Test func emptyStore_graceElapsedNoActivityQuiet_runs() {
        // THE H-8 FIX: a store that imports nothing (fresh-start wipe, data already all on the server)
        // never fires `.import`, so `hasCompletedFirstImport` stays false forever. After the grace with
        // NO import activity ever + quiet + fully idle → open the gate via the empty-store escape.
        let d = BootSaveGateLogic.decide(
            isAccountAvailable: true, hasCompletedFirstImport: false,
            hasObservedImportActivity: false, isQuiescent: true, noImportGraceElapsed: true,
            isSyncingAnyPhase: false
        )
        #expect(d == .runEmptyStore)
        #expect(d.isRun)
    }

    @Test func setupPhaseActive_waits_evenPastGraceNoActivity() {
        // ADVERSARIAL HARDENING CELL: a long `.syncing(.setup)` at the grace boundary — no `.import`
        // fired yet (activity false) and `isQuiescent` TRUE, because `isImportQuiescent` only checks
        // `.syncing(.importing)`, not `.setup`. Without `isSyncingAnyPhase` the empty-store escape would
        // open the gate while the restore handshake is still in flight. With it → wait. An idle empty
        // store is never in `.syncing`, so this guard does not reintroduce the H-8 hang.
        let d = BootSaveGateLogic.decide(
            isAccountAvailable: true, hasCompletedFirstImport: false,
            hasObservedImportActivity: false, isQuiescent: true, noImportGraceElapsed: true,
            isSyncingAnyPhase: true
        )
        #expect(d == .wait)
        #expect(!d.isRun)
    }

    @Test func graceNotElapsed_waits() {
        // At cold launch `isQuiescent` is true BEFORE any import starts. Until the grace elapses we
        // must WAIT — a populated restore's import may be imminent (promoting here is the premature-
        // promotion crash). This is the cell that protects a slow-starting real restore.
        let d = BootSaveGateLogic.decide(
            isAccountAvailable: true, hasCompletedFirstImport: false,
            hasObservedImportActivity: false, isQuiescent: true, noImportGraceElapsed: false,
            isSyncingAnyPhase: false
        )
        #expect(d == .wait)
        #expect(!d.isRun)
    }

    @Test func activityObservedButNotSettled_waits_realRestoreInFlight() {
        // THE INVARIANT CELL: a real restore whose import has STARTED (activity observed) but hasn't
        // completed — even momentarily quiescent, past the grace and with no phase currently in flight —
        // must NEVER open the gate. Keying the empty-store escape on `!hasObservedImportActivity` is
        // exactly what excludes a real restore: its import event flipped the activity flag, so
        // `.runEmptyStore` cannot fire, and without a completed first import `.runImportSettled` cannot
        // fire either → wait. A save here would land on a half-imported personal graph → SwiftData
        // `_assertionFailure` → crash-loop.
        let d = BootSaveGateLogic.decide(
            isAccountAvailable: true, hasCompletedFirstImport: false,
            hasObservedImportActivity: true, isQuiescent: true, noImportGraceElapsed: true,
            isSyncingAnyPhase: false
        )
        #expect(d == .wait)
        #expect(!d.isRun)
    }

    @Test func hungImportNotQuiescent_waits_evenPastGrace() {
        // A genuinely-hung/active import → `isQuiescent == false`. Every run branch ANDs with quiescence
        // and there's NO hard-cap promotion for boot-saves → keep waiting even past the grace (the caller's
        // total poll cap then ends the wait → DEFER, retried next launch). Forcing the save here would be
        // the crash.
        let d = BootSaveGateLogic.decide(
            isAccountAvailable: true, hasCompletedFirstImport: false,
            hasObservedImportActivity: false, isQuiescent: false, noImportGraceElapsed: true,
            isSyncingAnyPhase: true
        )
        #expect(d == .wait)
        #expect(!d.isRun)
    }

    @Test func settledButNotQuiet_waits() {
        // First import completed but a subsequent batch is importing (not quiet) → wait until it quiets.
        let d = BootSaveGateLogic.decide(
            isAccountAvailable: true, hasCompletedFirstImport: true,
            hasObservedImportActivity: true, isQuiescent: false, noImportGraceElapsed: true,
            isSyncingAnyPhase: true
        )
        #expect(d == .wait)
    }

    @Test func hardCapIsNeverConsulted_forBootSaves() {
        // Boot-saves have NO hard-cap promotion by construction: `decide` passes `reachedHardCap: false`
        // to `resolveWaitByQuiescence` internally. A state that the GROUP gate would force-promote on the
        // cap (nothing settled, not quiet, past grace, activity in flight) stays `.wait` here — proving a
        // hung import can never be force-saved. Contrast: the group gate promotes the SAME inputs on cap.
        let bootDecision = BootSaveGateLogic.decide(
            isAccountAvailable: true, hasCompletedFirstImport: false,
            hasObservedImportActivity: true, isQuiescent: false, noImportGraceElapsed: true,
            isSyncingAnyPhase: false
        )
        #expect(bootDecision == .wait)
        let groupWouldForce = SplitSyncStartGate.resolveWaitByQuiescence(
            hasCompletedFirstImport: false, hasObservedImportActivity: true, isQuiescent: false,
            noImportGraceElapsed: true, reachedHardCap: true
        )
        #expect(groupWouldForce == .start)  // The group ENGINE gate DOES promote on cap — harmless there.
    }
}
