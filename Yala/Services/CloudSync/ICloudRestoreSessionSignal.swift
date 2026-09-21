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
//  pantalla y `RestoreProgressView` NO llama al apagado — quedó detrás de su `guard
//  !Task.isCancelled`, que es lo que hace verdad el párrafo de arriba. El token sigue siendo la red
//  para cuando el apagado sí corre.
//
//  **EL RELOJ Y EL DUEÑO SON DOS COSAS DISTINTAS** (fix del 2026-09-21,
//  `abandoned-restore-no-longer-clears-the-session-window-clock`), y separarlos repara el daño
//  colateral del párrafo anterior. Mientras el flujo abandonado despertaba a los 90 s y apagaba, el
//  reloj se liberaba solo; desde que no despierta, nadie lo libera. Quien entraba, se arrepentía y
//  volvía a entrar siete minutos después heredaba un reloj de siete minutos: su tope duro caducaba a
//  media descarga y el guard cross-cuenta se cerraba sobre el dueño legítimo — el bug que esta señal
//  existe para impedir, entrando por la puerta de al lado.
//
//  Hoy son tres verbos y cada uno mueve lo suyo:
//
//   · `noteRestoreStarted` — entra un intento. **Estrena reloj si la ventana está apagada, y re-ancla
//     una huérfana solo si hay descarga real detrás**; con dueño vigente lo conserva. Los dos límites
//     son lo que impide que re-anclar se convierta en un tope extensible a voluntad.
//   · `noteRestoreAbandoned` — el intento se va con el import bajando. **Suelta la titularidad y NO
//     toca el reloj**: la ventana sigue abierta para ese import, y la cierran el asentamiento o la
//     caducidad. Apagarla aquí es justo lo que prohíbe el párrafo de «no se apaga al volver atrás».
//   · `noteRestoreFinished` — el intento terminó por sus propios méritos. Apaga las dos cosas.
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

    /// El flujo que hoy puede cerrar la ventana: el ÚLTIMO que entró. `nil` = **nadie la vigila**.
    ///
    /// **EL INVARIANTE, y solo va en una dirección** (cambiado el 2026-09-21): `currentFlow != nil ⇒
    /// restoreStartedAt != nil`. Un dueño sin reloj no existe — la única forma de acuñar un token es
    /// `noteRestoreStarted`, que deja las dos cosas puestas.
    ///
    /// **El converso ya NO vale, y ese hueco tiene nombre: la ventana HUÉRFANA.**
    /// `restoreStartedAt != nil && currentFlow == nil` es el estado legítimo de un intento que se fue
    /// con el import todavía bajando: la ventana sigue abierta —el import es real y sus filas siguen
    /// llegando— pero nadie la vigila, así que la cierran el asentamiento o la caducidad, y la
    /// siguiente entrada la ESTRENA en vez de heredar su reloj. Hasta el 2026-09-21 el invariante era
    /// una doble implicación, y por eso apagar la ventana y liberar su reloj eran el mismo acto:
    /// había que elegir entre cerrarle la ventana a un import vivo o dejar que el siguiente intento
    /// heredara un reloj que no describía nada suyo.
    private(set) static var currentFlow: FlowToken?

    /// Lo llama `WelcomeRestoreView` al pasar a `.searching`, que es el único estado en el que hay un
    /// import de CloudKit de verdad — `.wiped` y `.iCloudDisabled` no importan nada y encender ahí
    /// abriría la señal sin corpus que la justifique.
    ///
    /// **Estrena el reloj si no hay dueño, y ROTA el dueño siempre**, que son dos cosas distintas y
    /// conviene no mezclarlas:
    ///
    ///  · **La ventana apagada la enciende cualquier entrada** (`restoreStartedAt == nil`): es la
    ///    primera del proceso, o la que sigue a un flujo que terminó. Sin este término la señal no se
    ///    encendería nunca.
    ///  · **Una ventana HUÉRFANA solo la re-ancla una entrada con descarga real detrás**
    ///    (`currentFlow == nil` **Y** `hasObservedImportActivity`). Re-anclar es lo que arregla
    ///    `abandoned-restore-no-longer-clears-the-session-window-clock`: quien entra, se arrepiente y
    ///    vuelve 400 s después heredaba un reloj que no describía su descarga, y su tope duro caducaba
    ///    a media bajada con el guard cross-cuenta cerrándose sobre el dueño legítimo.
    ///    **Y el testigo del import es lo que impide que re-anclar se vuelva un tope infinito**, que
    ///    lo cazó una lente de la review: sin él, entrar y salir de Restaurar cada menos de 60 s
    ///    renueva la ventana indefinidamente —`isRestoringNow` mide TODOS sus plazos desde este
    ///    instante, gracia incluida— y en un teléfono con el corpus de otra persona eso mantiene
    ///    abierta de par en par la puerta que el guard existe para cerrar. Con el testigo, ese ciclo
    ///    no re-ancla nada: sin un solo `.importEvent` no hay descarga que justifique una ventana
    ///    nueva, y la gracia de 60 s la cierra como antes del ticket. Es el mismo testigo con el que
    ///    `ICloudRestoreInProgressLogic` separa «el import va lento» de «no hay nada que importar», y
    ///    su modo de fallo es conservar el reloj viejo, o sea CERRAR ANTES.
    ///  · Con dueño vigente el reloj **NO se toca** pase lo que pase, y ahí está el tope de dentro: un
    ///    flujo vivo que vuelva a pasar por aquí no puede re-anclar su propia ventana. Es la condición
    ///    que de verdad significa «dentro de un restore vivo» — y hasta el 2026-09-21 el guard decía
    ///    cubrir eso mirando `restoreStartedAt == nil`, que **no lo cubre**: los cinco botones de
    ///    «volver a buscar» de `WelcomeRestoreView` solo salen en estados terminales, todos aguas
    ///    abajo de `noteRestoreFinished`, así que en el instante del reintento el reloj ya era `nil` y
    ///    se estrenaba igual. Lo único que producía aquel guard era el bug.
    ///  · El dueño (`currentFlow`) es SIEMPRE el intento que acaba de entrar. Cada llamada acuña un
    ///    token nuevo, así que el intento anterior —esté abandonado o simplemente terminado— pierde
    ///    el derecho a cerrar. Sin esa rotación los dos comparten identidad y el token no distingue
    ///    nada, que es exactamente el bug que este mecanismo existe para cerrar.
    ///
    /// - Parameter hasObservedImportActivity: ¿llegó ALGÚN `.importEvent` en este proceso, con o sin
    ///   error? **SIN valor por defecto a propósito**, misma familia que el `restoreInProgress: Bool`
    ///   de `CrossAccountEntryGuardLogic` y que el `init` `fileprivate` de `FlowToken`: un default
    ///   sería una constante, y las dos constantes posibles rompen algo —`false` no re-ancla nunca y
    ///   devuelve el bug de heredar el reloj; `true` re-ancla siempre y deja el tope duro extensible
    ///   con solo navegar—, así que quien añada un call-site tiene que DECIDIR de dónde sale, y lo
    ///   comprueba el compilador y no un `grep`. Leerlo dentro tampoco vale: bajo el host de test
    ///   nadie importa nada y el singleton vale `false` en toda corrida, así que la rama que re-ancla
    ///   sería inalcanzable para los tests — que es como este término se vuelve letra muerta sin que
    ///   nada se ponga rojo.
    ///
    /// - Returns: el token de ESTE intento. Guárdalo y devuélvelo en `noteRestoreFinished(_:)` o en
    ///   `noteRestoreAbandoned(_:)`: es lo único que autoriza a cerrar la ventana o a soltarla.
    static func noteRestoreStarted(
        now: Date = .now,
        hasObservedImportActivity: Bool
    ) -> FlowToken {
        if restoreStartedAt == nil || (currentFlow == nil && hasObservedImportActivity) {
            restoreStartedAt = now
        }
        let token = FlowToken()
        currentFlow = token
        return token
    }

    /// El intento **se fue de la pantalla con el import todavía bajando**: suelta la titularidad y
    /// deja la ventana abierta.
    ///
    /// **No toca `restoreStartedAt`, y esa mitad es innegociable**: salir de Restaurar no para el
    /// import —CloudKit sigue trayendo filas— así que apagar aquí le devolvería al dueño legítimo el
    /// bloqueo cross-cuenta sobre su propia cuenta. Es literalmente el bug que cerró
    /// `force-fetch-and-wait-ignores-cancellation`, y por eso este método existe en vez de reusar
    /// `noteRestoreFinished`.
    ///
    /// Lo que sí hace es **dejar la ventana huérfana**: sigue viva para el import que la justifica —la
    /// cierran el asentamiento o la caducidad de `ICloudRestoreInProgressLogic`— pero ya no la vigila
    /// nadie, así que la entrada siguiente estrena reloj en vez de heredar un instante que no
    /// describe nada suyo.
    ///
    /// **Solo suelta si `token` es el dueño vigente**, por la misma razón que el apagado: un intento
    /// abandonado que se entera tarde no puede desposeer al que entró después. Sin ese guard, salir de
    /// una pantalla vieja le quitaría la titularidad al intento vivo y su
    /// `noteRestoreFinished` pasaría a ser un no-op — la ventana del vivo se quedaría abierta hasta
    /// caducar.
    static func noteRestoreAbandoned(_ token: FlowToken) {
        guard currentFlow == token else { return }
        currentFlow = nil
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
    /// cierra es la lógica pura — el import que asienta, o la caducidad. Lo que ese camino sí hace
    /// desde el 2026-09-21 es **soltar la titularidad** (`noteRestoreAbandoned`), que no es apagar:
    /// deja la ventana viva para su import y libera el reloj para la entrada siguiente.
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
