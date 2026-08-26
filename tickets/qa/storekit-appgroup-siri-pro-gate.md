---
id: storekit-appgroup-siri-pro-gate
status: qa
priority: high
area: "subscription, intents, app-group"
created: 2026-07-17
updated: 2026-08-26
source: YalaWiki/Bugs/qa_storekit-appgroup-siri-pro-gate.md
---


# StoreKitManager escribía `isProUser` a un App Group no-entitled — gate Pro de SiriNatural roto

> [!done] IMPLEMENTADO (2026-07-17, commit `944f53c9`) — pendiente QA device (SiriNatural con Pro real)

## El bug

`StoreKitManager.syncToAppGroup()` escribía el flag `isProUser` al suite hardcodeado `"group.com.yala.shared"`, que **no está en los entitlements** (el canónico es `group.com.jurgenschmidt.yala[.dev]`). Un suite no-entitled NO devuelve `nil` en `UserDefaults(suiteName:)` — crea un plist **local al sandbox** que ningún otro lector ve, por eso el guard con su print de fallo jamás saltó.

El único lector cross-proceso de esa key es el **gate Pro de SiriNatural** (`QuickExpenseIntent.swift:220`), que lee del canónico vía `WidgetURLHelper.appGroupIdentifier` → `?? false` siempre → **todo usuario Pro que invoca SiriNatural recibía `pro_required`**. Los widgets no leen la key (el doc-comment "for widgets" era stale).

## Historia (git)

- `655c912a` (2026-02-05): StoreKitManager nace con el suite hardcodeado.
- `7700b2df`: el intent SiriNatural nace leyendo **el mismo** suite hardcodeado → funcionaba (mismo proceso, mismo plist local).
- `b1e724a0` (flow review, item G14-SV-02): corrige el **lector** al canónico… pero nadie tocó el escritor. **Roto desde entonces (~abril 2026).**

Señal en telemetría: `intentFailed` con `error: "pro_required"` de usuarios que sí son Pro.

## Implementación

### 2026-07-17 — `944f53c9` (branch 2.0.5)

**Archivos modificados:**
- `Yala/App/Services/StoreKitManager.swift` — `appGroupID` pasa del literal a `SharedContainerService.appGroupIdentifier`; la key del write usa `AppPreferences.Keys.isProUser` (el mismo par suite/key que lee el intent).
- `YalaTests/StoreKitManagerAppGroupTests.swift` — NUEVO, 2 tests: (1) `syncToAppGroup` aterriza en el par (suite, key) que lee el intent; (2) guard anti-drift `SharedContainerService.appGroupIdentifier == WidgetURLHelper.appGroupIdentifier`.
- `qa/coverage-index.json` — área `app-intents-shortcuts-siri`: suite nueva en coverage + `lastVerified` 2026-07-17.

**Decisiones técnicas:**
- Sin migración de valores: el suite viejo solo contenía un flag que nadie leyó desde `b1e724a0`, y `updateSubscriptionStatus()` re-escribe el flag fresco en cada cold launch / foreground resume (`AppBootstrapper.refreshSubscriptionStatus`). El plist huérfano queda como basura inofensiva.
- El test de regresión se validó **en ambos sentidos**: contra el código pre-fix (stash temporal) falla exactamente el test del write; con el fix, 2/2 verdes.

**Gates:** build Yala 0 warnings en el cambio · 58 tests previos (ProUpsell/FeatureGate/AppBootstrapper/DataWipe) + 2 nuevos verdes · validate-coverage OK.

## QA device pendiente

1. Yala Dev con "Simular Pro" ON (o TestFlight con Pro real) → invocar el atajo SiriNatural con texto → **debe pasar el gate** y encolar el draft (antes: diálogo Pro requerido incluso en Dev).
2. Usuario Free → mismo atajo → sigue recibiendo el diálogo Pro (sin regresión del gate).
3. Post-release: el rate de `intentFailed`/`pro_required` en TelemetryDeck debe caer.

migrated from YalaWiki Bugs/qa_storekit-appgroup-siri-pro-gate.md @ 1934e8ad
