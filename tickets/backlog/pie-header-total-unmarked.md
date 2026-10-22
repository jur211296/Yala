---
id: pie-header-total-unmarked
status: backlog
priority: medium
area: "currency, ui"
created: 2026-09-09
updated: 2026-10-08
source: device-QA de fx-approximate-mark-missing-on-secondary-surfaces (2026-09-09)
---

# El total de «Análisis del gasto» no marca, y es el mismo número que el Panel sí marca

## Qué le pasa al usuario

Estadísticas → **Distribución** → «Análisis del gasto» encabeza los pies con el total del período y
su comparativa. Medido en simulador el 2026-09-09 (iPhone 17 Pro, iOS 26.5, `Yala Dev`,
`-uitest -uitest-reset -uitest-skip-onboarding -uitest-seed realista -uitest-seed-foreign-account JPY`,
«Este mes»):

| dónde | lo que se ve |
|---|---|
| Panel, «Gastos» | **`≈ S/ 4,673.00`** |
| Estadísticas → Resumen, chip de gasto | **`≈ S/ 4,673.00`** |
| Registros, chip «Gasto» | **`≈ S/ 4,673.00`** |
| Estadísticas → **Distribución**, «Análisis del gasto» | **`S/ 4,673.00`** ← sin marca |

Captura: `qa/evidencia-fx-20260909/05-distribucion-analisis-gasto-sin-marca.png`.

Es **el mismo número, al céntimo, en la misma app y con el mismo filtro**, declarado aproximado en
tres pantallas y exacto en la cuarta. Y la cuarta es justamente a la que se va a buscar el detalle
del número marcado.

## Dónde, medido

- `Yala/App/Views/Panel/PieChartVariationHeader.swift:73` — `AmountText(value: totalAmount, …)`,
  **sin** `isEstimate:`. El «vs» del período anterior, en `:87`, tampoco (ése está declarado fuera
  por [[fx-previous-period-amounts-unmarked]]).
- Camino sin comparativa, mismo defecto: `CategoriesPieWidget.swift:545`.
- Lo heredan `SubcategoriesPieWidget.swift:497` y `TagsPieWidget.swift:456`, que usan el mismo
  header (cero `isEstimate` en ambos ficheros).
- El número: `CategoriesPieWidget.swift:40-42`,
  `totalExpense = categories.reduce(0) { $0 + $1.amount }`, sobre el array que produce
  `TopSpendingCategoriesCalculator` (`CategoriesTabView.swift:1362-1369`).
- No hay señal que cablear: `CategorySpendingSummary` (`SharedModels.swift:400-406`) sólo lleva
  `category/amount/percentage/previousAmount`.

## Corrección a la premisa de `fx-category-totals-unmarked`

[[fx-category-totals-unmarked]] justifica su prioridad `low` diciendo (su :36-38) que «el total que
agrega estas líneas **SÍ avisa** desde el 2026-09-09». **Medido: no avisa.** El total del header del
pie es justo el que falta.

Y no es el mismo trabajo, por eso va aparte:

- Aquel ticket pide marca **por fila** del desglose, con `ApproximateMarkThreshold` sobre las
  transacciones de esa categoría, y su motivo para no hacerlo ya es válido: la incertidumbre puede
  estar entera en otra categoría.
- Éste pide marcar **un agregado del período** que ya tiene su señal calculada tres veces en la app.
  Es el trabajo barato, y es el que quita la contradicción que el usuario ve.

Cuando se cierre éste, la frase de aquél queda por fin cierta y su `low` justificado.

## Criterio de hecho (AC)

- [ ] El total de «Análisis del gasto» lleva la marca cuando el gasto del período la lleva. Las
      tajadas y las filas del desglose **siguen sin marca** ([[fx-category-totals-unmarked]]).
- [ ] Vale para los tres pies (categorías, subcategorías, etiquetas), que comparten header.
- [ ] Corregida la premisa de [[fx-category-totals-unmarked]] cuando este ticket cierre.
- [ ] Un test que falle si el header pierde el cableado.

## Relacionados

- [[fx-approximate-mark-missing-on-secondary-surfaces]] — la tanda que cubrió las otras superficies.
- [[fx-category-totals-unmarked]] — las filas del desglose; premisa corregida arriba.
- [[weekday-bar-daily-average-unmarked]] — el otro agregado de período sin marca, hallado a la vez.

## Medido en 2.1 (triage 2026-10-08)

- Sigue. `PieChartVariationHeader.swift:73` y `:87` llaman a `AmountText` sin `isEstimate:`.
- `CategoriesPieWidget.swift` (header en `:509`, rama sin comparativa en `:545`), `SubcategoriesPieWidget.swift:497` y `TagsPieWidget.swift:456` tienen cero `isEstimate`.
- No hay commits sobre estos ficheros desde el 2026-09-09.

Triage 2026-10-08: abierto · medium → medium · `PieChartVariationHeader.swift:73` sigue sin `isEstimate:` y los tres pies no tienen ni un `isEstimate`.
