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
//  **El apagado está acotado a UN flujo, y esa simetría se pagó** (fix del 2026-09-21). Hasta entonces
//  el encendido era idempotente y el apagado incondicional, así que un flujo ABANDONADO cerraba la
//  ventana de otro que seguía vivo: entrar a Restaurar, tocar atrás a los 5 s, volver a entrar a los
//  10 y, al minuto y medio, ver cómo el primer intento —clavado en el tope de `forceFetchAndWait`—
//  despertaba y apagaba la ventana del segundo, con su import a medias y el guard cross-cuenta
//  cerrándose sobre el dueño legítimo. Hoy cada entrada recibe su `FlowToken` y solo el DUEÑO vigente
//  puede cerrar.
//
//  **Y ese despertar ya no ocurre** (mismo día, `force-fetch-and-wait-ignores-cancellation`):
//  `forceFetchAndWait` observa cancelación, así que el intento abandonado se corta al salir de la
//  pantalla y `RestoreProgressView` NO llama aquí — el apagado quedó detrás de su `guard
//  !Task.isCancelled`, que es lo que hace verdad el párrafo de arriba. El token sigue siendo la red
//  para cuando el apagado sí corre.
//

import Foundation

@MainActor
enum ICloudRestoreSessionSignal {

    /// La identidad de UN intento de restauración: quién tiene derecho a cerrar la ventana.
    ///
    /// **Su `init` es `fileprivate` y eso es el invariante entero**: la única forma de tener un token
    /// es haber llamado a `noteRestoreStarted()`, así que un apagado no puede venir de un flujo que
    /// nunca encendió nada, y el mutante barato —`RestoreProgressView(flowToken: .init())`, que
    /// deshace el ticket y deja la suite verde— **no compila**. Misma familia que el
    /// `restoreInProgress: Bool` sin valor por defecto de `CrossAccountEntryGuardLogic`: quien añada
    /// un call-site tiene que DECIDIR, y lo comprueba el compilador y no un `grep`.
    struct FlowToken: Hashable, Sendable {
        private let raw: UUID
        fileprivate init() { raw = UUID() }
    }

    /// CUÁNDO arrancó la búsqueda del restore en ESTE proceso. `nil` = no se pidió.
    ///
    /// **Es un instante y no un `Bool` a propósito** (fix del 2026-08-13): como `Bool` era un latch que
    /// no se apagaba nunca dentro de la sesión, y toda la ventana dependía de que el import asentara —
    /// algo que puede no ocurrir JAMÁS. Con el instante, la ventana caduca sola aunque no la apague
    /// nadie, que es lo único que hace el sesgo fail-closed de verdad.
    private(set) static var restoreStartedAt: Date?

    /// El flujo que hoy puede cerrar la ventana: el ÚLTIMO que entró. `nil` ⇔ `restoreStartedAt == nil`.
    private(set) static var currentFlow: FlowToken?

    /// Lo llama `WelcomeRestoreView` al pasar a `.searching`, que es el único estado en el que hay un
    /// import de CloudKit de verdad — `.wiped` y `.iCloudDisabled` no importan nada y encender ahí
    /// abriría la señal sin corpus que la justifique.
    ///
    /// **Conserva el reloj y ROTA el dueño**, que son dos cosas distintas y conviene no mezclarlas:
    ///
    ///  · El reloj (`restoreStartedAt`) NO se reinicia. El botón de reintentar de la pantalla vuelve a
    ///    llamar aquí, y dejar que lo reiniciara convertiría el tope duro en una ventana extensible a
    ///    voluntad. La ventana de la segunda entrada sigue anclada en la primera, que es el sesgo
    ///    conservador: caduca antes, nunca después.
    ///  · El dueño (`currentFlow`) es SIEMPRE el intento que acaba de entrar. Cada llamada acuña un
    ///    token nuevo, así que el intento anterior —esté abandonado o simplemente terminado— pierde
    ///    el derecho a cerrar. Sin esa rotación los dos comparten identidad y el token no distingue
    ///    nada, que es exactamente el bug que este mecanismo existe para cerrar.
    ///
    /// - Returns: el token de ESTE intento. Guárdalo y devuélvelo en `noteRestoreFinished(_:)`: es lo
    ///   único que autoriza a cerrar la ventana.
    static func noteRestoreStarted(now: Date = .now) -> FlowToken {
        if restoreStartedAt == nil { restoreStartedAt = now }
        let token = FlowToken()
        currentFlow = token
        return token
    }

    /// El flujo de restauración TERMINÓ **por sus propios méritos** — gane (`completed`) o pierda
    /// (`partial`): en ese punto ya no hay ninguna descarga que justifique tener abierto un guard de
    /// frontera de cuenta.
    ///
    /// **«Por sus propios méritos» es la precisión que añadió el 2026-09-21**, y no es un matiz:
    /// `RestoreProgressView` llama detrás de un `guard !Task.isCancelled`, así que una espera que
    /// resuelve mientras la pantalla se va NO llega aquí — ni siquiera cuando resuelve con `true`, que
    /// `waitForImportQuiescence` puede hacer sobre un `Task` ya cancelado si el import quedó quiescente.
    /// Esa ventana la cierra entonces la lógica pura, leyendo el mundo.
    ///
    /// **Solo cierra si `token` es el dueño vigente.** Desde el arreglo de la cancelación
    /// (`force-fetch-and-wait-ignores-cancellation`) el flujo abandonado ya ni siquiera llega aquí —
    /// `RestoreProgressView` se corta al salir de la pantalla—, pero el guard se queda: es lo único que
    /// separa «este intento terminó» de «un intento cualquiera terminó», y basta con que alguien vuelva
    /// a llamar desde un camino que no comprueba la cancelación para que la distinción haga falta otra
    /// vez.
    ///
    /// Es precisión, no la red: quien toca «atrás» y no vuelve no apaga nada, y para ese hueco quien
    /// cierra es la lógica pura — el import que asienta, o la caducidad.
    static func noteRestoreFinished(_ token: FlowToken) {
        guard currentFlow == token else { return }
        restoreStartedAt = nil
        currentFlow = nil
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
        currentFlow = nil
    }
    #endif
}
