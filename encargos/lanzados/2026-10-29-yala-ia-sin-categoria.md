# Yala IA: clasificación sin categoría

Cierre: **cierra-sola** → al terminar, `/cerrar-total`.
Versión **2.2**. Base `origin/2.2`. Esfuerzo: medium.
Slug: `yala-ia-sin-categoria` · Sesión cola **S27** · al cerrar → **S28**.

## Encargo
Cumple **íntegramente** el brief per-card:

`~/Claude/tmp-frank/yala-ia-clasificacion-sin-categoria-oumm.md`

Léelo y ejecútalo tal cual (contexto, qué se pide, qué NO tocar, cómo se sabe que está bien). Este wrapper solo fija el hueco en la cola automática S0–S29.

## Qué NO tocar
Lo que diga el brief per-card. Además: no lanzar otras sesiones Yala; no tocar marketing/ ni Web/.

## Cómo se sabe que está bien
El criterio del brief per-card + PR a 2.2 cuando aplique.

## Pie pipeline
- Base: `origin/2.2`. Una sesión Yala a la vez. Rebase único antes del PR.
- Pipeline serial Yala: (1) limpiar sims muertos, DerivedData y cachés XcodeBuildMCP de worktrees cerrados; (2) build `xcodebuild -jobs 2` sin sim booteado; (3) bootear 1 sim; (4) tests; (5) apagar y limpiar.
- Al cerrar: Frank publica digest y lanza la siguiente según `~/Claude/tmp-frank/siguiente-activo.txt` y `~/Claude/tmp-frank/cola-2-2-orden-activo.txt`.
- marketing/ y Web/ = Lola. No relances otras sesiones Yala.


## Paso 0 — decisiones (resueltas en autónomo, bypass)

1. **Alcance de «Yala IA»**: builder del contexto (`FullFinancialContextBuilder`: gasto del mes, categorías, comercios, necesidades, historial, ingresos), `AnomalyDetectionCalculator`, `ChatTopicAreasLogic`, `ChatSuggestionsLLMService.monthSums`. Fuera: `InsightsCalculator` «Presupuestos en riesgo» (Observaciones, ticket propio `insights-budgets-at-risk-compute-spent-on-their-own`) y `ChatUnsignedExpenseRepairLogic` (deja fuera lo sin categoría a propósito).
2. **Nombre del trozo sin categoría en el contexto**: se queda «Other», el que ya usaba el builder. Es texto para el LLM, no UI.
3. **Bucket `uncategorized`**: pasa a contar solo GASTOS sin categoría (lo alimenta el gasto del mes). El ingreso sin categoría va a `income_categories` como «Other».
4. **Transferencias**: ya salen del contexto por `balanceAdjustmentType` (las dos patas lo llevan), así que la regla del signo no las alcanza.
5. **`tipo` de `buscar_movimientos`**: deja de existir `sin_categoria` (ya lo dice `categoria: null`); ingreso/gasto por `isIncomeOf`. De paso, una pata con `balance_adjustment_type = "transfer"` sale `transferencia` y no `ajuste_de_saldo`: es el mismo campo y la regla de la app (`TransactionDetailSheetLogic.kind`).
6. **Golden**: el builder del conector no porta categorías/anomalías (solo periodos y recurrentes), así que el golden gana `kinds` (el `tipo` por movimiento, calculado por la app) y el escenario de la tarjeta gana un ingreso sin categoría y una transferencia con la forma real.
7. **Tests**: suite nueva con un sin categoría de cada signo para builder, anomalías y sugerencias; el `tipo` por golden y `logic.test.ts`.
