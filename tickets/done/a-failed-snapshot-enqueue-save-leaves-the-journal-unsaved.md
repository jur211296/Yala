---
id: a-failed-snapshot-enqueue-save-leaves-the-journal-unsaved
status: done
priority: medium
area: "modo-nube, migración"
created: 2026-09-22
updated: 2026-10-02
source: "review adversarial de `snapshot-upload-has-no-ceiling-and-no-way-out` (2026-09-22), lente de lógica del techo"
---

# Si al subir tus datos falla un guardado local, la app puede decir que se rindió sin haberlo guardado

## Cerrado el 2026-10-02: medido, ese guardado no puede fallar por sus filas

**Veredicto, en lenguaje de usuario:** el escenario no se da. El guardado del encolado solo puede fallar por algo que
tumba también el guardado de la tarjeta (disco lleno, el almacenamiento que no responde). En ese caso la app no puede
guardar nada, y deshacer las filas no cambiaría eso. Sin cambio de código; un test fija las dos premisas.

**Medido (no inferido):**

1. **Nada en las filas puede rechazarlas.** Ningún modelo de la app tiene `#Unique`/`.unique`, regla `.deny` ni
   validación (grep en `Yala/`). `SyncOutbox`, `SyncCursor`, `SyncUnitClock` y `SyncIdentity` no tienen relaciones, y
   todos sus atributos tienen valor por defecto.
2. **Otro escritor no hace fallar el guardado.** Con dos contextos sobre el mismo SQLite, el que guarda con una
   instantánea vieja de una fila que el otro **modificó** o **borró** no lanza: SwiftData resuelve el conflicto sin
   error, y el guardado siguiente (el del journal) pasa y llega a disco. Medido primero en macOS con un binario y
   fijado en iOS con `SnapshotEnqueueSaveFailurePremiseTests`. Además, en producción nadie más escribe el store
   sync-meta: el único otro contexto (`MigrationPhaseStore.journaledPhaseRead`) solo lee.
3. **Lo que queda comparte destino con el journal.** `MigrationState` vive en el MISMO store (`syncMetaSchema`) que
   `SyncOutbox`, `SyncCursor`, `SyncUnitClock` y `SyncIdentity`. Disco lleno, E/S o un store que desaparece tumban el
   guardado del journal igual, con rollback o sin él.

**Los tres productores, mismo veredicto:**

- **Subida del snapshot** (`MigrationSnapshotUploader` → `enqueueSnapshotRows`): solo filas sync-meta. Cerrado.
- **Identidad, 35 %** (`MigrationWorkExecutor.assignIdentity`): además escribe `syncID` en filas de dominio (store
  personal, con el espejo de iCloud vivo). El importador del espejo es otro contexto; su conflicto no lanza (pata 2 del
  test, con filas modificadas y borradas). Cerrado.
- **Backfill y huérfanas del adopt** (`runAdoptOrphanReconcile`: `backfillIdentities` + `enqueueSnapshotRows` en un
  guardado): la misma forma que la identidad. Cerrado, sin ticket residual.

**Por qué no se añadió un rollback acotado «por si acaso»:** no le devolvería el guardado al journal en ningún caso
alcanzable (punto 3), y si el fallo fuera pasajero, dejar las filas en el contexto hace que el guardado siguiente las
escriba juntas, con el reloj, que es la invariante lockstep D-3. Deshacerlas a mano reabriría esa invariante sin
ganar nada.

**Qué reabre esto:** que `MigrationState` salga del store sync-meta, que una tabla de estos tres caminos gane una
restricción, relación obligatoria o validación, o que SwiftData cambie su política de merge. El primero y el
último los caza el test, pero no el del medio: una restricción nueva no la ve (revisar este ticket al añadirla).

## El problema, en lenguaje de usuario

Al activar la nube, si el teléfono no consigue guardar la página que va a subir, la subida se para y, a los 15
minutos, la tarjeta dice «No pudimos activar la nube». Pero ese cambio de estado puede quedarse **solo en memoria**:
al cerrar y volver a abrir Yala, la barra vuelve a estar en 55 % como si nada. Y «Reintentar» tampoco se guarda.

**Inferido, no medido.** Lo dedujo una lente de la review leyendo el código; nadie lo ha reproducido.

## Por qué pasaría (leído el 2026-09-22 en este árbol)

- `CloudSyncEngine.saveWithAuthor` no hace `rollback()` cuando el `save()` lanza: las filas de `SyncOutbox` que
  `enqueueSnapshotRows` insertó se quedan en el contexto, sin guardar.
- El runner y el executor comparten ese `ModelContext` (`CloudMigrationController`, el `mainContext` en
  producción). El siguiente `save()` —el del journal en `MigrationRunner.handle`— intenta guardar también esas
  filas. Si el fallo era por ellas, falla igual.
- `runGuarded` se traga ese error. La fila del journal cacheada ya tiene la fase nueva, pero el disco no.

## Por qué no se arregló en el ticket del techo

- **Es anterior**: antes del techo, el mismo contexto sucio impedía guardar cualquier cosa del journal igualmente.
  El techo solo lo hace visible.
- **La salida obvia es peligrosa**: un `rollback()` sobre el `mainContext` podría tirar cambios sin guardar de la
  persona en otras pantallas. Hace falta decidir el alcance (un contexto propio para el encolado, o un
  `rollback` acotado a las filas insertadas).

## Criterios de aceptación

- [ ] Medir primero: ¿un `save` de `SyncOutbox` puede fallar por las propias filas, o solo por causas que tumban
      cualquier `save` (disco lleno)? Si es lo segundo, el ticket se cierra: no hay nada que la app pueda guardar.
- [ ] Si es lo primero: un `save` fallido del encolado no deja el contexto compartido sin poder guardar el journal.

## Un segundo productor de la misma clase: la identidad (35 %), desde el 2026-09-22

Lo cazó una lente de la review de `forward-migration-steps-have-no-ceiling-and-no-exit`, que le dio techo al paso
`assigningIdentity`. **Medido**: `MigrationWorkExecutor.assignIdentity` mete filas `SyncIdentity` y coordenadas en el
mismo `ModelContext` que el runner, y si su `context.save()` lanza nadie hace `rollback()`. El techo journalea con
`handle`, cuyo `save()` arrastra esos cambios. **Inferido** (semántica de Core Data): si el fallo era por esas filas, la
salida a `failedRollback` —con su motivo `localFailure`— se queda en memoria, la tarjeta de fallo sale igual (el
controller lee el mismo contexto), «Reintentar» tampoco se guarda y al relanzar vuelve a estar al 35 %.

No se decidió allí por la misma razón que aquí: la salida obvia es un `rollback()` sobre el `mainContext`. El
`SyncApplyEngine` ya lo hace tras sus propios saves fallidos, que es un precedente, pero el alcance sigue sin decidir.
Con el disco lleno, además, ningún `save()` pasa y no hay nada que decidir. **Al cerrar este ticket, mide también este
camino.**

## Lo que ya no entra por aquí, desde el 2026-09-23

`drain-duplicates-the-unit-clock-when-its-row-cannot-be-read` hizo que `enqueueSnapshotRows` lea los relojes por unidad
ANTES de insertar nada: si esa lectura falla, lanza con el contexto limpio. Queda solo el `save()` que falla, que es lo
que este ticket describe. El drain sí hace ya rollback de su propio save (el barrido previo deja el contexto sin nada
del usuario); el encolado del snapshot no puede copiarlo tal cual por la razón de arriba.

## Relacionado

- `forward-migration-steps-have-no-ceiling-and-no-exit` — el techo de la identidad, que añade el segundo productor.

- `snapshot-upload-has-no-ceiling-and-no-way-out` — el techo que lo destapa.

- `adopt-effect-retries-forever-with-no-ceiling` (2026-09-23) — un tercer productor: el backfill y el encolado de las
  huérfanas del adopt insertan antes de su `save()`. Si ese save lanza, el sello del reloj del efecto
  (`observeAdoptEffectFailure`) y su salida vuelven a escribir lo mismo y fallan igual, así que ni los 15 min ni las 72 h
  llegan a disco. Lo vio la lente de relojes; no se reprodujo.
