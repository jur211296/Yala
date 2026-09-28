---
id: iphone-small-screens-and-safe-areas-audit
status: backlog
priority: medium
area: "design-system, iphone, adaptativo"
created: 2026-09-27
source: "plan adaptativo (docs/exploracion/adaptativo-ipad-duo.md §3 y §7, fase iPhone), 2026-09-27"
---

# iPhone · en la pantalla más pequeña, que nada quede tapado ni cortado

**Fase iPhone del carril adaptativo, paso 3 de 13. Tamaño S–M.** Puede entrar en 2.1 si cumple la regla del iPhone.

## Qué le pasa al usuario

Nadie lo ha mirado en un iPhone SE, que es el más bajo (sin Dynamic Island y con botón de inicio) y el más estrecho.
Lo mismo vale para el Duo cerrado, que Apple describe como más ancho y más bajo que un iPhone normal. **Sin síntoma
reportado:** es una auditoría, y lo que encuentre es el trabajo.

## Lo medido (2026-09-27, este árbol)

- 29 `ignoresSafeArea`.
- 24 alturas fijas de 200 puntos o más (`.frame(height:)`).
- Dos cuadrados fijos: 300×300 (`SubscriptionView.swift:153`) y 320×320 (`SplashScreenView.swift:63`).

## Qué hacer

1. Recorrer en `YalaLane-Adapt-iPhone-SE` las mismas diez pantallas de
   [[iphone-large-text-sizes-break-layouts]], más la suscripción y los formularios con teclado (Nuevo registro,
   presupuesto, cuenta).
2. Buscar: contenido debajo de la barra de estado o del indicador de inicio, botones que el teclado tapa, alturas
   fijas que dejan cortada una gráfica o un texto, scroll que no llega al último elemento.
3. Revisar los 29 `ignoresSafeArea`: se queda el que sea un fondo; se va el que meta contenido o controles bajo el
   borde.
4. Arreglar lo barato (márgenes, `safeAreaInset`, alturas relativas). Lo que cambie la estructura de una pantalla →
   ticket aparte.

## Hecho cuando

- Capturas antes/después en `YalaLane-Adapt-iPhone-SE` y `YalaLane-Adapt-iPhone-ProMax`, a tamaño por defecto y a
  AX5, en `qa/evidencia-adaptativo-AAAAMMDD/iphone-small-screens-and-safe-areas-audit/`.
- Lista de lo encontrado en el propio ticket: arreglado aquí o con su ticket.
- XCUITest de las áreas tocadas en verde, por UDID. Gate verde.

## Relacionados

- [[ipad-native-app]] — paraguas. [[iphone-duo-native-app]] — el Duo cerrado es el siguiente caso estrecho.
- [[floating-buttons-cover-row-amounts-on-ipad-landscape]] — arregla la última fila tapada por los botones
  flotantes, también en iPhone. No se duplica aquí.

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
