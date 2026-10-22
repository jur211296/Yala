---
name: gate-paso3-no-detecta-cero-casos
description: El paso 3 del gate (XCUITest) puede dar TEST SUCCEEDED sin ejecutar nada y su grep no lo detecta — YalaUITests es XCTest, no Swift Testing, y no emite «Test run with»
metadata:
  type: feedback
---

En el paso 3 del gate, cuenta los XCUITest con `^Test Suite '.*' (passed|failed)` y
`Executed [0-9]+ test` — **no** con los marcadores del paso 2.

**Why:** el paso 2 obliga a verificar `Test run with N tests in M suites` porque el modo de fallo
«cero casos» de Swift Testing sale con exit 0 y `TEST SUCCEEDED`. El paso 3 hereda ese mismo grep,
pero `YalaUITests` es **XCTest**: emite `Test Suite '<X>' passed` y `Executed N tests`, y **nunca
emite `Test run with`**. Medido el 2026-09-06: 5 suites de XCUITest dieron como única salida
filtrada `** TEST SUCCEEDED **` — indistinguible de una corrida que no ejecutó nada. Al re-grepear
salieron 16 tests en 5 suites. Un nombre de suite mal escrito ahí pasa por verde sin dejar rastro.

**How to apply:** siempre que corras el paso 3, saca los nombres de suite ejecutados
(`grep -oE "^Test Suite '[A-Za-z]+UITests'" | sort -u`) y compáralos uno a uno con los que pediste.
Si no cuadran, no está verde: está vacío.

**Y en el paso 2 el número que engaña es el OTRO: la M de `in M suites`.** El 10-sep pedí **11**
suites con `-only-testing` y la línea dijo `Test run with 65 tests in 8 suites passed`, exit 0,
`TEST SUCCEEDED`. Las tres que faltaban eran nombres de **FICHERO** (`RelaunchNetLogicTests`,
`PersonalSwapReleaseTests`, `NeutralMountRelaunchZeroTests`) y no de tipo: un fichero de este repo
suele declarar **cuatro `struct` con nombres distintos del suyo**, y `xcodebuild` no protesta por un
`-only-testing` que no existe — simplemente no corre nada. ⇒ **cuenta las suites que pediste y
compáralas con la M antes de leer el «passed»**; si no cuadra, saca los nombres reales
(`grep -oE '^(nonisolated )?(final class|struct) [A-Za-z0-9_]+' <fichero>`) y vuelve a correr.

Y el corolario general, que es el mismo de siempre:
[[feedback_mis_mediciones_fallan_por_el_filtro]] — un «cero» casi nunca es el código, es el filtro.
Aquí el filtro no daba cero: daba **verde**, que es peor.
