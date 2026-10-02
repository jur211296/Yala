---
id: ipad-real-multiwindow-with-per-scene-state
status: qa
priority: low
area: "platform, ipad, navigation, modo-nube"
created: 2026-09-26
updated: 2026-10-02
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

## Hecho (2026-10-02)

**La multiventana vuelve a estar encendida, y cada ventana lleva su propia navegación.** Decisiones y su porqué en el
Paso 0 del encargo (`encargos/lanzados/2026-10-02-ipad-real-multiwindow-with-per-scene-state.md`); lo que debe respetar
cualquier cambio futuro, en `.claude/rules/swiftui-ds.md` § «Varias ventanas».

- **Navegación por ventana**: pestaña, sub-pestañas, destinos pendientes y lo que tapa cada ventana salen de
  `SessionState` a `SceneNavigation`, una por ventana. Filtros y período siguen globales a propósito.
- **Una ventana líder** monta el shell de proceso (`ContentView`); las demás son seguidoras con sus pestañas. Si la
  líder se cierra, asciende la siguiente.
- **Router por ventana**: cada intent se sella con la ventana que recibió el enlace, la notificación, la tecla o el
  toque; los del shell van a la líder y, si los pidió el usuario desde otra ventana, la traen al frente.
- **Covers en todas**: cierre de sesión, forzado de actualización y swap de contenedor salen en todas las ventanas.
  Mientras otra ventana cierra la sesión, ninguna más opera (la seguidora se desmonta; la líder queda tapada entera).
  Si la líder pregunta algo (Welcome, borrado remoto, cambio de Apple ID, aviso del espejo tardío, activación), las
  seguidoras dicen «Yala te espera en otra ventana» con un botón que la trae.
- **`WindowGroup(for: WindowRoute.self)`**: «Abrir en una ventana nueva» en el menú contextual de un grupo o un
  registro. La ventana nueva es una Yala completa que aterriza ahí, por las mismas puertas que un enlace. Solo aparece
  si el sistema deja abrir otra ventana.
- **Manifiesto**: `UIApplicationSupportsMultipleScenes = true` en `Yala/Resources/Info.plist` (comprobado en el
  `Info.plist` compilado).

**Medido en `YalaLane-Adapt-iPad-Pro-13` (iOS 27.0)**, `YalaUITests/MultiWindowUITests`, verde: (1) abrir un registro
en ventana nueva la deja con ESE registro abierto y la de partida sin ninguno, y cambiar de sección en una no mueve la
otra; (2) con dos ventanas, un enlace `yaladev://statistics` llega a una sola. Capturas en
`qa/evidencia-adaptativo-20261002/ipad-real-multiwindow-with-per-scene-state/`. Unit: `YalaTests/MultiWindowRoutingTests`.

**Review adversarial** (router, covers y estado, más una segunda ronda sobre los arreglos): con una sola ventana
(iPhone) ninguna lente encontró regresión. Se arreglaron 17 hallazgos de multiventana; los que quedan, abajo.

**Lo que no se pudo medir aquí, y por eso el ticket va a `qa`:**

- Las dos ventanas **lado a lado**: en el simulador, con «Apps en ventanas», abrir la segunda o arrastrar su barra tumba
  `backboardd` (fallo de Metal del simulador, no de Yala). Los tests corren con «Apps en pantalla completa».
- El cierre de sesión con dos ventanas: los XCUITest no tienen sesión de nube real.
- El iPhone Duo: no hay su simulador en esta Mac. Queda anotado en [[iphone-duo-native-app]].

**Residuales aceptados (baja severidad, multiventana):** los intents diferidos de un arranque en frío con dos ventanas
restauradas aterrizan en la que esté al frente, no en la que tocó la notificación; si la líder se cierra a mitad del
arranque, el selector de idioma no vuelve a salir en esa sesión; volver a pedir «Abrir en una ventana nueva» sobre un
destino que ya tiene ventana la trae al frente tal como la dejó el usuario; con VoiceOver o Acceso total por teclado
el foco lo da la notificación de ventana principal y no el toque.

## Guion de QA (iPad real o Device Hub, build de TestFlight)

Prepara: Ajustes → Multitarea y gestos → **Apps en ventanas**. Yala con datos y sesión iniciada.

1. **Dos ventanas, cada una lo suyo.** En Registros, mantén pulsado un registro → **Abrir en una ventana nueva**. Sale
   una segunda ventana con ese registro abierto. Ponlas lado a lado. En la primera ve a Estadísticas; en la segunda,
   a Planificación. **Pasa** si cada una se queda en lo suyo.
2. **Una hoja no bloquea la otra.** En la primera abre «+» (nuevo registro). En la segunda cambia de sección.
   **Pasa** si la segunda responde con la hoja abierta en la primera.
3. **Un grupo en ventana propia.** En Grupos, mantén pulsado un grupo → **Abrir en una ventana nueva**. **Pasa** si la
   ventana nueva abre ese grupo. Repite con un grupo pendiente de aprobación: debe salir el aviso de revisión, no el
   grupo.
4. **Widget o enlace con dos ventanas.** Con las dos abiertas, toca un widget de Yala en la pantalla de inicio. Anota a
   qué ventana va. **Pasa** si llega a una sola y la otra no cambia.
5. **Cerrar sesión con dos ventanas.** En la segunda ventana: Ajustes → Cerrar sesión. Mientras cierra, mira la
   primera. **Pasa** si la primera no deja tocar nada mientras cierra y, al terminar, las dos enseñan «Ya casi está —
   reinicia Yala» a la vez.
6. **La ventana que pregunta.** Con dos ventanas, provoca una pregunta en la principal (p. ej. cambia de Apple ID en
   Ajustes del sistema, o borra los datos de Yala desde otro dispositivo). **Pasa** si la otra ventana enseña «Yala te
   espera en otra ventana» y su botón trae la principal al frente.
7. **Cerrar la principal.** Cierra la primera ventana que abriste (desde la vista de todas las ventanas). **Pasa** si
   la que queda sigue funcionando (puede enseñar un momento la pantalla de inicio de Yala).

Si todo pasa → `done`. Si falla un paso, apunta cuál y qué ves.

## Relacionados

- [[ipad-native-app]]. Depende de [[ipad-multiple-windows-share-one-navigation-state]].
- [[iphone-duo-native-app]] — el Duo hereda esto; su comprobación queda allí.

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
