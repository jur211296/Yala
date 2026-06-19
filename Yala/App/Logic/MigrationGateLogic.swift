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
}
