---
id: reverse-upload-sample-walks-every-row-twice-on-the-main-thread
status: backlog
priority: low
area: "modo-nube, migración, rendimiento"
created: 2026-09-16
source: "segunda pasada de review de `reverse-upload-has-no-ceiling-and-no-exit` (2026-09-16), lente de código — H4"
---

# Mientras se espera la vuelta a iCloud, cada observación recorre dos veces todas las filas en el hilo principal

## El problema, en lenguaje de usuario

Con muchos movimientos, la pantalla «Dónde viven tus datos» puede engancharse un momento cada 30 s mientras espera
a que los datos lleguen a iCloud. No está medido en un iPhone: es lo que dice el código.

## Por qué pasa

`MigrationWorkExecutor.reverseUploadStatus()` (`MigrationWorkExecutor.swift:1051`) corre en el `MainActor` y hace
dos pasadas sobre las mismas filas:

1. `collectReverseUploadPairs()` (`:390`): 16 fetch completos, un testigo scratch por fila sin `SyncIdentity` y, en
   `CKIdentityCapture.capture`, una consulta SQLite y un `JSONEncoder` por fila.
2. `collectLiveByEntityName(context:)` (`:1067`, `:1079`): otros 16 fetch completos para el canario de metadata
   huérfana.

La pantalla lo dispara cada 30 s (`StorageSettingsView.swift:102`) y cada paso a primer plano. La segunda pasada
ya existía para los migrados; desde D15 (el muestreo cuenta todas las filas vivas) también la paga toda cuenta
nacida en la nube, que antes salía sin abrir SQLite.

## Arreglo propuesto

Construir `liveByEntityName` desde los `persistentModelID` de la primera pasada, manteniendo las 16 claves aunque
vengan vacías (contrato RP-4 de `collectLiveByEntityName`). `collectLiveByEntityName` se queda para el panel
DEBUG. Un test de paridad entre las dos construcciones fija que cuentan lo mismo.

## Criterios de aceptación

- [ ] Medido en device cuánto dura una observación con un corpus grande, antes y después.
- [ ] Una sola pasada de fetch por observación, con la paridad fijada por test.

## Relacionado

- `reverse-upload-has-no-ceiling-and-no-exit` (D15) · `reverse-upload-sample-reads-unreadable-rows-as-drained`.
