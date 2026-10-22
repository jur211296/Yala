# Implementar ticket: remote-wipe-axis-misses-groups-only-installs-before-the-mount-mark

## Contexto
Cola autónoma nocturna. Tras #157/#162/#164: el eje `wipeSignalObeyedByThisSession` / `confirmedPrivateSession` ya gobierna borrado remoto y el aviso de datos borrados. Queda un residual HIGH: altas solo-grupos **anteriores al 2026-09-10** no tienen `groupsOnlyNeutralMountKey`, el backfill de `PrivateSessionMark` les escribe `hasPrivateSession = true`, y el eje da `true` — el teléfono prestado **sigue vaciándose** (y el aviso les sigue saliendo). El docblock ya lo nombra; falta cerrar el hueco.

Ticket: `tickets/backlog/remote-wipe-axis-misses-groups-only-installs-before-the-mount-mark.md` (leer entero en origin/2.1).

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs/board, actualizar `docs/TICKETS.md` (índice al día), merge y `/cerrar-total` sin preguntar si corre el gate o el commit. Bugs/decisiones nuevas → ticket propio (`--solo-crear` / fichero en tickets/) antes de cerrar; avisar a Frank. Device-QA → `tickets/qa/` si aplica. Solo parar ante decisión/acceso real de Jürgen.

Criterios del ticket ya dan un OR de producto: (a) esa población deja de obedecer la señal, o (b) se mide que la población está vacía y se cierra con el número. Resuelve Paso 0 midiendo; si hay población, cierra el hueco en el EJE (no un predicado local al aviso/borrado que diverja). Si el fork de implementación no está cubierto por ese OR, para y avisa (1).

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL y key en fichero local, no en git; no las escribas en el repo) cuando:
  (1) necesitas una decisión de producto o de acceso de Jürgen;
  (2) abriste el PR o dejaste preview/artifact listo;
  (3) terminaste el ticket y vas a /cerrar-total — incluye resumen corto de cierre en lenguaje de usuario;
  (4) acabaste un tramo y no tienes siguiente paso claro — una vez, no en bucle.
NO avises por: test rojo a reclasificar, build a reintentar, ni CI advisory.

## Que se pide
1. Leer ticket + `PrivateSessionMark.backfillIfNeeded` + `wipeSignalObeyedByThisSession` / `confirmedPrivateSession` + consumidores (borrado y aviso).
2. Cumplir los criterios de aceptación del ticket.
3. Docblock de `backfillIfNeeded` al día.
4. Tests/red que sostengan el cambio; PR a `2.1`; al terminar `/cerrar-total` (no `/cerrar`). Board + `docs/TICKETS.md` al día. Sync centro de mando: append `~/Claude/grok-shared/kanban-inbox.json` al crear/mover/cerrar.

## Que NO hay que tocar
marketing/. No inventar producto fuera del OR del ticket. No parchear solo el aviso dejando el borrado divergente.

## Como se sabe que esta bien
Criterios del ticket; tests; PR mergeado a `2.1`; `/cerrar-total` con board e índice al día.

## Paso 0 — decisiones (resueltas en autónomo (bypass), 2026-09-14)

El ticket ofrecía un OR de producto: (a) cerrar el hueco en el eje, o (b) medir que la población está
vacía y cerrar con el número. **Jürgen zanjó el fork en mitad de la sesión: población cero, sin
predicado nuevo en el receptor ni señal inventada.** Lo que sigue es el árbol con lo que se midió.

**D1 · ¿Qué población tiene el hueco?** → **CERO**, por cuatro vías independientes:

1. *Telemetría de producción* (Analytics Engine, dataset `yala_metrics`, 90 días de retención ⇒ cubre
   entera la vida del camino, nacido el 11-ago en `5fc75b94`): eventos `register` con
   `detail = groupsOrganizer` → **0**; con `groupInvite` → **0**. Lo único del periodo: 5 altas
   personales (`local/initial`) y 1 `cloud/migration`. Control negativo (detail inexistente) = 0 filas;
   control positivo = el censo devuelve filas con fechas reales. Las dos altas solo-grupos emiten ese
   KPI y `MetricsService.start()` corre incondicional en el cold launch (`AppBootstrapper:159`), sin
   opt-in que lo apague.
2. *Backend de Grupos* al que apunta un build de release (`CloudBackendConfig:43-49`, rama `#else` ⇒
   `kefvaiymtgytemwbltlz`, producción): `auth.users` = 0, `profiles` = 0, `split_groups` = 0,
   `group_members` = 0, `group_invites` = 0, `groups_consents` = 0. Control positivo: la misma consulta
   cuenta 31 migraciones y 30 tablas, como rol `postgres` (sin RLS que oculte). Y las dos altas exigen
   sesión remota antes de escribir nada (`GroupsGateLogic.nextStep:145-146` corta en `.presentSignIn`).
3. *Universo de distribución*: la App Store pública sirve **2.0.4** (6-jul-2026), anterior al camino.
   El alta solo-grupos solo existe en los builds 11 (18-ago), 12 (22-ago) y 13 (9-sep) de TestFlight, y
   TestFlight tiene **3 testers** (2 instalados, 1 invitado sin instalar).
4. *Nada ha corrido aún*: ningún build distribuido contiene `PrivateSessionMark` (el 13 se cortó el
   9-sep; el eje llegó el 12-sep) ⇒ el backfill no se ha ejecutado nunca fuera de un simulador.

**D2 · ¿Se toca el eje igualmente, por si acaso?** → **NO.** Cerrar el hueco pedía una señal que
distinguiera un solo-grupos viejo, y las candidatas del ticket (filas `SplitGroup` sin `Account`
propio, corpus personal ausente) derivan el eje de una AUSENCIA, que es lo que la cabecera de
`PrivateSessionMark` prohíbe: un gate así falla ABIERTO y le esconde las cuentas a alguien con su vida
personal entera cuando el store tarda en montar. Coste real contra población cero.

**D3 · ¿Un predicado local al receptor (aviso/borrado)?** → **NO**, y lo dice el propio ticket: un
predicado propio del aviso divergiría del que gobierna el borrado en el commit siguiente, en silencio.

**D4 · ¿Qué red sostiene un cierre que no cambia comportamiento?** → La premisa que mantiene la
población en cero hacia delante: **toda alta solo-grupos escribe el eje EN EL ACTO y arma el mount
neutro**, así que el backfill nunca ve la marca ausente en esa celda. Un test de wiring lo fija sobre
las dos altas, con conteo, para que una tercera obligue a decidir.

**D5 · ¿`done` o `discarded`?** → **`done`**: el criterio de aceptación (b) del ticket se cumple
literalmente («se mide que esa población está vacía y el ticket se cierra con el número»). No es una
refutación del mecanismo — el hueco de código es real y queda descrito en el docblock.

**D6 · ¿Hallazgos nuevos → ticket propio?** → Se midieron dos candidatos y **los dos quedaron
refutados**, así que no se abre ninguno: (i) la escritura de `hasCompletedOnboarding` del camino de
invitación (`ContentView:2839`) para todo `outcome != .declined` no alcanza la celda, porque
`GroupInviteOnboardingLogic.step:100` (`guard hasTappedJoin`) hace inalcanzables las pantallas de
abandono sin haber pasado por `performSilentSetup`, que arma el neutro y apaga el eje; (ii) el relevo
de humano (`wipeLocalGroupsDomain`) deja el eje ausente, pero sus tres call-sites corren con
`resetsPreferences == true` y `removeUserPreferenceKeys` borra `hasCompletedOnboarding`, así que el
gate del backfill cierra.
