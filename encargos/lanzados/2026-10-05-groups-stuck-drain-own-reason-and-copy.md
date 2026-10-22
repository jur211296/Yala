# Grupos: con el drain atascado en un teléfono sano, cerrar sesión dice lo que de verdad pasa (opción A de Jürgen)

## Contexto
Ticket: `tickets/backlog/groups-stuck-drain-on-a-healthy-phone-says-try-again-later.md` (léelo entero; sale del review adversarial de la sesión `groups-drain-that-always-aborts-takes-the-loss-exit-away`, PR #360 ya mergeado a 2.1).

Si este teléfono no consigue preparar para subir un cambio de tus grupos —siempre, no una vez— y todo lo demás va bien (App Attest, sesión válida, el cambio es tuyo), cerrar sesión, desasociar o «Empezar de cero» dicen «Los últimos cambios de tus grupos no llegaron al servidor… inténtalo de nuevo en un rato». Esperar no lo cura. Hoy `CloudSignOutFlowLogic.stuckCaptureVerdict` devuelve `.uploadRetryLater` en ese caso. El gemelo personal ya tiene motivo y texto propios (`.personalCaptureUnfinished`, `settings.signOutCaptureUnfinished`).

Decisión de Jürgen (2026-10-05): **opción A**. Motivo propio `.groupsCaptureUnfinished` con este texto, dicho de tus grupos:
«Algunos de los últimos cambios de tus grupos no se pudieron preparar para subirlos. Siguen guardados en este teléfono y no se pierden. Cierra y vuelve a abrir Yala; si sigue pasando, actualízala.»
Las 16 locales, sin salida que pierda datos. Jürgen quiere siempre lo más robusto y la mejor práctica aunque tarde más.

Card del tablero: `tablero-grupos-texto-propio-cuando-el-drain-se-a-vns8` (ya la paso yo a in progress).

## Qué se pide
1. Motivo `.groupsCaptureUnfinished` y su texto en las 16 locales, siguiendo el molde del personal.
2. Que `stuckCaptureVerdict` lo devuelva en el caso descrito, en los tres caminos (cerrar sesión, desasociar, «Empezar de cero»).
3. Mira el pariente del ticket (desasociar con drain atascado y sesión caducada dice «tu sesión caducó»): si cabe en el mismo molde sin abrir otra decisión de producto, arréglalo; si abre una decisión, déjalo como ticket nuevo con propuestas A/B/C y recomendación.
4. Tests unitarios rojo primero, luego verde. Guion de device-QA en iPhone y ticket a `tickets/qa/`.

## Qué NO hay que tocar
- No reabrir la decisión A (ninguna salida pierde datos).
- No cambiar el texto ni la lógica del caso personal ni del `.uploadRetryLater` legítimo (subida que sí falló).
- Nada de marketing/.

## Pipeline Mini (obligatorio)
Pipeline serial: limpiar → build `xcodebuild -jobs 2` sin sim booteado → boot 1 sim → tests → apagar y vaciar el sim. Nunca solapar compilación con simulador o UITests. Un solo simulador.
DerivedData y cachés: al lanzar y al cerrar, borra sin preguntar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen (retirados o con PR mergeado). No toques los de un worktree vivo. Si el borrado falla, dilo en el cierre.
Gate después del CI del PR anterior: arranca ya sobre `origin/2.1`, sin esperar a que entre el PR anterior (#361, Estadísticas, en cola de auto-merge) ni partir de su rama. Justo antes del gate, mira si #361 sigue en CI. Si sigue, espera a que entre y rebasa una sola vez, con el simulador apagado. Si `2.1` no se movió, sigue de frente. Si ese CI falla, no esperes: rebasa con lo que haya y sigue. El build y el simulador van después de ese rebase, una sola vez.
Si el cambio se ve (un aviso nuevo en pantalla), deja capturas antes/después en la carpeta de capturas y lista las rutas en el resumen.

## Cómo se sabe que está bien
- Con el drain de Grupos atascado en un teléfono sano, ningún aviso promete que esperar lo cura; sale el texto de la opción A.
- Ninguna salida pierde datos.
- Tests verdes, gate verde, PR a 2.1 con auto-merge, ticket en `tickets/qa/` con guion.
- Al terminar, `/cerrar-total` autónomo, dejando la Mini limpia (sim apagado y vaciado, DerivedData de la sesión borrado, worktree retirado si procede).

## Paso 0

Modo: MODO AUTÓNOMO (encargo lanzado, cierre con `/cerrar-total` autónomo). Worktree ⇒ rama + PR con auto-merge.

Decisiones (auto-contestadas, ninguna es de producto: la A ya la tomó Jürgen):
1. **Motivo nuevo `.groupsCaptureUnfinished`, al final del `enum`** (no mover el orden). Slug `groups-capture-unfinished`.
2. **`stuckCaptureVerdict`**: la última rama (captura atascada y nada que abra la salida) pasa de `.uploadRetryLater` a
   `.groupsCaptureUnfinished`. Incluye el «no se pudo leer de quién es» (`nil`) y los ciclos que pararon por algo que no
   abre la salida (canal en pausa, subida fallida): el atasco del drain es lo que impide subir, y esperar no lo cura.
   Las ramas que abren salida (attest, sesión, otra cuenta) no cambian.
3. **No se toca** el `.uploadRetryLater` legítimo: `classify` (subida fallida), `lossBlockAfterRecapture` con captura
   `.unfinished`, `groupsCaptureVerdict`, `freshStartUncapturedReason`, `freshStartResidualReason`, el alert del shell.
4. **Tablas por motivo**: `lossCause` → `nil`; `freshStartOffersGroupsLossExit` → `false` (decisión A: sin salida);
   `GroupsSignOutRetryDecision` → `.surfacePermanent` (como hoy `.uploadRetryLater`; sin él caería en 45 s de reintentos);
   `cloudSignOutGroupsBlockReason` → tal cual (si no, «revisa tu conexión»); `personalPushAllShownReason` y
   `personalLossCause` → no lo reciben.
5. **Pantallas**: Ajustes (mismo alert que `.uploadRetryLater`), hoja del Apple ID y «Empezar de cero» (vía
   `SignOutBlockedCopy`), desasociar (`GroupsAssociationSection`, texto nuevo) y **puerta de Grupos del Welcome** — rama
   propia antes del catch-all, que diría «vuelve a entrar con esa cuenta».
6. **Copy**: key `groups.errors.captureUnfinished`, texto de Jürgen en `es`/`es-419`; variantes con su registro (es-ES
   «no se han podido», es-AR voseo) y el resto traducido con el molde de `settings.signOutCaptureUnfinished`.
7. **Pariente** (desasociar + drain atascado + sesión caducada → «tu sesión caducó»): elegir qué texto gana o combinarlos es
   una decisión de copy ⇒ ticket nuevo con A/B/C, sin tocar código.
8. Sin review adversarial multi-lente: el cambio es de motivo y copy, no de lógica de sync (la decisión del veredicto es una
   línea). Sí mutante sobre la línea del veredicto.
9. Capturas: el aviso no se puede provocar en el simulador sin un drain atascado real; antes/después se sacan con un test de
   UI si hay seam, si no se dice.
