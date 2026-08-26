---
id: trends-insight-card-v2-bullets
status: backlog
priority: medium
area: stats
created: 2026-05-13
updated: 2026-08-26
source: YalaWiki/Backlog/trends-insight-card-v2-bullets.md
---


# Trend Insight Card V2 — resumen narrativo por bullets

## 📚 Contexto

Continuación de `stats-polish-panel-alignment` (Trends tab, commit pendiente
post device QA). En V1 quedó pendiente:

- Skip Rule 2 TREND SOSTENIDO (requiere `historicalTotals[N]` aún no expuesto
  por `StatisticsViewModel`).
- Pro AI placeholder reusa `InsightsViewModel.triggerAIGeneration()` → texto
  general del tab Insights, **NO contextualizado a tendencias temporales**.
- Free rule-based actual genera 1 hallazgo único (ONSET / VARIATION /
  STABILITY).

La conversación de diseño Iter del polish concluyó:
> "Mover el Insight al final y que sea un resumen narrativo en bullets, uno
> por gráfica que ve el usuario (Tendencia, Comparativa, Cash Flow, Weekday).
> Cierra la experiencia en lugar de adelantar el verdict arriba."

V1 movió el Insight Card al final pero mantiene el formato actual (1 párrafo
general). V2 implementa el cambio a bullets contextualizados.

## Objetivo

Convertir el Trend Insight Card al final de la tab Tendencias en un **resumen
narrativo de 3-4 bullets**, donde cada bullet describe lo que el usuario está
viendo en una de las gráficas anteriores (Tendencia, Comparativa, Cash Flow,
Weekday). Free con rule-based; Pro con LLM dedicado.

Ejemplo del output esperado (Pro AI):

```
📈 Análisis del período
  • Según la gráfica de tendencia, tu saldo bajó S/ 2.000 este mes,
    principalmente entre el día 4 y el 6.
  • La comparativa nos dice que contra el periodo anterior subiste tu
    balance en un 10%.
  • Tu flujo de efectivo muestra que gastaste 40% más de lo que ingresó
    este mes — el balance neto quedó en rojo.
  • El día más caro fue el lunes con un promedio de S/ 250 por movimiento.

✨ Análisis con IA · ↻ Regenerar
```

> **Nota (verificado 2026-07-01)**: el ejemplo original de este ticket
> decía "cuello de botella en la cuenta BCP Soles (40% del total)" — dato
> que **no existe hoy**. `CashFlowSummary` (`CashFlowCalculator.swift:25`)
> solo expone `totalIncome/totalExpense/netFlow/chartData/currencyCode`,
> **sin desglose por cuenta**. El bullet de Cash Flow real solo puede
> hablar de income/expense ratio o dirección del netFlow (ver D2 abajo)
> — desglose por cuenta sería un dato nuevo, fuera de scope de V2 salvo
> que se decida ampliar `CashFlowCalculator` (no está en el plan actual).

## Decisiones a tomar al implementar

### D1. Number de bullets — fijo o adaptativo?

- **Opción A — Fijo 4 bullets** (uno por gráfica visible). Predecible pero
  rígido. Si una gráfica está oculta (ej. Comparativa en `.allTime`), el
  bullet correspondiente desaparece.
- **Opción B — Adaptativo 3-5 bullets** según data disponible. Más flexible.
  Riesgo de inconsistencia visual entre cards (mes con 4, mes con 2).
- **Recomendación V2**: Adaptativo con mínimo 2 / máximo 4. Si una gráfica
  no tiene data, NO se incluye el bullet.

### D2. Data layer — historicalTotals[N]

V1 saltó la Rule 2 TREND SOSTENIDO por falta de `historicalTotals[N]`. V2
necesita esa data **además** para alimentar el LLM con contexto temporal:

- Expandir `StatisticsViewModel` para exponer `historicalTotals: [Date: Double]`
  de los últimos 12 períodos (cap por R-T-5 del V1).
- Cálculo cacheable (no recalcula cada render).
- Pure-logic helper `TrendInsightLogic.finding(...)` se expande a 5 reglas:
  ONSET / TREND_SOSTENIDO / VARIATION / STABILITY (las 4 originales) +
  CASHFLOW_HOTSPOT (nueva — análisis de la gráfica de flujo) + WEEKDAY_PEAK
  (análisis del día pico).

### D3. Pro AI — TrendsAIService dedicado

- **Nuevo `TrendsAIService`** con prompt específico que recibe 4 contextos
  (trend points + comparison delta + cashflow summary + weekday peak).
- Output: 3-5 bullets markdown con hallazgos por gráfica.
- Reuso: extraer base común con `InsightsViewModel.triggerAIGeneration()` si
  conviene; si no, viewmodel separado `TrendsAIViewModel`.
- Consent flow: reusa `appPreferences.aiInsightsConsentAccepted` (mismo gate
  global, no doble consent).

### D4. Free rule-based — bullets también

Free user en V2 también ve bullets (no 1 párrafo monolítico). Cada bullet
es una `TrendInsightFinding` distinta:

- Bullet 1: Tendencia → `TrendInsightLogic.findingForTrend(...)` (Rules ONSET
  / TREND_SOSTENIDO / VARIATION / STABILITY).
- Bullet 2: Comparativa → `TrendInsightLogic.findingForComparison(...)`
  (Rule VARIATION con `previousPeriodTotal`).
- Bullet 3: Cash Flow → `TrendInsightLogic.findingForCashFlow(...)` (Rule
  CASHFLOW_RATIO — income/expense ratio o dirección del netFlow; **no**
  desglose por cuenta, ver nota de verificación arriba).
- Bullet 4: Weekday → `TrendInsightLogic.findingForWeekday(...)` (Rule
  WEEKDAY_PEAK destaca el día más caro o más variable).

Cap `lineLimit(2)` por bullet para evitar cards muy verticales (R-T-3).

### D4-bis. Estructura de código concreta (verificado contra `TrendsTabView.swift`
### y `WeekdaySpendingCalculator.swift` — hueco que el plan original no cubría)

El plan original nombra `findingForTrend/findingForComparison/findingForCashFlow/`
`findingForWeekday` pero no especifica firmas ni de dónde saldría cada input.
Con el código actual ya mapeado, esto es lo que se necesitaría:

```swift
// TrendInsightLogic.swift — ampliación de V1

/// Un finding YA localizable + su origen (para icon contextual en D5 y
/// para que la UI pueda ordenar/filtrar por gráfica visible).
struct TrendInsightBullet: Equatable, Identifiable {
    enum Source: Equatable { case trend, comparison, cashFlow, weekday }
    let id: Source
    let finding: TrendInsightFinding   // reusa el enum de V1, ampliado (ver abajo)
}

// V1 solo tiene 4 cases (onset/variationUp/variationDown/stable).
// V2 necesita separar "qué pregunta responde" de "qué dice" — se puede
// seguir reusando el mismo enum para trend+comparison (ambos son
// variación temporal), y añadir 2 cases nuevos:
enum TrendInsightFinding: Equatable {
    case onset
    case variationUp(percent: Int, metric: TrendMetric)
    case variationDown(percent: Int, metric: TrendMetric)
    case stable(metric: TrendMetric)
    // NUEVO V2:
    case cashFlowSurplus(ratio: Int)      // netFlow > 0, ratio = income/expense %
    case cashFlowDeficit(ratio: Int)      // netFlow < 0
    case weekdayPeak(weekday: Int, average: Double, currencyCode: String)
}

enum TrendInsightLogic {
    // V1 — sin cambios de firma, se reusa para trend Y comparison
    // (mismo cálculo, distinto par current/previous).
    static func finding(metric:currentTotal:previousTotal:) -> TrendInsightFinding { … }

    // NUEVO V2 — input: CashFlowSummary ya calculado por
    // TrendsTabView.cashFlowCard (línea ~1142), sin fetch adicional.
    static func findingForCashFlow(summary: CashFlowSummary) -> TrendInsightFinding? {
        guard summary.totalExpense > 0 else { return nil }  // sin gasto, sin finding
        let ratio = Int((summary.totalIncome / summary.totalExpense * 100).rounded())
        return summary.netFlow >= 0 ? .cashFlowSurplus(ratio: ratio)
                                     : .cashFlowDeficit(ratio: ratio)
    }

    // NUEVO V2 — input: [WeekdaySpending] ya calculado, mismo array que
    // alimenta weekdayChartSection (TrendsTabView.swift:1308, @State
    // weekdaySpending línea 89). Reusa exactamente topDay de
    // weekdayCardBody (línea ~1329) — no requiere nuevo cálculo.
    static func findingForWeekday(
        spending: [WeekdaySpending],
        currencyCode: String
    ) -> TrendInsightFinding? {
        guard let top = spending.filter({ $0.average > 0 })
                                 .max(by: { $0.average < $1.average }) else { return nil }
        return .weekdayPeak(weekday: top.weekday, average: top.average, currencyCode: currencyCode)
    }

    // NUEVO V2 — construye la lista adaptativa (D1) para la card.
    // Orden fijo: trend, comparison, cashFlow, weekday. nil se omite.
    static func bullets(
        metric: TrendMetric,
        currentTotal: Double,
        previousTotal: Double?,           // comparison, ya existe en V1 (previousPeriodTotal)
        cashFlowSummary: CashFlowSummary?, // nil si .allTime o sin data
        weekdaySpending: [WeekdaySpending],
        currencyCode: String
    ) -> [TrendInsightBullet] {
        var result: [TrendInsightBullet] = [
            .init(id: .trend, finding: finding(metric: metric, currentTotal: currentTotal, previousTotal: nil))
        ]
        if let prev = previousTotal {
            result.append(.init(id: .comparison, finding: finding(metric: metric, currentTotal: currentTotal, previousTotal: prev)))
        }
        if let summary = cashFlowSummary, let cf = findingForCashFlow(summary: summary) {
            result.append(.init(id: .cashFlow, finding: cf))
        }
        if let wd = findingForWeekday(spending: weekdaySpending, currencyCode: currencyCode) {
            result.append(.init(id: .weekday, finding: wd))
        }
        return result  // ya viene con min 1 / max 4; D1 pide min 2 — validar en QA V2-02/V2-03
    }
}
```

**Puntos abiertos que esta estructura no resuelve solos** (para decidir al
implementar, no bloquean el diseño):
- `findingForTrend` (Rule TREND_SOSTENIDO) sigue bloqueada por
  `historicalTotals[N]` — ver D2, sin cambios respecto al plan original.
- El bullet de trend (Rule ONSET/VARIATION/STABLE) y el de comparison usan
  la MISMA función `finding(...)` con distinto par de totales — no son
  reglas distintas, son el mismo cálculo aplicado dos veces (una vs. el
  período anterior comparable, otra vs. el histórico). Si D1 exige mínimo
  2 bullets y ambos colapsan al mismo `case` (ej. dos `.stable`), la UI
  necesitará decidir si los funde en 1 bullet o los muestra igual con
  distinto prefijo — no especificado, decidir en implementación.
- `TrendsAIService` (D3) necesitaría los MISMOS 4 inputs de `bullets(...)`
  serializados a texto de prompt — la firma de arriba ya es un buen punto
  de partida para el payload del LLM (evita duplicar el fetch de data).

### D5. Sin AI vs con AI — diferenciación visual

- Free rule-based: bullets prefix `•` neutros, header `📈 Análisis del período`
  (sin sparkles).
- Pro pre-AI: igual a Free + CTA "Generar análisis IA" (mismo flow V1).
- Pro post-AI: bullets prefix con icon contextual (`chart.line.uptrend.xyaxis`
  para tendencia, `arrow.left.arrow.right` para comparativa, etc.), header
  con sparkles + título.

### D6. Empty state

Si `txCount < 5` (mismo gate que V1), el card NO se monta. Mantener
consistencia con V1.

## Cambios concretos esperados

Ver **D4-bis** arriba para firmas concretas — resumen de archivos tocados:

- **NEW** `Yala/Services/TrendsAIService.swift` (~150 LOC) con prompt dedicado.
- **NEW** `TrendsAIViewModel` o expansión de `InsightsViewModel` con métodos
  específicos.
- **MOD** `Yala/App/Logic/TrendInsightLogic.swift` (verificado 2026-07-01:
  hoy 47 líneas, 1 función `finding(...)` + enum `TrendInsightFinding` de
  4 cases) — se amplía con `findingForCashFlow`, `findingForWeekday`,
  `bullets(...) -> [TrendInsightBullet]`, y 3 cases nuevos del enum
  (`cashFlowSurplus/cashFlowDeficit/weekdayPeak`). `findingForTrend`/
  `findingForComparison` NO son funciones nuevas — reusan `finding(...)`
  de V1 sin cambio de firma (ver nota D4-bis sobre por qué no son reglas
  distintas).
- **MOD** `Yala/App/ViewModels/StatisticsViewModel.swift` — expone
  `historicalTotals: [Date: Double]` (cap 12 períodos). Verificado
  2026-07-01: no existe hoy ningún campo `historical*` en este archivo —
  hueco real, sin trabajo previo que reutilizar.
- **MOD** `Yala/App/Views/Statistics/TrendsTabView.swift` (verificado
  2026-07-01: hoy 1710 líneas; el Insight Card vive en
  `trendInsightCard`/`freeTrendInsightCard`/`proTrendInsightCard`/
  `proAIInsightCard`/`proPreAIInsightCard`/`findingText`, líneas 696-889):
  - `freeTrendInsightCard` (línea 710) reescribe a bullets list (1 por
    finding de `TrendInsightLogic.bullets(...)`).
  - `proAIInsightCard` (línea 784) parsea markdown bullets desde el LLM
    response — hoy usa `AIInsightCardComponents.markdownAttributed(aiHero)`
    con 1 párrafo (línea 788), shared con `InsightsTabView` (deuda técnica
    cross-file ya documentada en CLAUDE.md — extracción a
    `Yala/App/Views/Shared/` pendiente independiente de este ticket).
  - `proPreAIInsightCard` (línea 829) también muestra bullets rule-based
    (preview) en vez del 1-párrafo actual.
  - Los datos de `cashFlowSummary`/`weekdaySpending` que necesita D4-bis
    ya existen en este archivo como locals de `cashFlowCard` (línea 1142)
    y `@State weekdaySpending` (línea 89) — no requiere nuevo fetch, solo
    pasarlos a las nuevas funciones.
- **L10n** ~10-15 keys nuevas para los hallazgos cashflow + weekday
  (`Insight.cashFlowSurplus/cashFlowDeficit/weekdayPeak` × variantes por
  metric si aplica) × 16 locales, siguiendo el patrón de las 9 keys
  `Insight.varUp*/varDown*/stable*/onset` ya existentes en `L10n.swift`.

## Out of scope V2

- Cambio del flujo de consent global (sigue gateado por
  `aiInsightsConsentAccepted`).
- Refactor del AI cache de Insights existente (separado).
- Telemetry adicional (Pro AI generations contadas igual que en Insights).

## QA scenarios (V2 — propuesta inicial)

| ID | Escenario |
|---|---|
| V2-01 | Free + ≥5 tx + 4 gráficas visibles → 4 bullets rule-based ordenados. |
| V2-02 | Free + `.allTime` → 3 bullets (Comparativa oculta, sin bullet de comparativa). |
| V2-03 | Free + filtro currency único → 3 bullets (CashFlow byCurrency oculto si solo 1 currency). |
| V2-04 | Pro pre-AI → mismo card que Free + CTA "Generar análisis IA". |
| V2-05 | Pro post-AI → 3-5 bullets con icons contextuales por bullet. |
| V2-06 | Pro AI error → fallback al rule-based 4-bullets. |
| V2-07 | Card altura razonable (≤ 240pt) con 4 bullets (R-T-3 mitigada). |
| V2-08 | Dynamic Type XXL → bullets respetan lineLimit(2) sin overflow. |
| V2-09 | Voseo es-AR aplica a verbos 2da persona conjugados de los hallazgos
        (cashflow + weekday nuevos). |
| V2-10 | VoiceOver lee cada bullet como elemento independiente. |
| V2-11 | Tap "Regenerar" Pro → loading + nuevo LLM call. |
| V2-12 | iPad wide → bullets list mantiene 1 columna (no grid). |

## Estimación

Sprint medio: ~3-4 sesiones (data layer + AI service + rule-based + UI bullets
+ L10n + tests + QA). Bloquea: nada (Trends V1 ya envío sin esto).

## Riesgos

- **R-V2-1** Prompt LLM mal calibrado → bullets repetitivos o vagos.
  Mitigación: testing con 3-5 períodos diversos antes de ship.
- **R-V2-2** Costo aumenta (más context al LLM = más tokens). Mitigación:
  cache agresivo (24h) y reuse del consent gate global.
- **R-V2-3** Bullets adaptativos rompen consistencia visual mes a mes.
  Mitigación: min 2 / max 4, ordering estable.
- **R-V2-4** `historicalTotals[N]` recalcular cada filter change es caro.
  Mitigación: cachear en StatisticsViewModel con `@Observable` invalidation
  controlada.

## Notas

- Conversación de diseño consolidada en CLAUDE.md "Decisiones Recientes"
  (entry de Trends polish post commit).
- La decisión "mover al final" ya está implementada en V1 — V2 solo cambia
  el contenido del card.
- Cuando se cierre V2, archivar este ticket con prefix `ok_`.

migrated from YalaWiki Backlog/trends-insight-card-v2-bullets.md @ 1934e8ad
