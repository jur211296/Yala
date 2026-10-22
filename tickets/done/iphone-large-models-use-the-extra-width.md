---
id: iphone-large-models-use-the-extra-width
status: done
priority: low
area: "design-system, iphone, adaptativo"
created: 2026-09-27
updated: 2026-10-01
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

## Medido y propuesto (2026-10-01, antes de tocar)

Capturas de `2.1` en `f8c893cb3`, SE y Pro Max, texto por defecto y AX5 (`qa/evidencia-adaptativo-20261001/`).

| Pantalla | Qué deja vacío el Pro Max | Qué gana |
|---|---|---|
| Panel · Tendencias | la gráfica pasa de ~311 a ~376 pt de ancho con los mismos 170 pt de alto: sale aplastada | **más alta**, en proporción al ancho (≈200 pt) |
| Estadísticas · Tendencias | igual, en la gráfica de tendencia y en la de comparación | **más altas**, con la misma regla |
| Panel · carrusel de cuentas | dos tarjetas de ~198 pt | **nada**: tres saldrían a ~128 pt, bajo el mínimo de 140 pt del propio carrusel, y el carrusel viene plegado |
| Registros, Planificación | ya enseñan más filas por alto | **nada**: por ancho no hay qué añadir sin cambiar de sitio |

La regla: `alto = 170 × clamp(ancho de la gráfica / 320, 1, 1,2)`, solo en ancho compacto. En el SE la gráfica mide
menos de 320 pt, así que no cambia; en iPad (regular) tampoco.

## Resultado (2026-10-01)

- **Cambia**: en un iPhone grande, la gráfica de tendencia del Panel y las dos de Estadísticas › Tendencias (tendencia y
  Comparativa) salen ~30 pt más altas (170 → 200 en el Pro Max). Decide el ancho medido de la gráfica
  (`AdaptiveChartHeight`, `DS.Adaptive.chartHeight`), solo en ancho compacto.
- **No cambia**: el SE (diff píxel a píxel, por defecto y AX5: solo el punto animado «Hoy», la semilla y la barra de
  chips), el iPad, el carrusel de cuentas, Registros y Planificación. El porqué de cada uno, arriba.
- **Red**: `YalaTests/AdaptiveChartHeightTests` (7) y `AdaptiveNavigationUITests.test_panelTrendChart_…` /
  `test_statisticsTrendChart_growsWithTheWidth_onLargePhones`, verdes en SE, Pro Max e iPad mini; el mutante sin
  crecimiento los pone rojos en el Pro Max.
- **Evidencia**: `qa/evidencia-adaptativo-20261001/iphone-large-models-use-the-extra-width/`.

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
