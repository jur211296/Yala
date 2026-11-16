---
id: cash-flow-month-capsule-and-balance-widget-pill-sign-a-zero
status: done
priority: low
area: "cashflow, widgets, formatting"
created: 2026-11-05
updated: 2026-11-06
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

## 2026-11-06 · hecho (lote XCUITest y neto del flujo)

- Cápsula del mes: `CashFlowMonthSummaryLogic.capsuleNetText` deja sin signo lo que la tabla compacta pinta como «0».
  Mismo patrón, dos sitios más: el rótulo del mes («te sobran / te faltan») y el resumen del plan decían «te faltan
  S/ 0.00» con un residuo negativo; los dos preguntan `isShortfall`, que no cuenta como falta lo que se pinta como cero.
- Widgets: la flecha, el tono y la lectura de VoiceOver de la variación de **Saldo** y de **Entradas y salidas** salen
  de `WidgetAmountSplitter.shownSign`, que mira lo que el mismo formateador pinta. El umbral de antes
  (`abs(change) >= 0.5`) fallaba justo en 0,5: el redondeo al par lo pinta «S/ 0» y salía con flecha de subida. La
  lectura de VoiceOver de **Gastos** ya no dice «+0 %».
- Tests: `ZeroChangeSignTests` (lógica, con su control de que lo que no es cero conserva el signo) y
  `ZeroChangeSignWidgetWiringTests` (la extensión no compila en `YalaTests`: su cableado se fija por su código).
- Sin device-QA: el cero exacto no lo produce ninguna semilla de forma estable y la decisión es una función pura con test.
