//
//  CrossAccountEntryGuardLogic.swift
//  Yala
//
//  Pure-logic del guard cross-cuenta en el sign-in de nube desde el Welcome
//  (decisión owner 2026-07-12, degradación F0-C autorizada; M1 2026-07-13 añade
//  la tercera salida).
//
//  Un Apple ID DISTINTO al dueño del corpus local JAMÁS debe adoptar sobre esos
//  datos: el orphan-reconcile del adopt corre ANTES del relaunch y pushearía las
//  filas del dueño a la cuenta entrante (mezcla cross-cuenta — la clase de
//  incidente que `runtimeBlockedByUnclaimedIdentity` existe para impedir).
//
//  M1 (diseño MODO-NUBE-M1-DISENO-MULTICUENTA): con el feature ENCENDIDO, ese
//  camino ya no bloquea — enruta a la SESIÓN SECUNDARIA (store propio por archivo,
//  el corpus del dueño ni se lee; el adopt corre post-relaunch sobre store vacío).
//  Con el flag apagado (DARK), la tabla es EXACTAMENTE la de v1.
//
//  La MISMA cuenta re-entra libre: su claim persistido (CloudClaimActionStore,
//  keyed por userID, sobrevive el sign-out a propósito) es la prueba de que el
//  corpus local le pertenece.
//

import Foundation

nonisolated enum CrossAccountEntryGuardLogic {

    enum Decision: Equatable {
        /// Device limpio o misma cuenta → continuar al adopt.
        case proceed
        /// Datos locales de otra identidad, sin salida secundaria → BLOQUEADO. El caller
        /// debe hacer `signOut()` antes de volver al chooser (no dejar sesión SIWA colgada).
        case blockedForeignData
        /// M1: datos locales ajenos + cuenta EXISTENTE + feature encendido → sesión
        /// secundaria (confirmación explícita → descriptor + claim → relaunch; JAMÁS
        /// adopt pre-relaunch sobre el store del dueño).
        case proceedSecondarySession
    }

    /// - Parameters:
    ///   - hasLocalData: hay corpus personal en el device (transacciones/cuentas).
    ///   - sameAccountClaimExists: el claim-store tiene registro para el userID que
    ///     acaba de firmar (⇒ este corpus ya fue reclamado por ESTA cuenta).
    ///   - accountExists: `GET /account/exists == true` (la secundaria v1 solo soporta
    ///     `returningUser` — born-cloud de invitado diferido a v1.1, decisión 6).
    ///   - secondarySessionEnabled: `CloudSyncFlags.secondarySessionEntryAvailable`.
    ///   - restoreInProgress: ESTA sesión pidió restaurar de iCloud y ese import no ha terminado
    ///     (`ICloudRestoreSessionSignal.isRestoringNow`). **SIN valor por defecto a propósito**: un
    ///     default sería `false` y cualquier call-site nuevo heredaría el bug en silencio, que es la
    ///     familia del `attestProvider: { nil }` de `.claude/rules/gateway-attest.md`. Sin él, añadir
    ///     una puerta obliga a decidir, y lo comprueba el compilador y no un escáner.
    static func decide(
        hasLocalData: Bool,
        sameAccountClaimExists: Bool,
        accountExists: Bool,
        secondarySessionEnabled: Bool,
        restoreInProgress: Bool
    ) -> Decision {
        // Las filas que el propio dueño está bajando de SU iCloud ahora mismo no son «corpus
        // preexistente»: son el resultado, a medias, de lo que él acaba de pedir. Sin este término el
        // guard las clasifica como ajenas —el claim que las reclamaría vive en `UserDefaults` y muere
        // con la reinstalación, que es la mitad del escenario— y le bloquea la entrada a su cuenta.
        //
        // Va DELANTE del `guard hasLocalData` y no como una cuarta rama a propósito: lo que la señal
        // corrige es el TÉRMINO de los datos, no el veredicto. Todo lo demás del guard sigue mandando.
        guard hasLocalData, !restoreInProgress else { return .proceed }
        if sameAccountClaimExists { return .proceed }
        if accountExists && secondarySessionEnabled { return .proceedSecondarySession }
        return .blockedForeignData
    }
}
