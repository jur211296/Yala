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
}
