---
id: 2026-11-28-budget-at-limit-sonda-lee-un-gasto-10-veces-menor
status: backlog
priority: medium
area: "qa, planificacion, presupuestos"
created: 2026-11-28
updated: 2026-11-28
source: "QA completo de 2.3 del 27/28-nov (sesión del CI rojo y la build 12), tanda 13"
---

# «En el límite»: la prueba lee un gasto del mes diez veces menor que el real

## Qué pasa

`BudgetAtLimitUITests.test_budgetAt90Percent_saysAtLimit_inTheRowAndTheDetail` cae 3 de 3 en el QA completo de `2.3`
del 28-nov (01:30 de Lima, run 46091156235, tanda 13). El 26-nov pasaba (run 45932539245, tanda 9).

La prueba crea un presupuesto global de S/ 1 («QA Sonda»), lee su porcentaje para saber cuánto va gastado en el mes y
crea otro con el límite que deja ese gasto al ~90 % («QA Limite»). Este segundo sale con «900 por ciento gastado,
S/ 9,071.00 de S/ 1,007.00». O sea: la sonda leyó unos S/ 906 y el gasto real del mes es S/ 9,071, diez veces más.

## Lo que se midió y lo que no

- El formulario de presupuestos no cambió desde el 21-nov.
- `BudgetsViewModel.loadData` carga al menos el último año, así que no es una ventana corta de movimientos.
- No se reprodujo en local (la sesión ya había pasado su tope de pruebas de interfaz).

## Hipótesis por mirar

1. La fila de un presupuesto recién creado pinta un gasto calculado antes de que termine la recarga (sería un bug
   visible: un porcentaje falso un momento).
2. El segundo presupuesto toma otro período (anual en vez de mensual): a fines de noviembre el gasto del año es ~10
   veces el del mes.
3. La prueba lee el porcentaje de la sonda con separador de miles (`(\d+) por ciento` solo toma los últimos dígitos).

## Para cerrarlo

Reproducir con el seed `realista` a fin de mes, mirar la fila de la sonda con `axe describe-ui` y decidir si es la app
o la prueba. Si es la app, prueba unitaria en `BudgetsViewModel` además de este XCUITest.
