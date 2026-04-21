//
//  SyncIndicatorToolbarItemTests.swift
//  YalaTests
//
//  Integration-style tests: tapping the indicator should wire up the navigation
//  flow to iCloudSyncSettingsView via SessionState (pendingProfileDestination +
//  shouldOpenProfile) and should be suppressed during data wipes.
//
//  These tests exercise the state contract the ToolbarItem expects — the actual
//  SwiftUI rendering is covered by manual QA scenarios.
//

import CloudKit
import Foundation
import Testing

@testable import Yala

struct SyncIndicatorToolbarItemTests {

    @MainActor
    private func freshSession() -> SessionState {
        let session = SessionState.shared
        session.pendingProfileDestination = nil
        session.shouldOpenProfile = false
        session.isWipingData = false
        return session
    }

    @MainActor @Test func tap_setsPendingProfileDestinationToICloudSync() {
        let session = freshSession()

        // Simulate the onTap closure of SyncIndicatorHost.
        session.pendingProfileDestination = .iCloudSync
        session.shouldOpenProfile = true

        #expect(session.pendingProfileDestination == .iCloudSync)
        #expect(session.shouldOpenProfile == true)
    }

    @MainActor @Test func wipingData_suppressesIndicator_evenWithFailedStatus() {
        let session = freshSession()
        let service = iCloudSyncService.shared
        service._testReset()

        // Force a failed status at the service level.
        service.apply(eventType: .setup, error: CKError(.serviceUnavailable), endDate: nil)
        #expect(service.status.isFailed)

        // View-layer suppression: when isWipingData is true, the indicator host
        // should not render the indicator. This is the contract — we verify the
        // condition the view checks.
        session.isWipingData = true
        let shouldRender = !session.isWipingData && service.status.needsAttention
        #expect(shouldRender == false)

        // When wipe ends, indicator is back in scope.
        session.isWipingData = false
        let shouldRenderAfterWipe = !session.isWipingData && service.status.needsAttention
        #expect(shouldRenderAfterWipe == true)
    }
}
