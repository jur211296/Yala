# Plan de Diseño: Flujo de Caja

*Documentado: 2026-03-17*

## 1. Visión General

**Qué es:** Un planificador de flujo de caja donde el usuario construye su modelo financiero personal mes a mes, con líneas de ingreso y gasto que se estiman automáticamente a partir de su historial real.

**Objetivo:** Que el usuario sepa cuánto le queda disponible cada mes y acumule ese saldo para planificar gastos futuros con confianza.

**Ubicación:** Tab "Flujo de caja" en FinancialReportView (reemplaza el placeholder actual).

**Prioridad:** V1.2 — Fase 12.

---

## 2. Decisiones de Diseño

| Decisión | Resolución |
|----------|------------|
| Nombre | "Flujo de caja" (chip existente, localizado en 6 idiomas) |
| Horizonte futuro | Default 6 meses, expandible. Free: máx 3 meses |
| Horizonte pasado | Default 3 meses, expandible hasta inicio del plan |
| Granularidad | Categoría por defecto, desglosable a subcategorías. Líneas libres permitidas |
| Acumulado | Parte de cero, con opción de saldo inicial configurable |
| Divisa | Todo convertido a divisa preferida del usuario |
| Planes | Uno solo (v1) |
| Scroll tabla | Horizontal para meses, vertical para líneas |
| Gráficas | Sheet desde toolbar, estilo widgets PanelView |
| Notificaciones | No (presupuestos ya las cubre) |
| ScheduledPayments nuevos | Se sugieren, no se agregan automáticamente |

---

## 3. Gate Pro/Free

| Aspecto | Free | Pro |
|---------|------|-----|
| Horizonte futuro | 3 meses | Ilimitado |
| Meses hacia atrás | Solo mes actual (real vs plan) | 3+ meses |
| Líneas | Ilimitadas | Ilimitadas |
| Métodos de estimación | Promedio 6m, manual, pago fijo | + Tendencia, custom, promedio configurable |
| Gráficas de análisis | Saldo acumulado básico | Todas las gráficas |
| Pre-llenado inteligente | Sí | Sí |

**Implementación:** Agregar `.cashFlowAdvanced` a `ProFeature` enum. La feature base es Free; los métodos avanzados, horizonte extendido y gráficas completas son Pro.

---

## 4. Modelos SwiftData

### 4.1 CashFlowPlan (nuevo @Model)

```swift
@Model
final class CashFlowPlan {
    var id: UUID = UUID()
    var name: String = ""
    var startingBalance: Double = 0          // Saldo inicial (default 0)
    var defaultMonthsAhead: Int = 6          // Horizonte futuro default
    var defaultMonthsBack: Int = 3           // Horizonte pasado default
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var showOtherExpenses: Bool = true       // Línea "Otros gastos" visible

    @Relationship(deleteRule: .cascade, inverse: \CashFlowLine.plan)
    var lines: [CashFlowLine]?
}
```

### 4.2 CashFlowLine (nuevo @Model)

```swift
@Model
final class CashFlowLine {
    var id: UUID = UUID()
    var name: String = ""
    var isIncome: Bool = false
    var sortOrder: Int = 0
    var isEnabled: Bool = true               // Visible en el plan
    var isExpanded: Bool = false             // Subcategorías desplegadas

    // Método de estimación
    var estimationMethod: String = "average6m"
    // Valores: "average3m", "average6m", "average12m", "lastMonth",
    //          "manual", "trend", "custom", "scheduled"

    var manualAmount: Double?                // Para método "manual"
    var customMonthsRaw: String?             // Para método "custom" — ISO dates CSV

    // Vínculos opcionales
    @Relationship(deleteRule: .nullify)
    var category: Category?

    @Relationship(deleteRule: .nullify)
    var scheduledPayment: ScheduledPayment?

    // Relación con plan
    var plan: CashFlowPlan?

    // Overrides por mes
    @Relationship(deleteRule: .cascade, inverse: \CashFlowOverride.line)
    var overrides: [CashFlowOverride]?

    // Computed helpers (no persistidos)
    var customMonths: [String] {
        guard let raw = customMonthsRaw, !raw.isEmpty else { return [] }
        return raw.split(separator: ",").map(String.init)
    }
}
```

### 4.3 CashFlowOverride (nuevo @Model)

```swift
@Model
final class CashFlowOverride {
    var id: UUID = UUID()
    var monthKey: String = ""                // Formato: "2026-04"
    var amount: Double = 0
    var note: String = ""                    // Ej: "Bono anual"

    var line: CashFlowLine?
}
```

**Notas CloudKit:**
- Todas las propiedades con defaults
- Relaciones opcionales
- Sin `@Attribute(.unique)`
- `deleteRule: .cascade` de Plan → Lines → Overrides
- `deleteRule: .nullify` para vínculos a Category/ScheduledPayment

**Registro:** Agregar `CashFlowPlan.self`, `CashFlowLine.self`, `CashFlowOverride.self` a `SwiftDataConfiguration.schema`.

---

## 5. Calculador

### 5.1 CashFlowProjectionCalculator

```
Archivo: App/Logic/Calculators/CashFlowProjectionCalculator.swift
```

**Responsabilidades:**
- Calcular el monto estimado de cada línea según su método
- Calcular "Otros gastos" (categorías no asignadas a ninguna línea)
- Calcular real vs plan para meses pasados y actual
- Calcular saldo disponible y acumulado por mes
- Calcular progreso parcial del mes actual

**Structs de salida:**

```swift
struct CashFlowProjection {
    let months: [CashFlowMonth]
    let startingBalance: Double
    let totalProjectedIncome: Double        // Suma todos los meses futuros
    let totalProjectedExpense: Double
    let totalProjectedNet: Double
}

struct CashFlowMonth {
    let monthKey: String                     // "2026-04"
    let date: Date                           // Primer día del mes
    let isPast: Bool
    let isCurrent: Bool
    let incomeLines: [CashFlowLineResult]
    let expenseLines: [CashFlowLineResult]
    let otherExpenses: CashFlowOtherResult?
    let totalIncome: Double
    let totalExpense: Double                 // Negativo
    let netFlow: Double                      // income + expense
    let accumulatedBalance: Double           // Sumando desde startingBalance
}

struct CashFlowLineResult {
    let lineID: UUID
    let name: String
    let plannedAmount: Double
    let realAmount: Double?                  // Solo meses pasados/actual
    let difference: Double?                  // real - planned
    let differencePercent: Double?           // (real - planned) / planned
    let progress: Double?                    // Solo mes actual: real / planned
    let isOverride: Bool                     // Monto fue override manual
    let estimationMethod: String
    let subcategoryBreakdown: [SubcategoryLineResult]?  // Si está expandido
}

struct CashFlowOtherResult {
    let plannedAmount: Double
    let realAmount: Double?
    let categoryBreakdown: [OtherCategoryItem]
}

struct OtherCategoryItem {
    let categoryName: String
    let iconName: String
    let colorHex: String
    let amount: Double
}

struct SubcategoryLineResult {
    let subcategoryName: String
    let plannedAmount: Double
    let realAmount: Double?
}
```

**Métodos de estimación:**

| Método | Cálculo |
|--------|---------|
| `average3m` | Promedio últimos 3 meses con transacciones en esa categoría |
| `average6m` | Promedio últimos 6 meses |
| `average12m` | Promedio últimos 12 meses |
| `lastMonth` | Monto total del mes anterior |
| `manual` | `CashFlowLine.manualAmount` |
| `trend` | Regresión lineal sobre últimos 6 meses, extrapola (Pro) |
| `custom` | Promedio solo de meses seleccionados en `customMonthsRaw` (Pro) |
| `scheduled` | `ScheduledPayment.amount` × ocurrencias en el mes |

**Cálculo de "Otros gastos":**
1. Obtener todas las categorías de gasto del usuario
2. Restar las que están asignadas a alguna línea activa del plan
3. Sumar transacciones de las categorías restantes
4. Para meses futuros: promedio de los últimos 6 meses de esas categorías
5. Se actualiza automáticamente cuando se agregan/quitan líneas

**Cálculo mes actual (progreso parcial):**
1. Día actual del mes: `dayOfMonth / daysInMonth`
2. Real hasta hoy vs plan completo del mes
3. Ritmo: `realAmount / dayOfMonth * daysInMonth` (proyección lineal)
4. Barra de progreso: `realAmount / plannedAmount`

---

## 6. ViewModel

### 6.1 CashFlowPlanViewModel

```
Archivo: App/ViewModels/CashFlowPlanViewModel.swift
```

```swift
@MainActor @Observable
final class CashFlowPlanViewModel {
    private var modelContext: ModelContext?

    // Estado del plan
    private(set) var plan: CashFlowPlan?
    private(set) var hasPlan: Bool = false
    private(set) var projection: CashFlowProjection?

    // Setup state
    private(set) var suggestedLines: [SuggestedLine] = []

    // UI state
    var showLineConfig: Bool = false
    var selectedLine: CashFlowLine?
    var showChartsSheet: Bool = false
    var showOthersBreakdown: Bool = false

    // Horizonte visible
    var visibleMonthsAhead: Int = 6
    var visibleMonthsBack: Int = 3

    func setContext(_ ctx: ModelContext) { ... }
    func loadPlan() { ... }

    // Setup
    func generateSuggestions(from transactions: [TransactionItem],
                             scheduledPayments: [ScheduledPayment],
                             categories: [Category]) { ... }
    func createPlan(from suggestions: [SuggestedLine],
                    startingBalance: Double) { ... }

    // CRUD líneas
    func addLine(_ line: CashFlowLine) { ... }
    func removeLine(_ line: CashFlowLine) { ... }
    func updateLine(_ line: CashFlowLine) { ... }
    func reorderLines(_ offsets: IndexSet, to: Int) { ... }
    func promoteFromOthers(_ category: Category) { ... }  // Otros → línea propia

    // Overrides
    func setOverride(line: CashFlowLine, monthKey: String, amount: Double, note: String) { ... }
    func removeOverride(line: CashFlowLine, monthKey: String) { ... }

    // Recálculo
    func recalculate(transactions: [TransactionItem]) { ... }

    // Reset
    func resetPlan() { ... }
}

struct SuggestedLine {
    let category: Category?
    let scheduledPayment: ScheduledPayment?
    let name: String
    let isIncome: Bool
    let suggestedAmount: Double
    let estimationMethod: String
    let monthsWithActivity: Int             // De los últimos 6
    let isRecommended: Bool                 // 4+ meses → true
    var isSelected: Bool                    // Toggle del usuario
}
```

---

## 7. Vistas

### 7.1 Vista de Setup (primer uso)

```
Archivo: App/Views/Reports/CashFlow/CashFlowSetupView.swift
```

**Cuándo se muestra:** Cuando `hasPlan == false` (no existe CashFlowPlan).

**Estructura:**
```
ScrollView vertical {
    Header: título + descripción

    Sección "Ingresos":
        ForEach suggestedLines.filter(isIncome) {
            SuggestedLineRow(checkbox, nombre, icono, monto, método, chevron)
        }

    Sección "Gastos":
        ForEach suggestedLines.filter(!isIncome && isRecommended) {
            SuggestedLineRow — checked por defecto
        }
        ForEach suggestedLines.filter(!isIncome && !isRecommended) {
            SuggestedLineRow — unchecked por defecto
        }

    Botón "+ Agregar línea manual"

    Sección "Automático":
        Fila "Otros gastos" con monto calculado + chevron al desglose

    Divider

    Resumen en vivo:
        Ingresos: S/ X,XXX
        Gastos:  -S/ X,XXX
        Disponible: S/ X,XXX/mes

    Campo saldo inicial (opcional, default 0)

    YalaPrimaryButton "Crear mi plan"
}
```

**Reglas de pre-llenado:**
- Categorías con actividad en 4+ de los últimos 6 meses → checked (recommended)
- Categorías con actividad en 2-3 meses → mostradas unchecked
- Categorías con 1 solo mes → no mostradas
- ScheduledPayments activos → siempre checked, método "scheduled"
- Ingresos detectados por `category.isIncome == true`
- El resumen se actualiza en tiempo real al togglear líneas

**Tap en chevron de línea sugerida → Sheet de configuración de método:**
- Radio buttons: Promedio 6m, Promedio 3m, Último mes, Monto fijo
- Muestra tendencia y rango como contexto informativo
- Métodos Pro (tendencia, custom) con badge Pro si usuario es Free

### 7.2 Vista de Tabla (plan activo)

```
Archivo: App/Views/Reports/CashFlow/CashFlowTableView.swift
```

**Cuándo se muestra:** Cuando `hasPlan == true`.

**Layout:**

```
┌──────────────────────────────────────────────────────┐
│  [Columna sticky]  │  [ScrollView horizontal meses]  │
│                    │                                  │
│  INGRESOS     ▾    │   Ene*    Feb*    Mar     Abr   │
│    Sueldo          │  5,000   5,000   5,000   5,000  │
│    Freelance       │    800     800     800     800   │
│                    │                                  │
│  GASTOS        ▾   │                                  │
│    Renta           │ -1,200  -1,200  -1,200  -1,200  │
│    Alimentación    │   -680    -690    -340▐   -680   │
│    Transporte      │   -350    -350    -180▐   -350   │
│    Entretenimiento │   -400    -400    -220▐   -400   │
│    + Agregar       │                                  │
│  ··················│······························    │
│    Otros gastos    │   -420    -410    -200▐   -420   │
│                    │                                  │
├────────────────────┼─────────────────────────────────│
│  DISPONIBLE        │  2,750   2,750   3,160   2,750  │  ← sticky bottom
│  ACUMULADO         │  2,750   5,500   8,660  11,410  │
└──────────────────────────────────────────────────────┘

* = meses pasados (fondo tenue)
▐ = barra de progreso mini (mes actual)
```

**Componentes:**

```
App/Views/Reports/CashFlow/CashFlowTableView.swift      — Vista principal
App/Views/Reports/CashFlow/CashFlowMonthColumn.swift     — Columna de un mes
App/Views/Reports/CashFlow/CashFlowLineNameRow.swift     — Fila nombre (sticky)
App/Views/Reports/CashFlow/CashFlowCellView.swift        — Celda individual
App/Views/Reports/CashFlow/CashFlowSummaryRow.swift      — Fila resumen (sticky bottom)
```

**Indicadores visuales por celda:**

| Estado | Visual |
|--------|--------|
| Monto calculado automáticamente | Texto color secundario |
| Override manual | Texto color primario (bold) |
| Mes pasado real = plan | Sin indicador |
| Mes pasado real > plan (gasto) | Punto rojo + texto rojo |
| Mes pasado real < plan (gasto) | Punto verde + texto verde |
| Mes actual | Barra de progreso mini debajo del monto |
| Mes actual sobre ritmo | Barra amarilla/roja |
| Mes actual bajo ritmo | Barra verde |

**Mes actual — Barra de progreso:**
- Ancho proporcional: `min(1.0, realAmount / plannedAmount)`
- Color: verde si < 80%, amarillo 80-100%, rojo si > 100%
- Debajo del monto real, height: 3pt, corner radius: 1.5pt
- El monto muestra el real parcial (no el plan)

**Interacciones:**

| Gesto | Acción |
|-------|--------|
| Tap en celda de monto | Popover: plan, real (si aplica), diferencia, botón "Modificar" → override |
| Tap en nombre de línea | Sheet de configuración (método, categoría, desglose) |
| Tap en header "INGRESOS"/"GASTOS" | Colapsar/expandir sección |
| Tap en "Otros gastos" | Sheet con desglose de categorías no asignadas |
| Tap en categoría dentro de Otros | Promueve a línea propia (con confirmación) |
| Tap en "+ Agregar" | Sheet: desde categoría, desde pago programado, o línea manual |
| Long press en línea | Menú: duplicar, eliminar, desglosar subcategorías |
| Drag en nombres de línea | Reordenar |
| Swipe left en nombre | Eliminar línea |

### 7.3 Sheet de Configuración de Línea

```
Archivo: App/Views/Reports/CashFlow/CashFlowLineConfigSheet.swift
```

```
┌─────────────────────────────────────┐
│         Alimentación            ✕   │
│                                     │
│  Categoría                          │
│  [Alimentación                  ▸]  │
│                                     │
│  Desglosar subcategorías            │
│  [toggle off]                       │
│                                     │
│  Método de estimación               │
│  ● Promedio 6 meses      S/ 680    │
│  ○ Promedio 3 meses      S/ 710    │
│  ○ Promedio 12 meses     S/ 650    │
│  ○ Último mes            S/ 640    │
│  ○ Monto fijo            S/ ___    │
│  ○ Tendencia (↗ +3%)     S/ 700  🔒│  ← Pro
│  ○ Personalizado                 🔒│  ← Pro
│                                     │
│  Contexto:                          │
│  Tendencia: ↗ +3% mensual          │
│  Rango: S/ 580 – S/ 780            │
│  Meses con actividad: 6/6          │
│                                     │
│  ── Ajustes por mes ──              │
│  Jun 26: S/ 800 (vacaciones)    ✕   │
│  + Agregar ajuste                   │
│                                     │
│  [Eliminar línea]     rojo, bottom  │
└─────────────────────────────────────┘
```

### 7.4 Popover de Celda

```
Archivo: App/Views/Reports/CashFlow/CashFlowCellPopover.swift
```

```
┌──────────────────────┐
│  Alimentación — Abr  │
│                      │
│  Plan:  S/ 680       │
│  Real:  S/ 542       │  ← solo meses pasados/actual
│  Dif:   S/ -138 ✓    │  ← verde = gastó menos
│                      │
│  [Ajustar monto]     │  ← crea override
└──────────────────────┘
```

Para meses futuros sin real:

```
┌──────────────────────┐
│  Alimentación — Jun  │
│                      │
│  Plan:  S/ 680       │
│  Método: ø Prom. 6m  │
│                      │
│  [Ajustar monto]     │
└──────────────────────┘
```

### 7.5 Sheet de Desglose "Otros gastos"

```
Archivo: App/Views/Reports/CashFlow/CashFlowOthersSheet.swift
```

```
┌─────────────────────────────────────┐
│       Otros gastos — S/ 420     ✕   │
│                                     │
│  Gastos sin línea en tu plan:       │
│                                     │
│  🎁 Regalos              S/ 150  + │
│  🏥 Salud                S/ 120  + │
│  📚 Educación             S/ 80  + │
│  🐕 Mascotas              S/ 45  + │
│  ☁️ Sin categoría          S/ 25    │
│                                     │
│  Toca + para agregar como línea     │
│  independiente a tu plan.           │
│                                     │
└─────────────────────────────────────┘
```

Tap en "+" → la categoría se promueve a línea propia, "Otros" se reduce automáticamente.

### 7.6 Sheet de Gráficas

```
Archivo: App/Views/Reports/CashFlow/CashFlowChartsSheet.swift
```

Accesible desde botón en toolbar (ícono de gráfica).

**Gráficas incluidas (scroll vertical de widgets):**

| Gráfica | Tipo | Datos | Gate |
|---------|------|-------|------|
| Saldo acumulado | Área (LineMark + AreaMark) | Acumulado por mes, línea punteada futuro | Free |
| Ingreso vs Gasto | Barras agrupadas | Total ingreso y gasto por mes | Pro |
| Composición de gastos | Barras apiladas % | Cada línea como porcentaje del total | Pro |
| Real vs Plan | Barras dobles | Meses pasados: plan (outline) vs real (filled) | Pro |
| Tendencia por línea | Líneas múltiples | Líneas seleccionadas con su evolución | Pro |

**Estilo:** Mismo diseño que widgets de PanelView — tarjetas redondeadas, DS.Spacing, colores por categoría.

### 7.7 Integración en FinancialReportView

El `tabContent` switch pasa de:

```swift
case .flujoDeCaja:
    cashFlowPlaceholder
```

A:

```swift
case .flujoDeCaja:
    if cashFlowViewModel.hasPlan {
        CashFlowTableView(viewModel: cashFlowViewModel)
    } else {
        CashFlowSetupView(viewModel: cashFlowViewModel)
    }
```

**Toolbar condicional:** Cuando el tab es flujoDeCaja y hasPlan:
- Botón de gráficas (chart.bar.xaxis)
- Menú (...) con: "Reiniciar plan", "Configuración" (horizonte, saldo inicial)

---

## 8. Línea "Otros gastos"

### Comportamiento

- **Siempre presente** al final de la sección Gastos (no se puede eliminar, solo ocultar con toggle en plan)
- **Se calcula automáticamente**: suma de gastos en categorías no asignadas a ninguna línea activa
- **Se actualiza en vivo**: agregar/quitar una línea recalcula Otros inmediatamente
- **Visual diferenciado**: texto color secundario, separado por línea punteada

### Cálculo

**Meses pasados:** Suma real de transacciones en categorías no cubiertas.

**Meses futuros:** Promedio de los últimos 6 meses de esas mismas categorías (usa el mismo pool de categorías que el cálculo de meses pasados).

**Mes actual:** Real parcial de categorías no cubiertas (con barra de progreso proporcional al día del mes).

### Desglose

Tap en "Otros" → Sheet con lista de categorías incluidas + monto de cada una + botón "+" para promover a línea independiente.

---

## 9. Flujo del Usuario

### 9.1 Primer uso

```
1. Usuario toca chip "Flujo de caja"
2. App analiza últimos 6 meses de transacciones
3. Muestra CashFlowSetupView con sugerencias pre-llenadas
4. Usuario revisa: activa/desactiva líneas, ajusta métodos
5. Resumen en vivo muestra impacto en tiempo real
6. Opcionalmente ingresa saldo inicial
7. Toca "Crear mi plan"
8. Transición a CashFlowTableView con el plan completo
```

### 9.2 Uso recurrente

```
1. Usuario abre Reportes → Flujo de caja
2. Ve la tabla con datos actualizados (reales para meses pasados)
3. Puede:
   - Scrollear horizontalmente para ver más meses
   - Tap en celda para ver detalle/crear override
   - Tap en línea para cambiar configuración
   - Agregar nuevas líneas
   - Abrir gráficas de análisis
   - Explorar "Otros gastos" y promover categorías
```

### 9.3 Nuevo ScheduledPayment creado

```
1. Usuario crea un nuevo pago programado (ej: "Gimnasio S/ 150")
2. Al volver a Flujo de caja, aparece sugerencia sutil:
   "Nuevo pago: Gimnasio. ¿Agregar al plan?"
   [Agregar] [Ignorar]
3. Si acepta, se crea línea con método "scheduled"
```

---

## 10. Textos (Brand Voice)

### Setup

```
Título: "Tu flujo de caja"
Descripción: "Analizamos tus últimos 6 meses para armar tu plan. Revisa y ajusta lo que necesites."
Botón: "Crear mi plan"
Saldo inicial label: "Saldo inicial (opcional)"
Saldo inicial helper: "Si quieres que el acumulado parta de tu saldo actual."
```

### Tabla

```
Header Ingresos: "Ingresos"
Header Gastos: "Gastos"
Fila Disponible: "Disponible"
Fila Acumulado: "Acumulado"
Otros gastos: "Otros gastos"
Agregar línea: "Agregar línea"
```

### Popover

```
Plan: "Plan"
Real: "Real"
Diferencia: "Diferencia"
Ajustar: "Ajustar monto"
```

### Otros

```
Desglose Otros título: "Otros gastos"
Desglose Otros descripción: "Gastos sin línea en tu plan:"
Desglose Otros hint: "Toca + para agregar como línea independiente."
Reiniciar: "Reiniciar plan"
Reiniciar confirmación: "¿Reiniciar tu plan? Se eliminarán todas las líneas y ajustes. Esta acción no se puede deshacer."
Sugerencia ScheduledPayment: "Nuevo pago: %@. ¿Agregar al plan?"
```

### Empty state (sin transacciones)

```
Icono: "arrow.left.arrow.right"
Título: "Aún no hay datos"
Mensaje: "Registra tus gastos e ingresos por al menos un mes para crear tu plan de flujo de caja."
```

---

## 11. Archivos Nuevos

```
Modelos:
  Models/CashFlowPlan.swift
  Models/CashFlowLine.swift
  Models/CashFlowOverride.swift

Calculador:
  App/Logic/Calculators/CashFlowProjectionCalculator.swift

ViewModel:
  App/ViewModels/CashFlowPlanViewModel.swift

Vistas:
  App/Views/Reports/CashFlow/CashFlowSetupView.swift
  App/Views/Reports/CashFlow/CashFlowTableView.swift
  App/Views/Reports/CashFlow/CashFlowMonthColumn.swift
  App/Views/Reports/CashFlow/CashFlowLineNameRow.swift
  App/Views/Reports/CashFlow/CashFlowCellView.swift
  App/Views/Reports/CashFlow/CashFlowSummaryRow.swift
  App/Views/Reports/CashFlow/CashFlowLineConfigSheet.swift
  App/Views/Reports/CashFlow/CashFlowCellPopover.swift
  App/Views/Reports/CashFlow/CashFlowOthersSheet.swift
  App/Views/Reports/CashFlow/CashFlowChartsSheet.swift

Localizaciones:
  Agregar ~30 keys a L10n.swift + 6 .strings files
```

---

## 12. Incrementos de Implementación

### Incremento 1: Modelos + Schema
- Crear CashFlowPlan, CashFlowLine, CashFlowOverride
- Registrar en SwiftDataConfiguration.schema
- Agregar `.cashFlowAdvanced` a ProFeature
- Verificar build + migración CloudKit

### Incremento 2: Calculador base
- CashFlowProjectionCalculator con métodos: average3m, average6m, lastMonth, manual, scheduled
- Cálculo de "Otros gastos"
- Cálculo de real vs plan para meses pasados
- Cálculo de progreso parcial mes actual
- Tests unitarios (20-25 tests)

### Incremento 3: ViewModel + Setup
- CashFlowPlanViewModel con generación de sugerencias y CRUD
- CashFlowSetupView con checkboxes, resumen en vivo, saldo inicial
- Integrar en FinancialReportView (reemplazar placeholder)
- Localizaciones

### Incremento 4: Vista de tabla
- CashFlowTableView con scroll horizontal sticky
- CashFlowMonthColumn, CashFlowLineNameRow, CashFlowCellView
- CashFlowSummaryRow sticky en bottom
- Indicadores visuales (colores, barra progreso mes actual)
- Secciones colapsables

### Incremento 5: Interacciones
- CashFlowCellPopover (tap en celda)
- CashFlowLineConfigSheet (tap en nombre de línea)
- CashFlowOthersSheet (desglose + promover categoría)
- Override por mes
- Agregar línea (desde categoría, pago programado, o manual)
- Long press menú (eliminar, desglosar subcategorías)
- Drag to reorder, swipe to delete

### Incremento 6: Gráficas
- CashFlowChartsSheet con 5 gráficas
- Gráfica saldo acumulado (Free)
- Gráficas Pro: ingreso vs gasto, composición, real vs plan, tendencia por línea
- Gate Pro/Free en gráficas

### Incremento 7: Métodos avanzados + polish
- Método "trend" (regresión lineal) — Pro
- Método "custom" (seleccionar/excluir meses) — Pro
- Sugerencia de ScheduledPayments nuevos
- Desglose por subcategorías en líneas expandidas
- Gate horizonte Free (3 meses) vs Pro (ilimitado)
- QA scenarios

---

## 13. Dependencias

| Componente existente | Uso en Flujo de Caja |
|---------------------|----------------------|
| FilterService | Filtrar transacciones por categoría/período para cálculo de promedios |
| CurrencyConverter | Convertir todo a divisa preferida |
| FeatureGateService | Gate Pro/Free |
| SessionState | Período seleccionado (para real vs plan) |
| FinancialReportView | Vista padre (tab container) |
| FinancialReportViewModel | Podría compartir lógica de filtros o ser independiente |
| Category, Subcategory | Vinculados a CashFlowLine |
| ScheduledPayment | Vinculados a CashFlowLine para pagos fijos |
| TransactionItem | Fuente de datos para cálculos reales y promedios |
| DS (Design System) | Spacing, Typography, Radius, Semantic colors |
| L10n | Localizaciones en 6 idiomas |
| TelemetryService | Tracking de uso de la feature |

---

## 14. Escenarios QA

### Setup

- [ ] Pre-llenado detecta categorías correctas (4+ meses = checked, 2-3 = unchecked)
- [ ] ScheduledPayments aparecen como líneas con método "scheduled"
- [ ] Toggle de línea actualiza resumen en tiempo real
- [ ] Cambio de método actualiza monto en tiempo real
- [ ] Saldo inicial se persiste correctamente
- [ ] "Crear mi plan" persiste todas las líneas seleccionadas
- [ ] Sin transacciones muestra empty state correcto
- [ ] Con solo 1 mes de datos, el setup funciona (menos sugerencias)

### Tabla

- [ ] Scroll horizontal muestra meses correctos (3 atrás + 6 adelante default)
- [ ] Columna de nombres es sticky al scrollear
- [ ] Fila resumen es sticky en bottom
- [ ] Meses pasados muestran datos reales con fondo diferenciado
- [ ] Mes actual muestra barra de progreso proporcional al día
- [ ] Overrides se reflejan en la celda (texto bold)
- [ ] Colapsar sección oculta sus líneas
- [ ] "Otros gastos" calcula correcto las categorías no asignadas

### Interacciones

- [ ] Tap en celda muestra popover con datos correctos
- [ ] Crear override persiste y recalcula totales
- [ ] Tap en nombre abre configuración con datos de la línea
- [ ] Cambiar método recalcula montos
- [ ] Promover categoría de "Otros" crea línea y reduce Otros
- [ ] Agregar línea manual funciona (sin categoría)
- [ ] Agregar línea desde categoría vincula correctamente
- [ ] Eliminar línea recalcula Otros y totales
- [ ] Drag reorder persiste el nuevo orden
- [ ] Desglosar subcategorías muestra sublíneas

### Cálculos

- [ ] Promedios calculan correctamente (solo meses con actividad)
- [ ] "Último mes" usa el mes calendario anterior
- [ ] "Pago fijo" usa monto del ScheduledPayment
- [ ] Acumulado suma correctamente desde saldo inicial
- [ ] Conversión de divisas funciona para transacciones multi-moneda
- [ ] Real vs plan: diferencia y porcentaje correctos
- [ ] Progreso mes actual: barra proporcional al día

### Pro/Free

- [ ] Free: máximo 3 meses hacia adelante
- [ ] Free: solo métodos básicos (promedio 6m, manual, pago fijo)
- [ ] Free: solo gráfica de saldo acumulado
- [ ] Free: real vs plan solo mes actual
- [ ] Pro: horizonte ilimitado
- [ ] Pro: todos los métodos (tendencia, custom)
- [ ] Pro: todas las gráficas
- [ ] Pro: histórico completo

### Edge cases

- [ ] Plan sin líneas de ingreso (solo gastos)
- [ ] Línea con categoría eliminada (se desvincula, mantiene nombre)
- [ ] ScheduledPayment vinculado eliminado (línea pasa a manual con último monto)
- [ ] Mes sin transacciones (real = 0, plan mantiene estimación)
- [ ] Override con monto 0 (válido — el usuario dice "este mes no gasto")
- [ ] Cambio de divisa preferida (recalcula todo)
- [ ] Muchas líneas (20+): performance del scroll
- [ ] Primer día del mes: progreso = mínimo, barra casi vacía
- [ ] Último día del mes: progreso ≈ 100%

---

## 15. Riesgos y Mitigaciones

| Riesgo | Mitigación |
|--------|------------|
| Performance con muchas líneas × muchos meses | Lazy loading de columnas, cálculos async con debounce |
| Scroll horizontal + vertical confuso en iPhone | Columna sticky + resumen sticky dan anclaje visual |
| CloudKit sync de 3 modelos nuevos | Seguir patrones existentes (defaults, optional relations) |
| Usuario no entiende los métodos | Mostrar contexto (tendencia, rango) junto a cada opción |
| "Otros gastos" es confuso | Separar visualmente + helper text "gastos sin línea en tu plan" |
| Tabla muy densa en iPhone SE | Montos abreviados (1.2k) si ancho < threshold |

---

*Este documento es la referencia completa para implementar el Flujo de Caja. Cada incremento debe consultarlo antes de comenzar.*
