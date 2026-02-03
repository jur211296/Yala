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
| **Períodos** | Mismos que PanelView: Hoy, Ayer, Esta semana, Semana pasada, Este mes, Mes pasado, Este trimestre, Trimestre pasado, Este año, Año pasado, Todo el tiempo |
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

1. **Fase 1:** Corregir cálculos en WidgetDataCache (balance, trend, spent)
2. **Fase 2:** Expandir WidgetDataSnapshot con todos los datos necesarios
3. **Fase 3:** Crear enum WidgetPeriod con todos los períodos
4. **Fase 4:** Implementar widgets en orden de prioridad
5. **Fase 5:** Migrar colores a DS tokens
6. **Fase 6:** Testing de datos vs PanelView

