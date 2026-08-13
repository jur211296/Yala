//
//  ICloudRestoreSessionSignal.swift
//  Yala
//
//  El adaptador runtime de `ICloudRestoreInProgressLogic`: quién enciende la señal, quién la lee y por
//  qué vive donde vive.
//
//  **EN MEMORIA, JAMÁS en `UserDefaults`.** No es una omisión: es el sesgo fail-closed del fix. La
//  señal abre —acotadamente— un guard de frontera de cuenta, así que su modo de fallo tiene que ser
//  apagarse, nunca quedarse encendida. Persistida, un kill del proceso a mitad del restore dejaría la
//  puerta entornada en el arranque siguiente, cuando ya no hay ningún import que la justifique; en
//  memoria, ese mismo kill la apaga y el guard vuelve a bloquear.
//
//  **Y no se apaga al volver atrás.** Salir de la pantalla de restaurar no para el import: CloudKit
//  sigue bajando filas. Apagarla ahí dejaría el bug intacto, porque «tocar atrás» ES el escenario.
//  Lo que la apaga es que el import ASIENTE, y eso lo decide la lógica pura leyendo el mundo.
//

import Foundation

@MainActor
enum ICloudRestoreSessionSignal {

    /// CUÁNDO arrancó la búsqueda del restore en ESTE proceso. `nil` = no se pidió.
    ///
    /// **Es un instante y no un `Bool` a propósito** (fix del 2026-08-13): como `Bool` era un latch que
    /// no se apagaba nunca dentro de la sesión, y toda la ventana dependía de que el import asentara —
    /// algo que puede no ocurrir JAMÁS. Con el instante, la ventana caduca sola aunque no la apague
    /// nadie, que es lo único que hace el sesgo fail-closed de verdad.
    private(set) static var restoreStartedAt: Date?

    /// Lo llama `WelcomeRestoreView` al pasar a `.searching`, que es el único estado en el que hay un
    /// import de CloudKit de verdad — `.wiped` y `.iCloudDisabled` no importan nada y encender ahí
    /// abriría la señal sin corpus que la justifique.
    ///
    /// **No re-arma si ya estaba abierta**: el botón de reintentar de la pantalla vuelve a llamar aquí,
    /// y dejar que reinicie el reloj convertiría el tope en una ventana extensible a voluntad.
    static func noteRestoreStarted(now: Date = .now) {
        guard restoreStartedAt == nil else { return }
        restoreStartedAt = now
    }

    /// El flujo de restauración TERMINÓ — gane o pierda. Lo llama `RestoreProgressView` cuando su
    /// espera se resuelve, en los DOS desenlaces (`completed` y `partial`): en ese punto ya no hay
    /// ninguna descarga que justifique tener abierto un guard de frontera de cuenta.
    ///
    /// Es precisión, no la red: el usuario que toca «atrás» a mitad desmonta la vista y cancela ese
    /// `Task`, así que este apagado no llega a correr. Para ese camino —que es el escenario del propio
    /// bug que la señal arregla— quien cierra la ventana es la caducidad de la lógica pura.
    static func noteRestoreFinished() {
        restoreStartedAt = nil
    }

    /// El input del guard cross-cuenta. Se lee EN el instante de decidir y nunca se cachea: el mirror
    /// puede asentar entre que se monta la pantalla y que el usuario firma.
    static var isRestoringNow: Bool {
        ICloudRestoreInProgressLogic.isRestoringNow(
            restoreStartedAt: restoreStartedAt,
            hasCompletedFirstImport: iCloudSyncService.shared.hasCompletedFirstImport,
            isImportQuiescent: iCloudSyncService.shared.isImportQuiescent,
            hasObservedImportActivity: iCloudSyncService.shared.hasObservedImportActivity,
            now: .now)
    }

    #if DEBUG
    /// Solo tests: el latch es estado de proceso y las suites que lo tocan van `.serialized`.
    static func _testReset() {
        restoreStartedAt = nil
    }

    static func _testSetStartedAt(_ value: Date?) {
        restoreStartedAt = value
    }
    #endif
}
