//
//  SyncSignInBannerLogic.swift
//  Yala
//
//  La puerta para volver a entrar en la nube: la tarjeta «Sincronización» de «Dónde viven tus datos», con su
//  «Inicia sesión para subir N cambios» y su botón (`StorageSettingsView.syncStatusSection`). Aquí vive QUÉ decide que
//  salga y QUÉ se hace al pulsarla, en puro, para poder medirlo: el `CloudMigrationController` no se construye en tests.
//
//  Ticket `cloud-session-expiry-with-only-group-changes-has-no-sign-in-door` (2026-09-25). Hasta ese día la tarjeta solo
//  contaba los cambios PERSONALES: con la sesión caducada y solo cambios de grupos, el cierre de sesión decía «vuelve a
//  iniciar sesión» y no había dónde.
//

import Foundation

enum SyncSignInBannerLogic {

    /// Lo que pinta la tarjeta. `pendingCount == nil` es «no se pudo contar»: se ofrece firmar sin cifra.
    struct Banner: Equatable {
        let needsSignIn: Bool
        let pendingCount: Int?
    }

    /// ¿Sale el «Iniciar sesión»?
    ///
    /// **Lo pendiente son las DOS colas**: la personal (`SyncOutbox`) y la de grupos (`GroupSyncOutbox`), las dos sin
    /// `rejectedReason`. En la nube el ciclo de Grupos corre dentro del del motor personal (paso 5.6 de
    /// `CloudSyncRuntime.performCycle`), así que reanudar el motor sube las dos, y firmar es la salida para ambas.
    ///
    /// **Un recuento que falla ofrece firmar sin cifra**, el de cualquiera de las dos (molde de
    /// `an-unreadable-migration-journal-reads-as-never-started`): con el motor parado hasta firmar, firmar es inofensivo, y
    /// un fallo leído como cero pintaba «Todo sincronizado» con el motor parado.
    ///
    /// Exige el modo nube y un motor que espera a que se firme (`engineWaitsForSignIn`): es lo que dice que la sesión no
    /// sirve.
    static func decide(isCloud: Bool, engineWaitsForSignIn: Bool,
                       personalLive: Int?, groupsLive: Int?) -> Banner {
        guard isCloud, engineWaitsForSignIn else { return Banner(needsSignIn: false, pendingCount: 0) }
        guard let personalLive, let groupsLive else { return Banner(needsSignIn: true, pendingCount: nil) }
        let total = personalLive + groupsLive
        return Banner(needsSignIn: total > 0, pendingCount: total)
    }

    /// ¿El motor espera a que se vuelva a firmar? Dos estados, y el segundo es el caso PRINCIPAL del ticket:
    ///  · `.stoppedUntilSignIn`: la cadencia chocó con la sesión caducada en ESTE proceso, o el cierre de sesión la paró al
    ///    bloquear por ella (`CloudSyncRuntime.stopUntilSignIn`).
    ///  · `.idleSignedOut` SIN sesión: el SDK borró la sesión en un proceso anterior y este arrancó sin ella
    ///    (`CloudSyncRuntime.start`). Hasta la review del 2026-09-25 la tarjeta solo miraba el primero, y tras relanzar el
    ///    aviso mandaba a un «Iniciar sesión» que no estaba (lo cazaron tres lentes). Con sesión, `.idleSignedOut` es el
    ///    teardown de un cierre en curso: firmar no tiene nada que arreglar ahí.
    static func engineWaitsForSignIn(state: CloudSyncRuntime.RuntimeState?, hasSession: Bool) -> Bool {
        switch state {
        case .stoppedUntilSignIn: return true
        case .idleSignedOut: return !hasSession
        case .idle, .running, .stoppedUntilRelaunch, .none: return false
        }
    }

    /// Con qué proveedor firma la puerta. **El de la cuenta del teléfono**, que es la del faro cuando su hash es el del dueño
    /// del motor (`CloudBeacon`, lo escribe el claim de esa cuenta). `storedProvider()` a secas no basta: lo reescribe
    /// CUALQUIER firma, y una cuenta que entró por «Nuevo grupo» dejaba la puerta abriendo su proveedor —y, tras rechazarla,
    /// reponiéndolo— sin salida para la cuenta del teléfono (review del 2026-09-25). Sin ese ancla, el de siempre:
    /// `storedProvider()` y, sin él, Apple (el residual documentado del claim).
    static func provider(stored: String?, beaconProvider: String?, beaconHash: String?,
                         ownerUserID: String?) -> CloudSignInProvider {
        if let ownerUserID, let beaconHash, beaconHash == CloudBeacon.hash(ownerUserID),
           let anchored = CloudSignInProvider(rawValue: beaconProvider ?? "") {
            return anchored
        }
        return CloudSignInProvider(rawValue: stored ?? "") ?? .apple
    }

    // MARK: - Al pulsar

    /// Con la sesión que el SDK todavía guarda, la puerta prueba con un ciclo real antes de firmar.
    ///
    /// **El atajo de antes —«hay sesión y hay token ⇒ solo despierta la cadencia»— dejaba sin salida a quien más la
    /// necesitaba**: el 401 `yala_attest_invalid` con la sesión guardada. Ahí `accessToken()` devuelve el MISMO JWT que el
    /// servidor acaba de rechazar, así que el botón despertaba la cadencia, el ciclo volvía a chocar y la tarjeta volvía a
    /// salir: un botón que no entraba. El ciclo es la única prueba que pregunta al servidor.
    ///
    /// Solo `.sessionExpired` pide firmar. Sin red (`.transient`) no se puede firmar de todos modos, y un ciclo sano o en
    /// vuelo (`.completed`, `.coalesced`) es la sesión que revivió por otra entrada: basta con reanudar.
    static func needsSignIn(afterProbe outcome: SyncCadencePolicy.CadenceOutcome) -> Bool {
        outcome == .sessionExpired
    }

    /// Qué se hace tras firmar.
    enum AfterSignIn: Equatable {
        /// La misma cuenta que la del motor: se reanuda y suben las dos colas.
        case resume
        /// Entró OTRA cuenta. Se cierra esa sesión, no se reanuda nada y se avisa.
        case rejectOtherAccount
    }

    /// **La firma se ata a la cuenta del motor** (`CloudSyncRuntime.ownerUserID`, el `sub` con el que arrancó). Con Google el
    /// selector de cuentas sale siempre (`hint: nil`), y con Apple entra el Apple ID del teléfono, que pudo cambiar. Ninguna
    /// de las dos colas lleva dueño y el servidor firma con el `sub` del JWT: con otra cuenta, los cambios de una persona
    /// subirían a la cuenta de otra.
    ///
    /// **Sin dueño en memoria** —el motor arrancó sin sesión tras relanzar (`.idleSignedOut`) y nunca fijó el suyo— el ancla es
    /// el sello del claim (`CloudClaimActionStore`), el mismo que `CloudSyncRuntime.start` exige en la nube: una cuenta que
    /// nunca reclamó este teléfono no es la suya. Sin sesión tras una firma que no lanzó, se rechaza: no hay nada que
    /// reanudar.
    static func afterSignIn(ownerUserID: String?, signedInUserID: String?, signedInIsClaimed: Bool) -> AfterSignIn {
        guard let signedInUserID else { return .rejectOtherAccount }
        guard let ownerUserID else { return signedInIsClaimed ? .resume : .rejectOtherAccount }
        return signedInUserID == ownerUserID ? .resume : .rejectOtherAccount
    }
}
