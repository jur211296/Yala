# Zajar decisiones de producto en tickets blocked/backlog y dejarlos listos para la cola autónoma

## Contexto
Cola nocturna de Yala (Frank) parada en varios tickets porque falta decisión de Jürgen, no código. Sesión hermana viva: `distribution-balance-kpi-skips-fx` / PR #78 — su CI (tests) aún puede estar corriendo o a punto de mergear. Esta sesión es SOLO docs/tickets. Jürgen está disponible para responder las dudas aquí.

Quien arranca: contexto limpio. No inventes decisiones; pregúntale a Jürgen una a una (o en un paquete corto) y escribe SU respuesta en el ticket.

## Que se pide
1. Recorre estos tickets (lee el fichero entero antes de preguntar):
   - `tickets/blocked/hero-estadisticas-stock-vs-flujo-entre-pestanas.md` (puede estar solo en el worktree de Balance si aún no mergeó; si no está en este árbol, créalo con el mismo id cuando toque o cópialo del worktree hermano tras merge — no pises #78).
   - `tickets/backlog/groups-pending-member-can-open-group.md` (high) — puerta cerrada vs sala de espera explicada.
   - `tickets/backlog/reentry-killswitch-closes-both-doors.md` — 2ª puerta bajo kill; motor en sesión en re-entrada.
2. Por cada uno: resume en 3-5 líneas la tensión, ofrece las opciones ya escritas en el ticket (no inventes otras salvo hueco obvio), pide la decisión a Jürgen, y deja escrita en el ticket:
   - sección `## Decisión Jürgen (YYYY-MM-DD)` con la opción elegida y el porqué en sus palabras;
   - actualiza status/priority/AC según corresponda (p.ej. blocked→backlog/ready, o backlog con AC desbloqueado);
   - flag claro si aún falta algo (device-QA, etc.).
3. NO trates como decisión de producto (solo menciónalos al final como «siguen blocked por device»):
   - `tickets/blocked/apppreferences-rewritten-on-launch.md`
   - `tickets/blocked/groups-join-intent-reconciler.md`
4. Actualiza `docs/TICKETS.md` para que índice = disco.
5. Si de camino ves otro ticket backlog/blocked con «necesita decisión de producto» explícita y desbloquea lanzamiento, inclúyelo en la misma pasada (máximo 2 extra; no barreas todo el backlog).

## MODO DE ESTA SESIÓN (docs + gate de CI hermana)
- Trabaja en worktree propio. Puedes editar tickets y docs libremente en disco.
- **PROHIBIDO commit, push, abrir PR o /cerrar-total mientras el CI de PR #78 (jur211296/Yala) no haya terminado** (checks no pendientes). Si está verde o el PR ya mergeó, entonces sí: un solo commit docs, push, PR docs-only, merge si el gate lo permite, board + TICKETS.md, `/cerrar-total`.
- Esta sesión es docs: no toques Swift/gateway/tests. Si el CI de este PR docs se dispara, no bloquees por UI advisory; el objetivo es no reiniciar el CI de #78 con un push prematuro a la misma rama/árbol — tu rama es aparte, pero **igual esperas** a que #78 deje de tener checks IN_PROGRESS antes del primer push (pedido explícito de Jürgen 2026-09-06).
- Modelo/esfuerzo ya van por flags del launcher (fable / high). No los cambies.

## Que NO hay que tocar
- Código de producto (Swift, gateway, DDL, tests).
- marketing/.
- clinicas-dentales-bi.
- Relanzar o escribir en la sesión de Balance; si necesitas un fichero que solo existe ahí, espera merge o léelo en solo-lectura del worktree hermano sin modificarlo.
- No decidas tú las opciones de producto.

## Como se sabe que esta bien
- Los 3 tickets de decisión tienen sección Decisión Jürgen con opción y fecha.
- AC/status coherentes con esa decisión (listos para que Frank lance implementación, o cerrados como no-bug, o siguen blocked con motivo device).
- `docs/TICKETS.md` al día.
- Cero push antes de que #78 deje de tener CI pendiente; después, PR docs mergeado y `/cerrar-total`.

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL y key en fichero local, no en git; no las escribas en el repo) cuando:
  (1) necesitas una decisión de producto o de acceso de Jürgen;
  (2) abriste el PR o dejaste preview/artifact listo;
  (3) terminaste el ticket y vas a /cerrar-total — incluye en el aviso un resumen corto de cierre en lenguaje de usuario (qué se hizo), no solo «cerré»;
  (4) acabaste un tramo y no tienes siguiente paso claro (aunque no haya pregunta formal) — una vez, no en bucle.
NO avises por: un test rojo que vas a reclasificar, un build que vas a reintentar, ni ruido de CI advisory. URL/key solo en la Mini.
