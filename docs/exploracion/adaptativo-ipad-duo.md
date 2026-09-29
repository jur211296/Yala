---
fecha: 2026-09-27
estado: plan vigente. Dirección y §5.1 de ipad-nativo.md aprobadas por Jürgen el 2026-09-27. Sin código
sustituye: el §8 (plan por fases) de docs/exploracion/ipad-nativo.md; el resto de aquel documento sigue valiendo como medición
decisión: docs/DECISIONS.md, «[2026-09-27] Yala se adapta por espacio, no por dispositivo»
ticket: tickets/backlog/ipad-native-app.md (paraguas) y los de la tabla del §7
---

# Yala adaptativa: iPad, iPhone Duo y los iPhone de siempre

**Qué es:** el plan vigente para que Yala se adapte sola a cualquier tamaño de ventana: el iPhone pequeño y el
grande, el iPad entero, en Split View o en una ventana redimensionada, y el iPhone Duo abierto, cerrado o a medio
plegar. Parte de la exploración del 26-sep ([`ipad-nativo.md`](ipad-nativo.md)), que sigue siendo la medición de lo
que se ve hoy, y la actualiza con lo que Apple publicó para el Duo el 9-sep.

**En corto:**

- **Aprobado por Jürgen el 2026-09-27:** la estructura del §5.1 de `ipad-nativo.md` (barra lateral + lista + detalle),
  con una condición: la versión que Apple recomienda, nativa, que se adapte sola a cualquier tamaño.
- **El Duo no pide una app aparte.** Para Apple sigue siendo un iPhone: la pantalla exterior es *compact*, como
  cualquier iPhone, y la interior es *regular*, como un iPad. Lo que hagamos para iPad lo hereda el Duo abierto.
- **Una sola regla de layout:** se decide por el espacio disponible (size classes y ancho del contenedor), nunca por
  el tipo de dispositivo ni por la orientación. Yala la incumple hoy en un sitio: el tamaño de las hojas (§3).
- **Un ajuste a §5.1:** un único `NavigationSplitView` que se pliega solo en espacio estrecho, en vez de un `if` por
  size class en la raíz. En el Duo la app cambia de tamaño cada vez que se abre o se cierra, y el `if` perdería lo que
  el usuario tenía abierto.
- **Mejoras de iPhone permitidas** (sustituye a «el iPhone no cambia ni un píxel»): van como fase propia, con
  capturas antes y después en iPhone pequeño, grande y con texto grande.
- **La fase 0 sube de urgencia:** el Duo es el primer iPhone con varias ventanas de la misma app, y lo hereda del
  ajuste de iPad, que Yala tiene encendido. El Duo sale el 23-oct-2026.
- **La fase Duo necesita Xcode 27.1** (beta) en la Mac para tener su simulador. Hoy hay 27.0.

Convención: **documentado** = lo dice Apple en la URL citada. **Medido** = lo vi en el código de este árbol o en esta
Mac. **Supuesto** = no está documentado ni medido; se dice qué falta para comprobarlo.

---

## 1 · Lo que Apple documenta

Leído el 2026-09-27. Las páginas de documentación se leyeron por su JSON público (el mismo contenido que pinta la web);
las charlas, por su transcripción.

### 1.1 · iPhone Duo

| Hecho documentado | Fuente |
|---|---|
| Anunciado el 9-sep-2026. Reservas el 16-oct, a la venta el **23-oct-2026**. Sale con **iOS 27.1** | [Newsroom](https://www.apple.com/newsroom/2026/09/apple-unveils-iphone-duo/) |
| Dos pantallas: exterior de 5,4" e interior de 7,6", con la misma relación de aspecto. Apple da pulgadas, no puntos | [Newsroom](https://www.apple.com/newsroom/2026/09/apple-unveils-iphone-duo/) |
| «Although iPhone Duo is a new form factor, keep in mind that you're still designing for iPhone» | [HIG · Designing for iPhone Duo](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo) |
| Exterior: **compact** de ancho (regular de alto en vertical; compact/compact en horizontal). Interior: **regular** de ancho y de alto | [Tech talk · Prepare your app for iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111461/) |
| «A compact width layout for the outer display and a regular width layout for the inner display give you the fundamentals for every pose. Don't reinvent your app when it resizes» | [HIG](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo) |
| La exterior **respeta** las orientaciones que declara la app. La interior **no**: la app cambia de tamaño, también en Split View | [Tech talk 111461](https://developer.apple.com/videos/play/tech-talks/111461/) |
| Al abrir o cerrar, la app **se redimensiona**; no se recrea | [Tech talk 111461](https://developer.apple.com/videos/play/tech-talks/111461/) |
| Mismo patrón que Mail: en la exterior, lista **o** mensaje; en la interior, los dos lado a lado | [HIG](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo) |
| Un split view «expands on the inner display and collapses to a single pane on the outer display» y ajusta sus columnas al pliegue sin código | [HIG · Split views](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo#Split-views) |
| Alertas, menús contextuales y hojas se apartan solos del pliegue. Las vistas propias, no: para eso está `ReservedRegion` | [HIG · Reserved regions](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo#Reserved-regions) |
| En rejillas, **número par de columnas**, para que el pliegue caiga entre dos | [HIG](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo) |
| Las listas y el contenido con scroll **no se desplazan** al plegar: ya se adaptan con el scroll | [Tech talk · Strike a pose](https://developer.apple.com/videos/play/tech-talks/111463/) |
| Barras de navegación, herramientas y pestañas pasan a un **lateral vertical** en la exterior y en la interior en horizontal. En la interior en vertical siguen horizontales | [HIG · Vertical controls](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo#Vertical-controls) |
| Un botón de barra solo pasa al lateral si tiene **icono**; con solo texto o una vista propia, no. Pide icono y título (`Label`) | [Preparing your app for iPhone Duo](https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo) |
| Las barras hechas a mano (`UIToolbar`, `UITabBar` propios) no pasan al lateral; las de `NavigationStack`/`NavigationSplitView` con `.toolbar`, sí | [Preparing your app](https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo) |
| Es el **primer iPhone con varias ventanas de la misma app**: «If your app supports this on iPad, it will on iPhone Duo as well». Solo se crean en la pantalla interior | [Tech talk · Leverage multiple displays and scenes](https://developer.apple.com/videos/play/tech-talks/111464/) |
| Todas las apps participan en Split View en la pantalla interior | [Tech talk 111464](https://developer.apple.com/videos/play/tech-talks/111464/) |
| Compilada con el SDK 27.0, la app ya funciona y se extiende a la izquierda de la barra de estado en la interior. **Pantalla completa hasta el borde solo con el SDK de 27.1** | [Tech talk 111461](https://developer.apple.com/videos/play/tech-talks/111461/) |
| Simulador del Duo en **Xcode 27.1 beta**, con controles para abrir, cerrar, girar y plegar en Device Hub | [Get ready for iPhone Duo](https://developer.apple.com/iphone-duo/), [tech talk 111461](https://developer.apple.com/videos/play/tech-talks/111461/) |
| Trampa conocida: si se abre el Device Hub de Xcode 27.0, faltan los controles de postura. Hay que abrir el de 27.1 (`Xcode > Open Developer Tool > Device Hub`) | [Foro · iPhone Duo Simulator](https://developer.apple.com/forums/thread/847556) (respuesta de la comunidad, no de Apple) |

**Disponibilidad de las APIs nuevas**, leída del JSON de cada símbolo:

| API | Desde | Para qué |
|---|---|---|
| `ArrangementView`, `.arrangementViewStyle(.split / .overlay)` | iOS 27.1 (beta) | Dos vistas que se reparten el espacio y esquivan el pliegue |
| `GeometryProxy.reservedRegions(kind:options:layoutDirectionBehavior:)`, `ReservedRegion` | iOS 27.1 (beta) | Saber dónde está el pliegue o la cámara |
| `toolbarVerticalBehavior(_:)`, `toolbarVerticalEdge`, `axisBehavior(_:)`, `ToolbarVerticalCompressionBehavior` | iOS 27.1 (beta) | Barras verticales |
| `topBarPinnedTrailing`, `visibilityPriority(_:)`, `ToolbarOverflowMenu`, `presentationPlacement(_:)` | iOS 27.0 | Prioridad de botones en barras que se estrechan |
| `backgroundExtensionEffect()` | iOS 26.0 | Fondo que se extiende bajo barras laterales |
| `TabView` + `.sidebarAdaptable` | iOS 18.0 | Pestañas que se vuelven barra lateral |
| `.inspector(isPresented:)` | iOS 17.0 | Columna lateral (Yala IA) |
| `NavigationSplitView` | iOS 16.0 | Lista y detalle |

Yala despliega en iOS 26.0: todo lo de 27.x va tras `if #available`. **El núcleo del plan no depende de nada nuevo.**

### 1.2 · iPad y diseño adaptativo en general

| Hecho documentado | Fuente |
|---|---|
| «Determine layout based on size classes, not device type or orientation» | [HIG · Layout](https://developer.apple.com/design/human-interface-guidelines/layout) (revisada el 9-sep-2026) |
| «Consider taking advantage of larger spaces to switch from a tab bar to a sidebar» | [HIG · Layout](https://developer.apple.com/design/human-interface-guidelines/layout) |
| Texto grande: las vistas en fila tienen que poder apilarse y las filas crecer en alto | [HIG · Layout](https://developer.apple.com/design/human-interface-guidelines/layout) |
| Probar primero el layout más grande y el más pequeño; Device Hub sirve para ver la app redimensionada en iPad | [HIG · Layout](https://developer.apple.com/design/human-interface-guidelines/layout) |
| En iPadOS las ventanas se redimensionan libremente, con mosaico, pantalla completa y minimizado | [HIG · Multitasking](https://developer.apple.com/design/human-interface-guidelines/multitasking) |
| Un split view tiene que funcionar en anchos estrecho, intermedio y ancho, y dejar navegar entre paneles | [HIG · Split views](https://developer.apple.com/design/human-interface-guidelines/split-views) |
| `NavigationSplitView` se pliega en una pila en anchos estrechos y enseña la última columna útil; `preferredCompactColumn` elige cuál | [NavigationSplitView](https://developer.apple.com/documentation/swiftui/navigationsplitview) |
| `.sidebarAdaptable`: en iPadOS, pestañas arriba que se pueden convertir en barra lateral; en iOS, pestañas abajo | [sidebarAdaptable](https://developer.apple.com/documentation/swiftui/tabviewstyle/sidebaradaptable) |
| `UIRequiresFullScreen` está obsoleta desde iPadOS 26: la app tiene que aceptar que la redimensionen | [UIRequiresFullScreen](https://developer.apple.com/documentation/bundleresources/information-property-list/uirequiresfullscreen) |
| Evitar un `if` por size class en la raíz: «will tear down the state and views in the other branches». Preferir un contenedor adaptable (split view), `AnyLayout`, o `ViewThatFits` sacando fuera el estado compartido | [Foro · iOS 27 automatic resize](https://developer.apple.com/forums/thread/832755) (respuesta de un Frameworks Engineer de Apple) |
| Novedades de SwiftUI en iOS 27 que tocan esto: prioridad de botones en barra, menú de desbordamiento fijo, botón anclado a la derecha, reordenar en listas y rejillas | [What's new in SwiftUI](https://developer.apple.com/swiftui/whats-new/) |

### 1.3 · Fuente secundaria: sarunw.com

Referencia que pidió Jürgen el 27-sep para patrones y trampas prácticas. **Apple manda si hay conflicto.** Leídos el
27-sep; no contradicen nada del §1.1:

| Lo que dice | Artículo |
|---|---|
| No se diseña un layout por postura: dos anchos (compact y regular) bastan; las seis posturas sirven para **validar**, no para diseñar | [Adapting your app for iPhone Duo](https://sarunw.com/posts/adapting-your-app-for-iphone-duo/) (12-sep-2026) |
| Trampa: los márgenes laterales del área segura, que en un iPhone normal casi no existen, en el Duo sí, porque las barras se van al lateral | [Adapting your app for iPhone Duo](https://sarunw.com/posts/adapting-your-app-for-iphone-duo/) |
| Con `.sidebarAdaptable`, la barra de pestañas del Duo cerrado pasa a **barra lateral** en el abierto (ejemplo: la app Salud) | [Adapting content for iPhone Duo](https://sarunw.com/posts/adapting-content-for-iphone-duo/) (14-sep-2026) |
| Tres maneras de lidiar con la asimetría de la barra lateral: todo al área segura, lo principal centrado en la pantalla entera, o fondo a pantalla completa con el contenido metido | [Adapting content for iPhone Duo](https://sarunw.com/posts/adapting-content-for-iphone-duo/) |
| Las barras verticales **no llegan solas**: hace falta compilar con el SDK nuevo y usar las barras del sistema. «The system can only move a bar it owns»: lo hecho a mano se queda horizontal | [Opt in to vertical bars on iPhone Duo](https://sarunw.com/posts/opt-in-to-vertical-bars-on-iphone-duo/) (22-sep-2026) |
| `ViewThatFits` prueba sus hijas de la que más espacio pide a la que menos y se queda con la primera que cabe | [Responsive layout in SwiftUI with ViewThatFits](https://sarunw.com/posts/swiftui-viewthatfits/) |

---

## 2 · Lo que NO está documentado (supuestos que hay que medir)

| Pregunta | Por qué no se sabe | Cómo se cierra |
|---|---|---|
| ¿`.sidebarAdaptable` enseña barra lateral en el Duo abierto? | Su documentación solo distingue iPadOS (barra lateral) e iOS (pestañas abajo), y el Duo es iOS. El HIG dice que la interior «lets you show more content like sidebars», sin decir si la `TabView` lo hace sola. sarunw.com dice que **sí** (§1.3): probable, pero no es Apple | Simulador del Duo (Xcode 27.1), fase Duo |
| ¿Dónde caen los botones flotantes de Yala (`FABStackView`) cuando la barra de pestañas pasa al lateral? | Son una vista propia superpuesta, no un botón de barra. Apple no habla de botones flotantes; sarunw.com confirma que lo hecho a mano no se mueve con las barras (§1.3). Falta ver si choca | Simulador del Duo, cerrado y abierto en horizontal |
| Tamaño en puntos de cada pantalla del Duo | Apple publica pulgadas. No se inventan puntos | Leerlos del simulador |
| ¿Cómo se ven las hojas de Yala en la interior? | Depende de `usesLargeSheets` (§3), que hoy mira el tipo de dispositivo | Simulador del Duo |
| Size class de cada mitad en Split View en el Duo | Apple dice que todas las apps participan y que se usen size classes, no cuál toca | Simulador del Duo |
| Widgets en el Duo | No se investigó en este pase | Fuera de alcance; la fase 5 lo mira si hace falta |

---

## 3 · Lo medido en Yala hoy (este árbol, 2026-09-27)

- **Decisión por tipo de dispositivo, una:** `DS.Adaptive.usesLargeSheets` mira `userInterfaceIdiom == .pad`
  (`Yala/App/Theme/DesignTokens.swift:429-432`), y la usan 62 llamadas en 37 ficheros (directas o vía
  `DS.Adaptive.sheetDetents`). En el Duo abierto (idiom iPhone, ancho regular)
  las hojas saldrían con los detents de iPhone; en un iPad en una ventana estrecha, forzadas a grandes. Es lo único
  que decide por dispositivo: el resto de `userInterfaceIdiom`/`UIDevice.current` es informativo (versión, modelo,
  identificador). Ticket: `sheet-size-follows-the-device-not-the-window`. **Resuelto el 29-sep:** lo decide el size
  class de la ventana (`\.usesLargeSheets`, calculado en la raíz) y `userInterfaceIdiom` ya no aparece en `Yala/`.
- **Size classes en solo 6 ficheros**, todos de Panel y Estadísticas. `DS.Adaptive.horizontalPadding` tiene un solo
  uso (`PanelView.swift:562`).
- **El Panel ya reparte en pares:** 2 columnas en regular (`PanelWidgetsGrid.swift:24`), que es lo que el HIG pide
  para que el pliegue caiga entre dos. El carrusel de cuentas pasa de 2 a 4 tarjetas (`AccountsCarouselView.swift:23`).
- **iPhone solo en vertical**: `INFOPLIST_KEY_UISupportedInterfaceOrientations = UIInterfaceOrientationPortrait` en los
  cuatro build settings (`project.pbxproj:553`, `:601`, `:864`, `:911`). En el Duo, la exterior lo respetará; la
  interior lo ignora.
- **Texto grande:** 41 vistas topan el tamaño de texto en `accessibility1` (`.dynamicTypeSize(...accessibility1)`),
  cero usos de `isAccessibilitySize`, cero `ViewThatFits` o `AnyLayout`, y 177 `lineLimit(1)`. Nada cambia de fila a
  columna cuando el texto crece.
- **Márgenes y alturas fijas:** 29 `ignoresSafeArea`, 24 alturas fijas de 200 puntos o más, y dos cuadrados fijos de
  300 y 320 puntos (`SubscriptionView.swift:153`, `SplashScreenView.swift:63`).
- **Botones flotantes:** `FABStackView`, montado en Panel, Registros y el detalle de Estadísticas
  (`PanelView.swift:630`, `RecordsStandaloneView.swift:159`, `DetailContainerView.swift:253`).
- **Multiventana APAGADA desde el 2026-09-27** (fase 0). Antes estaba encendida con navegación de proceso
  (`ipad-nativo.md` §6.1), y una sonda en `YalaLane-Adapt-iPad-Pro-13` lo midió: el sistema abría una segunda
  ventana de Yala (1 → 2 escenas). Hoy el manifiesto va escrito en `Yala/Resources/Info.plist` con
  `UIApplicationSupportsMultipleScenes = false` y `INFOPLIST_KEY_UIApplicationSceneManifest_Generation = NO` en las
  cuatro configuraciones del target; la misma sonda recibe «La aplicación no admite varios entornos» y se queda en 1
  escena. **Se vuelve a encender en la fase 4**, `ipad-real-multiwindow-with-per-scene-state`, cuando cada ventana
  tenga su estado.
- **Esta Mac:** Xcode 27.0 (27A266a), runtimes iOS 26.5 y 27.0, **ningún tipo de dispositivo Duo**, 15 GB libres. Hay
  `DeviceHub.app` dentro de Xcode, que la exploración del 26-sep no contó: con él se puede redimensionar la app en el
  simulador de iPad, aunque es interfaz gráfica y no se maneja desde `simctl`.

---

## 4 · La regla de layout

**Se decide por el espacio, nunca por el dispositivo ni por la orientación.** Tres anchos, y cada pantalla sabe qué
hacer en cada uno:

| Espacio | Dónde aparece | Qué pinta Yala |
|---|---|---|
| **Compact** | Cualquier iPhone en vertical · Duo cerrado · iPad en ventana estrecha · probablemente el Duo en Split View (supuesto, §2) | La interfaz de iPhone de hoy: pestañas abajo, pila de navegación, detalle en hoja o empujado |
| **Regular, intermedio** | iPad mini · iPad en media pantalla, según el modelo · Duo abierto | Barra lateral (o pestañas arriba), lista y detalle a la vez donde los haya |
| **Regular, ancho** | iPad Pro/Air a pantalla completa · ventanas grandes | Lo mismo, con ancho legible (~700 pt) en listas y formularios, e inspector de Yala IA |

Cuatro consecuencias:

1. **Un contenedor que se adapta, no dos ramas.** `TabView` con `.sidebarAdaptable` en la raíz, y dentro de cada
   sección con lista y detalle un `NavigationSplitView` que en compact se pliega solo a pila. No hay
   `if sizeClass == .regular { … } else { … }` en la raíz.
2. **El estado vive fuera de la forma.** Qué registro está abierto, qué pestaña, qué filtro: se conservan al
   redimensionar. En el Duo, abrir y cerrar es redimensionar.
3. **Las rejillas propias, en pares.** Dos o cuatro columnas, no tres, para que el pliegue caiga entre dos.
4. **Lo nuevo de 27.1, detrás de `if #available`.** `ReservedRegion` y `ArrangementView` solo para vistas propias
   que caigan sobre el pliegue y que el sistema no aparte solo. Nunca dentro de un `List` o `ScrollView`, ni
   envolviendo un `NavigationSplitView` (lo desaconseja Apple).

---

## 5 · Cómo cubre el plan al iPhone Duo

| Postura | Espacio | Qué hereda del plan | Qué pide aparte |
|---|---|---|---|
| **Cerrado** (exterior) | compact | Todo lo del iPhone, incluidas las mejoras de la fase iPhone | Barras en el lateral: botones de barra con icono y título; comprobar que los flotantes no chocan |
| **Abierto en vertical** | regular | Todo lo de iPad: barra lateral si la `TabView` la da (§2), lista-detalle, ancho legible, inspector | Barras horizontales, como un iPad |
| **Abierto en horizontal** | regular | Lo mismo | Barras en el lateral |
| **A medio plegar** | regular, con pliegue | `NavigationSplitView`, hojas, alertas y menús se apartan solos | Las rejillas propias en pares; `ReservedRegion` solo si algo propio cae en el pliegue |
| **Split View** con otra app | no documentado (supuesto: compact) | Lo que toque por espacio | Cada app pone sus barras en su borde exterior (HIG); comprobarlo en el simulador |
| **Dos ventanas de Yala** | — | Fase 0 (apagar) y fase 4 (estado por ventana) | En la exterior no se pueden crear ventanas: el botón de «abrir en ventana nueva» tiene que ocultarse solo |

**Qué queda fuera, a propósito:** cámara (Yala no captura con AVFoundation), StandBy y contenido en la pantalla
exterior con la app en la interior.

---

## 6 · Reglas del carril

### 6.1 · iPhone: mejoras permitidas, con red

Sustituye a «el iPhone actual (compact) no cambia ni un píxel». Palabras de Jürgen, 2026-09-27:

> Se permiten mejoras de adaptación en iPhone si no rompen flujos ni ponen en riesgo la release 2.1; cada una
> verificable en simulador con capturas antes/después en tamaños iPhone pequeño/grande y Dynamic Type grande.

En la práctica, cada ticket que toque lo que se ve en iPhone termina con:

- capturas antes y después en **`YalaLane-Adapt-iPhone-SE`** (el más pequeño) y **`YalaLane-Adapt-iPhone-ProMax`**
  (el más grande), con texto por defecto y con **Dynamic Type AX5**
  (`xcrun simctl ui <UDID> content_size accessibility-extra-extra-extra-large`), en
  `qa/evidencia-adaptativo-AAAAMMDD/<ticket>/`;
- los XCUITest de las áreas tocadas en verde en iPhone, que es la prueba de que no se rompió ningún flujo;
- nada que cambie qué hace un botón o a dónde lleva: solo cómo se coloca.

Si una mejora no puede cumplir las tres, no es de esta regla: pasa a ticket con decisión de Jürgen.

### 6.2 · Simulador: nunca chocar con Cola A

Palabras de Jürgen, 2026-09-27, obligatoria en todo el carril:

> Este carril usa simuladores dedicados creados con `xcrun simctl create` con prefijo fijo `YalaLane-Adapt-` (p. ej.
> YalaLane-Adapt-iPhone-SE, YalaLane-Adapt-iPhone-ProMax, YalaLane-Adapt-iPad-Pro-13, YalaLane-Adapt-iPad-mini) y los
> usa SIEMPRE por UDID (`-destination id=<UDID>`), nunca por nombre genérico ni `booted`. Prohibido
> `simctl shutdown all`, `erase all`, `killall Simulator` o tocar simuladores sin ese prefijo (los usa la sesión de
> Cola A en paralelo). DerivedData propio del worktree.

Receta (se crean una vez; si ya existen, se reusan):

```bash
RT=com.apple.CoreSimulator.SimRuntime.iOS-26-5          # el runtime con el que pasa el gate en esta Mac
crear() { xcrun simctl list devices | grep -q "$1 (" || xcrun simctl create "$1" "$2" "$RT"; }
crear YalaLane-Adapt-iPhone-SE      com.apple.CoreSimulator.SimDeviceType.iPhone-SE-3rd-generation
crear YalaLane-Adapt-iPhone-ProMax  com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro-Max
crear YalaLane-Adapt-iPad-mini      com.apple.CoreSimulator.SimDeviceType.iPad-mini-A17-Pro
crear YalaLane-Adapt-iPad-Pro-13    com.apple.CoreSimulator.SimDeviceType.iPad-Pro-13-inch-M5-12GB
xcrun simctl list devices | grep 'YalaLane-Adapt-'      # de aquí salen los UDID
```

- Build y test siempre con `-destination "platform=iOS Simulator,id=<UDID>"` y `-derivedDataPath .ddp` (ignorado por
  git, dentro del worktree).
- Arrancar, apagar o borrar: solo `xcrun simctl boot|shutdown|erase <UDID>` de un simulador con el prefijo.
- El Duo, cuando haya Xcode 27.1: `YalaLane-Adapt-iPhone-Duo`, con el tipo de dispositivo y el runtime que traiga.
- Con 15 GB libres en esta Mac, crear los cuatro puede no caber: `bash qa/scripts/disk-report.sh` antes.

### 6.3 · Qué es «hecho» en una fase de este carril

Además de lo propio de cada ticket:

1. Capturas antes y después en los simuladores del §6.2 que toque (iPad en vertical y horizontal).
2. **Split View o ventana estrecha**: la app redimensionada en el simulador de iPad con Device Hub. Es interfaz
   gráfica: lo hace Jürgen con el guion del ticket, o la sesión con control del escritorio si lo tiene. Si ninguno
   puede, el ticket va a `qa` con el guion, no a `done`.
3. **Duo**, cuando exista `YalaLane-Adapt-iPhone-Duo`: cerrado, abierto en vertical, abierto en horizontal y a medio
   plegar. Mientras no exista, se anota como pendiente en el ticket de la fase Duo, no en cada fase.
4. iPhone según §6.1.
5. Gate verde, como siempre.

---

## 7 · Las fases, en serie

Cambios respecto al §8 de `ipad-nativo.md`: entra la **fase iPhone**; entra un **cimiento** (el tamaño de las hojas);
entra la **fase Duo**, que reusa `iphone-duo-native-app`; el Panel y Estadísticas salen de la fase 2 a una **2b**
propia; y la fase 0 pasa a ser también del Duo.

Tamaños: **S** ≈ una sesión · **M** ≈ dos o tres · **L** ≈ cuatro o más.

| # | Fase | Qué cambia para el usuario | Ticket | Tamaño | Depende de | Prioridad |
|---|---|---|---|---|---|---|
| 1 | **0 · Multiventana** ✅ 27-sep | No se puede abrir una segunda ventana rota, ni en iPad ni en el Duo. Apagada hasta la fase 4 (#12) | `ipad-multiple-windows-share-one-navigation-state` | S | nada | high · antes del 23-oct |
| 2 | **iPhone · texto grande** | Con texto grande, los importes no se cortan y las filas crecen | `iphone-large-text-sizes-break-layouts` | M | nada | medium |
| 3 | **iPhone · pantallas pequeñas** | En un iPhone SE nada queda tapado ni cortado, tampoco con el teclado | `iphone-small-screens-and-safe-areas-audit` | S–M | nada | medium |
| 4 | **Cimiento · hojas por espacio** ✅ 29-sep | Las hojas se dimensionan por la ventana, no por el aparato | `sheet-size-follows-the-device-not-the-window` | S | nada | medium |
| 5 | **1 · Barra lateral y lista-detalle** | Barra lateral; Registros y Planificación con lista y detalle a la vez; ancho legible | `ipad-sidebar-and-list-detail-for-records-and-planning` | L | 4 y [[cola-b-redesigns-must-hold-up-at-ipad-width]] | medium |
| 6 | **Duo · barras, pliegue y SDK 27.1** | Yala a pantalla completa en el Duo, barras en el lateral bien ordenadas, nada en el pliegue | `iphone-duo-native-app` | M | 5 y `xcode-27-1-with-the-iphone-duo-simulator` | medium |
| 7 | **2 · Grupos, Ajustes y Yala IA al lado** | Grupos y Ajustes en dos columnas; Yala IA como columna junto a los datos | `ipad-list-detail-for-groups-and-settings-and-chat-inspector` | M | 5 | low |
| 8 | **2b · Panel y Estadísticas aprovechan el ancho** | Cabecera más baja en horizontal, Últimos registros a dos columnas, Resumen en rejilla | `ipad-and-duo-panel-and-statistics-use-the-width` | M | 5 | low |
| 9 | **3 · Teclado, puntero y menús** | Atajos, resaltado al pasar el puntero, menús contextuales, soltar un recibo | `ipad-keyboard-shortcuts-pointer-context-menus-and-drop` | M | 5 | low |
| 10 | **iPhone · más espacio en los grandes** | El Pro Max enseña más sin cambiar nada de sitio | `iphone-large-models-use-the-extra-width` | S | 2 y 3 | low |
| 11 | **iPhone · horizontal** (decisión) | Yala gira en iPhone y en el Duo cerrado | `iphone-supports-landscape-orientation` | M | 5 y 2 | low |
| 12 | **4 · Varias ventanas de verdad** | Abrir un grupo o un registro en otra ventana, en iPad y en el Duo abierto | `ipad-real-multiwindow-with-per-scene-state` | L | 1 y 5 | low |
| 13 | **5 · Widgets grandes** | Widgets grandes y uno extragrande en iPad | `ipad-large-and-extra-large-widgets` | S–M | nada | low |

**Fuera del carril, pero dependencias suyas:** `cola-b-redesigns-must-hold-up-at-ipad-width` y
`floating-buttons-cover-row-amounts-on-ipad-landscape` siguen en Cola B, que es donde se rediseñan esas pantallas. El
segundo arregla también la última fila tapada en iPhone: la fase iPhone no lo duplica.

**Prerrequisito de acceso, de Jürgen:** `xcode-27-1-with-the-iphone-duo-simulator`. Instalar Xcode 27.1 beta en esta
Mac. Solo bloquea la fase 6.

**Por qué este orden:**

- La **0** va primero porque es un riesgo vivo y ahora tiene fecha: el 23-oct cualquiera con un Duo puede abrir dos
  ventanas de Yala.
- Las de **iPhone (2 y 3)** van antes de la 1 porque son baratas, las ve todo el mundo hoy y no tocan navegación.
  Pueden entrar en 2.1 si cumplen el §6.1.
- El **cimiento (4)** es de una sesión y la fase 1 lo necesita para que las hojas que siguen siendo hojas salgan bien
  en cualquier ventana.
- La **Duo (6)** va justo tras la 1 porque la 1 le da casi todo; lo que queda es lo propio del Duo.
- La **horizontal en iPhone (11)** va tras la 1 porque un iPhone Pro Max girado pasa a ancho regular y pintaría la
  interfaz de iPad: sin la fase 1 hecha, girar enseñaría la columna estirada.

---

## 8 · Vistas a rediseñar para aprovechar el espacio, por prioridad

| # | Vista | Qué gana | Fase |
|---|---|---|---|
| 1 | **Registros** | Lista y detalle a la vez; el detalle deja de ser una hoja que tapa la lista | 1 |
| 2 | **Planificación y presupuesto** | Lista y detalle; barras de progreso con ancho legible | 1 |
| 3 | **Todas las listas y formularios** | Ancho legible (~700 pt) y margen adaptativo; hoy filas de 1300 pt | 1 |
| 4 | **Navegación (Más)** | Pasa a barra lateral: las cuatro secciones de Más son las `TabSection` | 1 |
| 5 | **Yala IA** | Columna lateral (`.inspector`) junto al Panel, Registros o Estadísticas | 2 |
| 6 | **Grupos** | Lista y grupo abierto a la vez | 2 |
| 7 | **Perfil y Ajustes** | De hoja pequeña con pilas a dos columnas | 2 |
| 8 | **Panel** | Cabecera más baja en horizontal; Últimos registros a dos columnas | 2b |
| 9 | **Estadísticas · Resumen** | Hoy «iPhone estirado»: barras de 900 pt para tres números. Tarjetas en rejilla de dos | 2b |
| 10 | **Estadísticas · Tendencias** | Sin comparación, gráfica e indicadores lado a lado, como ya hace con comparación | 2b |
| — | Distribución, Nuevo registro, Bandeja | Ya valen. Solo margen adaptativo | — |

---

## 9 · Fuentes

- HIG · [Designing for iPhone Duo](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo) (nueva, 9-sep-2026)
- [Preparing your app for iPhone Duo](https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo)
- [Get ready for iPhone Duo](https://developer.apple.com/iphone-duo/) · [Build for iPhone Duo with new resources](https://developer.apple.com/news/?id=nyuppv9r) (18-sep-2026)
- Tech talks: [Prepare your app for iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111461/) ·
  [Raise the bar with iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111462/) ·
  [Strike a pose with adaptive layouts on iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111463/) ·
  [Leverage multiple displays and scenes on iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111464/) ·
  [Design for iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111466/)
- [Apple unveils iPhone Duo](https://www.apple.com/newsroom/2026/09/apple-unveils-iphone-duo/) (Newsroom, 9-sep-2026)
- HIG · [Layout](https://developer.apple.com/design/human-interface-guidelines/layout) ·
  [Split views](https://developer.apple.com/design/human-interface-guidelines/split-views) ·
  [Multitasking](https://developer.apple.com/design/human-interface-guidelines/multitasking) ·
  [Designing for iPadOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-ipados)
- SwiftUI: [NavigationSplitView](https://developer.apple.com/documentation/swiftui/navigationsplitview) ·
  [sidebarAdaptable](https://developer.apple.com/documentation/swiftui/tabviewstyle/sidebaradaptable) ·
  [ArrangementView](https://developer.apple.com/documentation/swiftui/arrangementview) ·
  [ReservedRegion](https://developer.apple.com/documentation/swiftui/reservedregion) ·
  [What's new in SwiftUI](https://developer.apple.com/swiftui/whats-new/)
- [UIRequiresFullScreen](https://developer.apple.com/documentation/bundleresources/information-property-list/uirequiresfullscreen)
- Fuente secundaria (sarunw.com): [Adapting your app for iPhone Duo](https://sarunw.com/posts/adapting-your-app-for-iphone-duo/) ·
  [Adapting content for iPhone Duo](https://sarunw.com/posts/adapting-content-for-iphone-duo/) ·
  [Opt in to vertical bars on iPhone Duo](https://sarunw.com/posts/opt-in-to-vertical-bars-on-iphone-duo/) ·
  [ViewThatFits](https://sarunw.com/posts/swiftui-viewthatfits/)
- Foros: [iOS 27 automatic resize](https://developer.apple.com/forums/thread/832755) (Frameworks Engineer de Apple) ·
  [iPhone Duo Simulator](https://developer.apple.com/forums/thread/847556) (comunidad)
