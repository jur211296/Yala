---
name: trasplantar-una-regla-hereda-su-universo
description: Al reusar una regla de una pantalla en otra, comprueba que su entrada «available» significa lo mismo; en Exportar «Ocultar» las monedas disponibles eran las de lo oculto
metadata:
  type: feedback
---

Reusar `RecordsAmountFilterCurrencyLogic` en Exportar era correcto; pasarle `availableCurrencies(selectedAccounts:)` no:
en el modo global «Ocultar» del asistente, las cuentas marcadas son las que DESAPARECEN, así que «disponibles» eran las
monedas de lo oculto. La review adversarial lo cazó (2026-10-28, PR #670); mis tests pasaban porque el XCUITest usaba
todo marcado, el único caso donde no se nota.

**Why:** una función pura con un parámetro «available» parece portable, pero el universo que lo rellena es de la pantalla
de origen (Registros tiene dos listas; Exportar, un modo global).

**How to apply:** al trasplantar una regla, escribe en una frase qué es cada entrada EN la pantalla nueva, y que el
escenario del test cambie de veredicto con el bug (desmarca algo, no lo dejes todo por defecto).
Relacionado: [[el-control-que-no-recorre-el-camino-no-descarta]].
