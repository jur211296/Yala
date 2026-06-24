//
//  MigrationGateLogic.swift
//  Yala
//
//  Pure-logic gate for the unified shortcutID + CSV mirror migration.
//  Decides whether to run the migration immediately or wait for CloudKit's
//  first import to complete (so M2M relations are hydrated).
//

import Foundation

enum MigrationGateLogic {

    enum WaitDecision: Equatable {
        /// Run the migration synchronously without awaiting CloudKit.
        case runNow
        /// Await `iCloudFirstImportCompleted` (with timeout) before running.
        case waitForHook
    }

    /// Decides whether the migration must wait for CloudKit's first import.
    ///
    /// - `isAccountAvailable=false` → no CloudKit, no lazy hydration race → run now.
    /// - `hasCompletedFirstImport=true` → import already settled → run now.
    /// - `iCloud available && import pending` → wait for hook (timeout-bounded).
    static func shouldWaitForCloudKit(
        isAccountAvailable: Bool,
        hasCompletedFirstImport: Bool
    ) -> WaitDecision {
        guard isAccountAvailable else { return .runNow }
        return hasCompletedFirstImport ? .runNow : .waitForHook
    }

    /// Decides whether the one-shot migration must be deferred because we waited
    /// for CloudKit's first import but it didn't settle within the timeout.
    ///
    /// Running the regen on a half-imported store is unrecoverable: it regenerates only
    /// the records present, marks its sentinel (which blocks re-runs), and the rest arrive
    /// collapsed and never heal. Deferring retries next launch. The repeatable self-healing
    /// in `CategoryDeduplicationService.repairCollapsedIdentityUUIDs` is the backstop, and
    /// the lazy CSV auto-heal covers the deferred backfill — so no cap is needed.
    ///
    /// - `waitedForSync=false` → ran now (offline or import already settled) → don't defer.
    /// - `waitedForSync=true && importSettled=true` → import completed → don't defer.
    /// - `waitedForSync=true && importSettled=false` → timed out on incomplete data → defer.
    static func shouldDeferMigration(waitedForSync: Bool, importSettled: Bool) -> Bool {
        waitedForSync && !importSettled
    }
}
