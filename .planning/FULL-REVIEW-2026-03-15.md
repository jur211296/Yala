# Full Review — Yala v1.1
**Fecha:** 2026-03-15
**Branch:** 1.1.1
**Build:** OK (0 errors, 1 warning)
**Tests:** All pass (90 suites, 1005 tests)

---

## Dashboard

| Area | Estado | Criticos | Altos | Medios | Bajos |
|------|--------|----------|-------|--------|-------|
| Build | OK | 0 | 0 | 1 warn | — |
| Tests | OK (1005/1005) | 0 | — | — | — |
| Calidad codigo | OK | 0 | 4 | 23 | 8 |
| Performance | OK | 0 | 5 | 20 | — |
| SwiftData | OK | 0 | 0 | — | — |
| Accesibilidad | ATENCION | 0 | 5 | 11 | 87 |
| Design System | B | 0 | 4 | 3 | 160 |
| APIs modernas | ATENCION | 0 | 3 | 2 | 2 |
| Localizacion | OK | 0 | 0 | 0 | 0 |
| Codigo muerto | 14 candidatos | 0 | 0 | 14 | — |
| Deuda tecnica | 0 TODOs | 0 | 0 | 0 | 0 |
| Apple compliance | OK | 0 | 0 | — | — |

**Totales (post-fix):** 0 criticos, 21 altos, 76 medios, 258 bajos
*Nota: C1-C3 y C5 resueltos. C4 reclasificado a MEDIO, C6 a BAJO, C7 a ALTO.*

---

## Comparativa vs Review 2026-03-12

| Area | 03-12 | 03-15 | Cambio |
|------|-------|-------|--------|
| Criticos | 3 | 0 | Todos resueltos |
| Altos | 18 | 21 | +3 |
| Localizacion | 2 altos | 0 | RESUELTO — cobertura perfecta |
| Deuda tecnica | 0 | 0 | Limpio |
| SwiftData | OK | OK | Sin cambios |
| Apple compliance | OK | OK | Sin cambios |

Nota: El aumento en criticos/altos se debe a mayor profundidad del escaneo (3 agentes paralelos), no a regresiones. Los criticos C1 (CurrencyConverter sin @MainActor) y L10n (keys faltantes, placeholder mismatch) del review anterior fueron resueltos.

---

## CRITICOS (7) — Revision exhaustiva

### C1. ~~FetchDescriptor sin predicate ni fetchLimit — ProfileViewModel~~ RESUELTO
- **Archivo:** `App/ViewModels/ProfileViewModel.swift`
- **Fix aplicado:** Reemplazado `allTransactions` array + `fetch()` por `hasTransactions` bool + `fetchCount()`. Zero transacciones cargadas en memoria.

### C2. ~~FetchDescriptor sin predicate ni fetchLimit — RecordsFiltersViewModel~~ RESUELTO
- **Archivo:** `App/ViewModels/RecordsFiltersViewModel.swift`
- **Fix aplicado:** Currencies derivadas de `allAccounts` (ya cargadas, ~5-10) filtrando cuentas con transacciones, en vez de fetch de todas las transacciones.

### C3. ~~FetchDescriptor sin predicate ni fetchLimit — CategoryDetailViewModel~~ RESUELTO
- **Archivos:** `App/ViewModels/CategoryDetailViewModel.swift`, `App/ViewModels/CategoriesSettingsListViewModel.swift`
- **Fix aplicado:** CategoryDetailViewModel reutiliza `deletionService.transactionCount(forCategory:)` (fetchCount + #Predicate). CategoriesSettingsListViewModel usa fetchCount + #Predicate directamente.

### C4. DispatchWorkItem + [weak self] en struct View — RECLASIFICADO: NO ES CRITICO
- **Archivo:** `App/Views/Settings/TutorialDetailView.swift:318`
- **Hallazgo real:** NO es una struct View. Es `LoopingPlayerUIView`, una `final class` que hereda de `UIView` (linea 260). Es un UIKit view wrapeado via `UIViewRepresentable`. Las clases SI tienen weak references — el `[weak self]` es correcto y necesario.
- **Uso real:** El `DispatchWorkItem` programa un restart del video con delay de 2 segundos. Se cancela correctamente en `cleanUp()` y `deinit`.
- **Fix real:** Reemplazar `DispatchQueue.main.asyncAfter` por `Task { try await Task.sleep(for: .seconds(2)) }` para consistencia con Swift Concurrency. Pero el patron actual es funcionalmente correcto.
- **Esfuerzo:** XS (5 min) — Reemplazar por Task, pero es opcional ya que el codigo es correcto.
- **Riesgo:** Ninguno. El patron actual funciona correctamente.
- **RECLASIFICACION:** Bajar a MEDIO. No es un bug ni un patron incorrecto.

### C5. ~~SharedContainerService — 6 try? FileManager sin log~~ RESUELTO
- **Archivo:** `Services/SharedContainerService.swift`
- **Fix aplicado:** do/catch con logging en paths criticos (`ensurePendingImagesDirectory`, `pendingImageURLs`). Mantenido try? en cleanup (`removePendingImage`, `clearOldPendingImages`).

### C6. ~~Font hardcoded size 48 sin @ScaledMetric~~ RESUELTO (reclasificado a BAJO)
- **Archivo:** `App/Views/Profile/ProfileView.swift:1050`
- **Fix aplicado:** Agregado comentario `// A11Y-DT: debug-only seed progress view`. Dentro de `#if DEBUG`, no afecta usuarios.

### C7. Typography raw en insight cards
- **Archivo:** `App/Views/Panel/PanelView.swift:1750,1789`
- **Problema:** `.font(.title2)` en iconos de ContextualInsightCard (linea 1750) y SiriTipCard (linea 1789) en vez de DS.Typography.
- **Uso real:** Es el icono decorativo (sparkles, mic.badge.plus) dentro de las cards. Ambas cards si usan `DS.Typography.caption` y `DS.Typography.headline` para el texto. Solo el icono usa `.title2` para sizing.
- **Fix:** Reemplazar `.font(.title2)` por un token DS o `@ScaledMetric` para el tamano del icono. Nota: el icono ya tiene `.frame(width: 36, height: 36)` que tambien deberia usar DS token.
- **Esfuerzo:** XS (5 min) — Cambiar 2 lineas a DS.Typography y 2 frames a DS token.
- **Riesgo:** Ninguno. Cambio visual minimo.
- **RECLASIFICACION:** Bajar a ALTO. Es inconsistencia DS, no un bug critico.

---

## Resumen de reclasificaciones

| ID | Severidad original | Severidad real | Razon |
|----|-------------------|----------------|-------|
| C1 | CRITICO | **CRITICO** | Confirmado — carga toda la BD para un booleano |
| C2 | CRITICO | **CRITICO** | Confirmado — limitacion SwiftData pero mitigable |
| C3 | CRITICO | **CRITICO** | Confirmado — se repite en 2 ViewModels |
| C4 | CRITICO | **MEDIO** | Es una UIView class, no struct. Patron correcto. |
| C5 | CRITICO | **ALTO** | Riesgo real pero acotado a Share Extension |
| C6 | CRITICO | **BAJO** | Dentro de #if DEBUG, no afecta usuarios |
| C7 | CRITICO | **ALTO** | Inconsistencia DS, no bug funcional |

**Criticos reales: 3** (C1, C2, C3 — todos FetchDescriptor sin limite)
**Esfuerzo total para resolver los 3 criticos: ~40 min**
**Esfuerzo total para resolver los 7 originales: ~60 min**

---

## ALTOS (21)

### Performance (5)
| # | Archivo | Descripcion |
|---|---------|-------------|
| 1 | `App/Views/Settings/CurrencySelectorView.swift:45` | ScrollView+ForEach sin LazyVStack (48 currencies) |
| 2 | `App/Views/Settings/ExchangeRatesSheet.swift:33` | ScrollView+ForEach sin LazyVStack |
| 3 | `App/Views/Search/GlobalSearchView.swift:165` | ScrollView horizontal+ForEach sin LazyHStack |
| 4 | `App/ViewModels/SubcategoryTransferViewModel.swift:102,118,140` | 3 FetchDescriptor sin predicate |
| 5 | `App/ViewModels/CategoriesSettingsListViewModel.swift:132` | FetchDescriptor sin predicate para contar por categoria |

### Calidad codigo (4)
| # | Archivo | Descripcion |
|---|---------|-------------|
| 6 | `App/Views/Settings/PersonalizationSettingsView.swift:79` | body de 632 lineas — extraer sub-vistas |
| 7 | `App/Intents/QuickExpenseIntent.swift:1147` | perform() de 250 lineas |
| 8 | `App/ContentView.swift:52` | body de 236 lineas |
| 9 | `Seed/DevSeedTransactions.swift:112-114` | 3 force unwraps (comps.day!, comps.month!, comps.weekday!) |

### Accesibilidad (5)
| # | Archivo | Descripcion |
|---|---------|-------------|
| 10 | `App/Views/Panel/PanelView.swift:~45,52` | 2 botones icon-only (bell, gearshape) sin accessibilityLabel |
| 11 | `App/Views/Transactions/NewTransactionView.swift:~180,185` | 2 botones toolbar (camera, mic) sin accessibilityLabel |
| 12 | `App/Views/Inbox/InboxView.swift:~62` | Boton trash sin accessibilityLabel |
| 13 | 47 archivos | Animaciones sin chequeo reduceMotion (65 usan animacion, solo 18 verifican) |
| 14 | PieChart widgets | `.font(.system(size: fontSize))` dinamico sin `@ScaledMetric` |

### Design System (4)
| # | Descripcion |
|---|-------------|
| 15 | 31 instancias de `.font(.title2/.caption/.subheadline)` en 17 archivos en vez de DS.Typography |
| 16 | 19 instancias de `.foregroundStyle(.red/.orange/.green)` en 15 archivos en vez de DS.Semantic |
| 17 | 130+ instancias de `.foregroundStyle(.white)` en 70+ archivos — bypasea sistema semantico |
| 18 | Solo 1 padding hardcodeado encontrado (excelente mejora) |

### APIs modernas (3)
| # | Descripcion |
|---|-------------|
| 19 | 37 `DispatchQueue.main.asyncAfter` en 22 archivos en vez de Swift Concurrency |
| 20 | 55 `replacingOccurrences(of:with:)` en 23 archivos en vez de `replacing(_:with:)` |
| 21 | 98 `.navigationBarTitleDisplayMode` — consolidable en ViewModifier |

---

## MEDIOS (74 — conteos por area)

| Area | Items | Detalle |
|------|-------|---------|
| Calidad codigo | 23 | 28 DispatchQueue.main.asyncAfter en Views, 5 try? sin log en SharedContainerService, 30+ funciones 50-200 lineas |
| Performance | 20 | 16 ScrollView+ForEach sin LazyVStack en vistas menores, 4 FetchDescriptor en servicios de migracion/import (one-shot) |
| Accesibilidad | 11 | accessibilityHidden(true) solo en 6 archivos, 219+ elementos decorativos sin marcar |
| Design System | 3 | .font(.body.monospacedDigit()) sin DS tokens, minor |
| APIs modernas | 2 | Date() y filter().count ya modernizados (0 encontrados) |
| Codigo muerto | 14 | Ver seccion dedicada abajo |

---

## BAJOS (256 total)

- 86 oportunidades de accessibilityLabel adicionales
- 160 usos de `Color(hex:)` — esperado para colores de categoria/tag configurables por usuario
- 8 try? aceptables (Tips.configure, AttributedString(markdown:), NSRegularExpression, Task.sleep)
- 3 try? sin logging en `SharedContainerService` cleanup (`removePendingImage`, `clearOldPendingImages`) — aceptable para cleanup de archivos temporales, agregar do/catch cuando se toque el archivo
- 2 oportunidades Liquid Glass (FilterChipView, SectionBox)

---

## Codigo muerto — 14 candidatos

| # | Archivo | Linea | Descripcion |
|---|---------|-------|-------------|
| 1 | `App/ViewModels/PanelViewModel.swift` | :985 | `calculateTrendWidget()` nunca llamada |
| 2 | `App/ViewModels/PanelViewModel.swift` | :996 | `processTrendPoints()` nunca llamada |
| 3 | `App/Logic/Helpers/BalanceHelper.swift` | :174 | `convertToPreferredCurrency()` nunca llamada |
| 4 | `App/Views/Statistics/TrendsTabView.swift` | :1330 | `getPreviousPeriodInterval()` nunca llamada |
| 5 | `App/Views/Panel/SubcategoriesPieWidget.swift` | :483 | `smallLayout()` nunca llamada |
| 6 | `App/Views/Panel/CategoriesPieWidget.swift` | :486 | `smallLayout()` nunca llamada |
| 7 | `App/Views/Panel/NeedTrendWidget.swift` | :295 | `getTotal()` nunca llamada |
| 8 | `App/Views/Panel/PanelView.swift` | :1111 | `skeletonView()` nunca llamada |
| 9 | `App/Views/Panel/ExchangeRateWidget.swift` | :540 | `calendarUnit()` nunca llamada |
| 10 | `App/ViewModels/StatisticsViewModel.swift` | :37 | `enum MetricLockState` sin referencias |
| 11 | `App/Models/SharedModels.swift` | :364 | `struct NeedSpendingSummary` sin referencias |
| 12 | `App/AppBootstrapper.swift` | :9 | `import CoreData` sin usar |
| 13 | `App/Views/Statistics/FilterChipModels.swift` | — | `CategoryChip`, `SubcategoryChip` sin refs externas |
| 14 | `App/Views/Shared/YalaLoadingOverlay.swift` | — | `YalaLoadingFullScreen` sin refs externas |

---

## Apple Compliance

| Check | Estado |
|-------|--------|
| PrivacyInfo.xcprivacy | OK — UserDefaults (CA92.1), FileTimestamp (C617.1), AudioData, Photos |
| Consent OpenAI (voz, imagen, texto) | OK — consent flow implementado |
| API keys hardcodeadas | OK — 0 (usa Secrets.xcconfig + Bundle.main.object) |
| print() fuera de #if DEBUG | OK — 0 de 378 prints |
| Restore purchases | OK — presente en SubscriptionView |
| Privacy Policy / Terms URLs | OK — URLs separadas, links en settings y subscription |
| Texto suscripcion | OK — precio, auto-renovacion, legalFooter en 6 idiomas |

---

## SwiftData

| Check | Estado |
|-------|--------|
| @Attribute(.unique) | OK — 0 (CloudKit compatible) |
| @Relationship inverse | OK — todos declarados en un lado |
| deleteRule explicito | OK — 40 relaciones, todas con .nullify |
| Properties con defaults/optional | OK — CloudKit compatible |
| @MainActor en servicios | OK — todos los servicios con ModelContext |
| init explicito | OK — 12/12 modelos |

---

## Highlights positivos
- 1005 tests, 0 fallos, 90 suites
- SwiftData impecable (12 modelos, CloudKit compatible)
- Localizacion perfecta (6 idiomas, 2161+117 keys, 0 gaps, 0 vacios, 0 placeholder mismatches)
- 0 TODO/FIXME/HACK en todo el codebase
- 0 API keys hardcodeadas, 0 prints fuera de DEBUG
- Ya migrado a @Observable (0 ObservableObject legacy), 0 Date(), 0 @available checks
- Apple compliance completo

---

## Veredicto: LISTO PARA RELEASE — 0 criticos

Todos los criticos resueltos (C1-C3: fetchCount/predicate, C5: do/catch logging, C6: A11Y-DT marker). C4 y C7 reclasificados a MEDIO y ALTO respectivamente — mejoras opcionales, no bloqueantes.

---

*Naming convention: `FULL-REVIEW-YYYY-MM-DD.md`*
*Review anterior: `FULL-REVIEW-2026-03-12.md`*
*Proximo review: crear `FULL-REVIEW-YYYY-MM-DD.md` con la nueva fecha para comparar.*
