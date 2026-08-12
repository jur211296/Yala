//
//  GroupsConsentDecisionLogic.swift
//  Yala
//
//  ¿Está aceptado el consent de Grupos? Decisión PURA sobre el snapshot local sellado (C1).
//
//  Existe separada de `GroupsConsentState` por lo de siempre: la lectura la hacen cinco tablas de routing
//  SÍNCRONAS (`ContentView`, `GroupFormView`, `GroupsContainerView`, `GroupJoinReconciler`,
//  `GroupBackendInviteEntryHandler`) y una decisión con tres reglas que no se puede ejercitar sin
//  `UserDefaults` ni sesión viva acaba sin tabla de tests.
//
//  ## Las tres reglas, y por qué cada una
//
//  1. **Sin snapshot → NO aceptado.** Trivial, y es el estado de un device nuevo.
//
//  2. **Versión aceptada por debajo de la última SUSTANTIVA → NO aceptado** (§8). Es la comparación que
//     hasta C1 no existía: la versión se persistía y no la miraba nadie.
//
//  3. **Un sello que CONTRADICE al `sub` vivo → NO aceptado.** No hay ningún dominio de `UserDefaults` por
//     sesión (`PreferenceSyncService.local` es `.standard` hardcodeado), así que la caché de una VISITA
//     M1 cae en el dominio del DUEÑO. La seguridad viene del sello, **no de una purga** — que es
//     exactamente por qué `AccountEntitlementStore` es seguro. Un snapshot de la cuenta A jamás vale como
//     consent de la cuenta B.
//
//  ## La asimetría deliberada: solo un sello que contradice invalida
//
//  Sin sesión viva (`sessionUserID == nil`) el sello NO se comprueba, y no es un descuido:
//
//   · **No abre ninguna puerta.** Las tres tablas de routing evalúan la SESIÓN antes que el consent
//     (`GroupCreateRoutingLogic`, `GroupsOrganizerFlowLogic`, `GroupBackendInviteEntryLogic`), así que sin
//     sesión el valor de este booleano no cambia ni una decisión.
//   · **Invalidar ahí sería peor**: haría que cerrar sesión OLVIDARA un consent que sigue siendo válido, y
//     el olvido del consent en un cierre es justo la mina que documenta la §prefs de
//     `.claude/rules/swiftdata-cloudkit.md` (un sign-out es «hasta luego», no una retirada de
//     consentimiento).
//
//  Y un snapshot SIN sello (`userID == nil`) también vale: es la forma que tiene el consent adoptado del
//  build anterior —que se escribía sin identidad ninguna— y la del seam `-uitest-groups-consent`. En
//  cuanto haya sesión, `GroupsConsentState.adoptLegacyIfNeeded` lo RE-SELLA con el `sub` vivo.
//

import Foundation

nonisolated enum GroupsConsentDecisionLogic {

    /// `true` si este device puede dar el consent por prestado para la sesión indicada.
    ///
    /// - Parameters:
    ///   - snapshot: la caché local sellada, o `nil` si no hay ninguna.
    ///   - sessionUserID: el `sub` de la sesión de nube VIVA (`nil` = sin sesión).
    ///   - requiresReacceptanceFrom: `GroupsConsentText.requiresReacceptanceFrom` (inyectado para poder
    ///     ejercitar §8 sin tocar la constante de producción).
    static func isAccepted(
        snapshot: GroupsConsentSnapshot?,
        sessionUserID: String?,
        requiresReacceptanceFrom: Int = GroupsConsentText.requiresReacceptanceFrom
    ) -> Bool {
        guard let snapshot else { return false }
        guard snapshot.textVersion >= requiresReacceptanceFrom else { return false }
        if let sealed = snapshot.userID, let live = sessionUserID, sealed != live { return false }
        return true
    }

    /// ¿Hay que registrar este consent contra la cuenta? `true` cuando el snapshot local es de ESTA sesión
    /// (o aún no tiene sello) y el servidor no consta que tenga esa versión o una posterior.
    ///
    /// Se usa en la adopción del consent LEGACY —el del parque que aceptó cuando las dos `PrefSyncKey`
    /// acababan en el iKV del Apple ID y no llegaban a Yala—: es lo que convierte C1 de «mover un registro»
    /// a «crearlo» para el grueso de los usuarios.
    static func needsServerRegistration(
        local: GroupsConsentSnapshot?,
        serverTextVersion: Int?,
        sessionUserID: String?
    ) -> Bool {
        guard let local else { return false }
        // Sin sesión no hay cuenta contra la que registrar; y con un sello ajeno, registrarlo sería
        // atribuirle a esta cuenta la aceptación de otra persona.
        guard let live = sessionUserID else { return false }
        if let sealed = local.userID, sealed != live { return false }
        guard let serverTextVersion else { return true }
        return local.textVersion > serverTextVersion
    }
}
