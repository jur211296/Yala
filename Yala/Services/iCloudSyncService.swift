//
//  iCloudSyncService.swift
//  Yala
//
//  Monitors iCloud sync status for UI display.
//  Sync is always enabled when iCloud account is available.
//

import CloudKit
import Foundation
import Observation
import SwiftData

/// Monitors iCloud sync status for UI display
@Observable
@MainActor
final class iCloudSyncService {

    // MARK: - Singleton

    static let shared = iCloudSyncService()

    // MARK: - State

    enum SyncStatus: Equatable {
        case idle
        case syncing
        case error(String)
        case noAccount
    }

    private(set) var syncStatus: SyncStatus = .idle
    private(set) var lastSyncDate: Date?

    /// Whether iCloud account is available (sync is automatic when true)
    var isAccountAvailable: Bool {
        SwiftDataConfiguration.isICloudAvailable()
    }

    /// Split group sync status (from CKSyncEngine)
    var splitSyncStatus: SplitSyncManager.SyncStatus {
        SplitSyncManager.shared.syncStatus
    }

    // MARK: - Initialization

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(accountDidChange),
            name: .NSUbiquityIdentityDidChange,
            object: nil
        )
        checkAccountStatus()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Account Status

    func checkAccountStatus() {
        if !isAccountAvailable {
            syncStatus = .noAccount
            return
        }

        syncStatus = .idle
    }

    @objc private func accountDidChange() {
        checkAccountStatus()
    }

    // MARK: - Force Sync

    /// Pings CloudKit to wake up the sync engine, saves local changes,
    /// deduplicates seed categories, and refreshes all views.
    func forceSync(modelContext: ModelContext) async {
        guard isAccountAvailable else {
            syncStatus = .noAccount
            return
        }
        guard syncStatus != .syncing else { return }

        syncStatus = .syncing

        do {
            // 1. Ping CloudKit — wakes up the sync engine
            let container = CKContainer(identifier: SwiftDataConfiguration.cloudKitContainerIdentifier)
            _ = try await container.privateCloudDatabase.allRecordZones()

            // 2. Save context — pushes pending local changes
            try modelContext.save()

            // 3. Deduplicate seed categories
            CategoryDeduplicationService.deduplicateSeedCategories(in: modelContext)

            // 4. Refresh UI
            SessionState.shared.incrementDataVersion()

            lastSyncDate = Date.now
            syncStatus = .idle
        } catch {
            #if DEBUG
            print("iCloudSync: Force sync error: \(error)")
            #endif
            syncStatus = .error(L10n.iCloud.statusError)
            do {
                try await Task.sleep(for: .seconds(3))
            } catch {
                // Task cancelled — reset immediately
            }
            syncStatus = .idle
        }
    }
}
