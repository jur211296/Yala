# Cerrar sesión en la nube: un fallo de grupos transitorio ya no se vende como «revisa tu conexión»

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs/board, actualizar `docs/TICKETS.md` (índice al día), merge y `/cerrar-total` sin preguntar si corre el gate o el commit. Bugs/decisiones nuevas → ticket propio (`--solo-crear` / fichero en tickets/) antes de cerrar. Solo parar ante decisión/acceso real de Jürgen.

## Contexto
Cola autónoma overnight (bypass). Acaba de mergear a `2.1` el PR #155 (`restore-start-fresh-keeps-the-imported-corpus`). El ticket `cloud-signout-collapses-every-groups-transient-into-permanent` (high) salió de la review del #154: en `CloudSessionSignOut`, todo veredicto de grupos que no sea `.channelPaused` se colapsa a `.permanent`, así que un 403 de infra, un 5xx o una red caída salen todos como «revisa tu conexión» y sin el reintento de 45 s.

Frank (canal frente a Jürgen) ya eligió la **opción 2** para overnight: aviso inmediato y honesto sin gastar el presupuesto de 45 s (mismo criterio que `.channelPaused` el 2026-09-13). No reabrir esa decisión.

Ticket: `tickets/backlog/cloud-signout-collapses-every-groups-transient-into-permanent.md`

## Qué se pide
1. Leer el ticket y el código citado (`CloudSessionSignOut`, `GroupsSignOutRetryDecision`, el camino solo-grupos `attemptGroupsOnlyClose` como referencia de propagación correcta).
2. Implementar la **opción 2**: propagar el motivo transitorio con aviso inmediato honesto («no pudimos subir tus cambios ahora, inténtalo en un rato» o el copy que ya exista / encaje), **sin** gastar el presupuesto de reintento de 45 s.
3. No tocar el camino `.channelPaused` ni el kill deliberado del canal (#152).
4. Unit tests + mutantes que demuestren el cambio (no solo source-scan).
5. Review adversarial propia antes de abrir PR.
6. Abrir PR a `2.1`, esperar CI, mergear, `/cerrar-total` (board + `docs/TICKETS.md` al día).

## Qué NO hay que tocar
- `marketing/`
- El ticket hermano `activation-restore-start-fresh-keeps-the-imported-rows` (high nuevo del #155; tiene decisiones propias).
- `apple-id-change-should-close-the-private-session` (bloqueado a decisión de Jürgen: borrado silencioso vs confirmación).
- No inventar device-QA seam para 403 de infra si no existe.

## Cómo se sabe que está bien
- Cerrar sesión cloud con un fallo de grupos **transitorio** ya no muestra «revisa tu conexión» como si fuera permanente; muestra el aviso honesto inmediato y no quema 45 s de reintentos.
- `.channelPaused` sigue igual.
- Solo-grupos no regresa.
- PR mergeado a `2.1`, board e índice al día, `/cerrar-total`.

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL y key en fichero local, no en git; no las escribas en el repo) cuando:
  (1) necesitas una decisión de producto o de acceso de Jürgen;
  (2) abriste el PR o dejaste preview/artifact listo;
  (3) terminaste el ticket y vas a /cerrar-total — incluye en el aviso un resumen corto de cierre en lenguaje de usuario (qué se hizo), no solo «cerré»;
  (4) acabaste un tramo y no tienes siguiente paso claro (aunque no haya pregunta formal) — una vez, no en bucle.
NO avises por: un test rojo que vas a reclasificar, un build que vas a reintentar, ni ruido de CI advisory. URL/key solo en la Mini.
