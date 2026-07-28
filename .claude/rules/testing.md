---
description: Reglas inviolables de tests: Swift Testing, makeTestContext, paralelismo y XCUITest. Se cargan al escribir o tocar tests.
paths:
  - "YalaTests/**"
  - "YalaUITests/**"
---
# Tests

Detalles completos en `$VAULT/planning/TESTING-STRATEGY.md`. Reglas mínimas:
- `makeTestContext()` **REUSA un `ModelContainer` in-memory por archivo (`#fileID`)**, no uno por llamada (2026-07-04): crear >~15 containers in-memory en un proceso acumula estado global de SwiftData → `EXC_BREAKPOINT` no atrapable (crash-loop; iOS 26.2 y 26.5). ⇒ **toda suite con ≥2 `makeTestContext()` DEBE ser `@Suite(.serialized)`**. Residual conocido: los SUTs que spawnean `Task { @MainActor in save() }` huérfanos (CSV backfill, dedup repair) racean con el reuso → 2 tests flaky bajo suite completa (Lista Negra en TESTING-STRATEGY.md). Prefiere `@Model` directos sin contexto cuando la lógica lo permite (más rápido y sin este acoplamiento).
- NUNCA `UserDefaults.standard` directo en tests → `UserDefaults(suiteName: "test.\(UUID().uuidString)")!` (helper `makeIsolatedDefaults()`).
- NUNCA tocar singletons `.shared` sin `@Suite(.serialized)` + `defer { restore }` o `_testReset()`.
- NUNCA `Task.sleep(.seconds(N))` con N>0.5 — usar señales determinísticas. Excepción: `≤50ms` para forzar dealloc.
- NUNCA `Date()` / `Calendar.current` en lógica testeada — inyectar vía param opcional `now: Date = .now` (patrón canónico, ya en `FinancialScoreCalculator`/`BudgetAlertService`).
- NUNCA `@Test(.disabled(...))` sin entrada en Lista Negra (TESTING-STRATEGY.md) con owner + deadline.
- NUNCA declarar fix completo si un test falla. "Preexistente" no es excusa: arreglar o registrar en Lista Negra con plan.
- Ejecutar con `-parallel-testing-enabled NO` (2026-07-04): con el reuso per-file de `makeTestContext`, parallel OFF es determinista (~7s) y no crashea; parallel YES destapa una race de singleton (`AppLanguageSyncTests`). Antes se recomendaba YES.


## XCUITest (regresión UI determinista) — `YalaUITests`
- Scheme **Yala Dev**. Lanzar con `XCUIApplication().launchForUITest(...)` (helper en `YalaUITests/Support/`).
- Launch args (`#if DEBUG`, `UITestHooks`): `-uitest` (modo + store local sin CloudKit), `-uitest-reset`, `-uitest-skip-onboarding`, `-uitest-pro`, `-uitest-seed <minimal|realista|pesado>`.
- **Seed `minimal` por default** (rápido); `realista`/`pesado` solo si el test necesita volumen (arranque más lento, riesgo watchdog).
- Esperar **`waitForUITestReady()`** (señal `uitest_ready`) antes de interactuar — NUNCA `sleep`.
- Targetear por `accessibilityIdentifier` (`feature_element` / `feature_row_<claveEstable>`), NUNCA texto localizado ni coordenadas.
- Al cubrir un área `deterministic`: poner `coverage: "xcuitest:<File#test>"` en `qa/coverage-index.json` y bajar `_meta.backlogBaseline`.

### Entorno del simulador (antes de culpar a un test)
- **El device DEBE casar con el runtime del SDK contra el que se compila.** Hoy se compila contra `iPhoneSimulator27.0` ⇒ hace falta un device de **iOS 27.0**. Si no existe ninguno, `xcodebuild` no da un error de test: muere con **exit 70** y **cero casos ejecutados** (`Unable to find a device matching the provided destination specifier`). Corolario al liberar disco: **borrar simuladores eligiendo por RUNTIME, nunca por «cuál está arrancado»** — así se perdieron los `iPhone 17 Pro` de 27.0 conservando uno de 26.4, y todas las corridas murieron sin ejecutar nada. Y cuando hay dos devices con el mismo nombre en runtimes distintos (`iPhone 17 Pro` existe hoy en 26.4 **y** en 27.0), `-destination 'platform=iOS Simulator,name=iPhone 17 Pro'` es ambiguo → usar **`-destination 'platform=iOS Simulator,id=<udid>'`**.
- **NO apagar el simulador entre corridas.** `xcrun simctl shutdown all` y relanzar de inmediato deja a CoreSimulator sin poder lanzar la app: `FBSOpenApplicationServiceErrorDomain Code=1 "Simulator device failed to launch"` / `RequestDenied (SBMainWorkspace)`, y la corrida muere sin ejecutar un solo caso. **Arrancar el device UNA vez (`simctl boot`) y apilar las corridas encima.**
- **Clasificar la corrida por su exit code ANTES de leer el output**: **65** = fallo de test (hay algo que arreglar en el código o en la aserción) · **70**, o **cero líneas `Test Case`**, = fallo de **INFRAESTRUCTURA** (destino inexistente, runner que no lanza, sim caído) — no hay resultado que interpretar y el test no es sospechoso. Un `grep -E "passed|failed"` sobre el log cuenta un fallo de lanzamiento como fallo de test: el 2026-07-28 eso produjo **dos diagnósticos falsos** (4 corridas muertas al lanzar contadas como el test en rojo). Antes de tocar un test, confirmar que la corrida ejecutó casos.
