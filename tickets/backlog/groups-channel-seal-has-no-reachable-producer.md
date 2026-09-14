---
id: groups-channel-seal-has-no-reachable-producer
status: backlog
priority: medium
area: "groups, modo-nube, sync"
created: 2026-09-14
source: "medición al cerrar `groups-sync-treats-an-infra-403-as-an-account-verdict`"
---

# El sello que apaga el canal de Grupos hasta relanzar ya no lo puede armar nadie

## El problema, en lenguaje de código

`GroupsSyncClient.stoppedUntilRelaunch` es el freno de mano del canal: una vez armado,
`GroupsLoopRestartLogic.shouldStart`, `syncNowFromPush`, `syncNowFromUI` y `syncNowAfterLocalSave`
devuelven `false` el resto de la vida del proceso. **Tras el arreglo del 403 de infraestructura
(2026-09-13) no le queda ningún productor alcanzable**, y eso no lo decidió nadie: salió de quitar el
último que quedaba.

## Lo medido (2026-09-14, este árbol)

- Lo escribe **un solo sitio**: `GroupsSyncClient.runLoop`, en la rama `.stopUntilRelaunch` de
  `SyncCadencePolicy.nextAction` cuando `stoppedByChannelKill(for:)` es `false`.
- A `.stopUntilRelaunch` solo se llega con `.accountUnavailable`, y en este canal eso tiene **dos
  productores en el código**:
  - el 403 del kill (`yala_groups_disabled`), que **nunca** arma el sello — es re-arrancable a
    propósito, y hay test que lo fija (`killSwitch403_stopsLoop_butDoesNotSealIt`);
  - el 409 `yala_account_reverting` del push (`GroupsSyncClient`, `case 409`), que **el gateway no
    emite en esta ruta**: `gateway/src/groups/routes.ts:12` lo dice de su puño — «El freeze de la
    reversa del personal NO aplica aquí (canal aparte): NO se llama beginFreezeCheck» —, y
    `beginFreezeCheck` solo tiene dos call-sites, los dos en `gateway/src/sync/routes.ts`
    (`/sync/push` y `/prefs/push`).
- El tercer 403, el de un proxy o un WAF, era el que llegaba de verdad y desde el fix es `.transient`.

## Por qué importa aunque hoy no rompa nada

Un mecanismo sin productor no es inocuo: es una pieza que parece cubrir un caso y no lo cubre. Un
lector futuro que lea `GroupsLoopRestartLogic.shouldStart` verá un freno para «cuenta no disponible» y
dará por hecho que ese caso está atendido. **No lo está**: si mañana el gateway añade un veredicto de
cuenta de verdad en `/groups/*`, el freno funcionaría — pero nadie lo ha probado contra un 403 real
desde que existe, porque el único que llegaba era el que ahora es transitorio.

## Lo que hay que decidir

Es una decisión, no una tarea:

1. **Retirarlo.** Quitar `stoppedUntilRelaunch`, su parámetro en `GroupsLoopRestartLogic.shouldStart`,
   los cuatro `guard` que lo leen y los tests que lo fijan. Queda un canal donde la única parada
   permanente es la sesión caducada. Coste: si vuelve a hacer falta, se reescribe.
2. **Dejarlo y darle un productor de verdad.** Cablear el 409 del freeze también en `/groups/push`
   —hoy el canal de Grupos sigue aceptando escrituras con la cuenta personal en reversa, que es una
   pregunta abierta aparte— o esperar a que exista un 403 de cuenta suspendida.
3. **Dejarlo documentado como está** (lo que hace el commit de hoy) y revisarlo cuando alguno de los
   dos casos aparezca.

## Relación con otros tickets

- `groups-sync-treats-an-infra-403-as-an-account-verdict` — el arreglo que dejó el sello sin productor.
- `groups-killswitch-403-blocks-detach-forever` — el que estableció que el kill NO sella.
- `reverse-upload-has-no-ceiling-and-no-exit` — el freeze de la reversa, pero en el canal personal.
