---
id: statistics-calculators-count-an-unwritten-conversion-as-zero
status: done
priority: low
area: "currency, fx, statistics"
created: 2026-10-11
updated: 2026-10-12
source: hallazgo de resolved-amount-trusts-a-zero-converted-amount (#461), card tablero-las-tartas-y-rankings-de-estadisticas-si-985z
---

# Las tartas y rankings de Estadísticas cuentan 0 un movimiento con la conversión sin escribir

## Qué le pasa al usuario

Un gasto en otra divisa cuya conversión a la divisa principal no llegó a escribirse ya suma bien en
los totales desde #461, pero las tartas, los rankings y el resto de cuadros que suman por su cuenta lo
seguían contando como **0**: la tarta de categorías podía sumar menos que el total de su misma
pantalla.

## Dónde, medido el 2026-10-12

Siete calculadores leen `amountInPreferredCurrency` sin pasar por `CashFlowCalculator.resolvedAmount`
y su rama «misma divisa» comparaba solo la divisa:

| Calculador | Pantalla |
|---|---|
| `TopSpendingCategoriesCalculator` | tarta de categorías (Estadísticas, Panel, avisos de informe) |
| `TopSubcategoriesCalculator` | ranking de subcategorías |
| `WeekdaySpendingCalculator` | gasto por día de la semana (Tendencias, Panel, Yala IA) |
| `TransactionIndex` (`CashFlowProjectionCalculator`) | real frente a lo planificado del Flujo de caja |
| `NeedTrendHelper` | tendencia por necesidad |
| `ReportNotificationService.accumulateReportTotals` | aviso de informe |
| `InsightsCalculator.txAmount` | Observaciones (mayor gasto, compartidos, necesidades, presupuestos) |

`mcp/` `buscar_movimientos` enseñaba `importe_en_divisa_preferida = 0` para esa fila.

## Cerrado el 2026-10-12

- **Un predicado, no una copia:** `CashFlowCalculator.readsStoredAmount` es la condición de la primera
  rama de `resolvedAmount` (misma divisa y, o pata ajustada, o convertido escrito); `resolvedAmount` y
  los siete lo usan. Cada calculador conserva su rama de conversión.
- **Sin «≈» nuevo:** ninguno de los siete pinta la marca de aproximado; añadirla sería una función
  nueva.
- **`mcp/`:** `buscar_movimientos` devuelve `null` con la conversión sin escribir, como cuando la fila
  se guardó en otra divisa. El resumen del periodo ya lo portó #461. **Pide deploy del conector.**
- **Tests:** `StatisticsCalculatorsZeroConvertedTests`, un par por calculador (fila sin convertir ⇒
  reconvertida; control con el convertido escrito y monodivisa con una tasa absurda ⇒ no cambia), más
  la tabla del predicado. Con los siete devueltos a la condición vieja, los siete casos de fila sin
  convertir salen rojos y los controles siguen verdes. En `mcp/`, el caso nuevo de `app.test.ts` sale
  rojo sin el filtro.
- **Fuera, con card:** `BalanceTrendCalculator` y `BalanceHelper.initialBalanceForTrend` tienen el
  mismo patrón pero ningún llamador de producción; la fila «Tipo de cambio» del detalle de un registro
  pinta «≈ 0,00» con la conversión sin escribir.
