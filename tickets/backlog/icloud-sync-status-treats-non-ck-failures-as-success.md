---
id: icloud-sync-status-treats-non-ck-failures-as-success
status: backlog
priority: low
area: "modo-nube, sync"
created: 2026-09-11
updated: 2026-10-08
source: "review adversarial del paso 9 (`session-exits-one-verb-per-session`), lente de pérdida de datos"
---

# Un evento del espejo que falla con un error que no es de CloudKit cuenta como un éxito

## Lo medido (2026-09-11)

`iCloudSyncService.handleContainerNotification` pasa `event.error as? CKError` a `apply`. Un evento que
TERMINA con un error de otro dominio —los `NSCocoaErrorDomain` 1344xx del propio espejo— llega con
`error == nil` y con fecha de fin, y cae en la rama de éxito: `lastSuccessfulImportDate`,
`lastSuccessfulExportDate`, `consecutiveFailures = 0`, el estado `.success` y, en un import,
`hasCompletedFirstImport = true`.

El paso 9 cortó solo sus dos piezas con `Event.succeeded`: el ancla del export y
`mirrorReportedNotAuthenticated`. El resto se dejó igual a propósito, porque `hasCompletedFirstImport`
abre las puertas de quiescencia de varios `save()` y cambiarlo sin medir podía dejar puertas cerradas para
siempre.

## Lo que hay que mirar

- Qué eventos terminan con `succeeded == false` y un error de Cocoa en device (setup sin cuenta, import con
  el store bloqueado).
- Qué consumidores de `hasCompletedFirstImport` y del estado se quedarían esperando si esos eventos dejaran de
  contar como éxito.

## Criterios de aceptación

- [ ] Un evento con `succeeded == false` no cuenta como éxito en ningún campo, o se documenta por qué uno sí.
- [ ] Ninguna puerta de quiescencia queda cerrada para siempre por el cambio (test por consumidor).

## Medido en 2.1 (triage 2026-10-08)

- `iCloudSyncService.apply`: `consecutiveFailures = 0` y `hasCompletedFirstImport = true` siguen en la rama de fin sin condicionar a `succeeded`; solo `mirrorReportedNotAuthenticated` y el ancla del export lo miran. El docblock de `apply` todavía cita este ticket como pendiente.
- Ningún commit posterior al 2026-09-11 sobre `iCloudSyncService.swift` cambió esa rama (los cinco que lo tocan son de Restaurar y de la vuelta a iCloud).

Triage 2026-10-08: abierto · low → low · `iCloudSyncService.apply` sigue poniendo `consecutiveFailures = 0` y `hasCompletedFirstImport = true` sin mirar `succeeded`; solo el ancla y `mirrorReportedNotAuthenticated` lo miran.
