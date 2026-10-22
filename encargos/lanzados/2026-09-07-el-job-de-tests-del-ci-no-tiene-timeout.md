# Timeout del job tests del CI + UI a nocturna

## Contexto
Ticket: `tickets/backlog/el-job-de-tests-del-ci-no-tiene-timeout.md` (medium).

**Decisión Jürgen (2026-09-06) — no repreguntar:** la suite de UI pasa a una corrida nocturna; el PR corre build + unit con `timeout-minutes`. El tope del PR se elige por encima del percentil alto medido de build + unit, no a ojo. La nocturna corre sobre `2.1` y avisa si hay rojo (sin avisar en verde). Gate local ya corre XCUITest de áreas tocadas.

Motivo reciente: en fx-pnl (#92) Claude mergeó con el job `tests` colgado ~36 min sin timeout (gate local verde). Esto cierra ese agujero.

Último de la cola medium autónoma (Frank).

## Que se pide
Implementar según ticket + decisión. Medir percentil alto real de build+unit antes de fijar el número. Board + `docs/TICKETS.md` al día.

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs/board, `docs/TICKETS.md`, merge y `/cerrar-total` sin preguntar. Bugs/decisiones nuevas → ticket propio. Solo parar ante decisión/acceso real de Jürgen.

## Que NO hay que tocar
- marketing/, clinicas-dentales-bi.
- No meter la suite UI completa otra vez en cada PR.

## Como se sabe que esta bien
- AC / decisión del ticket; PR mergeado a 2.1; board + índice; `/cerrar-total`.

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL/key en fichero local, no en git) cuando:
  (1) decisión/acceso Jürgen; (2) PR abierto; (3) /cerrar-total con resumen de usuario; (4) sin siguiente paso — una vez.
NO avises por test rojo a reclasificar, build a reintentar, ni CI advisory.
