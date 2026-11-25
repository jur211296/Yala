---
name: un-flag-en-uitesthooks-infla-la-interfaz-del-gate
description: Añadir un flag de semilla a UITestHooks hace que interfaz-de-lo-tocado elija ~9 clases ajenas y deje fuera por el techo las del área de verdad; se cambia la lista a mano y se dice.
metadata:
  type: feedback
---

Tocar `Yala/App/UITestHooks.swift` (aunque solo sea un `-uitest-…` nuevo) hace que `qa/scripts/interfaz-de-lo-tocado.py`
una por identificador (`uitest_ready`, `trial-used`) una decena de clases que no miran el cambio, y con el techo de
30 min deja FUERA justo las del área (en el lote 3 de la Bandeja: `InboxCrudUITests`, `InboxDuplicateCheckUITests`).

**Why:** medido el 2026-11-24 (Bandeja, fila con fuentes): 20 clases elegidas, 9 por UITestHooks; las que tocaban la
fila y el posible duplicado, fuera por el techo.

**How to apply:** en el gate, cuando el informe atribuya clases a «UITestHooks.swift: uitest_ready, trial-used»,
sustitúyelas por las del área que quedaron fuera y anótalo en el informe del gate, el PR y «Decidido sin consultar».
Y tras `YalaTests` entero, reinicia el simulador antes de la interfaz ([[ui-tras-yalatests-entero-reinicia-el-simulador]]):
volvió a salir «AX loaded» con cero casos.
