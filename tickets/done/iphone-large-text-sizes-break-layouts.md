---
id: iphone-large-text-sizes-break-layouts
status: backlog
priority: medium
area: "a11y, design-system, iphone, adaptativo"
created: 2026-09-27
source: "plan adaptativo (docs/exploracion/adaptativo-ipad-duo.md §3 y §7, fase iPhone), 2026-09-27"
---

# iPhone · con el texto muy grande, las pantallas principales no se reorganizan

**Fase iPhone del carril adaptativo, paso 2 de 13. Tamaño M.** Puede entrar en 2.1 si cumple la regla del iPhone.

## Qué le pasa al usuario

Quien tiene el texto del sistema en los tamaños de accesibilidad ve Yala a medias: en 41 vistas el texto deja de
crecer al llegar a `accessibility1`, y ninguna pantalla pasa de fila a columna cuando el texto no cabe. Lo esperable
es que un concepto largo empuje el importe fuera o lo corte. **Inferido del código, no visto aún en el simulador.**

## Lo medido (2026-09-27, este árbol)

- 41 `.dynamicTypeSize(...DynamicTypeSize.accessibility1)`, en Onboarding (7), Settings (7), Inbox (5), Planning
  (7), Profile (3), Transactions (4), Groups (2), Import (2) y otras.
- 0 usos de `dynamicTypeSize.isAccessibilitySize`, 0 `ViewThatFits`, 0 `AnyLayout`.
- 177 `lineLimit(1)` y 49 `minimumScaleFactor`.

## Qué hacer

1. **Medir antes de tocar.** Capturas en `YalaLane-Adapt-iPhone-SE` y `YalaLane-Adapt-iPhone-ProMax` con
   `content_size accessibility-extra-extra-extra-large` (AX5) de: Panel, Registros, detalle de registro, Nuevo
   registro, Planificación, detalle de presupuesto, Grupos, detalle de grupo, Perfil y Bandeja. Anotar qué se corta,
   qué se solapa y qué importe no se lee.
2. **Arreglar lo que corte un importe o tape un botón**, que es lo caro en una app de finanzas: filas de concepto e
   importe con `AnyLayout` (`HStack` → `VStack` cuando `isAccessibilitySize`), sin cambiar qué hace cada fila.
3. **Revisar los 41 topes uno por uno.** Se queda solo el que tenga motivo escrito al lado (por ejemplo, un control
   que no cabe en ningún tamaño). Los demás, fuera.
4. Lo que salga caro o toque navegación → ticket aparte, no aquí.

## Hecho cuando

- Capturas antes/después de las diez pantallas en los dos iPhone, a tamaño por defecto y a AX5, en
  `qa/evidencia-adaptativo-AAAAMMDD/iphone-large-text-sizes-break-layouts/`. A tamaño por defecto, sin diferencias.
- A AX5, ningún importe cortado ni botón tapado en esas diez pantallas.
- XCUITest de las áreas tocadas en verde en `YalaLane-Adapt-iPhone-ProMax`, por UDID.
- Gate verde.

## Relacionados

- [[ipad-native-app]] — paraguas del carril. [[late-icloud-sheet-buttons-may-leave-the-screen-at-large-dynamic-type]]
  — un caso concreto del mismo problema.

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
