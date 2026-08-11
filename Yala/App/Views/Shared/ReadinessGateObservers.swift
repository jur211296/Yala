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
    let forceUpdateRequired: Bool
    let showOnboarding: Bool
    let showWelcomeFlow: Bool
    let showLanguageSelection: Bool
    let showWelcomeRestore: Bool
    let showInviteRecovery: Bool
    let showWelcomeCloudSignIn: Bool
    let showSignOutRelaunch: Bool
    let secondaryEntryRelaunch: Bool
    let showFreshStartWipeAlert: Bool
    let showRemoteWipeAlert: Bool
    let showICloudRestartAlert: Bool
    let showRestoreOffer: Bool
    let hasActiveInviteError: Bool
    let hasActiveGroupSyncError: Bool
    let activeInboxNotification: PendingInboxNotification
    let showGroupInviteOnboarding: Bool
    let showGroupReconnect: Bool
    let showGroupsConsent: Bool
    let showGroupsSignIn: Bool
    let showGroupsOrganizerName: Bool
    let showFullModeActivation: Bool
    let showProTrialOffer: Bool
    let showWhatsNew: Bool
    let showSyncSettingsSheet: Bool
    let recompute: () -> Void

    func body(content: Content) -> some View {
        // Cadena partida en TRES sub-expresiones: 25 onChange encadenados en una sola exceden el
        // presupuesto del type-checker, y con 17 en un solo helper ya volvía a excederlo (G3, al añadir
        // `showGroupsOrganizerName`). Si añades un observador y el build se queja de «unable to
        // type-check in reasonable time», parte otra vez — no es tu expresión, es la longitud.
        alertObservers(groupObservers(welcomeObservers(content)))
    }

    private func welcomeObservers(_ content: some View) -> some View {
        content
            .onChange(of: showOnboarding) { _, _ in recompute() }
            .onChange(of: showWelcomeFlow) { _, _ in recompute() }
            .onChange(of: showLanguageSelection) { _, _ in recompute() }
            .onChange(of: showWelcomeRestore) { _, _ in recompute() }
            .onChange(of: showInviteRecovery) { _, _ in recompute() }
            .onChange(of: showWelcomeCloudSignIn) { _, _ in recompute() }
            .onChange(of: showSignOutRelaunch) { _, _ in recompute() }
            .onChange(of: secondaryEntryRelaunch) { _, _ in recompute() }
    }

    private func groupObservers(_ content: some View) -> some View {
        content
            .onChange(of: showGroupInviteOnboarding) { _, _ in recompute() }
            .onChange(of: showGroupReconnect) { _, _ in recompute() }
            .onChange(of: showGroupsConsent) { _, _ in recompute() }
            .onChange(of: showGroupsSignIn) { _, _ in recompute() }
            .onChange(of: showGroupsOrganizerName) { _, _ in recompute() }
            .onChange(of: showFullModeActivation) { _, _ in recompute() }
            .onChange(of: showProTrialOffer) { _, _ in recompute() }
            .onChange(of: showWhatsNew) { _, _ in recompute() }
            .onChange(of: showSyncSettingsSheet) { _, _ in recompute() }
    }

    private func alertObservers(_ content: some View) -> some View {
        content
            .onChange(of: forceUpdateRequired) { _, _ in recompute() }
            .onChange(of: showFreshStartWipeAlert) { _, _ in recompute() }
            .onChange(of: showRemoteWipeAlert) { _, _ in recompute() }
            .onChange(of: showICloudRestartAlert) { _, _ in recompute() }
            .onChange(of: showRestoreOffer) { _, _ in recompute() }
            .onChange(of: hasActiveInviteError) { _, _ in recompute() }
            .onChange(of: hasActiveGroupSyncError) { _, _ in recompute() }
            .onChange(of: activeInboxNotification) { _, _ in recompute() }
    }
}

extension View {
    func readinessGateObservers(
        forceUpdateRequired: Bool,
        showOnboarding: Bool,
        showWelcomeFlow: Bool,
        showLanguageSelection: Bool,
        showWelcomeRestore: Bool,
        showInviteRecovery: Bool,
        showWelcomeCloudSignIn: Bool,
        showSignOutRelaunch: Bool,
        secondaryEntryRelaunch: Bool,
        showFreshStartWipeAlert: Bool,
        showRemoteWipeAlert: Bool,
        showICloudRestartAlert: Bool,
        showRestoreOffer: Bool,
        hasActiveInviteError: Bool,
        hasActiveGroupSyncError: Bool,
        activeInboxNotification: PendingInboxNotification,
        showGroupInviteOnboarding: Bool,
        showGroupReconnect: Bool,
        showGroupsConsent: Bool,
        showGroupsSignIn: Bool,
        showGroupsOrganizerName: Bool,
        showFullModeActivation: Bool,
        showProTrialOffer: Bool,
        showWhatsNew: Bool,
        showSyncSettingsSheet: Bool,
        recompute: @escaping () -> Void
    ) -> some View {
        modifier(ReadinessGateObserversModifier(
            forceUpdateRequired: forceUpdateRequired,
            showOnboarding: showOnboarding,
            showWelcomeFlow: showWelcomeFlow,
            showLanguageSelection: showLanguageSelection,
            showWelcomeRestore: showWelcomeRestore,
            showInviteRecovery: showInviteRecovery,
            showWelcomeCloudSignIn: showWelcomeCloudSignIn,
            showSignOutRelaunch: showSignOutRelaunch,
            secondaryEntryRelaunch: secondaryEntryRelaunch,
            showFreshStartWipeAlert: showFreshStartWipeAlert,
            showRemoteWipeAlert: showRemoteWipeAlert,
            showICloudRestartAlert: showICloudRestartAlert,
            showRestoreOffer: showRestoreOffer,
            hasActiveInviteError: hasActiveInviteError,
            hasActiveGroupSyncError: hasActiveGroupSyncError,
            activeInboxNotification: activeInboxNotification,
            showGroupInviteOnboarding: showGroupInviteOnboarding,
            showGroupReconnect: showGroupReconnect,
            showGroupsConsent: showGroupsConsent,
            showGroupsSignIn: showGroupsSignIn,
            showGroupsOrganizerName: showGroupsOrganizerName,
            showFullModeActivation: showFullModeActivation,
            showProTrialOffer: showProTrialOffer,
            showWhatsNew: showWhatsNew,
            showSyncSettingsSheet: showSyncSettingsSheet,
            recompute: recompute
        ))
    }
}
