# Trend Insight Card V2 — bullets al final de Tendencias

## Contexto
Ticket: `tickets/backlog/trends-insight-card-v2-bullets.md` (medium). Cola Yala tras archived-accounts (PR #344 en cola de auto-merge). V1 dejó el Insight al final de Tendencias como un párrafo; V2 lo convierte en bullets — uno por gráfica visible (Tendencia, Comparativa, Cash Flow, Weekday). Free con reglas; Pro con LLM dedicado.

Decisiones del ticket (aplicar sin preguntar — son las recomendadas del propio ticket):
- D1: adaptativo, mínimo 2 / máximo 4 bullets; si una gráfica no tiene data, se omite el bullet.
- D2: exponer `historicalTotals` de los últimos 12 periodos en StatisticsViewModel (cacheable) para Rule TREND_SOSTENIDO + contexto Pro.
- D3: `TrendsAIService` / viewmodel propio; consent reusa `appPreferences.aiInsightsConsentAccepted`.
- D4: Free también ve bullets (no un solo párrafo); firmas y sources según el ticket (trend/comparison/cashFlow/weekday). Sin desglose por cuenta en Cash Flow.
- Sin inventar diseño nuevo: el ticket ya define copy de ejemplo y estructura de código.

## Que se pide
Implementar el AC del ticket V2 completo:
- Card al final de Tendencias con bullets contextualizados (uno por gráfica visible).
- Free rule-based + Pro AI regenerable.
- Tests unit del logic + XCUI del área tocada; gate verde.
- Si el cambio se ve: guarda `capturas/antes.png` y `capturas/despues.png` en el worktree y lista esas rutas en el cierre.
- Board + ticket a `qa` con guion si aplica Device-QA; tickets nuevos si aparecen hallazgos.
- Al terminar: `/cerrar-total` autónomo.

## Que NO hay que tocar
- marketing/, clinicas-dentales-bi.
- No ampliar CashFlowCalculator con desglose por cuenta (fuera de scope V2).
- No reabrir archived-accounts / PR #344.
- No inventar copy de producto fuera del ticket; si hace falta decisión de UI/UX no cubierta, deja propuestas en ticket y para — no inventes.

## Como se sabe que esta bien
- AC del ticket cumplidos; gate verde; PR a 2.1 en cola o mergeado.
- Free ve bullets por gráfica; Pro genera/regenera con contexto de tendencias (no el texto genérico de Insights).
- `/cerrar-total` al terminar.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿Qué dice el bullet de Tendencia, si el boceto del ticket le pasa `previousTotal: nil` (= siempre «onset»)?** → Rule TREND_SOSTENIDO: racha de ≥3 períodos COMPLETOS seguidos subiendo/bajando ≥5 % (ingresos/gastos) o con neto del mismo signo (balance). Sin racha, no hay bullet de Tendencia.
Por qué: el boceto daría siempre «Este es tu primer mes» y duplicaría la Comparativa; la racha es lo único que la gráfica de tendencia dice y la comparativa no. Alternativa descartada: «vs tu promedio» — compara un mes a medias con meses enteros y sesga a la baja.

**D2 · ¿Mínimo 2 bullets?** → La card se monta con ≥1 bullet (mismo gate de ≥5 movimientos de V1); no se fabrica un segundo. Por qué: con ≥5 movimientos casi siempre hay comparativa + día; ocultar la card entera quitaría también el CTA de IA. Alternativa descartada: ocultar con <2.

**D3 · `historicalTotals`** → `StatisticsViewModel.historicalTotals: [TrendHistoryPoint]` (inicio, ingreso, gasto; ordenado, 12 períodos completos), con firma de entrada para no recalcular. Array ordenado en vez de `[Date: Double]` porque la racha necesita orden y las dos magnitudes. Sin unidad natural (Últimos 30 días, Personalizado, Todo el tiempo) no hay racha; el histórico igual alimenta a la IA salvo en Todo el tiempo/Personalizado.

**D4 · Copy nuevo** → 6 frases de racha («Tu gasto viene subiendo desde hace %@», sin concordancia de género), 3 duraciones («%d meses/semanas/años»), 3 de flujo (superávit/déficit con % de cobertura, y «sin ingresos») y 1 de día pico. 16 locales, voseo en es-AR solo donde haya verbo en 2.ª persona.
Por qué: el ticket pide ~10-15 keys y da el ejemplo de tono; sin `stringsdict`, la duración va como sintagma aparte para no romper plurales (pl usa abreviatura).

**D5 · IA Pro** → `TrendsAIService` nuevo (prompt propio, JSON `{"bullets":[{"chart","text"}]}`, caché 24 h, 5 s entre llamadas, Regenerar salta la caché) + `TrendsAIViewModel` propio en la vista. Consent: `aiInsightsConsentAccepted`. Tono/enfoque del usuario reusados (se abren a `internal` los dos helpers de `InsightsLLMService`). Idioma: `AppLocale.current` (regla l10n).

**D6 · Error de IA** → vuelve la card rule-based con el CTA de generar (V2-06) y una línea de aviso localizada existente. No se deja una tarjeta de error sola.

**D7 · Iconos post-IA** → por gráfica: `chart.line.uptrend.xyaxis` tendencia, `arrow.left.arrow.right` comparativa, `arrow.up.arrow.down` flujo, `calendar` día (D5 del ticket). Free y pre-IA: viñeta neutra.
