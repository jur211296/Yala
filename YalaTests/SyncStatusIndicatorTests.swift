//
//  SyncStatusIndicatorTests.swift
//  YalaTests
//
//  Behavior tests for the passive top-bar sync indicator. These do not rely on
//  snapshot libraries — they verify the state machine that drives visibility
//  (shouldShow) and accessibility labels.
//

import CloudKit
import Foundation
import Testing

@testable import Yala

struct SyncStatusIndicatorTests {

    // MARK: - Visibility (needsAttention)

    @MainActor @Test func idle_isHidden() {
        let status: iCloudSyncService.SyncStatus = .idle
        #expect(status.needsAttention == false)
    }

    @MainActor @Test func syncing_isHidden() {
        let status: iCloudSyncService.SyncStatus = .syncing(kind: .exporting)
        #expect(status.needsAttention == false)
    }

    @MainActor @Test func success_isHidden() {
        let status: iCloudSyncService.SyncStatus = .success(.now)
        #expect(status.needsAttention == false)
    }

    @MainActor @Test func noAccount_isHidden() {
        let status: iCloudSyncService.SyncStatus = .noAccount
        #expect(status.needsAttention == false)
    }

    @MainActor @Test func failed_isVisible() {
        let status: iCloudSyncService.SyncStatus = .failed(
            code: .networkUnavailable,
            endDate: .now,
            retriable: true
        )
        #expect(status.needsAttention == true)
    }

    @MainActor @Test func stalled_isVisible() {
        let status: iCloudSyncService.SyncStatus = .stalled(
            daysSinceLastSuccess: 9,
            lastError: .quotaExceeded
        )
        #expect(status.needsAttention == true)
    }
}
