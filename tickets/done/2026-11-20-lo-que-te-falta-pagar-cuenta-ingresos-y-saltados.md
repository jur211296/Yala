---
id: 2026-11-20-lo-que-te-falta-pagar-cuenta-ingresos-y-saltados
status: done
priority: medium
area: "estadísticas, salud-financiera"
created: 2026-11-20
updated: 2026-11-22
source: hallazgo de la hoja de Salud financiera en tres secciones
---
# «Lo que te falta pagar» de Estadísticas cuenta ingresos planificados y pagos saltados

`InsightsCalculator.calculateCommitments` suma en `pendingPaymentsAmount` todo pago planificado ACTIVO cuyo
`nextDueDate` cae en el período: también los de INGRESO (un sueldo planificado sale como «te falta pagar») y los que la
persona saltó. Además cuenta una sola ocurrencia por pago (un pago semanal vale una vez al mes).

La hoja de Salud financiera y la nota cuentan «Te falta pagar este mes» con `FinancialScoreCalculator.pendingOccurrences`:
solo gastos, cada ocurrencia del mes, sin saltadas ni pagadas. Con pagos de gasto mensuales sin saltar las dos cifras
coinciden (`SaludFinancieraCompromisosParidadTests`); con un sueldo planificado, una ocurrencia saltada o un pago semanal,
no.

Hecho cuando: Estadísticas › Resumen usa la misma cuenta y el test de paridad añade los tres casos.

## Resuelto (2026-11-22)

`InsightsCalculator.calculateCommitments` cuenta lo pendiente con `FinancialScoreCalculator.pendingOccurrences` sobre los
pagos de gasto activos, con lo pagado del intervalo (`StatisticsRecalculation` lo carga con
`ScheduledPaymentPaidStatusHelper`). El reparto suscripciones/resto sigue sumando el total, por ocurrencia. Por el camino:
un pago de una vez del día 1 salía también en el mes anterior (`ScheduledPaymentDateCalculator.paymentDatesInMonth`, mes
cerrado) y contaba dos veces en un período que cruza dos meses; ahora el mes es semiabierto, como en `shared-core`.
Tests: `YalaTests/FaltaPagarCompromisos/` (sueldo, saltado, semanal, pagado, día 1), con mutante.
