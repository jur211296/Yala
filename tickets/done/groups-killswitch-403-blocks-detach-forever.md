---
id: groups-killswitch-403-blocks-detach-forever
status: done
priority: high
area: "groups, modo-nube, settings"
created: 2026-09-11
updated: 2026-09-23
source: "review adversarial de `cloud-killswitch-hides-the-only-door-to-detach-groups`, lente del incidente"
qa-status: not-replicable
qa-date: 2026-09-23
qa-notes: barrido 2026-09-23 sin device-QA - exige bajar el kill-switch del gateway con despliegue
---

# Con el canal de Grupos en pausa, quien tiene cambios sin subir no puede soltar su cuenta

## El problema, en lenguaje de usuario

Jürgen baja el kill-switch de **Grupos** por un incidente. Yo decido soltar mi cuenta de grupos desde
Ajustes → «¿Dónde viven tus datos?». Si tengo cambios de grupos sin subir, el botón no funciona: sale un
aviso que dice que **el problema es mi cuenta**, y no hay reintento posible mientras dure el incidente.
El aviso miente sobre la causa, y el gesto queda imposible hasta que alguien vuelva a subir el flag.

## Lo medido (2026-09-11, re-medido el 2026-09-13)

**Las tres coordenadas del ticket original estaban caducadas** (el paso 9 acortó el fichero):
`CloudSignOutFlowLogic.swift` tiene 255 líneas, no 279 — `classify` en `:183` (no `:214`),
`pushAllVerdict` en `:206` (no `:242`), `decide` en `:245` (no `:279`). Y el pre-check del outbox vacío
está en `CloudSessionSignOut.swift:1047`, no en `:1195`. **La CADENA que describen era exacta.**

Con el kill servido server-side como 403 (`yala_groups_disabled`) y el outbox NO vacío: el ciclo devuelve
`.accountUnavailable` → `classify` → `.permanent` → `pushAllVerdict` → `.blocked(.permanent)` → `decide`
→ `.surfacePermanent` sin un reintento → `pushGroupsForSignOut` → `false` → `detachGroupsAccount` sale
por su guard → el alert dice `detachBlockedPermanent` («no pudimos conectar, revisa tu conexión»).

**Con el outbox vacío el gesto completa**, y sigue completando: el pre-check corta en `.drained` sin una
sola petición. **No deja estado a medias**: el aborto ocurre antes del punto de no retorno.

**El gesto SÍ es alcanzable con el kill puesto** (medido, porque si no el arreglo sería para un camino
muerto): `GroupsAssociationPresence.sectionState` no lee ningún flag de grupos, y la fila de Ajustes la
abre `hasGroupsAccountToDetach` aunque `remoteEnabled` sea falso — eso lo dejó hecho el ticket hermano.

### Lo que la review adversarial añadió (2026-09-13)

- **La distinción YA existía y se perdía una capa más abajo**: `GroupsSyncClient.lastStopWasChannelKill`
  la escriben los dos sitios que leen un 403, y el loop de cadencia ya la usaba para no sellar
  `stoppedUntilRelaunch`. Lo que no existía era el camino hasta `classify`.
- **Una CUARTA celda mentía igual**, y no estaba en el ticket: `WelcomeGroupsGateView` —la puerta de
  grupos del Welcome, por donde se acepta una invitación— observa la misma fase y su rama `.blocked` es
  un catch-all que decía «vuelve a entrar con esa cuenta», consejo inútil bajo un 403 que no depende de
  la sesión.
- **Un aplanado preexistente tiraba el motivo antes de llegar a la pantalla**: `pushGroupsForSignOut`
  colapsaba todo lo que no fuera `.sessionExpired` en `.permanent`.
- **El «otro» 403 no es lo que parece**: el gateway emite exactamente dos 403 y ninguno es «cuenta
  suspendida», así que el que cae en `.permanent` viene de infraestructura. Ticket propio:
  `groups-sync-treats-an-infra-403-as-an-account-verdict`.

## Lo que se hizo — opción (a), decisión de Jürgen del 2026-09-13

1. **El testigo del kill viaja, ligado a su ciclo.** `GroupsSyncClient.stoppedByChannelKill(for:)` exige
   el outcome: el testigo solo significa algo si el ciclo paró por un 403, y se baja al ENTRAR en cada
   ciclo. Sin ese reset, el 409 `yala_account_reverting` —que produce el mismo `.accountUnavailable` sin
   tocar el testigo— heredaría un kill anterior y anunciaría «canal en pausa» sobre una cuenta que
   revierte.
2. **`BlockReason.channelPaused`**, con copy propio (`groups.errors.channelPaused`) en las **tres**
   pantallas. `classify(_:channelKilled:)` y `pushAllVerdict` reciben el término **sin default**, así que
   el compilador obligó a cada call-site a pronunciarse — y cazó el del motor personal, que nadie había
   mirado.
3. **Sin reintento automático, y es decisión, no olvido.** El kill se levanta con un deploy: dentro de
   los 45 s del presupuesto no se mueve. Reintentar gastaría ~22 peticiones contra un 403 seguro **en
   pleno incidente** y retrasaría 45 s un aviso que ya se puede dar. El gesto sigue siendo reintentable
   por la persona, porque no se escribió nada.
4. **NO se tocó el orden «lo pendiente sube ANTES de cortar»** (opción (b), descartada por Jürgen).

## Qué queda: device-QA, y NO es simulable

El kill real se sirve server-side, así que reproducirlo exige **bajar `GROUPS_BACKEND_ROLLOUT_PERCENT` a
0 en el gateway** y tener outbox de grupos no vacío. Ningún seam del simulador lo fabrica.

1. Con la cuenta de grupos asociada y al menos un gasto de grupo **sin subir**, baja el percent a 0.
2. Ajustes → «¿Dónde viven tus datos?» → **Desasociar** → cualquiera de las dos salidas.
3. **Esperado:** «No pudimos soltar la cuenta» + «Es algo de nuestro lado: los grupos están en pausa.
   Tus cambios siguen en este teléfono y no se pierden; vuelve a intentarlo en un rato.»
   **NO** debe decir «revisa tu conexión» ni hablar de tu cuenta.
4. Sube el percent a 100 y repite: el gesto tiene que completar.
5. **Con el outbox vacío y el percent en 0**, el desasociar tiene que completar igual (el pre-check corta
   sin pedir red). Es el caso dominante y la mitad que ya funcionaba.
6. Mismo kill, pero **cerrando sesión** desde el Perfil: el aviso es «No pudimos cerrar tu sesión» con el
   mismo cuerpo.
7. Mismo kill, aceptando una **invitación de grupo** en un teléfono con sesión privada y cambios de
   grupos sin subir: la puerta del Welcome tiene que enseñar el copy de pausa, **no** «vuelve a entrar
   con esa cuenta».

## Barrido de `qa` · 2026-09-23 · cerrado sin device-QA

Sale de la cola de device-QA por el barrido que pidió Jürgen el 2026-09-23 (encargo `2026-09-23-barrido-qa-in-qa-pre-device`). Exige apagar el canal de Grupos en el servidor con un despliegue. Lo cubren los tests de `channelPaused`.
