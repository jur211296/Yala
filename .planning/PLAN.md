# Plan: Optimización de Cálculos en Vistas con Gráficos

## Contexto

Fase 5.1 — Último item pendiente: optimizar cálculos en PanelView, TrendsTabView, CategoriesTabView, RecordsTabView.

**Análisis realizado:** Se identificaron problemas de rendimiento con ganancia potencial de 5-10× en velocidad de cálculo.

## Problemas Identificados (por severidad)

### CRÍTICO - N+1 Queries
- TrendsTabView filtra transactions una vez, luego re-filtra en loop por cada account/currency
- Costo: O(a×n) + O(c×n) en lugar de O(n)
- Impacto: 10× más lento de lo necesario

### ALTO - Duplicación de Cálculos Previous Period
- CategoriesTabView.calculatePreviousPeriodTotals() tiene 160 líneas duplicando calculateData()
- Llama TopSpendingCategoriesCalculator, TopSubcategoriesCalculator, NatureTrendHelper 2 veces
- Impacto: 100% overhead en cada cambio de periodo

### ALTO - Tag Calculator Inconsistente
- calculateTagSpending() es implementación ad-hoc (no servicio)
- Patrón diferente a TopSpendingCategoriesCalculator
- Se calcula 2 veces (current + previous)

### MEDIO - Computed Properties Sin Cache
- RecordsTabView.recordsSummary recalcula en cada render
- Loop O(n×m) sin memoización

### MEDIO - onChange Handlers Excesivos
- PanelView: 20+ triggers llaman recalculateData()
- TrendsTabView: onChange duplicados para misma propiedad

## Plan de Ejecución

### Incremento 1: Eliminar N+1 en TrendsTabView
**Archivos:** TrendsTabView.swift
**Cambio:** Reemplazar loops con filter() por Dictionary(grouping:)

```swift
// ANTES (O(a×n))
for account in accounts {
    let accountTransactions = filtered.filter { $0.account?.persistentModelID == account.persistentModelID }
}

// DESPUÉS (O(n))
let groupedByAccount = Dictionary(grouping: filtered) { $0.account?.persistentModelID }
for (accountID, transactions) in groupedByAccount { ... }
```

**DoD:**
- calculateCashFlowData() usa Dictionary(grouping:) para accounts y currencies
- Sin cambio en comportamiento visible
- /verify-ios pasa

---

### Incremento 2: Crear TagSpendingCalculator Service
**Archivos:** Nuevo TagSpendingCalculator.swift, CategoriesTabView.swift
**Cambio:** Extraer calculateTagSpending() a servicio reutilizable

```swift
struct TagSpendingCalculator {
    static func calculateTopSpending(
        transactions: [TransactionItem],
        interval: DateInterval,
        currencyCode: String,
        transactionNatures: Set<TransactionNature>?,
        context: ModelContext
    ) -> [TagSpendingSummary]
}
```

**DoD:**
- TagSpendingCalculator.swift creado siguiendo patrón de TopSpendingCategoriesCalculator
- CategoriesTabView usa el nuevo servicio
- Tests existentes pasan

---

### Incremento 3: Consolidar Cálculo de Previous Period
**Archivos:** CategoriesTabView.swift
**Cambio:** Unificar calculateData() + calculatePreviousPeriodTotals() en función única que retorna ambos periodos

```swift
struct PeriodComparisonResult<T> {
    let current: [T]
    let previousTotal: Double?
    let previousAmounts: [PersistentIdentifier: Double]
}

private func calculateWithComparison() {
    // Un solo pass de FilterService
    // Calcular current y previous en paralelo
    // Retornar resultado consolidado
}
```

**DoD:**
- calculatePreviousPeriodTotals() eliminado o reducido a <20 líneas
- Mismo comportamiento visual
- Reducción de ~140 líneas de código

---

### Incremento 4: Cache en RecordsTabView
**Archivos:** RecordsTabView.swift
**Cambio:** Mover recordsSummary a ViewModel con cache

```swift
// En ViewModel
@Published var cachedSummary: (balance: Double, income: Double, expense: Double)?

func updateSummaryIfNeeded(groupedRecords: [GroupedRecords]) {
    // Solo recalcular si groupedRecords cambió
}
```

**DoD:**
- recordsSummary no recalcula en cada render
- Mismo comportamiento visual

---

### Incremento 5: Optimizar onChange Handlers
**Archivos:** PanelView.swift, TrendsTabView.swift
**Cambio:** Consolidar handlers relacionados, eliminar duplicados

**DoD:**
- TrendsTabView: sin onChange duplicados
- PanelView: handlers agrupados lógicamente
- Mismo comportamiento funcional

---

## Orden de Ejecución

| # | Incremento | Ganancia Esperada | Riesgo | Dependencias |
|---|------------|-------------------|--------|--------------|
| 1 | N+1 TrendsTabView | 10× en cálculo CashFlow | Bajo | Ninguna |
| 2 | TagSpendingCalculator | Código limpio, testeable | Bajo | Ninguna |
| 3 | Previous Period | 50% reducción cálculos | Medio | Ninguna |
| 4 | Cache RecordsTabView | Menor overhead renders | Bajo | Ninguna |
| 5 | onChange Handlers | Código más limpio | Bajo | Ninguna |

## Restricciones

- NO cambiar comportamiento visible al usuario
- NO modificar modelos SwiftData
- NO agregar nuevas dependencias
- Mantener compatibilidad con filtros existentes
- Cada incremento debe compilar y pasar tests antes del siguiente

## Verificación

Después de cada incremento:
1. /verify-ios
2. /test-ios (si aplica)
3. /commit-one

Al finalizar:
- Todos los tests pasan
- App funciona igual visualmente
- Código más limpio y mantenible
