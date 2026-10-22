---
id: prefs-outbox-reads-an-unreadable-file-as-corrupt-and-overwrites-it
status: done
priority: medium
area: "modo-nube, sync, preferencias"
created: 2026-09-23
updated: 2026-09-26
qa-status: not-replicable
qa-date: 2026-09-26
qa-notes: un fallo de lectura del archivo no se puede provocar en un iPhone sin herramientas; lo fijan los unit con permisos 000 sobre el archivo real
source: "review adversarial de `drain-duplicates-the-unit-clock-when-its-row-cannot-be-read` (2026-09-23), lente de gemelos"
---

# Si el teléfono no consigue leer tus preferencias pendientes de subir, las borra

## El problema, en lenguaje de usuario

Los cambios de preferencias que aún no subieron a la nube esperan en un fichero. Si un día la app no consigue
leerlo —no porque esté roto, sino porque la lectura falla—, lo trata como basura, empieza uno vacío encima y esos
cambios no llegan nunca a tus otros dispositivos.

## Por qué pasa (leído el 2026-09-23; inferido, no ejecutado)

- `PrefsOutbox.loadOrCreateState` (`Yala/Services/CloudSync/PrefsOutbox.swift`) mete en el mismo `catch` el fallo de
  `Data(contentsOf:)` y el de `JSONDecoder().decode`: los dos acaban en «corrupto → estado nuevo».
- El siguiente `enqueue` o `setPullCursor` escribe ese estado nuevo encima: se pierden las filas pendientes y se
  resetean el `nodeID` y el reloj (que desempata el LWW).
- El docblock solo contempla la corrupción.

## Criterios de aceptación

- [x] Un fallo de LECTURA del fichero no lo sobrescribe: se reintenta más tarde sin encolar ni escribir.
- [x] La corrupción (decode) conserva el trato actual, con test de las dos ramas y control positivo.

## Resuelto (2026-09-26)

- `PrefsOutbox` separa lectura y decode (`readState`). Un archivo que no se deja leer lanza `.readFailed`: ni `enqueue` ni
  `setPullCursor` escriben encima, y las pendientes, el `nodeID` y el reloj se conservan byte a byte.
- El ciclo de prefs del runtime (el camino equivalente) lee con `syncSnapshot`, que también lanza: con el archivo
  ilegible no hace push ni pull. Antes bajaba todo desde el cursor 0 y el merge revertía en pantalla los cambios
  pendientes.
- La corrupción conserva el trato de siempre (estado nuevo), con tests de control.
- Residual con ticket: el cambio hecho en ese instante no se encola (`prefs-change-is-dropped-when-the-outbox-cannot-take-it`).
- Regla: «Y el outbox de preferencias tampoco» en `.claude/rules/swiftdata-cloudkit.md`.
