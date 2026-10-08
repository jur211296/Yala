---
id: cashflow-scheduled-line-ignores-payment-currency
status: backlog
priority: medium
area: "cashflow, planning, currency, fx"
created: 2026-10-08
updated: 2026-10-08
source: review adversarial de account-currency-change-leaves-scheduled-and-favorites-stale (2026-10-08)
---

# El flujo de caja suma el importe de un pago programado sin mirar su divisa

## Qué le pasa al usuario

Su divisa preferida es el sol y tiene una línea de flujo de caja ligada al alquiler. Si el alquiler está en dólares
(1.000 USD), el plan lo cuenta como 1.000 **soles**. Desde el arreglo de
`account-currency-change-leaves-scheduled-and-favorites-stale` se ve más: al cambiar la cuenta de soles a dólares, el
alquiler pasa de 3.500 PEN a ~930 USD, y el plan, que antes enseñaba 3.500 (bien por casualidad), pasa a enseñar 930
como si fueran soles.

## Lo medido (2026-10-08, en código; no ejecutado)

- `Yala/App/Logic/Calculators/CashFlowProjectionCalculator.swift:470-478` — `estimateScheduled` devuelve
  `abs(payment.amount) * dates.count`, sin leer `payment.currencyCode`.
- `Yala/App/ViewModels/CashFlowPlanViewModel.swift:222` y `:265` — `abs(payment.amount)` como importe sugerido.
- `Yala/App/Logic/Calculators/PlannedOccurrenceBuilder.swift:79-86` ya convierte el importe del pago: es el molde.

## Criterio de hecho (AC)

- [ ] El flujo de caja convierte el importe de un pago programado a la divisa en la que pinta el plan.
- [ ] Test con un pago en USD y preferida PEN que discrimine (con tasa ≠ 1), con control rojo.
