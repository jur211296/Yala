# Presupuesto de grupo (un límite por grupo)

## Contexto
Ticket: `tickets/backlog/groups-budget.md` (medium).

**Decisión Jürgen (2026-09-06) — no repreguntar:** un límite por grupo, no varios. Campos: `budgetLimitAmount` en la moneda del grupo (`currencyCode` ya existente). Grupos va por backend propio → esquema es DDL + RPCs pull/push + gateway (no CloudKit RecordType); el `/spec` lo comprueba.

Cola medium autónoma (Frank): tras /cerrar-total → fx-pnl-education-card → el-job-de-tests-del-ci-no-tiene-timeout.

## Que se pide
Implementar según ticket + decisión + AC. Board + `docs/TICKETS.md` al día. Device-QA documentado si aplica.

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs/board, `docs/TICKETS.md`, merge y `/cerrar-total` sin preguntar. Bugs/decisiones nuevas → ticket propio. Solo parar ante decisión/acceso real de Jürgen.

## Que NO hay que tocar
- marketing/, clinicas-dentales-bi.
- No multi-presupuesto / tabla nueva de presupuestos en V1.

## Como se sabe que esta bien
- AC del ticket; PR mergeado a 2.1; board + índice; `/cerrar-total`.

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL/key en fichero local, no en git) cuando:
  (1) decisión/acceso Jürgen; (2) PR abierto; (3) /cerrar-total con resumen de usuario; (4) sin siguiente paso — una vez.
NO avises por test rojo a reclasificar, build a reintentar, ni CI advisory.
