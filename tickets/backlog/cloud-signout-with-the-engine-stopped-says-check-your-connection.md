---
id: cloud-signout-with-the-engine-stopped-says-check-your-connection
status: backlog
priority: medium
area: "modo-nube, cierre de sesión, migración"
created: 2026-09-25
updated: 2026-09-25
source: "review adversarial de `sign-out-push-all-runs-a-sync-cycle-past-the-migration-gate` (2026-09-25)"
---

# Cerrar sesión con la sincronización parada dice «revisa tu conexión», y la salida es otra

## El problema, en lenguaje de usuario

Si la sincronización con la nube está parada a propósito —abriste una versión anterior de Yala que no entiende en qué punto
iba el cambio a la nube, o una vuelta a iCloud falló y no le diste a «Reintentar»— y tienes cambios sin subir, «Cerrar
sesión» se bloquea (bien: no se pierden). Pero el aviso te dice que revises tu conexión. La conexión no tiene nada que ver
y reintentar no cambia nada. Lo que te saca de ahí es actualizar Yala, o «Reintentar» en Almacenamiento.

## Medido (2026-09-25)

- Desde `sign-out-push-all-runs-a-sync-cycle-past-the-migration-gate`, con el candado del motor cerrado el push-all del
  cierre devuelve `.blocked(_, .permanent)` (`CloudSignOutFlowLogic.pushAllVerdictWithoutEngine`): con filas en el outbox,
  o con ediciones en el History que el motor no capturó (entonces la cifra es `Int.max`).
- El paso 1 de `CloudSessionSignOut.performCloudSecureSignOut` enseña `.permanent` con el texto de
  `L10n.Settings.signOutBlockedMessage` («Revisa tu conexión e inténtalo de nuevo»).
- Mismo colapso de familia que `cloud-signout-collapses-the-personal-push-all-reason-into-permanent`, pero con una causa que
  ese ticket no nombra: ahí el motivo existe y se tira; aquí no hay motivo que viaje.

## Qué habría que decidir (producto)

- El texto de este bloqueo y a dónde manda (Almacenamiento, actualizar Yala).
- Si con el journal ilegible se ofrece además exportar los movimientos antes de cerrar.

## Criterios de aceptación

- [ ] Con el motor parado por el candado, el aviso del cierre no habla de la conexión y nombra la salida real.
