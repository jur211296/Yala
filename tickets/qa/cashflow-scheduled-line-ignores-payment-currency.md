---
id: cashflow-scheduled-line-ignores-payment-currency
status: qa
priority: medium
area: "cashflow, planning, currency, fx"
created: 2026-10-08
updated: 2026-10-10
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

- [x] El flujo de caja convierte el importe de un pago programado a la divisa en la que pinta el plan.
- [x] Test con un pago en USD y preferida PEN que discrimine (con tasa ≠ 1), con control rojo.

Triage 2026-10-08: abierto · medium → medium · creado hoy y vivo: `estimateScheduled` devuelve `abs(payment.amount)` sin mirar `currencyCode` (`CashFlowProjectionCalculator.swift:477`).

## Resolución (2026-10-10)

Medido vivo en `2.1` y en **cuatro** sitios, no tres: también la fila del pago en «Añadir línea →
desde pago programado» pintaba `abs(payment.amount)` con la divisa del plan.

- Conversión única en `ScheduledPaymentAmountConversion` (extraída del molde
  `PlannedOccurrenceBuilder`, que ahora la usa). Tasa: la última disponible.
- La usan la proyección (`estimateScheduled`), las sugerencias del asistente (alta y cambio de
  método) y la hoja de añadir línea.
- `CashFlowLineResult.isPlannedApproximate`: «≈» en el importe del plan de una línea programada
  sin override cuando la tasa no es exacta (detalle del mes, hoja de celda, sugerencias).
- Fuera: los totales del mes no llevan «≈» (tampoco lo llevan hoy por las transacciones
  convertidas); sería otra decisión de producto.

Red: `YalaTests/CashFlowScheduledCurrencyTests` (7 casos). Control rojo con el código viejo (3
caen) y mutante del «≈» (2 caen).

## Guion de device-QA

1. Con divisa preferida **PEN**, crea un pago programado mensual de **100 USD** (Planificación →
   Pagos programados → +).
2. Ve a Informes → Flujo de Caja. Si no tienes plan, el asistente lo sugiere: la fila del pago debe
   mostrar ~**375 PEN** (100 × tu tasa USD→PEN), no 100.
3. Con plan ya creado: «Añadir línea» → desde pago programado. La fila del pago muestra el importe
   en PEN convertido.
4. Abre un mes futuro: la línea del pago suma el importe convertido y el total de gastos del mes
   lo incluye.
5. Sin red y sin tasas guardadas del día (modo avión tras reinstalar), el importe sale con «≈».
6. Un pago en PEN se ve igual que antes.
