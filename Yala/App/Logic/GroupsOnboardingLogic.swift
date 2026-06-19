//
//  GroupsOnboardingLogic.swift
//  Yala
//
//  Pure decision logic para el onboarding informativo del tab Grupos. Decide si
//  presentar el sheet en función del estado del user (flag persistida, modo de
//  onboarding global y deeplinks pendientes).
//
//  Extraído como pure-logic para tests sin SwiftData ni UI (sin flake R8 conocido
//  por `makeTestContext()`).
//
//  Patrón análogo a `YalaAIOnboardingLogic`.
//

import Foundation

enum GroupsOnboardingLogic {

    /// Decide si presentar el onboarding del tab Grupos. AND-gating: cualquier
    /// blocker presente bloquea (no OR — el orden de evaluación es irrelevante).
    ///
    /// - Parameters:
    ///   - hasShownOnboarding: `AppPreferences.hasShownGroupsOnboarding`. Una vez
    ///     `true`, el onboarding no se muestra más (persistencia per-device).
    ///   - onboardingMode: `SessionState.onboardingMode`. En `.groupInvite` el user
    ///     ya pasó por `GroupInviteOnboardingView` contextual al link — no duplicar.
    ///   - hasPendingGroupDeeplink: `sessionState.pendingGroupID != nil`. Si hay
    ///     deeplink hacia un grupo específico, abrir el detail tiene prioridad UX
    ///     sobre el onboarding informativo.
    static func shouldShow(
        hasShownOnboarding: Bool,
        onboardingMode: OnboardingMode,
        hasPendingGroupDeeplink: Bool
    ) -> Bool {
        if hasShownOnboarding { return false }
        if onboardingMode == .groupInvite { return false }
        if hasPendingGroupDeeplink { return false }
        return true
    }
}

/// Origen del trigger del onboarding — telemetría para distinguir entry points si
/// se añaden futuros launchers (deeplink directo, App Intent, widget, etc.).
enum GroupsOnboardingLauncher: String {
    case groupsTab
}

/// Resultado del onboarding cuando el sheet se cierra. Cada caso define efectos
/// distintos sobre la flag `hasShownGroupsOnboarding` y telemetría.
enum GroupsOnboardingResult: Equatable {
    /// CTA Step 3 "Ir a Grupos": persistir flag + ejecutar seed lazy.
    case complete
    /// "X" topLeft (cualquier step): NO persistir flag (volverá a aparecer).
    case close
}
