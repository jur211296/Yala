# Las transacciones que el chat ya guardó con la tasa falsa no tienen quien las cure

## Contexto
Ticket: `tickets/backlog/chat-rows-sealed-before-the-fix-have-no-repair-path.md` (medium).
Cola mediums (Jürgen 2026-09-08): goldens ✓ → chat contradict ✓ → currency stamp ✓ (#107) → **este** → FX ×3.

Acaba de cerrar `chat-draft-stamps-its-own-currency-not-the-account` (PR #107). De camino salió high `changing-an-account-currency-orphans-its-whole-history` (decisión Jürgen; no lo lances).

## Que se pide
AC del ticket. Board + `docs/TICKETS.md` al día.

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs/board, `docs/TICKETS.md`, merge y `/cerrar-total` sin preguntar si corre el gate o el commit. Bugs/decisiones nuevas → ticket propio antes de cerrar (`--solo-crear` / fichero en tickets/). Solo parar ante decisión/acceso real de Jürgen (pregúntale en la sesión; Frank avisa).

## Cola siguiente (no la lances tú)
Tras /cerrar-total Frank lanza: `bulk-update-account-leaves-converted-amount-stale`.

## Que NO hay que tocar
- marketing/, clinicas-dentales-bi.
- No relanzar `changing-an-account-currency-orphans-its-whole-history` ni otras decisiones de producto.

## Como se sabe que esta bien
- AC del ticket; PR mergeado a 2.1; board + índice; `/cerrar-total`.

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL y key en fichero local, no en git; no las escribas en el repo) cuando:
  (1) necesitas una decisión de producto o de acceso de Jürgen;
  (2) abriste el PR o dejaste preview/artifact listo;
  (3) terminaste el ticket y vas a /cerrar-total — incluye en el aviso un resumen corto de cierre en lenguaje de usuario (qué se hizo), no solo «cerré»;
  (4) acabaste un tramo y no tienes siguiente paso claro (aunque no haya pregunta formal) — una vez, no en bucle.
NO avises por: un test rojo que vas a reclasificar, un build que vas a reintentar, ni ruido de CI advisory.
