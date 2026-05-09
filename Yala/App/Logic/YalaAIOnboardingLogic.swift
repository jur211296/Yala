//
//  YalaAIOnboardingLogic.swift
//  Yala
//
//  Pure decision logic para los 3 launchers del chat de Yala AI (PanelView,
//  RecordsStandaloneView, DetailContainerView). Single source of truth que
//  decide qué pantalla presentar a continuación según el estado actual:
//  consent alert → onboarding sheet → chat sheet.
//
//  Extraído como pure-logic para evitar drift entre los 3 callsites y habilitar
//  tests sin SwiftData ni UI (sin flake R8 conocido por `makeTestContext()`).
//
//  Si en el futuro se añade un 4º launcher (deeplink / App Intent / widget),
//  basta invocar este helper sin replicar la lógica condicional.
//

import Foundation

enum YalaAIOnboardingLogic {

    /// Pantalla a presentar tras tap del FAB del chat.
    enum NextScreen: Equatable {
        /// User aún no aceptó los términos de procesamiento de datos por IA.
        /// El launcher debe mostrar `chatConsentAlert` (su callback decide el siguiente paso).
        case consent
        /// Consent aceptado pero el user aún no vio el onboarding del chat.
        /// El launcher debe presentar el sheet del `YalaAIOnboardingView`.
        case onboarding
        /// Consent aceptado y onboarding ya visto. El launcher abre directamente el `ChatSheetView`.
        case chat
    }

    /// Decide qué pantalla presentar en función del estado actual del user.
    ///
    /// - Parameters:
    ///   - consentAccepted: `AppPreferences.aiChatConsentAccepted`
    ///   - onboardingShown: `AppPreferences.hasShownYalaAIOnboarding`
    static func nextScreen(
        consentAccepted: Bool,
        onboardingShown: Bool
    ) -> NextScreen {
        if !consentAccepted { return .consent }
        if !onboardingShown { return .onboarding }
        return .chat
    }
}

/// Origen del FAB del chat — usado por telemetría para distinguir launchers.
/// Tipado para evitar typos silenciosos en raw strings dispersos.
enum YalaAIOnboardingLauncher: String {
    case panel
    case records
    case stats
}

/// Resultado del onboarding cuando el sheet se cierra. Cada caso define
/// efectos distintos sobre la flag `hasShownYalaAIOnboarding` y la apertura del chat.
enum YalaAIOnboardingResult: Equatable {
    /// CTA "Empezar a chatear" (Step 4): persistir flag + abrir chat tras dismiss.
    case complete
    /// Tap "Saltar" topRight (steps 1-3): persistir flag, no abrir chat.
    case skip
    /// Tap "X" topLeft (cualquier step): NO persistir flag (volverá a aparecer).
    case close
}
