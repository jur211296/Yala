# Crear desde el chat guarda exchangeRate = 1.0 sin mirar la tasa

## Contexto
Ticket: `tickets/backlog/chat-assistant-plants-exchange-rate-one.md` (medium).

Hallazgo de camino en fx-manual-writes: la ruta del chat planta `exchangeRate: 1.0` literal; las otras seis rutas derivan la tasa del resultado. El bug de fecha ya se arregló en #94; esto queda.

Cola medium autónoma (Frank): tras /cerrar-total → bulk-update-account-leaves-converted-amount-stale → groups-archived-still-accepts-changes (si no pide decisión) → resto mediums. approximate-mark-ors y dead-end/DNS esperan Jürgen.

## Que se pide
AC del ticket: la ruta del chat derive/guarde la tasa efectiva como las otras; no dejar 1.0 cuando hay conversión real. Board + `docs/TICKETS.md` al día.

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
