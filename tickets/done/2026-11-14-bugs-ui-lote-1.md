---
id: 2026-11-14-bugs-ui-lote-1
status: done
priority: high
area: "panel, statistics, records, cash-flow"
created: 2026-11-14
updated: 2026-11-14
card: tablero-2-3-con-texto-al-maximo-el-panel-se-sale-gphj
source: "encargo «Bugs de interfaz de 2.3, lote 1» (Jürgen, 14-nov)"
---

# Bugs de interfaz de 2.3, lote 1

Cuatro tarjetas del backlog de 2.3. Tres salen arregladas; la de Siri y la pestaña «Buscar» en inglés queda en su
tarjeta, porque los dos arreglos caen fuera del «toca» del lote.

## 1 · Con texto al máximo el Panel se salía por los dos lados (card gphj, alta)

**Causa medida** (árbol de accesibilidad del simulador, AX5, iPhone 17 Pro): no era el carrusel de cuentas, como decía la
tarjeta. Plegado o desplegado, «Tus finanzas» daba el mismo ancho. Era la fila «14 nov 2024 S/ 12,406 → hoy S/ 59,701 ·
+381 %» bajo la gráfica de saldo (decisión 11 de 2.3, 11-nov). Sus piezas llevan `.fixedSize()`, y
`ViewThatFits` se queda con su última forma aunque no quepa: el lado «14 nov 2024 S/ 12,406.00» solo medía 469 pt, y el
Panel entero pasaba a 604 pt en una ventana de 402. Primero se probó con la variación en su propia línea: el desborde
bajó de x = −85 a x = −49, pero no bastó.

**Arreglo** (`TrendsCarouselWidget.swift`, `toca` ampliado con autorización de Jürgen): una tercera forma en la que la
fecha y el monto de cada lado van en líneas distintas. A tamaño normal no cambia nada (`ViewThatFits` sigue eligiendo
la primera forma).

**Verificado:** `PanelQuickActionsLargeTextUITests` y `FormClarity23UITests.test_v3_largeText_manualEntryIsReachable`
pasan. En el árbol ya no hay nada fuera de los 402 pt, salvo los chips del carrusel horizontal, que se desplazan a
propósito. El «+» flotante se ve y se puede tocar.

## 2 · Hueco de más bajo los chips en Estadísticas › Registros (card 4wqy)

**Causa** (la de la tarjeta, confirmada): `RecordsListSearchSlot` pintaba siempre un `VStack`, vacío con el buscador
oculto, y la pila de `RecordsTabView` le sumaba su espaciado.

**Arreglo:** sin campo, el hueco no pinta nada. La animación al asomar y la escucha del texto suben a la pila de
`RecordsTabView` (`recordsListSearchContainer`, un solo modificador más). Ahora la animación cubre también lo que se
aparta debajo.

**Verificado:** `StatisticsHeroLikePanelUITests.test_statisticsHeroIsThePanelHero_inEveryTab` pasa (antes: 43 pt) y
`RecordsListSearchUITests` sigue verde (el campo asoma al tirar y busca).

## 3 · Siri y Atajos y la pestaña «Buscar» en español con Yala en inglés (card 3kns)

**No se arregló aquí.** La fila sale de `ProfileView.swift` y la pestaña de `ContentView.swift`, los dos fuera del
«toca». La nota de la tarjeta dice dónde y cómo arreglarlo.

## 4 · Flujo de caja: un mes pasado decía «Te quedan» (card eqw2)

**Confirmado por código:** `CashFlowDetailLineRow.trailingLabel` elegía «Te quedan» sin mirar si el mes había cerrado.
**Arreglo:** un gasto por debajo de lo planeado en un mes pasado dice «Te sobró» (`budgets.l9.leftoverLabel`, la misma
clave que el período cerrado de Presupuestos, ya presente en los 16 idiomas). No hizo falta ningún texto nuevo.

**Fuera, a tarjeta nueva** (`tablero-flujo-de-caja-un-ingreso-de-un-mes-pasad-i0ks`): un ingreso de un mes pasado
sigue diciendo «Te falta recibir». Es el mismo patrón, pero pide un texto nuevo y su accesor en `Yala/Utils/`.

## Tests

`YalaTests/BugsUILote1/BugsUILote1Tests.swift`: la etiqueta del flujo de caja según el mes y si se pasó, «Te sobró» en
los 16 idiomas, y un scan del cableado del hueco del buscador. Los XCUITest de las tarjetas ya existían y son la red
visual.

## Pendiente fuera de este PR

El PR de las tandas rojas de UI (#978) deja `XCTExpectFailure` no estrictos con los ids gphj y 4wqy en
`PanelQuickActionsLargeTextUITests`, `FormClarity23UITests` y `StatisticsHeroLikePanelUITests`. Con este arreglo ya no
hacen falta, y se quitan en el PR que aterrice segundo.
