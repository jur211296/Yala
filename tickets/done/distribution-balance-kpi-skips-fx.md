---
id: distribution-balance-kpi-skips-fx
status: done
priority: high
area: statistics
created: 2026-08-26
updated: 2026-09-08
qa-status: passed
qa-date: 2026-09-08
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

## HOLD (superado el 2026-09-06)

El HOLD original decía «no inventar PASS, sin fix en este ticket». El fix ya está
(ver `## Implementación`). Lo que sigue vivo del HOLD es **la mitad del PASS**: no hay
números de aparato, así que el device-QA multi-moneda sigue pendiente del owner.

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

Implementado el 2026-09-06 — ver `## Implementación`.

## Acceptance Criteria

- [ ] Con métrica Balance (`natures` vacío), el KPI hero/header de Distribución == KPI de Balance del Panel (mismo `LiveBalanceCalculator` / TC actual). Panel sin cambios.
- [ ] Ingresos/Gastos en Distribución siguen siendo flujo del período.
- [ ] Device-QA con cuenta multi-moneda.
- [ ] No inventar PASS.

---

## Implementación (2026-09-06)

### Lo que se re-midió antes de tocar nada

El ticket es del 26-ago y se implementó el 6-sep. Las coordenadas se volvieron a medir en HEAD:
los siete ficheros del análisis siguen existiendo y los dos paths se confirmaron. **Una coordenada
había envejecido**: `displayedBalanceInDefaultCurrency` estaba citada en `:999-1015` y hoy vive en
`PanelViewModel.swift:1045-1062`.

Y una corrección al propio ticket, medida: **el Panel tiene DOS números de balance, no uno.**

| | Qué es | De dónde sale |
|---|---|---|
| KPI del widget de tendencia | El que el owner comparó | `TrendsCarouselWidget.swift:263-268` → `trendFinalBalance` |
| «Tienes X en N cuentas» | Panorama de cuentas | `displayedBalanceInDefaultCurrency` → `PanelTotalAccountsLogic` |

Se igualó al **primero**, y por un motivo comprobable: es el único que responde al selector de
período, igual que el hero de Distribución. El del panorama no cambia con el período, así que
igualar a ése habría puesto un número fijo bajo un menú de períodos.

### El hallazgo que cambió el diseño: el KPI del Panel tiene dos regímenes

`LiveBalanceCalculator.liveBalanceOverride` (`:117`) devuelve nil si `interval.end < Date.now`, y
entonces `finalBalance` cae a `rawPoints.last?.value ?? 0` (`TrendDataProcessor.swift:251`):

1. **Período que cubre hoy** (`.thisMonth`, `.thisWeek`, `.allTime`…) → stock vivo al TC ACTUAL.
2. **Período cerrado** (`.lastMonth`, `.lastYear`) → saldo histórico al cierre, con los snapshots
   `amountInPreferredCurrency`.
3. **Sin transacciones en el período** → 0 (early-return de `processTrendData`, `:200-212`).

Poner el stock vivo incondicional —la lectura literal de «igualar Balance a stock»— habría enseñado
**el saldo de HOY bajo una etiqueta que dice "Mes pasado"**. Por eso se replican los tres.

### Qué se hizo

- **`Yala/App/Logic/Calculators/BalanceKPICalculator.swift` (nuevo).** SSOT del número. No
  reimplementa ninguna regla: delega en los mismos `LiveBalanceCalculator` y `TrendDataProcessor`
  que usa el Panel. Si mañana cambia `finalBalance`, este KPI cambia con él en vez de divergir —
  que es exactamente como el número se separó la primera vez.
- **`StatisticsViewModel.balanceKPI(...)`.** Resuelve los insumos replicando
  `PanelViewModel.balanceTransactions`: sin recorte de fecha, sin `BridgedTransactionFilter`,
  cuentas pre-filtradas por `eligibleAccountIDs`.
- **`CategoriesTabView`.** El hero usa ese número cuando la métrica es Balance. `isBalanceMode` se
  deriva **en la vista** con la regla del Panel (`enforceTrendLock`) en vez de leer
  `viewModel.selectedMetric`, porque esa propiedad solo se refresca en el camino de Tendencias
  (`enforceMetricLock`, `StatisticsViewModel.swift:44`) y en esta pestaña llegaría rancia.
### Lo que la review adversarial cazó de mi propio cambio

Tres lentes independientes con refutación por hallazgo. **Seis defectos que yo introducía**, ninguno
visible en mis tests en verde:

1. El hero se mostraba solo si `totalAmount > 0`. Con el saldo ahí, un **saldo negativo o cero
   escondía el hero entero** — justo cuando el usuario más quiere verlo.
2. **Sin movimientos en el período el hero decía «0»** a alguien con saldo, solo por abrir un mes
   vacío. El 0 del Panel es ambiguo (vale igual «no hay datos» que «el saldo es cero»); al Panel no
   le estorba porque oculta el KPI, pero aquí había que distinguirlo → `Result.hasDataInPeriod`.
3. El hero pintaba **«0» y rodaba los dígitos** antes del primer cálculo: la vista se destruye al
   cambiar de pestaña, así que el body corre antes del `onAppear` → `@State` opcional.
4. **Apagar «solo gastos» no recalculaba.** `isBalanceMode` cuelga de ese flag y no tenía observador;
   un `didSet` de `SessionState` lo salvaba de rebote, pero **no** cuando los chips ya estaban
   vacíos — que es el arranque de un usuario «solo gastos». Es la contrapartida que
   `.claude/rules/swiftui-ds.md` manda comprobar al precalcular.
5. **Con los DOS chips marcados volvía al flujo** — el bug de origen, en la rama que no había
   cubierto. El Panel conserva `.balance` ahí (`else { return }`), y tiene sentido: marcar ingresos
   y gastos no filtra nada, igual que no marcar ninguno.
6. El **`adjustment` de gastos de grupo no viajaba** al processor. El Panel sí lo pasa, y su
   `guard !isSuppressed` corre antes de fijar min/max, o sea que afecta al último bucket del saldo
   en períodos cerrados.

Y uno de diseño, corregido con la regla que la propia pantalla ya declara: con un **filtro
dimensional** activo (categoría/subcategoría/necesidad) el hero habría mostrado «el neto histórico
de esa categoría» bajo una etiqueta que dice «Este mes». `enforceMetricLock` ya usa
`!hasCategoryFilters` para decidir la métrica de esta pantalla, así que se reusa: con filtro
dimensional el hero vuelve al flujo, que es lo que el gráfico de debajo enseña.

### Rendimiento, medido

El processor construía la curva entera **y la descartaba** — `finalBalance` sale del anchor. Con
5.475 movimientos (3 años): «Este mes» 21,1 → **14,9 ms**; «Todo» 42,8 → **14,8 ms**. El atajo es
una condición duplicada, así que la suite **compara atajo contra cálculo completo en los 8
períodos** más los bordes.

Una premisa mía que resultó **falsa** y estaba escrita en un comentario: creí que esto corría por
tecla del buscador. No — el campo de esta pantalla es un `@State` local de `RecordsFiltersView` que
solo se vuelca al ViewModel al pulsar «Aplicar» (`:41`, `:511`, `:685`). Dos de las tres lentes se
contradijeron en esto y hubo que medirlo.

### Lo que NO se tocó, y por qué

- **El header del pie**, pese a que el ticket lo nombraba junto al hero. `CategoriesPieWidget` **se
  comparte con el Panel** (`PanelWidgetSection.swift:226`), así que cambiarlo habría tocado el Panel
  — que es justo lo que la decisión 3 prohíbe. Y su header es por construcción
  `categories.reduce(+)` (`:40-42`): ponerle un saldo lo dejaría sin cuadrar con sus propias tajadas.
- **El Panel**, en nada.
- **Ingresos/Gastos en Distribución**, que siguen siendo flujo del período.

### Verificación

- `unit:YalaTests/BalanceKPIParityTests` — **16 tests, todos verdes.** Cubren la paridad
  Distribución↔Panel en período vivo y cerrado, que el TC actual ≠ el snapshot histórico, que el KPI
  no es el flujo de `TopSpendingCategoriesCalculator`, el saldo negativo, el arrastre de lo anterior
  al período, y el contrato de que el camino histórico no filtra cuentas por sí mismo.
- **Control positivo hecho** (un test verde puede no estar probando nada): con el mutante
  `liveBalanceOverride: nil` compilado, 4 tests se ponen rojos, incluido el de paridad — 4000 contra
  4500. Revertido con `cp`, no con `git checkout`.
- El caso central es **multi-moneda con el TC actual distinto del histórico**. Con un solo tipo de
  cambio los dos caminos dan el mismo número y el test pasaría sin comprobar nada.

## Lo que queda para el owner

### 1. Device-QA multi-moneda — sin esto no hay PASS

No se declara PASS: no hay números de aparato. Lo que hay que mirar, con cuenta multi-moneda:

1. Panel → widget de tendencia con métrica **Balance** y período **Este mes**. Anotar la cifra.
2. Estadísticas → pestaña **Distribución**, mismo período, sin chips de naturaleza. **Debe ser la
   misma cifra.**
3. Cambiar a **Mes pasado** en las dos: deben seguir coincidiendo, y **no** deben mostrar el saldo
   de hoy.
4. Chips **Ingresos** y **Gastos** en Distribución: el hero debe seguir siendo el flujo del período.

### 2. Una decisión de producto que este cambio destapa

`TrendsTabView.swift:1193-1203` documenta **explícitamente** que el hero de Estadísticas usa el
agregado del período *«para coherencia cross-tab»*. Este cambio rompe esa regla en una de las cuatro
pestañas.

En Estadísticas, «Balance» ahora significa **dos cosas distintas según la pestaña**:

| Pestaña | Qué muestra su hero |
|---|---|
| **Distribución** | Saldo de las cuentas (tras este cambio) |
| Tendencias | `summary.netBalance` — ingresos − gastos del período (`TrendsTabView.swift:1199`) |
| Insights | `summary.netBalance` — lo mismo (`InsightsTabView.swift:207`) |
| Registros | `recordsSummary.balance` — neto de lo filtrado (`RecordsTabView.swift:148`) |

Las tres últimas son **flujo del período**; Distribución pasa a ser **stock**. Es consecuencia
directa de la decisión del 26-ago (igualar Distribución al Panel), y no se ha ampliado el alcance a
las otras pestañas porque eso es otro objeto y otra decisión. Queda anotado para que se decida a
sabiendas, no por omisión. **Decidido el 2026-09-06 en [[hero-estadisticas-stock-vs-flujo-entre-pestanas]]:
se etiqueta la cifra en las cuatro pestañas; ningún cálculo cambia.**

### 3. Límite conocido, no corregido

Con **dos o más cuentas seleccionadas** el número puede no cuadrar con el Panel: el Panel colapsa la
selección a `selectedAccountIDs.first` (`PanelViewModel.swift:291`) mientras Estadísticas respeta el
set completo. Es una asimetría **preexistente del Panel** y arreglarla exigía tocarlo.

---

## QA Visual · 2026-09-08

**Veredicto: PASS.** iPhone 17 Pro (iOS 26.5), `Yala Dev`, seed `realista`. Los dos números se
leyeron **en la misma sesión de la app** —sin relanzar entre medias— porque con `-uitest-reset` el
corpus se regenera y comparar dos lanzamientos sería comparar dos conjuntos de datos distintos.

### Lo que se vio

| Período | Panel · KPI Balance del widget de tendencia | Estadísticas · Distribución · hero | ¿Coinciden? |
|---|---|---|---|
| **Este mes** | S/ **+73.526,45** | S/ **73.526,45** — «Saldo de cuentas» | **Sí** |
| **Mes pasado** | S/ **+73.443,30** | S/ **73.443,30** — «Saldo de cuentas» | **Sí** |

Y los **dos regímenes** que la implementación describe quedan visibles: el período que cubre hoy da
el stock vivo (73.526,45) y el período **cerrado** da el saldo histórico al cierre (73.443,30). O
sea que Mes pasado **no muestra el saldo de hoy**, que era la mitad fina del criterio.

**Ingresos/Gastos siguen siendo flujo** (AC 2), y también cuadran entre las dos pantallas:
S/ 3.905,00 de gasto en «Este mes» y S/ 8.132,00 en «Mes pasado», el mismo número en el Panel y en
el «Análisis del gasto» de Distribución.

**El panorama no se movió** con el selector de período («Tienes ≈ S/ 73.526,45 en 2 cuentas» en los
dos), que es justo el motivo por el que la implementación igualó el hero al KPI del widget y no al
panorama. Se confirma en pantalla la decisión de diseño.

### El AC de multi-moneda: cumplido, y la premisa que lo bloqueaba era falsa

El ticket pedía «Device-QA con cuenta multi-moneda» y el HOLD decía que sin números de aparato no
había PASS. **El seed `realista` ya es multi-moneda**: `DevSeedAccounts.swift:22-36` crea la cuenta
principal en **PEN** y una de ahorros en **USD**, y se vieron las dos en pantalla (S/ -33.254,00 y
$ 30.079,00), con `DevSeedExchangeRates` sembrando ~730 filas diarias de tasa. La condición que el
ticket daba por imposible en simulador estaba sembrada desde el principio.

### Capturas

- `qa-distribution-balance-01-estemes-distribucion-20260908-211750.png`
- `qa-distribution-balance-02-mespasado-panel-20260908-211829.png`

### Lo que este QA no cubre

Los **números exactos del aparato del owner** (TF 2.1 build 12) siguen sin conocerse, y con ellos la
confirmación de que lo que él vio en agosto era este mismo caso. Lo verificado aquí es que hoy los
dos KPI coinciden en los dos regímenes con un corpus multi-moneda; no que el corpus del owner fuera
idéntico.
