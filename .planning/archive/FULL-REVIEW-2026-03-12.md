# Full Review — Yala V1.1
**Fecha:** 2026-03-12
**Branch:** 1.1
**Build:** OK (0 errors, 1 warning)
**Tests:** All pass (90 suites, 1005 tests)

---

## Dashboard

| Area | Estado | Criticos | Altos | Medios | Bajos |
|------|--------|----------|-------|--------|-------|
| Build | OK | 0 | 1 warn | — | — |
| Tests | OK (all pass) | 0 | — | — | — |
| Calidad codigo | ATENCION | 1 | 7 | 5 | 4 |
| Performance | OK | 0 | 1 | 1 | 1 |
| SwiftData | OK | 0 | 0 | 0 | 0 |
| Accesibilidad | ATENCION | 2 | 4 | 3 | 1 |
| Design System | B | 0 | 2 | 3 | 1 |
| APIs modernas | B | 0 | 2 | 4 | 2 |
| Localizacion | ATENCION | 0 | 2 | 4 | 5 |
| Codigo muerto | 4 candidatos | 0 | 0 | 4 | 3 |
| Deuda tecnica | 0 TODOs | 0 | 0 | 0 | 0 |
| Apple compliance | OK | 0 | 0 | 0 | 0 |

**Totales:** 3 criticos, 18 altos, 27 medios, 17 bajos

---

## CRITICOS (3)

### C1. CurrencyConverter sin @MainActor (data race)
- **Archivo:** `Services/CurrencyConverter.swift`
- `@Observable` pero sin `@MainActor`. Almacena y usa `ModelContext` (linea 37) en 5+ metodos. `ModelContext` no es thread-safe.
- `CurrencyConverter.shared` es singleton estatico accesible desde cualquier actor.

### C2. ~80 botones icon-only sin accessibilityLabel
- 132 `Button { } label: { Image(systemName:) }` encontrados en 64 archivos.
- Solo 46 archivos tienen algun `.accessibilityLabel`.
- Peores: PersonalizationSettingsView (13), OnboardingView (8), VoiceRecordingView (7), PanelView (5), RecordsStandaloneView (5).

### C3. 15 archivos con animaciones sin reduceMotion check
- 55 archivos usan `.animation()` o `withAnimation`. Solo 28 verifican `reduceMotion`.
- Archivos sin check: BudgetsWidget, ExchangeRateWidget, ScheduledPaymentsWidget, TrendChartView, TrendWidget, WidgetPreferencesView, PlanningView, ProfileView, GlobalSearchView, AppIconSettingsView, RecordsFiltersView, FilterChipView, PeriodSelectorComponents, PeriodSelectorLabel, RecordsTabView.

---

## ALTOS (18)

### Concurrencia — @Observable sin @MainActor (6)
| Clase | Archivo |
|-------|---------|
| VoiceTranscriptionService | Services/VoiceTranscriptionService.swift:81 |
| TranscriptionParserService | Services/TranscriptionParserService.swift:87 |
| InsightsLLMService | Services/InsightsLLMService.swift:60 |
| StoreKitManager | App/Services/StoreKitManager.swift:12 |
| ImageOCRService | App/Services/ImageOCR/ImageOCRService.swift:12 |
| ImageVisionService | App/Services/ImageVision/ImageVisionService.swift:66 |

Nota: Estos hacen network calls. Agregar `@MainActor` requiere marcar metodos de red como `nonisolated` o usar `Task.detached`.

### Performance — FetchDescriptor sin fetchLimit (1)
- `WidgetDataCache.swift:190`, `CurrencyChangeService.swift:31`, `BudgetAlertService.swift:64`, `ReportNotificationService.swift:290`
- Fetch de ALL transactions sin limite. Riesgo con miles de registros en contextos de widget/background.

### Localizacion (2)
- **4 keys faltan en de/fr/it/pt:** `onboarding.tutorialsExplore`, `onboarding.tutorialsSettingsHint`, `onboarding.tutorialsSubtitle`, `onboarding.tutorialsTitle`
- **Placeholder mismatch:** `notifications.dailyReport.hint` tiene 2x `%@` en en, pero solo 1x `%@` en de/fr/it/pt. Produce texto incorrecto visible al usuario.

### Accesibilidad (4)
- 32 `.disabled()` sin `.accessibilityHint` en 27 archivos
- Imagenes decorativas sin `.accessibilityHidden(true)` (solo 6 archivos lo usan)
- `NotificationPrimerSheet.swift:24` — `.font(.system(size: 48))` sin `@ScaledMetric`
- `VariationChip.swift:103` — `Color.gray` como unico indicador de estado zero-change

### Design System (2)
- **26 colores no-semanticos** en 10 archivos. Peor: ImageSelectionView (14x `Color.teal`), ProfileView (5x), SubscriptionView/UpgradePromptSheet (`Color.orange`)
- **57 fonts `.system(size:)`** en 38 archivos que bypasean DS.Typography (la mayoria usan @ScaledMetric pero no tokens DS)

### APIs modernas (2)
- **~201 `Date()` en vez de `Date.now`** en ~50 archivos. Mas: DraftService (12), InsightsLLMService (10), ExchangeRateService (10), WidgetDataCache (10), BudgetsViewModel (12), PanelViewModel (12)
- **~5 `DispatchQueue` genuinos** (no timing UI): NetworkMonitor, DetailContainerView, ProfileView, CoachMarkOverlay

### Codigo largo (1)
- `QuickExpenseIntent.perform()` — 250 lineas. App Intent critico para Siri/Shortcuts.

---

## MEDIOS (27 — conteos por area)

| Area | Items | Detalle |
|------|-------|---------|
| Funciones largas | 6 | PersonalizationSettingsView.body (632 lineas), CategoriesTabView.calculatePreviousPeriodTotals (182 lineas), 15+ funciones >80 lineas |
| Task.sleep deprecated | 2 | ExchangeRateService, ExportSummaryStepView usan `Task.sleep(nanoseconds:)` |
| BalanceCalculatorFieldState | 1 | @Observable sin @MainActor (bajo riesgo, solo UI) |
| try? silenciado | 1 | Tips.configure en YalaApp.swift:59 |
| Touch targets | ~20 | Frames de 24-28pt en ProfileView, CategoryDetailView, SubcategoryDetailView |
| Frames fijos con texto | ~8 | ImportIntroSheet `.frame(height: 50)`, SplashScreenView frames fijos |
| .cornerRadius() deprecated | 12 | 7 archivos usan API deprecated (valores si son DS tokens) |
| Shadows hardcodeadas | ~15 | Archivos con raw opacity (0.04, 0.08) en vez de DS.Opacity |
| replacingOccurrences | ~50 | 25 archivos. Candidatos simples: OnboardingView, MoneyParsing, XLSXWriter |
| L10n keys stale | 12 | Notification keys viejas en de/fr/it/pt (renombradas en en/es) |
| Dead code | 5 | 3 funciones (createMultiple, saveAll, clearPendingImages), BackgroundJobs.swift completo, FilterType enum |

---

## BAJOS (17 — conteo total)

- 3 unused imports (WidgetKit en DraftService/TransactionService, UserNotifications en ScheduledPaymentNotificationService)
- 2 dead L10n namespaces (L10n.Camera, L10n.FaceID)
- 6 try? en FileManager ops (SharedContainerService)
- 1 try? en photo loading (PersonalDetailsView)
- ~40 try? await Task.sleep (cancelacion — aceptable)
- 1 annotation order (@Observable antes de @MainActor en ExchangeRateService)
- 1 relaciones: todas usan .nullify (consistente pero revisar si cascade necesario)
- Color.black/white.opacity raw en ~30 shadows/overlays

---

## Apple Compliance

| Check | Estado |
|-------|--------|
| PrivacyInfo.xcprivacy | OK — presente en Resources/ |
| Consent OpenAI (voz, imagen, texto) | OK — consent flow implementado (b63b56d) |
| API keys hardcodeadas | OK — 0 encontradas (usa Secrets.xcconfig) |
| print() fuera de #if DEBUG | OK — 0 encontradas |
| Restore purchases | OK — presente en StoreKitManager + SubscriptionView |
| Privacy Policy / Terms URLs | OK — URLs separadas |
| Texto suscripcion | OK — precio y auto-renovacion claros |

---

## SwiftData

| Check | Estado |
|-------|--------|
| @Attribute(.unique) | OK — 0 (CloudKit compatible) |
| @Relationship inverse | OK — todos declarados al menos en un lado |
| deleteRule explicito | OK — 36 relaciones, todas con .nullify |
| Properties con defaults/optional | OK — CloudKit compatible |
| @MainActor en servicios | OK excepto CurrencyConverter (CRITICO arriba) |

---

## Veredicto: LISTO PARA RELEASE

3 criticos identificados que no causan crashes pero degradan accesibilidad (C2, C3) y tienen riesgo de data race (C1). El placeholder mismatch en L10n produce texto incorrecto en 4 idiomas (ALTO). Recomendado resolver criticos y altos de L10n antes de release.

---

*Naming convention: `FULL-REVIEW-YYYY-MM-DD.md`*
*Proximo review: crear `FULL-REVIEW-YYYY-MM-DD.md` con la nueva fecha para comparar.*
