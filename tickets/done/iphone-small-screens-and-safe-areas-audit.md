---
id: iphone-small-screens-and-safe-areas-audit
status: done
priority: medium
area: "design-system, iphone, adaptativo"
created: 2026-09-27
updated: 2026-09-28
source: "plan adaptativo (docs/exploracion/adaptativo-ipad-duo.md §3 y §7, fase iPhone), 2026-09-27"
---

# iPhone · en la pantalla más pequeña, que nada quede tapado ni cortado

**Fase iPhone del carril adaptativo, paso 3 de 13. Tamaño S–M.** Puede entrar en 2.1 si cumple la regla del iPhone.

## Qué le pasa al usuario

Nadie lo ha mirado en un iPhone SE, que es el más bajo (sin Dynamic Island y con botón de inicio) y el más estrecho.
Lo mismo vale para el Duo cerrado, que Apple describe como más ancho y más bajo que un iPhone normal. **Sin síntoma
reportado:** es una auditoría, y lo que encuentre es el trabajo.

## Lo medido (2026-09-27, este árbol)

- 29 `ignoresSafeArea`.
- 24 alturas fijas de 200 puntos o más (`.frame(height:)`).
- Dos cuadrados fijos: 300×300 (`SubscriptionView.swift:153`) y 320×320 (`SplashScreenView.swift:63`).

## Qué hacer

1. Recorrer en `YalaLane-Adapt-iPhone-SE` las mismas diez pantallas de
   [[iphone-large-text-sizes-break-layouts]], más la suscripción y los formularios con teclado (Nuevo registro,
   presupuesto, cuenta).
2. Buscar: contenido debajo de la barra de estado o del indicador de inicio, botones que el teclado tapa, alturas
   fijas que dejan cortada una gráfica o un texto, scroll que no llega al último elemento.
3. Revisar los 29 `ignoresSafeArea`: se queda el que sea un fondo; se va el que meta contenido o controles bajo el
   borde.
4. Arreglar lo barato (márgenes, `safeAreaInset`, alturas relativas). Lo que cambie la estructura de una pantalla →
   ticket aparte.

## Hecho cuando

- Capturas antes/después en `YalaLane-Adapt-iPhone-SE` y `YalaLane-Adapt-iPhone-ProMax`, a tamaño por defecto y a
  AX5, en `qa/evidencia-adaptativo-AAAAMMDD/iphone-small-screens-and-safe-areas-audit/`.
- Lista de lo encontrado en el propio ticket: arreglado aquí o con su ticket.
- XCUITest de las áreas tocadas en verde, por UDID. Gate verde.

## Relacionados

- [[ipad-native-app]] — paraguas. [[iphone-duo-native-app]] — el Duo cerrado es el siguiente caso estrecho.
- [[floating-buttons-cover-row-amounts-on-ipad-landscape]] — arregla la última fila tapada por los botones
  flotantes, también en iPhone. No se duplica aquí.

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

## Hecho (2026-09-28)

**Qué cambia para el usuario.** En un iPhone SE ya se puede guardar un registro con el texto en el tamaño máximo,
y el formulario, con el teclado abierto, deja de meterse bajo la barra. Las pantallas de éxito tras guardar un
registro y tras aprobar un borrador de la Bandeja caben en el SE, con «Editar» arriba y sus botones siempre a la
vista. Con el texto muy grande, el Panel y Registros vuelven a caber en el ancho de la pantalla, la tarjeta de
grupo enseña entera la suma de dos monedas y la cabecera de la suscripción no corta el título. A tamaño normal, lo
que ya cabía se ve igual.

**Premisas del ticket, medidas.** Los «29 `ignoresSafeArea`» son 27 llamadas (dos de las 29 líneas son comentarios)
y las alturas fijas de 200 pt o más son 27, no 24.

### Lo encontrado

| Dónde | Qué pasaba | Estado |
|---|---|---|
| Nuevo registro, SE a AX5 (y el chip «Cuenta» también en el ProMax a AX5) | El formulario no cabía: selector de tipo bajo la barra; «Guardar» y los chips de cuenta y subcategoría, fuera de la pantalla. No se podía guardar | **Arreglado**: scroll solo cuando no cabe |
| Nuevo registro, SE a tamaño normal, con teclado | El selector de tipo se metía bajo la barra y «Guardar» quedaba bajo el teclado, sin scroll | **Arreglado**, mismo cambio |
| Éxito tras guardar (`TransactionSuccessView`), SE a tamaño normal | «¡Listo!» y «Editar» se salían por arriba; «Registrar otro», por abajo | **Arreglado**: solo el centro se desplaza |
| Éxito tras aprobar un borrador (`InboxApproveSuccessView`), SE a tamaño normal y ProMax a AX5 | Lo mismo: «Editar» y el título fuera, «Aprobar siguiente» cortado | **Arreglado**, mismo molde |
| Panel y Registros, SE a AX5 | La píldora del período, de ancho fijo, no cabía y ensanchaba la columna entera: sin márgenes y con todo cortado contra los dos bordes; «Disponible» desaparecía | **Arreglado**: la píldora pasa a dos líneas y en el Panel baja bajo «Disponible» |
| Tarjeta de grupo con dos monedas, SE a AX5 | «S/ 190.00 + $ 46.…» | **Arreglado**: sin tope de líneas a esos tamaños |
| Suscripción, SE a AX5 | Cabecera de 320 pt fijos: «Desbloqu…», «Lleva tus fina…» | **Arreglado**: alto mínimo, no fijo |
| Bandeja, SE a AX5 | La cabecera fija no deja sitio a la lista: no se ve ni se abre ningún borrador | Ticket [[inbox-header-leaves-no-room-for-drafts-at-large-text]] |
| Primer gasto a mano | El aviso «¿era de prueba?» del Panel se come la pantalla de éxito (visto 1 de 8 veces) | Ticket [[first-expense-practice-alert-tears-down-the-success-screen]] |
| Guía de primeros pasos | Su tarjeta no se acota al área segura (inferido; no se puede capturar en test) | Ticket [[small-screen-leftovers-after-the-iphone-se-audit]] |
| Éxito de suscripción y de aprobación en lote | Misma forma sin scroll; sin medir | Mismo ticket |
| Tarjeta de Tendencias del Panel, SE a AX5 | Su cabecera se sale por los dos lados | Mismo ticket |
| Detalle de registro a AX5 | El texto pasa bajo «Cerrar» y «Editar» al desplazar | Mismo ticket |
| Última fila bajo los botones flotantes | Panel, Registros, Planificación, detalle de grupo | Ya en [[floating-buttons-cover-row-amounts-on-ipad-landscape]] |
| Rótulos cortados de Nuevo registro, filtros de la Bandeja, píldora «Nuevo registro» | Texto, no botones | Ya en [[large-text-leftovers-outside-the-main-iphone-screens]] (corregido su punto 3, que decía que no tapaba ningún botón) |

**Sin problema:** Nuevo presupuesto y Nueva cuenta con teclado (campo activo a la vista y «Guardar» en la barra, en
los dos iPhone y los dos tamaños); detalle de presupuesto, Grupos, detalle de grupo, Planificación y Perfil llegan
al final con el scroll. «Planificaci…» y «Viaje a Cus…» a AX5 son el título grande del sistema.

**Los 27 `ignoresSafeArea`, uno a uno.** Se quedan todos. 25 no meten contenido bajo el borde: 11 fondos, 5 velos
oscuros, 2 de confeti, el borde y el bloqueador transparente de la guía de primeros pasos, el fondo de material de
la barra de selección de la Bandeja (no sus botones) y 4 en `#Preview`. Los 2 que envuelven contenido también se
quedan: el splash tiene que centrarse igual que la pantalla de arranque, y su logo de 280 pt cabe en el SE; la
guía de primeros pasos necesita el mismo espacio de coordenadas que sus anclas. Lo que falla en la guía es que su
tarjeta no se acota, y eso va al ticket de restos.

**Las 27 alturas fijas.** Se tocó una: la cabecera de 320 pt de la suscripción, que cortaba su propio texto. 11
son gráficas dentro de un scroll y 6 son las ruedas de los selectores de período: alargan, no tapan. 7 son
decorativas y no cortan nada en el SE: los halos de 300 pt de las tres pantallas de éxito y del tutorial terminado,
los dos círculos del fondo de la suscripción y el de 320 pt del splash. Quedan el carrusel de 200 pt de la
bienvenida, que no estaba en el recorrido y no se midió, y una en un `#Preview`.

**Dónde, en el código.** `NewTransactionView`, `TransactionSuccessView` e `InboxApproveSuccessView` envuelven su
parte central en `GeometryReader` + `ScrollView` con `.frame(minHeight:)` y `.scrollBounceBehavior(.basedOnSize)`.
`PeriodSelectorLabel` deja de fijar su ancho a tamaños de accesibilidad. `HeroMonthView.topRow` usa
`AdaptiveRowStack`, `GroupCardView` quita el tope de líneas a esos tamaños y `SubscriptionView.heroSection` pasa a
`minHeight`. Las dos convenciones nuevas están en `.claude/rules/swiftui-ds.md`.

**Verificado** (simuladores del carril, iOS 27.0, por UDID):
- Capturas antes/después en `YalaLane-Adapt-iPhone-SE` y `YalaLane-Adapt-iPhone-ProMax`, a tamaño por defecto y a
  AX5, en `qa/evidencia-adaptativo-20260928/iphone-small-screens-and-safe-areas-audit/`. Su README cuenta el método y
  lo que el guion no alcanzó.
- **Tamaño por defecto:** píxel a píxel, solo cambian las pantallas arregladas; lo demás es animación o scroll,
  revisado uno a uno. Nuevo registro sin teclado, idéntico en los dos iPhone.
- Gate: builds `Yala` y `Yala Dev` sin avisos nuevos; `YalaTests` entero en verde (8407 tests en 799 suites); XCUITest
  de las 18 suites de las 13 áreas tocadas en `YalaLane-Adapt-iPhone-ProMax`, por UDID y en cola (44 casos, 0 fallos,
  0 reinicios, centinela en 0).

**Estado: `done`, sin device-QA.** Es maquetación y el simulador la pinta igual que el iPhone.
