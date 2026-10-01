---
id: floating-buttons-cover-row-amounts-on-ipad-landscape
status: backlog
priority: medium
area: "design-system, records, planning, groups, ipad, cola-b"
created: 2026-09-26
updated: 2026-09-27
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

## iPhone Duo (2026-09-27)

Los botones flotantes son una vista propia, no botones de barra, y Apple no documenta qué pasa con ellos cuando en el
Duo la barra de pestañas se va al lateral. Lo mide la fase Duo ([[iphone-duo-native-app]]); aquí basta con que el
margen inferior sea relativo al área segura y no a una altura fija.

## Hecho cuando

- Capturas antes/después con la última fila visible por encima de los botones, en `YalaLane-Adapt-iPad-Pro-13`
  horizontal (Registros, Planificación, Grupos) y en `YalaLane-Adapt-iPhone-SE` y `-ProMax` al final del scroll, a
  tamaño por defecto y a AX5.
- Las pantallas con `fab_` en sus identificadores, todas revisadas y listadas aquí. Gate verde.

## Relacionados

- [[ipad-native-app]] — paraguas. [[fab-appears-without-animation]] — mismo botón.

## Reglas del carril adaptativo (obligatorias)

**Simulador** (Jürgen, 2026-09-27). Este carril usa simuladores dedicados creados con `xcrun simctl create` con
prefijo fijo `YalaLane-Adapt-` (p. ej. YalaLane-Adapt-iPhone-SE, YalaLane-Adapt-iPhone-ProMax,
YalaLane-Adapt-iPad-Pro-13, YalaLane-Adapt-iPad-mini) y los usa SIEMPRE por UDID (`-destination id=<UDID>`), nunca
por nombre genérico ni `booted`. Prohibido `simctl shutdown all`, `erase all`, `killall Simulator` o tocar
simuladores sin ese prefijo (los usa la sesión de Cola A en paralelo). DerivedData propio del worktree
(`-derivedDataPath .ddp`). Receta para crearlos: `docs/exploracion/adaptativo-ipad-duo.md` §6.2.

**iPhone** (Jürgen, 2026-09-27). Se permiten mejoras de adaptación en iPhone si no rompen flujos ni ponen en riesgo
la release 2.1; cada una verificable en simulador con capturas antes/después en tamaños iPhone pequeño/grande y
Dynamic Type grande (`adaptativo-ipad-duo.md` §6.1).

**Layout** (ADR «[2026-09-27] Yala se adapta por espacio, no por dispositivo»). Se decide por size class y ancho del
contenedor, nunca por tipo de dispositivo ni orientación; un contenedor que se adapta, no un `if` por size class en
la raíz; APIs de iOS 27.1 solo tras `if #available`.

## iPhone en horizontal (2026-10-01)

Desde el paso 11 del carril ([[iphone-supports-landscape-orientation]]) el iPhone gira, y pasa lo mismo: en el Pro Max
girado, el «+» de Planificación tapa el importe del primer presupuesto, y en Registros Yala IA y «+» caen sobre la
lista (`qa/evidencia-adaptativo-20261001/iphone-supports-landscape-orientation/despues/promax__03-planificacion-h.jpg`
y `promax__04-registros-h.jpg`). El arreglo de aquí lo cubre: el margen inferior por área segura vale en los dos.
