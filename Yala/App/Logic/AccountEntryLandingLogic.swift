//
//  AccountEntryLandingLogic.swift
//  Yala
//
//  Lo que pasa al entrar en una cuenta de Yala desde la bienvenida (recorrido del iPhone 14, 13-nov; ticket
//  `panel-and-groups-show-data-on-entry`): que las pantallas se enteren de los datos que baja la nube, que el Panel espere
//  con su esqueleto en vez de enseñar S/ 0, y que quien entró por la puerta de Grupos aterrice en Grupos.
//

import Foundation

// MARK: - Lo que baja la nube refresca las pantallas a la vista

/// El aviso del motor de la nube tras un tirón con cambios (`.cloudSyncAppliedRemoteChanges`).
///
/// Hasta el 2026-11-13 solo marcaba «hay cambios pendientes», y lo pendiente se aplica al volver a primer plano o al
/// aparecer una vista. Tras «¡Tu cuenta está lista!» los datos de la cuenta llegan justo en ese tirón, con el Panel ya
/// pintado: se quedaba en S/ 0 y Registros en «Sin registros» hasta cambiar de pestaña o cerrar Yala (card c8i9). Con la
/// app delante se aplica en el acto (`dataVersion`), y todas las pantallas montadas recargan; sin ella, espera a volver.
@MainActor
enum RemoteChangesFanOut {
    static func receive(isApplicationActive: Bool) {
        receive(isApplicationActive: isApplicationActive, session: .shared)
    }

    static func receive(isApplicationActive: Bool, session: SessionState) {
        session.markRemoteChangePending()
        guard isApplicationActive else { return }
        session.applyPendingChangesIfNeeded()
    }
}

// MARK: - El Panel espera a la cuenta con su esqueleto

/// «Si los datos de verdad no están listos, un spinner, nunca un Panel en cero» (Jürgen, 13-nov, card c8i9).
///
/// La espera empieza solo si el Panel carga VACÍO (sin ninguna cuenta) con el motor de la nube activo y sin su primer
/// tirón: es la entrada a una cuenta, o un teléfono que la está bajando. Una vez empezada sigue hasta que el tirón
/// termina aunque ya hayan llegado cuentas, para no enseñar datos a medias. Con el teléfono que no consigue App Attest el
/// motor no baja nada (`CloudHydrationLogic`), y no se espera. El techo evita el esqueleto para siempre sin red: pasado,
/// el Panel enseña lo que haya hasta que el tirón termine.
nonisolated enum PanelAccountDataWait: Equatable {
    case idle
    case waiting(since: Date)
    case gaveUp

    static let ceiling: TimeInterval = 60

    var isWaiting: Bool {
        if case .waiting = self { return true }
        return false
    }

    func next(
        hasAccounts: Bool,
        cloudEngineActive: Bool,
        firstPullCompleted: Bool,
        attestVerdictIsTerminal: Bool,
        now: Date
    ) -> PanelAccountDataWait {
        let engineStillBringing = cloudEngineActive && !firstPullCompleted && !attestVerdictIsTerminal
        guard engineStillBringing else { return .idle }
        switch self {
        case .idle:
            return hasAccounts ? .idle : .waiting(since: now)
        case .waiting(let since):
            return now.timeIntervalSince(since) >= Self.ceiling ? .gaveUp : self
        case .gaveUp:
            return .gaveUp
        }
    }
}

// MARK: - Quien entra por la puerta de Grupos aterriza en Grupos

/// La bienvenida pierde la puerta por la que se entró en cuanto pasa a «¡Hola de nuevo!»: «Entra aquí» de «¿Cómo
/// empiezas?» va por la misma entrada que «Ya tengo una cuenta», y «Empezar» llevaba al Panel personal (card x5tm). La
/// puerta se apunta al tocar «Entra aquí» y la consume «Empezar». Cualquier otra entrada de la vitrina la retira. Vive en
/// memoria a propósito: si Yala se cierra a mitad, aterriza en el Panel, como antes.
@MainActor
enum WelcomeGroupsDoorLanding {
    private(set) static var isArmed = false

    static func arm() { isArmed = true }

    static func disarm() { isArmed = false }

    /// `true` una sola vez tras `arm()`.
    static func consume() -> Bool {
        defer { isArmed = false }
        return isArmed
    }
}
