# Un 403 de infraestructura apaga el canal de Grupos como si la cuenta ya no valiera

## Contexto
Cola autónoma Jürgen 2026-09-13 (bypass). Tras #152 (kill-switch 403 con copy de pausa) y #153 (wipe-alert de «Primera vez → privado»), toca este high adelantado: un 403 de infra/WAF/proxy delante del backend no es «cuenta muerta».

Decisión ya tomada por Frank (ratificada en cola): tratar el 403 de infra como **transitorio**, como ya hace el hermano `GroupsMembershipClient` (discrimina por código de envelope). El kill real `yala_groups_disabled` sigue siendo permanente/pausado según #152.

Avisos al bot dueño (Frank): POSTea al webhook local de la Mini (URL y key en fichero local, no en git) cuando:
  (1) necesitas una decisión de producto o de acceso de Jürgen;
  (2) abriste el PR o dejaste preview/artifact listo;
  (3) terminaste el ticket y vas a /cerrar-total — incluye resumen corto de cierre en lenguaje de usuario;
  (4) acabaste un tramo y no tienes siguiente paso claro — una vez, no en bucle.
NO avises por: test rojo que vas a reclasificar, build que vas a reintentar, ni ruido de CI advisory.

MODO AUTÓNOMO HASTA TERMINAR: gate, commit, docs/board, actualizar `docs/TICKETS.md` (índice al día), merge y /cerrar-total sin preguntar si corre el gate o el commit. Bugs/decisiones nuevas → ticket propio antes de cerrar. Solo parar ante decisión/acceso real.

## Que se pide
1. Leer el ticket entero + el mapeo medido en GroupsSyncClient vs GroupsMembershipClient.
2. Discriminar 403 de kill (`yala_groups_disabled`) vs 403 de infra/WAF/página HTML: infra → transient (no `stopUntilRelaunch` / no sellar el canal de por vida del proceso).
3. Tests + mutantes que cierren el agujero (un solo token no debe reintroducir el sello permanente).
4. Un PR a `2.1`; board + `docs/TICKETS.md`; device-QA a `tickets/qa/` solo si el sim no basta; `/cerrar-total`.

## Que NO hay que tocar
marketing/. Reabrir el copy/comportamiento del kill-switch ya mergeado en #152 salvo lo mínimo para compartir el discriminador. Ampliar wipe. Otros tickets de la cola (restore-start-fresh, apple-id-change, remote-wipe, paso 13).

## Como se sabe que esta bien
Criterios del ticket; un 403 de infra ya no apaga el canal como cuenta muerta; el kill real sigue anunciándose como pausa (#152); PR mergeado; `/cerrar-total`.

## Paso 0 — el árbol de decisiones, resuelto antes de escribir (2026-09-14)

**D1 · ¿Qué hace el 403 que no trae el envelope del kill?** → **`.transient`**, no un
`.accountUnavailable` sin sello. Ratificado en la cola, y lo confirma la medición: con
`.accountUnavailable` la persona vería «el canal está en pausa», que es *falso* (nadie bajó ninguna
palanca); con `.transient` ve «inténtalo en un momento», que es lo único cierto de un WAF. Es además lo
que ya hace el cliente hermano del mismo endpoint (`GroupsMembershipClient`, `case 403 where` +
`default:`), así que la simetría deja de estar rota.

**D2 · ¿Hay que inventar un discriminador?** → No. `GatewayErrorEnvelope.isGroupsChannelDisabled(data)`
existe y ya lo llaman tres clientes. El cambio es un `case 403 where …` delante del `case 403:`.

**D3 · ¿Hay que retirar `stoppedUntilRelaunch`?** → **No, y con ticket.** Tras D1 se queda sin productor
alcanzable (medido: el 409 que lo armaría no lo emite `/groups/push`). Retirarlo toca la firma de
`GroupsLoopRestartLogic.shouldStart` y sus tests, o sea ampliar el alcance a otro objeto. Se documenta
honestamente y se decide en `groups-channel-seal-has-no-reachable-producer`.

**D4 · ¿Y el tercer cliente que también mapea 403, `GroupsMerkleClient`?** → **Sin cambio funcional**,
medido: su `.accountUnavailable` lo colapsa `verifyGroupIntegrity` en un `.skipped` (`guard case
.snapshot`), así que ni sella el loop ni llega a un aviso. Lo que sí se corrige es su comentario, que
llamaba «cuenta suspendida» a un 403 que el gateway no emite.

**D5 · ¿Los dos tests que pinnean el comportamiento viejo se adaptan o se retiran?** → Se **retiran**.
Sembraban `yala_forbidden`, un tipo que el gateway no emite en ninguna ruta, así que fijaban una
premisa falsa. En su sitio van cuerpos que sí llegan de verdad.

**D6 · ¿Device-QA?** → **No procede, y no por falta de ganas.** El canal está encendido en producción
(`GROUPS_BACKEND_ROLLOUT_PERCENT = 100`, `gateway/wrangler.toml`), o sea que el bug estaba vivo; pero
provocar un 403 desde algo por delante del Worker no se puede ni en simulador ni en device sin un seam
que hoy no existe. La cobertura queda en la suite unitaria.
