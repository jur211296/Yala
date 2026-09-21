---
id: force-fetch-and-wait-ignores-cancellation
status: qa
priority: medium
area: "icloud, sync, restore"
created: 2026-09-21
updated: 2026-09-21
source: "Paso 0 (D5) y review adversarial de `restore-back-and-reenter-closes-the-live-session-window`, 2026-09-21"
---

# La espera del import de iCloud no se entera de que la cancelaron

## El problema, en lenguaje de usuario

Salgo de una pantalla que está esperando a iCloud. Por debajo, esa espera sigue viva hasta minuto y
medio después: la app sigue contando mis movimientos cada seis décimas, con la pantalla ya cerrada
y yo en otro sitio. En un teléfono ocupado se nota.

## Medido (2026-09-21)

- `Yala/Services/iCloudSyncService.swift:545-571` — `forceFetchAndWait` resuelve su
  `withCheckedContinuation` solo por la notificación de CloudKit o por su `Task { sleep(timeout) }`
  interno: **no observa cancelación**. Un `Task` cancelado sigue clavado ahí hasta agotar el tope
  (15 s desde el arranque de la app, 90 s desde el restore), reteniendo un observer de
  `NotificationCenter` y un `Task` de sleep.
- `Yala/App/Views/Onboarding/RestoreProgressView.swift` — su `refresher` es un `Task {}` **no
  estructurado**, así que **no hereda la cancelación** de `runTask`: solo lo para el
  `refresher.cancel()` que va DESPUÉS de la espera. Con la vista desmontada sigue haciendo
  `modelContext.iCloudAccountSummary(...)` en el MainActor cada 0,6 s — unos 150 fetches sobre 5+
  entidades, escribiendo el `@State` de una vista muerta.

## Por qué NO se arregló en el ticket del que sale

Aquel ticket cerró el daño visible (un flujo abandonado ya no apaga la ventana de sesión de otro
vivo) con un token por intento, y además dejó de montar la espera en los caminos que no importan
nada. Lo que queda es coste, no corrupción. Y la primitiva la usa el ARRANQUE de la app
(`AppBootstrapper`, dos call-sites) además del restore y de `GroupsBridgeRestoreConvergence`: su
modo de fallo al reescribirla es **crash** (doble `resume` de una `CheckedContinuation`) o **cuelgue**
(ninguno), que es peor que el defecto. Merece su propio ciclo.

## Criterios de aceptación

- [x] Cancelar el `Task` que espera corta la espera, sin doble `resume` y sin dejarla sin resolver.
      El caso del `Task` YA cancelado al entrar cuenta.
- [x] El `refresher` de `RestoreProgressView` para cuando para su padre.
- [x] Los llamadores de `forceFetchAndWait` y de `waitForImportQuiescence` siguen comportándose igual
      cuando nadie cancela — `AppBootstrapper` (×2), `RestoreProgressView`, `ContentView` (×2),
      `GroupsBridgeRestoreConvergence`.
- [x] Un test que CUELGUE en vez de fallar es un rojo mal leído: el caso de la cancelación lleva tope.

## Relación con otros tickets

- `restore-back-and-reenter-closes-the-live-session-window` — de donde sale (Paso 0, D5).
- `restore-empty-state-resolution-cannot-be-cancelled` — el otro «la cancelación no cancela» de la
  misma pantalla, en otra función.

---

## Paso 0 — el árbol de decisiones, resuelto antes de escribir código (2026-09-21)

Todo lo de abajo está **medido en este árbol**, no inferido del ticket.

### D1 · Qué devuelve la espera cancelada: `false`, no `throws`

`forceFetchAndWait` sigue siendo `async -> Bool` y una cancelación la resuelve con `false`. Cambiar la
firma a `throws` obligaría a tocar los seis call-sites y rompería los cuatro tests de source-scan que
fijan el literal `await iCloudSyncService.shared.waitForImportQuiescence` (`RestoreStartFreshGateTests`,
`WelcomePrivateICloudGateTests` ×2, `FullModeActivationFlowLogicTests`). `false` ya significa «no
asentó», que es exactamente lo que pasa cuando la cancelan.

### D2 · El mecanismo: `withTaskCancellationHandler` + una caja de resolución única

Tres vías compiten por resolver la misma `CheckedContinuation` —la notificación de CloudKit, el tope y
ahora la cancelación— y un doble `resume` es un **crash**, no un test rojo. La carrera que lo produce no
es hipotética: `onCancel` puede correr **antes** de que `withCheckedContinuation` haya instalado la
continuation (y corre de inmediato si el `Task` ya venía cancelado). ⇒ una caja con `NSLock` que guarda
el valor pendiente cuando todavía no hay continuation, y la resuelve en cuanto se instala.

La caja se queda además con lo que hay que **soltar**: el observer de `NotificationCenter` y el `Task`
del tope. Hoy ese `Task` sobrevive al desenlace feliz: cuando la notificación llega a los 2 s, el sleep
de 15 s (o 90 s) sigue vivo hasta agotarse. Eso también es trabajo fantasma y se cierra aquí.

**Sin `if Task.isCancelled { return false }` de entrada**, a propósito: `withTaskCancellationHandler` ya
ejecuta `onCancel` inmediatamente en ese caso, así que ese término sería un cinturón sin rama propia —
un mutante que lo borrase **sobreviviría**, y un término que ningún test puede matar es un término que
sobra.

### D3 · El hallazgo que define el ticket: al cancelar, la pantalla de progreso NO debe apagar la ventana de sesión

`ICloudRestoreInProgressLogic` documenta sus cuatro caminos de cierre, y el segundo dice literalmente:

> 2. **El flujo TERMINÓ** (`noteRestoreFinished`, gane o pierda) — precisión, no red: el usuario que
>    toca «atrás» a mitad **cancela ese `Task` y este camino no corre**.

Esa frase es **falsa hoy**: como la espera no observa cancelación, el flujo abandonado despierta al
minuto y medio y sí corre. Y el docblock de `ICloudRestoreSessionSignal` dice lo mismo por el otro lado
(«**Y no se apaga al volver atrás.** Salir de la pantalla de restaurar no para el import: CloudKit sigue
bajando filas. Apagarla ahí dejaría el bug intacto, porque "tocar atrás" ES el escenario»).

⇒ arreglar la cancelación **sin tocar el orden** haría que `noteRestoreFinished` corriese al tocar
atrás, que es justo lo que el diseño prohíbe: el import sigue bajando, y cerrar la ventana ahí le
devuelve al dueño legítimo el bloqueo cross-cuenta sobre su propia cuenta. **El arreglo de la
cancelación mueve el apagado detrás del `guard !Task.isCancelled`**, y con eso la implementación por
fin hace lo que sus dos docblocks ya afirmaban.

Lo que se pierde es precisión, y está acotado por la propia lógica pura: quien toca atrás y no vuelve
deja la ventana a cargo de los caminos (3) —el import asentó— y (4) —sin actividad pasada la gracia de
60 s, y el tope duro de 600 s pase lo que pase. El tramo largo cubre «import activo y lento», que es
exactamente el caso en que la ventana **debe** estar abierta — **y también «el import falló y no va a
volver»**, porque `hasObservedImportActivity` se enciende antes del `if let error`. Lo refutó la review;
se acepta porque el tope duro cierra igual.

El test `ICloudRestoreSignalTests.theProgressViewClosesTheWindowWhenTheFlowEnds` fija hoy el orden
contrario y se reescribe con la razón nueva. El token por intento del #196 **no se reabre**: sigue
siendo la red cuando el apagado sí corre.

### D4 · El `refresher` no espera al vecino

Es un `Task {}` no estructurado: no hereda la cancelación de `runTask`. Con D2 la espera devuelve pronto
y el `refresher.cancel()` de después llegaría pronto también — pero eso es el tramo de uno cumplido por
el vecino. Se le pasa la cancelación **por su propia vía**, con el `onCancel` de un
`withTaskCancellationHandler` que envuelve el cuerpo.

### D5 · El bucle caliente de `awaitPersonalImportForBootSave`, dentro del alcance

`AppBootstrapper.awaitPersonalImportForBootSave` llama a `forceFetchAndWait(15)` y luego **poll a 2 s
con `try? await Task.sleep`, sin guard de cancelación**: sobre un `Task` cancelado ese sleep vuelve al
instante y el bucle gira en caliente hasta el tope de 120 s. Su hermano de la misma función —la rama
`.cloudEngine` de `awaitPersonalStoreReady`— ya lo cierra, con el comentario «NO busy-spinear el resto
del cap». Mi arreglo **alcanza antes** ese bucle (hoy el paso 1 lo retrasa 15 s), así que arreglarlo no
es alcance de más: es no empeorar al vecino. Se espeja la rama que ya lo hace bien.

### D6 · Los dos call-sites de `ContentView` conservan su motivo `cancelled`

`performICloudCorpusWipe` y `performDeviceCorpusWipe` hacen
`guard await waitForImportQuiescence(30) else { return "importNotQuiescent" }` y **justo después** un
`guard !Task.isCancelled else { return "cancelled" }`. Con D2, una cancelación saldría por el primero y
el motivo que se le enseña al usuario pasaría a ser `importNotQuiescent` — una mentira nueva, causada
por mí, en un camino que el ticket no me pide cambiar. Se reordena para que el chequeo de cancelación
gane al motivo. Es el AC nº3 («los llamadores siguen comportándose igual»), no alcance extra.

`GroupsBridgeRestoreConvergence` no necesita nada: difiere igual en los dos casos y su log ya dice
`importNotQuiescent`.

### D7 · Un test de cancelación lleva su tope DENTRO del SUT

Nada de esperas artificiales en el test (regla de `.claude/rules/testing.md`: `Task.sleep` > 0,5 s está
prohibido). El tope lo pone el `timeout:` que se le pasa al SUT: si el arreglo regresa, el test tarda
ese tope y **falla por duración**, no cuelga.

### Ficheros que se tocan (9 + docs) — más de 3, se listan por la regla de control de ejecución

| Fichero | Qué cambia |
|---|---|
| `Yala/Services/iCloudSyncService.swift` | la caja de resolución única + `withTaskCancellationHandler` en `forceFetchAndWait` (D1, D2) |
| `Yala/App/Views/Onboarding/RestoreProgressView.swift` | el apagado detrás del guard de cancelación (D3) + el refresher con su propia vía (D4) |
| `Yala/App/AppBootstrapper.swift` | el poll deja de girar en caliente sobre un `Task` cancelado (D5) |
| `Yala/App/ContentView.swift` | ×2: el chequeo de cancelación gana al motivo (D6) |
| `Yala/Services/CloudSync/ICloudRestoreSessionSignal.swift` | prosa: «clavado en el tope, que no observa cancelación» caducó |
| `Yala/App/Logic/ICloudRestoreInProgressLogic.swift` | prosa: su camino (2) pasa de aspiración a verdad |
| `Yala/App/Views/Onboarding/WelcomeRestoreView.swift` | prosa: el motivo de la puerta `if let flowToken` ya no es la falta de cancelación |
| `YalaTests/iCloudSyncServiceTests.swift` | los casos de cancelación (mid-flight y ya-cancelado) con tope |
| `YalaTests/CloudSync/ICloudRestoreSignalTests.swift` | el orden del apagado, reescrito con la razón de D3 |

---

## Lo que se hizo (2026-09-21)

### En lenguaje de usuario

**Salgo de la pantalla que está esperando a iCloud y la espera se para de verdad.** Antes seguía viva
por debajo hasta minuto y medio: la app seguía contando mis movimientos cada seis décimas con la
pantalla ya cerrada, y en un teléfono ocupado se notaba. Ahora, al salir, se para la espera y se para
el contador.

**Y salir ya no cierra la ventana que protege mi entrada a mi propia cuenta.** Ésta es la mitad que no
estaba en el ticket y que decide el arreglo: mientras iCloud baja mis datos, la app mantiene abierto un
permiso para que pueda entrar a mi cuenta sin que el guard de frontera me tome por otra persona. Ese
permiso se apagaba «cuando el flujo termina», y hasta hoy tocar atrás no terminaba nada —la espera
seguía clavada— así que nunca se apagaba antes de tiempo. Al hacer que la cancelación corte de verdad,
apagarlo ahí habría sido cerrarme la puerta con la descarga a medias. Ahora el apagado solo ocurre
cuando la espera termina por sus propios méritos.

### Por dentro

| Qué | Dónde |
|---|---|
| La espera se envuelve en `withTaskCancellationHandler` y resuelve por una caja con `NSLock` (`ForceFetchWaitBox`) que garantiza **una sola** resolución entre las tres vías que compiten y suelta el observer y el `Task` del tope | `Yala/Services/iCloudSyncService.swift` |
| El apagado de la ventana de sesión pasa **detrás** del `guard !Task.isCancelled`; el refresher gana handle propio y se apaga en el mismo `onDisappear` que la espera | `Yala/App/Views/Onboarding/RestoreProgressView.swift` |
| El poll de boot-save deja de girar **en caliente** sobre un `Task` cancelado (espeja la rama `.cloudEngine` de su hermana) | `Yala/App/AppBootstrapper.swift` |
| Los dos borrados conservan su motivo `cancelled` en vez de pasar a decir `importNotQuiescent` | `Yala/App/ContentView.swift` |
| Prosa caducada: tres docblocks afirmaban «`forceFetchAndWait` no observa cancelación» | `ICloudRestoreSessionSignal`, `ICloudRestoreInProgressLogic`, `WelcomeRestoreView` |

**El `Task` del tope se cancela al resolver, y eso cierra un fantasma que nadie había contado**: hasta
hoy, una espera resuelta por la notificación a los 2 s dejaba su sleep de 15 s —o de 90— durmiendo
detrás con todo lo que retiene.

### Lo que enseñaron los mutantes, y es la parte que vale

- **El tope de un test de cancelación NO puede ser el del SUT.** La primera versión de los casos se
  apoyaba en que, si el arreglo regresaba, la espera se resolvería por su propio tope y el caso fallaría
  por duración. Es falso para el modo de fallo que más importa: si `arm(...)` deja de cobrar el valor
  pendiente, la caja queda resuelta con la continuation dentro y **nadie vuelve a resolverla** — la
  espera no termina nunca y el caso **CUELGA**. Los cuatro casos llevan ahora tope propio.
- **Un mutante que sobrevive puede estar señalando un término que sobra o un test que falta.** Quitar el
  `guard` de resolución única sobrevivía a la suite entera, porque el doble `resume` lo tapaba por
  casualidad el `continuation = nil` de la línea de al lado. La respuesta no era borrar el guard: era que
  los tres pasos de la caja —soltar el observer, cancelar el tope, resolver una vez— no tenían red de
  comportamiento. La caja dejó de ser `private` y tiene suite propia (`ForceFetchWaitBoxTests`).
- **Por el mismo criterio, un `if Task.isCancelled` de entrada se quedó FUERA**: `withTaskCancellationHandler`
  ya corre su `onCancel` de inmediato en ese caso, así que ningún mutante podría matarlo.

### Validación

- Build `Yala` sin warnings nuevos en ficheros tocados (el primero introdujo uno —la caja nacía aislada
  al MainActor por `SWIFT_DEFAULT_ACTOR_ISOLATION`— y se cerró con `nonisolated` explícito).
- Unit verdes en las cuatro suites del área.
- Mutantes: `onCancel` vacío (3 casos en rojo), `arm` sin cobrar el pendiente (1), sin `guard` de
  resolución única (1), sin soltar observer ni tope, y los cuatro del cableado.

### Residuales declarados

- **`onDisappear` es la única vía de cancelación de la pantalla.** Si SwiftUI lo dispara sin desmontaje
  real, la espera se corta y la pantalla se queda en `.searching`. Hoy `RestoreProgressView` vive dentro
  de un `switch` en un `ZStack` y no se navega desde ella, así que el riesgo es el mismo que ya tenía
  `runTask`; lo que cambia es que ahora la espera **hace caso**.
- **La precisión del apagado se pierde a propósito** (D3): quien toca atrás y no vuelve deja la ventana
  a cargo de la lógica pura. No hay ticket porque no es un defecto: es la decisión.


---

## La review adversarial (tres lentes, 2026-09-21)

**Los siete hallazgos son MÍOS.** Ninguno venía del código previo.

### Lo que cambió el código

1. **`refreshTask?.cancel()` podía matar el refresher de OTRA generación de la vista.** Estaba delante
   del `guard !Task.isCancelled`, y `refreshTask` es un `@State`, o sea una caja **compartida** entre
   montajes. Un `runTask` cancelado que despierta después de que la pantalla se haya vuelto a montar
   leía de esa caja el handle del intento **vivo** y lo apagaba, dejando los conteos congelados. Detrás
   del guard no puede pasar: en el camino cancelado el refresher propio ya lo apagó el `onDisappear`,
   que es el único sitio del fichero que cancela `runTask` — así que uno cancelado implica el otro, y
   ese `cancel()` ahí solo podía acertarle al vecino.
2. **`startFlow()` pisaba los handles previos sin cancelarlos.** Un `Task` pisado queda vivo y sin
   dueño. El código anterior era inmune por accidente: el refresher vivía dentro de `runTask` y se
   recreaba con él.

### Lo que cambió los tests, y es la mitad que más enseña

3. **Mi source-scan del poll de arranque era VACUO.** Sus cuatro pasos —`do {`,
   `try await Task.sleep(...)`, `} catch {`, `return false`— son **byte-idénticos** a los de la rama
   hermana `.cloudEngine` de `awaitPersonalStoreReady`, que vive más abajo en el mismo fichero. Como la
   búsqueda avanza hacia adelante, casaban allí: **los cuatro mutantes del poll sobrevivían, incluido
   el que el propio test dice cazar**. Medido reproduciendo el helper y mutando el fuente. El arreglo
   es acotar `code()` a un tramo (`entre:` / `y:`), y con él los tres mutantes se ponen rojos.
   ⇒ **es el patrón «el tramo sin acotar lo cumple el vecino», repetido tal cual.**
4. **Tres mutantes COLGABAN `ForceFetchWaitBoxTests` en vez de ponerlo rojo.** Sus casos hacen
   `await withCheckedContinuation` sin tope, y los mutantes que dejan la caja resuelta con la
   continuation dentro no la resuelven nunca. Es la misma regla que me obligó a dar tope propio a los
   casos del servicio, sin aplicar en el fichero donde vive el modo de fallo. Cerrado con
   `.timeLimit(.minutes(1))` en la suite.
5. **El scan que CUENTA se ponía rojo con un `// comentario` al final de una línea escaneada** — rojo
   sin que producción cambiara. `code()` recorta ahora la cola `//…`, como pide la regla L167.
6. **`forceFetchAndWait_cancellingAfterTheNotificationIsHarmless` era un duplicado**: su `cancel()`
   corría sobre un `Task` ya terminado (no-op), y sin esa línea el caso era idéntico a
   `forceFetchAndWait_returnsTrueWhenNotificationFires`. Borrado.
7. **El `removeObserver` de la rama `pendingValue` de `arm(...)` solo lo cazaba el scan.** Ahora
   `resolvingBeforeArmingIsHonouredOnArm` cuenta avisos, como su hermano.

### Y un hallazgo que NO se arregla aquí

**El flujo abandonado ya no libera el reloj de la ventana de sesión**, y eso es una consecuencia real
de D3 que este ticket no vio. Hasta hoy, el abandonado despertaba a los 90 s y `noteRestoreFinished`
ponía `restoreStartedAt = nil`, así que una entrada posterior estrenaba ventana. Ahora la hereda: quien
abandona y vuelve a los 400 s tiene ventana hasta t0+600, no hasta t+600, y si su import tarda más, el
tope duro caduca a medias y `CrossAccountEntryGuardLogic` le dice al **dueño legítimo** que los datos
son de otra persona.

Arreglarlo pide separar el reloj del dueño y romper el invariante
`restoreStartedAt == nil ⇔ currentFlow == nil`, que hoy tiene test propio: es rediseño de la señal,
otro eje. ⇒ ticket propio: `abandoned-restore-no-longer-clears-the-session-window-clock`.

### Residuales que la review dejó dichos y NO se tocan

- `GroupsBridgeRestoreConvergence` es el único llamador sin `guard !Task.isCancelled` tras la espera, y
  `waitForImportQuiescence` puede devolver `true` sobre un `Task` cancelado. Hoy es **inalcanzable**: su
  `Task` no tiene cancelador. Pre-existente.
- Los ~8 boot-tasks escriben `"import not quiescent"` en su breadcrumb también cuando el motivo fue una
  cancelación — la misma mentira que `ContentView` sí corrige. Inalcanzable por la misma razón: ninguno
  de los tres `.cancel()` del fichero alcanza a `awaitPersonalStoreReady`.
- `forceFetchAndWait` devuelve **`true`** a un `Task` cancelado si `hasCompletedFirstImport` ya era
  cierto: los dos early-returns van antes del envoltorio. La respuesta es correcta de hecho.
