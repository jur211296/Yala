---
id: groups-loop-in-backoff-ignores-the-return-to-foreground
status: backlog
priority: low
area: "groups, sync"
created: 2026-09-15
updated: 2026-09-15
source: "review adversarial de `groups-push-reads-an-offline-token-refresh-as-a-session-expiry` (2026-09-15)"
---

# Volver a Yala no adelanta la subida de grupos que espera su reintento

## El problema, en lenguaje de usuario

Me quedo sin red un rato con la app abierta, salgo, recupero la conexión y vuelvo a Yala. Los cambios de mis grupos no
suben al volver: pueden tardar hasta cinco minutos, salvo que guarde algo o tire hacia abajo para refrescar.

## Lo medido (leído en el código, sin ejecutar)

- Tras un fallo pasajero, el loop de Grupos duerme con un backoff creciente de 5, 10, 20… hasta 300 s
  (`SyncCadencePolicy.backoffDelay`).
- Volver a primer plano llama a `GroupsSyncClient.startIfEligible(context:trigger: "foreground")`
  (`AppBootstrapper`), pero con el loop vivo `GroupsLoopRestartLogic.shouldStart` devuelve `false` y no pasa nada: el
  sueño no se interrumpe.
- El runtime personal sí lo hace: su `handleBecameActive` cancela el sueño y corre un ciclo en el acto.
- Sin red y con la sesión vigente ya pasaba. Desde el 2026-09-15 pasa también con el token caducado: hasta entonces ese
  caso mataba el loop, y volver a primer plano lo re-arrancaba en el momento.
- Y con App Attest ausente, también desde el 2026-09-15 (`groups-sync-reads-a-missing-attest-401-as-a-session-expiry`):
  su 401 paraba el loop y volver a primer plano lo re-arrancaba; ahora espera en backoff, hasta 5 min.

## Lo que hay que decidir (Jürgen)

1. Despertar el loop al volver a primer plano (cortar el sueño y ciclar ya), como hace el runtime personal.
2. Dejarlo: los cambios suben solos en el siguiente reintento.

## Relación con otros tickets

- `groups-push-reads-an-offline-token-refresh-as-a-session-expiry` — el cambio que lleva este caso a más gente.
