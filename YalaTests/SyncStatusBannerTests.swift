//
//  SyncStatusBannerTests.swift
//  YalaTests
//
//  Tests for the global sync status banner. Validates visibility rules based
//  on `iCloudSyncService.SyncStatus` + wipe suppression, and the color tokens
//  per state. The banner replaces the former top-bar SyncStatusIndicator.
//
//  Note: SwiftUI View bodies are not introspected directly — the banner's
//  visibility is a pure function of `status.needsAttention && !isWiping`,
//  and its colors are pure functions of `status`. We test those contracts.
//

import CloudKit
import Foundation
import SwiftUI
import Testing

@testable import Yala

struct SyncStatusBannerTests {

    // MARK: - Helpers

    @MainActor
    private func freshService() -> iCloudSyncService {
        let service = iCloudSyncService.shared
        service._testReset()
        return service
    }

    /// Visibility predicate matches what `SyncStatusBannerHost` evaluates.
    private func shouldShowBanner(status: iCloudSyncService.SyncStatus, isWiping: Bool) -> Bool {
        status.needsAttention && !isWiping
    }

    // MARK: - Visibility — hidden states

    @MainActor @Test func banner_hidden_whenIdle() {
        let service = freshService()
        #expect(shouldShowBanner(status: service.status, isWiping: false) == false)
    }

    @MainActor @Test func banner_hidden_whenSuccess() {
        let service = freshService()
        service.apply(eventType: .exportEvent, error: nil, endDate: .now)
        #expect(shouldShowBanner(status: service.status, isWiping: false) == false)
    }

    @MainActor @Test func banner_hidden_whenSyncing() {
        let service = freshService()
        service.apply(eventType: .importEvent, error: nil, endDate: nil)
        #expect(shouldShowBanner(status: service.status, isWiping: false) == false)
    }

    /// Covers gap in prior indicator tests: if account was lost after a failure
    /// history, `.noAccount` takes over and banner must hide (user sees Sync
    /// Settings "no account" state instead).
    @MainActor @Test func banner_hidden_whenNoAccount_evenAfterFailureHistory() {
        let service = freshService()
        // Seed failure history
        service.apply(eventType: .exportEvent, error: CKError(.networkUnavailable), endDate: nil)
        // Then receive notAuthenticated → transitions to .noAccount
        service.apply(eventType: .exportEvent, error: CKError(.notAuthenticated), endDate: nil)
        #expect(service.status.isNoAccount)
        #expect(shouldShowBanner(status: service.status, isWiping: false) == false)
    }

    // MARK: - Visibility + colors — visible states

    @MainActor @Test func banner_visible_andErrorTinted_whenFailed() {
        let service = freshService()
        service._qaSimulateFailed(code: .networkUnavailable, visibleFor: 60)
        #expect(service.status.isFailed)
        #expect(shouldShowBanner(status: service.status, isWiping: false))

        let style = SyncStatusBanner.Style.make(for: service.status)
        #expect(style?.foreground == DS.Semantic.errorForeground)
        #expect(style?.background == DS.Semantic.errorBackground)

        service._testReset()
    }

    @MainActor @Test func banner_visible_andWarningTinted_whenStalled() {
        let service = freshService()
        service._qaSimulateStalled(days: 9, visibleFor: 60)
        #expect(service.status.isStalled)
        #expect(shouldShowBanner(status: service.status, isWiping: false))

        let style = SyncStatusBanner.Style.make(for: service.status)
        #expect(style?.foreground == DS.Semantic.warningForeground)
        #expect(style?.background == DS.Semantic.warningBackground)

        service._testReset()
    }

    // MARK: - Wipe suppression

    @MainActor @Test func banner_suppressed_whenWipingData_evenIfFailed() {
        let service = freshService()
        service._qaSimulateFailed(code: .networkUnavailable, visibleFor: 60)
        #expect(service.status.isFailed)
        #expect(shouldShowBanner(status: service.status, isWiping: true) == false)
        service._testReset()
    }
}
