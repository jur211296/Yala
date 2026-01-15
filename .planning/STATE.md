# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-01-13)

**Core value:** Registrar y entender gastos, cuentas, presupuestos y reportes con claridad
**Current focus:** Fase 4 — Panel y Navegación — Completada

## Current Position

Phase: 4 of 8 (Panel y Navegación)
Plan: Completed
Status: 3/3 items done
Last activity: 2026-01-15 — Widget de Presupuestos completado + múltiples bug fixes

Progress: ██████████ 100%

## Feature completada: Widget de Presupuestos en PanelView ✅

### Commits realizados (completos)
1. `c75f634` - feat(budgets): Añadir modelo y tipo de widget para presupuestos
2. `17498fd` - feat(budgets): Crear vistas BudgetsWidget y BudgetWidgetRow
3. `ff47c75` - feat(budgets): Integrar widget en PanelView con cálculo de datos
4. `193d9cd` - feat(budgets): Añadir interactividad al widget con toggle y dimming
5. `56b2365` - feat(budgets): Añadir gestión de favoritos en Profile
6. `6135f92` - feat(budgets): Añadir botón "Seleccionar favoritos" en widget vacío
7. `89beb71` - feat(budgets): Añadir acceso directo a favoritos desde BudgetsListView
8. `15e3a4e` - fix(budgets): Refrescar widget al cambiar favoritos y mover botón estrella
9. `1b57a60` - fix(budgets): Refrescar widget desde cualquier vista al modificar favoritos
10. `723c52f` - feat(budgets): Añadir botón de eliminar en editor de presupuestos
11. `7121d05` - fix(budgets): Mejorar estilo del botón eliminar y corregir localizaciones

### Funcionalidad completa

**Widget en Panel:**
- Muestra budgets favoritos ordenados por `favoriteOrder`
- Soporte `.medium` (top 3) y `.large` (top 5)
- Empty states: "Sin presupuestos" vs "Sin favoritos" con botón "Seleccionar favoritos"
- Tap en budget aplica sus filtros globalmente (accounts, subcategories, tags, natures)
- Toggle de selección con dimming visual

**Gestión de favoritos:**
- `BudgetsFavoritesSettingsView` en Profile → Organización → Presupuestos favoritos
- Toggle estrella para marcar/desmarcar favoritos
- Modo edición para reordenar favoritos (drag & drop)
- Acceso rápido desde Planning/Budgets (botón estrella en toolbar, izquierda del perfil)
- Refresco inmediato del widget al modificar favoritos (desde cualquier vista)

**Editor de presupuestos:**
- Botón "Eliminar presupuesto" al final del editor (solo en edición)
- Confirmación antes de eliminar
- Estilo consistente con cornerRadius: 24

### Archivos clave

```
Neto/Models/Budget.swift                               # +isFavorite, +favoriteOrder, @Relationship inversas
Neto/App/Models/WidgetModels.swift                     # +case budgets
Neto/App/Models/SessionState.swift                     # +needsBudgetsWidgetRefresh, +applyBudgetFilters()
Neto/App/Views/Panel/BudgetsWidget.swift               # Widget completo con interactividad
Neto/App/Views/Panel/BudgetWidgetRow.swift             # Fila compacta
Neto/App/ViewModels/PanelViewModel.swift               # +calculateBudgetsWidget()
Neto/App/Views/Panel/PanelView.swift                   # Integración + onChange(budgets)
Neto/App/Views/Settings/BudgetsFavoritesSettingsView.swift  # Gestión de favoritos
Neto/App/Views/Planning/PlanningView.swift             # +botón estrella en toolbar
Neto/App/Views/Planning/BudgetEditorView.swift         # +botón eliminar
```

## Bug Fixes (Sesión 2026-01-15)

### Críticos
- **Fix: Filtrado de subcategorías por ID** (`81af652`)
  - Problema: Subcategorías con nombres duplicados (ej: "Otros" en Compras y Hogar) causaban filtrado incorrecto
  - Solución: Cambiar de `selectedSubcategoryNames: Set<String>` a `selectedSubcategoryIDs: Set<PersistentIdentifier>`
  - Archivos: SessionState, PanelViewModel, SharedModels, widgets de categorías/subcategorías

- **Fix: Filtros globales en widgets** (`7af8d89`)
  - Problema: Tag, currency, amount, search no se aplicaban a PieCategories, TopCategories, PieSubcategories, TopSubcategories
  - Solución: Derivar `contextTransactions` de `expenseFiltered` (que ya tiene todos los filtros)

- **Fix: Relaciones many-to-many de Budget** (`44d94b9`)
  - Añadir `@Relationship(inverse:)` explícitos para accounts, subcategories, tags
  - Actualizar DataWipeService para limpiar relaciones antes de eliminar

### Exchange Rate
- `c535939` - feat(exchangeRate): Smart axis labels + fix edge case start==end
- `41adf86` - refactor(app): Extraer loadExchangeRates() reutilizable
- `389208c` - feat(import): Cargar tipos de cambio para transacciones importadas
- `233bdbb` - feat(settings): Recargar tipos de cambio después de borrar datos

## Completed (Fase 4) ✅

- [x] Chevron en widgets para redirigir a detalle
- [x] Widget de Presupuestos (completo con todas las funcionalidades)
- [x] Home configurable (widgets configurables desde preferencias)

## Completed (Fases 1-3) ✅

Ver historial completo en commits anteriores.

## Next Phase: Fase 5 — Gráficas de Estadísticas

Según ROADMAP.md, la siguiente fase incluye:
- Mejorar gráficas existentes
- Añadir nuevos tipos de visualización
- Optimizar rendimiento de cálculos

## Risk/Notes

- `selectedSubcategoryIDs` usa `PersistentIdentifier` para evitar duplicados por nombre
- `needsBudgetsWidgetRefresh` flag en SessionState para sincronizar widget desde cualquier vista
- Budget many-to-many relationships requieren limpieza explícita en DataWipeService
- cornerRadius: 24 es el estándar para botones/cards en la app

## Session Continuity

Last session: 2026-01-15 12:35
Stopped at: Fase 4 completada
Next step: Revisar ROADMAP.md para Fase 5
Resume file: None
