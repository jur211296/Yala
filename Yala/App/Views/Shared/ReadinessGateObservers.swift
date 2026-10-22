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
    let showFreshStartWipeAlert: Bool
    let showFreshStartWipeFailedAlert: Bool
    let showLateICloudNotice: Bool
    let showRemoteWipeAlert: Bool
    let showICloudRestartAlert: Bool
    /// El aviso del cambio de Apple ID pedido y sin resolver —la condición viva, no el `isPresented` de su
    /// hoja—: bloquea el gate mientras está pendiente, así que su transición tiene que recomputar como las
    /// de sus vecinos.
    let appleIDCloseNoticePending: Bool
    /// La FASE del cierre de sesión, no un `@State`: su transición a `.working` y su salida tienen que
    /// recomputar, o el gate se queda con la foto de antes del tap.
    let isSignOutWorking: Bool
    let hasActiveInviteError: Bool
    let hasActiveGroupSyncError: Bool
    let activeInboxNotification: PendingInboxNotification
    let showGroupInviteOnboarding: Bool
    let showGroupsConsent: Bool
    let showGroupsSignIn: Bool
    /// [I] · el bloqueo «esa cuenta ya tiene Yala completo».
    let showGroupsAccountIsCompleteBlock: Bool
    let showGroupsOrganizerName: Bool
    /// C2 · el educativo de las puertas A/B. Observarlo NO es opcional: su cover es un blocker de la
    /// matriz, así que sin este `onChange` el readiness no se recomputa al montarlo ni al bajarlo y el
    /// drain retiene (o suelta) en el momento equivocado.
    let showGroupsEducational: Bool
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
    }

    private func groupObservers(_ content: some View) -> some View {
        content
            .onChange(of: showGroupInviteOnboarding) { _, _ in recompute() }
            .onChange(of: showGroupsConsent) { _, _ in recompute() }
            .onChange(of: showGroupsSignIn) { _, _ in recompute() }
            .onChange(of: showGroupsAccountIsCompleteBlock) { _, _ in recompute() }
            .onChange(of: showGroupsOrganizerName) { _, _ in recompute() }
            .onChange(of: showGroupsEducational) { _, _ in recompute() }
            .onChange(of: showFullModeActivation) { _, _ in recompute() }
            .onChange(of: showProTrialOffer) { _, _ in recompute() }
            .onChange(of: showWhatsNew) { _, _ in recompute() }
            .onChange(of: showSyncSettingsSheet) { _, _ in recompute() }
    }

    private func alertObservers(_ content: some View) -> some View {
        content
            .onChange(of: forceUpdateRequired) { _, _ in recompute() }
            .onChange(of: showFreshStartWipeAlert) { _, _ in recompute() }
            .onChange(of: showFreshStartWipeFailedAlert) { _, _ in recompute() }
            .onChange(of: showLateICloudNotice) { _, _ in recompute() }
            .onChange(of: showRemoteWipeAlert) { _, _ in recompute() }
            .onChange(of: showICloudRestartAlert) { _, _ in recompute() }
            .onChange(of: appleIDCloseNoticePending) { _, _ in recompute() }
            .onChange(of: isSignOutWorking) { _, _ in recompute() }
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
        showFreshStartWipeAlert: Bool,
        showFreshStartWipeFailedAlert: Bool,
        showLateICloudNotice: Bool,
        showRemoteWipeAlert: Bool,
        showICloudRestartAlert: Bool,
        appleIDCloseNoticePending: Bool,
        isSignOutWorking: Bool,
        hasActiveInviteError: Bool,
        hasActiveGroupSyncError: Bool,
        activeInboxNotification: PendingInboxNotification,
        showGroupInviteOnboarding: Bool,
        showGroupsConsent: Bool,
        showGroupsSignIn: Bool,
        showGroupsAccountIsCompleteBlock: Bool,
        showGroupsOrganizerName: Bool,
        showGroupsEducational: Bool,
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
            showFreshStartWipeAlert: showFreshStartWipeAlert,
            showFreshStartWipeFailedAlert: showFreshStartWipeFailedAlert,
            showLateICloudNotice: showLateICloudNotice,
            showRemoteWipeAlert: showRemoteWipeAlert,
            showICloudRestartAlert: showICloudRestartAlert,
            appleIDCloseNoticePending: appleIDCloseNoticePending,
            isSignOutWorking: isSignOutWorking,
            hasActiveInviteError: hasActiveInviteError,
            hasActiveGroupSyncError: hasActiveGroupSyncError,
            activeInboxNotification: activeInboxNotification,
            showGroupInviteOnboarding: showGroupInviteOnboarding,
            showGroupsConsent: showGroupsConsent,
            showGroupsSignIn: showGroupsSignIn,
            showGroupsAccountIsCompleteBlock: showGroupsAccountIsCompleteBlock,
            showGroupsOrganizerName: showGroupsOrganizerName,
            showGroupsEducational: showGroupsEducational,
            showFullModeActivation: showFullModeActivation,
            showProTrialOffer: showProTrialOffer,
            showWhatsNew: showWhatsNew,
            showSyncSettingsSheet: showSyncSettingsSheet,
            recompute: recompute
        ))
    }
}
