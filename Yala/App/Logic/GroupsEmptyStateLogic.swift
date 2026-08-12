//
//  GroupsEmptyStateLogic.swift
//  Yala
//
//  Pure-logic del empty state del tab Grupos (hallazgo device-QA H-2026-07-18-7, ampliado en C2). Decide
//  QUÉ le falta al usuario para tener grupos, y lo dice. Sin SwiftData/CloudKit/UI — tabla completa en
//  GroupsEmptyStateLogicTests.
//
//  Flag OFF ⇒ SIEMPRE `.standard` (el shipping DARK queda byte-idéntico: la lógica no cambia el render).
//
//  ## Lo que C2 arregla, y por qué eran dos mentiras y no una
//
//  Con dos casos, todo el que no tenía sesión veía **«Tus grupos están en tu cuenta · Inicia sesión»**.
//  Para quien cerró su sesión de grupos eso es verdad. Para quien **nunca tuvo cuenta** —el caso dominante
//  en un fresh install— es falso dos veces: no hay ningunos grupos suyos esperando en ninguna cuenta, y no
//  hay sesión que «iniciar» porque la cuenta hay que **crearla**. Y faltaba un tercer estado real: sesión
//  viva SIN consent, donde el usuario ve un empty state que le ofrece crear un grupo y el tap lo manda a
//  una pantalla de consentimiento que no esperaba.
//
//  ## `hadSessionEver` NO es `GroupsSignOutBannerMarker` — se midió antes de usarlo
//
//  El §4 del spec proponía reusar ese marcador y pedía medirlo. **No sirve: es one-shot.** Se arma solo en
//  `CloudSessionSignOut.finalizeGroupsOnlyClose`, se QUEMA en el `onAppear` del banner y se DESARMA al
//  re-firmar (`GroupsSignOutBannerMarker.swift:24-37`) ⇒ en cuanto el banner se muestra una vez, quien SÍ
//  tuvo cuenta volvería a ver «crea una cuenta». Tampoco cubre el cierre de sesión de nube completo, que
//  no pasa por ahí. La señal correcta es un latch monotónico propio: `GroupsSessionHistoryMarker`.
//
//  Fuera de v1 (documentado): el caso "sin sesión + grupos CloudKit todavía visibles en la lista" NO aplica
//  aquí — el empty state solo se pinta con la lista VACÍA, así que un usuario con grupos CloudKit visibles
//  nunca lo ve. Decisión v1: no distinguir origen del grupo en la lista vacía.
//

import Foundation

nonisolated enum GroupsEmptyStateLogic {

    enum Kind: Equatable, CaseIterable {
        /// Empty state vigente ("aún no tienes grupos", CTA crear). Flag OFF SIEMPRE cae aquí, y también
        /// el estado COMPLETO (educativo visto + sesión + consent): ahí no falta nada, solo el grupo.
        case standard
        /// C2 · nunca vio el educativo. Antes de pedirle identidad se le cuenta qué es un grupo — es el
        /// mismo primer escalón que `GroupsGateLogic` antepone en las puertas A y B.
        case needsEducational
        /// Flag ON, sin sesión, pero SÍ tuvo cuenta alguna vez → "tus grupos están en tu cuenta", CTA
        /// iniciar sesión. Es el caso original H-2026-07-18-7, ahora acotado a quien es verdad.
        case signInToView
        /// C2 · flag ON, sin sesión y **nunca tuvo cuenta**. No hay grupos suyos esperando en ningún sitio:
        /// el copy habla de CREAR la cuenta, no de volver a una.
        case createAccount
        /// C2 · sesión viva sin consent. El tap de "crear grupo" acabaría en `GroupsConsentView`; decirlo
        /// antes evita que la pantalla de consentimiento aparezca como una sorpresa.
        case needsConsent
    }

    /// Precedencia: canal → educativo → identidad (crear cuenta vs. volver) → consent → estándar.
    ///
    /// El ORDEN espeja el de `GroupsGateLogic.nextStep` a propósito: lo que el empty state ANUNCIA tiene
    /// que ser lo que el tap va a PEDIR. Si divergen, el usuario lee una cosa y se encuentra otra.
    ///
    /// - Parameters:
    ///   - flagOn: `CloudSyncFlags.groupsBackendEnabled`. OFF → `.standard` (byte-idéntico).
    ///   - hasSeenEducational: `GroupsOnboardingLogic.hasSeenAnyGroupsEducational` — la MISMA señal que usa
    ///     la puerta, no una segunda fuente.
    ///   - hadSessionEver: `GroupsSessionHistoryMarker.hadSessionEver()`. Latch monotónico per-device.
    ///   - hasSession: `CloudAuthService.shared.hasSession`.
    ///   - isConsented: `GroupsConsentState.isAccepted`.
    static func decide(
        flagOn: Bool,
        hasSeenEducational: Bool,
        hadSessionEver: Bool,
        hasSession: Bool,
        isConsented: Bool
    ) -> Kind {
        guard flagOn else { return .standard }
        if !hasSeenEducational { return .needsEducational }
        if !hasSession { return hadSessionEver ? .signInToView : .createAccount }
        if !isConsented { return .needsConsent }
        return .standard
    }
}
