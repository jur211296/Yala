//
//  WhatsNewLaunchLogic.swift
//  Yala
//
//  Cuándo sale la hoja de Novedades: SOLO al actualizar (decisión de Jürgen, 16-oct-2026).
//
//  Dos reglas, y las dos se leen de `lastSeenAppVersion` (por dispositivo, no se sincroniza):
//
//  1. **Un dispositivo que arranca sin el onboarding hecho estrena Yala en ESTA versión.** Su versión
//     se da por vista en ese mismo arranque, antes de enseñar nada. Así una instalación nueva no ve
//     Novedades al terminar el onboarding ni en el arranque siguiente. El criterio es el onboarding
//     y no «`lastSeenAppVersion` vacío»: quien usó la 2.0 y nunca llegó a ver su hoja (cerró la app
//     tras el alta, o la oferta de prueba se llevó el turno) también lo tiene vacío, y ése SÍ
//     actualiza y tiene que verla.
//  2. **Se compara major.minor, no la versión entera.** Un hotfix (2.1.1 sobre 2.1) no trae
//     novedades nuevas: la entrada de `WhatsNewConfig` es la misma, y comparando la versión entera
//     la hoja volvía a salir en cada hotfix.
//

import Foundation

nonisolated enum WhatsNewLaunchLogic {

    /// La versión que este arranque debe dar por vista ANTES de decidir nada, o `nil` si no toca.
    /// Toca cuando el dispositivo aún no completó el onboarding: va a estrenar Yala en esta versión.
    static func versionToMarkSeenAtLaunch(hasCompletedOnboarding: Bool, currentVersion: String) -> String? {
        guard !hasCompletedOnboarding, !currentVersion.isEmpty else { return nil }
        return currentVersion
    }

    /// Si la versión actual trae novedades que este dispositivo no ha visto todavía.
    /// `hasFeatures` es si `WhatsNewConfig` tiene entrada para la versión actual.
    static func shouldPresent(currentVersion: String, lastSeenVersion: String, hasFeatures: Bool) -> Bool {
        guard hasFeatures, !currentVersion.isEmpty else { return false }
        return majorMinor(currentVersion) != majorMinor(lastSeenVersion)
    }

    /// Qué hoja enseña el arranque de quien vuelve, cuando las dos están pendientes. Una por arranque, como antes.
    enum ReturningUserSheet: Equatable { case whatsNew, trialOffer, none }

    /// **Novedades va ANTES que la oferta de prueba pendiente** (2026-10-19, ticket
    /// `whats-new-yields-to-a-pending-trial-offer-after-updating`). Hasta ese día era al revés (`if trial … else if
    /// novedades`), y quien actualizaba desde la 2.0.4 con la oferta pendiente no veía Novedades en el primer arranque sino
    /// en el segundo. La 2.0.4 deja la oferta pendiente sin consumirla cuando el alta fue «Restaurar» con destino directo a la
    /// app (`completeOnboardingAsRestoreSkip` pone `needsPostOnboardingTrial` y no pasa por el `onChange(showOnboarding)`
    /// que la consumía): es el iPhone del QA guiado del 19-oct, cuyo onboarding privado traía datos de iCloud.
    ///
    /// La oferta no se pierde: su marca solo se borra al PRESENTARSE (el drain), así que el arranque siguiente vuelve a
    /// pedirla con `TrialOfferMoments.note(.launch)` — y desde la 2.2 solo sale si su momento ya llegó (UX 2.2 · L1-12);
    /// sin momento, espera al primer registro. Y Novedades no vuelve, porque su versión se da por vista al cerrar la hoja.
    ///
    /// `hasPrivateSession` es la condición de siempre: quien entró solo por Grupos no ve ninguna de las dos.
    static func returningUserSheet(hasPrivateSession: Bool, whatsNewPending: Bool,
                                   trialOfferPending: Bool, isPro: Bool) -> ReturningUserSheet {
        guard hasPrivateSession else { return .none }
        if whatsNewPending { return .whatsNew }
        if trialOfferPending && !isPro { return .trialOffer }
        return .none
    }

    /// "2.1.1" → "2.1". Una versión sin punto se devuelve tal cual; la vacía sigue vacía.
    static func majorMinor(_ version: String) -> String {
        let parts = version.split(separator: ".")
        guard parts.count >= 2 else { return version }
        return "\(parts[0]).\(parts[1])"
    }
}
