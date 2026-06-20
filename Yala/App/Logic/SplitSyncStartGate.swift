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

    /// Decides, on each periodic poll while deferred, whether to start the engines.
    ///
    /// - `hasCompletedFirstImport=true` → import settled → start. This is the normal path:
    ///   a slow restore is respected because we only start once the import actually completes
    ///   (resolves the "fixed timeout cuts a slow restore" risk).
    /// - `reachedHardCap=true` → absolute last-resort cap reached → start anyway (a warning is
    ///   logged at the call site so a re-crash is diagnosable). The cap MUST start regardless of
    ///   sync state, otherwise a stuck-`.syncing` import would hang group sync forever.
    /// - otherwise → keep waiting (the `.iCloudFirstImportCompleted` observer is the fast path).
    static func resolveWait(
        hasCompletedFirstImport: Bool,
        reachedHardCap: Bool
    ) -> WaitResolution {
        if hasCompletedFirstImport { return .start }
        if reachedHardCap { return .start }
        return .keepWaiting
    }

    /// `true` when the engines are about to start without a confirmed personal import
    /// (i.e. via the hard cap). The call site logs a diagnostic warning in that case.
    static func startedOnIncompleteImport(hasCompletedFirstImport: Bool) -> Bool {
        !hasCompletedFirstImport
    }
}
