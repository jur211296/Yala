---
id: drain-duplicates-the-unit-clock-when-its-row-cannot-be-read
status: done
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

- [x] Un fetch de `SyncUnitClock` que lanza en el drain no inserta un segundo reloj ni deja el tombstone sin limpiar.
- [x] El drain que no se completa no deja filas dirty (rollback) y el token no avanza.
- [x] Tests con el fetch lanzando + control positivo.

## Resuelto (2026-09-23)

- **Leer antes de escribir.** El drain, `enqueueSnapshotRows` y `emitIdentityRemap` pasan por
  `SyncUnitClockStore.prepareWrites`, que lee el reloj de cada `syncID` del lote y lanza ANTES de insertar nada.
  `upsert`/`delete` tolerantes, retirados.
- **Rollback del drain en los pasos 6-7**, no en el `catch` general (el barrido guarda lo del usuario antes). Si falla el
  save del outbox se retira también su espejo del App Group.
- **`drainOnce` devuelve si terminó** (hallazgo medio de la review, en el propio fix): con el rollback, las filas de un
  drain abortado ya no quedaban ni sucias, y el pull aplicaba la página con el guard D-1 sin la edición. El pull, la
  cuarentena del arranque, la verificación, el líder, el drenaje de la vuelta y el snapshot no siguen si no terminó.
- A `done` sin device-QA: una base local ilegible no se provoca en un iPhone.
- Tests: `DrainUnitClockUnreadableTests` (10), un caso en `SyncApplyEngineTests` y otro en `IdentityRemapEmissionTests`.
  15 mutantes, todos muertos. Regla: `.claude/rules/swiftdata-cloudkit.md`, «Y el drain tampoco (2026-09-23)».
- Tickets nuevos: `unit-clocks-duplicated-before-the-fix-are-never-merged`,
  `clock-drift-aborted-drain-lets-the-pull-overwrite-untranslated-edits`,
  `first-drain-cursor-creation-saves-pending-edits-under-the-engine-author`,
  `groups-drain-has-no-rollback-and-keeps-the-mirror-of-a-failed-save`,
  `identity-uuid-repair-can-commit-half-done-after-a-read-failure`,
  `prefs-outbox-reads-an-unreadable-file-as-corrupt-and-overwrites-it`.
