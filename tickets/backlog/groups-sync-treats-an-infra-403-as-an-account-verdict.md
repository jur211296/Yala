---
id: groups-sync-treats-an-infra-403-as-an-account-verdict
status: backlog
priority: high
area: "groups, modo-nube, sync"
created: 2026-09-13
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
