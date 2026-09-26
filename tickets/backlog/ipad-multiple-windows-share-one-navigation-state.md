---
id: ipad-multiple-windows-share-one-navigation-state
status: backlog
priority: high
area: "platform, ipad, navigation"
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

## Relacionados

- [[ipad-native-app]] — paraguas.
- [[ipad-real-multiwindow-with-per-scene-state]] — donde se hace bien.
