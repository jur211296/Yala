---
id: iphone-large-models-use-the-extra-width
status: backlog
priority: low
area: "design-system, iphone, adaptativo"
created: 2026-09-27
source: "plan adaptativo (docs/exploracion/adaptativo-ipad-duo.md §7, fase iPhone), 2026-09-27"
---

# iPhone · que los modelos grandes enseñen más, sin cambiar nada de sitio

**Fase iPhone del carril adaptativo, paso 10 de 13. Tamaño S.** Tras [[iphone-large-text-sizes-break-layouts]] y
[[iphone-small-screens-and-safe-areas-audit]], que van primero porque arreglan cosas; ésta solo aprovecha.

## Qué le pasa al usuario

Hoy un iPhone Pro Max enseña lo mismo que un iPhone normal, solo más grande: el carrusel del Panel siempre muestra
dos cuentas (`AccountsCarouselView.swift:23`, cuatro solo en ancho regular), y las gráficas tienen alturas fijas.
**No es un fallo**: es margen que se desaprovecha.

## Qué hacer

1. Comparar capturas de `YalaLane-Adapt-iPhone-SE` y `YalaLane-Adapt-iPhone-ProMax` en Panel, Registros,
   Estadísticas y Planificación. Anotar dónde el Pro Max deja espacio vacío.
2. Proponer en el ticket, antes de tocar, qué gana cada pantalla. Solo cambios de **cantidad** (una tarjeta más a la
   vista, una gráfica algo más alta), nunca de **sitio** ni de función.
3. Decidir por el ancho del contenedor (`onGeometryChange`), no por el modelo de iPhone.

## Hecho cuando

- Capturas antes/después en los dos iPhone, a tamaño por defecto y a AX5. En el SE, sin diferencias.
- XCUITest de las áreas tocadas en verde, por UDID. Gate verde.

## Relacionados

- [[ipad-native-app]] — paraguas.

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
