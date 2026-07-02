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
