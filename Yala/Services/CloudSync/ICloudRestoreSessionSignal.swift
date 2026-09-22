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
//  Hoy son CINCO verbos y cada uno mueve lo suyo. **Eran cuatro en esta lista hasta el 2026-09-22 y
//  el quinto ya existía**: faltaba `noteRestoreUnavailable`, que es justo el único que borra el ancla
//  de la gracia que estrenó `restore-retry-reopens-the-session-window-every-90-seconds`. Lo midió una
//  lente de la review.
//
//   · `noteRestoreStarted` — entra un intento. **Estrena reloj si la ventana está apagada, y re-ancla
//     una huérfana solo si hay descarga VIGENTE detrás**; con dueño vigente lo conserva. Los dos
//     límites son lo que impide que re-anclar se convierta en un tope extensible a voluntad.
//     **«VIGENTE» dejó de significar «alguna vez» el 2026-09-21**
//     (`leaving-and-reentering-restore-renews-the-hard-cap`): hasta ese día el testigo era
//     `hasObservedImportActivity`, un latch monótono del proceso, así que salir de Restaurar y volver
//     estrenaba 600 s apoyándose en un import que podía haber terminado veinte minutos antes.
//     **Y desde ese mismo día hereda el reloj APARCADO si la puerta de descarte dejó uno**
//     (`restore-session-window-has-no-reachable-ceiling`). Es el cuarto verbo de abajo, y cierra el
//     recorrido de tres toques que tumbó el techo del ticket anterior.
//     **El techo con NÚMERO sigue sin existir, y conviene saber por qué antes de intentarlo otra vez.**
//     Se implementó uno —un reloj de la cadena de re-anclas que ningún re-ancla movía— y la review lo
//     tumbó midiendo las dos mitades: no acotaba a quien quisiera saltárselo, porque
//     `noteRestoreFinished` era alcanzable desde la UI con el import vivo («Empezar desde cero» →
//     «Volver» → Restaurar, tres toques) y tras él la entrada siguiente ESTRENABA; y sí bloqueaba al
//     dueño legítimo, de forma permanente en el proceso, porque agotado el techo ninguna entrada podía
//     ya ni re-anclar ni estrenar. Lo que entró en su lugar cierra la primera mitad SIN abrir la
//     segunda: el aparcado caduca con el mismo tope duro de la ventana, así que agotado ése se estrena
//     con normalidad. Por debajo sigue el baseline irreductible —la señal vive en memoria a propósito,
//     y matar la app lo estrena todo—, que es lo que hace inalcanzable cualquier techo absoluto.
//   · `noteRestoreAbandoned` — la persona **se fue de Restaurar** con el import bajando. **Suelta la
//     titularidad y NO toca el reloj**: la ventana sigue abierta para ese import, y la cierran el
//     asentamiento o la caducidad. Apagarla aquí es justo lo que prohíbe el párrafo de «no se apaga al
//     volver atrás». Lo llama `WelcomeRestoreView` al desaparecer ELLA, no la pantalla de progreso —
//     ver su docblock, que es la mitad del ticket del tope.
//   · `noteRestoreDiscardRequested` — la persona **llegó a la puerta que borra**. Apaga las dos
//     cosas **y aparca el reloj**, porque esa puerta solo PREGUNTA: si vuelve sin haber borrado nada,
//     esa entrada hereda el reloj en vez de estrenar tope duro nuevo. Dice «pidió» y no «confirmó»
//     desde el 2026-09-22: seis de los siete caminos de Restaurar confirman con diálogo y `.wiped` no
//     —su búsqueda concluye por acto de la propia persona—, así que lo que comparten no es el diálogo.
//     **Y es el ÚNICO que apaga SIN titularidad** (2026-09-22,
//     `discard-gate-cannot-close-an-orphan-session-window`): quien declara que no quiere esas filas
//     deroga la premisa que las protege, sea de quien sea el intento que las traía. Su llamador es el
//     MONTAJE de `WelcomePrivateICloudGateView` —el destino común de los siete caminos de Restaurar y
//     de los dos de «Soy nuevo» → «Privado»—, y no un punto dentro de `WelcomeRestoreView`, que no
//     alcanzaba a los segundos.
//   · `noteRestoreFinished` — el intento terminó **y no queda descarga**. Apaga las dos cosas, y
//     además BORRA el aparcado: después de un final de verdad, lo que venga es una entrada nueva.
//     **Lo que NO borra es el ancla de la gracia**, y eso es el ticket del 2026-09-22: es el verbo por
//     el que pasa cada vuelta del ciclo «la espera se rinde a los 90 s → volver a buscar», y borrarla
//     ahí le devolvía al reintento sus 60 s por vuelta.
//   · `noteRestoreUnavailable` — esta entrada **no puede restaurar nada** (sin cuenta de iCloud, o tras
//     un wipe). No toca la ventana ni la titularidad: tira el aparcado y el ancla de la gracia, que son
//     las dos cosas que ya no describen nada. **El borrado del ancla solo cambia algo cuando el reloj
//     también está apagado** — con la ventana viva, la entrada siguiente vuelve a derivarla de ese
//     reloj, que es el estado correcto y no un olvido; medido por una lente de la review.
//
//  **Y «terminó» dejó de significar «la espera devolvió» el 2026-09-21**
//  (`restore-timeout-closes-the-session-window-with-the-import-still-running`). Agotar el tope de 90 s
//  tiene dos formas y solo una es un final: **sin un solo import observado** no hay nada bajando ni lo
//  hubo, y apagar es la precisión que este verbo aporta; **habiendo visto un import**, las filas siguen
//  entrando, así que apagar le devolvía al dueño legítimo el `.blockedForeignData` sobre su propia
//  cuenta justo mientras sus datos bajaban. En ese desenlace la pantalla de progreso **no llama a
//  nada**: ni apaga ni suelta, y conservar la titularidad es lo que impide que el reintento desde
//  «seguimos trayendo tus datos» re-ancle el tope duro cada 90 s. El término que lo decide es
//  `ICloudRestoreInProgressLogic.closesTheSessionWindow`, con los dos valores crudos — **no el
//  desenlace que elige el copy**, que agrupa «no vi ningún import» con «el último dio error» y esos
//  errores suelen ser retriables, con CloudKit trayendo filas detrás.
//
//  **El precio, medido y aceptado**: para esa población la ventana pasa de cerrarse a los 90 s a vivir
//  hasta que el import asiente o caduque —tope duro de 600 s—, y dentro de ese tramo `isRestoringNow`
//  se recalcula vivo, así que un import de rutina del espejo puede reabrirla. Es la exposición que el
//  ticket compra a cambio de no bloquear al dueño legítimo sobre sus propios datos, y las dos salidas
//  que sí sabían que no queda descarga la cierran antes: el asentamiento, y llegar a la puerta que
//  borra —aparcando el reloj, para que volver de ella sin haber borrado no estrene uno nuevo—.
//

import Foundation

@MainActor
enum ICloudRestoreSessionSignal {

    /// La identidad de UN intento de restauración: quién tiene derecho a cerrar la ventana.
    ///
    /// **Su `init` es `fileprivate` y eso es el invariante entero**: la única forma de tener un token
    /// es haber llamado a `noteRestoreStarted()`, así que ni soltar ni terminar pueden venir de un
    /// flujo que nunca encendió nada, y el mutante barato —`RestoreProgressView(flowToken: .init())`,
    /// que deshace el ticket y deja la suite verde— **no compila**. Misma familia que el
    /// `restoreInProgress: Bool` sin valor por defecto de `CrossAccountEntryGuardLogic`: quien añada
    /// un call-site tiene que DECIDIR, y lo comprueba el compilador y no un `grep`.
    ///
    /// **Gobierna TRES de los cinco verbos, no los cinco, y desde el 2026-09-22 son tres y no cuatro**
    /// (`discard-gate-cannot-close-an-orphan-session-window`). `noteRestoreDiscardRequested` dejó de
    /// pedirlo: quien declara que descarta el import deroga la premisa que lo protege, sea de quien
    /// sea el intento que lo traía, y exigir titularidad ahí dejaba en no-op el descarte de quien
    /// salió de Restaurar y volvió a entrar. Para ese verbo la red no es el compilador: es el conteo
    /// de call-sites de `ICloudRestoreSignalWiringTests`, y está dicho en su mensaje.
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

    /// **El reloj que la puerta de descarte se guarda en el bolsillo**: `nil` = nadie pasó por ella, o
    /// el aparcado ya se consumió.
    ///
    /// `restore-session-window-has-no-reachable-ceiling`, 2026-09-21. Lo escribe
    /// `noteRestoreDiscardRequested` y lo lee —una vez— el estreno de `noteRestoreStarted`. Existe
    /// porque apagar la ventana y OLVIDAR que existió son dos cosas distintas, y confundirlas era el
    /// recorrido de tres toques que tumbó el techo del ticket anterior: el «Empezar
    /// desde cero» dejaba el estado idéntico al de «nadie ha pedido restaurar en este proceso», y la
    /// vuelta desde la puerta —que **solo pregunta: no ha borrado nada**— estrenaba 600 s enteros sin
    /// esperar nada y sin necesitar que ninguna descarga estuviera viva.
    ///
    /// **Y solo lo aparca el descarte, no cualquier apagado.** `noteRestoreFinished` lo LIMPIA, y esa
    /// asimetría es la que evita reeditar el bloqueo por la puerta de al lado: los cinco botones de
    /// «volver a buscar» de `WelcomeRestoreView` salen en estados terminales, aguas abajo de aquél, y
    /// ese reintento tiene que ESTRENAR — heredar ahí un reloj viejo haría caducar a media bajada la
    /// descarga que el reintento acaba de arrancar, que es el daño de
    /// `abandoned-restore-no-longer-clears-the-session-window-clock`.
    private(set) static var parkedStartedAt: Date?

    /// **Desde cuándo se cuenta la GRACIA de 60 s, y es del PROCESO y no de la entrada.**
    ///
    /// `restore-retry-reopens-the-session-window-every-90-seconds`, 2026-09-22. Lo pone el primer
    /// estreno y lo lee `isRestoringNow`; lo único que lo borra es `noteRestoreUnavailable` —y matar
    /// la app—. En particular **`noteRestoreFinished` NO lo toca, y ése es el ticket entero**: con la
    /// gracia colgada del reloj de cada entrada, el teléfono con el corpus de otra persona mantenía
    /// abierto el guard de frontera de cuenta con UN toque cada minuto y medio. La espera de 90 s se
    /// rendía sin un solo `.importEvent`, `closesTheSessionWindow` apagaba, y «volver a buscar»
    /// estrenaba otros 60 s de gracia — sin pasar por ninguna puerta y sin que tuviera que bajar nada.
    /// Era el camino más barato que quedaba: el de la puerta de descarte cuesta tres toques y 600 s.
    ///
    /// **Es una FECHA y no un `Bool` «ya se gastó»** porque la gracia consumida no siempre son 60 s: un
    /// final sin imports puede llegar a los 3 s —`closesTheSessionWindow` no espera a la gracia— y con
    /// un `Bool` el reintento perdería los 57 s que nadie gastó. Así es un presupuesto de 60 s
    /// repartido entre las entradas que hagan falta.
    ///
    /// **Y es SEPARADA del reloj a propósito**: el aparcado del descarte hereda `restoreStartedAt`
    /// entero, que recorta también el tope duro. Aquí eso violaría el criterio del ticket —el dueño
    /// legítimo que reintenta con razón conserva su ventana COMPLETA de 600 s—, así que el estreno
    /// sigue dando reloj nuevo y lo único que no se renueva es la gracia.
    private(set) static var graceStartedAt: Date?


    /// Lo llama `WelcomeRestoreView` al pasar a `.searching`, que es el único estado en el que hay un
    /// import de CloudKit de verdad — `.wiped` y `.iCloudDisabled` no importan nada y encender ahí
    /// abriría la señal sin corpus que la justifique.
    ///
    /// **Estrena el reloj si no hay dueño, y ROTA el dueño siempre**, que son dos cosas distintas y
    /// conviene no mezclarlas:
    ///
    ///  · **La ventana apagada la enciende cualquier entrada** (`restoreStartedAt == nil`): es la
    ///    primera del proceso, o la que sigue a un flujo que terminó. Sin este término la señal no se
    ///    encendería nunca. **Lo que ya no decide es su instante** (2026-09-21,
    ///    `restore-session-window-has-no-reachable-ceiling`): si la puerta de descarte dejó un reloj
    ///    aparcado y sigue sirviendo, la entrada lo HEREDA en vez de estrenar `now`. Volver de esa
    ///    puerta sin haber borrado nada no es una entrada nueva —la puerta solo pregunta—, y darle
    ///    tope duro nuevo era el recorrido de tres toques que dejó al ticket anterior sin techo.
    ///  · **Una ventana HUÉRFANA solo la re-ancla una entrada con descarga real detrás**
    ///    (`currentFlow == nil` **Y** `hasLiveImportActivity`).
    ///    Re-anclar es lo que arregla `abandoned-restore-no-longer-clears-the-session-window-clock`:
    ///    quien entra, se arrepiente y vuelve 400 s después heredaba un reloj que no describía su
    ///    descarga, y su tope duro caducaba a media bajada con el guard cross-cuenta cerrándose sobre
    ///    el dueño legítimo.
    ///    **Y el testigo es lo que impide que re-anclar se vuelva un tope infinito**, que lo cazó una
    ///    lente de la review: sin él, entrar y salir de Restaurar renueva la ventana indefinidamente
    ///    —`isRestoringNow` mide desde este instante el tope duro; **la gracia dejó de contarse desde
    ///    aquí el 2026-09-22** (`restore-retry-reopens-the-session-window-every-90-seconds`): tiene su
    ///    propia ancla de proceso, así que este término ya no la renueva— y en un
    ///    teléfono con el corpus de otra persona eso mantiene abierta de par en par la puerta que el
    ///    guard existe para cerrar.
    ///    **Era `hasObservedImportActivity` hasta el 2026-09-21, y ése es un latch MONÓTONO**: una vez
    ///    visto un `.importEvent`, cualquier salir-y-volver estrenaba 600 s nuevos apoyándose en una
    ///    descarga que podía haber terminado veinte minutos antes. Hoy pregunta si sigue bajando algo
    ///    AHORA (`ICloudRestoreInProgressLogic.hasLiveImportActivity`), así que el ciclo solo renueva
    ///    mientras la descarga esté viva — **lo cual acota la exposición a la vida de esa descarga, no
    ///    a un número**; el techo con número tiene ticket propio y el porqué está en la cabecera.
    ///    Su modo de fallo es conservar el reloj viejo, o sea CERRAR ANTES.
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
    /// - Parameter hasLiveImportActivity: ¿sigue bajando algo AHORA?
    ///   (`ICloudRestoreInProgressLogic.hasLiveImportActivity`, con el estado del espejo y la fecha
    ///   del último `.importEvent` observado). **Se llamaba `hasObservedImportActivity` y el rename es
    ///   deliberado**: el significado cambió de «lo hubo alguna vez en este proceso» a «lo hay
    ///   ahora», y un parámetro con el nombre viejo habría dejado los call-sites en verde afirmando
    ///   una premisa que ya no es la suya.
    ///   **SIN valor por defecto a propósito**, misma familia que el `restoreInProgress: Bool` de
    ///   `CrossAccountEntryGuardLogic` y que el `init` `fileprivate` de `FlowToken`: un default sería
    ///   una constante, y las dos constantes posibles rompen algo —`false` no re-ancla nunca y
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
        hasLiveImportActivity: Bool
    ) -> FlowToken {
        // **El RESCATE del dueño en pantalla, y su alcance es lo que costó la review**
        // (`restore-session-window-has-no-reachable-ceiling`). Con el reloj caducado y el dueño
        // todavía vigente no se entraba ni al estreno (`restoreStartedAt != nil`) ni al re-ancla
        // (`currentFlow != nil`): los cinco botones de «volver a buscar» no podían resucitar la
        // ventana y el dueño legítimo se quedaba con el bloqueo sobre sus propios datos el resto del
        // proceso, con las filas entrando. Es el defecto que tumbó el techo de cadena, entrando por
        // la caducidad en vez de por un presupuesto.
        //
        // **Y va con `currentFlow != nil`, no con la caducidad a secas: ahí está TODO el cuidado.**
        // Mi primera versión trataba «ventana agotada» como «ventana apagada» para cualquiera, y eso
        // deshace `leaving-and-reentering-restore-renews-the-hard-cap`: el ciclo salir-volver, que
        // suelta la titularidad cada vuelta, pasaba a estrenar 600 s **sin necesitar descarga viva**,
        // que es exactamente lo que aquel ticket cerró. Lo cazó su propio test, en rojo.
        //
        // Quien SALIÓ tiene la rama de abajo, que le exige una descarga real detrás; quien sigue
        // dentro no tiene ninguna otra, y su gesto es explícito: pulsó «volver a buscar». Eso no le
        // pide el testigo del import a propósito — la población del caso es el restore grande cuyo
        // import pasa minutos sin emitir, que es justo donde el testigo contesta `false`.
        //
        // Y conceder aquí no extiende nada: una ventana agotada ya no abre el guard, así que esto es
        // estrenar, no renovar — lo mismo que hace cualquiera matando la app.
        let ownerIsStuckOnASpentWindow = currentFlow != nil && restoreStartedAt.map {
            ICloudRestoreInProgressLogic.windowHasExpired(restoreStartedAt: $0, now: now)
        } ?? false

        if restoreStartedAt == nil {
            // **ESTRENO — salvo que la puerta de descarte tenga un reloj en el bolsillo.**
            // `resumableParkedWindowStart` devuelve ese instante mientras siga sirviendo, y `nil`
            // cuando toca reloj nuevo; el aparcado se CONSUME aquí en los dos casos, porque un
            // aparcado que sobreviviera al estreno se lo comería también al reintento legítimo que
            // viene después.
            restoreStartedAt = ICloudRestoreInProgressLogic.resumableParkedWindowStart(
                parkedStartedAt: parkedStartedAt, now: now) ?? now
            parkedStartedAt = nil
        } else if currentFlow == nil && hasLiveImportActivity {
            // RE-ANCLA de una ventana huérfana. No mira el aparcado: cuando hay reloj vivo, no hay
            // nada aparcado —`noteRestoreDiscardRequested` apaga al aparcar— y este camino es el que
            // arregla `abandoned-restore-no-longer-clears-the-session-window-clock`.
            restoreStartedAt = now
        } else if ownerIsStuckOnASpentWindow {
            restoreStartedAt = now
        }
        // **El ancla de la GRACIA, y la pone la PRIMERA entrada del proceso**
        // (`restore-retry-reopens-the-session-window-every-90-seconds`, 2026-09-22). El `??` es lo que
        // la hace del proceso: una vez puesta, ninguna entrada posterior la mueve, y `noteRestoreFinished`
        // no la borra — que es lo que le quita al ciclo reintentar-reintentar sus 60 s por vuelta.
        // Va FUERA de las ramas para no depender de cuál corrió: las tres dejan `restoreStartedAt`
        // puesto, y en la de estreno el ancla nace pegada al reloj (heredado o `now`), que es lo que
        // hace que el recorrido de la puerta de descarte no cambie de comportamiento.
        graceStartedAt = graceStartedAt ?? restoreStartedAt
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
    ///
    /// **Quien llama es `WelcomeRestoreView` al desaparecer, y no la pantalla de progreso** (mudanza
    /// del 2026-09-21, `restore-timeout-closes-the-session-window-with-the-import-still-running`).
    /// Aquélla se desmonta también cuando solo cambia el `state` de arriba —a `.importIncomplete`, a
    /// `.found`—, o sea con la persona TODAVÍA dentro de Restaurar: soltar ahí deja la ventana huérfana
    /// y el reintento la re-ancla, porque `hasObservedImportActivity` es un latch monótono del proceso
    /// y una vez encendido lo está para siempre. El tope duro de 600 s pasaba a renovarse cada 90 s con
    /// solo pulsar «volver a buscar». El desmontaje de la pantalla de Restaurar sí significa «me fui».
    static func noteRestoreAbandoned(_ token: FlowToken) {
        guard currentFlow == token else { return }
        currentFlow = nil
    }

    /// **Esta entrada a Restaurar no puede restaurar nada**: tira el reloj aparcado, si lo hay.
    ///
    /// Lo llaman los dos `return` tempranos de `WelcomeRestoreView.startSearch()` —sin cuenta de
    /// iCloud, y tras un wipe—, que son los estados en los que la pantalla NO enciende la señal.
    ///
    /// **Existe porque el aparcado se quedaba VARADO ahí, y lo midió una lente de la review.** El
    /// recorrido: la puerta de descarte contesta sin iCloud, la persona vuelve a Restaurar y cae en
    /// `.iCloudDisabled` —que desde el 2026-09-20 ofrece reintentar—, enciende iCloud, y su
    /// «volver a buscar» **estrena heredando el reloj de hace minutos**. Esa descarga es NUEVA: sin
    /// cuenta no bajaba nada. Su tope duro caducaría a media bajada y el guard de frontera de cuenta
    /// se cerraría sobre el dueño legítimo, que es el daño entero de
    /// `abandoned-restore-no-longer-clears-the-session-window-clock`.
    ///
    /// **No toca la ventana ni la titularidad, y es deliberado**: si hay una viva, no es suya —esta
    /// entrada ni siquiera llegó a encender— y apagarla desde aquí sería el bug que
    /// `noteRestoreAbandoned` existe para no cometer. Lo único que declara es que el reloj guardado
    /// ya no describe nada.
    ///
    /// **Y desde el 2026-09-22 tira también el ancla de la gracia**
    /// (`restore-retry-reopens-the-session-window-every-90-seconds`), por la misma razón y para la
    /// misma persona: quien entra sin cuenta, la enciende y pulsa «volver a buscar» tiene una descarga
    /// NUEVA detrás, y hacerle heredar una gracia que se consumió antes de que hubiera cuenta le
    /// dejaría la ventana cerrada desde el primer instante. Es el recorrido que el ticket midió como
    /// «el dueño legítimo que reintenta con razón».
    ///
    /// **Y ese borrado solo cambia algo cuando el reloj TAMBIÉN está apagado** — lo midió una lente de
    /// la review y conviene tenerlo escrito, porque el recorrido gemelo existe: si la persona se fue de
    /// Restaurar sin que nadie apagara (`noteRestoreAbandoned`) la ventana sigue viva, y la entrada que
    /// venga después vuelve a derivar el ancla de ESE reloj. No es un olvido ni una fuga: con la
    /// ventana viva, la gracia contada desde su reloj es exactamente lo que describe ese tramo, y
    /// moverla sería darle margen nuevo a una ventana que nunca se cerró. Apagar el reloj desde aquí sí
    /// sería un bug — es lo que prohíbe el párrafo de arriba.
    ///
    /// No le da salida a nadie más: llegar aquí pide apagar iCloud —o un wipe— en Ajustes del sistema,
    /// más caro que matar la app, que ya es el baseline declarado de esta señal.
    static func noteRestoreUnavailable() {
        parkedStartedAt = nil
        graceStartedAt = nil
    }

    /// La persona **pidió empezar de cero**: apaga la ventana y APARCA su reloj.
    ///
    /// `restore-session-window-has-no-reachable-ceiling`, 2026-09-21. Lo llama el MONTAJE de
    /// `WelcomePrivateICloudGateView`, que hasta ese día era una llamada a `noteRestoreFinished`
    /// dentro de la confirmación del diálogo de Restaurar. Las dos mitades hacen falta y ninguna sola
    /// basta:
    ///
    /// **El apagado SUBIÓ DOS VECES, y la segunda es la que lo hace cierto.** El 2026-09-22 salió de la
    /// closure del botón destructivo a un punto único de `WelcomeRestoreView`
    /// (`wiped-state-reaches-the-discard-gate-with-the-window-open`), porque seis de los siete caminos
    /// confirman con diálogo y `.wiped` no —su búsqueda concluye por acto de la propia persona—. Ese
    /// mismo día subió otra vez, del gesto al DESTINO
    /// (`discard-gate-cannot-close-an-orphan-session-window`): la puerta tiene **tres**
    /// instanciaciones y solo una llega desde Restaurar; por «Soy nuevo» → «Privado» se llega sin
    /// pasar por esa pantalla siquiera. Lo que comparten los caminos no es el diálogo, ni el gesto: es
    /// la pantalla a la que llegan.
    ///
    ///  · **Apagar**, porque la persona acaba de declarar que descarta el import, y la premisa de la
    ///    que cuelga todo este diseño —«las filas siguen entrando y hay que protegerlas»— deja de
    ///    valer. Sin el apagado, la ventana sobrevivía a la puerta hasta diez minutos con el guard de
    ///    frontera de cuenta entornado; lo cazó una lente de la review del ticket anterior.
    ///  · **Aparcar**, porque **la puerta de descarte solo PREGUNTA: no ha borrado nada.** Sus dos
    ///    salidas de vuelta —«Volver» y «Traer mis datos»— devuelven a Restaurar con el mismo corpus y
    ///    la misma descarga que había antes, así que eso no es una entrada nueva y no merece un tope
    ///    duro nuevo. Con el apagado a secas, el estado quedaba indistinguible de «nadie ha pedido
    ///    restaurar en este proceso» y la vuelta estrenaba 600 s **sin esperar nada y sin que ninguna
    ///    descarga tuviera que estar viva**: tres toques, repetibles a voluntad, que es lo que dejó el
    ///    ticket anterior sin techo.
    ///
    /// **Lo que NO hace, y es deliberado: no bloquea.** El aparcado caduca con el mismo tope duro de la
    /// ventana (`ICloudRestoreInProgressLogic.resumableParkedWindowStart`), así que agotado ése la
    /// entrada siguiente ESTRENA con normalidad. Es la diferencia exacta con el techo de cadena que la
    /// review tumbó: aquél, una vez agotado, no dejaba ni re-anclar ni estrenar en el resto del
    /// proceso, y le devolvía al dueño legítimo el bloqueo sobre su propia cuenta.
    ///
    /// **NO pide titularidad, y ésa es la decisión del 2026-09-22**
    /// (`discard-gate-cannot-close-an-orphan-session-window`, decisión de Jürgen). Es el ÚNICO de los
    /// cinco verbos que puede apagar una ventana que no es de su intento, y el porqué es el del primer
    /// bullet llevado hasta el final: la premisa que protege a un import —«las filas siguen entrando»—
    /// la deroga quien declara que no las quiere, y esa declaración no distingue de qué intento son.
    /// Hasta ese día llevaba `guard currentFlow == token`, y el recorrido que dejaba abierto era éste:
    /// entra a Restaurar (dueño `T1`), el tope de 90 s se rinde con el import vivo, toca atrás
    /// —`noteRestoreAbandoned(T1)` deja la ventana **viva y HUÉRFANA**—, vuelve a entrar y su
    /// `startSearch()` sale por un `return` temprano sin encender nada. Ahí el descarte se caía por su
    /// propio `guard` y la ventana llegaba a la puerta viva hasta el tope duro de 600 s, con el guard
    /// de frontera de cuenta entornado.
    ///
    /// **Lo que aquel guard protegía es hoy inalcanzable por construcción**: quien llama es el montaje
    /// de `WelcomePrivateICloudGateView`, que no guarda ningún token, así que no existe la «pantalla
    /// vieja que confirma tarde» de la que hablaban sus dos hermanos. Ellos SÍ lo conservan, y no es
    /// incoherencia: a `noteRestoreAbandoned` y a `noteRestoreFinished` los llama una pantalla que sí
    /// tiene token, y ahí la distinción sigue siendo la red.
    ///
    /// **Y el invariante del ticket hermano sigue intacto**
    /// (`abandoned-restore-no-longer-clears-the-session-window-clock`): quien abandona Restaurar y
    /// vuelve **sin pasar por la puerta** conserva su ventana viva. Lo que apaga no es irse: es llegar
    /// a la pantalla que borra.
    ///
    /// **Aparca SOLO si hay reloj, y esa rama es alcanzable — no es una defensa «por si acaso».** Se
    /// llega a esta puerta sin haber pedido nunca restaurar («Soy nuevo» → «Privado»), y su `.onAppear`
    /// puede correr más de una vez sobre el mismo montaje. Con la asignación incondicional, la segunda
    /// pasada escribe `parkedStartedAt = nil` encima del reloj que la primera acababa de guardar, y la
    /// vuelta desde la puerta estrena 600 s enteros: el recorrido de tres toques de
    /// `restore-session-window-has-no-reachable-ceiling`, reabierto por el montaje.
    ///
    /// Y si el descarte se consuma, nadie limpia el aparcado a mano. **La primera versión decía que no
    /// hacía falta porque «desde el borrado no hay vuelta a Restaurar sin pasar por el onboarding», y
    /// eso es FALSO**: lo midió una lente de la review en la activación —borrar, llegar al onboarding,
    /// CANCELARLO (`FullModeActivationView.cancelActivation` deja el restore pendiente) y reabrir
    /// «Activar Yala completo» aterriza en `.restore` directo—. La razón de verdad es la otra mitad de
    /// aquella frase, que sí se sostiene sola: heredar un reloj más corto sobre un corpus que acaba de
    /// borrarse es el lado seguro de esta señal, y a los 600 s el aparcado deja de heredarse.
    static func noteRestoreDiscardRequested() {
        if let restoreStartedAt {
            parkedStartedAt = restoreStartedAt
        }
        restoreStartedAt = nil
        currentFlow = nil
    }

    /// El flujo de restauración TERMINÓ **por sus propios méritos y sin dejar descarga detrás**: en ese
    /// punto ya no hay nada que justifique tener abierto un guard de frontera de cuenta.
    ///
    /// **«Sin dejar descarga detrás» es la precisión del 2026-09-21**
    /// (`restore-timeout-closes-the-session-window-with-the-import-still-running`), y sustituye al
    /// «gane o pierda» de antes. Quién llega aquí lo decide
    /// `ICloudRestoreInProgressLogic.closesTheSessionWindow`: el import que asentó, y el tope agotado
    /// **sin un solo import observado**. El tope agotado habiendo visto un import NO llega — apagar
    /// ahí ponía `restoreStartedAt = nil` con las filas entrando, y `CrossAccountEntryGuardLogic`
    /// volvía a `.blockedForeignData` para el dueño legítimo, que es el bug entero por el eje del
    /// DESENLACE en vez del abandono.
    ///
    /// **Y su llamador es UNO: la espera de `RestoreProgressView`.** Durante unas horas del 2026-09-21
    /// tuvo un segundo —el botón de «Empezar desde cero»— y ése se mudó a
    /// `noteRestoreDiscardRequested`, que apaga igual pero APARCA el reloj
    /// (`restore-session-window-has-no-reachable-ceiling`). La diferencia no es de estilo: aquí
    /// «terminó» significa que no queda nada que proteger, mientras que detrás del botón de descarte
    /// hay una puerta que **solo pregunta**, y volver de ella sin haber borrado nada no puede valer un
    /// tope duro nuevo. Que este verbo tenga un solo llamador es además lo que devuelve sentido a su
    /// nombre: hoy ya no es alcanzable desde la UI con el import vivo.
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
        // **Y NO toca el aparcado, porque aquí no puede haber ninguno.** La primera versión lo
        // limpiaba «por si acaso» y la review midió que la línea era inalcanzable: aparcar apaga en el
        // mismo acto, y la única forma de volver a tener dueño —que es lo que exige el guard de
        // arriba— es pasar por el estreno, que lo consume. Peor que inútil: ENMASCARABA al mutante que
        // le quita el consumo al estreno, porque lo recogía aquí detrás. Quien añada un segundo
        // llamador del descarte tiene enfrente el escáner de unicidad de la suite, que es la red
        // correcta para eso.
        //
        // **Y NO toca el ancla de la GRACIA, y eso sí es una decisión**
        // (`restore-retry-reopens-the-session-window-every-90-seconds`, 2026-09-22). Este verbo es el
        // que cierra el ciclo barato: el tope de 90 s se rinde sin un solo `.importEvent`, aquí se
        // apaga, y el «volver a buscar» siguiente estrena reloj. Si el ancla se fuera con el reloj,
        // ese estreno compraría otros 60 s de gracia y el guard de frontera de cuenta se quedaría
        // abierto 60 s de cada 91 indefinidamente, con un toque por vuelta. Sobreviviéndole, el
        // estreno da tope duro nuevo —la ventana del dueño legítimo sigue entera— pero ya no da
        // gracia nueva.
    }

    /// El input del guard cross-cuenta. Se lee EN el instante de decidir y nunca se cachea: el mirror
    /// puede asentar entre que se monta la pantalla y que el usuario firma.
    static var isRestoringNow: Bool {
        ICloudRestoreInProgressLogic.isRestoringNow(
            restoreStartedAt: restoreStartedAt,
            graceStartedAt: graceStartedAt,
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
        parkedStartedAt = nil
        graceStartedAt = nil
    }
    #endif
}
