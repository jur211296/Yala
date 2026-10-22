# El runner de XCUITest muere tras el primer caso de cada suite

## Contexto
Ticket: `tickets/backlog/rojo-xcuitest-runner-muere-tras-el-primer-caso.md` (high).

Cola nocturna / autónomo (Jürgen 2026-09-07): tras cerrar unit-suite-nondeterministic-reds (#95). Orden: fx-manual ✓ → unit-suite ✓ → **este** → web DNS (prep); `groups-owner-debt-no-heir-dead-end` parado a decisión.

Distinto de `uitest-compara-fechas-sin-fijar-locale` (rojos de aserción): aquí **el runner se cae** tras el primer caso de cada suite («Restarting after unexpected exit…»), luego `Executed 0 tests` y «Failing tests» que nunca imprimieron fallo. El conjunto de nombres varía con el orden — no archivarlos. Hipótesis principal: memoria (no disco); disco >25 GB no bastó.

Quien arranca EN CONTEXTO LIMPIO: no ve nuestra conversación.

## Que se pide
1. Reproducir con memoria holgada (sin builds/simuladores compitiendo) y disco > 25 GB; separar las dos variables.
2. Si persiste: mirar `.xcresult` y `~/Library/Logs/DiagnosticReports` (el stdout no trae el motivo del unexpected exit).
3. Mientras dure: el paso 3 del `/gate` no da veredicto XCUITest — dejarlo escrito en el PR.
4. No confundir con uitest-compara-fechas ni con unit-suite (ya cerrado: el “baile” era el grep del log).

## Que NO hay que tocar
- marketing/
- clinicas-dentales-bi
- No “arreglar” aserciones de uitest-compara-fechas aquí
- No meter en Lista Negra nombres que solo aparecen por orden de muerte del runner

## Como se sabe que esta bien
- AC del ticket; evidencia de repro o de causa; PR mergeado a 2.1; board + `docs/TICKETS.md` al día; `/cerrar-total`.

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs/board, actualizar `docs/TICKETS.md` (índice al día), merge y `/cerrar-total` sin preguntar si corre el gate o el commit. Bugs/decisiones nuevas → ticket propio (`--solo-crear`) antes de cerrar. Solo parar ante decisión/acceso real de Jürgen.

Avisos al bot dueño (Frank): POSTea al webhook local de la Mini (URL y key en fichero local, no en git; no las escribas en el repo) cuando:
  (1) necesitas una decisión de producto o de acceso de Jürgen;
  (2) abriste el PR o dejaste preview/artifact listo;
  (3) terminaste el ticket y vas a /cerrar-total — incluye en el aviso un resumen corto de cierre en lenguaje de usuario (qué se hizo), no solo «cerré»;
  (4) acabaste un tramo y no tienes siguiente paso claro (aunque no haya pregunta formal) — una vez, no en bucle.
NO avises por: un test rojo que vas a reclasificar, un build que vas a reintentar, ni ruido de CI advisory. URL/key solo en la Mini.
