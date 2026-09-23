---
id: a-failed-snapshot-enqueue-save-leaves-the-journal-unsaved
status: backlog
priority: medium
area: "modo-nube, migración"
created: 2026-09-22
updated: 2026-09-23
source: "review adversarial de `snapshot-upload-has-no-ceiling-and-no-way-out` (2026-09-22), lente de lógica del techo"
---

# Si al subir tus datos falla un guardado local, la app puede decir que se rindió sin haberlo guardado

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
