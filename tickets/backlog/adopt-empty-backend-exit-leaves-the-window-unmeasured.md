---
id: adopt-empty-backend-exit-leaves-the-window-unmeasured
status: backlog
priority: low
area: "modo-nube, migración"
created: 2026-10-05
updated: 2026-10-05
source: "review adversarial (lente de exactitud) de `adopt-window-uploads-what-reaches-the-mirror-after-the-icloud-check`, 2026-10-05"
---

# La salida del adopt por backend vacío arma la nube sin ventana: lo que el espejo baje después sube sin contarse

## El problema, en lenguaje de usuario

Activo la nube en este iPhone con una cuenta que existe pero está vacía. Mi iCloud dice que no tiene nada que probar, así
que entra. Antes de reabrir, el espejo baja finanzas de iCloud (otro dispositivo, u otro Apple ID). Al reabrir, todo eso
sube a la cuenta en la nube, y el canario que mide justo esto no lo ve.

## Lo medido (2026-10-05, en el código)

- `MigrationWorkExecutor.runAdoptOrphanReconcile`: con el backend enumerado vacío y algo que subir (los tipos de cambio
  sembrados del arranque bastan), sale por `abortedEmptyBackend` y BORRA lo que el backend conocía y el camino de entrada
  (`clearAdoptBackendKnown`). No deja la marca del adopt.
- `runAdoptFlow` trata `.abortedEmptyBackend` como `.completed`: sigue al paso 3 y persiste `.cloud`.
- Sin `….backend-known` ni marca de retirada no hay ventana: el canario `cloudAdoptLateImportUnproven` no cuenta, y el
  drain tras relanzar sube lo que el espejo bajó después del paso 3.
- Inferido, sin medir: cuántas cuentas `existing_stable` tienen el backend vacío (el comentario del guard dice que un
  adopt legítimo implica backend poblado).

## Opciones, sin decidir

- Que esa salida también deje la marca del adopt con una lista vacía y su camino: el drain no saltaría nada (nada es
  conocido) y el canario contaría. Toca el ciclo de vida que ajustó `adopt-window-late-imports-overwrite-newer-cloud-edits`.
- Decidirlo junto con la política de `adopt-window-uploads-what-reaches-the-mirror-after-the-icloud-check`.

## Relación

- Sale de `adopt-window-uploads-what-reaches-the-mirror-after-the-icloud-check`.
