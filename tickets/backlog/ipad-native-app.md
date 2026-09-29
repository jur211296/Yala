---
id: ipad-native-app
status: backlog
priority: medium
area: platform
created: 2026-09-09
updated: 2026-09-27
source: idea Jürgen 2026-09-09
---

# App nativa para iPad (y el carril adaptativo: iPad, iPhone Duo e iPhone)

## La idea

Una versión de Yala pensada para iPad, no la de iPhone estirada: aprovechar el ancho para ver el
detalle y el contexto a la vez.

## Por qué importa

Las finanzas se revisan sentado. El iPad es donde el usuario compara meses, cuadra cuentas y mira
informes largos — todo lo que en el teléfono obliga a ir y volver entre pantallas.

## Estado

Idea capturada, **sin spec**. Nota de camino, medida el 2026-09-09: la app **ya tiene rastro de
iPad** —el helper de Design System `DS.Adaptive.sheetDetents(_:)`
(`Yala/App/Theme/DesignTokens.swift:436`; desde el 29-sep, `.yalaSheetDetents(_:)`, que decide por la ventana) existe para adaptar sheets a iPad/Mac, y hay ramas `isWide`
en las vistas de Estadísticas—, así que el punto de partida no es cero. Al hacer spec, medir qué
parte está ya adaptada antes de estimar.

## Exploración (2026-09-26)

Hecha: `docs/exploracion/ipad-nativo.md`, con 45 capturas del simulador (iPad mini e iPad Pro 13", en
vertical y horizontal). Decisión de partida, de Jürgen: **misma app universal, no una app aparte**.
Este ticket pasa a ser el **paraguas** de las fases:

*(Tabla del 26-sep sustituida el 27-sep por la de abajo.)*

## Plan adaptativo aprobado (2026-09-27)

Jürgen aprobó la dirección y la estructura del §5.1 el **2026-09-27**, con una condición: la versión que Apple
recomienda, que se adapte sola a cualquier tamaño de iPad, de ventana y al **iPhone Duo**. Ese día añadió dos reglas:
mejoras de iPhone permitidas con red, y simuladores dedicados para no chocar con Cola A. Plan vigente:
`docs/exploracion/adaptativo-ipad-duo.md`. Decisión: ADR «[2026-09-27] Yala se adapta por espacio, no por
dispositivo» en `docs/DECISIONS.md`.

**El carril va en serie**, un encargo por fila:

| # | Fase | Ticket | Prioridad |
|---|---|---|---|
| 1 | 0 · multiventana (iPad y Duo) | [[ipad-multiple-windows-share-one-navigation-state]] | high · antes del 23-oct |
| 2 | iPhone · texto grande | [[iphone-large-text-sizes-break-layouts]] | medium |
| 3 | iPhone · pantallas pequeñas | [[iphone-small-screens-and-safe-areas-audit]] | medium |
| 4 | Cimiento · hojas por espacio | [[sheet-size-follows-the-device-not-the-window]] | medium |
| 5 | 1 · barra lateral y lista-detalle | [[ipad-sidebar-and-list-detail-for-records-and-planning]] | medium |
| 6 | Duo · barras, pliegue y SDK 27.1 | [[iphone-duo-native-app]] | medium |
| 7 | 2 · Grupos, Ajustes, Yala IA al lado | [[ipad-list-detail-for-groups-and-settings-and-chat-inspector]] | low |
| 8 | 2b · Panel y Estadísticas aprovechan el ancho | [[ipad-and-duo-panel-and-statistics-use-the-width]] | low |
| 9 | 3 · teclado, puntero, menús | [[ipad-keyboard-shortcuts-pointer-context-menus-and-drop]] | low |
| 10 | iPhone · más espacio en los grandes | [[iphone-large-models-use-the-extra-width]] | low |
| 11 | iPhone · horizontal (decisión de Jürgen) | [[iphone-supports-landscape-orientation]] | low |
| 12 | 4 · varias ventanas | [[ipad-real-multiwindow-with-per-scene-state]] | low |
| 13 | 5 · widgets grandes | [[ipad-large-and-extra-large-widgets]] | low |

Fuera del carril, en Cola B: [[floating-buttons-cover-row-amounts-on-ipad-landscape]] y
[[cola-b-redesigns-must-hold-up-at-ipad-width]]. Prerrequisito de acceso para la fila 6:
[[xcode-27-1-with-the-iphone-duo-simulator]].

Se cierra cuando se cierre la fase 1 (fila 5); las demás son mejoras independientes.

## Relacionados

- [[iphone-duo-native-app]] — desde el 27-sep, la fase Duo de este carril. [[apple-watch]] — la misma tanda de
  plataformas del 2026-09-09.
- [[yala-android]] — la otra plataforma pendiente.

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
