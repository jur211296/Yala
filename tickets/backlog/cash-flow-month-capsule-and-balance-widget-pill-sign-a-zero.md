---
id: cash-flow-month-capsule-and-balance-widget-pill-sign-a-zero
status: backlog
priority: low
area: "cashflow, widgets, formatting"
created: 2026-11-05
updated: 2026-11-05
source: "review adversarial del lote N8 · Divisas (2026-11-04)"
---

# El neto del mes del flujo de caja y la variación del widget de Saldo ponen signo o flecha a un cero

Mismo origen que «Una cuenta cuyo saldo suma cero sale como «€ -0.00»» (cerrada en el lote N8), en dos sitios que no
pintan un saldo y quedaron fuera de esa card:

- `CashFlowMonthCapsule.swift` (`(netFlow >= 0 ? "+" : "-") + compact`): un neto exacto de 0 sale «+0», y un residuo de
  coma flotante negativo, «-0».
- `BalanceWidget.swift` (píldora de variación): pasa `abs(change)` y elige la flecha con `change > 0`; un residuo da
  «▲ S/ 0» o «▼ S/ 0».

Medido leyendo el código el 2026-11-04. El helper ya existe: `CurrencyFormattingHelper.isShownAsZero` (en el widget no
compila; ahí, comparar con lo que su formateador escribe para el 0, como `WidgetAmountSplitter`).

## Hecho cuando

Un neto o una variación que se pintan como cero salen sin signo y sin flecha de subida o bajada, con test.
