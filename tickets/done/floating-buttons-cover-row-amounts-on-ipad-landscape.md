---
id: floating-buttons-cover-row-amounts-on-ipad-landscape
status: done
priority: medium
area: "design-system, records, planning, groups, ipad, cola-b"
created: 2026-09-26
updated: 2026-10-03
source: "exploración iPad (docs/exploracion/ipad-nativo.md §4), 2026-09-26"
---

# En iPad en horizontal, los botones flotantes tapan los importes de las filas

**Entra en Cola B**: toca las mismas pantallas que el rediseño y es barato.

## Qué le pasa al usuario

En un iPad en horizontal, las filas ocupan todo el ancho y el importe queda pegado al borde derecho,
justo debajo de los botones flotantes. Medido en el simulador el 2026-09-26:

- **Registros**: Yala IA y «+» tapan el importe y la etiqueta de las filas de abajo
  (`docs/exploracion/ipad-nativo/27-pro13-horizontal-registros.jpg`).
- **Planificación**: el «+» tapa el importe de un presupuesto
  (`docs/exploracion/ipad-nativo/64-mini-horizontal-planificacion.jpg`).
- **Grupos**: el «+» tapa el importe de la última fila (`docs/exploracion/ipad-nativo/71-mini-grupos-detalle.jpg`).

## Qué hacer

Reservar sitio para los botones: margen inferior del contenido igual al alto de la pila de botones
(`contentMargins`/`safeAreaInset` en el scroll), para que la última fila pueda subir por encima. Con el
ancho legible de [[cola-b-redesigns-must-hold-up-at-ipad-width]] el importe ya no llega al borde, pero
el margen hace falta igual: en iPhone la última fila también queda debajo al final del scroll.

Buscar **todas** las pantallas con botón flotante antes de dar el arreglo por completo (`fab_` en los
identificadores).

## iPhone Duo (2026-09-27)

Los botones flotantes son una vista propia, no botones de barra, y Apple no documenta qué pasa con ellos cuando en el
Duo la barra de pestañas se va al lateral. Lo mide la fase Duo ([[iphone-duo-native-app]]); aquí basta con que el
margen inferior sea relativo al área segura y no a una altura fija.

## Hecho cuando

- Capturas antes/después con la última fila visible por encima de los botones, en `YalaLane-Adapt-iPad-Pro-13`
  horizontal (Registros, Planificación, Grupos) y en `YalaLane-Adapt-iPhone-SE` y `-ProMax` al final del scroll, a
  tamaño por defecto y a AX5.
- Las pantallas con `fab_` en sus identificadores, todas revisadas y listadas aquí. Gate verde.

## Relacionados

- [[ipad-native-app]] — paraguas. [[fab-appears-without-animation]] — mismo botón.

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

## iPhone en horizontal (2026-10-01)

Desde el paso 11 del carril ([[iphone-supports-landscape-orientation]]) el iPhone gira, y pasa lo mismo: en el Pro Max
girado, el «+» de Planificación tapa el importe del primer presupuesto, y en Registros Yala IA y «+» caen sobre la
lista (`qa/evidencia-adaptativo-20261001/iphone-supports-landscape-orientation/despues/promax__03-planificacion-h.jpg`
y `promax__04-registros-h.jpg`). El arreglo de aquí lo cubre: el margen inferior por área segura vale en los dos.

**Visto otra vez (2026-10-01, [[iphone-landscape-headers-fill-the-short-screen]]).** Con la cabecera compactada, la
primera fila de Registros sube a la vista en el SE y el Pro Max girados, y Yala IA y «+» tapan ahora su importe
(`qa/evidencia-adaptativo-20261001/iphone-landscape-headers-fill-the-short-screen/comparativa-se-04-registros-horizontal.jpg`).
No se tocó allí.

## Resuelto (2026-10-03)

**Qué cambia para el usuario.** Al final de Registros, de Estadísticas › Registros y del Panel, la última fila sube por
encima de Yala IA y «+»: el importe ya no queda debajo. En iPad, en iPhone, girado y con texto grande.

**Por qué solo esas tres.** Las siete pantallas con botón flotante se midieron al final del scroll. Las de un botón
(Presupuestos, Pagos planificados, Grupos, detalle de grupo) ya reservaban 100 pt para un botón que ocupa 80, y dieron
cero textos tapados antes de tocar nada. Las de dos botones no: Registros (y Estadísticas › Registros, que monta la
misma lista) reservaban 100 para una pila de 148, y el Panel solo 32. Las capturas de Planificación y Grupos del iPad
mini de arriba son a mitad de scroll, donde un botón flotante tapa siempre lo que pasa por debajo.

**Cómo.** `DS.Button.fabStackClearance(buttons:)` calcula el margen con los mismos tokens que dibujan la pila (botones,
`Spacing.md` entre ellos, `Spacing.xxl` debajo, `Spacing.lg` de aire): 96 con uno, 164 con dos. Va como margen
inferior DENTRO del contenido del scroll, que ya suma el área segura, así que es relativo a ella y no a una altura fija
(lo que pedía la nota del Duo). `RecordsTabView` y `PanelView` usan el de dos. Test: `YalaTests/FabStackClearanceTests`.

**Medido** (texto tapado / holgura al techo de los botones, antes → después): Registros en iPad Pro 13 horizontal 3 →
0 (−34 → 30 pt); en SE y Pro Max, vertical y girados, 3 → 0; SE con AX5, 1 → 0; Panel en SE 7 → 0 (−98 → 34). Tabla
entera, pantallas revisadas y lo que no es de aquí: `qa/evidencia-adaptativo-20261003/floating-buttons-cover-row-amounts-on-ipad-landscape/README.md`.

**Un efecto que se ve.** En el iPad Pro 13 horizontal el Panel no tenía scroll suficiente para que salieran sus
botones flotantes; con el margen nuevo, al final salen (sin tapar nada). Es la regla de siempre: salen cuando la fila de
acciones se va por arriba.

**Pantallas `fab_` revisadas:** Panel, Estadísticas › Registros, Registros (`fab_chat`, `fab_new_transaction` y su
menú `fab_voice`/`fab_image`/`fab_manual`/`panel_fab_group`); Presupuestos (`budgets_create_fab`), Pagos planificados
(`scheduled_payments_create_fab`), Grupos (`groups_fab_new` y su menú `groups_fab_new_group`/`groups_fab_new_expense`),
detalle de grupo (`group_detail_fab_new_expense`).
