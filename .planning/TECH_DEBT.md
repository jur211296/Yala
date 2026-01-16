# Technical Debt & TODOs Audit

**Audit Date:** 2026-01-15

## Active TODOs

### High Priority (Blocks Features)

**Budget Monitoring in Background:**
- File: `Neto/Services/BackgroundJobs.swift:24`
- Code: `// TODO: Check budgets`
- Context: Background task runs daily but doesn't check budget thresholds
- Impact: No proactive budget alerts/notifications
- Related to: Fase 8 (Notificaciones)
- Effort: Medium

### Low Priority (Future Features)

**Alias Personalization:**
- File: `Neto/App/Views/Profile/PersonalDetailsView.swift:214`
- Code: `// TODO: Future feature note`
- Context: Placeholder for future alias display feature
- Impact: None - just informational text shown
- Effort: Low

---

## Deprecated Code (To Remove)

### Design System Legacy Aliases

**Location:** `Neto/App/Theme/DesignTokens.swift:215-254`

```swift
@available(*, deprecated, message: "Use DS instead")
enum DesignTokens { ... }
```

- Contains: `AppSpacing`, `AppRadius`, `AppOpacity`
- Status: Marked deprecated, should search for usages
- Action: Remove when all usages migrate to `DS.*`

### Currency Utils Legacy

**Location:** `Neto/Utils/CurrencyUtils.swift:66`

```swift
/// @deprecated Usar CurrencyConverter.shared para tasas actualizadas.
```

- Action: Audit usages and remove function

### ViewModel Date Range Properties

**RecordsViewModel:** `Neto/App/ViewModels/RecordsViewModel.swift:48,52`
```swift
/// Custom date range start (for backward compat, deprecated)
var customStartDate: Date?
/// Custom date range end (for backward compat, deprecated)
var customEndDate: Date?
```

**StatisticsViewModel:** `Neto/App/ViewModels/StatisticsViewModel.swift:96,100`
- Same pattern - deprecated properties
- Action: Remove when period selector fully migrated

### CurrencyConverter Sync Method

**Location:** `Neto/Services/CurrencyConverter.swift:92`
```swift
/// Will be deprecated once all calculators are updated to use async version.
```

- Action: Track async migration progress

---

## Important Implementation Notes

These are not TODOs but critical notes for maintenance:

### Data Wipe Safety
**File:** `Neto/Utils/DataWipeService.swift:32`
```swift
// IMPORTANT: Clear many-to-many tag relationships on BOTH sides to avoid batch delete constraint violation
```
- Risk: SwiftData crash if relationships not cleared before delete
- Must maintain when adding new many-to-many relationships

### Query Observer Safety
**File:** `Neto/App/ContentView.swift:46`
```swift
// IMPORTANT: When wiping data, completely unmount the TabView to deactivate all @Query observers
```
- Risk: Crash if @Query observers active during wipe
- Pattern: Use `wipingData` flag to unmount views

### Filter Consistency
**File:** `Neto/App/ViewModels/PanelViewModel.swift:650`
```swift
// IMPORTANT: Must apply the same global filters as 'filtered' to ensure consistency
```
- Risk: UI inconsistency if filters differ between calculations

### SwiftData Relationship Deletion
**File:** `Neto/Models/Category.swift:31`
```swift
// NOTE: Using nullify instead of cascade - manual deletion handles subcategories to avoid SwiftUI @Query conflicts
```
- Pattern: Use manual deletion for nested entities

---

## Print Statements (Debug Cleanup)

Files with print statements that should be guarded with `#if DEBUG`:

| File | Count | Lines |
|------|-------|-------|
| `ExchangeRateAPIService.swift` | 3 | Various |
| `BackgroundJobs.swift` | 1 | 14 |
| `ImportIntroSheet.swift` | 7 | Various |
| `DetailContainerView.swift` | 4 | Various |

**Action:** Wrap in `#if DEBUG` or remove before production

---

## DispatchQueue Usage (To Migrate)

Files using old-style `DispatchQueue.main.asyncAfter()`:

| File | Instances |
|------|-----------|
| `DetailContainerView.swift` | 2 |
| `ImportIntroSheet.swift` | 7 |
| `BudgetPeriodSelectorSheet.swift` | 3 |
| `ProfileView.swift` | 1 |

**Action:** Migrate to `Task { try? await Task.sleep() }`

---

## Summary

| Category | Count | Priority |
|----------|-------|----------|
| Active TODOs | 2 | 1 High, 1 Low |
| Deprecated Code | 4 areas | Medium |
| Print Cleanup | 15+ | Low |
| DispatchQueue Migration | 13 | Low |

---

*Next audit: After Fase 6 completion*
