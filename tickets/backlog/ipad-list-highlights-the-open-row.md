---
id: ipad-list-highlights-the-open-row
status: backlog
priority: low
area: "ipad, records, planning, adaptativo"
updated: 2026-09-29
created: 2026-09-29
source: "fase 1 del carril adaptativo (ipad-sidebar-and-list-detail-for-records-and-planning), 2026-09-29"
---

# En iPad, la lista no marca qué registro o presupuesto está abierto al lado

## Qué pasa

Desde la fase 1, en una ventana ancha Registros y Planificación enseñan la lista y el detalle a la vez. Pero la fila
abierta no se distingue de las demás: si bajas por la lista, no sabes cuál es la que ves a la derecha. Las apps de
Apple (Mail, Notas) la dejan resaltada.

## Qué hacer

- Registros: `RecordsViewModel.openRecordID` ya dice cuál es. `RecordRowView` tiene `isSelected`, pero es la marca del
  modo selección (casilla), así que hace falta un estado propio, sutil, con los tokens del DS.
- Planificación: el presupuesto abierto lo lleva la pila de la columna de detalle (`navigationDestination`), no un
  estado; habría que subirlo a un estado para poder marcar la fila.
- Solo en ancho regular: en iPhone no hay columna y la fila no cambia.

## Hecho cuando

- Capturas en `YalaLane-Adapt-iPad-Pro-13` con un registro y un presupuesto abiertos.
- `YalaLane-Adapt-iPhone-SE` y `-ProMax`: sin diferencias.

## Relacionados

- [[ipad-sidebar-and-list-detail-for-records-and-planning]] — la fase que abrió el detalle al lado.
