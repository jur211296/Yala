//
//  SyncStatusSectionLogic.swift
//  Yala
//
//  Qué dice la tarjeta «Sincronización» de «Dónde viven tus datos» (`StorageSettingsView.syncStatusSection`), en puro
//  para poder medirlo: el `CloudMigrationController` no se construye en tests.
//
//  Ticket `cloud-sync-status-says-all-synced-with-changes-still-pending` (decisión de Jürgen, 2026-10-07). Hasta ese día la
//  sección tenía tres ramas —el attest terminal, `syncNeedsSignIn` y un `else` con el check verde—, y todo lo que las dos
//  primeras no enumeraban caía al `else`: sin red y con dos gastos sin subir, la pantalla decía «Todo sincronizado».
//

import Foundation

enum SyncStatusSectionLogic {

    /// Lo que pinta la tarjeta, en orden de prioridad.
    enum Status: Equatable {
        /// Este teléfono no pasa App Attest: re-firmar no lo arregla, así que va antes que la puerta de firmar.
        case attestUnavailable
        /// El motor espera a que se vuelva a firmar. `nil` = la cola no se dejó contar: se ofrece firmar sin cifra.
        case needsSignIn(pendingCount: Int?)
        /// Quedan cambios sin subir y el motor no acaba de completar un ciclo. `nil` = no se dejaron contar.
        case waitingForConnection(pendingCount: Int?)
        /// Nada pendiente, o el motor sano y lo que queda sale en su próximo ciclo.
        case upToDate
    }

    /// **El orden es el contrato**: attest terminal > `syncNeedsSignIn` > cambios esperando > «Todo sincronizado».
    ///
    /// La tercera rama exige el modo nube y un motor que NO esté sano (`engineIsHealthy`): con el último ciclo completado,
    /// lo que se apuntó después sale en el siguiente (60 s), y decir «esperando conexión» con la red bien sería otra
    /// frase falsa. **Un recuento que no se deja leer no se lee como cero**: sale sin cifra, pero nunca el check verde.
    static func decide(attestNoticeShowing: Bool,
                       needsSignIn: Bool, signInPendingCount: Int?,
                       isCloud: Bool, pendingCount: Int?, engineIsHealthy: Bool) -> Status {
        if attestNoticeShowing { return .attestUnavailable }
        if needsSignIn { return .needsSignIn(pendingCount: signInPendingCount) }
        guard isCloud, !engineIsHealthy else { return .upToDate }
        guard let pendingCount else { return .waitingForConnection(pendingCount: nil) }
        return pendingCount > 0 ? .waitingForConnection(pendingCount: pendingCount) : .upToDate
    }

    /// ¿Está sano el motor? Corriendo su cadencia y con el último ciclo que dio señal de red COMPLETADO
    /// (`consecutiveTransients == 0`: el runtime lo pone a cero en `.completed` y lo sube en cada `.transient`;
    /// `.coalesced` no lo toca).
    ///
    /// Todo lo demás cuenta como no sano, y es la población del ticket: sin red (`.transient` por transporte), App Attest
    /// caducado (el motor sale en su puerta como `.transient`), el 401 `yala_attest_required` del gateway, la sesión perdida
    /// sin red con la verificación en caché, y el motor `.idle` por el gate de dominio.
    static func engineIsHealthy(state: CloudSyncRuntime.RuntimeState?, consecutiveTransients: Int) -> Bool {
        state == .running && consecutiveTransients == 0
    }

    /// Cuántos cambios esperan, sumando las TRES colas: las filas vivas del outbox personal, los cambios del History que
    /// ningún drain capturó todavía (sin red no se capturan hasta el siguiente ciclo, y el backoff llega a 300 s) y las
    /// filas vivas del outbox de grupos (en la nube su ciclo corre dentro del personal). `nil` si cualquiera no se dejó
    /// contar.
    static func pendingCount(personalRows: Int?, personalUncaptured: Int?, groupsRows: Int?) -> Int? {
        guard let personalRows, let personalUncaptured, let groupsRows else { return nil }
        return personalRows + personalUncaptured + groupsRows
    }
}
