# force-fetch-and-wait-ignores-cancellation — la espera del import de iCloud debe cancelarse al salir

## Contexto
Acaba de mergearse a 2.1 el PR #197 (restore-treats-budgets-and-groups-as-no-data). Este ticket es residual medium del pack de Restaurar / iCloud (Paso 0 y review de #196): `forceFetchAndWait` no observa cancelación y sigue vivo hasta 15s/90s con la pantalla ya cerrada.

Cola A serial autónoma (Frank): un ticket a la vez; este es el siguiente tras #197.

Hora Lima diurna (6:00–21:00): si necesitas decisión de producto o acceso de Jürgen, usa AskUserQuestion. Si no hace falta, sigue.

## Que se pide
Arregla `forceFetchAndWait` (y el camino de restore/import que lo usa) para que una cancelación del Task (salida de pantalla / dismiss) libere continuation, observer de NotificationCenter y sleep, sin dejar trabajo fantasma.

Lee el ticket en `tickets/backlog/force-fetch-and-wait-ignores-cancellation.md` y sigue su evidencia medida.

## Que NO hay que tocar
- marketing/
- Web/
- No reabrir el criterio de hasAnyData/grupos del #197 salvo regresión real
- No inventar copy de producto sin AskUserQuestion

## Como se sabe que esta bien
- Build Yala + Yala Dev sin warnings nuevos en ficheros tocados
- Unit/XCUITest del área verdes; mutantes del cambio muertos
- Ticket a qa (o done si no hay device-QA), `docs/TICKETS.md` al día
- PR mergeado a 2.1 y `/cerrar-total`

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs/board del repo, actualizar `docs/TICKETS.md`, merge y `/cerrar-total` sin preguntar si corre el gate o el commit. Bugs/decisiones nuevas → ticket propio (`--solo-crear`) antes de cerrar. Solo parar ante decisión/acceso real (AskUserQuestion de día). Board de proyectos Yala = tickets/ + docs/TICKETS.md (no inbox Tim).

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL y key en fichero local, no en git; no las escribas en el repo) cuando:
  (1) necesitas una decisión de producto o de acceso de Jürgen;
  (2) abriste el PR o dejaste preview/artifact listo;
  (3) terminaste el ticket y vas a /cerrar-total — incluye en el aviso un resumen corto de cierre en lenguaje de usuario (qué se hizo), no solo «cerré»;
  (4) acabaste un tramo y no tienes siguiente paso claro (aunque no haya pregunta formal) — una vez, no en bucle.
NO avises por: un test rojo que vas a reclasificar, un build que vas a reintentar, ni ruido de CI advisory. URL/key solo en la Mini.
