---
id: distribution-balance-kpi-skips-fx
status: backlog
priority: high
area: statistics
created: 2026-08-26
updated: 2026-08-26
---

# KPI de Balance en Distribución no aplica la transformación de moneda que sí usa el Panel

## Reporte

Owner, 2026-08-26. Jurgen. TF 2.1 build 12. Cuenta día a día, multi-moneda.

La misma gráfica de Balance muestra KPI distintos en Panel y en Distribución (Estadísticas → tab Distribución / CategoriesTabView).

El owner indica que Distribución no está tomando en cuenta la transformación entre monedas que el Panel sí aplica.

Números exactos de los dos KPI: desconocidos (pendiente owner).

Hallazgo durante device-QA.

## Distinto de

- `trends-comparison-kpi-vs-curve` — KPI vs curva en Comparativa.
- `records-standalone-amount-discrepancy` — clasificación ingreso/gasto.
- `cloud-fx-rates-blob-two-faces` — decode del blob rates.
- `fx-pnl-education-card` — idea de card P&L.

## HOLD

No inventar PASS. Status sigue `backlog`. Sin fix en este ticket.

## Causa (código)

Investigación 2026-08-26 (solo lectura). Números de device-QA siguen TBD.

**Hipótesis del owner, dos mitades:**

1. Panel usa `LiveBalanceCalculator` / moneda preferida — **confirmada**.
2. Distribución suma montos nativos sin convertir — **refutada**.

**Primera divergencia** (mismo `SessionState.selectedTransactionNatures` vacío = métrica Balance en Panel):

| | Panel (gráfica/card Balance) | Distribución (hero + header del pie) |
|---|---|---|
| Qué número | Saldo vivo (stock) | Gasto del período (flujo). `natures == []` → expense-only |
| FX | Buckets nativos × **TC actual** (`convertWithLatestRate`) | Snapshot histórico `amountInPreferredCurrency` o `convert(on: tx.date)` |
| Calculator | `LiveBalanceCalculator` | `TopSpendingCategoriesCalculator` |

Distribución **sí convierte**, pero no con la base live del Panel. El insight (`.balanced`) no es un KPI de saldo.

### Path 1 — Panel, KPI de la gráfica Balance

1. `Yala/App/Views/Panel/TrendsCarouselWidget.swift:263-268` `trendTotalForCurrentMetric` — `.balance` → `viewModel.trendFinalBalance`.
2. `Yala/App/ViewModels/PanelViewModel.swift:1170-1191` — `LiveBalanceCalculator.liveBalanceOverride` + `TrendDataProcessor.processTrendData` → `result.finalBalance`.
3. `Yala/Services/TrendDataProcessor.swift:251` — `finalBalance = liveAnchor?.value ?? rawPoints.last?.value ?? 0`.
4. `Yala/App/Logic/Calculators/LiveBalanceCalculator.swift:80-95` — suma `tx.amount` nativo por `currencyCode`, convierte con `converter.convertWithLatestRate`.
5. El panorama usa la misma base: `PanelViewModel.displayedBalanceInDefaultCurrency` (`:999-1015`) → `LiveBalanceCalculator.liveBalance`.

La curva histórica del trend sí usa `amountInPreferredCurrency` (`TrendDataProcessor.swift:87,297`). El KPI de Balance, cuando el período cubre hoy, lo pisa el live override.

### Path 2 — Estadísticas → Distribución

1. Hero: `Yala/App/Views/Statistics/CategoriesTabView.swift:294-296` `AmountText(value: totalAmount)`.
2. `CategoriesTabView.calculateData` `:1282-1295` — `naturesFilter` nil si natures vacío; `TopSpendingCategoriesCalculator.calculateTopSpending`; `totalAmount = sum(amount)`.
3. `Yala/App/Logic/Calculators/TopSpendingCategoriesCalculator.swift:30` — `naturesToInclude = transactionNatures ?? [.expense]`.
4. Misma calculadora `:66-75` — si `preferredCurrencyCode == currencyCode` usa `adjustment.amountInPreferredCurrency`; si no, `converter.convert(..., on: transaction.date)`.
5. Header del pie: `Yala/App/Views/Panel/CategoriesPieWidget.swift:40-42` y `:545-548` — `totalExpense` / `filteredTotalExpense` = suma de esos `amount` ya convertidos.
6. `DistributionInsightLogic` no produce monto. `DistributionPreviousPeriodCalculator.previousCategoryTotal` (`:72-78`) es el previo, misma calculadora.

`StatisticsViewModel.currentBalance` (`:555-563`) sí llama `LiveBalanceCalculator`. `CategoriesTabView` no lo lee.

### Qué no es

No es “Distribución omite FX”. No es `trends-comparison-kpi-vs-curve` (KPI vs curva en Comparativa). Sin números de device-QA no hay PASS.

## Decisión (2026-08-26)

Jurgen, device-QA TF 2.1 build 12:

1. El fix previo de Comparativa (`trends-comparison-kpi-vs-curve`, MTD-vs-MTD) se mantiene. Device-QA en Tendencias → Comparativa (Este mes, 3 métricas) OK. El widget Comparativa del Panel sigue pendiente. **No cerrar** ese ticket.
2. No mantener stock vs flujo para el KPI de Balance. No igualar todo a flujo. Igualar Balance a **stock**.
3. No tocar Panel. El stock vivo del Panel (`LiveBalanceCalculator`, TC actual) es la fuente de verdad del Balance.

Lectura acotada de Frank (no son palabras extra de Jurgen): solo el KPI de Balance en Distribución (hero / header del pie cuando `natures` está vacío / métrica Balance) pasa a ser el mismo número de stock vivo que el Panel. Ingresos/Gastos en Distribución siguen siendo flujo del período (un pie de gasto no tiene sentido de otro modo). No reescribir el pie como participaciones de stock por cuenta.

Status sigue `backlog`. Sin implementación en este ticket.

## Acceptance Criteria

- [ ] Con métrica Balance (`natures` vacío), el KPI hero/header de Distribución == KPI de Balance del Panel (mismo `LiveBalanceCalculator` / TC actual). Panel sin cambios.
- [ ] Ingresos/Gastos en Distribución siguen siendo flujo del período.
- [ ] Device-QA con cuenta multi-moneda.
- [ ] No inventar PASS.
