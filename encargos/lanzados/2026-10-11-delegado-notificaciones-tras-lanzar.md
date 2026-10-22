# El delegado de notificaciones se asigna después de que la app termine de lanzarse

## Contexto
Card del tablero `tablero-el-delegado-de-notificaciones-se-asigna-bdxj` (Yala 2.1, medium). Hueco de la auditoría de entradas del PR #441: el `UNUserNotificationCenter.delegate` se asigna tarde (después de `didFinishLaunching`), así que tocar una notificación con la app cerrada puede perder la respuesta (`didReceive`) y no llevar a donde debía. Ticket: `tickets/backlog/notification-delegate-assigned-after-launch.md`. Lee `docs/entry-points.md` (actualizado por #441 y #453) y el PR #441 para respetar el orden de arranque y el buffer de entradas aplazadas (`EntryReadinessLogic`, `DeferredIntentBufferLogic`); el PR #453 añadió que el Panel no presenta encima de hojas de otra pestaña. Reutiliza esos mecanismos; no inventes otro.

## Qué se pide
- Test que falle antes y pase después: notificación tocada en arranque en frío ⇒ la entrada se recibe y se enruta (aplazada si el arranque no terminó).
- Asignar el delegado antes de que termine el lanzamiento, sin romper el orden de arranque ni el borrado de cierre de sesión armado.
- Actualizar `docs/entry-points.md`.
- Capturas antes/después solo si cambia algo visible (`capturas/antes.png`, `capturas/despues.png`; mira `~/Claude/referencias-ui/README.md`).

## Qué NO hay que tocar
- Contenido de notificaciones, permisos, push del servidor, nube/CloudKit, marketing/.
- Si encuentras otro hallazgo, crea card: `tablero crear --proyecto Yala --titulo "..." --version 2.1 --agente frank` (sin --fecha).

## Reglas de build y Mini (obligatorias)
- `nice -n 10 xcodebuild -jobs 2 ...`. Antes de cada build, esperar a que el load average (uptime) sea < 8.
- Nunca filtrar la salida del build con `| head`. `-only-testing` como array de argumentos (uno por target/test).
- Pipeline serial: limpiar → build sin sim booteado → boot 1 simulador → tests → apagar y erase de ese simulador. Un solo simulador a la vez; nunca build con sim booteado.
- DerivedData de esta sesión y cachés de XcodeBuildMCP de worktrees que ya no existen: bórralos al cerrar sin preguntar. No toques los de otra sesión viva.
- Gate tras el CI del PR anterior (#453): arranca ya sobre `origin/2.1`; no partas de su rama. Justo antes del gate, mira si #453 sigue en CI; si sigue, espera a que entre y rebasa una sola vez con el sim apagado; si 2.1 no se movió, sigue; si ese CI falla, no esperes: rebasa con lo que haya. Build y simulador van después de ese rebase, una sola vez.
- PR contra la rama `2.1`.

## Cómo se sabe que está bien
Tocar una notificación con la app cerrada lleva a su destino (test nuevo rojo antes / verde después); suites de entradas en verde; PR abierto a 2.1. Al terminar, `/cerrar-total` (sim apagado y borrado, Mini limpia).

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**Hechos medidos antes de decidir.** El `init` de `NotificationService` solo asigna el delegado (no lee nada del
arranque). Hoy el primer `NotificationService.shared` es el paso 1 de `AppBootstrapper.bootstrap` (en el `.task` de
`ContentView`), salvo con el borrado de cierre de sesión armado, que lo toca antes desde `PersonalContainerHost`
(dentro de `YalaApp.init`, antes de `didFinishLaunching`). `didReceive` ya entra por `RouterEntryGate.submit(.navigate)`,
que lo aplaza en `DeferredIntentBuffer` (en disco, 24 h) si el arranque no terminó, y el paso 20 lo drena justo después
de `isInitialized = true`, sin `await` en medio.

**D1 · ¿Dónde se asigna el delegado?** → En `YalaAppDelegate.application(_:didFinishLaunchingWithOptions:)`, antes del
`return true`. Por qué: es lo que pide Apple («antes de que termine el lanzamiento») y lo que propone el ticket.
Alternativa descartada: `willFinishLaunching` — vale igual, pero no gana nada y aleja el cambio del sitio que ya
documenta el arranque del delegado.

**D2 · ¿Un escritor o dos?** → Uno: `NotificationService.installAsCenterDelegate()`, que llama el app delegate. El
`init` deja de asignar y el paso 1 del arranque se retira (quedaría como un no-op con un comentario falso). Por qué: con
dos escritores el test no puede distinguir quién lo puso, y el `_ = shared` del arranque invitaría a creer que sigue
haciendo falta. Alternativa descartada: añadir el install y dejar el `init` y el paso 1 como estaban (más defensivo,
menos limpio).

**D3 · ¿Cambia el orden de arranque o el borrado armado?** → No. `didFinishLaunching` corre después de `YalaApp.init`,
así que el borrado de cierre de sesión armado (que construye el contenedor) sigue corriendo antes; solo usa
`cancelAllNotifications`/`clearDeliveredNotifications`, que no dependen del delegado. Un toque que llegue tras el
borrado se aplaza igual que hoy en caliente: el buffer se escribe DESPUÉS del borrado.

**D4 · ¿Cómo se prueba «toque en frío ⇒ se recibe y se enruta»?** → Un test de unidad que (1) deja el centro sin
delegado, (2) corre el `didFinishLaunching` real del app delegate, (3) comprueba que el delegado es `NotificationService`
(rojo antes del arreglo) y (4) entrega el toque por el cuerpo de `didReceive` con el arranque sin terminar: va al buffer
aplazado y, al drenarlo con el arranque listo, sale `.navigate(destino)`. El cuerpo de `didReceive` se extrae a una
función (`handleTap`) porque `UNNotificationResponse` no tiene inicializador público. Alternativa descartada: XCUITest
de toque real en SpringBoard con la app matada — lento y frágil; queda en el guion de device-QA.

**D5 · ¿Capturas?** → No: nada cambia en pantalla salvo llegar al destino, y eso no se puede provocar en simulador sin
SpringBoard. Device-QA en iPhone (guion en el PR).

**D6 · Hallazgos fuera de alcance** → card en el tablero, sin tocarlos (p. ej. `deepLink: "accounts"` ya tiene ticket).
