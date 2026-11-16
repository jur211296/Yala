---
id: records-bulk-selection-undo-and-counts
status: done
priority: medium
area: "records, bulk-edit"
created: 2026-11-09
updated: 2026-11-11
card: tablero-2-3-seleccion-en-lote-en-registros-con-d-wz9n
source: "revisión 2.3 por vistas, zona 31 (Registros), decisiones 18 y 75 del 9-nov"
---

# Registros: el lote se puede deshacer y dice cuánto es

«Seleccionar todo» marcaba los 2.334 registros del período y borrarlos preguntaba «Esta acción no se puede deshacer»;
un cambio en lote tampoco tenía «Deshacer», cuando borrar un registro sí lo tenía. Los recuentos salían sin separador de
miles («2334 seleccionados») y la edición masiva decía «Hoy: 3 subcategorías distintas», que parece una fecha.

Decidido el 9-nov (opción E1 + E2, y la 75): «Deshacer» también en lote, con el mismo aviso que el borrado de uno, y
textos que dicen cuánto es («Seleccionar los 2.334», la pregunta con fechas e importe, «Seleccionar día»); «Ahora:» en
vez de «Hoy:».

## Hecho cuando

Se puede deshacer un borrado en lote, los totales llevan separador de miles y el texto de edición masiva no dice «Hoy».

## Resolución (2026-11-11)

- Borrar lo elegido pasa por el borrado diferido de un registro (`RecordPendingDeletion.requestBatch`): nada toca la
  base hasta que vence el aviso, así que «Deshacer» no sube nada a iCloud. Al vencer, un solo guardado.
- Editar en lote guarda una foto del antes (`RecordBulkEditUndo`) y el aviso «N registros ahora son X · Deshacer» la
  devuelve a los registros que nadie cambió después.
- Medido con 3.000 registros (simulador, Debug): la foto del antes 0,04 s; aplicar el lote 6,7 s y deshacerlo 6,2 s
  (el coste es el guardado de SwiftData, igual que antes en los dos sentidos); pedir el borrado 0,04 s.
- Tests: `RecordsBulkUndo23Tests`, `RecordsBulkUndo23TextosTests`, `RecordsBulkUndo23UITests`.
