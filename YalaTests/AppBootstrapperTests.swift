//
//  AppBootstrapperTests.swift
//  YalaTests
//
//  Unit tests for AppBootstrapper retry logic and invite link handling.
//

import CloudKit
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

    // MARK: - shouldReEmitInvite — RETIRADO en la Fase 3
    //
    // Las 5 celdas cubrían el guard puro del re-emit de un invite pendiente, y el mecanismo entero
    // (`reEmitPendingInviteIfNeeded` + `PendingInviteStore`) era del canal CKShare que el commit 1 borra.
    // El canal backend no re-emite: su intención vive en `GroupBackendInviteEntryHandler.persistIntent` y
    // la retoma `GroupJoinReconciler` en sus tres triggers, con su propia cobertura.

    // MARK: - isRecoverableInviteFetchError (red transitoria vs permanente)

    @Test func isRecoverableInviteFetchError_networkErrors_returnTrue() {
        #expect(AppBootstrapper.isRecoverableInviteFetchError(CKError(.networkUnavailable)))
        #expect(AppBootstrapper.isRecoverableInviteFetchError(CKError(.networkFailure)))
        #expect(AppBootstrapper.isRecoverableInviteFetchError(CKError(.serviceUnavailable)))
        #expect(AppBootstrapper.isRecoverableInviteFetchError(CKError(.requestRateLimited)))
        #expect(AppBootstrapper.isRecoverableInviteFetchError(CKError(.zoneBusy)))
    }

    @Test func isRecoverableInviteFetchError_permanentErrors_returnFalse() {
        #expect(!AppBootstrapper.isRecoverableInviteFetchError(CKError(.unknownItem)))
        #expect(!AppBootstrapper.isRecoverableInviteFetchError(CKError(.permissionFailure)))
        #expect(!AppBootstrapper.isRecoverableInviteFetchError(CKError(.invalidArguments)))
    }

    @Test func isRecoverableInviteFetchError_nonCKError_returnsFalse() {
        struct Boom: Error {}
        #expect(!AppBootstrapper.isRecoverableInviteFetchError(Boom()))
    }
}
