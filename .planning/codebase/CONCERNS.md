# Codebase Concerns

**Analysis Date:** 2026-01-15
**Updated:** 2026-03-24

## Estado general
La mayoria de las concerns originales han sido resueltas. Este archivo documenta lo que queda pendiente.

## Tech Debt activa

**DispatchQueue en algunas vistas:**
- Issue: `DispatchQueue.main.asyncAfter()` en vez de Swift Concurrency
- Archivos conocidos:
  - `DetailContainerView.swift` (2 instancias)
  - `ImportIntroSheet.swift` (7 instancias)
  - `BudgetPeriodSelectorSheet.swift` (3 instancias)
- Impacto: Bajo — funciona, pero no sigue el patron moderno
- Fix: Reemplazar con `Task { try? await Task.sleep(for:) }`

## Concerns resueltas (2026-01-15 → 2026-03-24)

- ~~API key hardcodeada~~ — Movida a Secrets.xcconfig
- ~~Print statements sin #if DEBUG~~ — Guardados con DEBUG flag
- ~~Missing inverse relationships SwiftData~~ — Agregadas con @Relationship(inverse:)
- ~~ViewModels sin tests~~ — 36 ViewModels testeados, 1085 tests totales
- ~~No analytics~~ — TelemetryDeck integrado
- ~~No iCloud sync~~ — CloudKit implementado
- ~~Coverage <10%~~ — Coverage significativamente mejorada

## Areas fragiles (monitorear)

**CSV Import Service:**
- `TransactionCSVImportService.swift` — complejo, multiples formatos
- Tiene tests (`TransactionsExportServiceTests` — 26 tests)
- Monitorear cuando se agreguen nuevos formatos

**SwiftData Migrations:**
- Sin migration handlers formales
- Estrategia actual: defaults en todas las propiedades nuevas (compatible con CloudKit)
- Monitorear cuando se hagan cambios de esquema grandes

---

*Last updated: 2026-03-24*
