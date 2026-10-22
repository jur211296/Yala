# La vuelta a iCloud con una muestra ilegible corta con el techo corto (como la ida) y deja de decir «subiendo»

## Contexto
Ticket `tickets/backlog/reverse-upload-unreadable-sample-waits-the-long-ceiling.md` (léelo entero: trae el porqué medido en el código). Card del tablero `tablero-decidir-el-plazo-y-el-texto-de-la-vuelta-fdwb`.

Hoy, al pulsar «Volver a iCloud», si el teléfono no consigue leer una de sus tablas la muestra sale `ReverseUploadStatus.unreadable`, pero la espera de `reverseUpload` elige el presupuesto con `ReverseUploadBlocker`, que no tiene un motivo «avería de este dispositivo». Resultado: espera el plazo largo (hasta 72 h) con el texto de «subiendo», o al revés corta a los 15 min culpando a iCloud si CloudKit tiene un error vigente. Además, si la espera EMPIEZA ilegible, `MigrationRunner.observeReverseUploadWait` no guarda `lastReverseUploadSample` y la tarjeta pierde el motivo ya conocido (p. ej. `icloudOff`); el test `reverseUploadCeiling_unreadableFirstObservation_sealsClockButNoLowest` fija hoy ese comportamiento a propósito.

La ida ya resuelve esto con `SnapshotStallBlocker.localFailure` (techo corto, «este dispositivo no pudo preparar tus datos») y la fase previa al montaje de la vuelta con `ReversePreMountBlocker.localFailure`.

**Decisión de Jürgen del 2026-10-04: A.** Techo corto, igual que la ida, y un texto que no diga «subiendo» cuando la muestra no se puede leer.

Hoy se cerró el PR #377 (retiro de la devolución del vaciado tardío), en cola de auto-merge a 2.1 con el CI en curso. No depende de este encargo.

Para orientarte: `CLAUDE.md`, `.claude/rules/` que toquen (swiftdata-cloudkit, swiftui-ds), y los tickets relacionados que nombra el ticket (`an-incomplete-inventory-reads-as-the-whole-corpus`, `reverse-upload-has-no-ceiling-and-no-exit`, `reverse-upload-sample-reads-unreadable-rows-as-drained`).

## Que se pide
1. Un motivo «avería de este dispositivo» para la espera de la vuelta (el análogo de `localFailure` de la ida) que una muestra `.unreadable` elija con prioridad sobre las señales del canal iCloud: techo CORTO, el mismo que la ida, y que `icloudOff`/`unknown` no pausen ese reloj corto cuando la causa es la muestra ilegible.
2. El texto de la tarjeta mientras espera y al salir de vuelta al modo nube no dice «subiendo» en este caso. Calca el tono y la forma del texto de la ida («este dispositivo no pudo preparar tus datos») adaptado a la vuelta, en las localizaciones que tenga la app hoy. Si ves que hay dos o más textos razonables y la elección cambia lo que entiende la persona, para y propónselos a Jürgen (A/B/C con recomendación) antes de seguir.
3. Que la pantalla no pierda el motivo cuando la espera empieza ilegible (el ticket sugiere una muestra con la cifra opcional que conserve el motivo). Ajusta el test que hoy fija lo contrario.
4. Tests: una muestra ilegible elige ese plazo y ese texto, con control positivo (una muestra legible lenta sigue con el plazo largo y «subiendo»), y mutantes que lo cacen. Actualiza el ticket (criterios) y `qa/coverage-index.json` si el área está.
5. Capturas: si consigues mostrar la tarjeta en el simulador de forma fiable (por ejemplo, con un estado de preview/test existente), deja `capturas/antes.png` y `capturas/despues.png` en el worktree y lista las rutas absolutas en el cierre. Si no es reproducible a mano, dilo y deja el guion de device-QA en `tickets/qa/`.
6. Cierre: `/cerrar-total` autónomo (PR a 2.1 con auto-merge, limpieza). Al cerrar, mueve la card `tablero-decidir-el-plazo-y-el-texto-de-la-vuelta-fdwb` a «in qa» si queda device-QA para Jürgen o a «done» si no, con `tablero mover <id> --a "<estado>" --agente frank`.

## Que NO hay que tocar
- La ida (`SnapshotStallBlocker`) ni `ReversePreMountBlocker`: solo como referencia.
- Los plazos existentes de la vuelta para los motivos de iCloud (lento, sin cuenta, error de CloudKit) cuando la muestra SÍ se lee.
- Nada de marketing/ ni Web/.

## Pipeline de la Mini (serial, obligatorio)
1. Limpiar sims muertos, DerivedData de sesiones cerradas y cachés de XcodeBuildMCP de worktrees que ya no existen, sin preguntar. El disco anda justo (~32 GB libres).
2. Build con `xcodebuild -jobs 2` sin simulador booteado.
3. Boot de 1 solo simulador.
4. Tests.
5. Apagar y borrar ese simulador.
Prohibido solapar swift-frontend + SpringBoard + app + UITests.

Gate tras el CI del PR anterior: la sesión arranca ya sobre `origin/2.1`. Justo antes del gate, mira si el PR #377 sigue en CI. Si sigue, espera a que entre y rebasa una sola vez, con el simulador apagado. Si `2.1` no se movió, sigue de frente. Si ese CI falla, no esperes: rebasa con lo que haya y sigue. El build y el simulador van después de ese rebase, una sola vez.

DerivedData y cachés de XcodeBuildMCP: al lanzar y al cerrar, borra el DerivedData de esta sesión y las cachés de worktrees retirados o ya mergeados, sin pedir aprobación. No toques los de otra sesión viva. Si el borrado falla, dilo en el cierre.

## Como se sabe que esta bien
- Una muestra ilegible en la vuelta corta con el techo corto de la ida y la tarjeta no dice «subiendo»; una legible lenta sigue igual que hoy.
- La espera que empieza ilegible conserva el motivo en pantalla.
- Tests y mutantes verdes, controles sin mutante verdes; build `Yala` y `Yala Dev` verdes.
- PR a 2.1 en auto-merge, card del tablero movida, Mini limpia (sim apagado y borrado, sin DerivedData de la sesión).

## Paso 0

Decidido antes de escribir (auto-contestado, MODO AUTÓNOMO):

1. **Motivo nuevo `ReverseUploadBlocker.localFailure`** (rawValue `localFailure`, wire nuevo), `stallCause = .definitive`.
   Lo elige el RUNNER, no el executor: solo el runner sabe que la muestra salió `.unreadable`. Con muestra ilegible no
   se consulta el canal iCloud: la avería local manda sobre `icloudOff`/`unknown`/`icloudFull`/`icloudUnusable`.
2. **Techo corto = 900 s**, el de la ida (`snapshotCauseBudgetSeconds`) y el que ya usa la vuelta
   (`reverseUploadDefinitiveBudgetSeconds`). No hay constante nueva: entra en el reloj de «cualquier motivo
   definitivo» igual que `icloudFull`. Alternado con un motivo de iCloud → salida `stalled` (regla de los tres relojes).
3. **Motivo de salida nuevo `ReverseAbortReason.localFailure`** con texto propio. `stalled` no vale: dice «iCloud no
   recibió todos tus datos» y pide revisar iCloud y la conexión.
4. **Textos**: calco de la ida (`storage.failed.snapshotLocalFailure`) y de la forma de los vecinos de la vuelta. Un
   solo texto razonable → no se pregunta. **Revisado tras la review**: no se mide si el espejo sin cuenta crea sus tablas
   (el simulador sin cuenta monta neutro en la instalación fresca y medirlo pedía otro montaje); el encargo ya decide la
   prioridad sobre las señales de iCloud. Queda anotado como residual en `reverse-offered-on-a-device-without-icloud`.
5. **`ReverseUploadSample.pending` pasa a `Int?`**: la espera que empieza ilegible guarda muestra (`nil`, `.localFailure`).
   Con una cifra buena previa se conserva esa cifra (comportamiento de hoy).
6. **Capturas**: no hay estado de test que monte la espera de la vuelta en el simulador. Sin capturas; guion de
   device-QA en `tickets/qa/`.
7. Review adversarial: sí (sync/techo de la vuelta).
