//
//  GroupCreateRoutingLogic.swift
//  Yala
//
//  Pure-logic del routing de CREAR GRUPO (G5-A, contrato C3 · **C4: la fábrica de zombis, CERRADA**).
//  Decide si el grupo nuevo nace en el canal BACKEND (RPC `create_group`), si antes hay que pedir
//  sign-in / consent, o si el canal está apagado y **no se crea nada**.
//
//  **La rama `.cloudKit` MURIÓ, y no por limpieza: fabricaba grupos irrecuperables.** Con el canal
//  apagado, `route` devolvía `.cloudKit` y `GroupService.createGroup` acuñaba un `SplitGroup` local con
//  `isBackendGroup == false`. Eso no tiene vuelta atrás, medido en este árbol: no hay ninguna llamada
//  cliente a `fetchCandidates` (cero ocurrencias en el repo), `migrate_group` no tiene endpoint en
//  `gateway/src/`, `movedToBackendAt` no tiene un escritor que lo ponga (su único autor lo copia del
//  `min` de un duplicado ⇒ punto fijo en `nil`) y `createShareLink` cae al `else` para todo
//  `isBackendGroup == false` ⇒ `Groups.Errors.inviteFailed` SIEMPRE. Un grupo de una persona, no
//  invitable, para siempre — y sin ningún error visible, porque el camino funciona OFFLINE.
//
//  **Y la ventana no es de instalaciones nuevas: el kill-switch la reabría en TODO el parque.** Con
//  `GROUPS_BACKEND_ROLLOUT_PERCENT = 0` cualquier device tiene `flagOn == false` ≤6 h después, con su
//  CTA «crear grupo» intacta. Bajar ese percent es la respuesta operativa documentada a un incidente
//  ⇒ el remedio ENCENDÍA la fábrica.
//
//  **La invariante que esta lógica NO puede sostener por sí sola:** `refreshIfDue(force: true)` va
//  ANTES de leer el flag. `route` es pura y recibe `flagOn` ya leído, así que puede ser perfecta y sus
//  tests verdes mientras el llamador mide un snapshot de hasta 6 h — que es exactamente el caso del
//  bug. Lo único que fija ese orden es un **source-scan** del call-site
//  (`GroupCreateRoutingWiringTests`, molde `GroupsOrganizerBranchTests`).
//
//  **Al bloquear, CERO escrituras**: `.channelOff` no persiste `onboardingMode`, ni
//  `groupsBetaUnlocked`, ni `hasCompletedOnboarding` — molde literal de
//  `GroupsOrganizerGateLogic.Decision.blockedChannelOff`, con cuyo copy comparte además el texto
//  («ahora mismo no podemos abrirte grupos»): describe un estado transitorio y no culpa al usuario.
//
//  ⚠️ **El escenario del canal apagado NO es ejercitable en el harness — no lo busques.**
//  `CloudRemoteFlags.decide()` cortocircuita a `absentDefault` bajo `isRunningTests || isUITestHost`
//  **sin leer el snapshot** (`CloudRemoteConfig.swift:186`), y en `Yala Dev` —el scheme de los
//  XCUITest— `absentDefault` es `true` (`:120-126`) ⇒ el flag nace ON y `.channelOff` es inalcanzable
//  desde un test de integración, en los dos targets. Es la asimetría observe/enforce de
//  `.claude/rules/gateway-attest.md` con otra ropa: la red es **estructural** (esta tabla + el
//  source-scan del orden), no un e2e.
//

import Foundation

nonisolated enum GroupCreateRoutingLogic {

    enum Route: Equatable {
        /// El canal de Grupos está apagado DESPUÉS del refresh forzado. **No se crea nada y no se
        /// escribe nada**: copy honesto y vuelta. Antes de C4 este caso era `.cloudKit` y acuñaba un
        /// grupo local irrecuperable.
        case channelOff
        /// Crear vía `GroupBackendMembershipService.createGroup` (RPC server-first).
        case backend
        /// Flag ON con sesión pero sin consent → presentar el consent de grupos ANTES del form.
        case needsConsent
        /// Flag ON sin sesión → presentar el sign-in solo-grupos ANTES del form.
        case needsSignIn
    }

    /// Precedencia (flag ON): sin sesión → sign-in; con sesión sin consent → consent; listo → backend.
    /// Flag OFF → `.channelOff` (el gate consent/sign-in no llega a preguntarse: sin canal no hay nada
    /// que crear, y pedir identidad para después bloquear sería pedirla en vano).
    ///
    /// **C2 (2026-08-12): los tres escalones de identidad DERIVAN de `GroupsGateLogic.nextStep(entry:
    /// .tab)`; el canal se queda aquí y sigue siendo el PRIMER término.** La tabla única no conoce el flag
    /// a propósito —ver su encabezado—, así que el orden canal-antes-que-identidad que C4 fijó no se puede
    /// perder al derivar: el `guard flagOn` está antes de la llamada.
    ///
    /// **El educativo tampoco entra aquí, y es una medición:** `.tab` no lo antepone porque
    /// `GroupsContainerView.evaluateGroupsOnboarding` lo presenta al MONTAR el tab —en el `onAppear`,
    /// antes de que ninguna de las cuatro CTA de creación sea alcanzable—, así que devolverlo desde aquí
    /// sería una segunda presentación compitiendo con ese sheet.
    ///
    /// - Parameter flagOn: `CloudSyncFlags.groupsBackendEnabled` **leído después** del
    ///   `refreshIfDue(force: true)` del call-site. Leerlo antes es el no-op que el bug describe.
    static func route(flagOn: Bool, hasSession: Bool, consentAccepted: Bool) -> Route {
        guard flagOn else { return .channelOff }
        switch GroupsGateLogic.nextStep(
            entry: .tab,
            // `.tab` no antepone el educativo (`showsEducationalFirst == false`) ⇒ no participa.
            hasSeenEducational: true,
            hasSession: hasSession,
            isConsented: consentAccepted,
            // El tab no da de alta a nadie: quien llega aquí ya tiene shell. El terminal de `.tab` es
            // siempre el formulario, así que este valor no cambia la decisión.
            hasCompletedSetup: true
        ) {
        case .presentSignIn:  return .needsSignIn
        case .presentConsent: return .needsConsent
        // Inalcanzables con `entry: .tab`: su único terminal es el formulario.
        case .presentGroupForm, .presentEducational, .presentName, .presentInviteOnboarding, .join:
            return .backend
        }
    }
}
