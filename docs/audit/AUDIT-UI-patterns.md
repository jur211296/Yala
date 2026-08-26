# Auditoría de patrones UI — Yala

Barrido de las **303 vistas** SwiftUI de Yala (~40 áreas de `Yala/App/Views/`) contra el Design System, cubriendo 8 dimensiones: tokens, tipografía, botones, backgrounds, glass-cards, color, componentes y a11y. **544 señales** detectadas y verificadas adversarialmente (las de severidad alta/media se confirmaron abriendo el código real para descartar falsos positivos); consolidando los sitios que violan varias reglas a la vez, son **~319 ubicaciones únicas** que tocar.

> Generado por el workflow `ui-audit` (`.claude/workflows/ui-audit.js`) — 122 agentes, fecha 2026-06-03. Re-ejecutable completo o acotado por área (`args.onlyAreas`).

---

## Estado de remediación (2026-06-03)

Resueltos en **12 commits** (~140 hallazgos de mayor impacto + dimensiones color, a11y y componentes completas, todos build-verde; cambios visuales validados con device-QA):

| Commit | Lote | Resuelto |
|--------|------|----------|
| `78f3724a` | tokens | 65 literales de dimensión → `DS.Spacing`/`Radius`/`Icon`/`Button` (46 vistas) |
| `ef685afd` | tipografía | token `DS.Typography.title3` + 5 migraciones de `.title3` nativo |
| `16e90f1d` | a11y | 16 `accessibilityLabel` en botones de solo-icono (incl. envío del Chat) |
| `3b04baf9` | botones | 12 CTAs reimplementados → `YalaPrimaryButton` |
| `1bd25d9e` | botones/a11y | 16 `.onTapGesture` → `Button` + `.contentShape` |
| `c4651c21` | glass-cards | 15 cards manuales → `.solidCard()`/`.selectableCard()` |
| `a1649c28` | backgrounds | 13 sheets → `.yalaScreenBackground(.panel)` |
| `ba4a36e0` | color | 10 colores semánticos de estado → `DS.Semantic.*` (alias 1:1, cero cambio visual) |
| `3509355f` | color | 16 markers `// A11Y-DM` (paletas decorativas intencionales) + grises de chart → `theme.secondaryText` |
| `2e4d93c7` | a11y | labels VoiceOver en 6 controles + keys `accessibility.expand/collapse` (16 locales) |
| `2709e391` | a11y | áreas táctiles ≥44pt en 9 controles (HIG; filas de día con expansión vertical) |
| `64cb28c0` | componentes | 2 empty states a mano → `YalaEmptyState` (Tags + Records, −37 LOC) |

Causa raíz también cerrada: `UI-PATTERNS.md` actualizado a la nomenclatura real (`theme.*`/`.thCard`, `YalaPrimaryButton`, sin `Color.yalaCard`/`YalaTextButton`).

**Dimensión color — CERRADA** (triage de 54 hallazgos): 10 fixes zero-change (semánticos→`DS.Semantic.*`) + 16 markers A11Y-DM (decorativos intencionales: paywall, What's New, edición masiva, acciones, Siri — `financeGreen` se mantiene por ser tono de marca) + 4 fixes (3 grises de chart theme-aware + 1 token swap) + 30 decorativos documentados como variedad intencional + 6 falsos positivos/stale (`GlobalSearchView:415` ya migrado). Decisión owner: mantener variedad decorativa en vez de aplanar a marca.

**Dimensión a11y — CERRADA**: verificación reveló que `16e90f1d` ya había resuelto 16 hallazgos (el reporte predataba ese commit). Restante cerrado en 2 commits: 8 labels VoiceOver (`2e4d93c7`, + keys nuevas `expand`/`collapse`) y 9 áreas táctiles ≥44pt (`2709e391`). Las filas de día (7 chips) usan expansión **vertical** 36→44h para no desbordar; M/A selector device-QA OK en iPhone 17 Pro.

**Dimensión componentes — CERRADA**: 2 empty states a mano migrados a `YalaEmptyState` (`64cb28c0`, Tags + Records, preservando el mensaje filter-aware + botón "Limpiar filtros"). Los **8 icon-badges NO se migran** (el reporte erró): `.yalaIconBadge*` tiene **0 usos** en la app (dead code) y renderiza `RoundedRectangle`, mientras la convención real (`RecordRowView` y resto) usa `Circle`. Migrar sería regresión visual + inconsistencia → se quedan como `Circle` hand-rolled (correcto). **Update 2026-06-04**: `.yalaIconBadge*` (`YalaIconBadgeModifier` + las 3 funcs `yalaIconBadgeSmall/Medium/Large` + sus previews) **eliminado** del codebase (~50 LOC, build verde). Las constantes `DS.Icon.badge*` siguen vivas (~50+ usos con `Circle()`). Las filas de la subsección *Componentes* que proponían `.yalaIconBadge*` como fix quedan **obsoletas** — la convención correcta es `Circle()` hand-rolled.

**Pendiente (deuda aceptada, no abordado):**
- **backgrounds Pattern B** (~70, severidad baja) — `ZStack { PanelBackgroundView(); content }` manual, deuda incremental aceptada, migrar al tocar el archivo.
- Casos puntuales saltados con criterio: `BiometricLockOverlay` (fondo opaco de seguridad), `RecordsStandaloneView` barra flotante (debe ser `glassEffect`), `PeriodSelectorComponents` (usa `.thCard` deliberado).

**Las 8 dimensiones del audit quedan resueltas o conscientemente diferidas.** Solo resta deuda de baja severidad documentada arriba.

---

## Resumen ejecutivo

### Por severidad

| Severidad | Señales |
|-----------|--------:|
| 🔴 Alta | 152 |
| 🟡 Media | 206 |
| ⚪ Baja | 186 |
| **Total** | **544** |

### Por dimensión

| Dimensión | Señales |
|-----------|--------:|
| tokens — spacing/radius hardcodeado | 185 |
| tipografía — font fija / jerarquía | 108 |
| backgrounds — falta `.yalaScreenBackground` | 91 |
| color — hardcoded / dark mode | 56 |
| botones — homogeneidad + tap target | 41 |
| a11y | 31 |
| glass-cards — iOS 26 | 22 |
| componentes — reúso | 10 |

> **Cómo leer estos números:** 544 es el total de *señales*. Un mismo sitio que viola varias reglas (p. ej. `.frame(32×32)` en un botón cuenta en `tokens` **y** en `a11y`) se cuenta una vez por dimensión. El cuerpo del reporte lista ~467 filas; consolidando los sitios multi-dimensión hay **~319 ubicaciones únicas** que tocar. Las cifras de esta sección son los totales exactos del barrido.

### Top 10 chunks con más hallazgos

| Área (chunk de ≤8 vistas) | Señales |
|---------------------------|--------:|
| Settings [3/4] | 30 |
| Settings [1/4] | 27 |
| Panel [4/5] | 26 |
| Categories | 19 |
| Settings [2/4] | 19 |
| Panel [1/5] | 17 |
| Reports/CashFlow [1/2] | 17 |
| ExportWizard | 16 |
| Statistics | 16 |
| Onboarding [1/2] | 15 |

> **Settings** y **Panel** concentran el grueso — varios de sus chunks lideran la tabla. Son las superficies más grandes y de mayor antigüedad.

---

## Hallazgos por dimensión

### Tokens

Dimensiones y spacings hardcodeados que mapean exacto a un token DS (`DS.Icon.*`, `DS.Spacing.*`, `DS.Button.*`, `DS.FormRow.*`, `DS.Chip.dotSize`, `DS.ListRow.iconSize`). Los de severidad alta mapean 1:1 a un token existente.

| Archivo:línea | Severidad | Regla | Snippet | Fix |
|---|---|---|---|---|
| Yala/App/Views/Accounts/AccountFormView.swift:474 | alta | mapea a DS.Icon.badgeMedium (32) | `.frame(width: 32, height: 32)` | `DS.Icon.badgeMedium` |
| Yala/App/Views/Accounts/AccountFormView.swift:492 | alta | mapea a DS.Icon.badgeMedium (32) | `.frame(width: 32, height: 32)` | `DS.Icon.badgeMedium` |
| Yala/App/Views/Categories/CategoryDetailView.swift:198 | alta | 24 = DS.Icon.badgeSmall | `.frame(width: 24, height: 24)` | `DS.Icon.badgeSmall` |
| Yala/App/Views/Categories/SubcategoryDetailView.swift:213 | alta | 24 = DS.Icon.badgeSmall | `.frame(width: 24, height: 24)` | `DS.Icon.badgeSmall` |
| Yala/App/Views/Categories/SubcategoryTransferSheet.swift:157 | alta | 44 = DS.Button.actionSize | `.frame(width: 44, height: 44)` | `DS.Button.actionSize` |
| Yala/App/Views/Categories/SubcategoryTransferSheet.swift:213 | alta | 32 = DS.Icon.badgeMedium | `.frame(width: 32, height: 32)` | `DS.Icon.badgeMedium` |
| Yala/App/Views/Chat/Onboarding/YalaAIOnboardingView.swift:193 | alta | 2 = DS.Spacing.xxs | `.padding(.vertical, 2)` | `DS.Spacing.xxs` |
| Yala/App/Views/Filters/FilterChipsSection.swift:60 | alta | 12 = DS.Spacing.md | `Color.clear.frame(height: 12)` | `DS.Spacing.md` |
| Yala/App/Views/Filters/FilterChipsSection.swift:109 | alta | 8×8 = DS.Chip.dotSize | `.frame(width: 8, height: 8)` | `DS.Chip.dotSize` |
| Yala/App/Views/Groups/GroupFormView.swift:122 | alta | 24 = DS.Icon.badgeSmall | `.frame(width: 24, height: 24)` | `DS.Icon.badgeSmall` |
| Yala/App/Views/Groups/GroupExpenseFormView.swift:399 | alta | 2 = DS.Spacing.xxs | `HStack(spacing: 2)` | `DS.Spacing.xxs` |
| Yala/App/Views/Groups/GroupExpenseFormView.swift:406 | alta | 4 = DS.Spacing.xs | `HStack(spacing: 4)` | `DS.Spacing.xs` |
| Yala/App/Views/Groups/GroupExpenseFormView.swift:416 | alta | 4 = DS.Spacing.xs | `HStack(spacing: 4)` | `DS.Spacing.xs` |
| Yala/App/Views/Groups/GroupExpenseFormView.swift:426 | alta | 4 = DS.Spacing.xs | `HStack(spacing: 4)` | `DS.Spacing.xs` |
| Yala/App/Views/Groups/GroupExpenseFormView.swift:438 | alta | 2 = DS.Spacing.xxs | `HStack(spacing: 2)` | `DS.Spacing.xxs` |
| Yala/App/Views/Groups/Onboarding/OnboardingDemoNotificationBubble.swift:33 | alta | 2 = DS.Spacing.xxs | `VStack(spacing: 2)` | `DS.Spacing.xxs` |
| Yala/App/Views/Groups/Onboarding/GroupsOnboardingView.swift:194 | alta | 44×44 = DS.Button.actionSize | `.frame(width: 44, height: 44)` | `DS.Button.actionSize` |
| Yala/App/Views/Groups/Onboarding/OnboardingDemoGroupCard.swift:59 | alta | 44×44 = DS.Button.actionSize | `.frame(width: 44, height: 44)` | `DS.Button.actionSize` |
| Yala/App/Views/Import/ImportAccountPickerSheet.swift:90 | alta | 40 = DS.ListRow.iconSize | `.frame(width: 40, height: 40)` | `DS.ListRow.iconSize` |
| Yala/App/Views/Import/ImportCurrencyMappingSheet.swift:135 | alta | 24 = DS.Icon.badgeSmall | `.frame(width: 24, height: 24)` | `DS.Icon.badgeSmall` |
| Yala/App/Views/Import/ImportCurrencyMappingSheet.swift:197 | alta | 32 = DS.Icon.badgeMedium | `.frame(width: 32, height: 32)` | `DS.Icon.badgeMedium` |
| Yala/App/Views/Favorites/FavoriteRowView.swift:97 | alta | 40 = DS.ListRow.iconSize | `.frame(width: 40, height: 40)` | `DS.ListRow.iconSize` |
| Yala/App/Views/More/MoreEditorSheet.swift:71 | alta | 52 = DS.FormRow.minHeight | `* 52` | `* DS.FormRow.minHeight` |
| Yala/App/Views/More/MoreEditorSheet.swift:82 | alta | 28 = DS.FormRow.iconWidth | `.frame(width: 28, height: 28)` | `DS.FormRow.iconWidth` |
| Yala/App/Views/More/MoreEditorSheet.swift:106 | alta | 28 = DS.FormRow.iconWidth | `.frame(width: 28, height: 28)` | `DS.FormRow.iconWidth` |
| Yala/App/Views/Onboarding/WelcomeBackButton.swift:25 | alta | 44 = DS.Button.actionSize | `.frame(width: 44, height: 44)` | `DS.Button.actionSize` |
| Yala/App/Views/Panel/AccountCardView.swift:134 | alta | 2 = DS.Spacing.xxs | `.padding(.vertical, 2)` | `DS.Spacing.xxs` |
| Yala/App/Views/Panel/ScheduledPaymentsWidget.swift:102 | alta | 56 = DS.Button.fabSize | `.frame(width: 56, height: 56)` | `DS.Button.fabSize` |
| Yala/App/Views/Panel/ScheduledPaymentsWidget.swift:258 | alta | 32 = DS.Icon.badgeMedium | `.frame(width: 32, height: 32)` | `DS.Icon.badgeMedium` |
| Yala/App/Views/Panel/TrendsCarouselWidget.swift:235 | alta | 32 = DS.Icon.badgeMedium | `.frame(width: 32, height: 32)` | `DS.Icon.badgeMedium` |
| Yala/App/Views/Planning/ScheduledPaymentRowView.swift:61 | alta | 40 = DS.Icon.badgeLarge | `.frame(width: 40, height: 40)` | `DS.Icon.badgeLarge` |
| Yala/App/Views/Planning/ScheduledPaymentsListView.swift:213 | alta | 32 = DS.Icon.badgeMedium | `.frame(width: 32, height: 32)` | `DS.Icon.badgeMedium` |
| Yala/App/Views/Records/RecordsStandaloneView.swift:229 | alta | 8 = DS.Chip.dotSize | `.frame(width: 8, height: 8)` | `DS.Chip.dotSize` |
| Yala/App/Views/Records/Components/RecordsCalendarView.swift:299 | alta | 2 = DS.Spacing.xxs | `.padding(.horizontal, 2)` | `DS.Spacing.xxs` |
| Yala/App/Views/Reports/CashFlow/CashFlowChartsSheet.swift:224 | alta | 2 = DS.Spacing.xxs | `.padding(.vertical, 2)` | `DS.Spacing.xxs` |
| Yala/App/Views/Reports/CashFlow/CashFlowLineConfigSheet.swift:221 | alta | 2 = DS.Spacing.xxs | `VStack(spacing: 2)` | `DS.Spacing.xxs` |
| Yala/App/Views/Reports/CashFlow/CashFlowOthersSheet.swift:74 | alta | 24 = DS.Icon.badgeSmall | `.frame(width: 24)` | `DS.Icon.badgeSmall` |
| Yala/App/Views/Reports/CashFlow/CashFlowSetupView.swift:251 | alta | 2 = DS.Spacing.xxs | `VStack(spacing: 2)` | `DS.Spacing.xxs` |
| Yala/App/Views/Reports/CashFlow/CashFlowSetupView.swift:480 | alta | 2 = DS.Spacing.xxs | `VStack(spacing: 2)` | `DS.Spacing.xxs` |
| Yala/App/Views/Search/GlobalSearchView.swift:403 | alta | 40 = DS.Icon.badgeLarge / DS.ListRow.iconSize | `.frame(width: 40, height: 40)` | `DS.Icon.badgeLarge` |
| Yala/App/Views/Settings/AccountsSettingsListView.swift:230 | alta | 32 = DS.Icon.badgeMedium | `.frame(width: 32, height: 32)` | `DS.Icon.badgeMedium` |
| Yala/App/Views/Settings/AccountsSettingsListView.swift:304 | alta | 44 = DS.Button.actionSize | `.frame(width: 44, height: 44)` | `DS.Button.actionSize` |
| Yala/App/Views/Settings/BudgetsFavoritesSettingsView.swift:266 | alta | 40 = DS.Icon.badgeLarge | `.frame(width: 40, height: 40)` | `DS.Icon.badgeLarge` |
| Yala/App/Views/Settings/BudgetsFavoritesSettingsView.swift:300 | alta | 44 = DS.Button.actionSize | `.frame(width: 44, height: 44)` | `DS.Button.actionSize` |
| Yala/App/Views/Settings/BudgetsFavoritesSettingsView.swift:312 | alta | 44 = DS.Button.actionSize | `.frame(width: 44, height: 44)` | `DS.Button.actionSize` |
| Yala/App/Views/Settings/SiriShortcutsView.swift:242 | alta | 2 = DS.Spacing.xxs | `VStack(spacing: 2)` | `DS.Spacing.xxs` |
| Yala/App/Views/Settings/TabBarConfigView.swift:111 | alta | 52 = DS.FormRow.minHeight | `* 52` | `* DS.FormRow.minHeight` |
| Yala/App/Views/Settings/TagsSettingsListView.swift:137 | alta | 52 = DS.FormRow.minHeight | `* 52` | `* DS.FormRow.minHeight` |
| Yala/App/Views/Settings/TagsSettingsListView.swift:170 | alta | 52 = DS.FormRow.minHeight | `* 52` | `* DS.FormRow.minHeight` |
| Yala/App/Views/Settings/TutorialsListView.swift:108 | alta | 2 = DS.Spacing.xxs | `VStack(spacing: 2)` | `DS.Spacing.xxs` |
| Yala/App/Views/Shared/AmountText.swift:67 | alta | 2 = DS.Spacing.xxs | `HStack(spacing: 2)` | `DS.Spacing.xxs` |
| Yala/App/Views/Shared/ProcessingProgressView.swift:117 | alta | 8 = DS.Chip.dotSize | `.frame(height: 8)` | `DS.Chip.dotSize` |
| Yala/App/Views/Shared/ProcessingProgressView.swift:135 | alta | 8 = DS.Chip.dotSize | `.frame(height: 8)` | `DS.Chip.dotSize` |
| Yala/App/Views/Shared/ProcessingProgressView.swift:181 | alta | 8 = DS.Chip.dotSize | `.frame(width: 8, height: 8)` | `DS.Chip.dotSize` |
| Yala/App/Views/Shared/ProfileToolbarButton.swift:36 | alta | 40 = DS.Icon.badgeLarge | `private let size: CGFloat = 40` | `DS.Icon.badgeLarge` |
| Yala/App/Views/Shared/UIHelpers.swift:26 | alta | 8 = DS.Chip.dotSize | `.frame(width: 8, height: 8)` | `DS.Chip.dotSize` |
| Yala/App/Views/Shared/VariationChip.swift:93 | alta | 2 = DS.Spacing.xxs | `HStack(spacing: 2)` | `DS.Spacing.xxs` |
| Yala/App/Views/Shared/YalaSpark.swift:84 | alta | 12 = DS.Icon.sizeSmall | `case .small: return 12` | `DS.Icon.sizeSmall` |
| Yala/App/Views/Shared/YalaSpark.swift:85 | alta | 16 = DS.Icon.sizeMedium | `case .medium: return 16` | `DS.Icon.sizeMedium` |
| Yala/App/Views/Shared/YalaSpark.swift:86 | alta | 24 = DS.Icon.badgeSmall | `case .large: return 24` | `DS.Icon.badgeSmall` / `DS.Icon.sizeLarge` |
| Yala/App/Views/Statistics/Sankey/SankeyChartView.swift:242 | alta | 4 = DS.Spacing.xs | `HStack(spacing: 4)` | `DS.Spacing.xs` |
| Yala/App/Views/Statistics/Sankey/SankeyLabelModeToggle.swift:40 | alta | 32 = DS.Icon.badgeMedium32 | `.frame(width: 32, height: 32)` | `DS.Icon.badgeMedium32` |
| Yala/App/Views/Tags/TagFormView.swift:164 | alta | 40 = DS.Icon.badgeLarge | `.frame(width: 40, height: 40)` | `DS.Icon.badgeLarge` |
| Yala/App/Views/Tags/TagFormView.swift:198 | alta | 32 = DS.Icon.badgeMedium | `.frame(width: 32, height: 32)` | `DS.Icon.badgeMedium` |
| Yala/App/Views/Tags/TagFormView.swift:221 | alta | 32 = DS.Icon.badgeMedium | `.frame(width: 32, height: 32)` | `DS.Icon.badgeMedium` |
| Yala/App/Views/Transactions/TransactionSuccessView.swift:319 | alta | 20 = DS.Icon.sizeLarge | `.frame(width: 20)` | `DS.Icon.sizeLarge` |
| Yala/App/Views/Transactions/SaveAsFavoriteSheet.swift:150 | alta | 24 = DS.Icon.badgeSmall | `.frame(width: 24)` | `DS.Icon.badgeSmall` |
| Yala/App/Views/WhatsNew/WhatsNewSheet.swift:112 | alta | 44 = DS.Button.actionSize | `.frame(width: 44, height: 44)` | `DS.Button.actionSize` |
| Yala/App/Views/Categories/CategoryDetailView.swift:187 | media | 70pt valor mágico | `.frame(width: 70, height: 70)` | constante local nombrada |
| Yala/App/Views/Categories/CategoryDetailView.swift:459 | media | 36pt valor mágico | `.frame(width: 36, height: 36)` | `DS.Icon.badgeMedium` o constante |
| Yala/App/Views/Categories/SubcategoryDetailView.swift:201 | media | 70pt valor mágico | `.frame(width: 70, height: 70)` | constante local nombrada |
| Yala/App/Views/Categories/SubcategoryTransferSheet.swift:85 | media | 70pt valor mágico | `.frame(width: 70, height: 70)` | constante local nombrada |
| Yala/App/Views/Chat/Onboarding/YalaAIOnboardingView.swift:302 | media | 96 sin token | `.frame(width: 96, height: 96)` | constante `heroBadgeSize` o token DS.Icon.heroBadge |
| Yala/App/Views/Chat/ChatTransactionDraftCard.swift:210 | media | 20 = DS.Icon.size20 | `.frame(width: 20)` | `DS.Icon.size20` |
| Yala/App/Views/Chat/ChatTransactionDraftCard.swift:231 | media | 20 = DS.Icon.size20 | `.frame(width: 20)` | `DS.Icon.size20` |
| Yala/App/Views/Chat/ChatTransactionDraftCard.swift:311 | media | 20 = DS.Icon.size20 | `.frame(width: 20)` | `DS.Icon.size20` |
| Yala/App/Views/Chat/ChatTransactionDraftCard.swift:367 | media | spacing 3 valor mágico | `VStack(spacing: 3)` | `DS.Spacing.xs` / `xxs` |
| Yala/App/Views/Filters/Components/CategorySelectorSheet.swift:128 | media | 36pt valor mágico | `.frame(width: 36, height: 36)` | `DS.Icon.badgeMedium`/`badgeLarge` |
| Yala/App/Views/Filters/Components/CategorySelectorSheet.swift:193 | media | 36pt valor mágico | `.frame(width: 36, height: 36)` | `DS.Icon.badgeMedium`/`badgeLarge` |
| Yala/App/Views/Groups/GroupDetailView.swift:142 | media | 8×8 sin token | `.frame(width: 8, height: 8)` | constante `badgeDotSize` |
| Yala/App/Views/Groups/GroupFormView.swift:112 | media | 80×80 sin token | `.frame(width: 80, height: 80)` | constante `iconPreviewSize` |
| Yala/App/Views/Groups/Onboarding/OnboardingDemoNotificationBubble.swift:31 | media | cornerRadius 9 sin token | `cornerRadius: 9` | `DS.Radius.sm` / `md` |
| Yala/App/Views/Groups/Onboarding/GroupsOnboardingView.swift:91 | media | 24/8 = DS.Spacing.xxl/sm | `step == currentStep ? 24 : 8` | `DS.Spacing.xxl` / `DS.Spacing.sm` |
| Yala/App/Views/Inbox/InboxBulkActionsSheet.swift:215 | media | 36pt sin token | `.frame(width: 36, height: 36)` | `DS.Icon.badgeMedium`/`badgeLarge` |
| Yala/App/Views/More/MoreView.swift:241 | media | cornerRadius 6 sin token | `cornerRadius: 6` | `DS.Radius.xs` / `sm` |
| Yala/App/Views/Panel/BudgetsWidget.swift:199 | media | 28 sin token | `.frame(width: 28, height: 28)` | `DS.Icon.badgeSmall`/`badgeMedium` |
| Yala/App/Views/Panel/CashFlowWidget.swift:842 | media | 8 = DS.Spacing.sm | `.frame(height: 8)` | `DS.Spacing.sm` / `barTrackHeight` |
| Yala/App/Views/Panel/CashFlowWidget.swift:873 | media | 8 = DS.Spacing.sm | `.frame(height: 8)` | `DS.Spacing.sm` / `barTrackHeight` |
| Yala/App/Views/Panel/FinancialScoreView.swift:219 | media | 8 = DS.Spacing.sm | `.frame(height: 8)` | `DS.Spacing.sm` / `scoreBarHeight` |
| Yala/App/Views/Panel/ScheduledPaymentsWidget.swift:304 | media | 36 sin token | `.frame(width: 36, height: 36)` | `DS.Icon.badgeLarge`/`badgeMedium` |
| Yala/App/Views/Panel/RecentRecordsWidget.swift:91 | media | 36 sin token | `subcategoryIcon(..., size: 36)` | `DS.Icon.badgeLarge`/`badgeMedium` |
| Yala/App/Views/Panel/PanelWidgetSection.swift:409 | media | 200 sin token | `.frame(height: 200)` | constante `cashFlowEmptyStateHeight` |
| Yala/App/Views/Panel/SubcategoriesPieWidget.swift:246 | media | 140 sin token | `.frame(width: 140)` | constante `legendWidth` |
| Yala/App/Views/Panel/TagsPieWidget.swift:227 | media | 140 sin token | `.frame(width: 140)` | constante `legendWidth` |
| Yala/App/Views/Panel/TopCategoriesWidget.swift:276 | media | 28×28 fuera de tokens | `.frame(width: 28, height: 28)` | `DS.Icon.badgeSmall`/`badgeMedium` |
| Yala/App/Views/Panel/TopSubcategoriesWidget.swift:391 | media | 28×28 fuera de tokens | `.frame(width: 28, height: 28)` | `DS.Icon.badgeSmall`/`badgeMedium` |
| Yala/App/Views/Planning/BudgetDetailView.swift:116 | media | 56 = DS.Button.fabSize | `.frame(width: 56, height: 56)` | `DS.Button.fabSize` |
| Yala/App/Views/Planning/ScheduledPaymentEditorView.swift:939 | media | .padding(.horizontal) sin token | `.padding(.horizontal)` | `.padding(.horizontal, DS.Spacing.lg)` |
| Yala/App/Views/Planning/ScheduledPaymentsListView.swift:242 | media | 8 dot indicator sin token frame | `.frame(width: 8, height: 8)` | constante `dotSize` |
| Yala/App/Views/Planning/ScheduledPaymentsListView.swift:360 | media | spacing 3 sin token | `HStack(spacing: 3)` | `DS.Spacing.xxs` / `xs` |
| Yala/App/Views/Planning/Components/BudgetChartsPeriodSelector.swift:178 | media | 52 no mapea (YalaPrimaryButton usa 50) | `.frame(height: 52)` | eliminar al migrar a YalaPrimaryButton |
| Yala/App/Views/Planning/Components/BudgetPeriodSelectorSheet.swift:193 | media | 52 no mapea | `.frame(height: 52)` | eliminar al migrar a YalaPrimaryButton |
| Yala/App/Views/Planning/Components/ScheduledPaymentPeriodSelectorSheet.swift:151 | media | 52 no mapea | `.frame(height: 52)` | eliminar al migrar a YalaPrimaryButton |
| Yala/App/Views/Profile/PersonalDetailsView.swift:180 | media | 32 = DS.Icon.badgeMedium | `.frame(width: 32, height: 32)` | `DS.Icon.badgeMedium` |
| Yala/App/Views/Profile/ProfileView.swift:781 | media | 28 = DS.FormRow.iconWidth | `.frame(width: 28, height: 28)` | `DS.FormRow.iconWidth` |
| Yala/App/Views/Profile/ProfileView.swift:783 | media | cornerRadius 6 valor mágico | `cornerRadius: 6` | `DS.Radius.sm` (8) |
| Yala/App/Views/Records/Components/RecordsCalendarView.swift:232 | media | 36 valor mágico | `.frame(width: 36, height: 36)` | `DS.Button.actionSize` o token compacto |
| Yala/App/Views/Records/Components/RecordsCalendarView.swift:309 | media | 56 = DS.Button.fabSize | `.frame(minHeight: 56, ...)` | `DS.Button.fabSize` / `DS.Calendar.cellMinHeight` |
| Yala/App/Views/Reports/CashFlow/CashFlowHorizonSheet.swift:30 | media | 32 = DS.Spacing.xxxl | `.frame(width: 32, ...)` | `DS.Spacing.xxxl` |
| Yala/App/Views/Reports/CashFlow/CashFlowHorizonSheet.swift:42 | media | 32 = DS.Spacing.xxxl | `.frame(width: 32, ...)` | `DS.Spacing.xxxl` |
| Yala/App/Views/Settings/AccountsSettingsListView.swift:201 | media | 16 = DS.Spacing.lg; 10 sin token | `EdgeInsets(top: 10, leading: 16, ...)` | `DS.Spacing.lg` lat.; `sm`/`md` vert. |
| Yala/App/Views/Settings/AppIconSettingsView.swift:116 | media | .padding() implícito (~16=lg) | `.padding()` | `.padding(DS.Spacing.lg)` |
| Yala/App/Views/Settings/BudgetsFavoritesSettingsView.swift:346 | media | 16=lg; 10 sin token | `EdgeInsets(top: 10, leading: 16, ...)` | `DS.Spacing.lg` lat. |
| Yala/App/Views/Settings/NotificationEditorSheet.swift:285 | media | .padding() sin token | `.padding()` | `.padding(DS.Spacing.lg)` |
| Yala/App/Views/Settings/ScheduledPaymentsSettingsView.swift:98 | media | 16=lg; 6 aprox xs | `EdgeInsets(top: 6, leading: 16, ...)` | `DS.Spacing.lg` lat.; `xs` vert. |
| Yala/App/Views/Settings/SiriShortcutsView.swift:238 | media | cornerRadius 6 valor mágico | `cornerRadius: 6` | `DS.Radius.xs`/`sm` |
| Yala/App/Views/Settings/SubscriptionView.swift:274 | media | 30 sin token | `.frame(width: 30, height: 30)` | `DS.Icon.badgeSmall24`/`badgeMedium32` |
| Yala/App/Views/Settings/SubscriptionView.swift:276 | media | cornerRadius 7 valor mágico | `cornerRadius: 7` | `DS.Radius.xs`/`sm` |
| Yala/App/Views/Settings/TagsSettingsListView.swift:126 | media | 10 sin token | `EdgeInsets(top: 10, leading: 16, ...)` | `DS.Spacing.sm`/`md` |
| Yala/App/Views/Settings/TagsSettingsListView.swift:160 | media | 10 sin token | `EdgeInsets(top: 10, leading: 16, ...)` | `DS.Spacing.sm`/`md` |
| Yala/App/Views/Settings/TutorialsListView.swift:104 | media | cornerRadius 6 valor mágico | `cornerRadius: 6` | `DS.Radius.xs`/`sm` |
| Yala/App/Views/Shared/MilestoneUpgradeSheet.swift:133 | media | 30×30 sin token | `.frame(width: 30, height: 30)` | `DS.Icon.badgeSmall`/`badgeMedium` |
| Yala/App/Views/Shared/MilestoneUpgradeSheet.swift:135 | media | cornerRadius 7 sin token | `cornerRadius: 7` | `DS.Radius.sm`/`xs` |
| Yala/App/Views/Shared/ProcessingProgressView.swift:169 | media | 28 sin token exacto | `.frame(width: 28, height: 28)` | constante `stepCircleSize` |
| Yala/App/Views/Statistics/DetailContainerView.swift:490 | media | 44 = DS.Button.actionSize | `.frame(width: 44, height: 44)` | `DS.Button.actionSize` |
| Yala/App/Views/Statistics/DetailContainerView.swift:510 | media | 44 = DS.Button.actionSize | `.frame(width: 44, height: 44)` | `DS.Button.actionSize` |
| Yala/App/Views/Statistics/InsightsTabView.swift:656 | media | 28 valor mágico | `.frame(width: 28, height: 28)` | `DS.Icon.badgeSmall`/`badgeMedium` |
| Yala/App/Views/Subscription/ProTrialOfferSheet.swift:189 | media | 26 = DS.Panel.headerAccessorySize | `.frame(width: 26, height: 26)` | `DS.Panel.headerAccessorySize` |
| Yala/App/Views/Subscription/ProTrialOfferSheet.swift:191 | media | cornerRadius 6 sin token | `cornerRadius: 6` | `DS.Radius.xs`/`sm` |
| Yala/App/Views/Transactions/TransactionFormRow.swift:72 | media | 28 sin token | `.frame(width: 28, height: 28)` | `DS.Icon.badgeSmall`/`badgeMedium` |
| Yala/App/Views/Transactions/AccountSelectorSheet.swift:118 | media | 36 sin token | `.frame(width: 36, height: 36)` | `DS.Icon.badgeMedium`/`badgeLarge` |
| Yala/App/Views/Transactions/SaveAsFavoriteSheet.swift:385 | media | 28 sin token | `.frame(width: 28, height: 28)` | `DS.Icon.badgeSmall`/`badgeMedium` |
| Yala/App/Views/Transactions/NewTransactionView.swift:846 | media | 48 sin token | `.frame(width: 48, height: 48)` | constante o `DS.Button.actionSize` |
| Yala/App/Views/Transactions/SubcategorySelectorSheet.swift:184 | media | 48 sin token | `.frame(width: 48, height: 48)` | constante o `DS.Button.actionSize` |
| Yala/App/Views/Voice/VoiceRecordingView.swift:546 | media | 72 sin token | `.frame(width: 72, height: 72)` | constante `voiceActionButtonSize` |
| Yala/App/Views/Voice/VoiceRecordingView.swift:583 | media | 72 sin token | `.frame(width: 72, height: 72)` | misma constante línea 546 |
| Yala/App/Views/Voice/VoiceRecordingView.swift:622 | media | 80 sin token | `.frame(width: 80, height: 80)` | constante `voiceStartButtonSize` |
| Yala/App/Views/WhatsNew/WhatsNewSheet.swift:55 | media | 72 sin token | `.padding(.top, 72)` | `DS.Spacing.sheetTop` (64) o constante |
| Yala/App/Views/ExportWizard/ExportSummaryStepView.swift:187 | baja | .padding() implícito (lg) | `.padding()` | `.padding(DS.Spacing.lg)` |
| Yala/App/Views/ExportWizard/ExportSummaryStepView.swift:204 | baja | 100 valor mágico | `.frame(width: 100, ...)` | constante `labelColumnWidth` |
| Yala/App/Views/ExportWizard/ExportFiltersStepView.swift:487 | baja | 24 = DS.Icon.badgeSmall | `.frame(width: 24)` | `DS.Icon.size24`/`badgeSmall` |
| Yala/App/Views/ExportWizard/ExportFiltersStepView.swift:515 | baja | 24 = DS.Icon.badgeSmall | `.frame(width: 24)` | `DS.Icon.size24`/`badgeSmall` |
| Yala/App/Views/ExportWizard/ExportFiltersStepView.swift:567 | baja | .padding() implícito (lg) | `.padding()` | `.padding(DS.Spacing.lg)` |
| Yala/App/Views/ExportWizard/FilterComponents.swift:190 | baja | 40 separador (semántica incorrecta) | `.frame(width: 1, height: 40)` | constante `separatorHeight` |
| Yala/App/Views/Favorites/FavoritesListView.swift:151 | baja | 16=lg; 6 sin token | `EdgeInsets(top: 6, leading: 16, ...)` | `DS.Spacing.lg` lat.; `xs`/`sm` vert. |
| Yala/App/Views/Groups/GroupNudgeBanner.swift:31 | baja | 24 = DS.Icon.badgeSmall | `.frame(width: 24)` | `DS.Icon.badgeSmall` |
| Yala/App/Views/Chat/Onboarding/YalaAIOnboardingView.swift:178 | baja | 44 = DS.Button.actionSize | `.frame(width: 44, height: 44)` | `DS.Icon.badgeLarge` |
| Yala/App/Views/Chat/Onboarding/YalaAIOnboardingView.swift:390 | baja | 28 = DS.FormRow.iconWidth | `.frame(width: 28, height: 28)` | `DS.FormRow.iconWidth` / `DS.Icon.badgeSmall` |
| Yala/App/Views/Onboarding/OnboardingView.swift:343 | baja | 24/8 = DS.Spacing.xxl/sm | `step == ... ? 24 : 8` | `DS.Spacing.xxl` / `sm` |
| Yala/App/Views/Onboarding/OnboardingView.swift:645 | baja | 44 = DS.Button.actionSize | `.frame(width: 44, height: 44)` | `DS.Button.actionSize` |
| Yala/App/Views/Onboarding/OnboardingView.swift:800 | baja | .padding() (~16=lg) | `.padding()` | `.padding(DS.Spacing.lg)` |
| Yala/App/Views/Onboarding/WelcomeChooserView.swift:128 | baja | 48 sin token | `.frame(width: 48, height: 48)` | constante `chooserIconCircleSize` |
| Yala/App/Views/Panel/PanelSectionPreferencesSheet.swift:155 | baja | 28 = DS.FormRow.iconWidth | `.frame(width: 28)` | `DS.FormRow.iconWidth` |
| Yala/App/Views/Panel/PanelSectionPreferencesSheet.swift:192 | baja | 28 = DS.FormRow.iconWidth | `.frame(width: 28)` | `DS.FormRow.iconWidth` |
| Yala/App/Views/Panel/PanelSectionsConfigView.swift:152 | baja | 28 = DS.FormRow.iconWidth | `.frame(width: 28)` | `DS.FormRow.iconWidth` |
| Yala/App/Views/Panel/PanelSectionsConfigView.swift:198 | baja | 28 = DS.FormRow.iconWidth | `.frame(width: 28)` | `DS.FormRow.iconWidth` |
| Yala/App/Views/Panel/ScheduledPaymentsWidget.swift:107 | baja | spacing 1 sin token | `VStack(spacing: 1)` | `DS.Spacing.xxs` o 0 + comentario |
| Yala/App/Views/Panel/SiriTipCard.swift:19 | baja | 36 fuera de tokens | `.frame(width: 36, height: 36)` | `DS.Icon.badgeMedium`/`badgeLarge` |
| Yala/App/Views/Panel/SubcategoriesPieWidget.swift:771 | baja | 28 sin token | `.frame(height: 28)` | constante `barHeight` / `DS.Spacing.xxl`/`xxxl` |
| Yala/App/Views/Panel/TagsPieWidget.swift:701 | baja | 28 sin token | `.frame(height: 28)` | constante `barHeight` |
| Yala/App/Views/Panel/PieChartVariationHeader.swift:149 | baja | #Preview clipShape manual | `cornerRadius: DS.Radius.xl` | informativo (#Preview); `.solidCard()` en prod |
| Yala/App/Views/Panel/Components/PanelSmallBarRow.swift:53 | baja | altura barra 6 sin token | `.frame(height: 6)` | `DS.Sizing.progressBarHeight` / `barRowHeight` |
| Yala/App/Views/Records/Components/DailySpendingBar.swift:46 | baja | 5 valor mágico | `.frame(height: 5)` | token `DS.Indicator.barHeight` o `DS.Spacing.xs` |
| Yala/App/Views/Records/Components/RecordRowView.swift:46 | baja | spacing 3 valor mágico (documentado) | `VStack(spacing: 3)` | token tight row spacing o `xxs`/`xs` |
| Yala/App/Views/Settings/CategoriesSettingsListView.swift:226 | baja | 36 sin token exacto | `.frame(width: 36, height: 36)` | `DS.Icon.badgeMedium`/`badgeLarge` |
| Yala/App/Views/Settings/CurrencySettingsView.swift:93 | baja | 200 valor mágico | `.frame(width: 200)` | constante o `maxWidth: .infinity` |
| Yala/App/Views/Shared/ContextualGuideBanner.swift:48 | baja | 24 = DS.Icon.badgeSmall | `.frame(width: 24)` | `DS.Icon.badgeSmall` |
| Yala/App/Views/Shared/ProfileToolbarButton.swift:38 | baja | 14 sin token exacto | `sparkBadgeSize: CGFloat = 14` | mantener constante nombrada (ya lo es) |
| Yala/App/Views/Shared/PeriodNavigationHeader.swift:82 | baja | 36 valor mágico | `.frame(width: 36, height: 36)` | `DS.Icon.badgeMedium32` / `DS.Button.actionSize44` |
| Yala/App/Views/Shared/SkeletonView.swift:94 | baja | 40 = DS.ListRow.iconSize | `.frame(width: 40, height: 40)` | `DS.ListRow.iconSize` |
| Yala/App/Views/Shared/YalaSpark.swift:186 | baja | 40 #Preview = DS.Icon.badgeLarge | `.frame(width: 40, height: 40)` | `DS.Icon.badgeLarge` (severidad baja en #Preview) |
| Yala/App/Views/Statistics/CategoriesTabView.swift:885 | baja | 32 = DS.Icon.badgeMedium | `.frame(width: 32, height: 32)` | `DS.Icon.badgeMedium` |
| Yala/App/Views/Statistics/RecordsTabView.swift:337 | baja | 32 = DS.Icon.badgeMedium | `.frame(width: 32, height: 32)` | `DS.Icon.badgeMedium` |
| Yala/App/Views/Statistics/TrendsTabView.swift:672 | baja | 32 = DS.Icon.badgeMedium | `.frame(width: 32, height: 32)` | `DS.Icon.badgeMedium` |
| Yala/App/Views/Statistics/TrendsTabView.swift:1005 | baja | 32 = DS.Icon.badgeMedium | `.frame(width: 32, height: 32)` | `DS.Icon.badgeMedium` |
| Yala/App/Views/Statistics/Components/NeedBar.swift:19 | baja | 2 = DS.Spacing.xxs | `HStack(spacing: 2)` | `DS.Spacing.xxs` |
| Yala/App/Views/Statistics/Components/NeedBar.swift:37 | baja | 24 = DS.Spacing.xxl | `.frame(height: 24)` | `DS.Spacing.xxl` o constante |
| Yala/App/Views/Statistics/Components/NeedBar.swift:53 | baja | 8×8 = DS.Spacing.sm | `.frame(width: 8, height: 8)` | `DS.Spacing.sm` / `DS.Chip.dotSize` |
| Yala/App/Views/Statistics/Components/WeekdayBarChart.swift:60 | baja | 2 = DS.Spacing.xxs | `.annotation(..., spacing: 2)` | `DS.Spacing.xxs` |
| Yala/App/Views/Statistics/Sankey/SankeyChartView.swift:230 | baja | 3 sin token | `.frame(height: 3)` | comentario / `DS.Spacing.xxs` |
| Yala/App/Views/Subscription/ProTrialOfferSheet.swift:295 | baja | 24 = DS.Icon.badgeSmall | `.frame(width: 24, height: 24)` | `DS.Icon.badgeSmall` |
| Yala/App/Views/Subscription/ProTrialOfferSheet.swift:300 | baja | 16 = DS.Icon.sizeMedium | `.frame(width: 16, height: 16)` | `DS.Icon.sizeMedium` |
| Yala/App/Views/Transactions/Components/NeedSelectorSheet.swift:34 | baja | .padding() (~16=lg) | `.padding()` | `.padding(DS.Spacing.lg)` |

### Tipografía

Fuentes nativas SwiftUI (`.title2.bold()`, `.title3`, `.footnote`, `.system(size:)`) en lugar de `DS.Typography.*`, y `.fontWeight()` manual apilado sobre tokens que ya definen el peso. Recordatorio: `DS.Typography` **no define `title3`** → mapear a `title2`. SF Symbols con `.system(size:)` sin marker `// A11Y-DT:`.

| Archivo:línea | Severidad | Regla | Snippet | Fix |
|---|---|---|---|---|
| Yala/App/Views/Panel/FinancialScoreView.swift:103 | alta | `.system(size: 28)` en texto del score sin A11Y-DT | `.font(.system(size: 28, weight: .semibold, design: .rounded))` | añadir marker A11Y-DT o `@ScaledMetric` |
| Yala/App/Views/Shared/UpgradePromptSheet.swift:87 | alta | `.title2.bold()` ≠ token (.semibold) | `.font(.title2.bold())` | `DS.Typography.title2` |
| Yala/App/Views/BiometricLockOverlay.swift:35 | media | `.title2.bold()` nativo | `.font(.title2.bold())` | `DS.Typography.title2` |
| Yala/App/Views/Chat/Onboarding/ChatDraftPreviewCard.swift:46 | media | monto mock con `DS.Typography.title` no token de cantidad | `.font(DS.Typography.title)` | `DS.Typography.amount` / `amountSmall` |
| Yala/App/Views/ExportWizard/ExportColumnsStepView.swift:78 | media | `.title3` no existe en DS | `.font(.title3.weight(.semibold))` | `DS.Typography.title2` |
| Yala/App/Views/ExportWizard/ExportSummaryStepView.swift:100 | media | `.title3` no existe en DS | `.font(.title3.weight(.semibold))` | `DS.Typography.title2` |
| Yala/App/Views/Groups/SplitTypeSegmentedSelector.swift:54 | media | `.footnote` nativo | `.font(.footnote.weight(...))` | `DS.Typography.caption`/`labelSmall` + weight condicional |
| Yala/App/Views/Groups/SplitTypeSegmentedSelector.swift:56 | media | `.footnote` nativo | `.font(.footnote.weight(...))` | `DS.Typography.caption`/`labelSmall` |
| Yala/App/Views/Inbox/InboxBulkApproveSuccessView.swift:59 | media | `Font.system(.largeTitle, design: .rounded)` | `.font(Font.system(.largeTitle, design: .rounded).weight(.bold))` | `DS.Typography.largeTitle`/`heroAmount` o marker A11Y-DT |
| Yala/App/Views/Inbox/InboxDraftEditSheet.swift:297 | media | `.subheadline` + weight manual | `.font(.subheadline.weight(...))` | `subheadlineEmphasized`/`subheadline` condicional |
| Yala/App/Views/Inbox/InboxDraftEditSheet.swift:315 | media | `.subheadline` + weight manual | `.font(.subheadline.weight(...))` | `subheadlineEmphasized`/`subheadline` condicional |
| Yala/App/Views/Onboarding/OnboardingView.swift:455 | media | `.fontWeight(.bold)` anula token | `.fontWeight(.bold)` | eliminar; `DS.Typography.largeTitle` ya tiene peso |
| Yala/App/Views/Panel/CashFlowWidget.swift:615 | media | `.fontWeight(.semibold)` sobre labelTiny | `.fontWeight(.semibold)` | eliminar override o token `labelTinySemibold` |
| Yala/App/Views/Panel/ExchangeRateWidget.swift:190 | media | captionSmall+.medium ≡ labelTiny | `.font(DS.Typography.captionSmall).fontWeight(.medium)` | `.font(DS.Typography.labelTiny)` |
| Yala/App/Views/Panel/ScheduledPaymentsWidget.swift:194 | media | `.title3` nativo en SF Symbol | `.font(.title3)` | `DS.Typography.title2` / `.system(size: DS.Icon.badgeLarge)` |
| Yala/App/Views/Planning/ScheduledPaymentDetailView.swift:343 | media | `.title3` no existe en DS | `.font(.title3.weight(.bold))` | `DS.Typography.title2` |
| Yala/App/Views/Planning/ScheduledPaymentEditorView.swift:920 | media | `.title3` no existe en DS | `.font(.title3.weight(.bold))` | `DS.Typography.title2` |
| Yala/App/Views/Planning/Components/BudgetChartsPeriodSelector.swift:84 | media | `.body` + weight manual | `.font(.body.weight(...))` | `DS.Typography.bodyBold`/`body` |
| Yala/App/Views/Planning/Components/BudgetPeriodSelectorSheet.swift:85 | media | `.body` + weight manual | `.font(.body.weight(...))` | `DS.Typography.bodyBold`/`body` |
| Yala/App/Views/Planning/Components/ScheduledPaymentPeriodSelectorSheet.swift:80 | media | `.body` + weight manual | `.font(.body.weight(...))` | `DS.Typography.bodyBold`/`body` |
| Yala/App/Views/Profile/ProfileView.swift:779 | media | subheadline+.medium ≡ label | `.font(DS.Typography.subheadline).fontWeight(.medium)` | `.font(DS.Typography.label)` |
| Yala/App/Views/Records/Components/RecordsCalendarView.swift:329 | media | `.caption2.weight(...)` nativo | `.font(.caption2.weight(...))` | `badgeLabel`/`labelTiny` condicional |
| Yala/App/Views/Reports/NetFlowSummaryView.swift:31 | media | `.fontWeight(.semibold)` anula label | `.fontWeight(.semibold)` | `.font(DS.Typography.label.weight(.semibold))` |
| Yala/App/Views/Reports/PivotRowView.swift:32 | media | `.fontWeight` anula token | `.fontWeight(level == 0 ? .semibold : .regular)` | consolidar en token |
| Yala/App/Views/Reports/CashFlow/CashFlowCellDetailSheet.swift:520 | media | `.fontWeight` sobre captionSmall | `.fontWeight(snap.isActive ? .semibold : .regular)` | eliminar / token enfatizado |
| Yala/App/Views/Reports/CashFlow/CashFlowCellDetailSheet.swift:524 | media | `.fontWeight(.bold)` anula label | `.fontWeight(snap.isActive ? .bold : .regular)` | eliminar / `bodyBold` |
| Yala/App/Views/Reports/CashFlow/CashFlowChartsSheet.swift:60 | media | `.fontWeight(.bold)` anula title2 | `.fontWeight(.bold)` | eliminar |
| Yala/App/Views/Reports/CashFlow/CashFlowChartsSheet.swift:468 | media | `.fontWeight(.semibold)` anula labelSmall | `.fontWeight(.semibold)` | eliminar |
| Yala/App/Views/Reports/CashFlow/CashFlowChartsSheet.swift:743 | media | `.fontWeight(.bold)` anula title | `.fontWeight(.bold)` | eliminar |
| Yala/App/Views/Reports/CashFlow/CashFlowMonthCapsule.swift:25 | media | `.fontWeight(.bold/.regular)` sobre captionSmall | `.fontWeight(isSelected ? .bold : .regular)` | eliminar / variantes DS |
| Yala/App/Views/Reports/CashFlow/CashFlowMonthCapsule.swift:32 | media | `.fontWeight(.semibold)` anula labelSmall | `.fontWeight(.semibold)` | eliminar |
| Yala/App/Views/Settings/AppIconSettingsView.swift:96 | media | `.title2.bold()` nativo | `.font(.title2.bold())` | `DS.Typography.title2` |
| Yala/App/Views/Settings/BiometricSecurityView.swift:36 | media | `.title2.bold()` nativo | `.font(.title2.bold())` | `DS.Typography.title2` |
| Yala/App/Views/Settings/CategoriesSettingsListView.swift:143 | media | subheadline+.medium | `.font(DS.Typography.subheadline).fontWeight(.medium)` | `subheadlineEmphasized` |
| Yala/App/Views/Settings/CategoriesSettingsListView.swift:195 | media | subheadline+.medium | `.font(DS.Typography.subheadline).fontWeight(.medium)` | `subheadlineEmphasized` |
| Yala/App/Views/Settings/FAQView.swift:29 | media | `.title2.bold()` nativo | `.font(.title2.bold())` | `DS.Typography.title` |
| Yala/App/Views/Settings/PersonalizationSettingsView.swift:81 | media | `.title2.bold()` nativo | `.font(.title2.bold())` | `DS.Typography.title` |
| Yala/App/Views/Settings/SiriShortcutsView.swift:35 | media | `.title2.bold()` nativo | `.font(.title2.bold())` | `DS.Typography.title` |
| Yala/App/Views/Settings/SubscriptionView.swift:224 | media | `.title2.bold()` ≠ token | `.font(.title2.bold())` | `DS.Typography.title2` |
| Yala/App/Views/Settings/TagsSettingsListView.swift:185 | media | subheadline+.medium ≡ label | `.font(DS.Typography.subheadline).fontWeight(.medium)` | `.font(DS.Typography.label)` |
| Yala/App/Views/Settings/TutorialsListView.swift:27 | media | `.title2.bold()` ≠ token | `.font(.title2.bold())` | `DS.Typography.title2` |
| Yala/App/Views/Settings/TutorialsListView.swift:100 | media | subheadline+.medium ≡ label | `.font(DS.Typography.subheadline).fontWeight(.medium)` | `.font(DS.Typography.label)` |
| Yala/App/Views/Statistics/RecordsTabView.swift:388 | media | `.title3.weight(.semibold)` nativo | `.font(.title3.weight(.semibold))` | `DS.Typography.headline`/`title2` |
| Yala/App/Views/Shared/MilestoneUpgradeSheet.swift:60 | media | `.title2.bold()` ≠ token | `.font(.title2.bold())` | `DS.Typography.title2`/`headline` |
| Yala/App/Views/Shared/ProBadge.swift:22 | media | `.caption2.weight(.bold)` ≡ badgeLabel | `case .small: return .caption2.weight(.bold)` | `DS.Typography.badgeLabel` |
| Yala/App/Views/Shared/ProBadge.swift:23 | media | `.caption.weight(.bold)` sin token | `case .medium: return .caption.weight(.bold)` | `labelSmall` / token nuevo |
| Yala/App/Views/Shared/ProBadge.swift:24 | media | `.subheadline.weight(.bold)` ≠ token | `case .large: return .subheadline.weight(.bold)` | `subheadlineEmphasized` |
| Yala/App/Views/Shared/VariationChip.swift:42 | media | `.caption2.weight(.medium)` ≡ labelTiny | `case .small: return .caption2.weight(.medium)` | `DS.Typography.labelTiny` |
| Yala/App/Views/Shared/WidgetHelpCircleLabel.swift:19 | media | captionSmall+.semibold ≡ indicator | `.fontWeight(.semibold)` | `DS.Typography.indicator` |
| Yala/App/Views/Subscription/DowngradeResolutionSheet.swift:140 | media | `.title2.bold()` ≠ token | `.font(.title2.bold())` | `DS.Typography.title2` |
| Yala/App/Views/Transactions/NewTransactionView.swift:148 | media | body+.semibold ≡ bodyBold | `.fontWeight(.semibold)` | `.font(DS.Typography.bodyBold)` |
| Yala/App/Views/Transactions/Components/TransactionTypeSelectorView.swift:37 | media | subheadline+weight inline | `.font(.subheadline.weight(...))` | `subheadlineEmphasized`/`subheadline` |
| Yala/App/Views/Favorites/FavoriteEditorView.swift:54 | baja | `@ScaledMetric` sin A11Y-DT | `heroAmountSize: CGFloat = 64` | añadir marker / `DS.Typography.heroAmount` |
| Yala/App/Views/Favorites/FavoriteEditorView.swift:55 | baja | `@ScaledMetric` sin A11Y-DT | `currencySymbolSize: CGFloat = 28` | añadir marker A11Y-DT |
| Yala/App/Views/ExportWizard/FilterComponents.swift:139 | baja | `.fontWeight(.semibold)` sobre caption | `.fontWeight(.semibold)` | `labelSmall` o token captionBold |
| Yala/App/Views/Groups/SplitTypeSegmentedSelector.swift:88 | baja | `.caption` nativo en SF Symbol | `.font(.caption)` | `DS.Typography.caption` |
| Yala/App/Views/Image/ImageSelectionView.swift:588 | baja | `.title2.weight(.medium)` nativo en SF Symbol | `.font(.title2.weight(.medium))` | `DS.Typography.iconMedium` / `DS.Icon.size20` |
| Yala/App/Views/Inbox/InboxBulkActionsSheet.swift:165 | baja | `.fontWeight(.semibold)` toolbar | `.fontWeight(.semibold)` | `YalaToolbarButton` / token |
| Yala/App/Views/Inbox/InboxBulkActionsSheet.swift:218 | baja | body+.medium encadenado | `.font(DS.Typography.body).fontWeight(.medium)` | token con peso o `bodyBold` |
| Yala/App/Views/Onboarding/InviteRecoveryView.swift:42 | baja | `.system(size: 56)` SF Symbol sin A11Y-DT | `.font(.system(size: 56))` | `@ScaledMetric` / `DS.Icon.badgeLarge` |
| Yala/App/Views/Onboarding/WelcomeBackButton.swift:23 | baja | `.system(size: 18)` SF Symbol sin A11Y-DT | `.font(.system(size: 18, weight: .semibold))` | `@ScaledMetric` / `DS.Typography.headline` |
| Yala/App/Views/Onboarding/WelcomeChooserView.swift:130 | baja | `.system(size: 22)` SF Symbol sin A11Y-DT | `.font(.system(size: 22, weight: .semibold))` | `@ScaledMetric` / `DS.Typography.headline` |
| Yala/App/Views/Onboarding/WelcomeHeroView.swift:217 | baja | `.system(size: 26)` SF Symbol sin A11Y-DT | `.font(.system(size: 26, weight: .semibold))` | `DS.Icon.size20`/`24` o marker |
| Yala/App/Views/Onboarding/WelcomeRestoreView.swift:160 | baja | `.system(size: 56)` SF Symbol sin A11Y-DT | `.font(.system(size: 56, weight: .semibold))` | marker / `DS.Typography.largeTitle` |
| Yala/App/Views/Onboarding/WelcomeRestoreView.swift:291 | baja | `.system(size: 24)` SF Symbol sin A11Y-DT | `.font(.system(size: 24, weight: .semibold))` | `DS.Icon.badgeMedium32` / marker |
| Yala/App/Views/Onboarding/WelcomeRestoreView.swift:366 | baja | `.system(size: 56)` SF Symbol sin A11Y-DT | `.font(.system(size: 56))` | marker A11Y-DT |
| Yala/App/Views/Panel/BudgetsWidget.swift:202 | baja | `.system(size: 14)` SF Symbol sin A11Y-DT | `.font(.system(size: 14, weight: .semibold))` | `DS.Icon.size12`/`16` / `DS.Chip.chipIcon` |
| Yala/App/Views/Panel/BudgetsWidget.swift:257 | baja | `.title3` nativo SF Symbol | `.font(.title3)` | `DS.Icon.size20` |
| Yala/App/Views/Panel/BudgetsWidget.swift:278 | baja | `.title3` nativo SF Symbol | `.font(.title3)` | `DS.Icon.size20` |
| Yala/App/Views/Panel/CategoriesPieWidget.swift:196 | baja | `.system(size: 28)` SF Symbol sin A11Y-DT | `.font(.system(size: 28))` | marker A11Y-DT / `DS.Icon.size20` |
| Yala/App/Views/Panel/PanelView.swift:186 | baja | `.fontWeight(.bold)` sobre captionSmall | `.font(DS.Typography.captionSmall).fontWeight(.bold)` | `bodyBold` / token con peso |
| Yala/App/Views/Panel/ScheduledPaymentsWidget.swift:256 | baja | `.fontWeight(.semibold)` SF Symbol | `.fontWeight(.semibold)` | `DS.Typography.labelSmall` |
| Yala/App/Views/Panel/SetupChecklistCard.swift:114 | baja | `.system(size: 10)` SF Symbol sin A11Y-DT | `.font(.system(size: 10))` | `DS.Typography.captionSmall` / `DS.Chip.chipIcon` |
| Yala/App/Views/Panel/SetupChecklistCard.swift:145 | baja | `.system(size: 10)` SF Symbol sin A11Y-DT | `.font(.system(size: 10))` | `DS.Typography.captionSmall` / marker |
| Yala/App/Views/Panel/SetupChecklistCard.swift:177 | baja | `.system(size: 12)` SF Symbol sin A11Y-DT | `.font(.system(size: 12, weight: .semibold))` | `DS.Typography.caption` / marker |
| Yala/App/Views/Panel/SubcategoriesPieWidget.swift:143 | baja | `.system(size: 28)` SF Symbol sin A11Y-DT | `.font(.system(size: 28))` | `DS.Icon.badgeLarge` / `DS.Typography.title` / marker |
| Yala/App/Views/Panel/TagsPieWidget.swift:132 | baja | `.system(size: 28)` SF Symbol sin A11Y-DT | `.font(.system(size: 28))` | `DS.Icon.badgeLarge` / `DS.Typography.title` / marker |
| Yala/App/Views/Panel/TopCategoriesWidget.swift:279 | baja | `.system(size: 14)` SF Symbol sin A11Y-DT | `.font(.system(size: 14, weight: .semibold))` | `DS.Typography.caption` / DS.Icon |
| Yala/App/Views/Panel/TopCategoriesWidget.swift:329 | baja | `.system(size: 24)` SF Symbol sin A11Y-DT | `.font(.system(size: 24))` | `DS.Icon.badgeMedium` / `DS.Typography.title` / marker |
| Yala/App/Views/Panel/TopSubcategoriesWidget.swift:394 | baja | `.system(size: 14)` SF Symbol sin A11Y-DT | `.font(.system(size: 14, weight: .semibold))` | `DS.Typography.caption` / DS.Icon |
| Yala/App/Views/Panel/TopSubcategoriesWidget.swift:446 | baja | `.system(size: 24)` SF Symbol sin A11Y-DT | `.font(.system(size: 24))` | `DS.Typography.title` / `DS.Icon.badgeMedium` / marker |
| Yala/App/Views/Planning/BudgetChartsView.swift:643 | baja | `.body.weight(.semibold)` nativo SF Symbol | `.font(.body.weight(.semibold))` | `DS.Typography.body` / `iconMedium` |
| Yala/App/Views/Reports/PivotRowView.swift:98 | baja | `.system(size: iconSize)` SF Symbol | `.font(.system(size: iconSize, weight: .semibold))` | `DS.Typography.iconMedium` / token equivalente |
| Yala/App/Views/Reports/CashFlow/CashFlowChartsSheet.swift:465 | baja | `.system(size: 10)` SF Symbol chip | `.font(.system(size: 10, weight: .semibold))` | `DS.Typography.chipIcon` / `DS.Chip.iconSize` |
| Yala/App/Views/Reports/CashFlow/CashFlowSetupView.swift:247 | baja | `.system(size: DS.Icon.sizeSmall)` SF Symbol | `.font(.system(size: DS.Icon.sizeSmall, weight: .semibold))` | aceptable; idealmente `DS.Typography.caption` |
| Yala/App/Views/Settings/FAQView.swift:81 | baja | subheadline+.semibold SF Symbol | `.font(DS.Typography.subheadline).fontWeight(.semibold)` | `subheadlineEmphasized` |
| Yala/App/Views/Settings/SiriShortcutsView.swift:77 | baja | subheadline+.semibold SF Symbol | `.font(DS.Typography.subheadline).fontWeight(.semibold)` | `subheadlineEmphasized` |
| Yala/App/Views/Settings/SiriShortcutsView.swift:161 | baja | subheadline+.semibold SF Symbol | `.font(DS.Typography.subheadline).fontWeight(.semibold)` | `subheadlineEmphasized` |
| Yala/App/Views/Settings/SiriShortcutsView.swift:269 | baja | subheadline+.semibold SF Symbol | `.font(DS.Typography.subheadline).fontWeight(.semibold)` | `subheadlineEmphasized` |
| Yala/App/Views/Settings/TutorialDetailView.swift:194 | baja | `.system(size: 60)` SF Symbol sin A11Y-DT | `.font(.system(size: 60))` | `@ScaledMetric` / `DS.Icon.badgeLarge40` |
| Yala/App/Views/Shared/AmountText.swift:122 | baja | `.subheadline` default en static helper | `integerFont: Font = .subheadline` | `DS.Typography.subheadline` o documentar actor-isolation |
| Yala/App/Views/Shared/AmountText.swift:123 | baja | `.caption` default en static helper | `secondaryFont: Font = .caption` | `DS.Typography.caption` o documentar |
| Yala/App/Views/Shared/ProBadge.swift:23 | baja | `.caption.weight(.bold)` nativo | `case .medium: return .caption.weight(.bold)` | `DS.Typography.caption` + weight / token |
| Yala/App/Views/Shared/ProBadge.swift:24 | baja | `.subheadline.weight(.bold)` nativo | `case .large: return .subheadline.weight(.bold)` | `subheadlineEmphasized` |
| Yala/App/Views/Shared/SyncStatusBanner.swift:52 | baja | `.system(size: 13)` SF Symbol | `.font(.system(size: 13, weight: .semibold))` | `DS.Icon.sizeLarge` / `labelSmall` / marker |
| Yala/App/Views/Shared/SyncStatusBanner.swift:60 | baja | `.system(size: 10)` SF Symbol | `.font(.system(size: 10, weight: .semibold))` | `DS.Typography.captionSmall` / `DS.Icon.sizeSmall` / marker |
| Yala/App/Views/Statistics/InsightsTabView.swift:307 | baja | `.system(size: 24)` SF Symbol | `.font(.system(size: 24))` | `.system(size: DS.Icon.badgeMedium)` / `iconMedium` |
| Yala/App/Views/Statistics/InsightsTabView.swift:535 | baja | `.system(size: 32)` SF Symbol | `.font(.system(size: 32))` | `.system(size: DS.Icon.badgeMedium)` |
| Yala/App/Views/Statistics/InsightsTabView.swift:578 | baja | `.system(size: 24)` SF Symbol | `.font(.system(size: 24))` | `.system(size: DS.Icon.badgeMedium)` / `iconMedium` |
| Yala/App/Views/Statistics/Sankey/SankeyLabelModeToggle.swift:38 | baja | `.system(size: 14)` SF Symbol chip | `.font(.system(size: 14, weight: .semibold))` | `DS.Chip.chipIcon` / `DS.Icon.size12`/`16` |
| Yala/App/Views/Transactions/Components/TransferAmountInputView.swift:23 | baja | `@ScaledMetric` sin A11Y-DT | `currencyLabelSize: CGFloat = 20` | añadir marker A11Y-DT |
| Yala/App/Views/UserDataResetView (Settings/UserDataResetView.swift):43 | baja | `.fontWeight(.semibold)` sobre title | `.fontWeight(.semibold)` | eliminar; `DS.Typography.title` ya tiene peso |
| Yala/App/Views/Voice/VoiceRecordingView.swift:525 | baja | `.title2.weight(.medium)` nativo SF Symbol | `.font(.title2.weight(.medium))` | `DS.Typography.title2` |
| Yala/App/Views/Voice/VoiceRecordingView.swift:564 | baja | `.title2.weight(.medium)` nativo SF Symbol | `.font(.title2.weight(.medium))` | `DS.Typography.title2` |
| Yala/App/Views/Voice/VoiceRecordingView.swift:601 | baja | `.title2.weight(.medium)` nativo SF Symbol | `.font(.title2.weight(.medium))` | `DS.Typography.title2` |
| Yala/App/Views/Tags/TagFormView.swift:167 | baja | body+.medium SF Symbol | `.font(DS.Typography.body).fontWeight(.medium)` | eliminar / `bodyBold` |
| Yala/App/Views/WhatsNew/WhatsNewSheet.swift:110 | baja | `.system(size: 22)` SF Symbol sin A11Y-DT | `.font(.system(size: 22, weight: .semibold))` | `DS.Chip.chipIcon` / `DS.Icon.sizeMedium` / marker |

### Botones

`.onTapGesture` en elementos interactivos (debe ser `Button` + `.buttonStyle(.plain)` + `.contentShape`), y CTAs primarios/secundarios reimplementados a mano (`.borderedProminent`, `.background(theme.accent)+.clipShape`) en lugar de `YalaPrimaryButton` / `YalaSecondaryButton`.

| Archivo:línea | Severidad | Regla | Snippet | Fix |
|---|---|---|---|---|
| Yala/App/Views/Accounts/AccountFormView.swift:482 | alta | `.onTapGesture` en swatch de color | `.onTapGesture {` | `Button { } .buttonStyle(.plain).contentShape(Circle())` |
| Yala/App/Views/Import/ImportCurrencyMappingSheet.swift:229 | alta | CTA con `.borderedProminent` | `Button {` | `YalaPrimaryButton` |
| Yala/App/Views/Import/ImportIntroSheet.swift:65 | alta | CTA en overlay a mano | `Button {` (`.background+.clipShape`) | `YalaPrimaryButton` |
| Yala/App/Views/Import/ImportIntroSheet.swift:165 | alta | CTA "Seleccionar Archivo" `.borderedProminent` | `Button {` | `YalaPrimaryButton(isLoading:)` |
| Yala/App/Views/Inbox/InboxApproveSuccessView.swift:335 | alta | CTA primario `.borderedProminent` | `Button(action: onAccept) { ... }.buttonStyle(.borderedProminent)` | `YalaPrimaryButton` |
| Yala/App/Views/Onboarding/InviteRecoveryView.swift:105 | alta | CTA a mano `.background(theme.accent)+.clipShape` | `Text(L10n.Welcome.Invite.join)...` | `YalaPrimaryButton(isDisabled:)` |
| Yala/App/Views/Onboarding/WelcomeRestoreView.swift:195 | alta | CTA a mano `.background(theme.accent)` | `Text(L10n.Welcome.Restore.continueAction)...` | `YalaPrimaryButton` |
| Yala/App/Views/Onboarding/WelcomeRestoreView.swift:381 | alta | CTA empty state a mano | `Button(action: primaryAction) { ... .background(theme.accent) }` | `YalaPrimaryButton` |
| Yala/App/Views/Panel/BudgetsWidget.swift:240 | alta | `.onTapGesture` en fila presupuesto | `.onTapGesture {` | `Button { }.buttonStyle(.plain).contentShape(Rectangle())` |
| Yala/App/Views/Panel/BudgetsWidget.swift:268 | alta | `.onTapGesture` en empty state CTA | `.onTapGesture { onEditFavorites?() }` | `Button { }.buttonStyle(.plain).contentShape(Rectangle())` |
| Yala/App/Views/Panel/CategoriesPieWidget.swift:450 | alta | `.onTapGesture` en VStack categoría | `.onTapGesture {` | `Button { }.buttonStyle(.plain).contentShape(Rectangle())` |
| Yala/App/Views/Panel/CategoriesPieWidget.swift:485 | alta | `.onTapGesture` en ForEach | `.onTapGesture {` | `Button { }.buttonStyle(.plain).contentShape(Rectangle())` |
| Yala/App/Views/Panel/TopCategoriesWidget.swift:211 | alta | `.onTapGesture` en fila lista | `.onTapGesture {` | `Button { }.buttonStyle(.plain).contentShape(Rectangle())` |
| Yala/App/Views/Panel/TopCategoriesWidget.swift:317 | alta | `.onTapGesture` en VStack | `.onTapGesture {` | `Button { }.buttonStyle(.plain).contentShape(Rectangle())` |
| Yala/App/Views/Panel/TopSubcategoriesWidget.swift:322 | alta | `.onTapGesture` en fila lista | `.onTapGesture {` | `Button { }.buttonStyle(.plain).contentShape(Rectangle())` |
| Yala/App/Views/Panel/TopSubcategoriesWidget.swift:432 | alta | `.onTapGesture` en VStack | `.onTapGesture {` | `Button { }.buttonStyle(.plain).contentShape(Rectangle())` |
| Yala/App/Views/Panel/Components/PanelSmallBarRow.swift:67 | alta | `.onTapGesture` en fila (TapIfPresent) | `content.onTapGesture { onTap() }` | `Button` condicional con `.buttonStyle(.plain)` |
| Yala/App/Views/Planning/Components/BudgetChartsPeriodSelector.swift:171 | alta | CTA a mano | `Button { confirmSelection() } label: { ...theme.accent... }` | `YalaPrimaryButton` |
| Yala/App/Views/Planning/Components/BudgetPeriodSelectorSheet.swift:186 | alta | CTA a mano | `Button { confirmSelection() } label: { ...theme.accent... }` | `YalaPrimaryButton` |
| Yala/App/Views/Planning/Components/ScheduledPaymentPeriodSelectorSheet.swift:144 | alta | CTA a mano | `Button { confirmSelection() } label: { ...theme.accent... }` | `YalaPrimaryButton` |
| Yala/App/Views/Reports/CashFlow/CashFlowMonthStrip.swift:29 | alta | `.onTapGesture` en capsule clicable | `.onTapGesture {` | `Button { }.buttonStyle(.plain).contentShape(Rectangle())` |
| Yala/App/Views/Reports/CashFlow/CashFlowSetupView.swift:287 | alta | `.onTapGesture` en HStack fila | `.onTapGesture {` | `Button { }.buttonStyle(.plain).contentShape(Rectangle())` |
| Yala/App/Views/Settings/TutorialDetailView.swift:199 | alta | `.onTapGesture` en área de video | `.onTapGesture { isVideoPlaying = true }` | `Button { }.buttonStyle(.plain)` + a11y |
| Yala/App/Views/Settings/TutorialDetailView.swift:261 | alta | CTA a mano `.background(theme.accent)` | `Button { ... } label: { Text(...) }` | `YalaPrimaryButton` |
| Yala/App/Views/Settings/TutorialCompletionView.swift:115 | alta | CTA `.borderedProminent` | `.buttonStyle(.borderedProminent)` | `YalaPrimaryButton` |
| Yala/App/Views/Shared/ProUpgradeBanner.swift:51 | alta | CTA a mano `.background(theme.accent)+.clipShape(Capsule())` | `Button { onUpgrade() } label: { ... }` | `YalaPrimaryButton` |
| Yala/App/Views/Statistics/Sankey/SankeyChartView.swift:272 | alta | `.onTapGesture` en view clicable | `.onTapGesture { handleTap(on: node) }` | `Button { }.buttonStyle(.plain).contentShape(Rectangle())` |
| Yala/App/Views/Tags/TagFormView.swift:91 | alta | CTA `.borderedProminent` | `.buttonStyle(.borderedProminent)` | `YalaPrimaryButton` |
| Yala/App/Views/Tags/TagFormView.swift:211 | alta | `.onTapGesture` en swatch de color | `.onTapGesture {` | `Button { }.buttonStyle(.plain).contentShape(Circle())` |
| Yala/App/Views/Transactions/NewTransactionView.swift:1275 | alta | CTA `registerButton` a mano `.borderedProminent` | `.buttonStyle(.borderedProminent)` | `YalaPrimaryButton(isLoading:isDisabled:)` |
| Yala/App/Views/Transactions/TransactionSuccessView.swift:197 | alta | CTA `.borderedProminent` | `.buttonStyle(.borderedProminent)` | `YalaPrimaryButton` |
| Yala/App/Views/ExportWizard/ExportSummaryStepView.swift:186 | media | CTA a mano (label es Menu) | `.background(theme.accent)+.clipShape(...)` | extraer `YalaPrimaryMenuButton` / ViewBuilder label |
| Yala/App/Views/Inbox/InboxApproveSuccessView.swift:346 | media | CTA secundario a mano `.bordered` | `Button(action: onApproveNext) {...}.buttonStyle(.bordered)` | `YalaSecondaryButton` |
| Yala/App/Views/Inbox/InboxDraftEditSheet.swift:693 | media | botón secundario full-width a mano (Capsule) | `Button { ... } label: { ...Capsule(...) }` | `YalaSecondaryButton` |
| Yala/App/Views/Panel/Sections/PanelHeroSection.swift:34 | media | `.onTapGesture` con controles hijos | `.onTapGesture {` | `.simultaneousGesture(TapGesture())` o overlay Button |
| Yala/App/Views/Panel/SubcategoriesPieWidget.swift:438 | media | `.onTapGesture` en VStack | `.onTapGesture {` | `Button { }.buttonStyle(.plain)` |
| Yala/App/Views/Panel/SubcategoriesPieWidget.swift:473 | media | `.onTapGesture` en ForEach | `.onTapGesture {` | `Button { }.buttonStyle(.plain)` |
| Yala/App/Views/Panel/TagsPieWidget.swift:402 | media | `.onTapGesture` en VStack | `.onTapGesture {` | `Button { }.buttonStyle(.plain)` |
| Yala/App/Views/Panel/TagsPieWidget.swift:433 | media | `.onTapGesture` en ForEach | `.onTapGesture {` | `Button { }.buttonStyle(.plain)` |
| Yala/App/Views/Reports/GroupingReorderSheet.swift:90 | media | `.onTapGesture` en control | `.onTapGesture {` | `Button { } label: { Image }.buttonStyle(.plain)` + a11y |
| Yala/App/Views/Chat/ChatSheetView.swift:229 | baja | botón reintento Capsule a mano | `Button {` | `YalaSecondaryButton` o helper compacto |

### Backgrounds

Vistas raíz / sheets que usan `.background(.thBackground)` o `Color(.systemBackground)` directo en lugar de `.yalaScreenBackground(_:)` (severidad **alta**). El resto son **Pattern B** (`ZStack { PanelBackgroundView(); content }`) — deuda incremental aceptada (severidad baja, ver sección "Deuda aceptada").

| Archivo:línea | Severidad | Regla | Snippet | Fix |
|---|---|---|---|---|
| Yala/App/Views/BiometricLockOverlay.swift:22 | alta | `Color(.systemBackground)` en raíz | `Color(.systemBackground).ignoresSafeArea()` | `.yalaScreenBackground(.panel)` |
| Yala/App/Views/Chat/ChatSheetView.swift:46 | alta | sheet root `.background(.thBackground)` | `.background(.thBackground)` | `.yalaScreenBackground(.panel)` + `.scrollContentBackground(.hidden)` |
| Yala/App/Views/Filters/PeriodSelectorComponents.swift:148 | alta | sheet `.medium` sin `.yalaScreenBackground(.compact)` | `NavigationStack {` | `.yalaScreenBackground(.compact)` |
| Yala/App/Views/Groups/GroupFormView.swift:65 | alta | `.background(.thBackground)` en ScrollView | `.background(.thBackground)` | `.yalaScreenBackground(.panel)` + `.scrollContentBackground(.hidden)` |
| Yala/App/Views/Groups/GroupSettingsView.swift:114 | alta | `.background(.thBackground)` raíz sheet | `.background(.thBackground)` | `.yalaScreenBackground(.panel)` |
| Yala/App/Views/Image/ImageSelectionView.swift:88 | alta | raíz sheet `.background(.thBackground)` | `.background(.thBackground)` | `.yalaScreenBackground(.panel)` |
| Yala/App/Views/Image/ImageSelectionView.swift:191 | alta | sheet anidado `.background(.thBackground)` | `.background(.thBackground)` | `.yalaScreenBackground(.compact)` |
| Yala/App/Views/Onboarding/LanguageSelectionView.swift:62 | alta | raíz `.background(.thBackground)` | `.background(.thBackground)` | `.yalaScreenBackground(.panel)` |
| Yala/App/Views/Onboarding/OnboardingView.swift:1471 | alta | sheet `.background(.thBackground)` | `.background(.thBackground)` | `.yalaScreenBackground(.panel)` + `.scrollContentBackground(.hidden)` |
| Yala/App/Views/Onboarding/OnboardingView.swift:1617 | alta | sheet `.background(.thBackground)` | `.background(.thBackground)` | `.yalaScreenBackground(.panel)` + `.scrollContentBackground(.hidden)` |
| Yala/App/Views/Shared/BalanceCalculatorSheet.swift:143 | alta | `.background(.thBackground)` en ScrollView | `.background(.thBackground)` | `.yalaScreenBackground(.panel)` en NavigationStack |
| Yala/App/Views/Shared/IconColorPickerSheet.swift:240 | alta | sheet root `.background(.thBackground)` | `.background(.thBackground)` | `.yalaScreenBackground(.panel)` |
| Yala/App/Views/Shared/MilestoneUpgradeSheet.swift:105 | alta | sheet `.background(.thBackground)` | `.background(.thBackground)` | `.yalaScreenBackground(.panel)` |
| Yala/App/Views/Shared/SplitCalculatorSheet.swift:171 | alta | `.background(.thBackground)` en ScrollView | `.background(.thBackground)` | `.yalaScreenBackground(.panel)` + `.scrollContentBackground(.hidden)` |
| Yala/App/Views/Shared/UpgradePromptSheet.swift:121 | alta | sheet raíz `.background(.thBackground)` | `.background(.thBackground)` | `.yalaScreenBackground(.panel)` |
| Yala/App/Views/Subscription/DowngradeResolutionSheet.swift:99 | alta | `.background(.thBackground)` en ScrollView | `.background(.thBackground)` | `.yalaScreenBackground(.panel)` + `.scrollContentBackground(.hidden)` |
| Yala/App/Views/Voice/VoiceRecordingView.swift:117 | alta | sheet raíz `.background(.thBackground)` | `.background(.thBackground)` | `.yalaScreenBackground(.panel)` |
| Yala/App/Views/SplashScreenView.swift:38 | baja | `Color.electricIndigo` fondo raíz (identidad marca) | `Color.electricIndigo.ignoresSafeArea()` | documentar excepción análoga a WelcomeFlow |
| Yala/App/Views/Panel/NeedTrendWidget.swift:955 | baja | Pattern B variante: `.background(theme.background)` en chip | `.background(isSelected ? theme.background : Color.clear)` | `Color.thCard` / `.solidCard()` |

Hallazgos **Pattern B** (severidad baja, deuda aceptada — migrar a `.yalaScreenBackground()` al tocar el archivo): `Categories/CategoryDetailView.swift:59`, `Categories/SubcategoryDetailView.swift:101`, `Categories/SubcategoryNeedSelectorView.swift:16`, `Categories/SubcategoryTransferSheet.swift:31`, `Chat/ChatTopicsSheet.swift:21`, `Chat/Onboarding/YalaAIOnboardingView.swift:33`, `ExportWizard/ExportColumnsStepView.swift:34`, `ExportWizard/ExportSummaryStepView.swift:46`, `ExportWizard/ExportFiltersStepView.swift:120`, `ExportWizard/ExportFiltersStepView.swift:547`, `ExportWizard/FilterComponents.swift:233`, `Favorites/FavoriteEditorView.swift:67`, `Filters/Components/CategorySelectorSheet.swift:34`, `Groups/GroupDetailView.swift:73`, `Groups/GroupExpenseFormView.swift:83`, `Groups/GroupInviteOnboardingView.swift:36`, `Groups/GroupsContainerView.swift:39`, `Groups/Onboarding/GroupsOnboardingView.swift:36`, `Import/ImportAccountPickerSheet.swift:21`, `Import/ImportCurrencyMappingSheet.swift:33`, `Import/ImportIntroSheet.swift:35`, `Import/ImportIntroSheet.swift:148`, `Inbox/InboxBulkActionsSheet.swift:118`, `Inbox/InboxDraftEditSheet.swift:262`, `Inbox/InboxView.swift:61`, `More/MoreView.swift:69`, `More/MoreEditorSheet.swift:22`, `Onboarding/InviteRecoveryView.swift:35`, `Onboarding/WelcomeRestoreView.swift:52`, `Panel/PanelSectionPreferencesSheet.swift:119`, `Panel/PanelSectionsConfigView.swift:98`, `Panel/Sheets/BalanceLiveAnchorEducationSheet.swift:33`, `Panel/Sheets/FinancialScoreDetailSheet.swift:57`, `Planning/BudgetChartsView.swift:168`, `Planning/BudgetDetailView.swift:52`, `Planning/PlanningView.swift:54`, `Planning/ScheduledPaymentDetailView.swift:77`, `Planning/BudgetsListView.swift:35`, `Planning/ScheduledPaymentsView.swift:23`, `Planning/Components/TransactionAssociationSheet.swift:27`, `Profile/PersonalDetailsView.swift:44`, `Profile/ProfileView.swift:106`, `Profile/SupportFormSheet.swift:50`, `Reports/FinancialReportView.swift:54`, `Reports/CashFlow/CashFlowSetupView.swift:389`, `Search/GlobalSearchView.swift:28`, `Search/GlobalSearchView.swift:152`, `Settings/AIPrivacySettingsView.swift:31`, `Settings/AccountsSettingsListView.swift:33`, `Settings/AppIconSettingsView.swift:83`, `Settings/BiometricSecurityView.swift:23`, `Settings/BudgetsFavoritesSettingsView.swift:22`, `Settings/CategoriesSettingsListView.swift:22`, `Settings/CurrencyPickerSheet.swift:43`, `Settings/CurrencySettingsView.swift:46`, `Settings/SmartInsightsSettingsView.swift:18`, `Settings/SubscriptionView.swift:29`, `Settings/TabBarConfigView.swift:30`, `Settings/TagsSettingsListView.swift:22`, `Settings/ThemeSettingsView.swift:32`, `Settings/TutorialDetailView.swift:35`, `Settings/TutorialsListView.swift:15`, `Settings/UserDataResetView.swift:33`, `Settings/iCloudSyncSettingsView.swift:25`, `Shared/CurrencySelectorView.swift:42`, `Tags/TagFormView.swift:45`, `Transactions/AccountSelectorSheet.swift:40`, `Transactions/NewTransactionView.swift:229`, `Transactions/SubcategorySelectorSheet.swift:33`, `Transactions/TagSelectorSheet.swift:26`, `Transactions/Components/DatePickerSheet.swift:32`, `Transactions/Components/NeedSelectorSheet.swift:19`.

### Glass-cards

Cards reimplementadas a mano (`.background(.thCard) + .clipShape + .overlay stroke`) en lugar del modifier canónico `.solidCard()` / `.selectableCard()`. También chips de selección con `Capsule + fill` manual en lugar de `.glassEffect()`, y el modifier legacy `.yalaCard()`.

| Archivo:línea | Severidad | Regla | Snippet | Fix |
|---|---|---|---|---|
| Yala/App/Views/ExportWizard/ExportFiltersStepView.swift:561 | alta | card manual reimplementa `.solidCard()` | `.background(.thCard).clipShape(...).overlay(stroke)` | `.solidCard(radius: DS.Radius.lg)` |
| Yala/App/Views/Groups/GroupSettingsView.swift:664 | alta | card manual `.background+.overlay` | `RoundedRectangle.fill(.thCard) + stroke(.thCardBorder)` | `.solidCard(radius: DS.Radius.card)` |
| Yala/App/Views/Groups/GroupSettingsView.swift:693 | alta | card manual `.background+.overlay` | `RoundedRectangle.fill(.thCard) + stroke(.thCardBorder)` | `.solidCard(radius: DS.Radius.card)` |
| Yala/App/Views/Groups/GroupSettingsView.swift:736 | alta | card manual `.background+.overlay` | `RoundedRectangle.fill(.thCard) + stroke(.thCardBorder)` | `.solidCard(radius: DS.Radius.card)` |
| Yala/App/Views/Groups/GroupsGlobalSettingsView.swift:50 | alta | card manual reimplementa `.solidCard()` | `.background(.thCard).clipShape(...).overlay(stroke)` | `.solidCard(padding: 0, radius: DS.Radius.lg)` |
| Yala/App/Views/Groups/GroupsGlobalSettingsView.swift:77 | alta | card manual reimplementa `.solidCard()` | `.background(.thCard).clipShape(...).overlay(stroke)` | `.solidCard(padding: 0, radius: DS.Radius.lg)` |
| Yala/App/Views/Groups/GroupsGlobalSettingsView.swift:91 | alta | card manual reimplementa `.solidCard()` | `.background(.thCard).clipShape(...).overlay(stroke)` | `.solidCard(padding: 0, radius: DS.Radius.lg)` |
| Yala/App/Views/Groups/GroupsGlobalSettingsView.swift:105 | alta | card manual reimplementa `.solidCard()` | `.background(.thCard).clipShape(...).overlay(stroke)` | `.solidCard(padding: 0, radius: DS.Radius.lg)` |
| Yala/App/Views/Import/ImportIntroSheet.swift:310 | alta | card manual reimplementa `.solidCard()` | `.background(.thCard).clipShape(...).overlay(stroke)` | `.solidCard(radius: DS.Radius.lg)` |
| Yala/App/Views/Import/ImportIntroSheet.swift:342 | alta | card manual reimplementa `.solidCard()` | `.background(.thCard).clipShape(...).overlay(stroke)` | `.solidCard(radius: DS.Radius.lg)` |
| Yala/App/Views/Records/RecordsStandaloneView.swift:315 | alta | barra selección `.ultraThinMaterial` manual | `.background(.ultraThinMaterial, in: RoundedRectangle(...))` | `.solidCard(radius: DS.Radius.lg)` |
| Yala/App/Views/Search/GlobalSearchView.swift:390 | alta | card a mano reimplementa `.solidCard()` | `.background(cardBackground).clipShape(...)` | `.solidCard(radius: DS.Radius.card)` + eliminar `cardBackground` |
| Yala/App/Views/Settings/AppIconSettingsView.swift:218 | alta | card a mano (selectable) | `.background(.thCard).clipShape(...).overlay(stroke)` | `.selectableCard(isSelected:, radius:)` |
| Yala/App/Views/Settings/BiometricSecurityView.swift:61 | alta | card a mano reimplementa `.solidCard()` | `.background(.thCard).clipShape(...).overlay(stroke)` | `.solidCard()` |
| Yala/App/Views/Settings/BiometricSecurityView.swift:87 | alta | card a mano reimplementa `.solidCard()` | `.background(.thCard).clipShape(...).overlay(stroke)` | `.solidCard()` |
| Yala/App/Views/Settings/BudgetsFavoritesSettingsView.swift:142 | alta | card a mano + `.dsSubtleShadow` | `.background(RoundedRectangle.fill(.thCard))...` | `.solidCard(...)` / `.selectableCard(activeColor:)` |
| Yala/App/Views/Filters/FilterChipsSection.swift:84 | media | chip `Capsule + fill` manual sin `.glassEffect()` | `.background(Capsule().fill(...))` | `.glassEffect(.regular.interactive().tint(...), in: .capsule)` |
| Yala/App/Views/Filters/FilterChipsSection.swift:118 | media | chip `Capsule + fill` manual sin `.glassEffect()` | `.background(Capsule().fill(...))` | `.glassEffect(.regular.interactive().tint(...), in: .capsule)` |
| Yala/App/Views/Panel/SetupChecklistCard.swift:120 | media | `.yalaCard()` legacy | `.yalaCard(padding:, radius:, shadow: false)` | `.solidCard(padding:, radius:)` |
| Yala/App/Views/Settings/NotificationsSettingsView.swift:234 | media | card manual reimplementa `.solidCard()` | `.background(.thCard).clipShape(...).overlay+.shadow` | `.solidCard(radius: DS.Radius.xl)` |
| Yala/App/Views/Settings/NotificationsSettingsView.swift:325 | media | NotificationCard manual | `.background(.thCard).clipShape(...).overlay+.shadow` | `.solidCard(radius: DS.Radius.xl)` |
| Yala/App/Views/Settings/iCloudSyncSettingsView.swift:322 | media | `statusCardStyle()` reimplementa solidCard (falta `.continuous` + stroke) | `.background(.thCard).clipShape(...)` | `.solidCard(padding:, radius: DS.Radius.xl)` |

### Color

Colores de sistema hardcodeados (`.blue`, `.purple`, `.red`, `.green`, `.orange`, `.gray`, `Color.financeGreen`, `Color.indigo`) en UI no-dato sin token semántico (`DS.Semantic.*`) ni marker `// A11Y-DM`. Algunos son `Color.white`/`Color.black` en strokes/sombras.

| Archivo:línea | Severidad | Regla | Snippet | Fix |
|---|---|---|---|---|
| Yala/App/Views/Import/ImportIntroSheet.swift:47 | alta | `Color.financeGreen` hardcodeado | `result.isSuccess ? Color.financeGreen : ...` | `DS.Semantic.successForeground` |
| Yala/App/Views/Import/ImportIntroSheet.swift:73 | alta | `Color.financeGreen` fondo de botón | `.background(result.isSuccess ? Color.financeGreen : ...)` | `DS.Semantic.successForeground` / `DS.Gradients.success` |
| Yala/App/Views/Reports/GroupingChipsBar.swift:84 | alta | `.indigo` fondo de UI sin token | `.background(Capsule().fill(.indigo))` | `theme.accent` / `.glassEffect()` |
| Yala/App/Views/Shared/ProfileToolbarButton.swift:94 | alta | `[.yellow, .orange]` duplica `DS.Gradients.proBadge` | `colors: [.yellow, .orange]` | `DS.Gradients.proBadge` |
| Yala/App/Views/Categories/SubcategoryTransferSheet.swift:117 | media | `.blue` UI sin marker | `color: .blue` | `DS.Semantic.infoForeground` / `theme.accent` |
| Yala/App/Views/Categories/SubcategoryTransferSheet.swift:127 | media | `.purple` UI sin marker | `color: .purple` | `Color.electricIndigo` / DS.Semantic |
| Yala/App/Views/Categories/SubcategoryTransferSheet.swift:137 | media | `.red` UI | `color: .red` | `DS.Semantic.errorForeground` |
| Yala/App/Views/Categories/CategoryDetailView.swift:297 | media | `Color.primary.opacity(0.6)` texto | `.foregroundStyle(Color.primary.opacity(0.6))` | `.secondary` / `.thSecondaryText` |
| Yala/App/Views/Categories/CategoryDetailView.swift:396 | media | `Color.primary.opacity(0.6)` texto | `.foregroundStyle(Color.primary.opacity(0.6))` | `.secondary` / `.thSecondaryText` |
| Yala/App/Views/Groups/GroupDetailView.swift:141 | media | `Color.red` badge sin marker | `.fill(Color.red)` | `DS.Semantic.errorForeground` |
| Yala/App/Views/More/MoreEditorSheet.swift:56 | media | `Color.primary.opacity(0.6)` texto | `.foregroundStyle(Color.primary.opacity(0.6))` | `.secondary` / `.thSecondaryText` |
| Yala/App/Views/Onboarding/InviteRecoveryView.swift:43 | media | `.green` sin token ni marker | `.foregroundStyle(.green)` | `DS.Semantic.successForeground` |
| Yala/App/Views/Panel/NeedTrendWidget.swift:1070 | media | `.gray` semántico sin marker (inconsistente con línea 238) | `case .unclassified: return .gray` | `DS.Semantic.disabledForeground` |
| Yala/App/Views/Records/BulkEditSheet.swift:44 | media | `.blue` sistema sin marker | `case .account: return .blue` | `Color.electricIndigo` / `theme.accent` |
| Yala/App/Views/Records/BulkEditSheet.swift:45 | media | `.purple` sistema sin marker | `case .subcategory: return .purple` | `Color.electricIndigo` / DS.Semantic.info |
| Yala/App/Views/Records/BulkEditSheet.swift:46 | media | `.orange` sistema sin marker | `case .tag: return .orange` | `DS.Semantic.warningForeground` / `Color.essentialNeed` |
| Yala/App/Views/Records/BulkEditSheet.swift:47 | media | `.green` sistema sin marker | `case .note: return .green` | `DS.Semantic.successForeground` |
| Yala/App/Views/Records/BulkEditSheet.swift:48 | media | `.pink` sistema sin marker | `case .amount: return .pink` | `Color.hotPink` |
| Yala/App/Views/Reports/CashFlow/CashFlowAddLineSheet.swift:406 | media | `Color.gray` borde chip sin marker | `Color.gray.opacity(DS.Opacity.subtle)` | `.thSecondaryText.opacity(DS.Opacity.subtle)` |
| Yala/App/Views/Reports/CashFlow/CashFlowChartsSheet.swift:674 | media | `Color.gray` barras futuras sin marker | `Color.gray.opacity(0.3).gradient` | `DS.Semantic.neutralBackground.opacity(0.3)` / `.thSecondaryText` |
| Yala/App/Views/Settings/CurrencySettingsView.swift:87 | media | `Color.black` overlay sin marker | `Color.black.opacity(DS.Opacity.overlay)` | marker A11Y-DM o `Color(.systemBackground).opacity(...)` |
| Yala/App/Views/Settings/SiriShortcutsView.swift:30 | media | `.blue` icono Siri sin marker | `.foregroundStyle(.blue)` | marker A11Y-DM (identidad Siri) / `DS.Semantic.infoForeground` |
| Yala/App/Views/Settings/SiriShortcutsView.swift:92 | media | `.blue` icono Siri sin marker | `.foregroundStyle(.blue)` | marker A11Y-DM / `DS.Semantic.infoForeground` |
| Yala/App/Views/Settings/SiriShortcutsView.swift:214 | media | `.gray` fondo icono sin marker | `iconColor: .gray` | `Color(.secondarySystemFill)` / `DS.Semantic.neutralBackground` |
| Yala/App/Views/Settings/NotificationsSettingsView.swift:319 | media | `.red.opacity(0.7)` destructivo sin marker | `.foregroundStyle(.red.opacity(0.7))` | `DS.Semantic.errorForeground` |
| Yala/App/Views/Settings/SubscriptionView.swift:256 | media | `.blue` icono decorativo sin marker | `featureRow(..., color: .blue)` | `Color.electricIndigo` / `DS.Semantic.infoForeground` |
| Yala/App/Views/Settings/SubscriptionView.swift:257 | media | `.purple` decorativo sin marker | `featureRow(..., color: .purple)` | DS.Semantic / brand |
| Yala/App/Views/Settings/SubscriptionView.swift:260 | media | `.teal` decorativo sin marker | `featureRow(..., color: .teal)` | DS / brand |
| Yala/App/Views/Settings/SubscriptionView.swift:261 | media | `.orange` decorativo sin marker | `featureRow(..., color: .orange)` | `DS.Semantic.warningForeground` / `Color.essentialNeed` |
| Yala/App/Views/Settings/SubscriptionView.swift:262 | media | `.pink` decorativo sin marker | `featureRow(..., color: .pink)` | `Color.hotPink` |
| Yala/App/Views/Settings/iCloudSyncSettingsView.swift:154 | media | `.orange` sin marker | `iconBadge("person.icloud.fill", color: .orange)` | `DS.Semantic.warningForeground` |
| Yala/App/Views/Shared/MilestoneUpgradeSheet.swift:74 | media | `.purple` fondo icono sin marker | `featureRow(..., color: .purple)` | `Color.electricIndigo` / DS.Semantic |
| Yala/App/Views/Shared/MilestoneUpgradeSheet.swift:75 | media | `.blue` fondo icono sin marker | `featureRow(..., color: .blue)` | `Color.electricIndigo` |
| Yala/App/Views/Shared/StandardButtons.swift:136 | media | `.gray` disabled | `if isDisabled { return .gray }` | `DS.Semantic.disabledForeground` |
| Yala/App/Views/Shared/StandardButtons.swift:137 | media | `.red` destructivo | `if destructive { return .red }` | `DS.Semantic.errorForeground` |
| Yala/App/Views/Shared/TrialBanner.swift:32 | media | `.orange`/`.blue` sin token | `isUrgent ? .orange : .blue` | `DS.Semantic.warningForeground` / `infoForeground` |
| Yala/App/Views/Shared/UpgradePromptSheet.swift:39 | media | `.orange`/`.purple`/`.red` sin marker | `case .limitReached: return .orange` | `warningForeground` / `errorForeground` / `theme.accent` |
| Yala/App/Views/Transactions/TransactionFormRow.swift:35 | media | `.red` estado error | `.foregroundStyle(hasError ? .red : .secondary)` | `DS.Semantic.errorForeground` |
| Yala/App/Views/WhatsNew/WhatsNewConfig.swift:33 | media | `.purple` sin marker | `iconColor: .purple` | brand / DS.Semantic + marker si intencional |
| Yala/App/Views/WhatsNew/WhatsNewConfig.swift:39 | media | `.blue` sin marker | `iconColor: .blue` | `Color.electricIndigo` |
| Yala/App/Views/WhatsNew/WhatsNewConfig.swift:45 | media | `.orange` sin marker | `iconColor: .orange` | `DS.Semantic.warningForeground` / `Color.essentialNeed` |
| Yala/App/Views/WhatsNew/WhatsNewConfig.swift:56 | media | `.blue` sin marker | `iconColor: .blue` | `Color.electricIndigo` |
| Yala/App/Views/WhatsNew/WhatsNewConfig.swift:62 | media | `.orange` sin marker | `iconColor: .orange` | `DS.Semantic.warningForeground` / `Color.essentialNeed` |
| Yala/App/Views/WhatsNew/WhatsNewConfig.swift:67 | media | `.purple` sin marker | `iconColor: .purple` | `Color.electricIndigo` / brand |
| Yala/App/Views/WhatsNew/WhatsNewConfig.swift:72 | media | `.teal` sin marker | `iconColor: .teal` | `Color.neonCyan` / brand |
| Yala/App/Views/WhatsNew/WhatsNewConfig.swift:80 | media | `.green` sin marker | `iconColor: .green` | `DS.Semantic.successForeground` |
| Yala/App/Views/Accounts/AccountFormView.swift:478 | baja | `Color.white` stroke sin marker | `Color.white,` | marker A11Y-DM o `.opacity(...)` justificado |
| Yala/App/Views/Profile/ProfileView.swift:360 | baja | `Color.yellow` gradiente decorativo sin marker | `colors: [Color.yellow.opacity(0.03), Color.clear]` | marker A11Y-DM / `DS.Gradients.proBadge` |
| Yala/App/Views/Records/Components/RecordRowView.swift:119 | baja | `Color.black` sombra sin marker | `color: Color.black.opacity(theme.shadowOpacity)` | token semántico de sombra / marker A11Y-DM |
| Yala/App/Views/Reports/CashFlow/CashFlowCellMiniChart.swift:117 | baja | `Color.gray` grid line sin marker | `.foregroundStyle(Color.gray.opacity(0.1))` | `.thSecondaryText.opacity(0.1)` |
| Yala/App/Views/Reports/CashFlow/CashFlowChartsSheet.swift:830 | baja | hex fallback hardcodeado | `colorHex: icons?.colorHex ?? "#9CA3AF"` | `AppConstants.defaultColorHex` |
| Yala/App/Views/Onboarding/WelcomeRestoreView.swift:319 | baja | `Color.gray` tint icono sin marker | `tint: .gray` | `.secondary` / `DS.Semantic.neutralForeground` / marker |
| Yala/App/Views/Search/GlobalSearchView.swift:415 | baja | `Color.black` shadow sin marker | `color: Color.black.opacity(theme.shadowOpacity)` | desaparece con `.solidCard()`; o marker |
| Yala/App/Views/Shared/InfoHintButton.swift:38 | baja | `Color.accentColor` iOS en vez de `theme.accent` | `iconColor: Color.accentColor` | inyectar `@Environment(\.yalaTheme)` y usar `theme.accent` |

### Componentes

Empty states a mano en lugar de `YalaEmptyState` (filas `alta`). ⚠️ **Las filas `media` de icon-badge NO son deuda**: proponían migrar a `.yalaIconBadge*`, pero ese modifier era dead code (renderizaba `RoundedRectangle`, divergente de la convención `Circle`) y fue **eliminado el 2026-06-04**. El `ZStack + Circle + frame` hand-rolled de esas filas es la convención **correcta** → ignorar la columna *Fix* en ellas.

| Archivo:línea | Severidad | Regla | Snippet | Fix |
|---|---|---|---|---|
| Yala/App/Views/Settings/TagsSettingsListView.swift:87 | alta | empty state a mano (existe `YalaEmptyState.noTags()`) | `private var emptyState: some View { VStack { Image("tag")... } }` | `YalaEmptyState.noTags()` |
| Yala/App/Views/Statistics/RecordsTabView.swift:380 | alta | empty state a mano | `private var emptyStateContent: some View { VStack { ... } }` | `YalaEmptyState(icon:title:message:actionTitle:action:)` |
| Yala/App/Views/Planning/ScheduledPaymentRowView.swift:57 | media | icon badge 40pt manual | `ZStack { Circle().fill(Color(hex: ...)).frame(40,40) }` | `.yalaIconBadgeLarge(background:)` (nota: usa RoundedRectangle) |
| Yala/App/Views/Planning/Components/TransactionAssociationSheet.swift:158 | media | icon badge 32 manual | `Circle().fill(Color(hex: subColor)).frame(32,32)` | `.yalaIconBadgeMedium(background:)` |
| Yala/App/Views/Planning/Components/TransactionAssociationSheet.swift:166 | media | icon badge 32 manual | `Circle().fill(Color.secondary.opacity(0.2)).frame(32,32)` | `.yalaIconBadgeMedium(background:, foreground:)` |
| Yala/App/Views/Settings/iCloudSyncSettingsView.swift:168 | media | iconBadge a mano (Circle+Image) | `private func iconBadge(_:color:) -> some View` | `.yalaIconBadgeMedium(background:, foreground:)` |
| Yala/App/Views/Statistics/InsightsTabView.swift:773 | media | icon badge 32 manual | `ZStack { Circle().fill(color.opacity(0.15)).frame(32,32) ... }` | `.yalaIconBadgeMedium(background:, foreground:)` |
| Yala/App/Views/Statistics/CategoriesTabView.swift:1768 | media | icon badge 40 manual | `ZStack { Circle().fill(Color(hex:)).frame(40,40) ... }` | `.yalaIconBadgeLarge(background:)` |
| Yala/App/Views/Statistics/CategoriesTabView.swift:1857 | media | icon badge 40 manual | `ZStack { Circle().fill(Color(hex:)).frame(40,40) ... }` | `.yalaIconBadgeLarge(background:)` |
| Yala/App/Views/WhatsNew/WhatsNewSheet.swift:113 | media | icon badge a mano | `.background(Circle().fill(feature.iconColor))` | `.yalaIconBadgeLarge(background: feature.iconColor)` |

### A11y

Botones de solo-icono / elementos interactivos sin `.accessibilityLabel`, tap targets por debajo de 44pt (`DS.Button.actionSize`), y gestos de navegación sin representación accesible.

| Archivo:línea | Severidad | Regla | Snippet | Fix |
|---|---|---|---|---|
| Yala/App/Views/Accounts/AccountFormView.swift:471 | alta | swatches de color en ForEach sin `.accessibilityLabel` | `ForEach(viewModel.colorOptions, id: \.self)` | `.accessibilityLabel` por swatch |
| Yala/App/Views/Categories/CategoryDetailView.swift:181 | alta | Button sin `.accessibilityLabel` | `Button {` | `.accessibilityLabel("Editar icono y color")` |
| Yala/App/Views/Categories/SubcategoryDetailView.swift:195 | alta | Button sin `.accessibilityLabel` | `Button {` | `.accessibilityLabel("Editar icono y color")` |
| Yala/App/Views/Chat/ChatSheetView.swift:447 | alta | botón envío (arrow.up) sin label | `Button {` | `.accessibilityLabel(L10n.Chat.sendMessage)` |
| Yala/App/Views/Panel/TrendsCarouselWidget.swift:220 | alta | botón solo-icono sin label | `return Button {` | `.accessibilityLabel(type.displayName)` |
| Yala/App/Views/Panel/TrendsCarouselWidget.swift:235 | alta | tap target 32pt < 44pt | `.frame(width: 32, height: 32)` | `.contentShape(Circle())` sobre frame 44pt |
| Yala/App/Views/Profile/ProfileView.swift:283 | alta | botón avatar sin label | `Button { activeSheet = .personalDetails } label: {` | `.accessibilityLabel(L10n.Profile.edit)` |
| Yala/App/Views/Settings/NotificationEditorSheet.swift:310 | alta | tap target 36pt < 44pt | `.frame(width: 36, height: 36)` | `DS.Button.actionSize` / `.contentShape` ampliado |
| Yala/App/Views/Settings/NotificationsSettingsView.swift:321 | alta | botón trash sin label | `Button(role: .destructive) {` | `.accessibilityLabel(L10n.Action.delete)` |
| Yala/App/Views/Shared/IconColorPickerSheet.swift:308 | alta | Button color sin label | `private func colorButton(hex: String) -> some View` | `.accessibilityLabel("Color \(hex)")` |
| Yala/App/Views/Shared/IconColorPickerSheet.swift:331 | alta | ColorPicker label vacío + `.labelsHidden()` | `ColorPicker("", selection: $customColor, ...)` | `.accessibilityLabel(L10n.IconPicker.customColor)` |
| Yala/App/Views/Statistics/Components/ComparisonModeSelector.swift:43 | alta | tap target 32pt < 44pt | `.frame(width: 32, height: 32)` | `.contentShape(...)` / `.padding` a 44pt |
| Yala/App/Views/Statistics/Sankey (ComparisonModeSelector arriba) — | — | — | — | — |
| Yala/App/Views/Categories/SubcategoryTransferSheet (ver tokens) — | — | — | — | — |
| Yala/App/Views/Chat/ChatSheetView.swift:435 | media | botón mic sin label | `Button {` | `.accessibilityLabel(isRecording ? stop : start)` |
| Yala/App/Views/Chat/ChatSheetView.swift:383 | media | botón stop sin label | `Button {` | `.accessibilityLabel(L10n.Chat.stopRecording)` |
| Yala/App/Views/Filters/Components/CategorySelectorSheet.swift:149 | media | Button con imagen `.accessibilityHidden(true)` sin label | `Button { toggleCategory(...) } label: { Image(...).accessibilityHidden(true) }` | `.accessibilityLabel` seleccionar/deseleccionar |
| Yala/App/Views/Filters/Components/CategorySelectorSheet.swift:163 | media | Button chevron sin label | `Button { toggleExpanded(...) } label: { Image("chevron.down").accessibilityHidden(true) }` | `.accessibilityLabel` contraer/expandir |
| Yala/App/Views/Panel/CategoriesPieWidget.swift:768 | media | `.onTapGesture` en segmento sin a11y | `.onTapGesture {` | `.accessibilityLabel` + `.accessibilityAddTraits(.isButton)` |
| Yala/App/Views/Panel/SetupChecklistCard.swift:179 | media | tap target cerrar 28pt < 44pt | `.frame(width: 28, height: 28)` | `.padding((44-28)/2)` o frame 44pt |
| Yala/App/Views/Panel/Components/PanelSectionFooterButton.swift:36 | media | tap target minHeight 36 < 44 | `.frame(minHeight: 36)` | `.frame(minHeight: DS.Button.actionSize)` |
| Yala/App/Views/Panel/Sections/PanelHeroSection.swift:34 | media | navegación `.onTapGesture` sin a11y | `.onTapGesture {` | `.accessibilityAction(named:)` |
| Yala/App/Views/Planning/BudgetChartsView.swift:246 | media | tap target 36 < 44 + sin label | `.frame(width: 36, height: 36)` | `DS.Button.actionSize` + `.accessibilityLabel("Período anterior")` |
| Yala/App/Views/Planning/BudgetChartsView.swift:277 | media | tap target 36 < 44 + sin label | `.frame(width: 36, height: 36)` | `DS.Button.actionSize` + `.accessibilityLabel("Período siguiente")` |
| Yala/App/Views/Profile/PersonalDetailsView.swift:102 | media | Menu avatar picker sin label | `Menu {` | `.accessibilityLabel(L10n.Profile.chooseAvatar)` |
| Yala/App/Views/Records/Components/RecordsCalendarView.swift:232 | media | tap target chevron 36 < 44 | `.frame(width: 36, height: 36)` | `.contentShape(...)` / `DS.Button.actionSize` |
| Yala/App/Views/Reports/FinancialReportView.swift:295 | media | botón solo-icono sin label | `Image(systemName: "chart.bar.xaxis")` | `.accessibilityLabel(L10n.CashFlowPlan.showCharts)` |
| Yala/App/Views/Reports/GroupingReorderSheet.swift:85 | media | control imagen minus/lock sin label | `Image(systemName: dimension.isMandatory ? "lock.fill" : "minus.circle.fill")` | `.accessibilityLabel` + hint |
| Yala/App/Views/Reports/CashFlow/CashFlowLineConfigSheet.swift:314 | media | botón solo-icono sin label | `Button { ... } label: { Image("xmark.circle.fill") }` | `.accessibilityLabel(L10n.Action.delete)` |
| Yala/App/Views/Shared/IconColorPickerSheet.swift:314 | media | tap target 40 < 44 | `.frame(width: 40, height: 40)` | `.contentShape(Circle().inset(by: -2))` / frame 44 |
| Yala/App/Views/Shared/IconColorPickerSheet.swift:359 | media | botón icono sin label | `private func iconButton(name: String) -> some View` | `.accessibilityLabel(Text(name))` |
| Yala/App/Views/Statistics/RecordsTabView.swift:175 | media | botones filtro income/expense sin label | `Button { ... } label: { HStack { Image.accessibilityHidden; AmountText } }` | `.accessibilityLabel("Filtrar por ingresos: ...")` |
| Yala/App/Views/Planning/ScheduledPaymentEditorView.swift:724 | baja | tap target chip día 36 < 44 (label presente) | `.frame(width: 36, height: 36)` | `.frame(width: DS.Button.actionSize, ...)` |

---

## Deuda aceptada y notas

**(a) Pattern B es deuda incremental ACEPTADA, no un bug.** Los ~70 hallazgos de severidad baja en `backgrounds` con la forma `ZStack { PanelBackgroundView(); content }` son funcionalmente equivalentes al modifier canónico `.yalaScreenBackground(.panel)` (mismo ZStack interno). Según CLAUDE.md, este patrón está documentado como deuda a migrar **al tocar el archivo**, con un sprint dedicado de cleanup post-épico que cerrará el sanity grep "0 residuales". **No requieren acción inmediata** — se incluyen en el informe por completitud, pero su prioridad real es baja y oportunista. Lo mismo aplica al **Pattern Subtle** de las success screens (`TransactionSuccessView`, `InboxApproveSuccessView`, etc.) — semánticamente ES `.subtle`. **Importante**: aunque el fondo sea Pattern B / Subtle, los botones y empty states de esas mismas vistas **sí** deben usar `YalaPrimaryButton` / `YalaEmptyState` (ver `InboxApproveSuccessView:335`, `TransactionSuccessView:197`).

**(b) Desincronización entre UI-PATTERNS.md y el código real.** El doc de patrones menciona tokens y componentes que **no corresponden al código actual**:
- UI-PATTERNS.md referencia `Color.yalaCard`, pero el código real usa `theme.*` / `.thCard` (token semántico vía environment).
- UI-PATTERNS.md menciona `YalaTextButton`, que **no existe** en el código — el patrón real es `YalaPrimaryButton` / `YalaSecondaryButton` (+ el modifier `.selectableCard()` recién extraído).

**Recomendación:** actualizar `$VAULT/planning/UI-PATTERNS.md` para reflejar la nomenclatura real (`.thCard` / `theme.accent`, `YalaPrimaryButton`/`YalaSecondaryButton`, `.solidCard()`/`.selectableCard()`, `.yalaScreenBackground()`; los icon-badges son `Circle()` hand-rolled con tokens `DS.Icon.badge*` — la familia `.yalaIconBadge*` fue eliminada por dead code el 2026-06-04). El doc desactualizado induce a reimplementar a mano lo que ya existe — varios de los hallazgos de `glass-cards` y `botones` probablemente nacieron de seguir el doc viejo.

---

## Quick wins

Arreglos de máximo impacto y mínimo riesgo (cambios mecánicos 1:1, sin decisión de diseño):

1. **Literales que mapean exacto a un token DS** (sed mecánico, riesgo cero): los `2 → DS.Spacing.xxs`, `4 → DS.Spacing.xs`, `8 → DS.Chip.dotSize`, `24 → DS.Icon.badgeSmall`, `32 → DS.Icon.badgeMedium`, `40 → DS.Icon.badgeLarge`, `44 → DS.Button.actionSize`, `52 → DS.FormRow.minHeight`, `56 → DS.Button.fabSize`, `28 → DS.FormRow.iconWidth`. Son los **49 hallazgos altos de `tokens`** — concentrados en `GroupExpenseFormView`, `TagFormView`, `ScheduledPayments*`, `Settings/*`, `ProcessingProgressView`, `YalaSpark`.

2. **`.fontWeight(...)` apilado sobre un token que ya define el peso** (eliminar el modificador, ~15 ocurrencias): `CashFlowChartsSheet:60/468/743`, `OnboardingView:455`, `UserDataResetView:43`, `NetFlowSummaryView:31`, `PivotRowView:32`. Cero cambio visual, elimina divergencia silenciosa con el token.

3. **`.title3` → `DS.Typography.title2`** (no existe `title3` en el DS): `ExportColumnsStepView:78`, `ExportSummaryStepView:100`, `ScheduledPaymentDetailView:343`, `ScheduledPaymentEditorView:920`, `RecordsTabView:388`.

4. **Cards manuales → `.solidCard()`** (13 hallazgos altos en `glass-cards`): bloque `.background(.thCard)+.clipShape+.overlay(stroke)` → `.solidCard(radius:)`. Concentrado en `GroupsGlobalSettingsView` (×4), `GroupSettingsView` (×3), `ImportIntroSheet` (×2), `BiometricSecurityView` (×2), `Search/GlobalSearchView`, `AppIconSettingsView` (este último → `.selectableCard()`).

5. **Sheets con `.background(.thBackground)` → `.yalaScreenBackground(.panel)`** (18 hallazgos altos en `backgrounds`): `ChatSheetView`, `GroupFormView`, `GroupSettingsView`, `ImageSelectionView` (×2), `OnboardingView` (×2), `UpgradePromptSheet`, `MilestoneUpgradeSheet`, `VoiceRecordingView`, `BalanceCalculatorSheet`, `SplitCalculatorSheet`, `DowngradeResolutionSheet`, `IconColorPickerSheet`, `LanguageSelectionView`. Para sheets `.medium`/`.height(<320)` usar `.compact` (`PeriodSelectorComponents`).

6. **Empty states a mano → `YalaEmptyState`**: `TagsSettingsListView:87` (existe `YalaEmptyState.noTags()`) y `RecordsTabView:380`. Reduce LOC y unifica copy/iconografía.

7. **CTAs `.borderedProminent` / `.background(theme.accent)` a mano → `YalaPrimaryButton`** (donde el label es texto simple): `ImportCurrencyMappingSheet:229`, `ImportIntroSheet:65/165`, `TutorialCompletionView:115`, `TagFormView:91`, `NewTransactionView:1275`, `TransactionSuccessView:197`, `InboxApproveSuccessView:335`, `WelcomeRestoreView:195/381`, `InviteRecoveryView:105`, `ProUpgradeBanner:51`, los 3 selectores de Planning. (Los que tienen Menu como label, p.ej. `ExportSummaryStepView:186`, requieren un `YalaPrimaryMenuButton` nuevo — fuera de quick win.)

8. **Glow/ring Pro hardcodeado → `DS.Gradients.proBadge`**: `ProfileToolbarButton:94` (`[.yellow, .orange]` duplica el token exacto).

9. **`.glassSheet()` y chips manuales → `.glassEffect()`**: chips `Capsule + fill` en `FilterChipsSection:84/118` → `.glassEffect(.regular.interactive().tint(...), in: .capsule)` (alinea con `FilterChipView`/`PeriodSelectorLabel` canónicos).

10. **`.accessibilityLabel` en botones de solo-icono** (13 hallazgos altos en `a11y`, una línea cada uno): `ChatSheetView:447` (envío — control primario), `ProfileView:283` (avatar), `NotificationsSettingsView:321` (trash), `TrendsCarouselWidget:220`, `IconColorPickerSheet:308/331`, los Buttons de header de `CategoryDetailView:181` / `SubcategoryDetailView:195`.
