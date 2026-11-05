---
id: report-grouping-sheet-row-center-does-not-respond
status: done
priority: low
area: "reports, ui"
created: 2026-10-18
updated: 2026-11-05
source: "visto al escribir `AccountCardReportsUITests` (entrega 4 de la tarjeta con varias divisas)"
---

# En «Profundizar», tocar el centro de una dimensión no la añade

## Qué pasa

En Reportes › Comparativa › «Profundizar», las filas de «Disponibles» (Categoría, Cuenta, Moneda…) solo responden si se
toca el «+» o el nombre: el resto de la fila está muerto. Medido el 2026-10-18 en el simulador (iOS 27.0): un toque en el
centro de la fila «Cuenta» no la añade; en el «+», sí. El XCUITest de la entrega 4 toca el «+» a propósito por esto.

## Por qué

`GroupingReorderSheet`, sección de inactivas: el `label` del `Button` es un `HStack` sin `Spacer` ni `contentShape`,
así que el área que responde es la de sus glifos. Es la regla de `swiftui-ds.md` (filas clicables con `contentShape`
dentro del label).

## Qué hacer

`Spacer()` + `.contentShape(Rectangle())` dentro del label, y un XCUITest que toque el centro de la fila.

## Resuelto (2026-11-05, lote P5 de la 2.3)

- `GroupingReorderSheet`: `Spacer(minLength: 0)` + `.contentShape(Rectangle())` dentro del label de la fila de
  «Disponibles». Toda la fila añade la dimensión.
- Red: `AccountCardReportsUITests#test_report_byCard_showsTheCardOnceConverted_andByLineShowsBothLines` ya no toca el
  «+»: toca el centro de la fila (el `tap()` de XCUITest) y comprueba que la dimensión pasa a «Activos». Medido: con el
  código de antes, rojo («Tocar el centro de la fila «Cuenta» no la añadió»); con el arreglo, verde.
- El resto de botones de `Reports/` son chips con fondo relleno y sin hueco: no tienen el problema.
