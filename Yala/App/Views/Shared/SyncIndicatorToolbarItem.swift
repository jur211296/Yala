//
//  SyncIndicatorToolbarItem.swift
//  Yala
//
//  ToolbarContent wrapper that places the SyncStatusIndicator in the top-trailing
//  slot before ProfileToolbarItem. Observes iCloudSyncService.shared for status
//  and SessionState for wipe suppression.
//
//  Wipe suppression lives here (in the view), not in the service — single source
//  of truth. Service always records real events; view decides visibility.
//

import SwiftUI

struct SyncIndicatorToolbarItem: ToolbarContent {
    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            SyncIndicatorHost()
        }
        .sharedBackgroundVisibility(.hidden)
    }
}

private struct SyncIndicatorHost: View {
    @State private var service = iCloudSyncService.shared
    @Environment(SessionState.self) private var sessionState

    var body: some View {
        if !sessionState.isWipingData {
            SyncStatusIndicator(status: service.status) {
                TelemetryService.track(.cloudkitIndicatorTapped)
                sessionState.pendingProfileDestination = .iCloudSync
                sessionState.shouldOpenProfile = true
            }
        }
    }
}
