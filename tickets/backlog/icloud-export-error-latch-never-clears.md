---
id: icloud-export-error-latch-never-clears
status: backlog
priority: medium
area: "modo-nube, sync"
created: 2026-09-10
source: "review adversarial de la primera pasada de `groups-entry-on-a-mirrored-store-still-blocks-the-owner` (2026-09-10); rescatado a `2.1` el 2026-09-11 — vivía solo en una rama sin PR"
---

# Un export con éxito no limpia `lastExportError`, así que un blip de red envenena el resto del proceso

## Lo medido (re-comprobado el 2026-09-11 sobre `d723f1f4`)

`iCloudSyncService.lastExportError` se ESCRIBE en un único sitio de producción
(`iCloudSyncService.swift:371`, al clasificar un evento fallido) y **no se limpia en ninguno**: los dos
sitios que lo ponen a `nil` o lo fabrican son `_testReset()` (`:689`) y `_qaSimulateFailed` (`:715`).

O sea que un fallo transitorio —modo avión de treinta segundos, un túnel— deja el latch puesto **hasta
que el proceso muere**, aunque después suban mil cambios sin un solo error.

## A quién le importa

Dos consumidores lo leen como si fuera el estado ACTUAL:

- `iCloudSyncService.swift:482` — `hasFailureHistory = consecutiveFailures > 0 || lastExportError != nil`
- `MigrationWorkExecutor.swift:251` y `:765` → `ICloudCutoverGateLogic`, que clasifica el atasco del
  cutover por el último código de error visto.

El segundo es el caro: la clasificación `definitive` / `unknown` decide un presupuesto de 900 s frente a
259 200 s, y un error viejo la empuja al lado corto.

**Tercer lector desde el 2026-09-16, y ese ya NO lo lee como estado actual:** la espera de «Volver a iCloud»
(`ReverseUploadBlockerLogic`, ticket `reverse-upload-has-no-ceiling-and-no-exit`) decide con él el techo, el copy de
la pantalla y el motivo guardado de la salida. Para no heredar el latch, `iCloudSyncService` gana
`lastExportErrorAt` (la fecha del evento que falló, aditiva) y la reversa solo cree el error si es posterior a
`lastSuccessfulExportDate`. El latch en sí y los otros dos lectores siguen igual: ese es el alcance de este ticket, y
esa misma fecha es una vía para cerrarlo sin cambiar el banner.

## Lo que NO es

No es lo mismo que `icloud-sync-status-treats-non-ck-failures-as-success`, que va de eventos que
TERMINAN con un error de otro dominio y cuentan como éxito. Aquí el evento se clasificó bien: lo que
falla es que su rastro no caduque.

## Criterios de aceptación

- [ ] Un export con éxito posterior limpia el latch (o los consumidores dejan de leerlo como estado
      actual y pasan a leer una marca con fecha).
- [ ] `ICloudCutoverGateLogic` no clasifica por un error anterior al último éxito.
- [ ] Test con un fallo seguido de un éxito que hoy quedaría verde con el latch puesto.
