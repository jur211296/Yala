//
//  AppBootstrapperTests.swift
//  YalaTests
//
//  Unit tests for AppBootstrapper retry logic and invite link handling.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite(.serialized)
struct AppBootstrapperTests {

    // MARK: - handleInviteLink invalid URL
    //
    // Note: end-to-end tests of `retryPendingBridges` crash the Swift Testing runner —
    // the bridge invokes globals (WidgetDataCache, BudgetAlertService, SessionState)
    // that assume a fully-configured app environment. The retry flow is exercised
    // manually via the smoke checklist instead.

    @Test func handleInviteLink_invalidURL_enqueuesShowInviteError() {
        #if DEBUG
        AppRouter.shared._testReset()
        AppRouter.shared.markReady(.contentView)
        #endif

        let bad = URL(string: "https://yala-app.pe/invite?broken")!
        AppBootstrapper.shared.handleInviteLink(bad)

        let peeked = AppRouter.shared.peekNext(for: .contentView)
        if case .showInviteError = peeked {
            #expect(true)
        } else {
            Issue.record("Expected .showInviteError to be enqueued, got: \(String(describing: peeked))")
        }
    }

    // MARK: - showGroupSyncError intent

    @Test func showGroupSyncError_routesToContentViewWithHighPriority() {
        let intent = RouterIntent.showGroupSyncError("boom")
        #expect(intent.handler == .contentView)
        #expect(intent.priority == .high)
        #expect(intent.id.contains("groupSyncError"))
    }

    @Test func showGroupSyncError_dedupesByMessage() {
        // Same message → same id (queue collapses to last-write-wins).
        let a = RouterIntent.showGroupSyncError("X")
        let b = RouterIntent.showGroupSyncError("X")
        #expect(a.id == b.id)
        // Different message → different id.
        let c = RouterIntent.showGroupSyncError("Y")
        #expect(a.id != c.id)
    }
}
