# Auditoría de Backgrounds en Sheets - Dark Mode

**Fecha:** 2026-01-30
**Bug:** Sheets con background negro en dark mode (debería ser Color.yalaCard)

---

## Casos Identificados por el Usuario

1. **AccountTypeSelectorView.swift** (Tipo de cuenta - creación de cuenta)
   - Líneas: 14-34
   - Problema: `List` sin `.scrollContentBackground(.hidden).background(Color.yalaCard)`
   - Estado: ❌ Pendiente

2. **AdjustmentModeSelectorView.swift** (Selección de ajuste - edición de cuenta)
   - Líneas: 14-41
   - Problema: `List` sin `.scrollContentBackground(.hidden).background(Color.yalaCard)`
   - Estado: ❌ Pendiente

---

## Casos Adicionales Encontrados en Auditoría

### Sheets/Modals que Requieren Corrección

3. **PeriodSelectorComponents.swift** - `CustomPeriodPickerSheet`
   - Líneas: 100-195
   - Problema: Tiene `.scrollContentBackground(.hidden)` pero usa `.background(Color.yalaBackground)` en vez de `.background(Color.yalaCard)`
   - Estado: ❌ Pendiente

4. **ExportFiltersStepView.swift** - `ExportCustomPeriodPickerSheet`
   - Líneas: 674-713
   - Problema: Sheet con List sin background correcto
   - Estado: ❌ Pendiente

5. **RecordsFiltersView.swift** - Sheets internos
   - Sheets: `accountsSheetView`, `tagsSheetView`, `currencySheetView`
   - Líneas: 469-583
   - Problema: NavigationStack con List sin `.scrollContentBackground(.hidden).background(Color.yalaCard)`
   - Estado: ❌ Pendiente

6. **InboxView.swift** - Verificar sheets
   - Sheets: `InboxDraftEditSheet`, `InboxBulkActionsSheet`
   - Líneas: 122-193
   - Problema: Verificar si tienen background correcto
   - Estado: ⚠️ Requiere verificación

---

## Archivos Correctos (No Requieren Cambios)

- **BudgetsFavoritesSettingsView.swift** - Navigation destination (no es sheet)
- **TagsSettingsListView.swift** - Navigation destination (no es sheet)
- **AccountsSettingsListView.swift** - Navigation destination (no es sheet)
- **TabBarConfigView.swift** - Navigation destination (no es sheet)
- **ScheduledPaymentsSettingsView.swift** - Navigation destination (no es sheet)
- **WidgetPreferencesView.swift** - Navigation destination (no es sheet)
- **FavoritesListView.swift** - Navigation destination (no es sheet)
- **FilterComponents.swift** - Subcomponentes, no sheets independientes

---

## Patrón de Corrección

```swift
// ANTES (incorrecto)
List {
    ForEach(...) { item in
        // contenido
    }
}
.navigationTitle("...")

// DESPUÉS (correcto para sheets)
List {
    ForEach(...) { item in
        // contenido
    }
}
.scrollContentBackground(.hidden)
.background(Color.yalaCard)
.navigationTitle("...")
```

---

## Total de Archivos a Corregir

**6 archivos** requieren corrección:
1. AccountTypeSelectorView.swift ✅
2. AdjustmentModeSelectorView.swift ✅
3. PeriodSelectorComponents.swift
4. ExportFiltersStepView.swift
5. RecordsFiltersView.swift
6. InboxView.swift (verificar)

---

**Estado:** Incremento 2 - Auditoría completada
**Siguiente:** Incremento 3 - Aplicar correcciones
