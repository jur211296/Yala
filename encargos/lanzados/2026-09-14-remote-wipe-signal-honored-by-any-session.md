# La señal «vacía tus datos» solo la obedece una sesión privada del Apple ID

## Contexto
Ticket `tickets/backlog/remote-wipe-signal-honored-by-any-session.md` (high). El paso 9 ya cerró el lado EMISOR: la señal de vaciado solo sale de una sesión privada. Queda el RECEPTOR: hoy cualquier sesión del Apple ID (también `.cloud` / solo-grupos) obedece `lastWipeTimestamp` y se vacía — y en nube eso sube borrados a SU cuenta.

Cola autónoma overnight (Frank/Jürgen): tras merge de #156 (cloud-signout groups transient). Saltamos `activation-restore-start-fresh-keeps-the-imported-rows` y `apple-id-change-should-close-the-private-session` porque piden decisión de producto.

## Qué se pide
Implementar el ticket: solo una sesión PRIVADA obedece la señal de wipe remoto; una sesión en la nube (completa o solo grupos) la ignora y la marca como procesada. Preferir decisor puro (`RemoteWipeSignalDecider`) con tests del eje de sesión. Gate, review adversarial, PR a 2.1, merge y `/cerrar-total`.

## Qué NO hay que tocar
- marketing/
- clinicas
- No reinventar el emisor (ya cerrado en paso 9)
- No tocar tickets bloqueados a decisión (`apple-id-change-…`, `activation-restore-…`) salvo crear tickets nuevos de hallazgos

## Cómo se sabe que está bien
- Criterios del ticket: `.cloud`/solo-grupos no borran; privada sí; test del decisor puro
- Gate verde; review adversarial; board + `docs/TICKETS.md` al día
- Device-QA si aplica, con ticket en `tickets/qa/`

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs/board, actualizar `docs/TICKETS.md` (índice al día), merge y `/cerrar-total` sin preguntar si corre el gate o el commit. Bugs/decisiones nuevas → ticket propio (`--solo-crear` / fichero en tickets/) antes de cerrar. Solo parar ante decisión/acceso real de Jürgen.

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL y key en fichero local, no en git; no las escribas en el repo) cuando:
  (1) necesitas una decisión de producto o de acceso de Jürgen;
  (2) abriste el PR o dejaste preview/artifact listo;
  (3) terminaste el ticket y vas a /cerrar-total — incluye en el aviso un resumen corto de cierre en lenguaje de usuario (qué se hizo), no solo «cerré»;
  (4) acabaste un tramo y no tienes siguiente paso claro (aunque no haya pregunta formal) — una vez, no en bucle.
NO avises por: un test rojo que vas a reclasificar, un build que vas a reintentar, ni ruido de CI advisory. URL/key solo en la Mini.
