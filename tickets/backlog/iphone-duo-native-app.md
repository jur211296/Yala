---
id: iphone-duo-native-app
status: backlog
priority: medium
area: "platform, iphone-duo, adaptativo"
created: 2026-09-09
updated: 2026-10-08
source: idea Jürgen 2026-09-09; plan adaptativo (docs/exploracion/adaptativo-ipad-duo.md §5 y §7), 2026-09-27
---

# iPhone Duo · fase Duo: barras en el lateral, pliegue y SDK 27.1

**Paso 6 de 13 del carril adaptativo. Tamaño M. Después de la fase 1 y de
[[xcode-27-1-with-the-iphone-duo-simulator]].**

## La pregunta del 9-sep, contestada

Jürgen lo dejó abierto: app nativa aparte o adaptar la de iOS. **Adaptar** (ADR «[2026-09-27] Yala se adapta por
espacio, no por dispositivo»). Apple publicó su documentación el 9-sep y lo dice sin ambigüedad: «you're still
designing for iPhone». La pantalla exterior es compact, como cualquier iPhone, y la interior regular, como un iPad. El
grueso del trabajo lo hacen la fase iPhone y la fase 1; este ticket es lo que queda propio del Duo.

El Duo sale el **23-oct-2026** con iOS 27.1. Hasta entonces, y después si no se hace esta fase, Yala funciona en él en
modo compatible: sin llegar al borde de la pantalla en la interior.

## Lo documentado que pide trabajo (fuentes en `adaptativo-ipad-duo.md` §1.1)

- **Barras en el lateral**: en el Duo cerrado y en el abierto en horizontal, barras de navegación, herramientas y
  pestañas pasan a un lateral vertical. Solo pasan los botones con icono; pide `Label` con icono y título, y
  posiciones semánticas (`cancellationAction`, `topBarPinnedTrailing`).
- **Pliegue**: `NavigationSplitView`, hojas, alertas y menús se apartan solos. Las vistas propias (rejillas del
  Panel, donuts de Distribución) no: rejillas en pares, y `ReservedRegion` solo si algo cae sobre el pliegue.
- **Pantalla completa**: solo compilando con el SDK de 27.1.
- **Ventanas**: el Duo abierto deja abrir varias ventanas de la misma app si el iPad lo deja. Lo cubren
  [[ipad-multiple-windows-share-one-navigation-state]] (fase 0) y [[ipad-real-multiwindow-with-per-scene-state]].
  **Pendiente de medir aquí (2026-10-02)**, cuando exista `YalaLane-Adapt-iPhone-Duo`: la multiventana ya está
  encendida con estado por ventana. Comprobar que, cerrado, el menú contextual de un registro o un grupo NO ofrece
  «Abrir en una ventana nueva» (`OpenInNewWindowButton`, gateado por `supportsMultipleWindows`) y que, abierto, sí; y
  que la ventana nueva aparece en la pantalla interior.

## Lo no documentado, que esta fase mide primero

- ¿La `TabView` con `.sidebarAdaptable` da barra lateral en el Duo abierto? Su documentación solo habla de iPadOS e
  iOS. sarunw.com (fuente secundaria) dice que sí; se confirma en el simulador.
- ¿Dónde caen los botones flotantes (`FABStackView`) cuando la barra de pestañas está en el lateral? Apple no habla
  de botones flotantes; `toolbarVerticalEdge` (iOS 27.1) dice en qué lado está la barra.
- Tamaño en puntos de cada pantalla (Apple publica pulgadas).

## Qué hacer

1. Con `YalaLane-Adapt-iPhone-Duo`: capturas de las pantallas principales en las cuatro posturas **antes** de tocar
   nada, y contestar las tres preguntas de arriba en este ticket.
2. Botones de barra con icono y título; posiciones semánticas; `visibilityPriority` donde se desborden.
3. Botones flotantes lejos de la barra vertical (tras `if #available(iOS 27.1, *)`).
4. Rejillas propias en pares y nada importante en el pliegue.
5. Compilar con el SDK 27.1 es **decisión de release de Jürgen**: esta fase deja el código listo y probado en el
   simulador; no cambia el Xcode de la release.

## Hecho cuando

- Capturas antes/después en `YalaLane-Adapt-iPhone-Duo`: cerrado, abierto en vertical, abierto en horizontal y a
  medio plegar (controles de postura de Device Hub), de Panel, Registros con un registro abierto, Planificación,
  Estadísticas y Nuevo registro. Ningún control ni importe en el pliegue ni bajo la barra lateral.
- Abrir y cerrar con un registro abierto no lo pierde.
- En `YalaLane-Adapt-iPhone-SE` y `-ProMax`: sin diferencias, o solo las permitidas por la regla del iPhone.
- XCUITest de navegación en el Duo, por UDID. Gate verde (en 27.0, como siempre).

## Relacionados

- [[ipad-native-app]] — paraguas del carril. [[apple-watch]] — la misma tanda de plataformas del 2026-09-09.
- [[sheet-size-follows-the-device-not-the-window]] — sin él, las hojas del Duo abierto salen con tamaño de iPhone.
- [[iphone-supports-landscape-orientation]] — el horizontal en el Duo cerrado. **Hecho el 2026-10-01** (iPhone: vertical y
  horizontal izquierda/derecha). Pendiente aquí: girar el Duo cerrado en `YalaLane-Adapt-iPhone-Duo` y comprobar que
  sigue y conserva lo abierto (`IPhoneLandscapeUITests` por UDID).

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

## Medido en 2.1 (triage 2026-10-08)

- No hay código propio del Duo en `Yala/`: `toolbarVerticalEdge`, `visibilityPriority`, `ReservedRegion` y `onHingeChange` dan cero.
- El prerrequisito `xcode-27-1-with-the-iphone-duo-simulator` sigue en `backlog/`, así que no hay `YalaLane-Adapt-iPhone-Duo` para medir.

Triage 2026-10-08: abierto · medium → medium · nada del Duo en el código todavía, y sigue bloqueado por `xcode-27-1-with-the-iphone-duo-simulator`; mientras tanto la app corre en modo compatible.
