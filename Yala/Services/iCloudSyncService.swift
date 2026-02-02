//
//  iCloudSyncService.swift
//  Yala
//
//  Monitors iCloud sync status for UI display.
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
        case disabled
        case noAccount
    }

    private(set) var syncStatus: SyncStatus = .idle
    private(set) var lastSyncDate: Date?

    /// Whether iCloud sync is enabled by user
    var isEnabled: Bool {
        get { SwiftDataConfiguration.iCloudSyncEnabled }
        set {
            SwiftDataConfiguration.iCloudSyncEnabled = newValue
            if newValue {
                checkAccountStatus()
            } else {
                syncStatus = .disabled
            }
        }
    }

    /// Whether iCloud account is available
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
        if !isEnabled {
            syncStatus = .disabled
            return
        }

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
