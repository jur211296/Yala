---
id: trends-comparison-kpi-vs-curve
status: done
priority: high
created: 2026-07-06
updated: 2026-08-26
source: YalaWiki/Backlog/p20-15_comparativa-kpi-vs-curva-descuadre.md
---

> Sync 18 ago (Iris, Mac SSOT). Código en 2.1 (PR 15 @ `4bf4ead`). No `ok_`: QA visual desconocido.
> Mismo PR (escrito): `0dcc828f` doble conteo lunes; `96bd55fb` Distribución e Informe recortan al mismo día; `8ea80b67` Distribución compila. No cerré tickets extra.


# Bug: en Tendencias → Comparativa, el KPI "Período anterior" no cuadra con la curva de la gráfica

## Descripción

En **Estadísticas → pestaña Tendencias → card "Comparativa"**, el número que muestra el KPI del período anterior no coincide con lo que dibuja la curva punteada (período anterior) de la misma gráfica. El usuario lo detectó a simple vista: el badge de variación es **verde/positivo** mientras la curva anterior está claramente **por encima** de la actual (contradicción visual directa).

**Evidencia del reporte (screenshot, modo "P-1" = período anterior inmediato, período "este mes" = julio 2026, datos hasta el día 4):**

| Elemento | Valor mostrado | Qué representa realmente |
|---|---|---|
| KPI actual (header) | S/ 17,520.66 | Saldo del período actual **al día 4** (period-to-date) ✅ |
| KPI "vs" período anterior (header) | **S/ 11,814.45** | Saldo al **fin de junio completo** (period-full) ❌ |
| Badge de variación | **+48.3%** | (17,520.66 − 11,814.45) / 11,814.45 |
| Tooltip de la curva (scrub día 4) — serie actual | S/ 17,520.66 | Julio al día 4 ✅ (coincide con el KPI actual) |
| Tooltip de la curva (scrub día 4) — serie anterior | **S/ 24,122.10** | **Junio al día 4** (period-to-date) — NO coincide con el KPI |

El descuadre: el KPI dice que el período anterior vale **11,814.45**, pero la curva anterior en el punto visible (día 4 de junio) vale **24,122.10**. Son bases temporales distintas del **mismo** período anterior.

**Impacto de correctness (no cosmético — puede invertir el signo):**
- Con la base actual (fin de junio = 11,814.45) → badge **+48.3%** ("tu patrimonio subió mucho vs el mes pasado").
- Con la base honesta que la propia curva muestra (junio al día 4 = 24,122.10) → sería **≈ −27.4%** ("bajó").

El usuario ve simultáneamente un badge verde de +48% y una curva anterior punteada muy por encima de la actual. La conclusión financiera cambia de sentido.

## Causa raíz confirmada

Comparación **asimétrica**: el lado actual se calcula **period-to-date** (hasta hoy, día 4) y el lado anterior se calcula **period-full** (mes anterior completo, ~fin de junio). La gráfica sí alinea ambos lados al mismo día del período; el KPI no.

Metodología: investigación multi-agente (4 lectores + 1 verificación adversarial Opus). La causa raíz **se sostuvo tras 4 intentos de refutación** (override de saldo vivo, bug de clipping, doble fuente del KPI actual, redondeo — todos descartados). Severidad **alta**.

**Causa próxima exacta** — `Yala/App/Views/Statistics/TrendsTabView.swift:1693-1697` (función `calculatePeriodComparisonData`):
```swift
let newCurrentTotal = currentResult.points.last?.value ?? 0   // 17,520.66 (julio al día 4) ✅
...
let prevTotal = previousResult.points.last?.value ?? 0         // 11,814.45 (junio al FIN) ❌
let newPreviousTotal: Double? = previousResult.points.isEmpty ? nil : prevTotal
if newPreviousTotal != previousPeriodTotal { previousPeriodTotal = newPreviousTotal }
```

**Cadena que produce la asimetría:**

1. **El intervalo anterior es el mes completo.** `PreviousPeriodHelper.previousInterval` para `.thisMonth` devuelve `[startOfPreviousMonth ... currentInterval.start)` = todo junio (`PreviousPeriodHelper.swift:98-101`).

2. **`TrendDataProcessor` capa los puntos al rango REAL de datos**, no al día de hoy: `effectiveEnd = min(lastTransactionDate + 1s, interval.end)` (`TrendDataProcessor.swift:122-125`). Para el mes en curso (julio) eso es el **día 4** (última TX); para el mes anterior completo (junio) eso es **~fin de junio** (última TX del mes). Por eso `currentResult.points.last` termina en el día 4 y `previousResult.points.last` termina a fin de junio — **fechas distintas del período**.
   - Nota de precisión: no es rígidamente "día 30" sino la última transacción de junio; da igual, semánticamente es fin-de-junio, no día 4.

3. **La curva SÍ alinea y clippea el período anterior al día actual.** `PeriodComparisonChartView.clippedPreviousPoints` (`:58-68`) mapea junio→julio con `adjustDateToCurrent` (estrategia `.dayOfMonth` para `.thisMonth`: 4-jun → 4-jul) y descarta lo que cae fuera del dominio actual. Por eso el tooltip del día 4 muestra correctamente **24,122.10** (junio al día 4).

4. **El KPI/chip usan el `.last` sin truncar** → comparan día-4-de-julio (17,520.66) contra fin-de-junio (11,814.45). La gráfica hace lo correcto (MTD-vs-MTD); el KPI numérico no aplica el mismo recorte que la curva ya aplica.

**El lado ACTUAL es coherente consigo mismo** — `currentKPIValue` (`:1219`, usa `rawTrendPoints.last`) y `currentPeriodTotal` (`:1693`, usa `currentResult.points.last`) dan ambos 17,520.66 (period-to-date). El defecto es **unilateral en el lado anterior**.

**Descartado como causa (verificado):**
- **`liveBalanceOverride`** (solo se aplica al actual y solo a `.balance`, `TrendsTabView.swift:1627`): es ortogonal y correcto por diseño. Explica por qué el actual muestra el saldo vivo al TC de hoy, no el mismatch del previo.
- **Bug de clipping en la gráfica**: la curva es correcta (MTD-vs-MTD); es el KPI el que falla.
- **Doble fuente / redondeo / filtros distintos**: descartados (las dos fuentes del actual coinciden; la diferencia es 2×, no decimales; ambos lados del previo parten del mismo `previousResult`).

## Métricas afectadas

**Las 3 métricas** (balance, ingresos, gastos). Para **income/expense es aún más severo**: son acumulativos monótonos, así que el KPI anterior refleja **30 días acumulados de junio** contra una curva de **4 días** → sesgo anti-actual inflado (compara 4 días vs 30 días). En balance es igual de real pero menos obvio por no ser monótono (puede incluso invertir el signo, como en el caso reportado).

## Alcance — otros consumidores con el mismo patrón

El bug **no es exclusivo de la card Comparativa de Tendencias**. El mismo patrón "total del período anterior tomado como period-full mientras el actual es period-to-date" se replica en:

| Sitio | Evidencia | Estado |
|---|---|---|
| `TrendsTabView.calculatePeriodComparisonData` | `:1695-1697` (`previousResult.points.last`) | **Bug reportado** (card Comparativa + su VariationChip `:559-561`) |
| `TrendsTabView` — VariationChip de la card **Tendencias** | `:441-443` (mismo `previousPeriodTotal`) | Mismo bug, otro chip |
| `PanelViewModel.calculatePeriodComparisonWidget` | `:2558-2561` (`previousResult.points.last`) | **Mismo bug** — widget Comparativa del Panel (home), misma `PeriodComparisonChartView` |
| `PanelViewModel` — widgets categoría/subcategoría/tags/necesidad | `:1651, :1721, :1851, :2468` (previousTotal = suma period-full vs current por `effectiveInterval`) | Asimétrico para meses parciales — **verificar** |
| `PanelViewModel.calculateCashFlowWidget` | `:1743-1774` (previousNetFlow period-full vs current `effectiveInterval`) | **CORREGIDO** — hoy pasa por `alignedPreviousTransactions` → `DateAlignmentHelper.alignedPreviousItems` (verificado 2026-08-14) |
| **`TrendsTabView.calculateCashFlowData`** — card «Flujo de Efectivo» de la pestaña **Tendencias** | Filtra el previo con `PreviousPeriodHelper.previousInterval` COMPLETO y se lo pasa a `CashFlowCalculator`; **cero apariciones de `DateAlignmentHelper` en la función** | 🔴 **BUG VIVO — esta fila FALTABA en la tabla, y por eso nadie lo miró.** Medido en pantalla el 2026-08-14: 4 544 vs **8 422** (−46 %) contra los 4 544 vs **4 710** (−3,5 %) de la card Comparativa **en la misma pantalla y con la misma etiqueta «vs Jul 26»**. Es el gemelo de Tendencias del que sí se arregló en el Panel |
| `InsightsCalculator` (hero de Insights/Tendencias, `balanceVariation`/`incomeVariation`/`expenseVariation`) | `InsightsCalculator.swift:231-242` (usa `CashFlowCalculator.netFlow` full-period en AMBOS lados) | **NO afectado** — simétrico full-vs-full (referencia de comportamiento coherente) |

> **Ojo con el patrón de referencia:** `InsightsCalculator` compara full-vs-full (junio completo vs julio completo-hasta-ahora en sumas), que es coherente pero NO es MTD-vs-MTD. La card Comparativa es distinta: su curva es explícitamente MTD-vs-MTD. El fix debe decidir a cuál semántica converger (ver Decisión de producto).

## 🛠️ Progreso de implementación (2026-07-06)

**Código implementado (Grupo A) — build verde, tests verdes; PENDIENTE device-QA + commit.**

- Nuevo helper puro `Yala/App/Logic/Helpers/DateAlignmentHelper.swift` — alineación temporal (extraída de `PeriodComparisonChartView`) + `alignedPreviousTotal(...)` que replica el pipeline de `clippedPreviousPoints` y devuelve el valor del último punto VISIBLE de la curva anterior.
- `PeriodComparisonChartView` delega sus 3 métodos privados en el helper (curva sin cambios).
- `TrendsTabView.calculatePeriodComparisonData` y `PanelViewModel.calculatePeriodComparisonWidget` usan `alignedPreviousTotal` en vez de `previousResult.points.last`. Corrige a la vez la card Comparativa, el "vs" + `VariationChip` de la card Tendencias, y el texto del insight card (mismo `@State`).
- Tests: `YalaTests/DateAlignmentHelperTests.swift` (8, pure-logic, `calendar` inyectable) — trunca MTD, no-op en período cerrado, A-1, semana, vacío/ceros, guard de coherencia KPI==curva. Build Yala + Yala Dev 0 warnings; regresión `PreviousPeriodHelperTests`/`TrendDataProcessorTests` verde (55). `coverage-index` área `trend-previous-period-alignment` + QA-SCENARIOS F-STA-03 paso 4.
- **Hallazgo lateral (deuda preexistente, NO tocado):** el fallback de fin-de-mes en `adjustDateToCurrent` está muerto — `Calendar.date(from:)` normaliza por rollover (feb31→mar3) en vez de devolver `nil`. Heredado de la curva; arreglarlo la movería (fuera de scope). Documentado en el test.

**`/code-review high` HECHO (2026-07-06):** 25 agentes, 17 candidatos, 0 bugs de correctness (los 2 candidatos serios de divergencia de intervalos → REFUTED). Findings de cleanup low: (1) pipeline de clipping duplicado view↔helper — **APLICADO el DRY**: `DateAlignmentHelper` es ahora la SSOT (`currentDataDomain` + `clippedPreviousPoints`), consumido por la curva Y el KPI → drift imposible (cierra el re-riesgo del propio bug); (2) fallback rollover muerto (preexistente, no tocado); (3) doble iteración (micro-opt, no tocado). Build Yala+Yala Dev 0 warnings + 8 tests verdes tras el DRY.

**Pendiente:** device-QA (sim/TestFlight, verificar KPI==curva en período en curso, 3 métricas, P-1/A-1) → `/commit-one` (⚠️ working tree mezclado con cambios ajenos de `GroupExpenseSuccess*`/`InboxView`/`L10n` — commitear SOLO los archivos de este fix + tests + coverage).

**Follow-up (D2, otra sesión):** alinear el hero de Tendencias (`heroVariationSubtitle` / `PeriodSummary.balanceVariation`, `InsightsCalculator` netFlow full-vs-full) a la semántica MTD, para que hero y card cuenten la misma historia. Decisión de producto aparte.

## 🛠️ Progreso de implementación — Grupo B / fase 2 (2026-07-06)

**Código implementado — build Yala+Yala Dev 0 warnings, 168 tests verdes, device-QA sim PASS parcial; PENDIENTE commit.**

Los **5 VariationChips agregados del Panel** (gasto por categoría/subcategoría/tags/necesidad y cash flow neto) truncan el período anterior al día equivalente del último dato del actual (**MTD**), truncando `previousTransactions` ANTES de cada calculadora. Decisión de producto confirmada por el owner: **MTD-vs-MTD** (consistente con Grupo A).

- Nuevos en `DateAlignmentHelper`: `aggregatePreviousNeedsAlignment(period:comparisonMode:)` (gate) + `alignedPreviousItems<T>(...)` (trunca vía `adjustDateToCurrent`, ventana `[currentInterval.start … max(currentDates)]`, genérico + closure `date:` testeable sin SwiftData).
- En `PanelViewModel`: `currentPeriodDates(_:in:natures:)` + `alignedPreviousTransactions(...)` (centraliza el pre-filtro del previo, antes duplicado en los 5 widgets).
- 6 tests nuevos en `DateAlignmentHelperTests` (gate solo-thisMonth, trunca thisMonth, no-op thisWeek/cerrados/rodantes, bordes mes-corto/actual-vacío).

**Hallazgo clave (`/code-review high`, 37 agentes) — el análisis inicial estaba equivocado:** el ÚNICO período asimétrico es **`.thisMonth`** (su previo = mes anterior COMPLETO). **`.thisWeek` NO se alinea** — su `previousInterval` es una **ventana trailing de igual duración** (comparte rama con `.last7Days` en `PreviousPeriodHelper`), ya simétrica; incluirlo + alinear con `.dayOfWeek` VACIABA las 5 chips a mitad de semana (regresión cazada y corregida). El gate quedó **solo `.thisMonth`** (coincide con la conclusión de D2/hero). 2º fix: el corte MTD es **nature-aware** (coincide con lo que cada calculadora cuenta — gasto-only salvo cashflow). Residuales documentados: Tags no filtra "tiene tag" (sesgo acotado, dirección segura); scrub (`focusedDate`) preexistente (no empeora).

**QA Visual (device sim iPhone 17 Pro, seed realista, "Este mes" en curso):** app arranca sin crash; Panel + gráficos Charts renderizan (sin SIGTRAP de `.annotation`); Flujo de Efectivo → chip **"Disminución −45.5%"** (a11y-confirmado) = el pipeline MTD funciona end-to-end. Distribución (categoría/tags/necesidad) usa el pipeline idéntico + cubierto por unit tests (captura visual bloqueada por fricción de scroll del sim). e2e del escenario exacto (nómina tardía, semana a mitad) → TestFlight.

**⚠️ Commit:** working tree compartido con la sesión D2 (mismos archivos `DateAlignmentHelper.swift`/`DateAlignmentHelperTests.swift`/`coverage-index.json` interleaved; `InsightsCalculator.swift` es de D2; `PanelViewModel.swift` es 100% de fase 2). Aislar exige cirugía hunk-level o commitear el ticket entero junto — decisión con el owner.

## 🛠️ Progreso de implementación — D2 / hero de Tendencias (2026-07-06)

**HECHO — committeado en `f779a7ab` (commit combinado fase 2 + D2). Build Yala+Yala Dev 0 warnings, tests verdes, device-QA parcial.**

El **hero de Tendencias** (subtítulo "tu balance subió/bajó X%" + chips ingreso/gasto) tomaba sus 4 variaciones (`balanceVariation`/`expenseVariation`/`incomeVariation`/`dailyAverageVariation`) de `InsightsCalculator.calculate`, que comparaba el período actual (MTD parcial) contra el previo COMPLETO → mismo sesgo parcial-vs-completo. Decisión de producto del owner: **alinear la ventana a MTD manteniendo la métrica netFlow** (el KPI grande `netBalance` no cambia; solo la variación), alcance **holístico** (arreglar en la fuente `prevCashFlow` → las 4 variaciones justas de una vez, en Tendencias E Insights + insights rule-based + prompt IA).

- Nuevo helper puro `DateAlignmentHelper.alignedPreviousInterval(...)` — trunca el intervalo previo al día equivalente del `asOf`. **Gate solo `.thisMonth`+`.month`** (único (período,modo) asimétrico) → **CONVERGE con el gate `aggregatePreviousNeedsAlignment` de fase 2** (ambos `.thisMonth`-only; cero divergencia hero↔Panel — la duda inicial de alinear `.thisWeek` la descartaron AMBAS sesiones).
- `InsightsCalculator.calculate`: param `now: Date = .now`; usa el intervalo alineado en `prevTxns`/`prevCashFlow`/`prevDaysInPeriod`; conserva `prevInterval` completo solo para el label ("vs Jun 26").
- 13 tests `alignedPreviousInterval_*` (trunca thisMonth / no-op resto / edge mes corto / día-1 / mid-month exacto / feb bisiesto / simetría de borde).

**`/code-review high` (4 finders adversariales) → 2 bugs de correctness corregidos:**
1. **Asimetría de medianoche + colapso día-1:** `alignedEnd` era la medianoche del día equivalente → con `.contains` cerrado, una TX del previo con hora (jun 6 14:00) caía fuera mientras su gemela actual (jul 6 14:00) sí contaba; y en día-1 el intervalo colapsaba a ancho cero. **Fix:** extender `alignedEnd` al FIN del día equivalente (`mapped + 1 día`), simétrico con el actual (que incluye hoy completo vía `endOfToday`). +tests de borde que lo guardan.
2. **Determinismo:** `interval` usaba `Date.now` real mientras `asOf` usaba el `now` inyectado → podían divergir. **Fix:** pasar `now` a `period.dateInterval(customRange:, now: now)`.

Convenciones (CLAUDE.md): limpio. Radio de impacto: todos los consumidores mejora/neutral (elimina el falso "gasto bajó" de inicio de mes); `YearComparison` fuera de scope (prevCashFlow propio modo `.year`); cache-key IA no depende de valores (no bump). La alineación se propaga (correctamente) al bloque de insights de grupos (R6 "gasto compartido MoM") vía el `prevTxns` compartido — mantenido (misma asimetría).

**Device-QA (sim iPhone 17 Pro, seed realista) — PARCIAL:** app cold-launch sin crash; Panel + Swift Charts renderizan (sin SIGTRAP de `.annotation`); cero crash reports del app principal. Navegación al hero de Estadísticas bloqueada por **contención de simuladores con la sesión de fase-2 en paralelo** (3 sims homónimos "iPhone 17 Pro" booteados/re-booteados; agent-device apunta por nombre y no desambigua; taps nativos de XcodeBuildMCP no habilitados). e2e visual del hero (signo coherente con la card) → TestFlight/manual, consistente con el diferido del ticket.

**Nota de coordinación:** commit consolidado por la sesión de fase-2 (archivos compartidos no separables a nivel de archivo) → fase 2 + D2 aterrizaron juntos en `f779a7ab`. Verificado que el commit contiene mi versión final con los 2 fixes del code-review (`endOfEquivalentDay`, `now` en `dateInterval`) y los 13 tests.

## QA Visual

### 2026-08-14 — **FAIL**: el fix es correcto donde se aplicó, pero falta una card de la MISMA pantalla

**Resultado: FAIL.** Lo que el ticket arregló funciona y se verificó con su control. Lo que aparece es
**otra instancia del mismo patrón que el barrido no recogió**: la card **«Flujo de Efectivo» de la pestaña
Tendencias**, que compara el mes en curso contra el mes anterior **COMPLETO** mientras la card
«Comparativa», tres dedos más arriba y con la misma etiqueta «vs Jul 26», lo compara alineado.

**Setup:** Yala Dev · Debug-Dev · iPhone 17 Pro · `-uitest -uitest-reset -uitest-skip-onboarding -uitest-seed realista`
· 2336 movimientos · **14 de agosto (día 14 de 31: la ventana de mitad de mes que este escenario exige)** ·
período «Este mes» confirmado en la cápsula (con «Todo el tiempo» hay early-return y no se ejercita nada).

**Lo medido en pantalla, métrica Gastos, todo a la vez y sin cambiar nada más:**

| Card | KPI actual | «vs» | Badge | Base temporal real |
|---|---|---|---|---|
| **Comparativa** | S/ 4 544,00 | **S/ 4 710,00** | Disminución −3,5 % | 1–14 jul (**alineado** ✅) |
| **Flujo de Efectivo** → Total | S/ 4 544,00 | **S/ 8 422,00** | Disminución **−46 %** | 1–31 jul (**sin alinear** ❌) |

![[qa-p2015-comparativa-vs-flujo-descuadre-20260814-113344.png]]

**El control que lo convierte en prueba** (paso obligatorio del guion, porque sin él el escenario podría no
discriminar): cambiando el período a «Mes pasado», el gasto de **julio completo** (la gráfica declara «31
puntos») es **S/ 8 422,00 exacto** — el mismo número que el Flujo de Efectivo usa como «período anterior».
Y 4 710 ≪ 8 422 (44 % de diferencia), así que el escenario **sí discrimina**: no es el caso degenerado en el
que alineado y completo coinciden.

![[qa-p2015-mes-pasado-completo-20260814-113344.png]]

**Causa, localizada en el código:**

- `TrendsTabView.calculatePeriodComparisonData` usa `DateAlignmentHelper.alignedPreviousTotal(...)` — el fix
  de este ticket. ✅
- `TrendsTabView.calculateCashFlowData` filtra el período anterior con `PreviousPeriodHelper.previousInterval`
  **completo** y se lo pasa tal cual a `CashFlowCalculator`. **Cero apariciones de `DateAlignmentHelper` en
  toda la función** (medido). ❌
- Y el mismo widget **sí está alineado en el Panel**: `PanelViewModel.calculateCashFlowWidget` pasa por
  `alignedPreviousTransactions` → `DateAlignmentHelper.alignedPreviousItems`. ⇒ **el «Flujo de Efectivo» del
  Panel y el de Tendencias dan hoy respuestas distintas al mismo usuario en el mismo día.**

**Por qué se escapó, que es lo que importa para no repetirlo:** la tabla «Alcance — otros consumidores con
el mismo patrón» de este ticket lista `PanelViewModel.calculateCashFlowWidget` (`:1743-1774`) y **no** lista
`TrendsTabView.calculateCashFlowData`. El barrido se hizo sobre el Panel y la card Comparativa; el cash flow
de Tendencias no estaba en la lista, así que nadie lo miró.

⚠️ **Y una ambigüedad del QA de julio que conviene resolver antes de dar nada por visto:** el «Progreso —
Grupo B / fase 2» cita como prueba de que «el pipeline MTD funciona end-to-end» un chip de **Flujo de
Efectivo con «Disminución −45,5 %»**. Hoy la card **sin alinear** de Tendencias marca **−46 %** y la alineada
−3,5 %. No hay forma de saber desde el texto cuál de las dos superficies se miró (el párrafo habla de
«Panel + gráficos»), pero un −45,5 % es exactamente la forma que tiene el chip NO alineado. Si aquella
lectura fue sobre Tendencias, se leyó como éxito justo la card que faltaba por arreglar. **Re-medir esa
afirmación antes de reusarla.**

**Lo que SÍ quedó verificado del fix (no se pierde):**

1. La card Comparativa cumple su AC: la serie punteada está recortada al día 14 (la gráfica declara
   «Periodo actual vs anterior, **14 puntos**», frente a los «31 puntos» de un período cerrado) y termina
   por encima de la sólida, coherente con el badge «Disminución −3,5 %».
   ![[qa-p2015-tendencias-gastos-mtd-20260814-113344.png]]
2. Coherencia de signo con métrica **Balance**: 84 078,90 (actual) vs 81 261,30 (anterior) con badge
   «Aumento +3,5 %» — el sentido del badge concuerda con qué serie acaba más arriba. La comprobación
   visual curva↔badge se hizo sobre Gastos; en Balance se verificaron los dos importes y el badge en
   pantalla.
   ![[qa-p2015-balance-signo-20260814-113344.png]]
3. Con período cerrado («Mes pasado») la Comparativa compara mes completo contra mes completo
   (8 422 vs 6 929 «vs Jun 26»), que es lo correcto: el gate solo-`.thisMonth` se comporta como se diseñó.

**No verificado aquí:** el tooltip de scrub del paso 7 del guion (el tap no fija el scrub de forma fiable
desde automatización y la gráfica captura los gestos de scroll), y el modo A-1. La conclusión NO depende de
ellos: se sostiene sobre el control de «Mes pasado», que es aritmético y no visual.

### 2026-07-06
**Resultado:** PASS (sim — no-regresión + coherencia KPI↔curva)

**Setup:** Yala Dev en iPhone 17 Pro (iOS 26.4), seed `realista` (varios meses), período "Este mes" (julio, día 6 en curso), métrica Saldo, modo P-1.

**Card Comparativa (Tendencias):**
![[qa-p20-15-comparativa-curvas-20260706-102740.jpg]]
- KPI: **S/ 80,036.10 vs S/ 62,793.80** · badge **+27.5% vs Jun 26**.
- La **curva anterior (punteada)** termina en **~62K en el día 6** (último punto visible) = coincide con el KPI "vs 62,793.80". ✅ KPI == último punto visible de la curva (objetivo del fix).
- La curva actual (sólida) está por encima de la anterior → el badge verde +27.5% es coherente con lo que se ve. **No hay descuadre** (antes: badge verde con curva anterior por encima).

![[qa-p20-15-comparativa-kpi-20260706-102740.jpg]]

**Coherencia transitiva confirmada:** la card Tendencias y el insight card ("Tu balance creció 27% vs Jun 26") muestran el **mismo +27.5%** (comparten `previousPeriodTotal`). Gráficos Charts renderizan sin crash de `.annotation`.

**Pendiente (no bloqueante):** e2e del escenario EXACTO del bug (balance del anterior muy distinto en día-equivalente vs fin-de-mes, capaz de invertir el signo) + modo A-1 visual → TestFlight/manual; A-1 cubierto por unit test (`calendarYear`). App sin crash, migración lightweight OK.

## ✅ Decisión de producto (TOMADA — 2026-07-06)

**Opción 1 — MTD-vs-MTD (mismo día del mes).** Confirmada por el owner.

Cuando el período actual es parcial (mes en curso), se trunca el período anterior al **mismo día equivalente** (día 4 de junio). El KPI dirá "vs S/ 24,122.10" y el badge ≈ **−27.4%**. Es lo que **ya muestra la curva y el tooltip** → alinea número + badge + gráfica (hoy se contradicen). Reusa `adjustDateToCurrent`/`getOriginalPreviousDate` que ya existen. El copy del info-sheet ("ves si la tendencia va mejorando") respalda esta semántica.

**Sub-decisión (métrica balance) — resuelta por coherencia con la Opción 1:** el "período anterior a la fecha" es el **valor del running balance** en el día equivalente (24,122.10, lo que muestra la curva), NO el delta de los primeros N días. Así el KPI == el último punto visible de la curva anterior, exactamente lo que el usuario ve.

Opciones descartadas (registro): **Opción 2** (full-vs-full, cambia la gráfica y pierde "mismo día del mes"); **Opción 3** (dejar KPI period-full + copy "4 de 30 días", sigue contradiciendo la curva).

## Fix propuesto (una vez decidida la Opción)

Si **Opción 1 (MTD-vs-MTD)** — la de menor cambio y que alinea todo:
1. En `calculatePeriodComparisonData` (`TrendsTabView.swift`), NO usar `previousResult.points.last`. En su lugar, tomar el punto del período anterior **alineado al último día con datos del período actual** — usar la inversa de `adjustDateToCurrent` (`getOriginalPreviousDate`) sobre `currentResult.points.last?.date`, o buscar en `previousResult.points` el punto cuya fecha alineada ≤ dominio actual (equivalente al último punto de `clippedPreviousPoints`). Interpolar/tomar el más cercano si el día exacto no existe.
2. Aplicar el mismo cambio a `PanelViewModel.calculatePeriodComparisonWidget` (`:2558-2561`) — comparte `PeriodComparisonChartView`.
3. Barrido: alinear el resto de sitios de la tabla de Alcance (o documentar por qué se dejan) para no arrastrar el mismo sesgo en widgets de Panel/CashFlow.
4. **No tocar la curva** — ya es correcta. El fix es solo del valor numérico del KPI/chip.

## Riesgos / notas

- **El número visible cambiará** para cualquier usuario en un período parcial (el KPI anterior y el badge se recalculan). En el caso reportado el badge pasaría de +48.3% a ≈ −27.4% — que es lo correcto, pero es un cambio visible; alinea el número con lo que la curva ya mostraba.
- **No romper `.allTime`** (ya retorna temprano en `:1572`) ni períodos ya completos (`.lastMonth`, `.lastYear`) donde period-to-date == period-full — verificar que el fix es no-op ahí.
- **Modo "A-1" (año anterior)** usa `alignmentStrategy .calendarYear` — el fix debe cubrir también ese mapeo (mismo día del año anterior), no solo `.dayOfMonth`.
- **No hay tests** de `calculatePeriodComparisonData` ni de esta alineación hoy. El fix debe venir con test de regresión (ver AC).
- Este bug es **independiente** de p20-13 / [[p20-14_income-expense-classification-trends-reports]] (esos son clasificación income/expense por signo vs categoría; este es alineación temporal de la comparación). Comparten archivo/pantalla pero no causa.

## Acceptance Criteria

- [x] **Decisión de producto tomada y documentada** (Opción 1 — MTD-vs-MTD + sub-decisión balance = valor del punto). ✅ 2026-07-06
- [ ] En la card Comparativa (Tendencias), el KPI "período anterior", el badge de variación y el valor de la curva anterior en el último día visible son **consistentes entre sí** para un período parcial (mes en curso), en las 3 métricas (balance/ingresos/gastos).
- [ ] Mismo criterio aplicado al **widget Comparativa del Panel** (`PanelViewModel.calculatePeriodComparisonWidget`) y a los VariationChip de las cards Tendencias/Comparativa.
- [x] Barrido de los demás consumidores de la tabla de Alcance (widgets categoría/subcat/tags/necesidad/cashflow del Panel): **corregidos** (Grupo B, fase 2 — truncado MTD solo `.thisMonth`; el resto justificado como ya simétrico). ✅ 2026-07-06
- [x] Verificar no-regresión en modos donde period-to-date == period-full (`.lastMonth`, `.lastYear`, `.allTime`) y en modo "A-1" (año anterior, `.calendarYear`): no-op unit-testeado (gate solo `.thisMonth`). ✅ 2026-07-06
- [ ] Test de regresión: con un dataset fijo donde el período anterior tenga saldo distinto en el "día equivalente" vs el fin de período, el KPI anterior == valor de la curva anterior en ese día (al primer decimal), para las 3 métricas y para modos "P-1" y "A-1".
- [ ] Device-QA en Yala Dev: reproducir con el período "Este mes" a mitad de mes y confirmar que badge + KPI + curva cuentan la misma historia (mismo signo).
- [x] Actualizar `qa/coverage-index.json` (regla anti-drift) para el área de comparación de períodos: área `trend-previous-period-alignment` extendida con Grupo B + D2 (`InsightsCalculator`). ✅ 2026-07-06
- [x] **D2 (hero de Tendencias):** las 4 variaciones del hero (balance/ingreso/gasto/prom-diario) alineadas a MTD vía `InsightsCalculator` (gate `.thisMonth`+`.month`, **converge** con fase 2); 2 bugs de `/code-review high` corregidos (asimetría de medianoche del día equivalente + determinismo `now`); unit cubierto (13 tests, incl. bordes día-1/mes-corto/bisiesto); committeado en `f779a7ab`. Device-QA sim parcial (launch + Charts sin crash; visual del hero → TestFlight). ✅ 2026-07-06

migrated from YalaWiki Backlog/p20-15_comparativa-kpi-vs-curva-descuadre.md @ 1934e8ad

## Owner check 2026-08-26 (Jurgen, TF 2.1 build 12)

- Estadísticas → Tendencias → card Comparativa, período Este mes: KPI período anterior, badge y curva punteada cuentan la misma historia en Balance, Ingresos y Gastos.
- Panel → card Comparativa: mismo criterio, cuadra.
- Ticket cerrado por device-QA de alineación KPI/curva. Tests de DateAlignmentHelper ya estaban en árbol (PR 15).
