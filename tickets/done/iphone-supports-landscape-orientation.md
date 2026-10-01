---
id: iphone-supports-landscape-orientation
status: done
priority: low
area: "platform, iphone, iphone-duo, adaptativo"
created: 2026-09-27
updated: 2026-10-01
source: "plan adaptativo (docs/exploracion/adaptativo-ipad-duo.md §7), 2026-09-27"
---

# iPhone · ¿Yala gira a horizontal? (decisión de producto)

**Paso 11 de 13. Tamaño M. Decidido por Jürgen el 2026-09-27: opción A. Hecho el 2026-10-01.** Jürgen citó «horizontal» entre las mejoras
de iPhone del 27-sep; no entra como mejora de bajo riesgo por lo que sigue.

## La situación

- **Medido:** en iPhone, Yala solo va en vertical: `INFOPLIST_KEY_UISupportedInterfaceOrientations =
  UIInterfaceOrientationPortrait` en los cuatro build settings (`project.pbxproj:553`, `:601`, `:864`, `:911`).
- **Documentado (Apple):** en el Duo, la pantalla exterior respeta esa preferencia y la interior la ignora. Apple
  anima a abrir el horizontal en la exterior, «as people may want to set the phone down like a tent» (tech talk
  *Prepare your app for iPhone Duo*).
- **Por qué no es de bajo riesgo:** un iPhone Pro Max en horizontal tiene ancho **regular**, así que pintaría la
  interfaz de iPad. Sin la fase 1 hecha, girar enseñaría columnas estiradas. Y toca todas las pantallas.

## La decisión

| Opción | Qué supone |
|---|---|
| **A · Abrir horizontal tras la fase 1** (recomendada) | Coherente con el Duo y con el HIG; la fase 1 ya da la interfaz de pantalla ancha. Coste: una pasada por todas las pantallas |
| B · Seguir solo en vertical | Cero coste. En el Duo cerrado y girado, Yala no gira |

## Hecho cuando (si se elige A)

- Capturas en `YalaLane-Adapt-iPhone-SE` y `YalaLane-Adapt-iPhone-ProMax`, vertical y horizontal, a tamaño por
  defecto y a AX5, de las pantallas principales.
- Girar con un registro abierto y con un formulario a medias no pierde lo abierto ni lo escrito.
- XCUITest de navegación en horizontal en los dos iPhone, por UDID. Gate verde.

## Resultado (2026-10-01)

**Yala gira en iPhone.** Vertical y horizontal a izquierda y derecha; boca abajo no (los iPhone con Face ID no lo
hacen). Abierto en los cuatro build settings de `Yala` y `Yala Dev`. Ningún cambio de código: la app ya decidía la
forma por el ancho de la ventana (fase 1), así que en el SE girado sigue la interfaz de iPhone y en el Pro Max girado
(ancho regular) sale la de pantalla ancha: pestañas con las seis páginas, lista y detalle a la vez.

- **Girar no pierde nada:** un registro abierto sigue abierto (abierto en vertical o en horizontal) y el formulario de
  nuevo registro conserva lo escrito, al ir y al volver.
- **XCUITest** `IPhoneLandscapeUITests` (4 casos), verde por UDID en SE y Pro Max, y en iPad mini como regresión.
  Control negativo: con solo vertical, los 4 en rojo en la espera del giro.
- **Capturas** SE y Pro Max × vertical/horizontal × texto por defecto/AX5, antes y después:
  `qa/evidencia-adaptativo-20261001/iphone-supports-landscape-orientation/`. En vertical, 24 de 28 parejas a 0 px; las
  otras cuatro, el punto animado «Hoy» y un aviso de Grupos con tope semanal.
- **Encontrado y no tocado:** las cabeceras de Registros y Estadísticas llenan casi todo el alto en horizontal, y con
  AX5 la columna de la lista del Pro Max girado queda estrecha → [[iphone-landscape-headers-fill-the-short-screen]].
  El «+» flotante tapa un importe en el Pro Max girado → anotado en [[floating-buttons-cover-row-amounts-on-ipad-landscape]].
- **Duo cerrado:** lo hereda; medirlo queda en [[iphone-duo-native-app]] (necesita Xcode 27.1).

## Relacionados

- [[ipad-native-app]]. Depende de [[ipad-sidebar-and-list-detail-for-records-and-planning]] y de
  [[iphone-large-text-sizes-break-layouts]]. [[iphone-duo-native-app]].

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
