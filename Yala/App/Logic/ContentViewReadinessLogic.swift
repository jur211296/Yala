//
//  ContentViewReadinessLogic.swift
//  Yala
//
//  Pure-logic decision: should the .contentView consumer drain intents right now?
//
//  The shell hosts ~15 modals that should block intent drainage while visible
//  (otherwise SwiftUI cannot present a second fullScreenCover / sheet on top
//  and intents queue up to land later "tardío"). This helper centralizes the
//  blocker matrix so ContentView.updateContentViewReadiness has one source.
//

import Foundation

/// Snapshot of every shell-level modal/state that can block intent drainage.
/// Built by ContentView from its @State flags + SessionState before calling
/// `ContentViewReadinessLogic.isReady`.
struct ShellReadinessState: Equatable {
    let isSplashDismissed: Bool
    let isWipingData: Bool

    /// D1: pantalla de retención «Seguir con mis grupos» pendiente tras vaciar con grupos vivos.
    /// Tier alto (tras `wipingData`): mientras está pendiente, nada más presenta debajo y el
    /// ruteo automático a Welcome del `onChange(hasCompletedOnboarding)` queda gateado.
    let groupsRetentionPending: Bool

    // Onboarding/welcome covers (block readiness when active)
    let showOnboarding: Bool
    let showWelcomeFlow: Bool
    let showLanguageSelection: Bool
    let showWelcomeRestore: Bool
    let showInviteRecovery: Bool
    /// H4: cover de sign-in a cuenta nube desde el Welcome. NO está en
    /// `welcomeChainBlockers` a propósito: un adopt en vuelo no debe tumbarse
    /// por un intent superseding (los intents se RETIENEN hasta que termine).
    let showWelcomeCloudSignIn: Bool
    /// H4: cover terminal del cierre de sesión `.cloud` (wipe armado, esperando
    /// relaunch). Severidad máxima tras wipingData: nada debe presentarse debajo.
    let showSignOutRelaunch: Bool
    /// M1: VENTANA DE ENTRADA de la sesión secundaria — descriptor persistido pero este
    /// proceso montó el store del DUEÑO (relaunch pendiente). Mismo tier terminal que
    /// `signOutRelaunch`: la app JAMÁS queda usable debajo (el runtime ya está bloqueado
    /// por el guard de mount-mismatch; esto tapa la UI).
    let secondaryEntryRelaunch: Bool

    // System alerts (block readiness — alert → would collide with subsequent intent)
    let showFreshStartWipeAlert: Bool
    let showRemoteWipeAlert: Bool
    let showICloudRestartAlert: Bool
    let showRestoreOffer: Bool
    let hasActiveInviteError: Bool
    let hasActiveGroupSyncError: Bool

    // Active modal payloads (block readiness while presented)
    let hasActiveInboxAlert: Bool
    let showGroupInviteOnboarding: Bool
    let showGroupReconnect: Bool
    /// G4-invites (A2): sheets del flujo backend sign-in → consent → join. Mismo anchor
    /// que todo lo demás — mientras uno está arriba, el drain se retiene (peek-first).
    let showGroupsConsent: Bool
    let showGroupsSignIn: Bool
    let showFullModeActivation: Bool

    // Shell sheets (same anchor as everything above — a second presentation
    // while one is up gets silently discarded by SwiftUI, so they must block)
    let showProTrialOffer: Bool
    let showWhatsNew: Bool
    let showSyncSettingsSheet: Bool

    // Cross-node: sheet de MainTabView visible (downgrade/trialExpired/
    // milestone). Presentar el cover del inbox alert ENCIMA de uno y que su
    // dismiss lo tumbe es la variante cross-node del bug TestFlight.
    let isMainTabModalVisible: Bool
}

enum ContentViewReadinessLogic {

    /// `.contentView` is ready to drain when no shell-level blocker is active.
    /// Order of evaluation does NOT matter for the final boolean — but matches
    /// `blocker(state:)` priority for consistent diagnostics.
    static func isReady(state: ShellReadinessState) -> Bool {
        blocker(state: state) == nil
    }

    /// Returns the highest-priority blocker name (for debug logs / telemetry).
    /// Nil when the consumer can drain.
    static func blocker(state: ShellReadinessState) -> String? {
        // Order = severity. Wipe trumps everything.
        if state.isWipingData { return "wipingData" }
        // D1: retención pendiente tras el wipe — bloquea Welcome/router hasta que el usuario elige.
        // Tras `wipingData` (el cover solo se presenta cuando `!isWipingData`).
        if state.groupsRetentionPending { return "groupsRetention" }
        // H4: sesión cerrada + wipe de boot ARMADO — terminal, nada presenta debajo.
        if state.showSignOutRelaunch { return "signOutRelaunch" }
        // M1: entrada secundaria armada con el store del dueño aún montado — terminal.
        if state.secondaryEntryRelaunch { return "secondaryEntryRelaunch" }
        if !state.isSplashDismissed { return "splash" }

        // System alerts: must clear before the next router intent presents.
        if state.showRemoteWipeAlert { return "remoteWipeAlert" }
        if state.showICloudRestartAlert { return "iCloudRestartAlert" }
        if state.showFreshStartWipeAlert { return "freshStartWipeAlert" }
        if state.showRestoreOffer { return "restoreOffer" }
        if state.hasActiveInviteError { return "inviteError" }
        if state.hasActiveGroupSyncError { return "groupSyncError" }

        // Onboarding/welcome chain (a fullScreenCover blocks subsequent presentations).
        if state.showLanguageSelection { return "languageSelection" }
        if state.showWelcomeFlow { return "welcomeFlow" }
        if state.showWelcomeRestore { return "welcomeRestore" }
        if state.showInviteRecovery { return "inviteRecovery" }
        if state.showWelcomeCloudSignIn { return "welcomeCloudSignIn" }
        if state.showOnboarding { return "onboarding" }
        if state.showFullModeActivation { return "fullModeActivation" }

        // Group flows (modal sheets/covers).
        if state.showGroupInviteOnboarding { return "groupInviteOnboarding" }
        if state.showGroupReconnect { return "groupReconnect" }
        if state.showGroupsConsent { return "groupsConsent" }
        if state.showGroupsSignIn { return "groupsSignIn" }

        // Shell sheets: while one is presented, a drained intent that sets a
        // second sheet/cover on this same anchor gets discarded by SwiftUI
        // (and the intent is already consumed). Hold the queue instead.
        if state.showProTrialOffer { return "proTrialOffer" }
        if state.showWhatsNew { return "whatsNew" }
        if state.showSyncSettingsSheet { return "syncSettingsSheet" }
        if state.isMainTabModalVisible { return "mainTabModal" }

        // Active inbox alert (fullScreenCover): blocks new shell presentations
        // until dismissed — root cause of the "automatizaciones" tardío bug.
        if state.hasActiveInboxAlert { return "activeInboxAlert" }

        return nil
    }

    /// Blockers que forman la cadena welcome/onboarding inicial. Un intent
    /// `supersedesWelcomeChain` (group invite/reconnect) está diseñado para
    /// REEMPLAZAR estos covers, no para apilarse — por eso pueden cerrarse para
    /// dejar pasar su drain. `onboarding` NO está aquí: no es deadlock duro (se
    /// auto-resuelve al completarlo) y tiene su propio dual-path.
    static let welcomeChainBlockers: Set<String> = [
        "languageSelection", "welcomeFlow", "welcomeRestore", "inviteRecovery"
    ]

    /// `true` sii el blocker actual pertenece a la cadena welcome Y limpiar esa
    /// cadena dejaría al consumer listo. La 2ª condición es load-bearing: impide
    /// el teardown cuando hay OTRO blocker (splash, alerts, onboarding,
    /// freshStartWipeAlert) que sobreviviría — preservando la protección
    /// anti-"inbox alert tardío". Usado por `ContentView.drainContentViewIntents`
    /// para cerrar la cadena welcome cuando un intent que la supersede está
    /// pendiente (cierra el deadlock B4-04).
    static func isBlockedSolelyByWelcomeChain(state: ShellReadinessState) -> Bool {
        guard let current = blocker(state: state),
              welcomeChainBlockers.contains(current) else { return false }
        return isReady(state: state.withWelcomeChainCleared())
    }
}

extension ShellReadinessState {
    /// Copia con los 4 covers de la cadena welcome forzados a `false`. Usado por
    /// `ContentViewReadinessLogic.isBlockedSolelyByWelcomeChain` para decidir si
    /// la cadena welcome es el ÚNICO blocker antes de cerrarla por un intent
    /// superseding. Método (no campo nuevo) para no romper el init memberwise.
    func withWelcomeChainCleared() -> ShellReadinessState {
        ShellReadinessState(
            isSplashDismissed: isSplashDismissed,
            isWipingData: isWipingData,
            groupsRetentionPending: groupsRetentionPending,
            showOnboarding: showOnboarding,
            showWelcomeFlow: false,
            showLanguageSelection: false,
            showWelcomeRestore: false,
            showInviteRecovery: false,
            showWelcomeCloudSignIn: showWelcomeCloudSignIn,
            showSignOutRelaunch: showSignOutRelaunch,
            secondaryEntryRelaunch: secondaryEntryRelaunch,
            showFreshStartWipeAlert: showFreshStartWipeAlert,
            showRemoteWipeAlert: showRemoteWipeAlert,
            showICloudRestartAlert: showICloudRestartAlert,
            showRestoreOffer: showRestoreOffer,
            hasActiveInviteError: hasActiveInviteError,
            hasActiveGroupSyncError: hasActiveGroupSyncError,
            hasActiveInboxAlert: hasActiveInboxAlert,
            showGroupInviteOnboarding: showGroupInviteOnboarding,
            showGroupReconnect: showGroupReconnect,
            showGroupsConsent: showGroupsConsent,
            showGroupsSignIn: showGroupsSignIn,
            showFullModeActivation: showFullModeActivation,
            showProTrialOffer: showProTrialOffer,
            showWhatsNew: showWhatsNew,
            showSyncSettingsSheet: showSyncSettingsSheet,
            isMainTabModalVisible: isMainTabModalVisible
        )
    }
}
