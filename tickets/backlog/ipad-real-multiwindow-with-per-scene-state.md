---
id: ipad-real-multiwindow-with-per-scene-state
status: backlog
priority: low
area: "platform, ipad, navigation, modo-nube"
created: 2026-09-26
updated: 2026-09-27
source: "exploración iPad (docs/exploracion/ipad-nativo.md §5.4, §6.1 y §8, fase 4), 2026-09-26"
---

# iPad · fase 4: varias ventanas de verdad, con estado por ventana

**Paso 12 de 13 del carril adaptativo. Tamaño L. Cuando haya demanda.** Toca lógica donde un bug sale caro (covers de cierre de sesión,
router): lleva review adversarial.

## Qué cambia para el usuario

Abrir un grupo, un registro o una sección en una ventana propia; tener Registros en una y
Estadísticas en otra; Split View y Stage Manager probados en iPad real.

## Qué hay que resolver

- **Navegación por ventana**: pestaña, modales y bandeja a `@SceneStorage` o a un estado por escena, no
  en `SessionState.shared`. `AppRouter` decide a qué ventana va cada intent (widget, enlace, Siri).
- **Covers terminales** (cierre de sesión, «Un momento más», swap de contenedor): se muestran en **todas**
  las ventanas a la vez. El swap ya remonta toda la jerarquía (`YalaApp.swift:90-97`); falta que ninguna
  ventana siga operando mientras otra enseña el cover.
- `WindowGroup(for:)` para abrir un grupo o un registro en ventana propia.
- **Volver a encender la multiventana**, que [[ipad-multiple-windows-share-one-navigation-state]] apagó el
  2026-09-27. Está en dos sitios y se tocan los dos: `UIApplicationSupportsMultipleScenes` a `true` en el
  `UIApplicationSceneManifest` de `Yala/Resources/Info.plist`, y —si se quiere volver al manifiesto generado—
  `INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES` en las cuatro configuraciones del target `Yala`
  quitando a la vez el manifiesto del fichero. **`INFOPLIST_KEY_UIApplicationSupportsMultipleScenes` no existe** en
  el generador de Xcode 27.0: se probó y no cambia el plist. Se comprueba con
  `plutil -p <.app>/Info.plist | grep -A1 SceneManifest`.

## iPhone Duo (documentado, 2026-09-27)

El Duo abierto deja abrir varias ventanas de la misma app, con las mismas reglas que el iPad; en la pantalla exterior
no se pueden crear. Apple pide que el gesto de «abrir en ventana nueva» se oculte solo cuando no hay ventanas
disponibles (en UIKit, `UIWindowSceneActivationAction`), y que un fallo al pedir una escena se trate. Fuente: tech
talk *Leverage multiple displays and scenes on iPhone Duo*
(https://developer.apple.com/videos/play/tech-talks/111464/).

## Hecho cuando

- Con Device Hub en `YalaLane-Adapt-iPad-Pro-13`: dos ventanas de Yala, cada una con su pestaña, su registro abierto
  y su hoja; cambiar en una no toca la otra. Capturas. Si la sesión no maneja el escritorio, a `qa` con guion.
- Un widget o un enlace `yala://` con dos ventanas abiertas llega a una sola, la esperada.
- Cerrar sesión con dos ventanas abiertas: las dos enseñan el cover a la vez y ninguna sigue operando.
- En el Duo (si existe su simulador): cerrado, «abrir en ventana nueva» no aparece; abierto, sí.
- Review adversarial hecha (router y covers). Gate verde.

## Relacionados

- [[ipad-native-app]]. Depende de [[ipad-multiple-windows-share-one-navigation-state]].

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
