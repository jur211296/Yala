---
id: 2026-11-20-flujo-limites-pagos-planificados-y-moneda-maquetas
status: done
priority: medium
area: "cashflow, planificacion, currency, fx, sync"
created: 2026-11-20
updated: 2026-11-20
source: "encargo 2026-11-20-flujo-de-caja-limites-por-pagos-planificados-y-moneda-maquetas"
---

# Maquetas: límites de Flujo de caja atados a pagos planificados y en otra moneda

Sesión de diseño: no cambia código de la app. Entrega: artifact «Límites con pagos y monedas» (enlace en el PR y en
el cierre) y su copia en `docs/maquetas/flujo-limites-pagos-y-moneda/`. Implementación:
`tickets/backlog/2026-11-20-flujo-limites-pagos-planificados-y-moneda.md`.

## Qué decide Jürgen (con la recomendación)

Ocho preguntas en la base del artifact (colección `decisiones`, un documento por pregunta con `valor` y `nota`). El
árbol y sus motivos están en el Paso 0 del encargo, que viaja en el PR.

| # | Pregunta | Recomendación |
|---|---|---|
| 1 | Cómo se elige monto fijo / pagos / pagos + extra | A: un método «Pagos planificados» con «monto extra» opcional dentro |
| 2 | Cómo se eligen varios pagos | B: hoja con casillas; un pago de otra línea se mueve aquí avisando |
| 3 | Un pago se borra, se pausa o termina | A: deja de sumar; sin nada, monto fijo con el último límite y un aviso |
| 4 | Pagos en otra moneda dentro de una línea | A: cada uno se convierte y se suman; original visible si comparten moneda |
| 5 | Límite fijo en otra moneda | A: moneda elegible en «Monto fijo»; vale para todos los meses |
| 6 | Qué tipo de cambio | A: promedio del mes (cerrado fijo, en curso lo que va, futuro el último con «≈») |
| 7 | Cómo se ve | A: soles arriba y la original debajo; tasa en el detalle; nota en el resumen |
| 8 | Sincronización | A: cuatro campos nuevos en la línea, compatibles con versiones viejas |

## Medido (2.3, 20-nov)

- `CashFlowLine` ya tiene `scheduledPayment` (relación a-uno) y el método `.scheduled` («Pago planificado» en
  «Cálculo del monto»). Hoy una línea se ata a **un** pago, no a varios.
- El cálculo ya convierte el pago a la moneda del flujo (`ScheduledPaymentAmountConversion`, con la **última tasa
  disponible**) y marca «≈» si la tasa no es exacta (`CashFlowLineResult.isPlannedApproximate`).
- El motor del mes reparte cada movimiento por su pago: una línea con pago solo recibe los movimientos de ese pago
  (`FlujoMotorMes.Dueños`, `porPago`). Un mismo pago en dos líneas deja la segunda como repetida: «un pago, una línea»
  ya es la regla.
- La moneda del flujo es la preferida de la persona (`CashFlowPlanViewModel`, `currencyCode`); el plan no guarda
  moneda propia.
- Si el pago de una línea se borra, la relación se anula (`.nullify`) y la línea con `.scheduled` cae a
  `manualAmount ?? 0` (`CashFlowProjectionCalculator.estimatePlannedAmount`): hoy se queda en 0 sin avisar.
- Las tasas se guardan por día (`ExchangeRateService`), así que el promedio de un mes sale de
  `CurrencyConverting.rateFactors(for:to:on:)` sin otra fuente.
- Modo Nube: la columna más nueva del manifiesto lleva `since: 7` (`capability_manifest.json`); la siguiente sería 8.
- Capturas del «antes» con `FlujoAisladosCapturasUITests` (semilla `realista` + `-uitest-seed-flujo-aislados`),
  iPhone 17 Pro, iOS 27.2.
