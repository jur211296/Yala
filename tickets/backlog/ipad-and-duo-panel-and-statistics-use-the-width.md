---
id: ipad-and-duo-panel-and-statistics-use-the-width
status: backlog
priority: low
area: "panel, statistics, ipad, iphone-duo, adaptativo"
created: 2026-09-27
source: "plan adaptativo (docs/exploracion/adaptativo-ipad-duo.md §7 y §8, fase 2b), 2026-09-27; sale de la fase 2"
---

# iPad y Duo · fase 2b: el Panel y Estadísticas aprovechan el ancho

**Paso 8 de 13. Tamaño M. Después de la fase 1.** Sale de la fase 2 para que aquélla quede en lista-detalle e
inspector.

## Qué cambia para el usuario

En pantalla ancha (iPad, Duo abierto):

- **Panel**: la cabecera (saldo, acciones y «Tus finanzas») deja de comerse un tercio de la pantalla en horizontal;
  Últimos registros ocupa las dos columnas en vez de media fila con la otra media vacía.
- **Estadísticas · Resumen**: hoy es el iPhone estirado, con barras de 900 puntos para tres números. Las tarjetas
  pasan a rejilla de dos columnas.
- **Estadísticas · Tendencias**: sin comparación, gráfica e indicadores lado a lado, como ya hace con comparación.

Capturas del antes: `docs/exploracion/ipad-nativo/01`, `02`, `03`, `20`, `21`, `22`.

## Cómo

- Rejillas en **pares** (dos columnas), para que en el Duo a medio plegar el pliegue caiga entre dos (HIG · Designing
  for iPhone Duo). El Panel ya lo hace (`PanelWidgetsGrid.swift:24`).
- Cambiar de fila a rejilla con `AnyLayout` o con el contenedor, no con dos árboles por size class.

## Hecho cuando

- Capturas antes/después en `YalaLane-Adapt-iPad-mini` y `YalaLane-Adapt-iPad-Pro-13`, vertical y horizontal.
- En `YalaLane-Adapt-iPhone-SE` y `-ProMax`: sin diferencias (regla del iPhone).
- iPad redimensionado a ventana estrecha con Device Hub: vuelve a una columna sin perder la pestaña ni el período
  elegido.
- Duo a medio plegar, si ya existe `YalaLane-Adapt-iPhone-Duo`: ninguna tarjeta partida por el pliegue.
- Gate verde.

## Relacionados

- [[ipad-native-app]]. Depende de [[ipad-sidebar-and-list-detail-for-records-and-planning]].
- [[trends-insight-card-v2-bullets]] — ya prevé una columna en iPad ancho.

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
