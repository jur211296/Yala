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
