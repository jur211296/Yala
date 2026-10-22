# Resumen de grupo compartible/exportable (cierre del viaje)

## Contexto
Ticket: `tickets/backlog/groups-shareable-summary.md` (medium).

**Decisión Jürgen (2026-09-06) — no repreguntar:** todo el historial (`selectedPeriod = .allTime`), botón en Ajustes del grupo — no el período filtrado ni botón en Estadísticas.

Cola medium autónoma (Frank): tras /cerrar-total → groups-budget → fx-pnl-education-card → el-job-de-tests-del-ci-no-tiene-timeout.

## Que se pide
Implementar según ticket + AC: punto de entrada «Compartir resumen» (o similar) que genera imagen compartible con nombre del grupo, total gastado, desglose por miembro, lista mínima de pagos vía `DebtSimplificationService.simplify`. Board + `docs/TICKETS.md` al día.

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs/board, `docs/TICKETS.md`, merge y `/cerrar-total` sin preguntar. Bugs/decisiones nuevas → ticket propio. Solo parar ante decisión/acceso real de Jürgen.

## Que NO hay que tocar
- marketing/, clinicas-dentales-bi.
- No atar el resumen al período filtrado de Estadísticas.

## Como se sabe que esta bien
- AC del ticket; PR mergeado a 2.1; board + índice; `/cerrar-total`.

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL/key en fichero local, no en git) cuando:
  (1) decisión/acceso Jürgen; (2) PR abierto; (3) /cerrar-total con resumen de usuario; (4) sin siguiente paso — una vez.
NO avises por test rojo a reclasificar, build a reintentar, ni CI advisory.
