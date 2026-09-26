---
id: floating-buttons-cover-row-amounts-on-ipad-landscape
status: backlog
priority: medium
area: "design-system, records, planning, groups, ipad, cola-b"
created: 2026-09-26
source: "exploración iPad (docs/exploracion/ipad-nativo.md §4), 2026-09-26"
---

# En iPad en horizontal, los botones flotantes tapan los importes de las filas

**Entra en Cola B**: toca las mismas pantallas que el rediseño y es barato.

## Qué le pasa al usuario

En un iPad en horizontal, las filas ocupan todo el ancho y el importe queda pegado al borde derecho,
justo debajo de los botones flotantes. Medido en el simulador el 2026-09-26:

- **Registros**: Yala IA y «+» tapan el importe y la etiqueta de las filas de abajo
  (`docs/exploracion/ipad-nativo/27-pro13-horizontal-registros.jpg`).
- **Planificación**: el «+» tapa el importe de un presupuesto
  (`docs/exploracion/ipad-nativo/64-mini-horizontal-planificacion.jpg`).
- **Grupos**: el «+» tapa el importe de la última fila (`docs/exploracion/ipad-nativo/71-mini-grupos-detalle.jpg`).

## Qué hacer

Reservar sitio para los botones: margen inferior del contenido igual al alto de la pila de botones
(`contentMargins`/`safeAreaInset` en el scroll), para que la última fila pueda subir por encima. Con el
ancho legible de [[cola-b-redesigns-must-hold-up-at-ipad-width]] el importe ya no llega al borde, pero
el margen hace falta igual: en iPhone la última fila también queda debajo al final del scroll.

Buscar **todas** las pantallas con botón flotante antes de dar el arreglo por completo (`fab_` en los
identificadores).

## Relacionados

- [[ipad-native-app]] — paraguas. [[fab-appears-without-animation]] — mismo botón.
