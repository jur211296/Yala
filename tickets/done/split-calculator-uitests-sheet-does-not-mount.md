---
id: split-calculator-uitests-sheet-does-not-mount
status: done
priority: medium
area: "transactions, qa"
created: 2026-11-16
updated: 2026-11-17
source: "gate del encargo hero claro (2026-11-16) + nocturna del CI del mismo día"
---

# Los dos casos de `SplitCalculatorUITests` no llegan a abrir la calculadora de reparto

## Qué pasa

`SplitCalculatorUITests#test_applyingSplitShowsChipInForm` y `#test_splitCalculatorComputesPortion` caen en el mismo
aserto de su ayudante `openSplitWith50Percent` (línea 43): «No se montó SplitCalculatorSheet (selector de modo)».

## Medido

- **Nocturna del CI del 2026-11-16 (18:31 UTC, run 43929672868), tanda 8**: el mismo aserto, con sus reintentos. Esa
  corrida es de `2.3` antes del encargo del hero claro, así que el rojo no viene de él.
- **Gate local del hero claro (2026-11-16, iPhone 17 Pro, iOS 27.2)**: los dos casos rojos en el mismo punto, con el
  centinela diciendo que la corrida estuvo sola (`sim-libre.sh --vigilar` → 0). Los otros 50 casos de la tanda, verdes.

## Pista

Las decisiones de Jürgen del 16-nov (17:40) piden encolar «el bug de Nuevo registro que no queda en reposo para
XCUITest». Esta calculadora se abre desde Nuevo registro: probablemente es el mismo bug. Si ya hay ticket de ese bug,
este se absorbe en él.

## Cierre (2026-11-17)

No era el reposo de «Nuevo registro»: con el teclado abierto, la fila de categorías a un toque (decisión 21 de 2.3) baja
«Mi parte» hasta debajo del teclado y el toque se pierde. La prueba cierra el teclado antes de tocarlo. Detalle en
`tickets/done/2026-11-16-ui-tests-rojos-tandas.md`.
