# Una transacción del chat puede quedar en una divisa distinta a la de su cuenta

## Contexto
Ticket: `tickets/backlog/chat-draft-stamps-its-own-currency-not-the-account.md` (medium).
Cola mediums (Jürgen 2026-09-08): goldens ✓ → chat contradict ✓ → **este** → sealed → FX ×3.

## Que se pide
AC del ticket. Board + `docs/TICKETS.md` al día.

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs/board, `docs/TICKETS.md`, merge y `/cerrar-total` sin preguntar. Bugs/decisiones nuevas → ticket propio. Solo parar ante decisión/acceso real de Jürgen (pregúntale en la sesión; Frank avisa).

## Cola siguiente (no la lances tú)
Tras /cerrar-total Frank lanza: `chat-rows-sealed-before-the-fix-have-no-repair-path`.

## Que NO hay que tocar
- marketing/, clinicas-dentales-bi.

## Como se sabe que esta bien
- AC del ticket; PR mergeado a 2.1; board + índice; `/cerrar-total`.

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL/key en fichero local, no en git) cuando:
  (1) decisión/acceso Jürgen; (2) PR abierto; (3) /cerrar-total con resumen de usuario; (4) sin siguiente paso — una vez.
NO avises por test rojo a reclasificar, build a reintentar, ni CI advisory.
