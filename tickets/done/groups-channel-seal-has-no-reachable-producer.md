---
id: groups-channel-seal-has-no-reachable-producer
status: done
priority: medium
area: "groups, modo-nube, sync"
created: 2026-09-14
updated: 2026-09-15
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

## Cerrado (2026-09-15 · PR de `encargo/2026-09-15-groups-channel-seal-has-no-reachable-producer`)

**Decisión de Jürgen (2026-09-14, «4A» en la cola): la opción 1, retirarlo.** Ni productor nuevo ni
dejarlo documentado como muerto.

**Lo que cambia para quien usa la app: nada visible.** El freno solo lo echaba una respuesta que el
servidor no manda en esta ruta. En el código, si el canal de Grupos para porque la cuenta no está
disponible, vuelve a intentarlo en el siguiente arranque, vuelta a la app o inicio de sesión, como ya
hacía con la sesión caducada y con el apagado del canal.

**La premisa se sostiene, medida antes de tocar nada.** En el canal hay tres productores de «cuenta no
disponible»: el 403 del apagado en el push y en el pull, que nunca echaban el freno, y el 409 de la
reversa, el único que lo echaba. Ese 409 solo sale de `beginFreezeCheck`, que se llama en `/sync/push` y
`/prefs/push`; `/groups/push` no pasa por ahí.

**Lo que se retiró:** el flag, su escritura en el loop, los guards de los tres `syncNow*`, el parámetro
de `GroupsLoopRestartLogic.shouldStart`, el seam de test, el test que fijaba el freno y las aserciones
sobre el seam. **Se quedan** el testigo del apagado, que elige el aviso del cierre de sesión y el motivo
del log, y el `.stoppedUntilRelaunch` del runtime personal, que es otro mecanismo con productores vivos.

**La review cazó dos huecos de red, y los dos están arreglados.** El único cambio de conducta —el 409 ya
no cierra el canal— no lo fijaba ningún test, así que volver a poner el freno salía verde en toda la
suite. Y al quitar la aserción sobre el seam, el test del apagado dejó de cubrir los guards del save
local y del silent push. Hay test nuevo, `accountReverting409_stopsLoop_andTheNextStartRestartsIt`, y el
del apagado ejerce ahora los dos caminos. Mutantes: tres compilados y tres muertos. **El freno retirado,
puesto tal cual, cae.**

**Un rojo de XCUITest que no era de este cambio.** `test_extremeMinimumAmountSaves` cayó una vez y pasó
la siguiente con el mismo binario; el árbol base pasó con el mismo comando, y el test no ejecuta el código
tocado porque lanza sin sesión de nube. La medición está en `edgecases-extreme-minimum-flaky-under-load`.

**Sin device-QA:** en producción nada cambia.

**Abre:** `groups-loop-restart-docs-cite-a-retired-mount-guard` (`low`).
