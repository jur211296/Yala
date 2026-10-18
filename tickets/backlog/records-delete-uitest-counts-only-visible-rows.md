---
id: records-delete-uitest-counts-only-visible-rows
status: backlog
priority: medium
area: testing, records
created: 2026-10-18
updated: 2026-10-18
source: gate de la implementación UX 2.2 · lotes 11 y 16 (encargo 2026-10-18-implementar-2-2-l11-l16-estadisticas-y-ajustes)
---

# `RecordsLote8UITests` da por no borrado un registro que sí se borró (cuenta filas visibles)

## Medido (2026-10-18, iPhone 17 Pro, iOS 27.0, `Yala Dev`)

- `test_detail_deleteAsksNamingTheRecord_cancelKeepsIt_deleteRemovesIt` cae en `RecordsLote8UITests.swift:85`:
  «("12") is not less than ("12") - El registro sigue en la lista». El detalle sí se cierra tras «Eliminar».
- Rojo en la batería completa del gate (centinela «estuviste solo»), rojo aislado, y **rojo en `origin/2.2` limpio**
  (`2776b307e`): no lo trae el cambio de los lotes 11 y 16.

## Hipótesis (sin medir)

`rowCount` cuenta `record_row` en el árbol, y la lista es perezosa: si la semilla tiene más registros de los que caben,
al borrar uno entra otro y el número no baja. Si es eso, el test tiene que comprobar que el registro borrado (por su
etiqueta) ya no está, no el recuento.

## Hecho cuando

El caso distingue «se borró» de «no se borró» con cualquier tamaño de semilla, y pasa en `2.2`.
