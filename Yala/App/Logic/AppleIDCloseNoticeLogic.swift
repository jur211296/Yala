//
//  AppleIDCloseNoticeLogic.swift
//  Yala
//
//  La decisión PURA de la hoja «Cambiaste de cuenta de iCloud»: qué ve la persona en cada momento, qué
//  hace cada botón y cuándo se suelta la condición viva que retiene el router.
//
//  POR QUÉ EXISTE (ticket `apple-id-close-blocked-has-no-visible-outcome`). Hasta el 2026-09-15 este aviso
//  era un `.alert` cuyo botón lanzaba el cierre de sesión y se cerraba. Si el coordinador terminaba en
//  `.blocked` —la celda D sin red o con el canal de Grupos en pausa, o cambios de grupos de una sesión
//  caducada, que también alcanza a la C—, nadie lo enseñaba: los tres sitios que pintan ese bloqueo son
//  Ajustes, la puerta del invitado y la sección de asociación, y ninguno suele estar montado cuando el aviso
//  sale sobre el Panel. Y la fase pegada en `.blocked` tapiaba al coordinador el resto del lanzamiento:
//  `signOut`, el desasociar y la puerta del invitado empiezan con `guard phase == .idle`.
//
//  La salida barata —encender un segundo `.alert` desde el botón del primero— es el molde de brick de
//  `.claude/rules/swiftui-ds.md`. La rule prescribe UNA presentación con fases dentro, y lo que esas fases
//  enseñan y hacen se decide aquí.
//
//  QUÉ NO DECIDE. La fase del cierre no se duplica: la manda `CloudSessionSignOut.phase` y la hoja la LEE.
//  Lo único propio es `AppleIDCloseNotice`, que dice si la persona ya pidió cerrar y si ese cierre sigue en
//  vuelo. Ninguna fase del coordinador guarda esos dos hechos, y tienen que sobrevivir a la vista.
//

import Foundation

/// **El aviso del cambio de Apple ID, pedido y sin resolver.** Vive en `ContentView` (`nil` = no hay nada
/// pendiente) y es la CONDICIÓN VIVA que entra en la matriz de readiness.
///
/// **No vive en la vista, y es a propósito.** Si UIKit tumba la hoja y la red la vuelve a presentar, una
/// vista nueva con estado propio volvería a preguntar con el cierre ya corriendo.
enum AppleIDCloseNotice: Equatable {
    /// Presentado y sin contestar.
    case asking
    /// La persona confirmó y el cierre está EN VUELO: desde el tap hasta que `signOut` vuelve.
    case closing
    /// **El cierre de este aviso corrió y volvió sin armar el borrado**: paró en un bloqueo. Lo que se ve lo
    /// dice la fase: el bloqueo con su motivo, o «un momento más» si otra pantalla ya lo reconoció.
    ///
    /// Va aparte de `.closing` por un bug de la review adversarial del 2026-09-15: con un solo estado,
    /// `.closing` + `.idle` se pintaba como progreso, y si Ajustes —montado debajo— reconocía el bloqueo, la
    /// hoja se quedaba en un spinner sin botones y reteniendo el router hasta matar la app.
    case stopped
    /// Se pidió cerrar y el cierre no arrancó: el coordinador estaba ocupado con otro gesto, o `signOut`
    /// volvió por uno de sus `return` mudos sin tocar la fase.
    case couldNotStart
}

enum AppleIDCloseNoticeLogic {

    /// Lo que enseña la hoja.
    enum Stage: Equatable {
        /// La pregunta: el aviso con sus dos salidas.
        case asking
        /// El cierre corre, o ya armó el borrado y la hoja está cediendo el anchor al cover del
        /// relanzamiento. Sin botones: un cierre a medias no admite abandono.
        case working
        /// El cierre paró. El motivo decide el texto; las salidas son «Reintentar» y «Ahora no».
        case blocked(CloudSignOutFlowLogic.BlockReason)
        /// No hay cierre en vuelo ni bloqueo que enseñar: no arrancó, u otra pantalla reconoció su bloqueo.
        /// Mismo texto que el bloqueo pasajero, «un momento más», y las mismas dos salidas.
        case busy
        /// **El cierre paró porque este teléfono lleva más de un día sin App Attest, y puede seguir perdiendo los
        /// cambios de grupos** (2026-09-15). El aviso cuenta `pending` y ofrece «Cerrar sesión y perderlos» junto a
        /// «Ahora no». Solo lo da `stage(notice:phase:offersGroupsLossExit:)`, con la salida de ESTE cierre viva.
        case losingGroupChanges(pending: Int)
    }

    /// La etapa con la salida que pierde los cambios de grupos (ticket
    /// `groups-phone-that-never-attests-is-told-to-retry-forever`).
    ///
    /// **La salida viaja DENTRO de la etapa porque la hoja la congela.** Con «Ahora no» el coordinador reconoce el
    /// bloqueo y deja de ofrecer la salida en el mismo gesto; si la vista la leyera aparte, la animación de salida
    /// pintaría el bloqueo sin salida justo encima de lo que la persona eligió (el bug que ya obligó a congelar la etapa).
    ///
    /// Solo cambia `.blocked(.attestUnavailable)` con la salida ofrecida; el resto es la tabla de siempre.
    static func stage(notice: AppleIDCloseNotice, phase: CloudSessionSignOut.Phase,
                      offersGroupsLossExit: Bool) -> Stage {
        let base = stage(notice: notice, phase: phase)
        guard base == .blocked(.attestUnavailable), offersGroupsLossExit,
              case .blocked(let pending, _) = phase else { return base }
        return .losingGroupChanges(pending: pending)
    }

    static func stage(notice: AppleIDCloseNotice, phase: CloudSessionSignOut.Phase) -> Stage {
        switch notice {
        case .asking:
            return .asking
        case .couldNotStart:
            return .busy
        case .closing:
            switch phase {
            // En vuelo, `.idle` es la vuelta que va del tap al primer turno del `Task`: el progreso es cierto.
            case .idle, .working, .awaitingRelaunch:
                return .working
            case .blocked(_, let reason):
                return .blocked(reason)
            }
        case .stopped:
            switch phase {
            case .blocked(_, let reason):
                return .blocked(reason)
            // El borrado ya está armado: la hoja cede el anchor al cover terminal.
            case .awaitingRelaunch:
                return .working
            // **Ni cierre en vuelo ni bloqueo que enseñar.** Un progreso aquí no avanzaría nunca.
            case .idle, .working:
                return .busy
            }
        }
    }

    /// Qué hace «Cerrar sesión y quitarlos», y «Reintentar», que es el mismo gesto otra vez.
    enum CloseRequest: Equatable {
        /// La celda ya no es una de las dos que este aviso describe, o el borrado ya está armado: no
        /// queda nada que cerrar y la hoja se retira.
        case release
        /// Arrancar el cierre. `acknowledgingBlockedFirst`: el coordinador está parado en un bloqueo y hay
        /// que devolverlo a `.idle` antes, o `signOut` volvería por su `guard phase == .idle` sin hacer nada.
        case start(acknowledgingBlockedFirst: Bool)
        /// Otro gesto tiene al coordinador trabajando: no se arranca nada.
        case couldNotStart
    }

    /// - Parameter cell: la celda resuelta EN EL TAP, con los mismos getters que el coordinador.
    ///
    /// **Un bloqueo AJENO también se reconoce, y es deliberado.** Si Ajustes dejó al coordinador en
    /// `.blocked` y nadie lo vio, la persona que ahora confirma está pidiendo lo mismo: cerrar la sesión de
    /// este teléfono. Su confirmación es la más nueva y manda. Sin reconocerlo, el botón no haría nada, que
    /// es justo el bug del ticket.
    static func closeRequest(cell: CloudSignOutFlowLogic.Path, phase: CloudSessionSignOut.Phase) -> CloseRequest {
        guard cell == .privateSignOut || cell == .privateWithGroupsSignOut else { return .release }
        switch phase {
        case .idle: return .start(acknowledgingBlockedFirst: false)
        case .blocked: return .start(acknowledgingBlockedFirst: true)
        case .working: return .couldNotStart
        case .awaitingRelaunch: return .release
        }
    }

    /// Qué queda del aviso cuando `signOut` vuelve.
    ///
    /// `signOut` solo vuelve cuando su camino termina, y los caminos C y D terminan en `.blocked` o en
    /// `.awaitingRelaunch`: el cierre corrió (`.stopped`). Volver con `.idle` es uno de sus `return` mudos
    /// (celda distinta de la confirmada), y volver con `.working`, que la fase era de otro gesto y su `guard`
    /// cortó: el cierre no llegó a arrancar (`.couldNotStart`).
    static func noticeAfterClose(phaseAfter phase: CloudSessionSignOut.Phase) -> AppleIDCloseNotice {
        switch phase {
        case .idle, .working: return .couldNotStart
        case .blocked, .awaitingRelaunch: return .stopped
        }
    }

    /// «Ahora no»: ¿hay que devolver al coordinador a `.idle`? **Solo si el bloqueo es de ESTE cierre**, en
    /// vuelo o ya vuelto.
    ///
    /// Uno ajeno se deja donde está: su pantalla lo vuelve a enseñar, y reconocerlo aquí le borraría la
    /// decisión pendiente —«Esperar» o «Cerrar sesión igualmente» del export de Ajustes vive en el
    /// `blockedExit` que `acknowledgeBlocked()` pone a `nil`—. Quien NO pidió cerrar no toca el cierre.
    static func laterAcknowledgesBlocked(notice: AppleIDCloseNotice?, phase: CloudSessionSignOut.Phase) -> Bool {
        guard notice == .closing || notice == .stopped, case .blocked = phase else { return false }
        return true
    }

    // MARK: - La red de presentación

    /// ¿La hoja tiene que estar presentada?
    ///
    /// **Con `.awaitingRelaunch`, no.** El borrado está armado y el anchor es del cover terminal
    /// (`SignOutRelaunchNetModifier`, dueño único). Dos redes togglando presentaciones en el mismo anchor
    /// son la carrera del 2026-07-14 que tumbaba las dos cadenas.
    static func presentationArmed(notice: AppleIDCloseNotice?, phase: CloudSessionSignOut.Phase) -> Bool {
        notice != nil && phase != .awaitingRelaunch
    }

    /// ¿La fase nueva del coordinador suelta el aviso? Solo `.awaitingRelaunch`, y soltar ahí no abre
    /// ninguna ventana al router: la matriz lo sigue reteniendo por `showSignOutRelaunch`.
    static func releasesOnPhaseChange(notice: AppleIDCloseNotice?, phase: CloudSessionSignOut.Phase) -> Bool {
        notice != nil && phase == .awaitingRelaunch
    }

    /// El `onDismiss` de la hoja: ¿re-presentar? **Solo si la hoja HABÍA aparecido.**
    ///
    /// Una hoja que nunca montó y que la propia red apaga para reintentar no es un desmontaje que atender.
    /// Re-armar ahí reiniciaría el contador del cap en cada vuelta, la red no se agotaría nunca y la
    /// condición viva no se soltaría: el brick que la red existe para impedir.
    static func rearmsOnDismiss(wasPresented: Bool, notice: AppleIDCloseNotice?,
                                phase: CloudSessionSignOut.Phase) -> Bool {
        wasPresented && presentationArmed(notice: notice, phase: phase)
    }

    /// Qué hacer cuando la red agota el cap del ciclo sin que la hoja monte.
    enum ExhaustedResolution: Equatable {
        /// Seguir intentando. Solo con el cierre EN VUELO y trabajando: `isSignOutWorking` ya retiene el
        /// router, así que soltar no libera nada, y dejaría sin pantalla el bloqueo en que puede acabar.
        case keepTrying
        /// Soltar el aviso: vuelve en el arranque siguiente. `acknowledgingBlocked`: el cierre de este
        /// aviso paró en un bloqueo y, sin la hoja, nadie lo va a enseñar ni a reconocer.
        case release(acknowledgingBlocked: Bool)
    }

    static func onPresentationExhausted(notice: AppleIDCloseNotice?,
                                        phase: CloudSessionSignOut.Phase) -> ExhaustedResolution {
        if notice == .closing, phase == .working { return .keepTrying }
        return .release(acknowledgingBlocked: laterAcknowledgesBlocked(notice: notice, phase: phase))
    }
}
