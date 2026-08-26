---
id: records-standalone-amount-discrepancy
status: backlog
priority: medium
created: 2026-04-30
updated: 2026-08-26
source: YalaWiki/Backlog/p20-13_records-standalone-discrepancy.md
---


# Bug: RecordsStandalone muestra montos distintos a CashFlow/Insights con el mismo filtro

## Descripcion

Con el filtro global "Este mes" del Panel y sin filtros adicionales, **cuatro vistas** de la app reportan ingresos/egresos diferentes para el mismo período. Caso reportado por el usuario el 2026-04-30:

| Vista | Ingresos | Egresos |
|---|---|---|
| Hero del Panel (chip/KPI) | 11356 | 7542 ← cubierto por p20-12 (ya resuelto) |
| CashFlow widget | 11356 | 7063 |
| Insights resumen | 11356 | 7063 |
| **RecordsStandalone** | **11596** (+240) | **7303** (+240) |

El bug del Hero (+479 en egresos) fue cubierto por p20-12 (ticket ya cerrado/archivado — no existe como archivo en `Backlog/` a fecha 2026-07-01). Este ticket trata la discrepancia restante: **RecordsStandalone vs CashFlow/Insights** = +240 en ambos lados, y **por qué +240 en ambos simultáneamente** es la pista central: no es una TX que "aparece de más" en un solo pool (eso movería income O expense, no ambos por el mismo monto), sino una o más TX que **cruzan de bucket** — el pool de transacciones es el mismo en ambos lados, pero la clasificación income/expense de esas TX difiere entre calculators. Una TX de monto `X` que un lado cuenta como income y el otro como expense produce +X en el income de un lado y +X en el expense del otro (o viceversa) — exactamente el patrón "+240 en ambos" reportado, no "+240 en un total desalineado".

**Nota de alcance**: el análisis debajo confirma que esto no es exclusivo de "RecordsStandalone" — el mecanismo vive en `RecordsViewModel.calculateSummary()`, consumido por `RecordsTabView.swift`, que a su vez es la vista compartida tanto por la pestaña "Registros" dentro de Estadísticas como por `RecordsStandaloneView` (navegación desde "Más"). El bug se manifiesta en **cualquier lugar que muestre ese hero**, no solo en el standalone.

## Causa raiz confirmada

Dos calculators clasifican la MISMA transacción con criterios distintos:

**Lado "correcto" (CashFlow / Insights) — clasifica por categoría:**

`Yala/App/Logic/Calculators/HeroBucketsCalculator.swift:60-64` (usado por el Hero, ya resuelto en p20-12, pero mismo patrón):
```swift
let amount = abs(tx.amountInPreferredCurrency)
let isIncome = tx.category?.isIncome == true
```

`Yala/App/Logic/Calculators/CashFlowCalculator.swift:54,63,76` (usado por el widget CashFlow del Panel — confirmado que `PanelViewModel.calculateCashFlowWidget:1743` llama `CashFlowCalculator.calculateCashFlow(transactions: context.expenseFilteredTransactions, ...)`):
```swift
guard let category = tx.category else { continue }   // línea 54 — EXCLUYE TX sin categoría
guard tx.balanceAdjustmentType == nil else { continue }
...
val = tx.amountInPreferredCurrency   // línea 63 — signo tal cual, pero...
let isIncome = category.isIncome     // línea 76 — LA CATEGORÍA decide el bucket, no el signo de `val`
```

`Yala/App/Logic/Calculators/InsightsCalculator.swift:468,579,640` — mismo patrón, ej. línea 579:
```swift
let expenseTxns = allTransactions.filter { $0.category?.isIncome == false && $0.balanceAdjustmentType == nil }
```

**Lado "divergente" (RecordsViewModel) — clasifica por signo literal:**

`Yala/App/ViewModels/RecordsViewModel.swift:289-314`, función `calculateSummary()`:
```swift
private func calculateSummary() {
    var income: Double = 0
    var expense: Double = 0

    for group in groupedRecords {
        for record in group.records {
            guard let account = record.account else { continue }
            if account.excludeFromStatistics { continue }

            // Exclude balance adjustments and transfers from summary
            let isBalanceAdjustment = record.balanceAdjustmentType != nil
            if !isBalanceAdjustment {
                let amount = record.amountInPreferredCurrency
                if amount > 0 {                    // línea 301 — SOLO mira el signo
                    income += amount
                } else {
                    expense += abs(amount)
                }
            }
        }
    }

    let newSummary = (income - expense, income, expense)
    if newSummary != recordsSummary { recordsSummary = newSummary }
}
```

**Segunda divergencia independiente (guard de categoría)**: `CashFlowCalculator.swift:54` excluye explícitamente cualquier TX con `category == nil` ("Must have a category (excludes Transfers)"). `RecordsViewModel.calculateSummary()` **no tiene ese guard** — solo excluye por `excludeFromStatistics` de la cuenta y `balanceAdjustmentType != nil`. Cualquier TX con `category == nil` pero sin `balanceAdjustmentType` seteado contaría en Records y no en CashFlow/Insights. En la práctica esto es menos probable que el mecanismo de signo (la mayoría de flujos de creación siempre asignan `category`), pero es una discrepancia estructural real y vale la pena cerrarla en el mismo fix.

### Invariante real esperada — HAY UNA REGLA CANÓNICA YA DOCUMENTADA EN EL CÓDIGO

No es solo una inferencia: existe un doc-comment explícito que declara la regla del proyecto, en `Yala/App/Logic/TransactionDetailSheetLogic.swift:34-41`:
```swift
/// Clasificación visual de la TX. Transfer gana siempre; si no, la
/// categoría decide y el signo del monto es el fallback — paridad exacta
/// con RecordRowView.amountColor para que el hero no contradiga a la row.
static func kind(isTransfer: Bool, categoryIsIncome: Bool?, amount: Double) -> Kind {
    if isTransfer { return .transfer }
    let isIncome = categoryIsIncome ?? (amount >= 0)
    return isIncome ? .income : .expense
}
```
Y su gemelo real en la fila de Records, `Yala/App/Views/Records/Components/RecordRowView.swift:262-265`:
```swift
private var amountColor: Color {
    let isIncome = record.category?.isIncome ?? (record.amount >= 0)
    return isIncome ? Color.electricIndigo : Color.hotPink
}
```
Y en `Yala/App/Logic/Calculators/PivotTableCalculator.swift:173`, mismo patrón exacto: `let isIncome = tx.category?.isIncome ?? (tx.amount > 0)`.

**La regla canónica es: `category.isIncome` es la fuente de verdad primaria; el signo de `amount` es el fallback ÚNICAMENTE para cuando `category == nil`.** No es "ambos pesan igual", ni "el signo gana" — es un `??` de Swift, precedencia estricta. `RecordsViewModel.calculateSummary()` viola esto por completo: ni siquiera mira `category`, usa solo el signo incluso cuando la categoría existe.

Reforzado por el flujo de creación normal:
- `Yala/App/ViewModels/NewTransactionViewModel.swift:356-366` (prefill del form): al elegir una subcategoría, el tipo de transacción (que determina el signo) se deriva de la categoría, no viceversa (`if subcategory.safeCategory.isIncome { transactionType = .income } else { transactionType = .expense }`). El picker de subcategorías además solo ofrece subcategorías coherentes con el `transactionType` activo (`SubcategorySelectorViewModel`), por lo que en el flujo normal de creación individual la divergencia signo/categoría no puede originarse — solo se produce por los mecanismos 1 y 2 de abajo, o por edición directa.
- `Yala/App/Models/TransactionFormModels.swift:49-55` (`TransactionType.isNegative`) + `NewTransactionViewModel.swift:610`: `let finalAmount = transactionType.isNegative ? -amount : amount`.
- **Transferencias no son la causa**: `NewTransactionViewModel.saveTransfer()` (líneas 683-772) asigna `category`/`subcategory` de sistema y signo de forma coherente por construcción (`outAmount = -amount` con `outflowSubcategory` de `isIncome==false`; `inAmount` positivo con `inflowSubcategory` de `isIncome==true`), y **ambas piernas llevan `balanceAdjustmentType = TransactionItem.adjustmentTypeTransfer`** (líneas 741, 756) — por lo que ya son excluidas por igual en `HeroBucketsCalculator` (línea 55), `CashFlowCalculator` (línea 55), `InsightsCalculator` (filtro `balanceAdjustmentType == nil`), `TrendDataProcessor`/`ReportNotificationService` (mismo guard) Y en `RecordsViewModel.calculateSummary` (línea 299-300). Las transferencias quedan simétricamente fuera de todos los lados — no explican el +240.

**Caso legítimo adicional donde signo y categoría divergen a propósito (no bug de datos): ajuste de saldo inicial.** `Services/InitialBalanceService.swift` asigna siempre la subcategoría de sistema `"Ajuste de saldo"` (bajo la categoría "Otros", `isIncome: false`), pero el `amount`/`adjustmentAmount` puede ser positivo o negativo según si el ajuste aumenta o disminuye el saldo de la cuenta — un ajuste que sube el saldo en S/5000 queda con `amount > 0` y `category.isIncome == false`. Este caso normalmente no es visible porque **todos** los calculators relevantes (incluido `RecordsViewModel.calculateSummary`) ya excluyen por `balanceAdjustmentType != nil` — es el mismo guard que protege contra las transferencias. Solo sería un problema en un consumidor que omitiera ese guard.

### Dos mecanismos reales confirmados que rompen la invariante (con datos de usuario reales, no solo teóricos)

**Mecanismo 1 — Import CSV/XLSX, modo "solo categorías existentes":**

`Yala/Utils/TransactionCSVImportService.swift` tiene el mismo patrón duplicado en al menos 2 entry points (líneas 466-529 y 1325-1373). Ejemplo (líneas 466-495):
```swift
// Supuesto: montos >= 0 se consideran ingresos, < 0 gastos.
let isIncome = decimalAmount >= 0
...
} else {
    // Modo estricto: solo se permiten categorías existentes.
    // Busca por nombre sin filtrar por isIncome para soportar categorías
    // "neutrales" como "Otros" que contienen transferencias.
    let categoryDescriptor = FetchDescriptor<Category>(
        predicate: #Predicate { cat in cat.name == trimmedCategory }
    )
    ...
    category = existingCategory   // se usa TAL CUAL, sin verificar isIncome vs signo del archivo
}
```
El draft resultante (`ParsedTransactionDraft`) lleva `amount: decimalAmount` (signo del archivo importado) y `category: category` (resuelta solo por nombre) de forma **completamente independiente** — se materializan juntos en el `TransactionItem` final (ej. línea 1490-1497) sin ninguna reconciliación cruzada. Si el usuario mapea una fila con monto negativo a una categoría existente cuyo nombre coincide con una categoría `isIncome == true` en su catálogo (o viceversa), la TX resultante queda con signo y categoría contradictorios.

**Incluso en modo "crear categorías nuevas"** (`allowCreatingNewCategories = true`), `Yala/Utils/CategoryImportHelper.swift:36-97` (`fetchOrCreateCategory`) reusa cualquier categoría existente con el mismo nombre **sin filtrar por `isIncome`** — el comentario del propio código lo confirma como diseño intencional (líneas 45-47): "Buscamos una categoría ya existente con el mismo nombre (sin filtrar por isIncome). Esto permite que categorías 'neutrales' como 'Otros' funcionen para transferencias que tienen montos positivos (entrada) y negativos (salida)." El efecto colateral es que categorías normales homónimas (no solo "Otros") pueden quedar con `isIncome` distinto al signo del monto importado.

**Mecanismo 2 — Bulk-edit de subcategoría en Records:**

`Yala/App/ViewModels/RecordsViewModel.swift:519-537` (`bulkUpdateSubcategory`):
```swift
func bulkUpdateSubcategory(_ subcategory: Subcategory, context: ModelContext) {
    let transactions = getSelectedTransactions(context: context)
    if transactions.contains(where: { $0.balanceAdjustmentType == TransactionItem.adjustmentTypeTransfer }) {
        bulkUpdateError = L10n.BulkEdit.cannotEditTransferSubcategory
        return
    }
    for transaction in transactions {
        transaction.subcategory = subcategory
        transaction.category = subcategory.safeCategory   // cambia la categoría...
    }                                                       // ...pero NUNCA toca transaction.amount
    ...
}
```
A diferencia del form individual (que reconcilia `transactionType`/signo cuando cambia la subcategoría elegida — ver invariante arriba), el bulk-edit permite reasignar la subcategoría de N transacciones seleccionadas sin ajustar el signo del monto. Si el usuario selecciona TX de gasto (`amount < 0`) y las reasigna en bulk a una subcategoría de ingreso (o viceversa), el resultado es exactamente `amount` con signo contrario a `category.isIncome`.

Nota menor: `RecordsViewModel.bulkUpdateAmount()` (líneas 652-683) hace lo inverso — preserva el signo previo del monto (`transaction.amount < 0 ? -abs(amount) : abs(amount)`) sin tocar la categoría. Esto por sí solo no crea divergencia nueva (preserva lo que ya había), pero confirma que en todo el código de bulk-edit no existe ningún punto que valide la coherencia signo↔categoría tras una edición.

## Alcance real (ampliado 2026-07-01 — mapeo exhaustivo de todo el codebase)

Un segundo pase de investigación (sub-agente en background, ~1h de trabajo) mapeó **todos** los sitios de clasificación income/expense del proyecto, no solo los relevantes al síntoma original. Confirma que el problema es sistémico, no acotado a Records — hay ~14 sitios con **Lógica A pura**, ~5 con **Lógica B pura**, ~4-5 con **"A con fallback"** (2 variantes distintas de fallback, ver hallazgo nuevo abajo), y ~6 con **Lógica C** (sobre `ScheduledPayment.transactionType`, fuente de verdad distinta — no comparable directo con `TransactionItem.category`).

| Archivo:línea | Lógica | Snippet clave | Feature/vista que lo consume |
|---|---|---|---|
| `HeroBucketsCalculator.swift:60-64` | A (categoría, sin fallback) | `isIncome = tx.category?.isIncome == true` | Hero del Panel (chip/KPI) — ya resuelto por p20-12 con este mismo patrón |
| `CashFlowCalculator.swift:54,76` | A (categoría) + excluye `category == nil` | `guard let category = tx.category else { continue }` / `let isIncome = category.isIncome` | **CashFlow widget del Panel** (`PanelViewModel.swift:1742-1749`) |
| `InsightsCalculator.swift:468,579,640` | A (categoría, sin fallback) | `$0.category?.isIncome == false` | Resumen de Insights del Panel, presupuestos en riesgo, distribución por Necesidad |
| `SankeyFlowCalculator.swift:67,75` | A pura | `if category.isIncome { … } else { … }` | Diagrama Sankey (tab Distribución) |
| `TopSpendingCategoriesCalculator.swift:37,40` / `TopSubcategoriesCalculator.swift:43,49` / `TagSpendingCalculator.swift:35,37` | A pura | `category.isIncome ? .income : .expense` | Pie charts de Categorías/Subcategorías/Etiquetas |
| `WeekdaySpendingCalculator.swift:60` | A pura | `guard ..., !category.isIncome else { continue }` | Chart "gasto por día de semana" |
| `PanelViewModel.swift:1019,1786,2164,2857` | A pura (4 sitios propios) | `category?.isIncome == false/!= true` | Panel — gasto por cuenta, widget "Últimos registros", widget presupuestos |
| `BudgetsViewModel.swift:588` | A pura | `$0.category?.isIncome == false` | Presupuestos + `BudgetAlertService` (delega 100% a este cálculo) |
| `FilterService.matchesCriteria:255,257,268,270` | A (categoría, sin fallback) | `transaction.category?.isIncome == true/false` | Filtro de naturaleza (chips ingreso/gasto) — usado por `RecordsViewModel.applyFilters()` ANTES de `calculateSummary()`, y por Categories/FinancialReport/Sankey/TopSpendingCategories |
| `TransactionDetailSheetLogic.kind:37-41` | A-fallback (canónico) | `categoryIsIncome ?? (amount >= 0)` | Sheet de detalle de una TX individual (Records) |
| `RecordRowView.amountColor:262-265`, `RecentRecordsWidget.swift:213`, `GlobalSearchView.swift:411` | A-fallback (canónico, idéntico ×3) | `record.category?.isIncome ?? (record.amount >= 0)` | Color del monto en filas de Records, widget Panel, Búsqueda Global |
| `NewTransactionView.swift:1387` | A-fallback (canónico) | `subcategory?.safeCategory.isIncome == true \|\| tx.amount > 0` | Prefill segmented Ingreso/Gasto al editar TX |
| **`PivotTableCalculator.swift:173` (dimensión "Tipo")** | A-fallback (canónico) | `tx.category?.isIncome ?? (tx.amount > 0)` | Tabla pivote (Reports), dimensión "Tipo" |
| **`PivotTableCalculator.swift:183,190,213` (dimensiones "Categoría"/"Subcategoría"/"Cuenta")** | **A-fallback DISTINTO (variante propia, nunca mira signo)** | `tx.category?.isIncome ?? false` | **Mismo Reporte, mismo archivo — para una TX sin categoría, la dimensión "Tipo" la clasificaría por signo mientras "Categoría"/"Subcategoría"/"Cuenta" la clasificarían siempre como gasto** — divergencia intra-archivo nueva, no documentada hasta ahora |
| **`RecordsViewModel.swift:289-314` (`calculateSummary`)** | **B (signo puro, ignora categoría)** — seed original de este ticket | `if amount > 0 { income += amount } else { expense += abs(amount) }` | Header de `RecordsTabView.swift` — tab "Registros" de Estadísticas y `RecordsStandaloneView` |
| **`RecordsViewModel.swift:719-726`** (bulk-edit) | A pura (consistente, no suma al problema) | `if subcategory.safeCategory.isIncome { … }` | `BulkEditSheet` — detecta selección income/expense/mixta antes de aplicar un bulk update |
| **`Services/TrendDataProcessor.swift:81-94` (`processTrendData`)** | **B (signo puro, ignora categoría)** | `if amount > 0 { totalIncome += amount } else { totalExpense += abs(amount) }` | Tab **Tendencias** de Estadísticas (`TrendsTabView.swift`) y **trend widget del Panel** (`PanelViewModel.swift:1151,2528,2539`) |
| **`StatisticsViewModel.swift:532-539,561-566,654-664`** (3 funciones propias) | **B (signo puro)** | `filter { $0.amountInPreferredCurrency > 0 }` / `< 0` | Totales de Stats, registros recientes en detalle, trend chart por cuenta |

### Hallazgo nuevo más grave: mezcla A/B **dentro de la misma pantalla**, no solo entre pantallas distintas

El síntoma original documentado (Records vs CashFlow/Insights) ya era grave porque compara pantallas *distintas*. Este pase encontró algo peor — **el mismo `PanelViewModel`, en la misma pantalla del Panel, usa Lógica A para un widget y Lógica B para el widget de al lado**: el **widget Cash Flow** (línea 1742-1749, vía `CashFlowCalculator` → A) y el **widget Tendencias** (línea 1151, vía `TrendDataProcessor` → B) pueden mostrar totales de income/expense **distintos entre sí, en la misma vista, para el mismo período**, si existe una sola transacción con signo/categoría desincronizados. Verificado línea por línea contra el código real (no solo grep) — ambos callsites están en el mismo archivo, mismo ViewModel. El mismo patrón se repite en la tab Tendencias de Statistics (trend chart con B, Cash Flow widget con A) y dentro de `PivotTableCalculator` (dimensión "Tipo" con un fallback, "Categoría"/"Subcategoría"/"Cuenta" con otro).

**Esto eleva la prioridad de la Solución propuesta abajo**: el Fix B (helper compartido) deja de ser "recomendado, opcional" y pasa a ser la forma más segura de cerrar esto de raíz — con 3+ sitios de Lógica B pura y 2 variantes de fallback distintas ya confirmadas, seguir parchando sitio por sitio (Fix A) deja abierta la puerta a que aparezca un cuarto/quinto sitio divergente.

### Fuera de este ticket, pero relacionado (no tocar aquí)

`FinancialScoreCalculator.swift:356` y `ScheduledPaymentsViewModel.swift` (varios sitios) usan **Lógica C** — clasifican por `ScheduledPayment.transactionType` (un enum de string propio de pagos planificados, `"income"`/`"expense"`), no por `TransactionItem.category`. No es directamente comparable ni parte de esta divergencia (son modelos distintos), pero es la misma familia de riesgo (múltiples fuentes de verdad para "es esto un ingreso") — posible ticket aparte si se decide unificar.
| **`Services/ReportNotificationService.swift:161-189`** | **B (signo puro, ignora categoría)** | `if amount > 0 { totalIncome += amount } else { totalExpense += abs(amount) }`, con comentario explícito línea 183: `// R4: Same sign convention as TrendDataProcessor` | Reportes automáticos/notificaciones programadas por email o push |

**Corrección importante vs mi primera pasada de este ticket**: la Lógica B (signo puro) NO está aislada en `RecordsViewModel` — es un clúster de **3 sitios** (`RecordsViewModel`, `TrendDataProcessor`, `ReportNotificationService`), y el comentario en `ReportNotificationService.swift:183` confirma que la réplica entre `TrendDataProcessor` y `ReportNotificationService` es deliberada ("same sign convention as..."), aunque contradice la regla canónica documentada en `TransactionDetailSheetLogic`/`RecordRowView`/`PivotTableCalculator`. Esto amplía el alcance real del bug reportado: **la tab Tendencias de Estadísticas y el trend widget del Panel también podrían mostrar montos income/expense divergentes** frente a CashFlow/Insights/Hero para cualquier cuenta con TX de signo/categoría desincronizados — no solo Records. No se verificó en esta sesión si el caso puntual del reporte (+240) también se manifiesta en Tendencias; sería el primer chequeo a hacer al retomar.

**Hallazgo relacionado (bug distinto, mismo síntoma raíz) — prefill de edición con OR invertido**: `Yala/App/Views/Transactions/NewTransactionView.swift:1387`, al abrir el form para EDITAR una TX existente:
```swift
if tx.subcategory?.safeCategory.isIncome == true || tx.amount > 0 {
    viewModel.transactionType = .income
} else {
    viewModel.transactionType = .expense
}
```
Este `OR` es más agresivo que el fallback canónico (`??`): si `category.isIncome == false` pero `amount > 0` (el escenario exacto de la divergencia), este código igual prefillea `.income`, en la dirección contraria a la regla "la categoría manda". No afecta cálculos de totales (es solo el estado inicial del formulario al editar), pero significa que al abrir para editar una TX ya divergente, el usuario ve un `transactionType` que no necesariamente coincide con su categoría real — vale la pena corregirlo en el mismo fix o documentarlo como follow-up, a decisión de quien retome.

**Hallazgo clave del alcance**: el filtro de *naturaleza* (chips ingreso/gasto) que `RecordsViewModel.applyFilters()` aplica vía `FilterService.matchesCriteria` **sí usa Lógica A** (`category?.isIncome`, líneas 254-271 de `FilterService.swift`). Es decir, dentro del mismo ViewModel, el filtrado por naturaleza y el cálculo del summary usan criterios **contradictorios** — si el usuario filtra explícitamente por "Ingresos" (que selecciona por categoría), el summary resultante reclasificaría por signo, pudiendo en teoría mostrar una TX filtrada como "ingreso" sumada al lado de gastos si su signo no coincide.

## Fix propuesto

**La categoría debe ser la autoridad, con el signo como fallback solo si `category == nil`** — esto no es una propuesta nueva, es **la regla que el propio código ya declara como canónica** en `TransactionDetailSheetLogic.kind()` y replica en `RecordRowView.amountColor` y `PivotTableCalculator.swift:173`. El fix es hacer que los 3 sitios de Lógica B (`RecordsViewModel.calculateSummary`, `TrendDataProcessor.processTrendData`, `ReportNotificationService`) sigan esa misma regla en vez de ignorarla.

Dos niveles de fix, no mutuamente excluyentes:

**A. Fix inmediato (síntoma) — alinear los 3 sitios de Lógica B con el patrón canónico ya existente:**
```swift
let isIncome = record.category?.isIncome ?? (amount >= 0)
if isIncome {
    income += abs(amount)
} else {
    expense += abs(amount)
}
```
Nota: este patrón usa el fallback `?? (amount >= 0)` (igual que `TransactionDetailSheetLogic`/`RecordRowView`/`PivotTableCalculator`), NO excluye TX con `category == nil` — a diferencia de `CashFlowCalculator`, que sí las excluye con un `guard`. Decidir explícitamente cuál de las dos convenciones adoptar (fallback vs exclusión) es parte del Acceptance Criteria — ambas son defendibles, pero deben ser la MISMA en los 3 sitios corregidos para no crear una tercera familia de divergencia.

Aplicar el mismo cambio en los 3 sitios:
- `Yala/App/ViewModels/RecordsViewModel.swift:289-314` (`calculateSummary`)
- `Yala/Services/TrendDataProcessor.swift:81-94` (`processTrendData`)
- `Yala/Services/ReportNotificationService.swift:161-189`

**B. Fix estructural (recomendado, evita que la próxima vista nueva repita el bug) — extraer un helper compartido de clasificación:**

La misma regla (`category?.isIncome ?? (amount >= 0)`, o su variante con exclusión de `category == nil`) está hoy duplicada literal en al menos 3 sitios "correctos" (`TransactionDetailSheetLogic`, `RecordRowView`, `PivotTableCalculator`) más las variantes sin-fallback de `HeroBucketsCalculator`/`InsightsCalculator`/`FilterService`, y violada en otros 3 (`RecordsViewModel`/`TrendDataProcessor`/`ReportNotificationService`). Un helper puro tipo:
```swift
enum TransactionClassification {
    static func isIncome(_ tx: TransactionItem) -> Bool {
        tx.category?.isIncome ?? (tx.amountInPreferredCurrency >= 0)
    }
}
```
permitiría que los 6+ sitios existentes lo consuman sin reinventar el criterio, y que cualquier calculator futuro lo use por default en vez de reinventar su propia variante. No es estrictamente necesario para cerrar este ticket puntual, pero reduce el riesgo de que aparezca un p20-14 análogo en otra vista nueva (de hecho, este ticket YA es ese caso — la Lógica B se replicó de `RecordsViewModel` a `TrendDataProcessor` a `ReportNotificationService` con un comentario que asume que copiar la convención es correcto). Decisión de alcance: aplicar solo A, o A+B, queda a criterio de quien retome — A por sí solo ya cierra el bug reportado en los 3 sitios conocidos.

**Los mecanismos que CAUSAN la divergencia de datos (import CSV modo estricto, bulk-edit de subcategoría, y el `OR` invertido de `NewTransactionView.swift:1387` en el prefill de edición) NO son parte de este fix** — son comportamientos de producto potencialmente correctos (o al menos, decisiones de diseño ya tomadas conscientemente, ver comentarios en `CategoryImportHelper.swift:45-47`) que quedan fuera de alcance salvo que el equipo decida que también deben corregirse. Este ticket es sobre **cómo se lee/agrega** un dato que puede legítimamente llegar desincronizado, no sobre prevenir que llegue desincronizado.

## Riesgos

- **Totales visibles hoy cambiarán en 3 vistas, no solo RecordsStandalone**: header de Records (tab Estadísticas + Standalone), tab Tendencias de Estadísticas, y cualquier reporte automático generado por `ReportNotificationService` — para cualquier cuenta que tenga al menos una TX con signo/categoría desincronizados (vía import CSV modo estricto, bulk-edit de subcategoría histórico, o el ajuste de saldo inicial si algún consumidor omitiera el guard de `balanceAdjustmentType`). El monto que el usuario ve hoy bajará o subirá según el sentido de la(s) TX afectada(s) — pasará a coincidir con lo que YA muestran CashFlow/Insights/Hero, pero representa un cambio visual real para cualquier usuario con datos divergentes (no solo el reportante original; los reportes automáticos por email/push que reciban esos usuarios también cambiarán retroactivamente en el próximo envío).
- **El balance (`income - expense`) no cambia** con el fix A en ninguno de los 3 sitios — solo se redistribuye entre income/expense, el neto es invariante ante reclasificación. Esto es importante para explicarle al usuario si pregunta "¿por qué cambió el número?": el balance total del período se mantiene igual, solo el desglose ingreso/gasto se corrige.
- **Decisión fallback vs exclusión de `category == nil`** (ver Fix propuesto A): si se elige el patrón canónico con fallback (`?? amount>=0`, como `TransactionDetailSheetLogic`/`RecordRowView`), el comportamiento para TX sin categoría es "no romper, usar el signo" — no cambia respecto a lo que Records/Trends/Reports ya hacían hoy para esas TX (ambos lados ya usaban el signo, coincidentemente). Si en cambio se decide alinear con `CashFlowCalculator` (excluir `category == nil` con `guard`), cualquier cuenta con TX huérfanas de categoría vería un cambio adicional: esas TX dejarían de sumar a los 3 buckets corregidos. Verificar con una query real si existen TX así en producción antes de decidir.
- **No se investigó (fuera de alcance de esta sesión) qué tan frecuente es la divergencia en datos reales de producción**, ni si el caso puntual reportado (+240, 2026-04-30) también se manifiesta en la tab Tendencias del mismo usuario — no hay telemetría ni query ejecutada contra sus datos para contar cuántas TX exactas explican el +240, ni para confirmar si el alcance ampliado (Tendencias/Reports) le afecta a él también. La causa raíz confirmada en código explica el MECANISMO y su alcance real en la base de código, pero identificar la(s) TX exacta(s) del caso reportado requiere un diff de datos real, que sigue pendiente si se quiere verificar el caso puntual antes de generalizar el fix.
- **Ninguno de los 3 sitios de Lógica B tiene tests existentes que cubran la clasificación income/expense** (confirmado: no hay `RecordsViewModelTests.swift`, ni test de `TrendDataProcessor.processTrendData` ni de `ReportNotificationService` que verifique esto; sí existen `CashFlowCalculatorTests.swift` y `HeroBucketsCalculatorTests.swift` para el lado A). Si se extrae el helper compartido (fix B), se habilita testear la clasificación en aislado sin `makeTestContext()` (evita el flake R8 documentado en CLAUDE.md); si se aplica solo el fix A inline en los 3 sitios, seguirán sin cobertura unitaria directa de esta regla específica salvo que se agreguen tests de integración con SwiftData.
- **El `OR` invertido de `NewTransactionView.swift:1387`** (ver Alcance real) es un bug relacionado pero separado — no afecta ningún total agregado, solo el estado inicial del formulario al editar una TX ya divergente. Si se corrige en la misma sesión, verificar que no rompe el flujo normal de edición (donde categoría y signo ya coinciden en el 99% de los casos).

## Resolución — Fase 1 (2026-07-05): acotada a Registros

Se implementó y verificó la corrección **solo en el header de Registros** (`RecordsViewModel.calculateSummary`), que resuelve el caso reportado (RecordsStandalone vs CashFlow/Insights) y es **autocoherente** (una sola cifra, sin curvas/listas que clasifiquen aparte).

**Qué se hizo:**
- Helper puro nuevo `Yala/App/Logic/TransactionClassificationLogic.swift` — regla canónica `category?.isIncome ?? (amountInPreferredCurrency >= 0)` (fallback al signo; decisión tomada).
- `RecordsViewModel.calculateSummary` usa el helper + **acumulación signed** (paridad exacta con `CashFlowCalculator`: un monto que contradice su categoría se trata como reembolso y reduce el bucket). Esto preserva la invariante `balance = Σ montos con signo`.
- Tests: `TransactionClassificationLogicTests` (7, lógica pura sin `ModelContext`). Build Yala+Yala Dev verde, 29 tests verdes. `qa/coverage-index.json` área `income-expense-classification-parity`.
- Device-QA: no-regresión (app compila y arranca sin crash; Panel renderiza). Navegación interactiva a Registros bloqueada por conflicto agent-device↔runner (conocido); e2e con TX desincronizada = manual/TestFlight.

**Qué se acotó y por qué:** `TrendDataProcessor` y `ReportNotificationService` (los otros 2 sitios que el plan original incluía) se **revirtieron**. El `/code-review high` (2026-07-05) confirmó que cambiar solo sus *totales*, dejando sin tocar el código adyacente que aún clasifica por signo (la **curva** de Tendencias, la lista de recientes de Estadísticas, el **empty-check** de Reportes), introduce **divergencias intra-pantalla nuevas** — lo contrario del objetivo. Esa migración coherente (total + curva/lista/empty-check juntos) vive ahora en **[[p20-14_income-expense-classification-trends-reports]]** (fase 2).

**Estado de los AC (scope original abajo):** cubiertos para Records — clasificación por categoría, convención `category==nil` (fallback), helper extraído, invariante del balance, coverage-index. Diferidos a fase 2 (p20-14): Tendencias/Estadísticas/Reportes + confirmar caso +240 en Tendencias + QA-SCENARIOS §35.11. Sigue pendiente (follow-up): `OR` invertido en `NewTransactionView.swift:1387`. El ticket queda **open** hasta cerrar fase 2.

## Acceptance Criteria

- [ ] `RecordsViewModel.calculateSummary()`, `TrendDataProcessor.processTrendData()` y `ReportNotificationService` (líneas de clasificación citadas en Causa raíz/Alcance real) clasifican income/expense por `category?.isIncome` (con o sin fallback de signo, ver decisión de abajo), no por el signo de `amount` como criterio primario.
- [ ] Decidir y documentar UNA convención para TX con `category == nil` — fallback al signo (patrón `TransactionDetailSheetLogic`/`RecordRowView`) o exclusión (patrón `CashFlowCalculator`) — y aplicarla consistentemente en los 3 sitios corregidos.
- [ ] (Opcional, recomendado) Extraer la clasificación income/expense a un helper puro reusado por los 3 sitios corregidos y, si se decide expandir el fix, por `HeroBucketsCalculator`/`CashFlowCalculator`/`InsightsCalculator`/`TransactionDetailSheetLogic`/`RecordRowView`/`PivotTableCalculator` — reduce la duplicación de la misma regla en 9+ sitios.
- [ ] Test de regresión: con un dataset fijo que incluya al menos 1 TX con signo/categoría desincronizados (simulando el caso import CSV o bulk-edit), la suma del header de Records, del total de Tendencias, y de un reporte generado por `ReportNotificationService` coinciden con CashFlow widget al primer decimal, en al menos 3 períodos distintos (Este mes, Última semana, Este año).
- [ ] Verificar que el balance (`income - expense`) de los 3 sitios corregidos no cambia tras el fix (solo se redistribuye entre income/expense) — test explícito de esta invariante.
- [ ] Confirmar si el caso puntual reportado (+240, 2026-04-30) también se manifiesta en la tab Tendencias de la cuenta del reportante — primer chequeo recomendado al retomar, antes de aplicar el fix a ciegas.
- [ ] (Opcional, follow-up) Corregir el `OR` invertido en `NewTransactionView.swift:1387` para que el prefill de edición siga la misma regla canónica.
- [ ] Device QA: reproducir con los datos del reporter (o dataset sintético equivalente) y confirmar que RecordsStandalone, tab Tendencias, y CashFlow/Insights coinciden exactamente para "Este mes".
- [ ] Añadir caso "Coherencia entre widgets de filtro de período" a QA-SCENARIOS sección 35.11 una vez resuelto.
- [ ] Actualizar `qa/coverage-index.json` si se agrega test nuevo (regla anti-drift de CLAUDE.md).

migrated from YalaWiki Backlog/p20-13_records-standalone-discrepancy.md @ 1934e8ad
