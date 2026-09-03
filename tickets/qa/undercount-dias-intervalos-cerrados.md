---
id: undercount-dias-intervalos-cerrados
status: qa
priority: medium
area: statistics
created: 2026-09-02
updated: 2026-09-03
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

---

## Resuelto · 2026-09-03

### El trazado, que era el trabajo que este ticket pedía

33 instancias del patrón en `Yala/`, trazadas una a una siguiendo **de dónde sale el intervalo que
recibe cada una** (no basta con mirar la línea). Resultado: **4 afectadas, 28 sanas y 1 ya corregida**.
Cada «afectada» pasó además por una refutación independiente antes de tocarla.

| Sitio | Qué veía mal el usuario |
|---|---|
| `WeekdaySpendingCalculator:102` | El **último día del período no sumaba su día de la semana**. En enero (31 contados como 30) el sábado salía con 4 ocurrencias en vez de 5 ⇒ su media inflada ~25 % y el KPI «día más caro» podía señalar el día equivocado. Es el peor de los cuatro, y no es un promedio sesgado: es un día que desaparece. |
| `InsightsCalculator:266` | «Promedio diario» inflado ~3,3 % en «mes pasado» (+0,27 % en «año pasado»). |
| `FullFinancialContextBuilder:393` | El asistente de chat respondía con promedios inflados: **+16,7 %** en «semana pasada», que sobre 7 días es un día entero. |
| `WidgetDataCache:932` | Umbral, no denominador: solo importa en la frontera exacta. Se normaliza igual, por no dejar una instancia suelta del mismo patrón. |

**Correcciones a las hipótesis del ticket:**

- `InsightsCalculator:266` **sí estaba afectada**, en contra de lo que el ticket suponía. Su `interval`
  es `period.dateInterval(...)`, y `.lastMonth`/`.lastYear`/`custom` cierran en 23:59:59.
- `HeroMonthCalculator:124` es **falso candidato confirmado**: su `monthInterval` nace de
  `Calendar.dateInterval(of: .month)`, cuyo `end` es el primer instante del mes siguiente.
- `FinancialScoreCalculator:251` **no está afectada**: su `bucket` no es el intervalo del período.
- **`CashFlowSmallBinner:41` no tiene NI UN call-site de producción.** Era candidato del ticket y es
  código muerto: compila en el target y no lo invoca nadie. Trampa latente, no bug vivo.
- **Cuarta fuente del cierre en 23:59:59, que el ticket no listaba**: los rangos personalizados
  (`PeriodSelectorComponents.swift:195`, con `bySettingHour: 23, 59, 59`), que `DetailPeriod.custom`
  devuelve tal cual.

### La duda de diseño, resuelta midiendo

El `CLAUDE.md` avisa de que en una función compartida por períodos EN CURSO y CERRADOS el `-1 s` no
puede ser incondicional. **Ese aviso vale para CONSTRUIR el intervalo, no para contarlo**: sumar un
segundo a un `end` que ya es medianoche NO cambia el conteo, porque `dateComponents` trunca. Así que
la normalización repara los cerrados sin tocar los sanos y **no necesita guarda**. Está pinneado como
test (`openInterval_isUnaffectedByTheNormalization`), porque de eso dependía que el fix fuera un helper
único en vez de uno con condición en cada call-site.

### Hecho

`DateIntervalDayCount` (helper único) + los 4 sitios + **el gemelo `prevDaysInPeriod`**, que
normalizaba a mano desde el 2026-09-02. Unificarlo no es cosmético: mientras hubo dos formas de contar
lo mismo, una corrección arregló una sola — que es literalmente cómo nació este ticket.

### Lo que la mutación reveló sobre la cobertura

Al mutar el helper cayeron **solo sus propios tests**: ninguna de las 5999 pruebas del repo notaba que
el promedio de un usuario cambiara. Por eso se añadió cobertura de COMPORTAMIENTO al caso más grave
(`WeekdaySpendingCalculatorTests`, dos casos), verificada por mutación del cableado: con el patrón
crudo, el sábado vuelve a salir 4 y el total 30. Los otros tres call-sites siguen cubiertos solo por
el helper — anotado, no tapado.

### Verificación

Build en las dos schemes · **6001 tests, 599 suites, verde**. Mutación del helper (4 rojos) y del
cableado del caso grave (2 rojos).

### Decisión consciente que se deja fuera

`FullFinancialContextBuilder:627` (`daysLeft` de un presupuesto) cuenta `from: now, to: interval.end`
y se clasificó **no-afectada**. Tocarla cambiaría la semántica de «días que quedan» —si un presupuesto
acaba hoy, ¿queda 1 día o 0?— y eso es producto, no este bug. Queda escrito para que el próximo
barrido no la trate como hallazgo nuevo.
