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

    /// ¿El último step del educativo ofrece el CTA de iniciar sesión? (A1 de D-A7, decisión
    /// P1(b) del owner: CTA al cierre ADEMÁS del contextual que ya existe).
    ///
    /// Va en lógica pura y NO como un `if` dentro del `body`: un predicado enterrado en un
    /// `@ViewBuilder` es invisible para los unitarios y se puede borrar con la suite entera en
    /// verde (lección de `965a4d86`, molde exacto de `OnboardingGroupsPurposeGateLogic`). El
    /// CABLEADO —que la vista pase los valores REALES y no literales— lo pinnea el source-scan
    /// de `GroupsOnboardingSignInCTAWiringTests`.
    ///
    /// - Parameters:
    ///   - isLastStep: solo el step de cierre ofrece el CTA; los intermedios siguen con
    ///     "Continuar".
    ///   - flagOn: `CloudSyncFlags.groupsBackendEnabled`. Con el canal APAGADO Grupos sigue
    ///     viviendo en CloudKit y no hay sesión Yala que pedir ⇒ el recorrido queda
    ///     byte-idéntico al de siempre. Es la MISMA señal que gatea el empty state
    ///     (`GroupsEmptyStateLogic.decide`), no una segunda fuente.
    ///   - hasSession: `CloudAuthService.shared.hasSession`, la misma que lee el caller de
    ///     `GroupsEmptyStateLogic.decide` en `GroupsContainerView`. Con sesión viva el CTA
    ///     sería un prompt sin sentido.
    static func shouldShowSignInCTA(
        isLastStep: Bool,
        flagOn: Bool,
        hasSession: Bool
    ) -> Bool {
        isLastStep && flagOn && !hasSession
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
    /// CTA Step 3 "Iniciar sesión" (A1, solo sin sesión): mismos efectos que `.complete`
    /// —el usuario TERMINÓ el educativo— más el sign-in de Grupos. El intent se emite con el
    /// sheet YA desmontado (`onDismiss`): emitirlo con el sheet puesto lo dejaría RETENIDO por
    /// peek-first, igual que documenta `GroupsContainerView.requestCreateGroup`.
    case completeAndSignIn
    /// "X" topLeft (cualquier step): NO persistir flag (volverá a aparecer).
    case close
}
