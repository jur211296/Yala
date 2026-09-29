---
id: sheet-size-follows-the-device-not-the-window
status: done
priority: medium
area: "design-system, ipad, iphone-duo, adaptativo"
created: 2026-09-27
updated: 2026-09-29
source: "plan adaptativo (docs/exploracion/adaptativo-ipad-duo.md §3), 2026-09-27"
---

# El tamaño de las hojas se decide por el aparato, no por el espacio de la ventana

**Cimiento del carril adaptativo, paso 4 de 13. Tamaño S.** Previo a la fase 1.

## Qué le pasa al usuario

**Inferido del código, no visto.** Las hojas de Yala (formularios, selectores) se fuerzan a tamaño grande solo si el
aparato es un iPad. Dos casos salen mal:

- **iPhone Duo abierto**: es un iPhone con pantalla de 7,6" y ancho regular. Las hojas saldrían con la altura media
  de iPhone en una pantalla de tableta.
- **iPad en ventana estrecha o Split View**: el espacio es de iPhone, pero la hoja se fuerza a grande.

## Lo medido (2026-09-27)

- `DS.Adaptive.usesLargeSheets` devuelve `UIDevice.current.userInterfaceIdiom == .pad || isiOSAppOnMac`
  (`Yala/App/Theme/DesignTokens.swift:429-432`).
- 62 llamadas en 37 ficheros la usan, directas o vía `DS.Adaptive.sheetDetents(_:)`, también para elegir el fondo
  de la hoja.
- Es la **única** decisión de layout por tipo de dispositivo en `Yala/`. Apple lo desaconseja: «Determine layout
  based on size classes, not device type or orientation» (HIG · Layout), y en el Duo «avoid checking idiom»
  (tech talk *Prepare your app for iPhone Duo*).

## Qué hacer

Que la decisión dependa del espacio (size class de la ventana que presenta la hoja), no de `userInterfaceIdiom`. Es
un `static var` sin entorno: habrá que pasarle el size class o convertirlo en un modificador que lo lea. Mantener el
comportamiento de Mac (`isiOSAppOnMac`).

## Hecho cuando

- En `YalaLane-Adapt-iPhone-ProMax`: capturas antes/después de tres hojas con detent medio (p. ej. selector de
  cuenta, filtro, formulario corto). **Sin diferencias**: en iPhone no debe cambiar nada.
- En `YalaLane-Adapt-iPad-Pro-13` a pantalla completa: las mismas tres hojas, grandes como hoy.
- En el iPad redimensionado a ventana estrecha con Device Hub (guion en el ticket; lo corre Jürgen si la sesión no
  maneja el escritorio): las hojas usan los detents de iPhone.
- Duo: queda para [[iphone-duo-native-app]].
- Test unitario de la función que decide, con los dos size classes. Gate verde.

## Relacionados

- [[ipad-native-app]] — paraguas. Lo necesita [[ipad-sidebar-and-list-detail-for-records-and-planning]].
- [[account-form-as-medium-detent-sheet]] — depende de esta decisión en iPad.

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

## Hecho (2026-09-29)

**Qué cambia para el usuario.** En un iPad con la ventana de Yala estrechada, las hojas salen con el tamaño de
iPhone: el detalle de un registro, el selector de fecha o el de período ocupan media pantalla, como en el teléfono,
en vez de estirarse a toda la altura. A pantalla completa en iPad siguen grandes, y en iPhone no cambia nada. Cuando
llegue el iPhone Duo, abierto tendrá las hojas grandes de tableta y cerrado las de teléfono, sin tocar nada más.

**Cómo.** El tamaño lo decide el espacio de la ventana (size class horizontal), no el tipo de aparato. La raíz de la
ventana (`YalaApp.rootView`) lo calcula una vez con `.sizesSheetsByWindow()` y lo baja como `\.usesLargeSheets`, que
llega intacto a toda hoja que cuelgue de ella. Las hojas usan `.yalaSheetDetents(_:)` (o `(_:selection:)`) y su fondo
`.yalaScreenBackground(.partialSheet)`; los tres detalles de detent fijo leen `@Environment(\.usesLargeSheets)`. El
`static var usesLargeSheets` se retiró, así que el compilador no deja ninguna llamada decidiendo por aparato. Mac
sigue con hojas grandes siempre. Decisiones en el Paso 0 del encargo; convención en `.claude/rules/swiftui-ds.md`.

**Premisas del ticket, medidas en `435bd8eb`.** Las «62 llamadas en 37 ficheros» eran 64 líneas en 38 ficheros fuera
de `DesignTokens.swift`: 57 de código de la app en 34 ficheros, 5 comentarios y 2 de tests. Tras el cambio,
`DS.Adaptive.usesLargeSheets` y `DS.Adaptive.sheetDetents` solo aparecen en `DesignTokens.swift` y `ViewModifiers.swift`,
y `userInterfaceIdiom` ya no aparece en `Yala/`.

**Verificado** (simuladores del carril, iOS 27.0, por UDID; evidencia en
`qa/evidencia-adaptativo-20260928/sheet-size-follows-the-device-not-the-window/`, con su README):
- `YalaLane-Adapt-iPhone-ProMax`, tres hojas con detent medio: **idénticas** antes y después, píxel a píxel (solo
  difiere la barra de inicio del sistema).
- `YalaLane-Adapt-iPad-Pro-13` a pantalla completa, las mismas tres: **idénticas**, grandes como hoy.
- **El mismo iPad con la ventana estrechada** —«Apps en ventanas» y la esquina arrastrada hasta el 40 % desde un
  XCUITest temporal, sin Device Hub—: antes, las tres a toda la altura; ahora, con los detents de iPhone. La ventana
  sin la hoja es idéntica en las dos corridas, así que lo único que cambia es la hoja.
- Test unitario de la decisión con los dos size classes, sin size class y en Mac: `YalaTests/AdaptiveSheetSizingTests.swift`.

**Encontrado:** 19 hojas con detent parcial nunca pasaron por el helper y salen medias también en un iPad a pantalla
completa. Es preexistente y queda en [[partial-sheets-that-never-adapted-to-the-window]].

**No medido:** el iPhone Duo (no hay simulador sin Xcode 27.1; queda en [[iphone-duo-native-app]]) y la app en Mac.

**Estado: `done`, sin device-QA.** Todos los criterios se vieron en el simulador, incluido el de ventana estrecha
que el ticket dejaba para Jürgen.

