---
id: a-failed-snapshot-enqueue-save-leaves-the-journal-unsaved
status: backlog
priority: medium
area: "modo-nube, migración"
created: 2026-09-22
updated: 2026-09-22
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

## Relacionado

- `snapshot-upload-has-no-ceiling-and-no-way-out` — el techo que lo destapa.
