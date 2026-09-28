---
id: ipad-multiple-windows-share-one-navigation-state
status: backlog
priority: high
area: "platform, ipad, navigation"
updated: 2026-09-27
created: 2026-09-26
source: "exploración iPad (docs/exploracion/ipad-nativo.md §6.1), 2026-09-26"
---

# En iPad ya se pueden abrir dos ventanas de Yala, y comparten un solo estado de navegación

## Qué le pasa al usuario

**Inferido, no reproducido** (en esta Mac no hay Simulator.app para abrir una segunda ventana). Quien
abra dos ventanas de Yala en un iPad (Dock, App Exposé o Stage Manager) verá que cambiar de pestaña en
una la cambia en la otra, que un widget o un enlace abre su destino en la ventana que le toque, y que
una hoja abierta en una bloquea la navegación de la otra.

## Lo medido

- El `Info.plist` compilado trae `UIApplicationSupportsMultipleScenes = true`: lo genera
  `INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES` y nadie lo pone a `NO`.
- Un solo `WindowGroup` (`Yala/App/YalaApp.swift:81`), sin `@SceneStorage` ni `openWindow` en todo `Yala/`.
- `MainTabView` se ata a `SessionState.shared` (`Yala/App/ContentView.swift:3044`) y la `TabView` usa
  `$sessionState.selectedMainTab` (`:3053`).
- `SessionState` tiene una sola pestaña, un solo modal y una sola hoja de bandeja por proceso
  (`SessionState.swift:473`, `:481`, `:487`, `:619`). `AppRouter` tiene una sola cola y un solo juego de
  consumidores (`AppRouter.swift:36-45`).
- Los datos no se duplican: un `ModelContainer` por proceso. El riesgo es de navegación y de los covers
  terminales (cierre de sesión, «Un momento más»), que se enseñarían en una ventana con la otra viva.

## El iPhone Duo lo hereda (documentado, 2026-09-27)

Apple, tech talk *Leverage multiple displays and scenes on iPhone Duo*
(https://developer.apple.com/videos/play/tech-talks/111464/): «iPhone Duo is the first iPhone to support multiple
instances of your app's UI. If your app supports this on iPad, it will on iPhone Duo as well». En el Duo, las
ventanas nuevas solo se crean en la pantalla interior. **Inferido:** con el ajuste de hoy, quien abra Yala en un Duo
desde el **23-oct-2026** podrá tener dos ventanas con el mismo fallo. Por eso esta fase va primera del carril
adaptativo y tiene fecha.

## Qué hacer

1. **Medir en un iPad real** con el guion de abajo.
2. Si se confirma, **apagar la multiventana**: `INFOPLIST_KEY_UIApplicationSupportsMultipleScenes = NO`
   en los dos build settings del target `Yala`. No quita nada que funcione hoy. Se vuelve a encender en
   `ipad-real-multiwindow-with-per-scene-state`.

## Guion de QA (iPad real, build de TestFlight)

1. Abre Yala. Desde el Dock, arrastra el icono de Yala a un lado de la pantalla: si aparece una segunda
   ventana de Yala, la multiventana está encendida.
2. En la ventana A ve a Estadísticas; en la B, a Planificación. Vuelve a mirar la A. **Fallo** si la A
   también está en Planificación.
3. En la A abre la bandeja de entrada. En la B intenta cambiar de pestaña. **Fallo** si no responde.
4. Con las dos abiertas, toca un widget de Yala en la pantalla de inicio. Anota qué ventana lo abre.
5. Si todo es fallo: aplica el punto 2 de «Qué hacer» y repite el paso 1. **Pasa** si ya no aparece la
   segunda ventana.

## Hecho cuando

- **Verificable en simulador sin interfaz:** tras el cambio, el `Info.plist` compilado para
  `YalaLane-Adapt-iPad-Pro-13` dice `UIApplicationSupportsMultipleScenes = false`
  (`plutil -p .ddp/Build/Products/Debug-iphonesimulator/Yala.app/Info.plist`). Antes del cambio, `true`.
- **Con Device Hub** en `YalaLane-Adapt-iPad-Pro-13`: intentar abrir una segunda ventana de Yala. Con el cambio no
  aparece. Si la sesión no maneja el escritorio, el ticket va a `qa` con el guion de arriba para Jürgen.
- XCUITest de navegación en `YalaLane-Adapt-iPad-Pro-13` y en un iPhone del carril, en verde, por UDID. Gate verde.
- Duo: se comprueba en [[iphone-duo-native-app]], cuando exista su simulador.

## Relacionados

- [[ipad-native-app]] — paraguas.
- [[ipad-real-multiwindow-with-per-scene-state]] — donde se hace bien.

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
