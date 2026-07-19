//
//  SplitSyncStartGate.swift
//  Yala
//
//  Pure-logic gate for starting the group CKSyncEngines.
//  On a device restored from iCloud, the personal store (NSPersistentCloudKitContainer,
//  `.private`) imports into the SHARED `mainContext` while the group sync (CKSyncEngine,
//  store `.none`) would `save()` on that same context. Saving over a half-imported
//  personal graph triggers an internal SwiftData `_assertionFailure` (SIGTRAP, NOT a
//  catchable throw → the process dies, re-entering a crash loop on every cold launch).
//
//  This gate defers CREATING the engines until the personal first import has settled
//  (or there's no iCloud). No events are lost: the queue lives in CloudKit + the local
//  `stateSerialization`; the engines resume and fetch pending changes once created.
//
//  See `MigrationGateLogic` — same "wait for first import" semantics for the V3 migration.
//

import CloudKit
import Foundation

enum SplitSyncStartGate {

    enum StartDecision: Equatable {
        /// Create the engines immediately (offline → no import race; or import already settled).
        case startNow
        /// Defer creation until the personal first import settles.
        case deferUntilImport
    }

    /// Decides whether the group engines can start immediately.
    ///
    /// - `isAccountAvailable=false` → no CloudKit, no half-imported personal graph → start now.
    /// - `hasCompletedFirstImport=true` → personal import settled → start now.
    /// - `iCloud available && import pending` → defer until the first import completes.
    ///
    /// An EMPTY personal store (e.g. a groups-only user who never created personal data) never fires a
    /// `.import` event, so `hasCompletedFirstImport` stays `false` and this returns `.deferUntilImport`. That
    /// case is promoted later by `resolveWaitByQuiescence`'s empty-store branch (no import observed within the
    /// grace + quiescent) — NOT here, so the quiescence/no-activity guards stay live even at cold launch.
    static func decideStart(
        isAccountAvailable: Bool,
        hasCompletedFirstImport: Bool
    ) -> StartDecision {
        guard isAccountAvailable else { return .startNow }
        return hasCompletedFirstImport ? .startNow : .deferUntilImport
    }

    enum WaitResolution: Equatable {
        /// Create the engines now.
        case start
        /// Keep waiting for the import to settle.
        case keepWaiting
    }

    // MARK: - Promote by QUIESCENCE (not first import)

    /// Decides, on each periodic poll while deferred, whether to PROMOTE the engines to auto-sync —
    /// gating on **import quiescence** + **observed import activity** instead of the first `importEvent`.
    ///
    /// The first import is a PREMATURE signal on a multi-batch restore: NSPersistentCloudKitContainer
    /// keeps importing after the first event fires, so promoting there turns off the delegate-save gate
    /// (`shouldDeferDelegateSave`) while the personal graph is still half-imported → the next delegate
    /// `save()` trips SwiftData's `_assertionFailure`. Waiting for quiescence (no import in flight AND
    /// past a quiet window — `iCloudSyncService.isImportQuiescent`, itself `SubcategoryDedupGate.decide`)
    /// keeps the engines export-only through the WHOLE active import. In export-only there's no
    /// auto-fetch, so deferring loses nothing: fetched changes only arrive after promotion = after the
    /// store is quiet.
    ///
    /// - `reachedHardCap=true` → absolute last-resort cap reached → promote anyway (a warning is logged;
    ///   a stuck-`.syncing` import must not hang group sync forever). The per-save breadcrumb + the
    ///   delegate's own gating remain as the last line of defense in that rare case.
    /// - `hasCompletedFirstImport && isQuiescent` → the import actually started, finished, and went
    ///   quiet → promote. Both are required: `isQuiescent` alone is `true` BEFORE any import starts
    ///   (`lastImportDate == nil`), which would promote prematurely on a restore where the import is
    ///   still pending; gating also on `hasCompletedFirstImport` ensures we waited for it to happen.
    /// - `noImportGraceElapsed && !hasObservedImportActivity && isQuiescent` → EMPTY store: the grace window
    ///   passed and NO `.import` ever appeared (a populated account would have fired an import event by now),
    ///   and the store is quiet → safe to promote. This is what unblocks a user with no personal data (e.g.
    ///   groups-only) whose empty `.private` store never fires `.import`, so `hasCompletedFirstImport` stays
    ///   `false` forever. Keying on *absence of observed import activity* (not the onboarding mode) is the
    ///   safe distinguisher: a populated store on restore sets `hasObservedImportActivity` as soon as the
    ///   import starts → this branch never fires for it → it waits for the real import via the branch above.
    /// - otherwise → keep waiting.
    static func resolveWaitByQuiescence(
        hasCompletedFirstImport: Bool,
        hasObservedImportActivity: Bool,
        isQuiescent: Bool,
        noImportGraceElapsed: Bool,
        reachedHardCap: Bool
    ) -> WaitResolution {
        if reachedHardCap { return .start }
        if hasCompletedFirstImport && isQuiescent { return .start }
        if noImportGraceElapsed && !hasObservedImportActivity && isQuiescent { return .start }
        return .keepWaiting
    }

    /// `true` when the engines are promoted without a settled+quiet store (i.e. via the hard cap).
    /// The call site logs a diagnostic warning + telemetry in that case.
    static func promotedWhileNotQuiescent(hasCompletedFirstImport: Bool, isQuiescent: Bool) -> Bool {
        !(hasCompletedFirstImport && isQuiescent)
    }

    // MARK: - Delegate save gate

    /// Whether a `modelContext.save()` from the group sync delegate must be **deferred**.
    ///
    /// While the engines run in "export-only" mode (`automaticallySync = false`, set before the
    /// personal first import settles), any `save()` of the shared `mainContext` could persist the
    /// half-imported personal graph and trip SwiftData's internal `_assertionFailure`. The delegate
    /// gates every save on this: defer (in-memory cleanup only) until the engines are promoted to
    /// auto-sync (`autoSyncActive == true`). The fetch after promotion reconciles anything skipped.
    static func shouldDeferDelegateSave(autoSyncActive: Bool) -> Bool {
        !autoSyncActive
    }

    // MARK: - Zone recovery

    /// Whether an owned group needs its CloudKit zone re-enqueued on engine startup.
    ///
    /// A group created while the engines were deferred (old gate) had its `createZone` no-op'd →
    /// the zone + GroupMeta never reached CloudKit (it can't be invited). `ckSystemFieldsData` is
    /// only populated after a successful GroupMeta upload (`storeSystemFields`), so an owned group
    /// with no system fields never uploaded → re-enqueue its zone (idempotent). Groups already
    /// synced (system fields present) are skipped — no sync storm.
    static func needsZoneRecovery(isOwner: Bool, hasSystemFields: Bool) -> Bool {
        isOwner && !hasSystemFields
    }

    // MARK: - Record recovery

    /// Whether an individual group record (member/expense/share/settlement) needs re-enqueueing on
    /// engine startup because it never round-tripped to CloudKit.
    ///
    /// `ckSystemFieldsData` is populated on BOTH sides of a round-trip: successful uploads
    /// (`storeSystemFields`) and records applied from a remote fetch (`CKRecordTranslator` encodes
    /// the fetched record's system fields). So `nil` ≡ created locally and never accepted by the
    /// server — e.g. dropped by CKSyncEngine after a definitive rejection (the `isOpeningBalance`
    /// schema incident, 27-jun→1-jul) or enqueued right before a kill. Benign false positive: an
    /// upload whose system-fields save was deferred during the export-only window re-uploads once
    /// and reconciles via `serverRecordChanged` (server wins, system fields re-captured).
    static func needsRecordRecovery(hasSystemFields: Bool) -> Bool {
        !hasSystemFields
    }

    // MARK: - Failed save classification

    /// What to do with a record save that CloudKit reported as failed.
    ///
    /// CKSyncEngine REMOVES a failed record save from its pending queue after reporting it — it
    /// only retries transport-level failures on its own. Anything the delegate doesn't re-enqueue
    /// is gone until something re-enqueues it (user edit, or `recoverUnsyncedRecordsIfNeeded` on
    /// the next launch via the nil-system-fields heuristic).
    enum FailedSaveDisposition: Equatable {
        /// `serverRecordChanged` — resolve via conflict handler (server wins).
        case conflict
        /// `zoneNotFound` — group's zone is gone; clean up the local cache.
        case zoneNotFound
        /// `unknownItem` — record deleted on server; drop local pending tracking.
        case unknownItem
        /// `quotaExceeded` — park for retry when quota may have changed.
        case quota
        /// Server rejected the record itself (schema mismatch, permissions). NOT retried inline —
        /// a schema error would loop forever; the launch-time recovery re-enqueues it instead.
        case definitiveRejection
        /// Transient (network, rate limit, batch): CKSyncEngine retries these on its own.
        case transient
    }

    /// Maps a `CKError.Code` from `failedRecordSaves` to its handling. The first four cases mirror
    /// the pre-hardening switch exactly (no behavior change); the split of the old `default:` into
    /// `definitiveRejection`/`transient` is what makes schema rejections visible and consciously
    /// NOT re-enqueued inline.
    static func classifyFailedSave(code: CKError.Code) -> FailedSaveDisposition {
        switch code {
        case .serverRecordChanged: return .conflict
        case .zoneNotFound: return .zoneNotFound
        case .unknownItem: return .unknownItem
        case .quotaExceeded: return .quota
        case .invalidArguments, .serverRejectedRequest, .permissionFailure: return .definitiveRejection
        default: return .transient
        }
    }
}

// MARK: - Boot-save gate

/// Pure gate for early-boot **personal-store** `save()`s — the ~8 boot tasks funneled through
/// `AppBootstrapper.awaitPersonalImportForBootSave` (retryPendingBridges, migrateShareGroupZoneIDs,
/// scheduled-payment / exchange-rate / provisional-tx drains, reconciles, sendDueReports, …). A
/// `save()` of the shared `mainContext` while NSPersistentCloudKitContainer is still importing trips
/// SwiftData's internal `_assertionFailure` (SIGTRAP, NOT catchable → crash-loop on an iCloud restore).
///
/// This composes the correct branches for boot-saves as ONE testable truth, reusing the group gate's
/// `resolveWaitByQuiescence` for the promote/wait decision — but with **`reachedHardCap` HARDCODED to
/// `false`**. That asymmetry is the whole point: the group ENGINE gate may promote on the hard cap
/// because promoting an export-only engine is harmless (it just enables auto-fetch), whereas forcing a
/// mainContext `save()` while a genuinely-hung import is in flight (`isSyncing` → `isQuiescent == false`)
/// is exactly the restore crash. So the caller's total poll cap only ENDS THE WAIT (→ DEFER, retried
/// next launch); it never forces a save.
///
/// Why a wrapper (not just calling `resolveWaitByQuiescence` inline in the caller): `resolveWaitByQuiescence`
/// does NOT model the no-account short-circuit, and the caller (`awaitPersonalImportForBootSave`) is the
/// untested runtime shell. Folding no-account + hard-cap-off + path naming here keeps the entire boot-save
/// composition unit-tested in one place (`BootSaveGateLogicTests` cells in `SplitSyncStartGateTests`).
enum BootSaveGateLogic {

    /// Resolution of the boot-save gate. `isRun` opens the save; each run case names WHY (for path-
    /// specific breadcrumbs at the call site).
    enum Decision: Equatable {
        /// No CloudKit account → no mirror → no half-imported personal graph can exist → save is safe.
        case runNoAccount
        /// The real personal import fired AND went quiet (fast-path). Protects a genuine restore: while
        /// it's still importing (`hasObservedImportActivity == true`, `hasCompletedFirstImport` not yet),
        /// `isQuiescent` is `false` → this does NOT fire → the gate keeps waiting.
        case runImportSettled
        /// EMPTY store escape (H-2026-07-18-8): the grace passed, NO `.import` was EVER observed, the
        /// store is quiet, AND no sync phase of ANY kind is in flight (`!isSyncingAnyPhase` — covers
        /// `.setup`/`.exporting`, which `isQuiescent` does NOT: it only checks `.syncing(.importing)`).
        /// A store that imports nothing (e.g. a fresh-start wipe whose data is already all on the
        /// server → `hasCompletedFirstImport` stays `false` forever) sits idle, so the extra guard does
        /// not reintroduce the H-8 hang. SUPUESTO (not a guarantee): a populated restore *usually* fires
        /// its `.import` within the grace (flipping `hasObservedImportActivity`) or is at least in a
        /// `.syncing` phase at the boundary — both keep this branch closed. RESIDUAL EXPLÍCITO: a restore
        /// whose FIRST `.import` arrives >60s in with NOTHING active at the tick (no `.setup`, no
        /// `.import` yet, fully idle) would open the gate pre-import. That save lands on the LOCAL
        /// pre-import graph — NOT the crash condition, which is a save DURING an active import over a
        /// half-imported graph (invariante device-confirmed 2026-06-22, build 32).
        case runEmptyStore
        /// Keep waiting: grace not elapsed, a real restore is still importing, or an import is hung
        /// (`isSyncing` → not quiescent). The caller polls until this flips or its total cap ends the wait.
        case wait

        var isRun: Bool { self != .wait }
    }

    /// Decides whether an early-boot personal-store save is safe RIGHT NOW.
    ///
    /// Decision table (mutually exclusive by construction — `hasCompletedFirstImport == true` implies
    /// `hasObservedImportActivity == true`, since the activity flag is set at the top of the import
    /// event handler before the completion check. SEAM EXCEPTION: `_uiTestSimulateAvailableAccount()`
    /// breaks the implication — it sets `hasCompletedFirstImport` directly without the activity flag.
    /// Harmless: the fast-path fires first for it, so the classification below never mislabels):
    ///   - `!isAccountAvailable`                                                 → `.runNoAccount`
    ///   - `hasCompletedFirstImport && isQuiescent`                              → `.runImportSettled`
    ///   - `noImportGraceElapsed && !hasObservedImportActivity && isQuiescent
    ///      && !isSyncingAnyPhase`                                               → `.runEmptyStore`
    ///   - otherwise (incl. `isSyncing`/hung import: `isQuiescent == false`)     → `.wait`
    ///
    /// - Parameter isSyncingAnyPhase: `true` while the container is in ANY `.syncing` phase — incl.
    ///   `.setup` and `.exporting`, which `isQuiescent` does NOT see (it only checks
    ///   `.syncing(.importing)`). Hardens ONLY the empty-store escape: a long `.setup` at the grace
    ///   boundary (restore still handshaking, `.import` not fired yet) must keep waiting. The fast-path
    ///   is intentionally NOT gated on it — identical to the pre-fix behavior.
    /// - Note: `reachedHardCap` is intentionally passed `false` to `resolveWaitByQuiescence` — see the
    ///   type doc. There is NO hard-cap promotion for boot-saves.
    static func decide(
        isAccountAvailable: Bool,
        hasCompletedFirstImport: Bool,
        hasObservedImportActivity: Bool,
        isQuiescent: Bool,
        noImportGraceElapsed: Bool,
        isSyncingAnyPhase: Bool
    ) -> Decision {
        guard isAccountAvailable else { return .runNoAccount }
        let resolution = SplitSyncStartGate.resolveWaitByQuiescence(
            hasCompletedFirstImport: hasCompletedFirstImport,
            hasObservedImportActivity: hasObservedImportActivity,
            isQuiescent: isQuiescent,
            noImportGraceElapsed: noImportGraceElapsed,
            reachedHardCap: false  // boot-saves NEVER force on the cap — that would be the restore crash.
        )
        guard resolution == .start else { return .wait }
        // With `reachedHardCap == false`, `.start` means exactly one of the two run branches fired.
        // They're mutually exclusive (see the note above), so this cleanly identifies which.
        if hasCompletedFirstImport && isQuiescent { return .runImportSettled }
        // Empty-store escape — HARDENED: any in-flight `.syncing` phase (setup/export) closes it.
        return isSyncingAnyPhase ? .wait : .runEmptyStore
    }
}
