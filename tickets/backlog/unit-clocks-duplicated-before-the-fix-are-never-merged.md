---
id: unit-clocks-duplicated-before-the-fix-are-never-merged
status: backlog
priority: low
area: "modo-nube, sync"
created: 2026-09-23
updated: 2026-09-23
source: "Paso 0 de `drain-duplicates-the-unit-clock-when-its-row-cannot-be-read` (2026-09-23)"
---

# Si un teléfono ya tiene dos relojes para el mismo movimiento, la app sigue sin saber cuál es el bueno

## El problema, en lenguaje de usuario

Desde el 23-sep la app ya no crea un segundo registro de «cuándo se tocó cada parte» cuando no consigue leer el
primero. Pero si un teléfono llegó a crear uno antes de ese arreglo, los dos siguen ahí: al decidir qué pata de una
transferencia es la más nueva, la app puede seguir leyendo el viejo y pisar el importe bueno.

## Por qué pasa (leído el 2026-09-23; no ejecutado)

- `SyncUnitClockStore.findRow` hace `fetchLimit = 1` sin orden, y lo mismo el lector del reconciler
  (`CloudSyncReconciler`, vía `unitHLC`). Con dos filas para un `syncID`, se lee una cualquiera.
- Los escritores (`upsertChecked`, `deleteChecked`, `prepareWrites`) actualizan o borran la fila que leen, así que
  la otra sobrevive: el tombstone deja un reloj vivo y el merge MAX no ve las unidades de la otra.

## Cuántos puede haber

Hacía falta que un `fetch` de SwiftData LANZARA en el drain (base ilegible), y ese fallo no se ha visto en producción.
Probablemente cero o casi cero teléfonos. Por eso `low`.

## Qué habría que decidir

- Fundir en los escritores (leer todas las filas del `syncID`, MAX por unidad en una, borrar el resto) o un barrido
  único al arrancar. Lo primero cura solo lo que se vuelve a tocar; lo segundo lo cura todo una vez.

## Criterios de aceptación

- [ ] Con dos `SyncUnitClock` para un `syncID`, tras el arreglo queda uno con el MAX por unidad de los dos.
- [ ] Un tombstone de ese `syncID` no deja ninguno.
