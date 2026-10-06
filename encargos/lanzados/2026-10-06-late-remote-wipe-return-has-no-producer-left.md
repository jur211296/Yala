# Retirar el mecanismo de devolución del vaciado tardío, que ya no tiene productor

## Contexto
Ticket `tickets/backlog/late-remote-wipe-return-has-no-producer-left.md` (léelo entero primero). Tarjeta del tablero `tablero-decidir-se-retira-el-mecanismo-del-vacia-txxa`.
Decisión de Jürgen del 2026-10-04: **A, retirarlo**. Desde el 28-sep el dispositivo que procesa tarde «Vaciar datos» solo borra lo que existía al vaciar (`RemoteWipeCutLogic`) y ya no declara nada al parque, así que `GroupsRemoteWipeReturn.declare` / `GroupsRemoteWipeReturnLogic.toDeclare` no tienen llamador en producción, y `GroupsRemoteWipeReturn.returnIfDeclared` se llama en cada arranque desde `AppBootstrapper.retryPendingBridges` leyendo un KV que ningún build escribe. Un mecanismo sin productor parece cubrir un caso que no cubre.
Acaba de entrar en cola de auto-merge el PR #376 (solo CI: el vigilante de la nocturna en `.github/workflows`). No depende de este encargo.

## Qué se pide
MODO AUTÓNOMO HASTA TERMINAR. Retirar el mecanismo entero, con la mejor práctica aunque tome más tiempo:
- Las dos piezas (`declare`/`toDeclare` y `returnIfDeclared`), la llamada del arranque, la key del KV (`GroupsRemoteWipeReturnStore.kvKey`) y la de `handled`, sus tests (incluido lo que entra por `legacyReceiverWipe` en `GroupsBridgeRestoreConvergenceTests.swift` si solo existe para esto) y sus dos entradas en `.claude/rules/swiftdata-cloudkit.md`.
- Antes de borrar, lista lo que hacía ADEMÁS de declarar y conserva ese orden: el arranque lo llama después de la convergencia y antes de la poda de borradores de liquidación (`pruneSettlementDraftsAlreadyResolved`); el source-scan `RemoteWipeSignalWiringTests.theBootPrunesSettlementDraftsAlreadyResolved` lo nombra y debe quedar verde y con sentido.
- Si una key de KV ya escrita por algún build pudiera quedar huérfana en un dispositivo, decide la limpieza sensata y anótala; no hace falta migración si ningún build publicado la escribió (el último publicado, 14, es del 23-sep).
- Mueve el ticket a done, actualiza `docs/TICKETS.md` y la tarjeta (`tablero mover ... --a done --agente frank`; es retiro sin cambio visible, no necesita device-QA salvo que encuentres lo contrario). Bugs o decisiones nuevas → ticket propio antes de cerrar.
- PR a `2.1` con auto-merge.

## Qué NO hay que tocar
- `RemoteWipeCutLogic` ni la convergencia de #284: siguen vivos.
- El resto de tickets de vaciado tardío (`late-remote-wipe-cut-keeps-what-it-cannot-date-until-the-mirror-decides` y los de qa) salvo que el retiro los cambie de verdad; si es así, anótalo en ellos.
- Workflows de `.github/` (PR #376 en cola).
- Pipeline serial de la Mini para build y tests: (1) limpiar simuladores muertos y basura, (2) build con `xcodebuild -jobs 2` sin simulador encendido, (3) boot de 1 solo simulador, (4) tests, (5) apagar y borrar los datos de ese simulador. Nunca solapar swift-frontend + SpringBoard + app + UITests. Un solo simulador.

## Gate después del CI del PR anterior
La sesión arranca ya, sobre `origin/2.1`. No se espera a que el PR anterior entre, y no se parte de la rama en auto-merge. Justo antes del gate, mirar si el PR anterior (#376) sigue en CI. Si sigue, esperar a que entre y rebasar una sola vez, con el simulador apagado. Si `2.1` no se movió, seguir de frente. Si ese CI falla, no esperar: rebasar con lo que haya y seguir. El build y el simulador van después de ese rebase, una sola vez.

## DerivedData y cachés
Al lanzar y al cerrar, borra sin preguntar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen. No toques los de otra sesión viva. Si el borrado falla, dilo en el cierre.

## Cómo se sabe que está bien
- No queda ningún símbolo, key ni regla del mecanismo en `Yala/`, tests ni `.claude/rules` (grep limpio), y el arranque mantiene el orden convergencia → poda de borradores.
- Build y tests unitarios verdes (los de UI son advisory).
- PR abierto a `2.1` con auto-merge, con lo retirado y lo conservado en el cuerpo.
- Cierra con `/cerrar-total` autónomo: Mini limpia (simulador apagado y borrado, sin DerivedData de la sesión, worktree retirado si ya no hace falta, tmux muerta).
