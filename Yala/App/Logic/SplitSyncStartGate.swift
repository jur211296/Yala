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
    /// gating on **import quiescence** instead of the first `importEvent`.
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
    /// - otherwise → keep waiting.
    static func resolveWaitByQuiescence(
        hasCompletedFirstImport: Bool,
        isQuiescent: Bool,
        reachedHardCap: Bool
    ) -> WaitResolution {
        if reachedHardCap { return .start }
        if hasCompletedFirstImport && isQuiescent { return .start }
        return .keepWaiting
    }

    /// `true` when the engines are promoted without a settled+quiet import (i.e. via the hard cap).
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
}
