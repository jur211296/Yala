---
id: panel-spent-per-account-counts-refunds-as-spending
status: backlog
priority: low
area: "panel, calculations"
created: 2026-10-03
updated: 2026-10-03
source: hallazgo de la revisión adversarial de panel-accounts-redesign, 2026-10-03
---

# Lo gastado por cuenta suma las devoluciones como gasto

`PanelViewModel.calculateAccountPeriodExpenses` suma `abs(transaction.amount)` de todo registro con categoría de
gasto: una devolución de +30 en «Supermercado» **sube** lo gastado en vez de bajarlo. Es lo que enseña la tarjeta de
cuenta en modo «solo gastos». La vista de cuenta (`AccountDetailCalculator.topCategories` / `dailySpending`) copia la
misma regla a propósito, para no contradecir a la tarjeta. Registros y Tendencias ya acumulan con signo
(`TransactionClassificationLogic`). Arreglarlo es cambiar las dos a la vez, con test de paridad.
