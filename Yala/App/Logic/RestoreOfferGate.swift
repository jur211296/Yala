//
//  RestoreOfferGate.swift
//  Yala
//
//  SSOT del "respeto al wipe": solo se ofrece restaurar datos de iCloud si el
//  último acto del usuario en este Apple ID NO fue un wipe. Pure-logic sobre los
//  timestamps del KV-store (`lastOnboardingTimestamp` / `lastWipeTimestamp`).
//
//  Usado por:
//  - WelcomeHero (detección rápida del alert) → `hasReturningSignal`.
//  - WelcomeRestoreView (estado `.wiped` vs `.found`/`.notFound`).
//  - Invitación de grupo + returning user (Parte F) → ofrecer cargar antes de unirse.
//
//  Evita el bug #6 (autopromote por KV-store contaminado): la señal solo decide
//  si OFRECER (alert/oferta), nunca dispara wipe ni completa onboarding.
//

import Foundation

enum RestoreOfferGate {

    /// ¿El último acto en este Apple ID fue completar onboarding (no un wipe)?
    /// Señal rápida (KV-store) de "returning user con datos en iCloud".
    /// - `lastOnboarding == 0` (nunca onboardeó) → false (fresh real).
    /// - `lastWipe > lastOnboarding` (wipe más reciente) → false (respeta el wipe).
    static func hasReturningSignal(lastOnboarding: Double, lastWipe: Double) -> Bool {
        lastOnboarding > 0 && (lastWipe == 0 || lastOnboarding > lastWipe)
    }

    /// ¿Ofrecer restaurar? Requiere datos presentes Y que no haya sido un wipe.
    /// `hasData` se evalúa tras la quiescencia del import (datos completos).
    static func shouldOfferRestore(hasData: Bool, lastOnboarding: Double, lastWipe: Double) -> Bool {
        hasData && hasReturningSignal(lastOnboarding: lastOnboarding, lastWipe: lastWipe)
    }

    /// ¿El último acto fue un wipe? (para mostrar el estado `.wiped` en RestoreView).
    static func wasWiped(lastOnboarding: Double, lastWipe: Double) -> Bool {
        lastWipe > 0 && lastWipe >= lastOnboarding
    }
}
