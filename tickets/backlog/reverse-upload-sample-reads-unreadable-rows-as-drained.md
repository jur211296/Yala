---
id: reverse-upload-sample-reads-unreadable-rows-as-drained
status: backlog
priority: medium
area: "modo-nube, migración"
created: 2026-09-16
updated: 2026-09-23
source: "medición de `reverse-upload-has-no-ceiling-and-no-exit` (2026-09-16)"
---

# Si el muestreo de la subida no puede leer las filas, la vuelta a iCloud se da por terminada

## El problema, en lenguaje de usuario

Pulso «Volver a iCloud» y la vuelta termina bien: la app queda en modo privado. Pero mis datos no llegaron a
iCloud. La pantalla dijo que sí porque la comprobación no pudo mirar y lo contó como «nada pendiente».

## Por qué pasa (medido en el código)

`MigrationWorkExecutor.reverseUploadStatus()` decide `pending = report.exportPending + report.noMetadata`. Las
filas `failed` **no cuentan**, y quedan tres caminos que las producen o vacían el muestreo:

- `CKIdentityCapture.captureResolved`: si SQLite no abre, o no encuentra la tabla de metadata, o faltan las
  columnas, marca TODAS las filas `failed` ⇒ `pending == 0` ⇒ `.drained`.
- ~~`addReverseUploadPairs`: si el fetch de un tipo de entidad lanza, sus filas no entran en el muestreo.~~
  **Cerrado el 2026-09-23** en `an-incomplete-inventory-reads-as-the-whole-corpus`: ese fetch LANZA y la muestra sale
  `.unreadable`, que ni cierra la vuelta ni cuenta como avance. Queda lo de las filas `failed`, que sigue pidiendo medir.
- Fallos por fila (`no-zent`, `zone-fk-missing`…): no cuentan.

**Ya NO es un camino (arreglado el 2026-09-16 en `reverse-upload-has-no-ceiling-and-no-exit`, D15):** las filas
vivas sin testigo `SyncIdentity`. Era el caso ESTRUCTURAL —todo lo creado en el teléfono por una cuenta nacida en
la nube, es decir, casi toda la población tras el fresh start—, y lo cazó la review adversarial de ese ticket.
Ahora el muestreo las empareja con un testigo scratch sin insertar, y un fallo del fetch de `SyncIdentity` ya no
vacía el muestreo.

Es un gate que falla ABIERTO por su entrada: «no pude leer» se lee como «no queda nada». Con `.drained` la
reversa corre el cuarteto de cierre —borra el marcador, limpia el faro, persiste `.icloud`,
`reverse_complete`— y la nube de Yala queda congelada con la última copia verificada.

## Cuánto pasa

No medido. El caso más probable de observarlo es el de un teléfono sin cuenta de iCloud: si el mirror
`.automatic` no crea las tablas de metadata, todas las filas salen `failed` y la vuelta «termina» sin
iCloud. Si las crea, salen `noMetadata` y la espera espera (lo que atiende el techo). El guion de device de
`reverse-upload-has-no-ceiling-and-no-exit` lo mira de paso, en su paso 2.

## Por qué no se tocó en el ticket del techo

Contar `failed` como pendiente es una línea, pero cambia el comportamiento para una población que no se
puede medir desde aquí: si hay filas `failed` por un motivo benigno y permanente, la vuelta no drenaría nunca
y cada intento acabaría en el techo. Hay que medir antes qué `failed` aparecen en un device real.

## Criterios de aceptación

- [ ] Medido en device qué motivos de `failed` aparecen durante una reversa real.
- [ ] Un muestreo que no pudo leer NO devuelve `.drained`.
- [ ] Test con mutante: devolver la suma vieja pone el caso en rojo.

## Relacionado

- `reverse-upload-has-no-ceiling-and-no-exit`.
- `.claude/rules/swiftdata-cloudkit.md` — `isMarkerExported()` es necesaria-no-suficiente por lo mismo.
