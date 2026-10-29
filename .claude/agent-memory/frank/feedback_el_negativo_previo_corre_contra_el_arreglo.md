---
name: el-negativo-previo-corre-contra-el-arreglo
description: Un XCUITest de «antes no está, luego aparece» con un seam de reloj: el plazo del seam tiene que superar la navegación, o con el arreglo cae en el negativo
metadata:
  type: feedback
---

Un XCUITest que afirma «sin X todavía, la fila no está» y luego espera a que aparezca, con X llegando por un seam de
reloj (`-uitest-fake-cloud-session-after N`), solo discrimina si N supera lo que tarda el test en llegar a mirar.
Card n533 (2026-10-28): con N=8 el «antes» salía rojo en la espera —bien— pero con el arreglo salía rojo en el
NEGATIVO, porque bajar 14 veces por Ajustes en iOS 27.0 tarda más de 8 s y la fila ya había aparecido. Sin el arreglo
ese negativo pasaba siempre: no se veía el problema hasta tener el arreglo puesto.

**Why:** el negativo previo y la espera corren contra el mismo reloj; el bug lo enmascara porque nunca repinta.
**How to apply:** pon el plazo del seam muy por encima de la navegación (25 s ahí), para de bajar en cuanto llegues
(un id del final, no N swipes fijos) y verifica con los tres: rojo sin arreglo, verde con él, rojo con el mutante.
Relacionado: [[un-seam-de-reloj-arranca-bajo-el-splash]].
