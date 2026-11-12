---
id: cross-currency-sale-coverage-depends-on-the-rates-each-device-has
status: backlog
priority: low
area: "grupos, divisas"
created: 2026-11-03
updated: 2026-11-03
source: "review adversarial del encargo 2026-11-03-widgets-y-venta-en-otra-divisa (venta en otra divisa, decisión A), hallazgos plausibles sin medir"
---

# Lo cobrado de una venta en otra divisa puede moverse si cambian las tasas guardadas de ese día

Con «deudas en una sola moneda», un pago en la moneda del grupo cubre una venta en otra divisa con el tipo de cambio del
día del pago (`GroupReceivableCoverageLogic.coverage(of:convert:)`, `GroupTransactionBridge.convertAtPaymentDay`). El
reparto se rehace en cada repaso con las tasas que el teléfono tiene en ese momento. Tres casos sin medir:

1. **La tasa del día llega después del pago.** Hasta entonces `CurrencyConverter` usa la de la víspera; al llegar la del
   día, el repaso siguiente convierte con otra y lo cobrado puede cambiar unos céntimos (o dejar un resto por cobrar).
2. **Dos aparatos con distintas filas de tasas** calculan patas distintas para la misma venta, y las patas viajan.
3. **La zona horaria del aparato** decide el día de la tasa (`BalanceValuation.rateDay(of:calendar: .current)`): un pago
   a las 23:00 en Lima cae en el día siguiente para un aparato en Madrid.

Qué haría falta para cerrarlo: guardar en la liquidación el tipo con el que se cubrió (como `exchangeRate` en un
registro) en vez de leerlo de las tasas en cada repaso. Toca el modelo de Grupos y su canal de sync, por eso no entró en
el encargo.
