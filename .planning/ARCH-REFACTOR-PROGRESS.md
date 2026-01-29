# Progreso Refactoring Arquitectural

**Inicio:** 2026-01-29
**Objetivo:** Mejorar testabilidad y separación de capas

## Estado Actual

**Fase:** A - Servicios Stateless → @Environment
**Incremento:** A.1 - CurrencyConverter
**Status:** 🔄 En progreso

## Resumen de Fases

| Fase | Descripción | Incrementos | Estado |
|------|-------------|-------------|--------|
| A | Singletons → @Environment | 3 | 🔄 En progreso |
| B | SessionState consistente | 2 | ⏳ Pendiente |
| C | Services para ModelContext | 3 | ⏳ Pendiente |
| D | @Query → ViewModels | 7 | ⏳ Pendiente |

## Fase A: Servicios Stateless → @Environment

### A.1: CurrencyConverter (33 usos en 17 archivos)
- **Estado:** 🔄 En progreso
- **Archivos a modificar:**
  - [ ] `CurrencyConverter.swift` - Agregar @Observable, remover .shared
  - [ ] `YalaApp.swift` - Agregar .environment(CurrencyConverter())
  - [ ] 17 archivos que usan CurrencyConverter.shared

**Patrón de cambio:**
```swift
// ANTES
CurrencyConverter.shared.convert(...)

// DESPUÉS
@Environment(CurrencyConverter.self) private var currencyConverter
currencyConverter.convert(...)
```

### A.2: ExchangeRateService (16 usos)
- **Estado:** ⏳ Pendiente

### A.3: Vision/Voice Services (3 usos)
- **Estado:** ⏳ Pendiente

## Fase B: SessionState.shared → @Environment

### B.1: Widget refresh flags (5 Views)
- **Estado:** ⏳ Pendiente
- **Views:** ImportIntroSheet, UserDataResetView, BudgetsFavoritesSettingsView, BudgetEditorView, PersonalizationSettingsView

### B.2: Otros accesos (2 Views)
- **Estado:** ⏳ Pendiente
- **Views:** OnboardingView, StatisticsView

## Fase C: Services para ModelContext

### C.1: DraftService
- **Estado:** ⏳ Pendiente

### C.2: EntityDeletionService
- **Estado:** ⏳ Pendiente

### C.3: TransactionService
- **Estado:** ⏳ Pendiente

## Fase D: @Query → ViewModels

### D.1-D.7: 48 Views total
- **Estado:** ⏳ Pendiente

## Commits Realizados

(Se actualiza automáticamente)

## Notas Técnicas

- CurrencyConverter es stateless, ideal para @Environment
- Mantener backward compatibility durante migración
- Verificar que no hay dependencias circulares
