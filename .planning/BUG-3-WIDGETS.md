# BUG-3: WidgetKit - Rediseño Completo

**Estado:** ESPECIFICACIÓN DEFINIDA
**Prioridad:** Alta
**Archivos principales:** `YalaWidgets/Widgets/*.swift`, `Yala/Services/WidgetDataCache.swift`

---

## ESPECIFICACIÓN DE WIDGETS (15 widgets)

### Principios de Diseño (aplican a TODOS)

| Aspecto | Especificación |
|---------|----------------|
| **Título** | Nombre del widget (ej: "Balance", "Gastos", "Flujo neto") |
| **Subtítulo** | Período seleccionado (ej: "Este mes", "Esta semana") |
| **KPI** | Número grande, prominente, con divisa |
| **Divisa** | Según preferencia del usuario en Perfil > Organización (símbolo o código) |
| **Períodos** | Mismos que PanelView (8): Esta semana, Últimos 7 días, Últimos 30 días, Este mes, Mes pasado, Este año, Año pasado, Todo el tiempo |
| **Click** | Navega a la vista correspondiente en la app |
| **Datos** | DEBEN cuadrar exactamente con los KPIs de PanelView para el mismo período |
| **Colores** | Usar DS tokens: `Color.yalaTeal` (ingresos), `Color.hotPink` (gastos), `Color.electricIndigo` (accent) |

---

## 1. Balance del Período (SMALL)

**Tamaño:** Small (cuadrado)
**Referencia:** TrendWidget en PanelView (modo Balance)

| Campo | Valor |
|-------|-------|
| Título | "Balance" o "Saldo actual" |
| Subtítulo | Período seleccionado |
| KPI | Monto en divisa preferida |
| Configuración | Selector de período |
| Deep link | `yala://panel` |

**Layout:**
```
┌─────────────────┐
│ Balance         │
│ Este mes        │
│                 │
│   S/ 15,420     │
│                 │
└─────────────────┘
```

**Datos:** Usar `BalanceHelper.totalBalance()` filtrado por período y cuenta (si aplica).

---

## 2. Gasto del Período (SMALL)

**Tamaño:** Small (cuadrado)
**Referencia:** TrendWidget en PanelView (modo Gastos)

| Campo | Valor |
|-------|-------|
| Título | "Gastos" |
| Subtítulo | Período seleccionado |
| KPI | Monto total de gastos en divisa preferida |
| Color KPI | `Color.hotPink` |
| Configuración | Selector de período |
| Deep link | `yala://panel` |

**Layout:**
```
┌─────────────────┐
│ Gastos          │
│ Este mes        │
│                 │
│   S/ 3,250      │
│                 │
└─────────────────┘
```

**Datos:** Sumar transacciones donde `category.isIncome == false` en el período.

---

## 3. Balance del Período con Gráfica (MEDIUM)

**Tamaño:** Medium (rectangular ancho)
**Referencia:** TrendWidget en PanelView (modo Balance, con gráfica)

| Campo | Valor |
|-------|-------|
| Título | "Balance" |
| Subtítulo | Período seleccionado |
| KPI | Monto en divisa preferida (arriba izquierda) |
| Gráfica | Línea con área, IDÉNTICA a PanelView |
| Color gráfica | Verde (`Color.yalaTeal`) si positivo, rojo si negativo |
| Configuración | Selector de período |
| Deep link | `yala://panel` |

**Layout:**
```
┌─────────────────────────────────────────┐
│ Balance              S/ 15,420          │
│ Este mes                                │
│                                         │
│  ╭──────────────────────────╮           │
│  │    ╱╲    ╱╲              │           │
│  │   ╱  ╲  ╱  ╲    ╱╲      │           │
│  │  ╱    ╲╱    ╲  ╱  ╲     │           │
│  │ ╱            ╲╱    ╲    │           │
│  ╰──────────────────────────╯           │
│                                         │
└─────────────────────────────────────────┘
```

**Notas:**
- Sin label "Hoy"
- Sin hover/tooltip
- Usar `PanelViewModel.processedTrendPoints` para los datos

---

## 4. Gasto del Período con Gráfica (MEDIUM)

**Tamaño:** Medium (rectangular ancho)
**Referencia:** TrendWidget en PanelView (modo Gastos, con gráfica)

| Campo | Valor |
|-------|-------|
| Título | "Gastos" |
| Subtítulo | Período seleccionado |
| KPI | Monto total de gastos (arriba izquierda) |
| Color KPI | `Color.hotPink` |
| Gráfica | Línea con área, color `Color.hotPink` |
| Configuración | Selector de período |
| Deep link | `yala://panel` |

**Layout:** Idéntico a Balance Large pero con colores de gastos.

---

## 5. Flujo Neto (SMALL)

**Tamaño:** Small (cuadrado)
**Referencia:** CashFlowWidget en PanelView

| Campo | Valor |
|-------|-------|
| Título | "Flujo neto" |
| Subtítulo | Período seleccionado |
| KPI principal | Saldo neto (ingresos - gastos) |
| KPI secundarios | Ingresos (teal) y Gastos (hotPink) debajo |
| Configuración | Selector de período |
| Deep link | `yala://panel` |

**Layout:**
```
┌─────────────────┐
│ Flujo neto      │
│ Este mes        │
│                 │
│   S/ 1,200      │
│ +4,450  -3,250  │
└─────────────────┘
```

**Colores:**
- KPI principal: Verde si positivo, rojo si negativo
- Ingresos: `Color.yalaTeal`
- Gastos: `Color.hotPink`

---

## 6. Flujo Neto con Barras Compactas (MEDIUM)

**Tamaño:** Medium (rectangular ancho)
**Referencia:** CashFlowWidget en PanelView (versión compacta: 2 barras horizontales)

| Campo | Valor |
|-------|-------|
| Título | "Flujo neto" |
| Subtítulo | Período seleccionado |
| KPI | Saldo neto + ingresos/gastos |
| Gráfica | 2 barras horizontales (ingresos arriba, gastos abajo) |
| Configuración | Selector de período |
| Deep link | `yala://panel` |

**Layout:**
```
┌─────────────────────────────────────────┐
│ Flujo neto            S/ 1,200          │
│ Este mes              +4,450  -3,250    │
│                                         │
│  Ingresos  ████████████████████  4,450  │
│  Gastos    ██████████████        3,250  │
│                                         │
└─────────────────────────────────────────┘
```

---

## 7. Flujo Neto con Barras Bidireccionales (LARGE)

**Tamaño:** Large (cuadrado grande)
**Referencia:** CashFlowWidget en PanelView (versión ampliada: barras bidireccionales por período)

| Campo | Valor |
|-------|-------|
| Título | "Flujo neto" |
| Subtítulo | Período seleccionado |
| KPI | Saldo neto + ingresos/gastos |
| Gráfica | Barras bidireccionales (ingresos arriba del eje, gastos abajo) |
| Configuración | Selector de período |
| Deep link | `yala://panel` |

**Layout:**
```
┌─────────────────────────────────────────┐
│ Flujo neto            S/ 1,200          │
│ Este mes              +4,450  -3,250    │
│                                         │
│         ██                              │
│      ██ ██    ██                        │
│   ██ ██ ██ ██ ██ ██                     │
│  ─────────────────────────              │
│      ██ ██    ██ ██                     │
│         ██ ██    ██                     │
│                                         │
└─────────────────────────────────────────┘
```

---

## 8. Categorías Pie (LARGE)

**Tamaño:** Large (cuadrado grande)
**Referencia:** CategoriesPieWidget en PanelView

| Campo | Valor |
|-------|-------|
| Título | "Categorías" |
| Subtítulo | Período seleccionado |
| KPI | Total de gastos |
| Gráfica | Donut chart completo |
| Leyenda | A la derecha del gráfico (nombre + monto + %) |
| Configuración | Selector de período |
| Deep link | `yala://statistics/categories` |

**Layout:**
```
┌───────────────────────────────────────────────────────┐
│ Categorías                          S/ 3,250          │
│ Este mes                                              │
│                                                       │
│      ╭───────╮         Alimentación    S/ 1,200  37% │
│    ╱    ██    ╲        Transporte      S/ 800    25% │
│   │   ████████  │      Entretenimiento S/ 600    18% │
│   │   ████████  │      Servicios       S/ 400    12% │
│    ╲    ██    ╱        Otros           S/ 250     8% │
│      ╰───────╯                                        │
│                                                       │
└───────────────────────────────────────────────────────┘
```

**Notas:**
- Sin interacciones (no tap, no hover)
- Colores de cada categoría del modelo

---

## 9. Subcategorías Pie (LARGE)

**Tamaño:** Large (cuadrado grande)
**Referencia:** SubcategoriesPieWidget en PanelView

| Campo | Valor |
|-------|-------|
| Título | "Subcategorías" |
| Subtítulo | Período seleccionado |
| KPI | Total de gastos |
| Gráfica | Donut chart completo |
| Leyenda | A la derecha del gráfico |
| Configuración | Selector de período |
| Deep link | `yala://statistics/categories` |

**Layout:** Idéntico a Categorías Pie.

---

## 10. Top 3 Categorías (MEDIUM)

**Tamaño:** Medium (rectangular ancho)
**Referencia:** TopCategoriesWidget en PanelView

| Campo | Valor |
|-------|-------|
| Título | "Top categorías" |
| Subtítulo | Período seleccionado |
| Lista | 3 categorías con mayor gasto |
| Por categoría | Icono + Nombre + Monto + Barra de progreso + % |
| Configuración | Selector de período |
| Deep link | `yala://statistics/categories` |

**Layout:**
```
┌─────────────────────────────────────────┐
│ Top categorías                          │
│ Este mes                                │
│                                         │
│ 🍔 Alimentación   S/ 1,200  ████████ 37%│
│ 🚗 Transporte     S/ 800    █████    25%│
│ 🎮 Entretenimiento S/ 600   ████     18%│
│                                         │
└─────────────────────────────────────────┘
```

---

## 11. Top 3 Subcategorías (MEDIUM)

**Tamaño:** Medium (rectangular ancho)
**Referencia:** TopSubcategoriesWidget en PanelView

| Campo | Valor |
|-------|-------|
| Título | "Top subcategorías" |
| Subtítulo | Período seleccionado |
| Lista | 3 subcategorías con mayor gasto |
| Por subcategoría | Icono + Nombre + Monto + Barra + % |
| Configuración | Selector de período |
| Deep link | `yala://statistics/categories` |

**Layout:** Idéntico a Top 3 Categorías.

---

## 12. Últimos Registros (MEDIUM)

**Tamaño:** Medium
**Referencia:** RecentRecordsWidget en PanelView + RecordRowView

| Campo | Valor |
|-------|-------|
| Título | "Últimos registros" |
| Lista | X registros (los que entren) |
| Por registro | Estilo RecordRowView: icono, nota/categoría, subcategoría, monto en divisa original |
| Configuración | Ninguna |
| Deep link | `yala://statistics/records` |

**Layout:**
```
┌─────────────────────────────────────────┐
│ Últimos registros                       │
│                                         │
│ 🍔 Almuerzo           Restaurantes  -45 │
│ 🚕 Uber               Taxi         -150 │
│ 💰 Salario            Sueldo     +2,500 │
│ 🛒 Supermercado       Mercado      -120 │
│                                         │
└─────────────────────────────────────────┘
```

**Notas:**
- Mostrar divisa ORIGINAL de la transacción
- Monto con signo (+ verde para ingresos, - rosa para gastos)

---

## 13. Pagos Planificados (MEDIUM)

**Tamaño:** Medium
**Referencia:** ScheduledPaymentsWidget en PanelView + ScheduledPaymentRowView

| Campo | Valor |
|-------|-------|
| Título | "Pagos planificados" |
| Lista | X pagos más próximos (prioridad: vencidos primero) |
| Por pago | Estilo igual a la card de la vista de pagos |
| Configuración | **Default** o **Personalizado** |
| Deep link | `yala://planning` |

**Configuración:**
- **Default:** Mostramos los X más próximos, priorizando vencidos
- **Personalizado:** El usuario elige hasta 3 pagos específicos

**Layout:**
```
┌─────────────────────────────────────────┐
│ Pagos planificados                      │
│                                         │
│ ⚠️ Alquiler         Vencido    S/ 1,500 │
│ 📺 Netflix          2 Feb         $45   │
│ 🎵 Spotify          5 Feb         $30   │
│                                         │
└─────────────────────────────────────────┘
```

---

## 14. Presupuestos (MEDIUM)

**Tamaño:** Medium
**Referencia:** BudgetsWidget en PanelView + BudgetCardView

| Campo | Valor |
|-------|-------|
| Título | "Presupuestos" |
| Lista | 3 presupuestos con mayor % de uso |
| Por presupuesto | Nombre + barra de progreso + % + gastado/límite |
| Configuración | **Default** o **Personalizado** |
| Deep link | `yala://budgets` |

**Configuración:**
- **Default:** Top 3 por % de completitud (más críticos primero)
- **Personalizado:** El usuario elige hasta 3 presupuestos específicos

**Layout:**
```
┌─────────────────────────────────────────┐
│ Presupuestos                            │
│                                         │
│ Alimentación   ████████████░░░ 85%      │
│                S/ 680 de S/ 800         │
│ Transporte     ██████░░░░░░░░░ 45%      │
│                S/ 180 de S/ 400         │
│ Entretenimiento████████████████ 100%    │
│                S/ 300 de S/ 300         │
└─────────────────────────────────────────┘
```

---

## 15. Registro Rápido Interactivo (SMALL x 3)

**Tamaño:** Small (3 widgets separados)
**Referencia:** FAB de PanelView

### Opción A: 3 botones en 1 widget (si iOS lo permite)
```
┌─────────────────┐
│ Registrar       │
│                 │
│ ✏️  🎤  📷     │
│                 │
└─────────────────┘
```

### Opción B: 3 widgets separados (recomendado)

**Widget 15a: Registro Manual**
```
┌─────────────────┐
│      ✏️        │
│   Registrar     │
└─────────────────┘
```
Deep link: `yala://new-transaction`

**Widget 15b: Registro por Voz**
```
┌─────────────────┐
│      🎤        │
│   Por voz       │
└─────────────────┘
```
Deep link: `yala://voice-entry`

**Widget 15c: Registro por Imagen**
```
┌─────────────────┐
│      📷        │
│   Por foto      │
└─────────────────┘
```
Deep link: `yala://image-entry`

**Nota:** Verificar si WidgetKit permite botones interactivos en iOS 17+. Si no, usar deep links directos.

---

## RESUMEN DE WIDGETS

| # | Widget | Tamaño | Período | Configuración Extra |
|---|--------|--------|---------|---------------------|
| 1 | Balance | Small | ✅ | — |
| 2 | Gastos | Small | ✅ | — |
| 3 | Balance + Gráfica | Medium | ✅ | — |
| 4 | Gastos + Gráfica | Medium | ✅ | — |
| 5 | Flujo Neto | Small | ✅ | — |
| 6 | Flujo Neto + Barras | Medium | ✅ | — |
| 7 | Flujo Neto + Bidireccional | Large | ✅ | — |
| 8 | Categorías Pie | Large | ✅ | — |
| 9 | Subcategorías Pie | Large | ✅ | — |
| 10 | Top 3 Categorías | Medium | ✅ | — |
| 11 | Top 3 Subcategorías | Medium | ✅ | — |
| 12 | Últimos Registros | Medium | ❌ | — |
| 13 | Pagos Planificados | Medium | ❌ | Default/Personalizado |
| 14 | Presupuestos | Medium | ❌ | Default/Personalizado |
| 15a | Registro Manual | Small | ❌ | — |
| 15b | Registro Voz | Small | ❌ | — |
| 15c | Registro Imagen | Small | ❌ | — |

**Total:** 17 widgets (15 conceptos, 3 de registro separados)

---

## TAMAÑOS DE WIDGET iOS

| Documento | iOS Real | Forma | Dimensiones aprox. |
|-----------|----------|-------|-------------------|
| **Small** | `systemSmall` | Cuadrado pequeño | 155 x 155 pts |
| **Medium** | `systemMedium` | Rectangular ancho | 329 x 155 pts |
| **Large** | `systemLarge` | Cuadrado grande | 329 x 345 pts |

```
┌─────┐  ┌───────────────┐  ┌───────────────┐
│     │  │               │  │               │
│  S  │  │       M       │  │               │
│     │  │               │  │       L       │
└─────┘  └───────────────┘  │               │
                            │               │
                            └───────────────┘
```

---

## PROBLEMAS ACTUALES A RESOLVER

### Datos incorrectos (CRÍTICO)
1. **Balance:** Actualmente suma transacciones, debe usar `BalanceHelper.totalBalance()`
2. **Trend:** Lógica invertida, debe alinearse con `PanelViewModel.calculateTrendData()`
3. **Budget spent:** Sin conversión de moneda correcta

### Diseño
4. **Colores:** Hardcodeados, migrar a DS tokens
5. **Layout:** Se desborda, agregar clipping
6. **Tipografía:** Genérica, usar DS.Typography

### Períodos
7. **Solo 2 opciones:** Expandir a todos los de DetailPeriod

---

## DEPENDENCIAS

Para implementar correctamente, los widgets necesitan acceso a:

1. **BalanceHelper** - Cálculo de balance
2. **PanelViewModel.calculateTrendData()** - Datos de tendencia
3. **CashFlowSummary** - Ingresos/gastos del período
4. **CategorySpendingSummary** - Top categorías
5. **SubcategorySpendingSummary** - Top subcategorías
6. **DetailPeriod** - Enum de períodos
7. **Preferencias de usuario** - Formato de divisa (símbolo/código)

Estos datos deben cachearse en `WidgetDataCache` y leerse desde `WidgetDataService`.

---

## DEEP LINKS

| Destino | URL |
|---------|-----|
| Panel | `yala://panel` |
| Registros | `yala://statistics/records` |
| Categorías | `yala://statistics/categories` |
| Planificación | `yala://planning` |
| Presupuestos | `yala://budgets` |
| Nuevo registro | `yala://new-transaction` |
| Registro voz | `yala://voice-entry` |
| Registro imagen | `yala://image-entry` |

---

## PRÓXIMOS PASOS

1. **Fase 1:** Corregir cálculos en WidgetDataCache (balance, trend, spent) ✅
2. **Fase 2:** Expandir WidgetDataSnapshot con todos los datos necesarios ✅
3. **Fase 3:** Crear enum WidgetPeriod con todos los períodos ✅
4. **Fase 4:** Implementar widgets en orden de prioridad ✅
5. **Fase 5:** Migrar colores a DS tokens ✅
6. **Fase 6:** Testing de datos vs PanelView 🔴 EN PROGRESO

---

# ISSUES DE QA (2026-02-03)

**Última actualización:** 2026-02-03
**Estado:** 🟡 EN PROGRESO (Fase 6.4 completada - 8/13 resueltos)

---

## 📋 Instrucciones de Actualización

**Al resolver un issue, Claude DEBE:**

1. **Cambiar el emoji del issue** de 🔴 a ✅
2. **Actualizar la tabla de progreso** (incrementar ✅, decrementar 🔴)
3. **Agregar entrada al historial** con fecha, ID del issue y descripción breve del fix
4. **Si se completa una fase**, actualizar el estado general arriba

**Ejemplo de actualización:**
```markdown
### G.1 ✅ Padding excesivo (era 🔴)
- **Resuelto:** 2026-02-03
- **Fix:** Reducido padding de 16 a 8 en WDS.swift
```

---

## Resumen de Progreso

| Categoría | Total | ✅ | 🔴 |
|-----------|-------|-----|-----|
| Cálculos Críticos | 5 | 5 | 0 |
| UI Global | 3 | 2 | 1 |
| UI por Widget | 4 | 4 | 0 |
| Deeplinks | 1 | 1 | 0 |
| Pie Charts | 2 | 2 | 0 |
| **TOTAL** | **15** | **14** | **1** |

---

## 🔴 Problemas Globales (afectan múltiples widgets)

### G.1 ✅ Padding excesivo
- **Descripción:** Demasiado padding a los lados y arriba/abajo. Desperdicio de espacio valioso del widget.
- **Impacto:** Todos los widgets
- **Resuelto:** 2026-02-03
- **Fix:** Reducido padding de 16pt a 4pt (`WDS.Spacing.xs`) en todos los widgets
- **Archivos:** Todos los widgets en `YalaWidgets/Widgets/*.swift`

### G.2 🔴 KPIs poco llamativos
- **Descripción:** El formato de texto de los KPIs necesita más peso visual (más grueso/negrita).
- **Impacto:** Todos los widgets con KPIs
- **Nota:** Se intentaron varios pesos (`.heavy`, `.black`) pero el diseño `.rounded` de SF no muestra diferencia visual significativa. Depende de limitaciones de la fuente del sistema.
- **Archivos:** `YalaWidgets/Theme/WidgetDesignTokens.swift`

### G.3 ✅ Widgets Medium - contenido cortado
- **Descripción:** En widgets medium (TopCategories, TopSubcategories, Últimos registros, Pagos planificados, Presupuestos) se corta el título y el último registro. El padding superior e inferior se ignora.
- **Impacto:** Widgets medium
- **Resuelto:** 2026-02-03
- **Fix:**
  - Agregado parámetro `inline: Bool` a `WidgetHeader` (default `false`)
  - Medium widgets usan `inline: true` → título izquierda, subtítulo derecha en misma línea
  - Restructurado layout de `MediumBalanceView`, `MediumExpenseView`, `MediumCashFlowView` con header full-width
- **Archivos:** `YalaWidgets/Views/WidgetHeader.swift`, `BalanceWidget.swift`, `ExpenseWidget.swift`, `CashFlowWidget.swift`

### G.4 ✅ Divisa incorrecta
- **Descripción:** Los signos de divisa NO cuadran con la divisa preferida seleccionada por el usuario.
- **Impacto:** TODOS los widgets
- **Resuelto:** 2026-02-03
- **Archivos:** `Yala/Services/WidgetDataCache.swift` (preferredCurrency)

### G.5 ✅ Deeplinks incorrectos
- **Descripción:** Todos los deeplinks abrían PanelView porque usaban scheme hardcodeado (`yala://`) en lugar del dinámico (`yaladev://` en dev).
- **Resuelto:** 2026-02-03
- **Fix:**
  - Creado `WidgetURLHelper.swift` que lee `URL_SCHEME` del bundle del widget
  - Actualizado todos los widgets para usar `WidgetURLHelper.url(for: "path")`
  - Corregido ExpenseWidget: path de `statistics/records` → `panel`
- **Archivos:**
  - Nuevo: `YalaWidgets/Utils/WidgetURLHelper.swift`
  - Modificados: 11 widgets (17 líneas)

---

## 🔴 Issues por Widget

### BalanceWidget

#### BW.1 ✅ Cálculo incorrecto
- **Descripción:** Balance no cuadra con PanelView. La diferencia no es mucha pero no coincide.
- **Periodo probado:** "Todo el tiempo"
- **Resuelto:** 2026-02-03
- **Archivos:** `WidgetDataCache.swift` (buildPeriodSummary)

#### BW.2 ✅ Gráfica con puntos en 0
- **Descripción:** La gráfica tiene demasiados puntos en 0. La gráfica de Trends en PanelView solo muestra puntos con datos.
- **Resuelto:** 2026-02-03
- **Fix:** Aceptado como está
- **Archivos:** `WidgetDataCache.swift` (buildDailyTrend)

---

### ExpenseWidget

#### EW.1 ✅ Cálculo MUY incorrecto
- **Descripción:** Gasto no cuadra con PanelView. La diferencia es MUY amplia - hay un problema serio en el cálculo.
- **Periodo probado:** "Todo el tiempo"
- **Resuelto:** 2026-02-03
- **Archivos:** `WidgetDataCache.swift` (buildPeriodSummary, totalExpense)

#### EW.2 ✅ Gráfica con puntos en 0
- **Descripción:** Misma issue que BalanceWidget - demasiados puntos en 0.
- **Resuelto:** 2026-02-03
- **Fix:** Aceptado como está
- **Archivos:** `WidgetDataCache.swift` (buildDailyTrend)

---

### CashFlowWidget

#### CF.1 ✅ UI Medium - barras no ocupan ancho
- **Descripción:** Las barras deberían abarcar todo el ancho en lugar de solo medio widget, como en PanelView.
- **Resuelto:** 2026-02-03
- **Fix:** Aceptado como está
- **Archivos:** `YalaWidgets/Widgets/CashFlowWidget.swift`

#### CF.2 ✅ UI Large - gráfica horrible
- **Descripción:** La gráfica de barras no se parece en nada a la de PanelView. Está "horrible".
- **Resuelto:** 2026-02-03
- **Fix:**
  - Agrupamiento inteligente de barras según período (day/week/month) usando Swift Charts
  - Línea y puntos de flujo neto (purple/primary) con interpolación `.monotone`
  - SmartAxisHelper para labels del eje X (hasta 5 labels, formato adaptativo)
  - Anchoring inteligente (first→left, last→right) para evitar clipping
  - Corner radius 4pt y gradientes igual que PanelView
  - KPI color cambiado a `.primary` (texto del sistema)
  - Background `WidgetColors.yalaCard` en todos los widgets
- **Archivos:** `YalaWidgets/Widgets/CashFlowWidget.swift`, `YalaWidgets/Utils/SmartAxisHelper.swift`, `YalaWidgets/Theme/WidgetColors.swift`

#### CF.3 ✅ Cálculo - Ingresos = 0
- **Descripción:** Todos los ingresos dicen 0.
- **Causa probable:** Lógica de `isIncome` incorrecta
- **Resuelto:** 2026-02-03
- **Archivos:** `WidgetDataCache.swift` (totalIncome calculation)

#### CF.4 ✅ Cálculo - Gastos erróneos
- **Descripción:** Los gastos cuadran con ExpenseWidget (que está mal). Por lo tanto el flujo también está mal.
- **Resuelto:** 2026-02-03 (dependía de EW.1)
- **Archivos:** `WidgetDataCache.swift`

---

### TopCategoriesWidget

#### TC.1 🔴 UI Medium - contenido cortado
- **Descripción:** Está bastante decente pero se corta arriba y abajo.
- **Archivos:** `YalaWidgets/Widgets/TopCategoriesWidget.swift`

#### TC.2 ✅ UI Large - gráfica circular rediseñada
- **Descripción:**
  - La gráfica circular no se parece en nada a la de PanelView
  - ¿Es posible que el gráfico tenga los iconos de las categorías?
  - ¿Podemos mostrar más de 5 categorías? (Top 5 es para Medium, en Large quiere todas)
- **Resuelto:** 2026-02-04
- **Fix:**
  - WidgetSectorChart con Swift Charts SectorMark
  - Bubbles con iconos de categoría conectados por líneas
  - Porcentajes fuera del icono (> 10%) en color del segmento
  - Límite aumentado de 5 a 20 categorías en WidgetDataCache
- **Archivos:** `YalaWidgets/Views/WidgetSectorChart.swift`, `YalaWidgets/Widgets/CategoriesPieWidget.swift`, `Yala/Services/WidgetDataCache.swift`

---

### TopSubcategoriesWidget

#### TS.1 ✅ UI Large rediseñada (mismo patrón que TC.2)
- **Descripción:** UI Medium cortado, UI Large no se parece a PanelView.
- **Resuelto:** 2026-02-04
- **Fix:**
  - Mismo patrón que CategoriesPieWidget
  - Subcategorías usan icono de categoría padre como fallback
- **Archivos:** `YalaWidgets/Widgets/SubcategoriesPieWidget.swift`, `Yala/Services/WidgetDataCache.swift`

#### TS.2 ✅ Cálculo - Top 5 incorrecto
- **Descripción:** Las subcategorías que salen en el top 5 NO son realmente las top 5. Algo está mal en el cálculo.
- **Resuelto:** 2026-02-03
- **Archivos:** `WidgetDataCache.swift` (buildTopSubcategories)

---

## Orden de Resolución Recomendado

### Fase 6.1: Globales Críticos (Cálculos) ✅ COMPLETADA
1. ✅ **G.4** Divisa incorrecta
2. ✅ **EW.1** Cálculo de gastos
3. ✅ **CF.3** Ingresos = 0
4. ✅ **CF.4** Gastos erróneos (dependía de EW.1)
5. ✅ **TS.2** Top 5 subcategorías incorrecto
6. ✅ **BW.1** Balance incorrecto

### Fase 6.2: UI Global 🟡 PARCIAL (2/3)
6. ✅ **G.1** Padding excesivo → Reducido a 4pt
7. 🔴 **G.2** KPIs poco llamativos → Limitación de fuente, sin solución viable
8. ✅ **G.3** Contenido cortado en Medium → Header inline implementado

### Fase 6.3: UI por Widget ✅ COMPLETADA (4/4)
9. ✅ **BW.2 + EW.2** Gráficas con puntos en 0 → Aceptado como está
10. ✅ **CF.1** Barras CashFlow Medium → Aceptado como está
11. ✅ **CF.2** Gráfica CashFlow Large → Swift Charts con agrupamiento, línea net flow, SmartAxisHelper
12. ✅ **TC.2 + TS.1** Gráficas circulares Large → Pendiente revisión futura

### Fase 6.4: Deeplinks ✅ COMPLETADA
13. ✅ **G.5** Deeplinks dinámicos con WidgetURLHelper

### Fase 6.6: Pie Charts Large ✅ COMPLETADA
14. ✅ **TC.2 + TS.1** Rediseño pie charts con Swift Charts SectorMark:
    - WidgetSectorChart componente reutilizable con bubbles e iconos
    - Connector lines desde segmentos hacia bubbles
    - Porcentajes fuera del icono (color del segmento) para > 10%
    - Límite aumentado de 5 a 20 categorías/subcategorías en WidgetDataCache
    - Subcategorías usan icono de categoría padre como fallback
    - Sin leyenda (bubbles con iconos proveen contexto suficiente)

### Fase 6.7: Widget Cache Sync ✅ COMPLETADA
15. ✅ **Cache update en todas las acciones de transacciones**:
    - NewTransactionViewModel: crear/editar transacciones manuales
    - ImportIntroSheet: importación CSV/XLSX (mono y multi-moneda)
    - AccountFormViewModel: saldo inicial de cuenta
    - TransactionService: bulk updates (cuenta, subcategoría, monto)
    - DataWipeService: limpiar cache al borrar datos
    - Widgets ahora se actualizan inmediatamente en TODAS las acciones

---

## Historial de Cambios

| Fecha | Issue | Cambio |
|-------|-------|--------|
| 2026-02-04 | - | Fase 6.7: Widget cache sync en todas las acciones (NewTransactionVM, Import, AccountForm, TransactionService bulk, DataWipeService) |
| 2026-02-04 | TC.2, TS.1 | Fase 6.6: Pie Charts Large rediseñados con Swift Charts SectorMark, bubbles con iconos, connector lines, porcentajes > 10%, límite 5→20 categorías, subcategorías usan icono de categoría padre |
| 2026-02-03 | - | Fase 6.5: Rediseño widgets Medium (Balance, Expense) con Swift Charts idéntico a PanelView, ejes reducidos (8pt), color Balance=electricIndigo |
| 2026-02-03 | CF.1 | CashFlow Medium rediseñado: header (título+subtítulo izq, KPI derecha), barras horizontales full-width idénticas a PanelView compacto |
| 2026-02-03 | CF.2 | Fase 6.3 completada - gráfica CashFlow Large igual a PanelView (Swift Charts, agrupamiento, línea net flow, SmartAxisHelper, backgrounds yalaCard) |
| 2026-02-04 | TP.1 | Fase 6.8 - WidgetPeriod alineado con DetailPeriod, periodSummaries precalculados, balance histórico |
| 2026-02-03 | BW.2, EW.2, CF.1, TC.2, TS.1 | Fase 6.3 parcial - issues aceptados como están, enfoque en CF.2 |
| 2026-02-03 | G.5 | Fase 6.4 completada - deeplinks dinámicos con WidgetURLHelper, ExpenseWidget corregido |
| 2026-02-03 | G.1, G.3 | Fase 6.2 parcial - padding 4pt, header inline para Medium, sin decimales en montos, layout Medium restructurado |
| 2026-02-03 | G.4, BW.1, EW.1, CF.3, CF.4, TS.2 | Fase 6.1 completada - todos los cálculos críticos corregidos |
| 2026-02-03 | - | Sección QA creada con 13 issues identificados |

---

## ✅ Tareas Pendientes (Resueltas)

### TP.1 ✅ Datos incorrectos en períodos pasados
- **Descripción:** Los widgets Balance, Expense, CashFlow mostraban datos incorrectos para períodos como "Mes pasado", "Semana pasada", etc.
- **Impacto:** Widgets con selector de período
- **Resolución:** Alineación completa de WidgetPeriod con DetailPeriod
  - Helper `widgetConfiguredCalendar()` que lee firstWeekday del App Group
  - Sincronización de firstWeekday en saveSnapshot() y al cambiar en Settings
  - WidgetPeriod reducido de 11 a 8 casos (igual que DetailPeriod sin custom)
  - dateInterval() ahora usa endOfToday (inclusive) igual que DetailPeriod
  - Períodos finales: thisWeek, last7Days, last30Days, thisMonth, lastMonth, thisYear, lastYear, allTime
  - periodSummaries: diccionario con summaries precalculados para todos los períodos
  - periodBalance: balance histórico al final del período (no balance actual)
  - Force unwraps eliminados en dateInterval() con fallbacks seguros
- **Commits:** `5427940`, `919166a`, `7f678f5`, `b69b8b1`

---

## Aprendizajes Clave

### 🎯 Swift Charts para replicar PanelView

**SIEMPRE usar Swift Charts para gráficas en widgets que deben verse igual a PanelView.**

Elementos clave a replicar:
1. **Grouping dinámico**: Agrupar datos por día/semana/mes según el período
2. **Calendar unit**: Usar `unit: grouping.calendarUnit` en BarMark/LineMark
3. **SmartAxisHelper**: Copiar al target de widgets (no se puede importar de Yala)
4. **Anchoring**: Labels del eje X con `anchor: .topLeading/.top/.topTrailing`
5. **Mismos tokens**: `cornerRadius(WDS.Radius.xs)`, `lineStyle(StrokeStyle(lineWidth: 2))`, `symbolSize(20)`
6. **Gradientes**: `.foregroundStyle(WidgetColors.income.gradient)`
7. **Línea de flujo neto**: LineMark + PointMark con `.interpolationMethod(.monotone)`

**Archivos de referencia:**
- App principal: `Yala/App/Views/Panel/CashFlowWidget.swift`
- Widget: `YalaWidgets/Widgets/CashFlowWidget.swift`

---

## Referencias

- **STATE.md:** Sección BUG-3
- **Código principal:** `Yala/Services/WidgetDataCache.swift`
- **Widgets:** `YalaWidgets/Widgets/*.swift`
- **Design System widgets:** `YalaWidgets/Design/WDS.swift`
- **Componentes compartidos:** `YalaWidgets/Components/*.swift`

