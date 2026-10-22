# Recordatorio amable de liquidación pendiente (nudge al deudor)

## Contexto
Ticket: `tickets/backlog/groups-settlement-reminder.md` (medium).

**Decisión Jürgen (2026-09-06) — no repreguntar:** al deudor, tono suave («te recordamos que le debes X a Ana»), amable nunca cobrador; puede acompañar banner en el grupo, pero el pedido es nudge que llega sin abrir la app.

Cola medium autónoma (Frank): tras /cerrar-total → groups-shareable-summary → groups-budget → fx-pnl-education-card → el-job-de-tests-del-ci-no-tiene-timeout.

## Que se pide
Implementar según ticket + decisión + AC del fichero. Copy revisado contra BRAND-VOICE.md; 16 `.lproj` si hay strings. Board + `docs/TICKETS.md` al día. Device-QA documentado si aplica.

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs/board, `docs/TICKETS.md`, merge y `/cerrar-total` sin preguntar. Bugs/decisiones nuevas → ticket propio. Solo parar ante decisión/acceso real de Jürgen.

## Que NO hay que tocar
- marketing/, clinicas-dentales-bi.
- No push al acreedor como destinatario principal.
- No tono cobrador.

## Como se sabe que esta bien
- AC del ticket; PR mergeado a 2.1; board + índice; `/cerrar-total`.

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL/key en fichero local, no en git) cuando:
  (1) decisión/acceso Jürgen; (2) PR abierto; (3) /cerrar-total con resumen de usuario; (4) sin siguiente paso — una vez.
NO avises por test rojo a reclasificar, build a reintentar, ni CI advisory.
