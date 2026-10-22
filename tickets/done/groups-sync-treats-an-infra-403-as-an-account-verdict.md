---
id: groups-sync-treats-an-infra-403-as-an-account-verdict
status: done
priority: high
area: "groups, modo-nube, sync"
created: 2026-09-13
updated: 2026-09-14
source: "review adversarial de `groups-killswitch-403-blocks-detach-forever`, lente de sync"
---

# Un 403 de infraestructura apaga el canal de Grupos como si la cuenta ya no valiera

## El problema, en lenguaje de usuario

Un proxy o un WAF por delante del backend devuelve un 403 —o una página de error de Cloudflare en vez
del cuerpo JSON de siempre—. El canal de Grupos lo lee como «esta cuenta ya no está disponible»: **para
el sync, lo sella para el resto de la vida de la app** y, si en ese momento intento cerrar sesión o
soltar mi cuenta de grupos, me dice que revise mi conexión. Nada de eso es verdad, y nada se cura hasta
que mate y reabra la app.

## Lo medido (2026-09-13)

- **El gateway emite exactamente DOS 403 en todo `gateway/src/`**: `yala_groups_disabled`
  (`groups/killSwitch.ts:125`) y `yala_pro_required` (`ratelimit.ts:18`), que es de la IA y no alcanza
  estas rutas — `policy.ts` da límites de `sync` a los dos tiers («Modo Nube es GRATIS»). **No existe un
  403 de «cuenta suspendida» en `/groups/*`**: el 403 que no es el kill viene de fuera del Worker.
- `GroupsSyncClient` mapea todo 403 a `.accountUnavailable` (push `:1517`, pull `:1792`) →
  `SyncCadencePolicy.nextAction` → `.stopUntilRelaunch` → `stoppedUntilRelaunch = true` (`:387`), que
  `GroupsLoopRestartLogic.shouldStart` y `syncNowFromPush` leen: **no re-arranca en ese proceso**.
- El cliente HERMANO del mismo endpoint ya decidió lo contrario, y está escrito:
  `GroupsMembershipClient.swift:354-363` discrimina por el CÓDIGO del envelope justo para que «un 403
  que viene de un proxy o WAF por delante del Worker […] conserve su comportamiento de HOY —
  `.transient`, con retry—», y avisa de que un `case 403:` pelado «habría convertido un fallo de
  infraestructura en un canal apagado permanente». El canal de sync hace exactamente eso.
- Desde el 2026-09-13 ese 403 llega además a la pantalla como `BlockReason.permanent` («revisa tu
  conexión»), mientras que el del kill tiene copy propio.

## Lo que se espera

Decidir si el 403 **sin envelope reconocible** debe seguir siendo un veredicto sobre la cuenta, o pasar a
transitorio con reintento como en `GroupsMembershipClient`. Afecta a tres cosas a la vez y por eso no se
tocó de paso: el sellado del loop, la clasificación del bloqueo del cierre, y los dos tests que hoy
pinnean el comportamiento actual (`accountUnavailable403_withoutKillCode_stillSealsLoop` y
`killWitness_isOffForTheAccountKindOf403`, que además siembran `yala_forbidden`, un tipo que el gateway
no emite).

**Corolario que lo hace urgente en incidente:** si el mismo edge que devuelve el 403 reescribe o trunca
el cuerpo del kill, el testigo del kill se apaga y la persona recibe el aviso pre-fix **justo durante el
incidente**, que es cuando el arreglo tenía que servir.

## Cerrado (2026-09-14 · PR de `encargo/2026-09-13-groups-sync-treats-an-infra-403-as-an-account-verdict`)

**Lo que cambia para quien usa la app.** Cuando un proxy o un cortafuegos por delante del servidor
devuelve un 403, el canal de Grupos ya no lo lee como «esta cuenta ya no vale»: reintenta con su espera
habitual, como con cualquier otro fallo de red. Antes se apagaba hasta que matabas y reabrías la app, y
si en ese momento intentabas cerrar sesión o soltar tu cuenta de grupos te decía que revisaras tu
conexión — sobre un problema que no era tuyo ni se arreglaba esperando.

**Lo que NO cambia.** El apagado deliberado del canal (`yala_groups_disabled`) sigue exactamente como lo
dejó `groups-killswitch-403-blocks-detach-forever`: para el ciclo, se anuncia como una pausa y vuelve
solo, sin relanzar la app.

**Lo medido en el cierre, que corrige una premisa de este mismo ticket.** El ticket decía que el 403 no
reconocido cae en `.permanent`, y era cierto; lo que no decía es qué queda después. Tras el arreglo,
`stoppedUntilRelaunch` **se queda sin ningún productor alcanzable**: el 409 `yala_account_reverting` que
lo armaría no lo emite `/groups/push` — `gateway/src/groups/routes.ts:12` dice que el freeze de la
reversa del personal no aplica a este canal y no llama a `beginFreezeCheck`. Decidirlo es su propio
ticket: `groups-channel-seal-has-no-reachable-producer`.

**Eran CUATRO tests pinneando el comportamiento viejo, no dos, y los otros dos no daban rojo: colgaban
la corrida.** El ticket nombraba `accountUnavailable403_withoutKillCode_stillSealsLoop` y
`killWitness_isOffForTheAccountKindOf403`, que sembraban `yala_forbidden` —un tipo que el gateway no
emite— y se retiraron. La review adversarial encontró los otros dos, en un fichero que el arreglo no
tocaba: `loop_403_armsStopUntilRelaunch_subsequentStartIsNoOp` y `restart_403_stillNoOp`
(`GroupsSyncClientTests`), que sembraban `StubHTTPSession(statusCode: 403)` con su body por defecto —una
página de pull vacía, sin envelope—. Con el fix eso es transitorio, así que el loop entra en backoff y su
`await _testLoopTask?.value` **no vuelve nunca**: la suite no habría fallado, se habría quedado colgada.
Los cuatro fuera.

En su sitio quedan **10 casos parametrizados** (5 cuerpos que sí llegan de verdad —una página de error del
edge, un cuerpo vacío, un JSON de proxy, un envelope de otro tipo y el envelope del kill **truncado por el
edge**, que es el corolario que hacía urgente este ticket— × los DOS bordes que leen un 403, push y pull)
**más 2 sueltos**: el del sello sobre el loop y el mutante de colapsar las dos ramas en un `case 403:`
pelado.

**Lo que este arreglo NO cubre, y hay que decirlo.** En el cierre de sesión de una cuenta `.cloud`, el
paso 2 de `CloudSessionSignOut.performCloudSecureSignOut` **colapsa en `.permanent` todo veredicto de
grupos que no sea `.channelPaused`** (`:781-782`), así que ahí un WAF sigue saliendo como «revisa tu
conexión». Ese colapso es anterior, deliberado, y cambiarlo movería también la red caída y los 5xx —otro
objeto—. Ticket: `cloud-signout-collapses-every-groups-transient-into-permanent`. Donde sí queda cerrado
es en el sellado del canal, en el cierre solo-grupos y en «soltar la cuenta de grupos».

**Un matiz del alcance, medido en la review:** el sello solo existía en el modo loop-propio. Cuando el
runtime personal cadencia y el ciclo de grupos va de piggyback, el outcome se descarta y
`stoppedUntilRelaunch` nunca se escribía — o sea que «apagaba el canal el resto de la vida del proceso»
valía para la sesión solo-grupos, no para toda población.

**El camino nuevo deja rastro.** Antes, un 403 de infraestructura dejaba su `loopStopped
reason=account-unavailable`; como transitorio no dejaría nada, y un WAF que apagara `/groups/*` para una
cohorte sería invisible en los logs. Lleva breadcrumb propio (`forbiddenNotKill edge=push|pull`).

**Sin device-QA, y no por falta de ganas.** El canal está encendido en producción
(`GROUPS_BACKEND_ROLLOUT_PERCENT = 100`), así que el bug estaba vivo; pero reproducir el caso exige que
algo por delante del Worker devuelva un 403, y eso no se provoca ni en simulador ni en device sin un seam
que hoy no existe. La cobertura es la suite unitaria.
