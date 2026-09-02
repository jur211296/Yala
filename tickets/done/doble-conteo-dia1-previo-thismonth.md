---
id: doble-conteo-dia1-previo-thismonth
status: done
priority: high
area: statistics
created: 2026-09-02
updated: 2026-09-02
resolved: 2026-09-02
source: hallazgo colateral del análisis de rojo-heroBuckets-thisWeek-trailing-window (2026-09-02)
---

# Una transacción del día 1 se cuenta a la vez en el período actual y en el anterior

Quinta instancia de la trampa que `CLAUDE.md` documenta en «Cálculos con fechas» como
replicada en cuatro ficheros: **`DateInterval` es CERRADO en ambos extremos**.

## La raíz

`PreviousPeriodHelper.swift:112` — la rama `.thisMonth` es **la única de las siete** que
devuelve el `end` sin restarle un segundo:

```swift
return DateInterval(start: startOfPreviousMonth, end: currentInterval.start)
```

Las otras **cinco** (líneas 100, 107, 119, 126, 141) sí lo restan — **no seis: la 152
(`sameIntervalPreviousYear`) resta un AÑO, no un segundo**, error de conteo de la primera
versión de este ticket, corregido al re-medirlo. La de `.thisWeek`
lleva además el comentario que explica por qué, dos ramas más arriba: *«sin -1s, una TX a
medianoche del primer día de esta semana cae en ambos periodos»*. En `.thisMonth` ese
`end` es exactamente el `start` del período actual, así que el instante es compartido — y
la medianoche exacta es justo lo que produce `DatePicker(displayedComponents: [.date])`.

`HeroBucketsCalculator` no sufre el problema porque lo compensa con un guard **local**
(`!periodInterval.contains(tx.date)`, líneas 98-99, con su test en `:371`). Es el único
consumidor que lo hace.

## Lo medido (réplica ejecutable de los tramos del árbol `8168987a`, TZ America/Lima, 730 días desde 2026-01-01)

| Dónde | Frecuencia | Efecto |
|---|---|---|
| **`FinancialReportViewModel`** (informe) | **730 de 730 días — 100 %** | una TX del día 1 a medianoche entra en la columna «actual» Y en la «anterior» |
| **`InsightsCalculator`** (hero de Estadísticas) | **30 de 730 días — 4,1 %** | 28 de `.thisMonth` (fin de mes + clamp de febrero: 31-ene, 28→31-mar, 30-may…) y 2 de `.thisYear` (31-dic) |

Los dos difieren porque el informe filtra el previo con el intervalo **crudo**
(`FilterService.matchesCriteria` → `interval.contains`, `FilterService.swift:226`) y luego
`alignedPreviousItems` **conserva** esa transacción: `adjustDateToCurrent` la mapea por
`day = 1` al día 1 del mes actual, y el filtro `adjusted >= currentInterval.start` la deja
pasar. Estadísticas, en cambio, filtra contra el intervalo ya **truncado**, que solo
alcanza `currentInterval.start` cuando el día del mes en curso llega o supera la longitud
del mes anterior.

⇒ El informe infla la columna «anterior» **todos los días del mes**, no sólo a fin de mes.

## Qué hay que decidir

**Fuente o consumidor.** Restar 1 s en `PreviousPeriodHelper:112` uniformaría las siete
ramas y cerraría los dos casos de golpe, pero **hay que medir el impacto antes**: cambia
`prevDaysInPeriod` (`InsightsCalculator:274` — la 271 es comentario; otra coordenada mal citada al abrir el ticket) y los tests de duración de
`PreviousPeriodHelperTests`. Un `-1s` sobre un intervalo de un mes cambia su `duration`, y
si algo divide por esa duración, el promedio diario se mueve.

## Antes de declararlo cerrado

Trazar **cada** consumidor del intervalo crudo, uno a uno: `PanelViewModel`,
`CategoriesTabView`, `TrendsTabView`, `TopCategoriesWidget`, `TopSubcategoriesWidget`,
`NeedTrendWidget`, `PieChartVariationHeader`. **No todos están afectados**: varios pasan
antes por `alignedPreviousTransactions`, que corta por fecha mapeada y no por `.contains`.
Hay que mirarlos, no suponerlos.

Es cálculo financiero ⇒ **review adversarial** (varias lentes + refutación por hallazgo),
como manda `CLAUDE.md`.

## Test de regresión

En el espejo de `calculate_periodPrevExpense_excludesSharedBoundaryTx`
(`HeroBucketsCalculatorTests:371`), que es el que ya cubre este caso para el hero.

## Al commitear

Toca código bajo `Yala/` ⇒ actualizar `qa/coverage-index.json` en el MISMO commit
(contrato anti-drift) y pasar `/gate`.


---

## Resuelto — 2026-09-02

Arreglado **en la fuente**, más dos instancias artesanales. Verificado con réplica ejecutable:
**de 730/730 días con doble conteo a 0/730.**

### El radio real era mayor que el de este ticket

El ticket nombraba 2 consumidores. El barrido adversarial encontró **8 caminos de cálculo**, seis
de ellos al 100 % de los días: el informe, los cinco widgets del Panel, Distribución, la tarjeta de
Flujo de caja de Tendencias, el hero de Estadísticas (28/730), la comparativa interanual (2/730) y
el baseline de anomalías del chat.

### Qué se tocó

- **`PreviousPeriodHelper:112`** (`.thisMonth`) — resta 1 s, como sus cinco hermanas.
- **`PreviousPeriodHelper:151`** (`sameIntervalPreviousYear`) — el `.thisYear` del 31-dic no nacía
  en la 112, así que el fix de arriba no lo cerraba. Aquí el `-1 s` va **condicionado a que el
  extremo sea medianoche**: esta función sirve también a períodos CERRADOS, que ya cierran en
  23:59:59, y restarles otro segundo les quitaría un instante real — medido, los 730 días. Con la
  condicional el solape baja a 0/730 y los cerrados quedan intactos.
- **`AnomalyDetectionCalculator:62`** — instancia a mano fuera del helper, con síntoma propio: la
  transacción entraba en su **propia línea base** y apagaba su detección como anomalía.
- **`PanelViewModel:2781`** — misma forma, hoy inofensiva porque el consumidor
  (`HeroBucketsCalculator`) usa `if/else-if` mutuamente excluyente. Trampa dormida: la protección
  vivía en el consumidor, no aquí.
- **`InsightsCalculator:274`** — normaliza `end + 1 s` antes de contar días. Obligatorio: sin esto
  el fix habría quitado un día entero al denominador del promedio diario en los mismos 28 días,
  cambiando un bug por un off-by-one.
- **Dos docstrings** que el cambio convertía en mentira (`HeroBucketsCalculator:90-97` y
  `HeroBucketsCalculatorTests:367`). El guard del hero **se conserva** aunque quede redundante: es
  la única red que detectaría una regresión de la fuente.

### Tests

`previousInterval_thisMonth_month_previousMonth` estaba escrito **sin inyectar `now`** y medía con
`duration / 86400`: con el `-1 s` habría dado 27,99999 y se habría puesto rojo **sólo en marzo de
un año no bisiesto**, meses después del cambio. Reescrito con `now` fijo y conteo por días de
calendario.

Tres tests de regresión nuevos, y **tres mutantes verificados en rojo**: quitar el `-1 s` de
`.thisMonth`, quitar el de `sameIntervalPreviousYear`, y aplicarlo *sin* la condicional (que rompe
el período cerrado). Los tres mueren.

### Queda fuera, en ticket aparte

El **undercount sistemático de días**: `dateComponents([.day])` trunca, así que todo intervalo que
cierre en 23:59:59 cuenta un día de menos. Medido en `.lastMonth`, que ya llevaba el `-1 s`:
**730/730 días** cuenta mal hoy. Aquí sólo se normalizó `InsightsCalculator:274`; hay ~6 sitios más.
⇒ `tickets/backlog/undercount-dias-intervalos-cerrados.md`
