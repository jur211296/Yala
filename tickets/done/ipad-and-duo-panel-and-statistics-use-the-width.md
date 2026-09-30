---
id: ipad-and-duo-panel-and-statistics-use-the-width
status: done
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
- **Estadísticas · Registros** (el chip): el detalle de un registro sigue saliendo en hoja, también en ancho. La
  fase 1 lo resolvió en la página Registros (`RecordsStandaloneView`, columna de detalle) pero no aquí: el chip vive
  dentro de `DetailContainerView`, que no tiene split, y su hoja encadena el editor al cerrarse
  (`DetailContainerView.swift`, `showTransactionDetail`). Mismo molde: `RecordsViewModel.opensDetailInColumn`.

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

## Cierre (2026-09-30)

Qué cambia para el usuario, en pantalla ancha (iPad, Duo abierto); en iPhone no cambia nada:

- **Panel**: la cabecera va en dos columnas —saldo y acciones a la izquierda, «Tus finanzas» a la derecha— y los avisos
  debajo. En el iPad Pro 13 en horizontal pasa de ~290 a ~180 pt, y Últimos registros asoma en la primera pantalla.
  Últimos registros ocupa la fila entera con sus cinco filas en pares. El carrusel de cuentas enseña dos tarjetas en
  media columna (cuatro solo si caben).
- **Resumen**: [Salud financiera · Resumen inteligente], [Promedio diario · las cuatro cifras], [Compromisos · Por
  necesidad]; en Observaciones, las tarjetas en pares.
- **Tendencias**: todas las tarjetas en pares; sin comparación, la tendencia va al lado del flujo de efectivo.
- **Registros (chip)**: el registro se abre en un panel al lado de la lista, con X y Editar (Editar abre el editor
  directo). Si no caben lista y panel (iPad mini en vertical, Yala IA al lado), el panel tapa la lista y la X la
  devuelve. Al estrechar a compacta con uno abierto, pasa a la hoja de siempre.

Cómo: `PairedCardsStack` / `PairedColumnsLayout` y `HeaderBandLayout` (`Views/Shared/PairedColumnsLayout.swift`),
con `AnyLayout` para que en compacta sea el `VStackLayout` de siempre. Detalle y trampas en `swiftui-ds.md`,
«Layout adaptativo: rejillas en pares».

Verificado:

- Capturas antes/después en los cuatro Adapt, iPad en las dos orientaciones:
  `qa/evidencia-adaptativo-20260930/ipad-and-duo-panel-and-statistics-use-the-width/`.
- iPhone SE y Pro Max, texto por defecto y AX5: sin diferencias de layout (diff al píxel, detalle en el README).
- Redimensionado: `AdaptiveNavigationUITests.test_narrowingTheWindow_onStatistics_…` en el iPad Pro 13 con «Apps en
  ventanas» — estrechar conserva chip y período, volver a ancho también, y el registro abierto pasa a la hoja.
- Tests nuevos: `PairedColumnsLogicTests` (columnas, filas, colocación y banda), cinco casos en
  `WidgetConfigManagerTests`, y cuatro en `AdaptiveNavigationUITests` (banda del Panel, Resumen en pares, registro
  en panel / en hoja, estrechar en Estadísticas).

Queda fuera: el **Duo a medio plegar** (no hay simulador del Duo en esta Mac) va con `iphone-duo-native-app`.

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
