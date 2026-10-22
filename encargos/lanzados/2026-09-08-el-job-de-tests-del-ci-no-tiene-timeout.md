# Timeout del job tests del CI + UI a nocturna

## Contexto
Ticket: `tickets/backlog/el-job-de-tests-del-ci-no-tiene-timeout.md` (medium).

Decisión Jürgen (2026-09-06) — no repreguntar: la suite de UI pasa a una corrida nocturna; el PR corre build + unit con `timeout-minutes`. El tope del PR se elige por encima del percentil alto medido de build + unit, no a ojo. La nocturna corre sobre `2.1` y avisa si hay rojo (sin avisar en verde). Gate local ya corre XCUITest de áreas tocadas.

Motivo reciente: en fx-pnl (#92) Claude mergeó con el job `tests` colgado ~36 min sin timeout (gate local verde). Esto cierra ese agujero.

Último de la cola medium autónoma (Frank). Viene justo después del cierre de repair-queue (#98).

## Que se pide
Implementar según ticket + decisión. Medir percentil alto real de build+unit antes de fijar el número. Board + `docs/TICKETS.md` al día.

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs/board, actualizar `docs/TICKETS.md` (índice al día), merge y `/cerrar-total` sin preguntar si corre el gate o el commit. Bugs/decisiones nuevas → ticket propio antes de cerrar (`--solo-crear` / fichero en tickets/). Solo parar ante decisión o acceso real de Jürgen.

## Que NO hay que tocar
- marketing/, clinicas-dentales-bi.
- No meter la suite UI completa otra vez en cada PR.

## Como se sabe que esta bien
- AC / decisión del ticket; PR mergeado a 2.1; board + índice; `/cerrar-total`.

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL y key en fichero local, no en git; no las escribas en el repo) cuando:
  (1) necesitas una decisión de producto o de acceso de Jürgen;
  (2) abriste el PR o dejaste preview/artifact listo;
  (3) terminaste el ticket y vas a /cerrar-total — incluye en el aviso un resumen corto de cierre en lenguaje de usuario (qué se hizo), no solo «cerré»;
  (4) acabaste un tramo y no tienes siguiente paso claro (aunque no haya pregunta formal) — una vez, no en bucle.
NO avises por: un test rojo que vas a reclasificar, un build que vas a reintentar, ni ruido de CI advisory. URL/key solo en la Mini.
