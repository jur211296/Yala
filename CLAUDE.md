# Yala (iOS)

Yala es una app iOS de finanzas personales. Objetivo: entender gastos, cuentas, presupuestos y reportes con claridad.

## Stack

- Swift, SwiftUI, SwiftData (.xcodeproj)
- **Target iOS 26+** — APIs nativas (Liquid Glass, ToolbarSpacer, etc.)
- Schemes: **Yala** (producción) | **Yala Dev** (con toggle Pro y `DEV_BUILD`) | Tests: YalaTests
- Simulador: **iPhone 17 Pro**
- 20 SwiftData models. ModelContainer via `SwiftDataConfiguration`. Divisas SSOT en `Yala/Utils/CurrencyUtils.swift` (`CurrencyCode`, 48 divisas).

## Docs (leer cuando sea relevante)

| Archivo | Propósito |
|---------|-----------|
| `$VAULT/planning/CODEBASE-MAP.md` | Tablas de Services / Calculators / ViewModels / Tests con paths |
| `$VAULT/planning/UI-PATTERNS.md` | Design System, gotchas de SwiftUI, formularios, glass |
| `$VAULT/planning/SWIFT-STYLE.md` | ViewModel pattern, idioms modernos, DS.Semantic / DS.Gradients, "añadir preferencia" |
| `$VAULT/planning/L10N.md` | 16 locales, workflow para añadir keys, tests CI |
| `$VAULT/planning/DEVICE-QA.md` | Setup Yala Dev + agent-device patterns |
| `$VAULT/planning/BRAND-VOICE.md` | Tono y estilo de marca |
| `$VAULT/planning/WORKFLOW.md` | Workflow detallado de skills |
| `$VAULT/planning/PROJECT.md` · `ROADMAP.md` · `STATE.md` | Producto, plan, progreso |
| `$VAULT/planning/DECISIONS.md` | Registro de decisiones arquitectura |
| `$VAULT/planning/QA-SCENARIOS.md` | Escenarios de prueba |
| `qa/README.md` | QA automatizado (agent-device + suites) |

`$VAULT` = `~/Library/Mobile Documents/iCloud~md~obsidian/Documents/YalaWiki/` (Obsidian, sync vía iCloud).

Carpetas del vault: `Backlog/` · `Ideas/` · `Bugs/` · `Attachments/` · `planning/`. Skills: `/backlog`, `/spec`, `/promote`.

## General Rules

- Hacer SOLO los cambios explícitamente solicitados. No mover UI, refactorizar adyacente, ni añadir mejoras no pedidas.
- Antes de editar, listar archivos a modificar y qué cambia. Esperar aprobación si son más de 3 archivos.
- Confirmar que rutas referenciadas existen antes de proceder. Si no, preguntar al usuario.
- Evitar refactors grandes innecesarios. No introducir dependencias nuevas sin justificación.
- Mantener separación UI / lógica / SwiftData.

## Reglas inviolables

### Errores y unwraps
- NUNCA `try?` que silencia. Usar `do { try } catch { print("Service: Error: \(error)") }`.
- NUNCA force unwraps sin validación previa (`guard let x = ... else { return }`).
- Logs SIEMPRE dentro de `#if DEBUG` — nunca datos sensibles en producción.
- API keys: NUNCA hardcodear. Usar `Secrets.xcconfig` + `Info.plist` via `Bundle.main.object(forInfoDictionaryKey:)`.

### SwiftData
- SIEMPRE `@Relationship(inverse:)` en relaciones bidireccionales.
- Verificar `deleteRule` en cada relación.
- `@MainActor` en servicios que manipulan `ModelContext`.
- **CloudKit compat:** NUNCA `@Attribute(.unique)`, propiedades con default obligatorias, ni relaciones non-optional.

### State Management (SwiftUI)
- `@Observable` SIEMPRE con `@MainActor`. `@State` SIEMPRE `private`.
- NUNCA `Binding(get:set:)` en body — usar `@Binding` + `.onChange()`.
- NUNCA `@AppStorage` dentro de `@Observable` (no triggerea updates).
- Preferir `@Observable` + `@State`/`@Bindable` sobre `ObservableObject`/`@Published`/`@StateObject`.
- **Preferencias persistentes → `AppPreferences` inyectado via `@Environment`.** NUNCA `@AppStorage` directo en views nuevas.

### Gotchas críticos
- **`containerRelativeFrame(.horizontal)` en `ScrollView(.vertical)` con `.contentMargins`** → deadlock de layout, splash nunca dismissa, sin crash log. Usar `onGeometryChange`. Detalles en UI-PATTERNS.md.
- **`YalaFormatter` no auto-refresca prefs** — lee `UserDefaults` directo. Vista que lo use con `decimalPlaces` o `currencyDisplayFormat` debe inyectar `@Environment(AppPreferences.self)` y leer `let _ = appPreferences.X` en body para registrar dependencia.
- **Forms con `TextField`/`TextEditor`/`SecureField`** (sin `Form`): obligatorio `dismissKeyboardOnTap()` desde el primer commit. Detalles en SWIFT-STYLE.md.

### iOS 26 Liquid Glass (OBLIGATORIO)
- `ToolbarSpacer(.fixed, placement: .topBarTrailing)` — placement es OBLIGATORIO.
- `.glassEffect()` para chips, barras flotantes, elementos translúcidos.
- Si existe API iOS 26 que mejore integración con sistema, USARLA.

### Tests (OBLIGATORIO)
Detalles completos en `$VAULT/planning/TESTING-STRATEGY.md`. Reglas mínimas:
- `makeTestContext()` es seguro desde Fase 5 (2026-04-29) — usa UUID suffix + `isRunningTests` detecta Swift Testing. Aún así prefiere `@Model` directos sin contexto cuando la lógica lo permite (más rápido).
- NUNCA `UserDefaults.standard` directo en tests → `UserDefaults(suiteName: "test.\(UUID().uuidString)")!` (helper `makeIsolatedDefaults()`).
- NUNCA tocar singletons `.shared` sin `@Suite(.serialized)` + `defer { restore }` o `_testReset()`.
- NUNCA `Task.sleep(.seconds(N))` con N>0.5 — usar señales determinísticas. Excepción: `≤50ms` para forzar dealloc.
- NUNCA `Date()` / `Calendar.current` en lógica testeada — inyectar vía param opcional `now: Date = .now` (patrón canónico, ya en `FinancialScoreCalculator`/`BudgetAlertService`).
- NUNCA `@Test(.disabled(...))` sin entrada en Lista Negra (TESTING-STRATEGY.md) con owner + deadline.
- NUNCA declarar fix completo si un test falla. "Preexistente" no es excusa: arreglar o registrar en Lista Negra con plan.
- Ejecutar SIEMPRE con `-parallel-testing-enabled NO` (iOS 26 simulator clones crashean).

### Audit markers
- `// A11Y-DT:` justifica font size hardcodeado (Dynamic Type).
- `// A11Y-DM:` justifica color hardcodeado (Dark Mode).

### Design System (en cambios UI)
- SIEMPRE `DS.Spacing`, `DS.Radius`, `DS.Typography`, `DS.Semantic.*`, `DS.Gradients.*` — NUNCA hardcoded.
- SIEMPRE filas clicables con `Button` + `contentShape(Rectangle())`.
- Componentes estándar: `YalaPrimaryButton`, `YalaEmptyState`, etc.
- Tablas DS.Semantic / DS.Gradients en SWIFT-STYLE.md.

### Documentation & copy
- Describir features desde la perspectiva del USUARIO, no técnica.
- NUNCA fabricar features — solo lo confirmado en scope.
- Copy nuevo: leer BRAND-VOICE.md.

## Workflow

Skills disponibles vienen en el system-reminder de cada sesión. Flujos canónicos:

```
Feature:    /clear → /next → Plan Mode → /review-plan → implementar →
            /verify-ios → /test-smart → /device-qa → /swift-audit → /commit-one → /clear
Bug fix:    /next → implementar → /verify-ios → /device-qa → /commit-one
Autónomo:   /clear → /next → Plan Mode → /review-plan → /yolo
Complejo:   añade /analyze-impact antes de Plan Mode + /simplify antes de commit
```

**Regla QA-SCENARIOS:** cada feature nueva requiere escenarios en `$VAULT/planning/QA-SCENARIOS.md` ANTES del commit.

## Testing

| Tipo de cambio | Comando |
|----------------|---------|
| Modelo / servicio | `/test-smart` (relevantes) |
| Solo UI (Views) | `/verify-ios` |
| Antes de commit | `/test-smart` siempre |
| Tras merge / refactor grande | `/test-ios` (todos) |

Después de implementar cualquier cambio, SIEMPRE ejecutar `/verify-ios` o `xcodebuild` antes de presentar como completado.

## Corrección de errores

- SIEMPRE buscar TODAS las instancias del mismo patrón antes de declarar fix completo.
- NO confiar ciegamente en "BUILD SUCCEEDED" — verificar todos los casos.
- Si hay errores tras build exitoso, limpiar cache: `xcodebuild clean`.

## Self-Maintenance

Cuando se modifican modelos / servicios / ViewModels:
- Actualizar tablas en `$VAULT/planning/CODEBASE-MAP.md`.
- Actualizar conteo de tests si se agregaron nuevos.
- Agregar gotchas descubiertos a "Reglas inviolables" de este archivo.

Para preferencias nuevas (`UserDefaults`): ver checklist en SWIFT-STYLE.md sección "añadir una preferencia nueva".

## Control de Ejecución

Después de implementar código:
1. Mostrar resumen de cambios.
2. Sugerir siguiente paso.
3. DETENERSE y esperar instrucción del usuario.
4. NO ejecutar verificaciones o commits automáticamente.

**Git:** ejecutar cada comando de lectura UNA SOLA VEZ, secuencialmente, nunca en paralelo. No matar shells con git en curso.

**Tags:** SIEMPRE semver con prefijo `v` → `v1.0.0`, `v1.1.0`. Nunca sin prefijo o sin 3 componentes.

## Decisiones Recientes (TTL: hasta cierre de fase)

[Formato: [FECHA] Decisión breve — se archiva en DECISIONS.md al cerrar fase. Máx 3-5 entradas activas.]

- [2026-04-28] Traducciones reales keys-por-keys de los 4 locales nuevos (nl `b3f16aba`, pl `d6b3748e`, zh-Hans `d6697ec5`, ja `8891408f`). Cierra épico l10n M14 — reemplaza rule-based v0. Approach validado: ~17 Edits grandes (50-150 keys), `grep -c` por Edit, sesión ~60 min. Decisiones específicas por locale (forma です/ます ja, pronombre `你` zh, voseo es-AR, glosarios financieros, counter words contextuales, placeholder reorder con notación positional para idiomas SOV). Pendiente: device QA visual en simulador para los 4 locales. Siguiente: M16 (ASC metadata localizada).
- [2026-04-28] 3 fixes runtime logs post-QA chat-registrar-transacciones (`773fe651` + `35bd11d1` + `aade3042`). (1) Sheet collision chat→NTV — gate del consumer `.panel` mientras `showChatSheet=true` vía markUnready/markReady del AppRouter. (2) ProfileImageStorage — guard `fileExists` antes de `Data(contentsOf:)` (caso normal vs error real). (3) UserSegmentService race — `currentSegment` se leía como `.dormant` durante cold start (recalculate antes del primer importEvent). Fix con NotificationCenter (patrón establecido) + 2 flags separadas (`hasCompletedFirstImport` en iCloudSyncService + `hasRecalculatedAfterFirstImport` en UserSegmentService) + helper `markRecalculatedAfterFirstImport()`. AppBootstrapper:555 gate-ea con la flag — caía a "require interaction" si segmento no confiable. Tests: 2 nuevos (`@Suite(.serialized)` en UserSegmentService). Pendiente: device QA con cold launch + cuenta poblada >100 tx (verificar log `(pre-import)` en primer scan).
