---
id: groups-join-intent-expires-silently-after-transient-failures
status: backlog
priority: medium
area: "groups, invitaciones"
created: 2026-09-15
updated: 2026-09-15
source: "review adversarial de `groups-sync-reads-a-missing-attest-401-as-a-session-expiry` (2026-09-15)"
---

# Una invitación que falla por algo pasajero caduca a los 7 días sin que nadie lo diga

## El problema, en lenguaje de usuario

Toco el enlace de invitación a un grupo. La pantalla de unión se queda esperando y me dice «Está tardando un poco más
de lo normal». Sigo usando la app. El grupo no aparece nunca, y una semana después la invitación ya no existe: nadie
me avisó de que no entré.

## Lo medido (leído en el código, sin ejecutar)

- Un fallo pasajero de `join_group` —sin red, un 5xx y, desde el 2026-09-15, también un 401 por App Attest ausente—
  se clasifica `.transient` (`GroupBackendAcceptErrorLogic.classify`). `GroupBackendInviteEntryHandler.handleJoinError`
  lo trata sin alerta y sin `noteAcceptFailed`: conserva el intent y re-arma el tap para que el reconciler reintente.
- A los 20 s la pantalla de unión pasa a `groups.invite.slow.title`, «Está tardando un poco más de lo normal»
  (`GroupInviteOnboardingLogic`).
- El intent vive en `PendingJoinStore` con un TTL de 7 días (`PendingJoinStore.ttl`). Al leerlo caducado, `all(now:)`
  lo borra y solo emite el canario `groupJoinIntentExpired`, que `groups-join-intent-reconciler` declara «debe ser 0».
  A la persona no se le dice nada.
- Si el fallo se cura, el reconciler completa la unión en un arranque posterior y esto no pasa. Lo que estira el fallo
  hasta la caducidad es una causa que no se cura sola, como un teléfono que no consigue App Attest
  (`groups-phone-that-never-attests-is-told-to-retry-forever`).
- Antes del 2026-09-15, con App Attest ausente, el mismo intent reabría el inicio de sesión de Grupos en cada
  reintento: no arreglaba nada, y la caducidad era igual de silenciosa.
- Sin medir: cuántas invitaciones caducan. El canario `groupJoinIntentExpired` en Analytics Engine lo diría.

## Lo que hay que decidir (Jürgen)

1. Avisar al caducar: al purgar el intent, un aviso de que no pudimos unirte al grupo y de que pidas otro enlace.
2. Avisar antes: tras varios reintentos pasajeros, decirlo en la pantalla de unión o en la pestaña Grupos.
3. Dejarlo: el canario ya lo cuenta.

## Relación con otros tickets

- `groups-sync-reads-a-missing-attest-401-as-a-session-expiry` — de donde sale.
- `groups-phone-that-never-attests-is-told-to-retry-forever` — la causa que no se cura sola.
- `groups-join-intent-reconciler` — el diseño del intent y su canario.
