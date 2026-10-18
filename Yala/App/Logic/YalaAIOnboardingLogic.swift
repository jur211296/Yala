//
//  YalaAIOnboardingLogic.swift
//  Yala
//
//  Pure decision logic para los 3 launchers del chat de Yala AI (PanelView,
//  RecordsStandaloneView, DetailContainerView). Single source of truth que
//  decide qué pantalla presentar a continuación según el estado actual:
//  presentación (con el permiso en su último paso) → chat.
//
//  UX 2.2 · L14-2 (variante 2, Jürgen 2026-10-15): el permiso de datos ya no sale ANTES de saber qué es Yala IA, en
//  una alerta de nueve líneas. Es el último paso de la presentación («Antes de empezar»), y aceptarlo ahí persiste el
//  consentimiento y la presentación a la vez. La alerta queda solo para quien ya vio la presentación y retiró el
//  permiso después en Privacidad y datos IA: volver a enseñarle cuatro pasos para pedirle una cosa sería un paso de más.
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
        /// El usuario ya vio la presentación pero retiró el permiso de datos (Privacidad y datos IA).
        /// El launcher debe mostrar `chatConsentAlert` (su callback decide el siguiente paso).
        case consent
        /// Aún no vio la presentación. El launcher presenta el sheet del `YalaAIOnboardingView`, que pide el permiso
        /// en su último paso: aplica tenga o no el permiso ya aceptado de antes.
        case onboarding
        /// Permiso aceptado y presentación vista. El launcher abre directamente el `ChatSheetView`.
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
        if !onboardingShown { return .onboarding }
        if !consentAccepted { return .consent }
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
    /// CTA final «Aceptar y empezar» (paso «Antes de empezar»): la vista ya guardó el permiso; el launcher persiste la
    /// presentación y abre el chat tras el dismiss.
    case complete
    /// Tap "X" topLeft (cualquier step): NO persistir flag (volverá a aparecer).
    case close
}
