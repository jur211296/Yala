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

No inventar causa.

Hipótesis del owner (no confirmada en código): Panel usa saldo live / moneda preferida (`LiveBalanceCalculator`); Distribución suma sin convertir.

## Superficies a mirar (cuando se implemente)

No editar estos archivos en este ticket de captura:

- Panel: `PanelView` / `PanelViewModel` / `LiveBalanceCalculator`
- Distribución: `CategoriesTabView` / `DistributionInsightLogic` / `DistributionPreviousPeriodCalculator`

## Acceptance Criteria

- [ ] Mismo período y mismos filtros: KPI de Balance en Panel y en Distribución usan la misma base de moneda (preferida) y el mismo número (o documentar por qué no, si hay decisión).
- [ ] Device-QA con cuenta multi-moneda.
- [ ] No inventar PASS.
