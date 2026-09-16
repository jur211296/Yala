---
id: personal-sync-reads-an-offline-token-refresh-as-a-session-expiry
status: backlog
priority: medium
area: "modo-nube, sesión"
created: 2026-09-15
updated: 2026-09-15
source: "barrido del mismo patrón en `groups-push-reads-an-offline-token-refresh-as-a-session-expiry` (2026-09-15); prioridad corregida por la review adversarial del mismo día"
---

# El canal personal de Modo Nube también lee una renovación sin red como sesión caducada

## El problema, en lenguaje de usuario

Tengo una cuenta en la nube y me quedo sin conexión con el token caducado. Mis datos dejan de sincronizar hasta que
vuelvo a abrir la app, y los cambios de mis grupos tampoco suben, aunque lo único que falla es la red. Si activo el
modo completo sin red, Yala me enseña el aviso de sesión caducada.

**A quién le llega, corregido en la review del 2026-09-15.** La primera versión de este ticket decía que a nadie,
porque Modo Nube estaría apagado. No lo está: la tarjeta de alta en la nube se ofrece en producción desde el
2026-09-09 (`CloudSyncFlags.bornCloudChoiceEnabled`, medido allí con `curl`), así que puede haber cuentas `.cloud`
en los builds que la traen. Sin medir cuántas hay.

## Lo medido (leído en el código, sin ejecutar)

`CloudAuthService.accessToken()` devuelve `nil` por cualquier fallo, y en estos sitios ese `nil` se lee como sesión
caducada:

- `SyncPushClient.push` y `SyncPullClient.pull`: devuelven `.sessionExpired` sin hacer la petición y cuentan el
  canario `cloudSyncBlockedByExpiredSession`. `CloudSyncRuntime` los convierte en `stopUntilSignIn`.
- `PrefsSyncClient`, `MigrationWorkExecutor` (8 `guard` sobre el token), `BornCloudSignUpService`,
  `AccountDeletionService` y `SIWATokenRevocation`.
- Los proveedores de token de `AccountEntitlementService`, `AccountKindService`, `CloudIdentityDiscovery` y
  `CloudMigrationController`.
- **Y frena también a Grupos.** En `.cloud` Grupos no tiene loop propio: cicla en el paso 5.6 del runtime personal
  (`CloudSyncRuntime.performCycle`). Con el push o el pull personal parados por el token nulo, el ciclo sale antes de
  ese paso y los cambios de grupos no suben hasta volver a primer plano. El canal de Grupos ya separa los dos casos
  desde el 2026-09-15, pero en `.cloud` no llega a ejecutarse.
- La activación del modo completo por la nube pasa por `BornCloudSignUpService`: sin token termina en
  `FullModeActivationFlowLogic` → `.blocked(.sessionExpired)`.
- **El 401 `yala_attest_required` también se lee caducado aquí** (`SyncPushClient`, `SyncPullClient` y
  `PrefsSyncClient` mapean todo 401 a `.sessionExpired`). `CloudSyncRuntime.performCycle` pide el attest antes de
  subir (paso 2, `resolveAttest`), pero no lo evita: la migración sube sin esa puerta (`MigrationWorkExecutor`,
  `MigrationSnapshotUploader`, que lo tratan como transitorio), y la comprobación solo mira la caché local, así que
  el 401 también llega con un token que caduca entre ese paso y la petición o que el servidor ya no acepta
  (`attest-session-token-rejected-by-the-gateway-stays-cached`). Dos docblocks dan el attest ausente por un problema
  de sesión que se arregla volviendo a entrar: `CloudAccountClient.swift:55` y `SyncPullClient.swift:61`. El canal
  de Grupos lo lee pasajero desde el 2026-09-15 con `GatewayErrorEnvelope.isAttestRequired`
  (`groups-sync-reads-a-missing-attest-401-as-a-session-expiry`).

El runtime personal ya consulta `canRenewSession` antes de subir (`SessionExpiryPolicy`), pero solo para bloquear
cuando la sesión NO se puede renovar. Cuando sí se puede y el token no llega, el push devuelve igualmente
`.sessionExpired` y el canario lo cuenta como sesión caducada.

## Lo que hay que decidir antes de tocarlo

Si se aplica el criterio del canal de Grupos (`GroupsSyncClient.sdkRemovedTheSession`): con la sesión guardada,
pasajero; sin ella, caducada. Varios de estos sitios son migraciones y borrados de cuenta, donde un pasajero
reintenta: hay que medir cada uno antes de decidir.

## Criterios de aceptación

- [ ] Inventario de cada sitio y de lo que hace hoy con el `nil`.
- [ ] Decisión escrita por sitio.
- [ ] Tests en las dos direcciones donde cambie algo.

## Relación con otros tickets

- `groups-push-reads-an-offline-token-refresh-as-a-session-expiry` — el arreglo del canal de Grupos.
- `groups-actions-read-an-offline-token-refresh-as-a-session-expiry` — el de las acciones de grupo.

## Consecuencia nueva: el aviso fijo del canal personal NO llega a esta población (2026-09-15)

Medido en la review adversarial de `cloud-tab-does-not-say-this-phone-cannot-sync-personal-data`, el mismo día que
ese aviso entró. El aviso se gatea por `GroupsAttestStreakStore.isTerminal()`, y a esta población **la racha nunca se
le escribe**, por dos razones que se suman:

- `SyncPushClient` (`:342-345`) y `SyncPullClient` (`:184-187`) mapean **todo** 401 a `.sessionExpired`. La rama
  `case 401 where GatewayErrorEnvelope.isAttestRequired(data)` que sí tienen `GroupsSyncClient` (`:1578`, `:1894`) y
  `GroupsMembershipClient` (`:355`) no existe aquí — `isAttestRequired` no tiene **ni un call-site fuera de Grupos**.
- Y en ese mismo ciclo la puerta ya **borró** la racha: `CloudSyncRuntime.resolveAttest` (`:774-777`) llama a
  `recordAcceptance()` en cuanto `session.attestToken()` devuelve algo, **incluido un token de la caché** que el
  gateway está rechazando (`attest-session-token-rejected-by-the-gateway-stays-cached`).

⇒ a quien el gateway le rechaza el token aunque el teléfono lo acuñe bien, la app le dice **«Vuelve a iniciar
sesión»** —y volver a entrar no arregla nada— o, sin filas pendientes, nada en absoluto. Es una de las dos formas de
que un teléfono en la nube deje de subir por attest, y es la única que no produce racha, así que el aviso nuevo no
puede salir ahí **por construcción**, no por casualidad.

**Al arreglar este ticket, comprobar que el aviso aparece**: es el consumidor que hoy queda ciego, y la comprobación
es la que demuestra que la clasificación del 401 llegó hasta el final.
