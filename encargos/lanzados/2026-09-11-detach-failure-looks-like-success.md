# Implementar ticket: detach-failure-looks-like-success

## Contexto
Cola autónoma del rediseño de sesiones (bypass hasta terminar). Acaba de mergear a 2.1 el PR #143 (`groups-invite-on-a-mirrored-store-crosses-data`). Siguiente high de la cola de Frank: si «Desasociar» falla al borrar el dominio local, la UI dice que soltó la cuenta y no avisa — los grupos siguen enteros en el teléfono.

Quien arranca EN CONTEXTO LIMPIO: lee el ticket en `tickets/backlog/detach-failure-looks-like-success.md`, el patrón hermano del «Empiezo de cero» (`ShellDataAlertsModifier` + canario `freshStartWipeFailed`), y el paso 10 reciente (`detach-history-replay` / `CloudSessionSignOut.purgeGroupsDomainForDetach`) sin inventar.

## Que se pide
1. Que `purgeGroupsDomainForDetach` propague el fallo (o devuelva un veredicto) en vez de tragarlo.
2. Que `detachGroupsAccount` **no** haga `clear()` / marker / phase=.idle si el borrado falló: asociación y datos tienen que contar la misma historia. Decidir y documentar qué se ofrece tras el cierre de sesión en la nube (reintentar borrado vs rehacer asociación).
3. Aviso propio en la pantalla (molde «No pudimos soltar la cuenta») + canario de métricas.
4. Pruebas: seam UITest existente (`-uitest-fail-wipe` / `UITestHooks.shouldFailWipeNow`) o equivalente; unit del veredicto + XCUITest del aviso.
5. MODO AUTÓNOMO HASTA TERMINAR: gate, commit, board + **actualizar `docs/TICKETS.md`** (índice = disco, conteos), merge a 2.1 y `/cerrar-total` sin preguntar si corre el gate o el commit. Bugs/decisiones nuevas → ticket propio (`--solo-crear`) antes de cerrar. Solo parar ante decisión/acceso real de Jürgen.

## Que NO hay que tocar
marketing/. Wipe de producción. Paso 12/13 salvo mínimo imprescindible. No borrar corpus real del dispositivo de Jürgen.

## Como se sabe que esta bien
- Si el borrado falla, la UI lo dice y no finge éxito; la asociación no se limpia mientras los datos sigan.
- Tests del veredicto + aviso en rojo→verde locales; CI advisory de UI no bloquea merge (patrón flaky 2.1).
- Ticket a qa/ con criterios marcados; `docs/TICKETS.md` al día; PR mergeado a 2.1; `/cerrar-total`.

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL y key en fichero local, no en git; no las escribas en el repo) cuando:
  (1) necesitas una decisión de producto o de acceso de Jürgen;
  (2) abriste el PR o dejaste preview/artifact listo;
  (3) terminaste el ticket y vas a /cerrar-total — incluye en el aviso un resumen corto de cierre en lenguaje de usuario (qué se hizo), no solo «cerré»;
  (4) acabaste un tramo y no tienes siguiente paso claro (aunque no haya pregunta formal) — una vez, no en bucle.
NO avises por: un test rojo que vas a reclasificar, un build que vas a reintentar, ni ruido de CI advisory. URL/key solo en la Mini.
