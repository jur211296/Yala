# Smart Insights — Documento de Diseno

## 1. Vision general

Nueva tab **Insights** en Statistics (primera posicion, izquierda de Tendencias). Vista personalizable con KPIs, graficas, quick stats y textos inteligentes. Usuarios Free ven insights rule-based; usuarios Pro desbloquean capa narrativa con IA (GPT-4o Mini). Todo calculado localmente excepto generacion de textos Pro.

**Prerequisito:** Refactor de filtros deferred (ver seccion 7).

**Plan:** `.planning/SMART-INSIGHTS-DESIGN.md` (este archivo)

---

## 2. Navegacion

Nuevo caso `.insights` en `DetailViewTab` (SharedModels.swift):

```
[Insights] [Tendencias] [Categorias] [Registros]
```

Mismos filtros, mismo periodo, mismo control bar que las demas tabs.

---

## 3. Tiering Free vs Pro

| Elemento | Free | Pro |
|----------|------|-----|
| KPIs numericos | Si | Si |
| Quick stats (grid 2x3) | Si | Si |
| Graficas (comparativa + barras dia) | Si | Si |
| Distribucion por naturaleza | Si | Si |
| Pagos/compromisos | Si | Si |
| Racha de registro | Si | Si |
| Textos inteligentes | Templates fijos (3-4) | LLM: variados, contextuales (5-8) |
| Insight destacado (hero) | Template fijo | LLM: personalizado, fresco |
| "Dato curioso" | Locked (visible con candado) | Combinaciones inesperadas |
| Comparativa ano a ano | Si (si hay datos) | Si (si hay datos) |
| Secciones colapsables | Si | Si |
| Personalizacion toggles | Si | Si |

**Visual para contenido Pro bloqueado:** Card con `.redacted(reason: .placeholder)` + opacity reducida + overlay centrado: `lock.fill` + `ProBadge(size: .small)`. Tap -> `UpgradePromptSheet(feature: .smartInsightsAI, context: .proFeature)`.

---

## 4. Anatomia de la vista

```
InsightsTabView
|
|- Control Bar (period selector + filter chips + exclude badge)
|
|- Banner Pro AI (condicional — ver seccion 10)
|
|- 1. RESUMEN DEL PERIODO (siempre visible, no toggleable)
|  |- Gasto total + VariationChip vs periodo anterior
|  |- Ingreso total + VariationChip
|  |- Balance neto (ingreso - gasto)
|  |- # de registros del periodo
|
|- 2. INSIGHT DESTACADO (colapsable)
|  |- Pro+AI: LLM hero card (fondo sutil accent)
|  |- Pro sin AI / Free: Template rule-based
|  |- Loading: Shimmer + sparkle pulse
|
|- 3. QUICK STATS — Grid 2x3 (colapsable)
|  |- Promedio diario de gasto
|  |- Top categoria (nombre + monto + %)
|  |- Top subcategoria (nombre + monto)
|  |- Gasto mas alto (monto + nota/subcategoria)
|  |- Dia de mas gasto (fecha + monto)
|  |- Suscripciones del periodo (monto total)
|
|- 4. PAGOS Y COMPROMISOS (colapsable, adaptativo)
|  |- Pagos planificados pendientes (cantidad + monto)
|  |- Suscripciones activas (cantidad + monto mensual)
|  |- Presupuestos en riesgo (>75%, BudgetProgressBar + proyeccion)
|
|- 5. RACHA DE REGISTRO (condicional: solo si racha > 3 dias)
|  |- "Llevas 15 dias registrando gastos"
|
|- 6. GRAFICA COMPARATIVA (colapsable)
|  |- PeriodComparisonChartView (reutilizado)
|
|- 7. GRAFICA BARRAS POR DIA DE LA SEMANA (colapsable)
|  |- 7 BarMarks (Lun-Dom), highlight del maximo
|
|- 8. DISTRIBUCION POR NATURALEZA (colapsable)
|  |- Stacked bar horizontal: [Esencial 65%|Prioridad 20%|Opcional 15%]
|
|- 9. COMPARATIVA ANO A ANO (condicional: solo si hay datos)
|  |- "En marzo 2025 gastaste PEN 3,200. Este marzo llevas PEN 2,800."
|
|- 10. TEXTOS INTELIGENTES (colapsable)
|  |- 3-5 InsightCards (Pro+AI: LLM / Free: templates)
|  |- 1 "Dato curioso" (Pro only, locked para Free)
|
|- 11. PRIMERA VEZ (condicional: 1 vez)
|  |- Tip inline: "Aqui veras un resumen de tus finanzas..."
|
|- yalaSafeBottomPadding()
```

**Secciones adaptativas:** Si no hay datos relevantes (0 pagos, 0 presupuestos, racha < 3, sin datos del ano anterior), la seccion no se renderiza.

---

## 5. Equilibrio visual

Alternancia estricta de formatos:

```
[Resumen]        -> Metric cards (numeros grandes)
[Destacado]      -> Narrative hero card (texto + dato)
[Quick Stats]    -> Grid 2x3 mini metric cards
[Compromisos]    -> Alert cards (icono + barra progreso)
[Racha]          -> Inline badge (pequeno, celebratorio)
[Comparativa]    -> Chart card (lineas)
[Barras dia]     -> Chart card (barras)
[Naturaleza]     -> Stacked bar (visual compacto)
[Ano a ano]      -> Stat row (texto comparativo)
[Textos]         -> Narrative cards (texto + dato inline)
```

Regla: nunca 2 secciones consecutivas del mismo formato.

---

## 6. Brand Voice en Insights

### Principios

1. **Datos primero, opinion despues** — lidera con el numero
2. **Nunca culpar** — describir, no juzgar
3. **Proponer, no imponer** — "que tal si...?" no "deberias..."
4. **Celebrar con mesura** — 1 emoji maximo
5. **El usuario tiene razon** — si gasto mas, quiza lo necesitaba
6. **Ofrecer accion** — "revisamos?", "ajustamos?"

### Buenos vs malos

**Gasto subio:**

| Malo (por que) | Bueno |
|----------------|-------|
| "Gastaste demasiado en Comida" (juicio) | "Comida fue tu categoria mas fuerte: PEN 800 (+12%)" |
| "Cuidado! Gastos fuera de control" (alarmista) | "Tus gastos subieron 15% — quieres revisar que cambio?" |
| "Deberias gastar menos" (imperativo) | "Entretenimiento subio PEN 200. Tu decides si ajustar." |
| "Error: superaste tu presupuesto" (frio) | "Tu presupuesto de Transporte llego al 110%. Ajustemos." |
| "Tus finanzas estan mal" (negativo) | "Balance negativo este mes. Veamos como equilibrarlo." |

**Gasto bajo:**

| Malo (por que) | Bueno |
|----------------|-------|
| "INCREIBLE!!!" (exagerado) | "Buen mes: gastaste 12% menos que en febrero" |
| "Felicidades por no gastar tanto" (condescendiente) | "Tu gasto en Comida bajo PEN 150. Buen ritmo." |
| "Sigue asi y seras millonario" (irreal) | "Llevas 3 meses reduciendo gastos opcionales." |

**Dato neutro:**

| Malo (por que) | Bueno |
|----------------|-------|
| "PEN 45/dia es mucho" (juzga) | "Tu promedio diario: PEN 45. El mes pasado fue PEN 42." |
| "45 transacciones, eso es demasiado" (arbitrario) | "45 gastos registrados, 8 mas que en febrero." |
| "Solo 3 ingresos, busca mas" (invasivo) | "3 ingresos este mes por PEN 5,000." |

**Presupuestos:**

| Malo (por que) | Bueno |
|----------------|-------|
| "ALERTA: presupuesto agotado" (alarmista) | "Llevas el 85% de Comida. Quedan 8 dias y PEN 120." |
| "Fallaste tu presupuesto" (culpa) | "Comida paso el limite por PEN 50. Ajustamos para el proximo?" |

### System prompt LLM

Incluira reglas de BRAND-VOICE.md + estos principios + datos agregados. Nunca montos exactos individuales.

---

## 7. Filtros

### Prerequisito: Refactor filtros deferred

**Problema actual:** Los filtros se aplican inmediatamente al seleccionar (mutan SessionState directo). El boton "Aplicar" y "X" hacen lo mismo (dismiss). No hay cancelacion real.

**Solucion:** Refactorizar RecordsFiltersView para usar estado local:
- Al abrir sheet: copiar valores de SessionState a @State locales
- Chips mutan estado local (preview visual, no aplican)
- "Aplicar": escribir estado local a SessionState
- "X": descartar cambios (dismiss sin escribir)

**Beneficio para Smart Insights:** LLM se llama 1 sola vez al aplicar filtros, no durante exploracion.

**Beneficio general:** Buena practica iOS. Cancelar = cancelar. Aplica a toda la app.

### Comportamiento post-refactor

- Datos locales (KPIs, graficas) se recalculan al aplicar filtros (instantaneo)
- LLM se invoca 1 vez tras aplicar
- Cambio de periodo (chips directos): debounce 1s antes de llamar LLM
- Sheet abierta: ningun recalculo hasta "Aplicar"

---

## 8. Estrategia LLM

### Cuando llamar

| Evento | Llamar? | Nota |
|--------|---------|------|
| Abre tab sin cache | Si | Primera carga |
| Cambia periodo | Si, debounce 1s | Datos diferentes |
| Aplica filtros (cierra sheet) | Si | 1 sola llamada |
| Abre tab con cache valido | No | Usa cache |
| Sin conexion | No | Cache o fallback |
| Nuevas transacciones desde cache | Si | Cache invalidado |

**Cache key:** `periodo + hash(filtros) + conteo transacciones`
**Rate limit:** Maximo 1 llamada cada 5s.

### Datos enviados al LLM

```json
{
  "period": "marzo 2026",
  "comparison": "febrero 2026",
  "currency": "PEN",
  "spending": {
    "total_variation": "+12%",
    "top_categories": [
      {"name": "Comida", "pct": 40, "variation": "+12%"},
      {"name": "Transporte", "pct": 20, "variation": "-5%"}
    ],
    "nature_split": {"essential": 65, "priority": 20, "optional": 15}
  },
  "budgets_at_risk": [
    {"name": "Comida", "usage_pct": 85, "days_left": 8}
  ],
  "income_variation": "-3%",
  "count": 45,
  "daily_avg_variation": "+8%",
  "streak": 15,
  "year_ago_available": true,
  "year_ago_variation": "-12%"
}
```

**Nunca:** montos exactos, notas, nombres de cuentas, nombres de personas.

### Loading UX

KPIs y graficas cargan instantaneo (local). Solo secciones IA tienen loading:

```swift
HStack(spacing: DS.Spacing.sm) {
    Image("YalaSpark")
        .foregroundStyle(theme.accent)
        .symbolEffect(.pulse)
    Text("Analizando tus datos...")
        .font(DS.Typography.caption)
        .foregroundStyle(.secondary)
}
// + .yalaSkeleton(true) en placeholder del texto
```

### Fallback offline

| Estado | Comportamiento |
|--------|----------------|
| Sin conexion + hay cache | Mostrar cache + banner: "Sin conexion. Mostrando ultimo analisis. Se actualizara al reconectarte." |
| Sin conexion + sin cache | Solo datos locales + banner: "Sin conexion. Los insights personalizados estaran disponibles al conectarte." |
| Conexion restaurada + cache viejo | Banner con boton: "Actualizar insights" (no auto-refresh) |
| LLM error/timeout | Datos locales + rule-based + banner: "No pudimos generar los insights. Intenta mas tarde." |

---

## 9. Secciones colapsables

Patron con @AppStorage (estado persistido):

```swift
@AppStorage("insightsQuickStatsExpanded") private var quickStatsExpanded = true

YalaSectionHeader(title: "Quick Stats",
                  icon: quickStatsExpanded ? "chevron.up" : "chevron.down",
                  action: { withAnimation(.easeInOut) { quickStatsExpanded.toggle() } })

if quickStatsExpanded {
    QuickStatsGrid(...)
        .transition(.opacity.combined(with: .move(edge: .top)))
}
```

Diferencia con toggles de Personalizacion: toggles **ocultan completamente**; collapse es **temporal y visual**, persistido entre sesiones.

---

## 10. Banner Pro AI Consent

### Flujo de estados

```
Es Pro? -- No --> No mostrar (cards locked ya comunican Pro)
    |
   Si
    |
AI consent activo? -- Si --> No mostrar (funciona)
    |
   No
    |
Dismissed permanente? -- Si --> No mostrar
    |                           (1 vez: texto "Siempre puedes activarlo en...")
   No
    |
   MOSTRAR BANNER
```

### Diseno del banner

Patron TrialBanner/LimitReachedBanner:
- Fondo: DS.Semantic.infoBackground
- Icono: YalaSpark + accent
- Titulo: "Activa los insights con IA"
- Texto: "Como usuario Pro, puedes obtener analisis mas personalizados de tus finanzas."
- Boton primario: "Activar" -> navega a Perfil > Personalizacion > Smart Insights
- Boton secundario: "No me interesa" -> dismiss permanente

### Despues de "No me interesa"

Texto inline sutil (1 sola vez, no banner):
> "Siempre puedes activar los insights con IA en Perfil > Personalizacion > Smart Insights."

Storage: @AppStorage("dismissedAIInsightsBanner") + @AppStorage("shownAIInsightsFallbackHint")

---

## 11. Personalizacion

Nueva seccion en PersonalizationSettingsView -> sheet SmartInsightsSettingsView:

```
Smart Insights
|
|- INTELIGENCIA ARTIFICIAL
|  |- [Toggle] Insights con IA (Pro: toggle / Free: lock + ProBadge)
|  |  |- Activar -> AIConsentAlert con texto:
|  |     "Para generar insights personalizados, Yala comparte con
|  |      OpenAI un resumen de tus categorias y porcentajes de gasto.
|  |      Nunca se comparten montos exactos, notas personales ni
|  |      informacion de tus cuentas."
|  |- [Caption] "Los datos se procesan de forma anonima."
|
|- RESUMEN Y METRICAS
|  |- [Toggle] KPIs principales
|  |- [Toggle] Quick Stats
|
|- COMPROMISOS
|  |- [Toggle] Pagos pendientes
|  |- [Toggle] Suscripciones
|  |- [Toggle] Presupuestos en riesgo
|
|- GRAFICAS
|  |- [Toggle] Comparativa vs periodo anterior
|  |- [Toggle] Gasto por dia de la semana
|
|- ANALISIS
|  |- [Toggle] Distribucion por naturaleza
|  |- [Toggle] Textos inteligentes
|
|- [Boton] Restaurar valores por defecto
```

---

## 12. Edge cases

| Caso | Comportamiento |
|------|----------------|
| 0 transacciones | YalaEmptyState — "Registra gastos para ver tus insights" |
| < 5 transacciones | KPIs si, graficas y textos ocultos + mensaje "Registra mas para desbloquear todos los insights" |
| Sin periodo anterior | VariationChips muestran "—", textos sin comparativas |
| Solo ingresos | KPI gasto = PEN 0, insight adapta |
| Multiples monedas | amountInPreferredCurrency (ya estandarizado) |
| LLM error/timeout | Datos locales + rule-based + banner sutil |

---

## 13. Recomendaciones adicionales (aprobadas)

### A) Notificacion mensual
Al inicio de cada mes, si > 10 transacciones del mes anterior:
> "Tu resumen de febrero esta listo. Abrelo en Insights."
Integrar con ReportNotificationService. Toggle en notificaciones.

### B) Comparativa ano a ano
Cuando hay datos del mismo mes del ano anterior — seccion condicional con texto comparativo.

### C) Primera vez en Insights
Tip inline (1 vez, @AppStorage("hasSeenInsightsIntro")):
> "Aqui veras un resumen inteligente de tus finanzas. Personaliza las secciones en Perfil > Personalizacion."

### D) Dato curioso (Pro LLM only)
El LLM combina datos de formas inesperadas:
- "Si mantuvieras este ahorro, en 6 meses tendrias para unas vacaciones"
- "Tu gasto en cafe este mes equivale a 2 cenas afuera"

### E) Racha de registro (gamification suave)
- "Llevas 15 dias registrando gastos"
- Solo aparece si racha > 3 dias

### F) Distribucion por naturaleza (stacked bar)
Barra horizontal: [Esencial 65%|Prioridad 20%|Opcional 15%]

### G) Exportar insights (futuro, no v1)
Boton toolbar para imagen compartible. Dejar espacio en diseno.

---

## 14. Privacy / Legal

Actualizar:
1. **Privacy Manifest** (PrivacyInfo.xcprivacy) — uso de datos agregados de categorias
2. **Privacy Policy web** — seccion Smart Insights
3. **Consent in-app** — reutilizar AIConsentAlert con texto especifico
4. **Terms of Service** — mencion de procesamiento de datos agregados con IA

---

## 15. Arquitectura

### Archivos nuevos

```
App/Views/Statistics/InsightsTabView.swift
App/ViewModels/InsightsViewModel.swift
App/Logic/Calculators/InsightsCalculator.swift
App/Logic/Calculators/WeekdaySpendingCalculator.swift
App/Views/Statistics/Components/InsightCard.swift
App/Views/Statistics/Components/QuickStatCell.swift
App/Views/Statistics/Components/NatureBar.swift
App/Views/Settings/SmartInsightsSettingsView.swift
Services/InsightsLLMService.swift
```

### ProFeature

```swift
case smartInsightsAI  // isProOnly = true, icon: "sparkles"
```

### Modelos

```swift
struct InsightData {
    let periodSummary: PeriodSummary
    let quickStats: QuickStats
    let commitments: Commitments
    let weekdaySpending: [WeekdaySpending]
    let natureDistribution: NatureDistribution
    let streak: Int
    let yearOverYear: YearComparison?
    let ruleBasedInsights: [InsightResult]
}

struct InsightResult {
    let id: String
    let icon: String
    let text: AttributedString
    let sentiment: Sentiment       // .positive / .neutral / .attention
    let isProOnly: Bool
}

enum Sentiment {
    case positive   // successForeground accent
    case neutral    // sin color especial
    case attention  // warningForeground accent (nunca "error/negative")
}
```

### Flujo de datos

```
1. InsightsTabView.onAppear / onChange(periodo/filtros)
   |
2. InsightsViewModel.calculateLocalData()
   | <- FilterService.filterForTrends() + calculadoras existentes
   | <- Resultado inmediato -> renderiza KPIs, graficas, quick stats
   |
3. InsightsViewModel.generateAIInsights() (si Pro + AI consent + online)
   | <- Construye JSON agregado (nunca datos individuales)
   | <- Verifica cache: si valido, usa cache
   | <- Si no, llama InsightsLLMService
   | <- Resultado -> renderiza cards narrativas + insight destacado
   |
4. Fallback:
   |- Sin conexion + cache -> Muestra cache + banner
   |- Sin conexion + sin cache -> Solo datos locales + banner
   |- Pro sin AI consent -> Rule-based + banner activacion
   |- Free -> Rule-based + cards locked con ProBadge
```

---

## 16. Decisiones finales

| Decision | Resolucion |
|----------|-----------|
| Filtros | Refactor a deferred (prerequisito) |
| LLM en filtros | 1 llamada al aplicar |
| LLM en periodo | Debounce 1s |
| Secciones colapsables | @State + @AppStorage persistido |
| Quick stats | Grid 2x3 |
| Grafica comparativa | Reutilizar PeriodComparisonChartView |
| Consent IA | Reutilizar AIConsentAlert, texto especifico |
| Banner Pro AI | Con "No me interesa" + hint one-time |
| Offline | Cache + banner conexion + restaura |
| Free locked | redacted + lock.fill + ProBadge |
| Loading IA | Shimmer + YalaSpark pulse |
| Datos al LLM | Solo agregados |
| Sentiment | positive/neutral/attention |
| Notificacion mensual | Via ReportNotificationService |
| Comparativa ano a ano | Condicional |
| Racha | Condicional (> 3 dias) |
| Dato curioso | Pro only |
| Primera vez | Tip inline 1 vez |
| Secciones adaptativas | No renderizar si sin datos |
