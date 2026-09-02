---
id: undercount-dias-intervalos-cerrados
status: backlog
priority: medium
area: statistics
created: 2026-09-02
updated: 2026-09-02
source: hallazgo colateral del fix doble-conteo-dia1-previo-thismonth (2026-09-02)
---

# Contar días con `dateComponents([.day])` sobre un intervalo que cierra en 23:59:59 da un día de menos

`Calendar.dateComponents([.day], from:to:)` cuenta días **completos** y **trunca**. Los intervalos
de este repo que evitan el doble conteo del borde cierran en `23:59:59` (el `-1 s`), así que
contarlos así devuelve **uno menos** que la longitud real del período.

## Lo medido (réplica ejecutable, TZ America/Lima, 730 días desde 2026-01-01)

Sobre `.lastMonth`, que ya llevaba el `-1 s` desde antes de hoy:

| Forma de contar | Coincide con la longitud real del mes |
|---|---|
| `dateComponents([.day], from: start, to: end)` — la actual | **0 de 730 días** |
| `dateComponents([.day], from: start, to: end.addingTimeInterval(1))` | **730 de 730 días** |

Es decir: **no es un caso raro, falla siempre**. Un mes de 31 días se cuenta como 30.

## Alcance

Ya corregido **sólo** en `InsightsCalculator.swift:274` (`prevDaysInPeriod`), porque el fix del
doble conteo lo habría empeorado ahí. **El resto sigue sin tocar.** Candidatos localizados con
`grep -rn "dateComponents(\[\.day\]"`, **sin trazar cuál recibe un intervalo con `-1 s`** —
eso es justo el trabajo de este ticket:

- `Yala/App/Logic/Calculators/WeekdaySpendingCalculator.swift:102` (`totalDays`)
- `Yala/App/Logic/Helpers/CashFlowSmallBinner.swift:41` (`days`)
- `Yala/App/Logic/Calculators/FinancialScoreCalculator.swift:251` (`totalDays` sobre `bucket`)
- `Yala/App/Logic/Calculators/HeroMonthCalculator.swift:124` (`total`)
- `Yala/App/ViewModels/PanelViewModel.swift:2379` y `BudgetsViewModel.swift:698`
  (`from: today, to: interval.end` — forma distinta, hay que mirarla aparte)
- `Yala/App/Logic/Calculators/InsightsCalculator.swift:266` (`daysInPeriod`) — este recibe el
  intervalo ACTUAL, que cierra en medianoche y **no** lleva `-1 s`: probablemente sano, verificarlo.

## Qué hacer

1. Trazar, para cada sitio, si el intervalo que recibe cierra en `23:59:59` o en medianoche. **Sólo
   los primeros están mal**; normalizar los sanos sería introducir el error al revés.
2. Decidir si se normaliza en cada call site o se añade un helper único
   (`DateInterval.calendarDays(in:)`) que haga el `+1 s` una vez. Lo segundo evita la sexta copia.
3. Test por sitio afectado, con un mes de 31 y uno de 28 días.

## Por qué importa

Estos conteos son **denominadores**: promedio diario de gasto, ritmo de presupuesto, puntuación
financiera. Un día de menos infla el promedio ~3,3 % de forma sistemática y silenciosa — no es un
pico visible, es un sesgo constante en el número que el usuario usa para juzgarse.

## Al commitear

Toca código bajo `Yala/` ⇒ actualizar `qa/coverage-index.json` en el MISMO commit y pasar `/gate`.
