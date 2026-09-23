---
id: drain-duplicates-the-unit-clock-when-its-row-cannot-be-read
status: in-progress
priority: high
area: "modo-nube, sync"
created: 2026-09-22
updated: 2026-09-23
source: "review adversarial de `apply-overwrites-a-pending-local-write-without-its-guards` (2026-09-22), lentes de tests e instancias gemelas"
---

# Si al guardar un cambio tuyo la app no puede leer su reloj interno, lo duplica y una transferencia puede quedarse con el importe viejo

## El problema, en lenguaje de usuario

Para decidir qué versión de una transferencia es la buena, la app guarda cuándo se tocó cada parte. Si al
capturar un cambio tuyo no consigue leer ese registro, crea uno nuevo al lado. Después puede leer el viejo, dar
por más nueva la pata equivocada y **pisar su importe**, y ese importe equivocado sube a la nube.

## Por qué pasa (leído el 2026-09-22; no ejecutado)

`SyncUnitClockStore.row` devuelve `nil` si el fetch lanza, y `upsert` lo lee como «no hay fila» ⇒ inserta un
segundo `SyncUnitClock` para el mismo `syncID` (sin `.unique`: CloudKit no lo permite). `delete` queda en no-op.
`CloudSyncReconciler.transferPair` lee luego una sola fila (`fetchLimit 1`, sin orden).

En `applyPage` quedó cerrado en `apply-overwrites-…` (variantes `upsertChecked`/`deleteChecked` que lanzan). Aquí
queda el DRAIN: `CloudSyncEngine.updateUnitClock` (llamado desde `drainOnce`, `enqueueSnapshotRows` y
`emitIdentityRemap`).

## Qué habría que decidir

- El `catch` de `drainOnce` **no hace rollback**: si se añade un `throw` nuevo a mitad del save, las filas de
  outbox ya insertadas quedan dirty y un autosave las flushearía bajo el autor por defecto. Arreglar eso primero
  (o a la vez) es condición para pasar el drain a `upsertChecked`.
- `emitIdentityRemap` comitea en la transacción del llamador: mirar qué hace su llamador con un `throw`.

## Criterios de aceptación

- [ ] Un fetch de `SyncUnitClock` que lanza en el drain no inserta un segundo reloj ni deja el tombstone sin limpiar.
- [ ] El drain que no se completa no deja filas dirty (rollback) y el token no avanza.
- [ ] Tests con el fetch lanzando + control positivo.
