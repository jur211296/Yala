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
    let isLocked: Bool
    let isWipingData: Bool

    // Onboarding/welcome covers (block readiness when active)
    let showOnboarding: Bool
    let showWelcomeFlow: Bool
    let showLanguageSelection: Bool
    let showWelcomeRestore: Bool
    let showInviteRecovery: Bool

    // System alerts (block readiness — alert → would collide with subsequent intent)
    let showFreshStartWipeAlert: Bool
    let showRemoteWipeAlert: Bool
    let showICloudRestartAlert: Bool

    // Active modal payloads (block readiness while presented)
    let hasActiveInboxAlert: Bool
    let showGroupInviteOnboarding: Bool
    let showGroupReconnect: Bool
    let showFullModeActivation: Bool
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
        // Order = severity. Wipe trumps everything; lock comes before splash because
        // a locked-but-dismissed-splash app is in a worse state than a splash-loading one.
        if state.isWipingData { return "wipingData" }
        if !state.isSplashDismissed { return "splash" }
        if state.isLocked { return "biometricLock" }

        // System alerts: must clear before the next router intent presents.
        if state.showRemoteWipeAlert { return "remoteWipeAlert" }
        if state.showICloudRestartAlert { return "iCloudRestartAlert" }
        if state.showFreshStartWipeAlert { return "freshStartWipeAlert" }

        // Onboarding/welcome chain (a fullScreenCover blocks subsequent presentations).
        if state.showLanguageSelection { return "languageSelection" }
        if state.showWelcomeFlow { return "welcomeFlow" }
        if state.showWelcomeRestore { return "welcomeRestore" }
        if state.showInviteRecovery { return "inviteRecovery" }
        if state.showOnboarding { return "onboarding" }
        if state.showFullModeActivation { return "fullModeActivation" }

        // Group flows (modal sheets/covers).
        if state.showGroupInviteOnboarding { return "groupInviteOnboarding" }
        if state.showGroupReconnect { return "groupReconnect" }

        // Active inbox alert (fullScreenCover): blocks new shell presentations
        // until dismissed — root cause of the "automatizaciones" tardío bug.
        if state.hasActiveInboxAlert { return "activeInboxAlert" }

        return nil
    }
}
