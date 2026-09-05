//
//  EntryOnboardingEffects.swift
//  Yala
//
//  Qué efectos de "primera vez" corresponden a cada forma de ENTRAR en la app.
//
//  Existe porque los dos efectos del ALTA —la oferta de prueba post-onboarding y el marcador que
//  hace visible la card «Configura tu Yala»— se estaban armando también en la RE-ENTRADA: los tres
//  callsites de `completeOnboardingAsRestoreSkip` (restaurar de iCloud con datos completos, el
//  usuario que era "solo grupos", y el adopt de una cuenta del Modo Nube) son gente que YA tenía
//  cuenta, y aterrizaban en una app que les daba la bienvenida como si acabaran de descubrirla.
//
//  El criterio no es nuevo: la entrada de sesión secundaria ya lo aplicaba a mano
//  (`onSecondaryEntryFlagsMarked`, decisión del owner M1/D1 2026-08-13 — "flags SÍ, trial NO ni
//  markAsNewInstall"). Aquí se declara UNA vez para que los dos caminos lo lean del mismo sitio.
//
//  **La oferta Pro no se pierde en la re-entrada**: quien vuelve y no es Pro sigue recibiéndola por
//  el canal de los usuarios existentes (`ProUpsellService.shouldShowPeriodicBanner`, cooldown de
//  5 días y tope de 4/mes). Lo que se retira es la oferta *de alta*, que promete un estreno a quien
//  lleva meses usando la app.
//

import Foundation

/// Cómo llegó el usuario a esta pantalla de "ya está, entra en la app".
///
/// `nonisolated` porque el proyecto compila con `SWIFT_DEFAULT_ACTOR_ISOLATION=MainActor`: sin él, su
/// conformance a `Equatable` nace aislada al MainActor y compararlo desde este enum —que es
/// `nonisolated`— es warning hoy y error en el modo Swift 6.
nonisolated enum AppEntryKind: Equatable {
    /// Alta real: el onboarding de pasos terminó y esta cuenta estrena Yala.
    case freshInstall
    /// Vuelta: restaurar desde iCloud, retomar el modo "solo grupos", o adoptar una cuenta del
    /// Modo Nube desde un móvil recién instalado. Sus datos ya existen — solo están bajando.
    case reentry
}

nonisolated enum EntryOnboardingEffects {

    /// `setup.isNewInstall`, el marcador sin el cual la card «Configura tu Yala» no se muestra
    /// (`SetupChecklistManager.isExistingUser`).
    ///
    /// No basta con confiar en `SetupChecklistManager.autoDetect` para reparar el checklist en la
    /// vuelta: **auto-detecta 3 de los 7 pasos** (`firstExpense`, `firstBudget`, `scheduledPayment`
    /// — los que dejan rastro en SwiftData). Los otros cuatro son gestos sin dato que los revele, y
    /// el primero de la lista, `exploreSettings`, es además el único que el bloqueo secuencial deja
    /// desbloqueado ⇒ quien vuelve vería «3/7 · Explora los ajustes» encima de su app de años.
    static func marksNewInstall(_ kind: AppEntryKind) -> Bool {
        kind == .freshInstall
    }

    /// `needsPostOnboardingTrial`, el one-shot que presenta la oferta de prueba al terminar el alta.
    static func armsTrialOffer(_ kind: AppEntryKind, isProUser: Bool) -> Bool {
        kind == .freshInstall && !isProUser
    }
}
