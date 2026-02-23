# Plan: Release Review Batches 8, 9 & 10

## Context

Batches 1–7 of the Release Review are complete (bugs, HIGH fixes, L10N toolbar labels, A11Y labels, DS semantic tokens, onTapGesture→Button). ~67 items remain unchecked in RELEASE-REVIEW.md across 5 categories: EMPTY (7), CODE (30+), DS (7), L10N (11), A11Y (24+).

**Already deferred (won't touch):**
- `[>]` HIGH-2/3/12/13 (performance — post-release)
- `[>]` HIGH-24 / A11Y-41 (onboarding a11y — post-release)
- `[-]` L10N-8 (transfer category search by Spanish name — risky data layer)
- `[-]` L10N-18 (SeedCategoryPreview — cosmetic, onboarding only)

**Verify first:** DS-5 (FAB 56→token) and DS-6 (chevron→.secondary) may already be done in batch 7 — check before re-doing.

---

## Batch 8: Empty States (7 items, ~10 files, LOW risk)

**Strategy:** Use `YalaEmptyState` for medium/large views. Keep inline compact for small widgets/popovers.

| Item | File | Fix |
|------|------|-----|
| EMPTY-1 | 11 Panel widgets | Replace custom inline empty states with `YalaEmptyState` convenience inits where layout allows. Small widgets (pie slices, trend line) keep compact text — only medium/large widgets migrate |
| EMPTY-2 | PanelView.swift:961 | CashFlowWidget `EmptyView()` → `YalaEmptyState.noTransactions()` |
| EMPTY-3 | PanelView.swift:464 | 0 accounts → `YalaEmptyState.noAccounts(action: { /* navigate to add account */ })` |
| EMPTY-4 | AccountSelectorSheet.swift:33 | 0 active accounts → `YalaEmptyState.noAccounts(action:)` with message |
| EMPTY-5 | NewTransactionView.swift:900 | Autocomplete no results → inline `Text(L10n.Common.noResults)` (popover, too small for full component) |
| EMPTY-6 | TrendsTabView:584, CategoriesTabView:964 | Custom VStack → `YalaEmptyState.noTransactions()` |
| EMPTY-7 | ContentView.swift:982 | Custom search empty → `YalaEmptyState.noResults()` |

**New L10n keys needed:** ~2 (noResults if missing, account creation hint)

---

## Batch 9A: Dead Code & Static Formatters (~20 items, ~25 files, ZERO risk)

Pure deletion and `static let` extraction. No behavior change.

| Item | File | Fix |
|------|------|-----|
| CODE-1 | PanelView.swift:70 | Delete `calculationTask` @State |
| CODE-2 | PanelView.swift:54 | Delete `trendDetailType` + comment |
| CODE-3 | PanelViewModel.swift:440-460 | Remove duplicate doc comments |
| CODE-4 | PanelView.swift:309 | Rename `hasMultipleInputs` → `hasAlternativeInputs` |
| CODE-14 | ExchangeRateInputView.swift | Delete if confirmed dead code |
| CODE-22 | StatisticsViewModel.swift:684 | Delete `clearAllFilters()` dead code |
| CODE-23 | StatisticsViewModel.swift:437-566 | Delete ~130 lines `calculateAggregatedTrend` |
| CODE-24 | DetailContainerView + StatisticsVM | Delete 7 no-op sync functions |
| CODE-25 | FilterControlBar.swift | Delete if unused (verify no references) |
| CODE-30 | Budget.swift:19-24 | Delete legacy `month`, `year`, `category` fields |
| CODE-31/39 | ScheduledPayment.swift:229-253 | Delete `isPaidForCurrentCycle` dead code |
| CODE-48 | NotificationsSettingsView.swift:199-254 | Delete `notificationsList` legacy code |
| CODE-50 | ProfileView.swift:237 | Delete unused `@AppStorage("defaultPeriod")` |
| CODE-8 | TopSubcategoriesWidget:409, PanelView:776 | `NumberFormatter()` → `static let` |
| CODE-13 | NewTransactionView.swift:823 | `DateFormatter()` → `static let` |
| CODE-36 | 5+ files (ScheduledPayments) | `DateFormatter()` → `static let` in computed props |

**⚠️ CODE-30 (Budget legacy fields):** Verify no SwiftData migration issue — removing stored properties from @Model requires migration plan. If risky, skip.

---

## Batch 9B: Service Routing & Behavior Fixes (~16 items, ~12 files, MEDIUM risk)

Fixes where code bypasses services or has incorrect routing. Each needs careful testing.

| Item | File | Fix |
|------|------|-----|
| CODE-5 | PanelView.swift:16-27 | Move UIPageControl appearance to App delegate / one-time |
| CODE-6 | PanelView.swift:1325 | `asyncAfter(0.3)` → `onDismiss` callback chaining |
| CODE-10 | ScheduledPaymentsWidget.swift:268 | `CurrencyConverter.shared` → injected instance |
| CODE-11 | PanelView.swift | Add `subcategoriesWidgetFilter` to `clearAllPanelFilters()` |
| CODE-12 | NewTransactionView.swift:1194 | `modelContext.delete()` → `TransactionService.delete()` |
| CODE-15 | NewTransactionView.swift:73 | Re-apply `prefillAccountID` in `onCreateAnother` |
| CODE-17 | SaveAsRecurringSheet.swift:793 | Add `needsScheduledPaymentsRefresh = true` after save |
| CODE-21 | NewTransactionViewModel.swift | Consolidate 3 saves into 1 for transfer creation |
| CODE-27 | BulkEditSheet.swift | Allow empty note (clear notes use case) |
| CODE-28 | RecordsViewModel.swift:309 | `context.delete()` → `EntityDeletionService` |
| CODE-29 | RecordsStandaloneView.swift:419 | Remove redundant `DispatchQueue.main.async` |
| CODE-33 | BudgetEditorViewModel.swift:206 | Add `WidgetDataCache.updateCache()` on budget delete |
| CODE-37 | ScheduledPaymentsSettingsVM:73 | `context.delete()` → `EntityDeletionService` |
| CODE-41 | InboxView.swift:544 | `modelContext.save()` → `DraftService` path |
| CODE-44 | DraftService.swift:227 | Return skip count + show toast with "X aprobados, Y saltados" |
| CODE-51 | DowngradeResolutionSheet.swift:37 | Hardcoded limits → `FeatureGateService.maxFree*` |

---

## Batch 10: Remaining DS + L10N + A11Y (~42 items, ~40 files, LOW risk)

### 10A: DS tokens & L10N (~18 items, ~20 files)

**DS violations:**
| Item | Fix |
|------|-----|
| DS-1 | BalanceStatusIndicator: .green/.red/.gray → DS.Semantic tokens |
| DS-2 | Hex #6366F1 → Color.electricIndigo (3 files); #888888 → DS token |
| DS-3 | `Color(.tertiarySystemFill)` → leave if valid semantic (decision from batch 7) |
| DS-4 | `Color.primary.opacity(0.06)` → DS.Card.borderOpacity if exists |
| DS-7 | Padding 44 → DS.Spacing.formIndent (52) in WidgetPreferencesView |
| DS-8 | `Color(UIColor.label)` → `.primary`; `Color(UIColor.darkGray)` → DS token |
| DS-9 | Hex "6366F1" fallback → Color.electricIndigo |
| DS-10 | Transfer `.label` → `Color.transferColor` |
| DS-13 | `Color.gray` FAB locked → `DS.Semantic.disabledForeground` |
| DS-14 | Opacity 0.1 → `DS.Opacity.subtle` |
| DS-15 | CategoryDetailView paddings → DS.Spacing |
| DS-17 | BulkEditSheet sizes → DS tokens |
| DS-18 | BudgetProgressBar add warning color 75-99% |
| DS-19 | BudgetRowView `DS.Radius.md` → `DS.Radius.card` |
| DS-20 | `.orange` → `DS.Semantic.warningForeground` |
| DS-21 | InboxBulkActionsSheet raw colors → DS.Semantic |
| DS-22 | InboxDraftEditSheet opacity → DS tokens |
| DS-28 | Typography.title2 → DS.Typography.title2 consistency |

**L10N remaining:**
| Item | Fix |
|------|-----|
| L10N-1 | 10+ hardcoded a11y labels in Panel → L10n.Accessibility.* |
| L10N-4 | BalanceStatusIndicator "Bueno"/"Crítico"/"Normal" → L10n |
| L10N-10 | "Categoria" fallback → L10n |
| L10N-11 | "Quitar filtro" → L10n |
| L10N-14 | Budget "No hay presupuestos inactivos" → L10n |
| L10N-15 | ScheduledPaymentDetailView NSLocalizedString → L10n |
| L10N-17 | VoiceTranscriptionService: detect locale → match user's app language |
| L10N-22 | Date format "d 'de' MMMM" → locale-aware format |
| L10N-23 | Settings strings "Listo", "Reordenar" → L10n |

### 10B: A11Y improvements (~24 items, ~20 files)

**onTapGesture → Button (verify batch 7 didn't already fix):**
- A11Y-1: AccountsCarouselView
- A11Y-2: BudgetsWidget
- A11Y-22: CategoriesTabView category rows
- A11Y-29: CategorySelectorSheet expand

**Accessibility labels (new):**
- A11Y-4/5: AccountCardView combined + edit button labels
- A11Y-6: Page indicator dots
- A11Y-7: WidgetPreferencesView Toggle labels
- A11Y-8: ScheduledPaymentsWidget filters/calendar
- A11Y-9: RecentRecordsWidget rows
- A11Y-10: SiriTipCard close button min touch target 44pt
- A11Y-15: TransactionTypeSelectorView `.isSelected` trait
- A11Y-16/17/18: AccountSelector/SubcategoryGrid/TagSelector combined labels
- A11Y-19: TransferAmountInputView field labels
- A11Y-20: SelectionChip selection state
- A11Y-21: NatureEditChip label + hint
- A11Y-23/24/25: Metric/comparison/cashflow selector labels
- A11Y-26: Clear All buttons labels

**Reduce Motion:**
- A11Y-3: FAB breathing `.phaseAnimator` → check `accessibilityReduceMotion`
- DS-16: FAB pulse in DetailContainerView → same fix

**Hardcoded Spanish a11y (merge with L10N-1):**
- A11Y-11/12/13/14: Transaction selectors
- A11Y-27: PeriodComparisonChartView
- A11Y-28: RecordsStandaloneView
- A11Y-34/35: InboxView, InboxDraftEditSheet
- A11Y-38: ImageSelectionView

---

## Execution Order

```
Batch 8  → /verify-ios → /commit-one     (empty states, low risk)
Batch 9A → /verify-ios → /commit-one     (dead code, zero risk)
Batch 9B → /verify-ios → /test-smart → /commit-one  (service routing, needs tests)
Batch 10A → /verify-ios → /commit-one    (DS + L10N, low risk)
Batch 10B → /verify-ios → /commit-one    (A11Y, low risk)
```

## Verification

- `/verify-ios` after each batch
- `/test-smart` after batch 9B (service routing changes)
- Manual check: empty states visible when data cleared
- VoiceOver spot-check after batch 10B
- Update RELEASE-REVIEW.md checkboxes after each batch
- Update STATE.md with batch progress
