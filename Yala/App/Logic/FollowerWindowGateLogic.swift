//
//  FollowerWindowGateLogic.swift
//  Yala
//
//  Qué enseña una ventana seguidora según en qué estado está la app (fase 4 del carril adaptativo).
//

import Foundation

/// Decisión pura de qué monta una ventana **seguidora** (toda ventana que no es la líder, ver `SceneRegistry`).
///
/// La seguidora no tiene shell propio: el arranque, el Welcome, los borrados y las preguntas de sistema los lleva la
/// líder. Mientras la app esté en un estado en el que nada debe operar, la seguidora **desmonta** su contenido —y con
/// él cualquier hoja que tuviera abierta— y enseña lo que toca. Desmontar y no tapar es a propósito: una hoja
/// presentada sigue encima de cualquier capa, y solo desmontar garantiza que esa ventana no siga operando.
enum FollowerWindowGateLogic {

    enum State: Equatable {
        /// Pestañas, hojas y lo de siempre.
        case operating
        /// Arranque, borrado o cierre de sesión en curso: fondo con progreso, sin nada que tocar.
        case busy
        /// Sesión cerrada, falta reabrir: el mismo cover terminal que la líder.
        case signOutRelaunch
        /// Por debajo del build mínimo: el mismo cover terminal que la líder.
        case forceUpdate
        /// La líder está preguntando algo que hay que contestar antes de seguir (Welcome, borrado remoto, cambio de
        /// Apple ID…): «Yala te espera en otra ventana», con un botón que la trae al frente.
        case needsLeader

        /// Lo que la seguidora publica como `shellModalBlocker` de su ventana: con algo puesto, sus consumidores del
        /// router retienen la cola en vez de presentar sobre un contenido desmontado.
        var blockerName: String? {
            switch self {
            case .operating: nil
            case .busy: "followerBusy"
            case .signOutRelaunch: "signOutRelaunch"
            case .forceUpdate: "forceUpdate"
            case .needsLeader: "followerNeedsLeader"
            }
        }
    }

    /// Bloqueos de la líder que son arranque: la seguidora espera sin decir nada.
    static let startingBlockers: Set<String> = ["splash", "bootstrapPending"]

    /// Bloqueos de la líder que son una pregunta o un flujo que hay que terminar allí antes de usar Yala. Los demás
    /// bloqueos de la líder (bandeja, ofertas, invitaciones, avisos de grupo, Novedades, Ajustes de sync) son hojas
    /// suyas: la seguidora sigue operando.
    static let attentionBlockers: Set<String> = [
        "remoteWipeAlert", "iCloudRestartAlert", "appleIDCloseNotice",
        "freshStartWipeAlert", "freshStartWipeFailedAlert",
        // Los dos pueden BORRAR el corpus personal desde su hoja sin pasar por `isWipingData` (el aviso del espejo
        // tardío y la activación de Yala completo): con una sola ventana la hoja modal impedía escribir mientras.
        "lateICloudNotice", "fullModeActivation",
        "languageSelection", "welcomeFlow", "welcomeRestore", "inviteRecovery", "welcomeCloudSignIn", "onboarding"
    ]

    /// - Parameters:
    ///   - leaderBlocker: el `shellModalBlocker` de la ventana líder (`nil` si está libre).
    ///   - hasLeader: hay una líder registrada.
    ///   - isWipingData: borrado de datos en curso (`SessionState.isWipingData`).
    ///   - busyBySignOut: hay un cierre de sesión en curso que lanzó OTRA ventana (`SignOutDriverLogic.windowIsBusy`).
    ///   - signOutAwaitingRelaunch: sesión cerrada, falta reabrir.
    ///   - forceUpdateRequired: forzado de actualización vigente.
    ///   - hasCompletedOnboarding: el onboarding está hecho.
    static func state(
        leaderBlocker: String?,
        hasLeader: Bool,
        isWipingData: Bool,
        busyBySignOut: Bool,
        signOutAwaitingRelaunch: Bool,
        forceUpdateRequired: Bool,
        hasCompletedOnboarding: Bool
    ) -> State {
        // Orden = severidad, el mismo de la matriz de la líder (`ContentViewReadinessLogic.blocker`).
        if forceUpdateRequired { return .forceUpdate }
        if signOutAwaitingRelaunch { return .signOutRelaunch }
        if isWipingData { return .busy }
        if busyBySignOut { return .busy }
        guard hasLeader else { return .busy }
        if let leaderBlocker {
            if startingBlockers.contains(leaderBlocker) { return .busy }
            if attentionBlockers.contains(leaderBlocker) { return .needsLeader }
        }
        // Sin onboarding hecho la líder está en el Welcome (o a punto): aquí no hay nada que operar todavía.
        if !hasCompletedOnboarding { return .needsLeader }
        return .operating
    }

}

/// Qué dice una ventana que espera y a qué ventana lleva su botón (UX 2.2 · L15-11). Decisión pura: la lee `WindowBusyView`.
enum WindowBusyLogic {

    enum Reason: Equatable {
        /// Otra ventana está cerrando la sesión.
        case signingOut
        /// Se están borrando los datos. Puede lanzarlo esta misma ventana (Ajustes › Vaciar datos), así que ni el texto
        /// habla de «la otra ventana» ni hay botón.
        case wiping
        /// La líder arranca, o todavía no hay líder.
        case starting
    }

    /// El texto: «en la otra ventana» solo cuando hay otra ventana a la que ir.
    enum Text: Equatable {
        case signingOutElsewhere, signingOut, wiping, starting
    }

    static func text(for reason: Reason, hasTarget: Bool) -> Text {
        switch reason {
        case .signingOut: hasTarget ? .signingOutElsewhere : .signingOut
        case .wiping: .wiping
        case .starting: .starting
        }
    }

    /// El mismo orden que `FollowerWindowGateLogic.state`: el borrado pesa más que el cierre de sesión.
    static func reason(isWipingData: Bool, signOutWorking: Bool) -> Reason {
        if isWipingData { return .wiping }
        if signOutWorking { return .signingOut }
        return .starting
    }

    /// La ventana que hace lo que esta espera: la que lanzó el cierre de sesión, o la líder. `nil` si es esta misma o ya
    /// no está viva: entonces no hay a dónde ir y el botón no sale.
    static func target(
        for reason: Reason,
        windowID: UUID,
        signOutDriverID: UUID?,
        leaderID: UUID?,
        aliveIDs: [UUID]
    ) -> UUID? {
        let candidate: UUID? = switch reason {
        case .signingOut: signOutDriverID
        case .wiping: nil
        case .starting: leaderID
        }
        guard let candidate, candidate != windowID, aliveIDs.contains(candidate) else { return nil }
        return candidate
    }
}
