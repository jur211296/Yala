---
id: panel-spent-per-account-counts-refunds-as-spending
status: done
priority: medium
area: "panel, calculations"
created: 2026-10-03
updated: 2026-10-10
source: hallazgo de la revisión adversarial de panel-accounts-redesign, 2026-10-03
---

# Lo gastado por cuenta suma las devoluciones como gasto

`PanelViewModel.calculateAccountPeriodExpenses` suma `abs(transaction.amount)` de todo registro con categoría de
gasto: una devolución de +30 en «Supermercado» **sube** lo gastado en vez de bajarlo. Es lo que enseña la tarjeta de
cuenta en modo «solo gastos». La vista de cuenta (`AccountDetailCalculator.topCategories` / `dailySpending`) copia la
misma regla a propósito, para no contradecir a la tarjeta. Registros y Tendencias ya acumulan con signo
(`TransactionClassificationLogic`). Arreglarlo es cambiar las dos a la vez, con test de paridad.

## Medido en 2.1 (triage 2026-10-08)

- Sin cambios desde el ticket: `calculateAccountPeriodExpenses` hace `guard transaction.category?.isIncome == false` y suma `abs(transaction.amount)`. `AccountDetailCalculator` sigue con `abs` en `topCategories` y `dailySpending`.
- Sube a `medium`: una devolución es uso normal y la cifra que ve la persona sobre su propio gasto sale inflada. No es pérdida de datos. Gemelo de pantalla, no duplicado, de `records-standalone-amount-discrepancy` (medium).

Triage 2026-10-08: abierto · low → medium · `PanelViewModel.calculateAccountPeriodExpenses` sigue sumando `abs(transaction.amount)` de todo registro con categoría de gasto, y `AccountDetailCalculator` copia la regla; la tarjeta enseña un gasto mayor que el real tras una devolución normal.

## Cerrado (2026-10-10)

Una sola regla, `AccountSpendingLogic`, para la tarjeta de cuenta del Panel (`spentByAccount`) y la vista de cuenta
(`AccountDetailCalculator`: «En qué se fue» y su curva). Acumula con signo: un gasto de −100 y una devolución de +30 en
la misma categoría de gasto dan 70 en los dos sitios. Sin devoluciones, igual que antes. Un neto negativo (más devuelto
que gastado) se enseña negativo, y «En qué se fue» no pinta esa categoría.

Red: `YalaTests/AccountSpendingParityTests` (control rojo con `abs`: 2 casos; mutante del Panel sin cablear: el scan del
cuerpo cae). Sin device-QA: no hay seed ni camino del formulario que produzca una devolución en categoría de gasto, y el
número queda fijado por los tests.
