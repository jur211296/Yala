//
//  GroupsAttestTabNoticeLogic.swift
//  Yala
//
//  Cuándo la pestaña Grupos enseña, fijo, lo que hasta hoy solo salía al intentar salir (ticket
//  `groups-tab-does-not-say-this-phone-cannot-sync-groups`, decisión de Jürgen del 2026-09-15, opción 1).
//
//  POR QUÉ EXISTE. El veredicto terminal (`GroupsAttestStreakStore.isTerminal`) lo leían solo los gestos que pueden
//  PERDER algo —cerrar sesión, desasociar la cuenta de grupos, salir de un grupo—, así que quien editaba gastos y
//  no hacía ninguno de los tres no se enteraba nunca de que sus cambios no llegaban al grupo.
//
//  POR QUÉ NO BASTA EL VEREDICTO, y por qué son CUATRO condiciones. La racha describe al TELÉFONO: sobrevive al
//  cierre de sesión a propósito (`GroupsAttestStreakStore`) y desde el 2026-09-15 la escribe **también el motor
//  personal**, que no sube un solo gasto de grupo. Hay tres poblaciones a las que el veredicto es cierto y la frase
//  sería MENTIRA, y cada una se excluye con su término:
//
//   - **Sin sesión en la nube.** El tab ya dice «inicia sesión para ver tus grupos»; encima de eso, «este teléfono
//     no puede sincronizar tus grupos» señala al culpable equivocado. Nada está sincronizando.
//   - **Con Grupos sin compilar en esta versión.** Entonces la racha sería entera del motor personal, y anunciar una
//     avería de Grupos donde Grupos no existe es inventarla.
//   - **Sin el consent de Grupos aceptado para la sesión viva.** El tab está enseñando «te cuento qué es un grupo» o
//     «acepta para usar Grupos»; esta persona no tiene ningún cambio de grupos esperando, porque el canal no sube
//     nada suyo. Es la misma mentira que la primera, y la cazó una lente adversarial el 2026-09-15.
//
//  EL TÉRMINO DEL CANAL ES LA CAPACIDAD COMPILADA, NO EL GETTER COMPUESTO, y esto costó el hallazgo más caro de la
//  review. `CloudSyncFlags.groupsBackendEnabled` es `compilado && remoto`, y su propio docblock separa las dos
//  clases de call-site: las ENTRADAS leen el compuesto —es lo que el kill-switch existe para cortar—, y los
//  TEARDOWNS leen `groupsBackendCompiledCapability`, porque el término remoto **es fail-closed ante un snapshot
//  ausente o corrupto** y no es testigo del corpus de este teléfono. Este aviso es de la segunda clase: describe un
//  hecho sobre datos que YA existen, no una puerta que abrir. Con el compuesto, un teléfono restaurado desde una
//  copia de iCloud —que hereda la racha y no la key de attest— se quedaba **sin aviso en su primer arranque**, sin
//  snapshot todavía, mientras el cierre de sesión sí se lo enseñaba: el bug del ticket, vivo, en la población más
//  probable.
//
//  QUÉ NO DECIDE. Cuándo se vuelve a mirar. El veredicto depende del reloj —una racha de ayer se vuelve terminal sin
//  que nadie escriba nada— y `isTerminal()` lee `UserDefaults`, que no repinta ninguna vista: por eso el store avisa
//  (`GroupsAttestStreakStore.didChangeNotification`) y la pestaña lo escucha. Las otras tres entradas sí son
//  reactivas y se leen VIVAS en el body, como sus vecinas del empty state.
//

import Foundation

nonisolated enum GroupsAttestTabNoticeLogic {

    /// ¿La pestaña Grupos enseña el aviso fijo «este teléfono no puede sincronizar tus grupos»?
    ///
    /// Las cuatro condiciones a la vez, y ninguna sobra: el veredicto dice que el teléfono no atesta, y las otras
    /// tres dicen que esta persona TIENE grupos en la nube desde este teléfono. Sin parámetros por defecto a
    /// propósito —quien lo llame se pronuncia sobre los cuatro— por el mismo motivo que `CloudSignOutFlowLogic.path`.
    ///
    /// - Parameters:
    ///   - verdictIsTerminal: `GroupsAttestStreakStore.isTerminal()`.
    ///   - channelIsCompiled: `CloudSyncFlags.groupsBackendCompiledCapability`. **No el getter compuesto**: ver la
    ///     cabecera.
    ///   - hasLiveSession: `CloudAuthService.shared.hasSession`.
    ///   - hasGroupsConsent: `GroupsConsentState.isAccepted` — aceptado Y válido para la sesión viva.
    static func showsNotice(verdictIsTerminal: Bool,
                            channelIsCompiled: Bool,
                            hasLiveSession: Bool,
                            hasGroupsConsent: Bool) -> Bool {
        verdictIsTerminal && channelIsCompiled && hasLiveSession && hasGroupsConsent
    }
}
