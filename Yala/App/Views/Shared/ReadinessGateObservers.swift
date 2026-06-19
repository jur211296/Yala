//
//  ReadinessGateObservers.swift
//  Yala
//
//  ViewModifier that wires up `onChange(of:)` observers for every shell-level
//  modal flag, calling `recompute` whenever any flips. Kept as a ViewModifier
//  so ContentView.body stays within the type-checker budget.
//

import SwiftUI

private struct ReadinessGateObserversModifier: ViewModifier {
    let showOnboarding: Bool
    let showWelcomeFlow: Bool
    let showLanguageSelection: Bool
    let showWelcomeRestore: Bool
    let showInviteRecovery: Bool
    let showFreshStartWipeAlert: Bool
    let showRemoteWipeAlert: Bool
    let showICloudRestartAlert: Bool
    let activeInboxNotification: PendingInboxNotification
    let showGroupInviteOnboarding: Bool
    let showGroupReconnect: Bool
    let showFullModeActivation: Bool
    let recompute: () -> Void

    func body(content: Content) -> some View {
        content
            .onChange(of: showOnboarding) { _, _ in recompute() }
            .onChange(of: showWelcomeFlow) { _, _ in recompute() }
            .onChange(of: showLanguageSelection) { _, _ in recompute() }
            .onChange(of: showWelcomeRestore) { _, _ in recompute() }
            .onChange(of: showInviteRecovery) { _, _ in recompute() }
            .onChange(of: showFreshStartWipeAlert) { _, _ in recompute() }
            .onChange(of: showRemoteWipeAlert) { _, _ in recompute() }
            .onChange(of: showICloudRestartAlert) { _, _ in recompute() }
            .onChange(of: activeInboxNotification) { _, _ in recompute() }
            .onChange(of: showGroupInviteOnboarding) { _, _ in recompute() }
            .onChange(of: showGroupReconnect) { _, _ in recompute() }
            .onChange(of: showFullModeActivation) { _, _ in recompute() }
    }
}

extension View {
    func readinessGateObservers(
        showOnboarding: Bool,
        showWelcomeFlow: Bool,
        showLanguageSelection: Bool,
        showWelcomeRestore: Bool,
        showInviteRecovery: Bool,
        showFreshStartWipeAlert: Bool,
        showRemoteWipeAlert: Bool,
        showICloudRestartAlert: Bool,
        activeInboxNotification: PendingInboxNotification,
        showGroupInviteOnboarding: Bool,
        showGroupReconnect: Bool,
        showFullModeActivation: Bool,
        recompute: @escaping () -> Void
    ) -> some View {
        modifier(ReadinessGateObserversModifier(
            showOnboarding: showOnboarding,
            showWelcomeFlow: showWelcomeFlow,
            showLanguageSelection: showLanguageSelection,
            showWelcomeRestore: showWelcomeRestore,
            showInviteRecovery: showInviteRecovery,
            showFreshStartWipeAlert: showFreshStartWipeAlert,
            showRemoteWipeAlert: showRemoteWipeAlert,
            showICloudRestartAlert: showICloudRestartAlert,
            activeInboxNotification: activeInboxNotification,
            showGroupInviteOnboarding: showGroupInviteOnboarding,
            showGroupReconnect: showGroupReconnect,
            showFullModeActivation: showFullModeActivation,
            recompute: recompute
        ))
    }
}
