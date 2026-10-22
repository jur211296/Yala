# Un gasto guardado desde el chat SUMA al saldo de la cuenta

## Contexto
Ticket: `tickets/backlog/chat-draft-drops-the-expense-sign.md` (high).

Hallazgo de camino en chat-assistant-plants-exchange-rate-one: `ChatAssistantViewModel.saveDraft` persiste el monto sin firmar; el saldo sube en vez de bajar.

Cola reactivada (Jürgen 2026-09-08): tras /cerrar-total → FX mediums (`bulk-update-account-leaves-converted-amount-stale`, `chat-rows-sealed-before-the-fix-have-no-repair-path`, …) → grupos.

## Que se pide
AC del ticket: firmar el monto al guardar (gasto resta); test que demuestre el fallo viejo y el arreglo; barrido de otras rutas del chat si aplica. Board + `docs/TICKETS.md` al día.

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs/board, `docs/TICKETS.md`, merge y `/cerrar-total` sin preguntar. Bugs/decisiones nuevas → ticket propio. Solo parar ante decisión/acceso real de Jürgen.

## Que NO hay que tocar
- marketing/, clinicas-dentales-bi.

## Como se sabe que esta bien
- AC del ticket; PR mergeado a 2.1; board + índice; `/cerrar-total`.

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL/key en fichero local, no en git) cuando:
  (1) decisión/acceso Jürgen; (2) PR abierto; (3) /cerrar-total con resumen de usuario; (4) sin siguiente paso — una vez.
NO avises por test rojo a reclasificar, build a reintentar, ni CI advisory.
