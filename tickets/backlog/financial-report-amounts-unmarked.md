---
id: financial-report-amounts-unmarked
status: backlog
priority: medium
area: "currency, fx"
created: 2026-09-09
source: hallazgo de camino en bridge-de-grupos-pierde-la-marca-de-sus-patas (2026-09-09)
updated: 2026-10-08
---

# La pantalla de Informes presenta 22 importes y ninguno puede llevar la marca

## Qué le pasa al usuario

El Panel dice que el gasto del mes es «≈ S/ 3.200». El usuario abre **Informes** para ver de dónde
sale, y ahí el mismo dinero —el neto del período, su comparativa con el anterior y todas las filas de
la tabla dinámica— aparece **sin marca**, como exacto. La pantalla a la que se va a buscar el detalle
es justo la que no puede decir que el número es aproximado.

## Dónde, medido el 2026-09-09

- `Yala/App/Views/Reports/` tiene **22 `AmountText`** y **cero** con `isEstimate:` de FX. El único
  `isEstimate` del árbol (`CashFlowAddLineSheet.swift:562`) es otra cosa: marca un pago programado de
  importe variable.
- `FinancialReportViewModel.swift:219,222` calcula `netFlowCurrent` (y el previo) con
  `adjustment.incomeAwarePreferred(_:)`, así que **el ajuste de grupos sí está cableado**: lo que
  falta es solo la señal de calidad de la tasa.
- `PivotTableCalculator` no acumula ninguna señal de calidad — cero menciones de «approximate».

Es la misma familia que [[fx-category-totals-unmarked]] y [[fx-per-bucket-approximate-signal-missing]],
y por el mismo motivo: el calculador suma importes ya convertidos y tira la calidad por el camino. La
diferencia es que aquí no es un desglose auxiliar sino la pantalla de informes entera.

## Qué habría que hacer

Acumular la magnitud aproximada junto al importe en `FinancialReportViewModel` (numerador) y en
`PivotTableCalculator` (por fila), medir con `ApproximateMarkThreshold` —nunca un OR— y pasar el
`isEstimate:` a los `AmountText`. Ojo con lo que ya está decidido en la familia: la señal va **por
lado**, el denominador de una resta es el número que se muestra, y la marca de un importe compuesto
la da `GroupBridgeStatsAdjustment.isApproximate(_:)`, no el flag de la fila.

## Acceptance Criteria

- [ ] El neto del período y su comparativa llevan la marca cuando la parte aproximada pesa.
- [ ] Las filas de la tabla dinámica también, o queda escrito en el código por qué una no debe.
- [ ] Ningún importe cambia: solo su marca.

## Relacionados

- [[fx-approximate-mark-missing-on-secondary-surfaces]] — la tanda que cubrió las otras pantallas; su
  tabla no nombraba Informes.
- [[fx-category-totals-unmarked]] · [[fx-per-bucket-approximate-signal-missing]] — misma familia.

## Medido en 2.1 (triage 2026-10-08)

- `Yala/App/Views/Reports/` sigue con 22 `AmountText(` y ninguno pasa `isEstimate:` de FX; el único `isEstimate` sigue siendo el de pago variable de `CashFlowAddLineSheet`.
- `FinancialReportViewModel` y `PivotTableCalculator` siguen sin ninguna mención de «approximate». El único commit posterior en esos ficheros (`133437905`, iPad) no toca la marca.
- Sube a `medium` por coherencia con `pie-header-total-unmarked` (medium en el triage del 2026-10-08): es el mismo número que el Panel sí marca, en la pantalla a la que se va a buscar el detalle.

Triage 2026-10-08: abierto · low → medium · Informes sigue sin poder marcar «≈»; enseña como exacto el mismo dinero que el Panel marca como aproximado, que es copy que miente sobre los datos.
