---
id: update-banner-appstore-criteria
status: qa
created: 2026-07-22
updated: 2026-08-26
source: YalaWiki/Bugs/ux_update-banner-appstore-criterios-y-forzado.md
---


# Banner "Actualización disponible" del Panel — criterios actuales, gaps de UX y ausencia de forzado

## Cómo funciona HOY (diagnóstico completo)

**Piezas:**
- Servicio: `Yala/App/Services/AppUpdateService.swift` (1-161)
- Banner: `Yala/App/Views/Shared/UpdateAvailableBanner.swift` (1-84)
- Inserción en Panel: `Yala/App/Views/Panel/PanelView.swift:373-381` (sin gating por Pro/segmento)
- Disparador: `ContentView.swift:1029` dentro de `runReturningUserPostChecks` (1016-1033)
- L10n: `L10n.swift:6238-6245` (`enum AppUpdate`), keys en los 16 locales

**Criterios:** iTunes Lookup API (`itunes.apple.com/lookup?bundleId=…&country=us`, `AppUpdateService.swift:70`) → compara `CFBundleShortVersionString` local vs `version` remota con `compareVersions` (148-160, split por `.` + `Int()`). Muestra si `current < latest` y no fue descartado en sesión (`shouldShowBanner`, 38-40).

**Frecuencia:** chequeo de red 1 vez por cold launch (solo returning users), cooldown 24h (`cacheDuration`, línea 46; cache en `UserDefaults.standard`: `appUpdate.latestVersion`/`appUpdate.lastChecked`). **NO re-chequea al volver a foreground.**

**Descarte:** botón X → `dismissedInSession` **solo en memoria** (línea 36) ⇒ reaparece en CADA cold launch mientras haya update.

**Tap "Actualizar":** abre la ficha `https://apps.apple.com/app/id<trackId>` (línea 103). No fuerza nada.

**Forzado de actualización: NO EXISTE.** Ni pantalla bloqueante, ni versión mínima, ni gating de features por versión de cliente.

## Gaps / bugs encontrados

1. **Dismiss no persistente** — reaparece cada arranque en frío hasta que el usuario actualiza. Molesto; contrasta con `lastSeenAppVersion` de What's New que sí persiste. Falta un "no volver a mostrar para la versión X" (o al menos cooldown de días).
2. **Sin re-chequeo en foreground** — usuario que no mata la app en días no ve el banner (el gancho `scenePhase == .active` de `ContentView:536-560` no llama a `checkForUpdate`).
3. **`country=us` hardcodeado** (línea 70) — el lookup consulta el catálogo de EE.UU.; propagación regional desfasada puede dar resultado incorrecto. Debería usar el storefront del device.
4. **Comparador de versiones frágil** (148-160) — `compactMap { Int($0) }` descarta componentes no numéricos en silencio (`1.2.0-beta` → `[1,2]`). Funciona con el esquema actual, pero es bomba latente y **sin ningún unit test** (`UserDefaults.standard` cableado no-inyectable).
5. **Fail-open** — si `CFBundleShortVersionString` faltara, default `"0.0.0"` (línea 142) ⇒ banner siempre visible.
6. **Cero observabilidad en release** — errores solo en `print` bajo `#if DEBUG` (81-88, 106-110); en TestFlight/prod los fallos son invisibles. Contrasta con el patrón `RemoteConfigBreadcrumb` (os.Logger sin PII fuera de DEBUG).
7. **Gate temporal, no por éxito** — si el primer intento falla sin red, no reintenta hasta pasadas 24h aunque vuelva la conectividad.
8. String huérfano: `appUpdate.dismissButton` localizada ×16 pero sin uso (el X usa `L10n.Action.close`).

**Lo que está bien:** DS tokens correctos (glassEffect, DS.Spacing/Typography), l10n completa ×16 con placeholder consistente, `@MainActor @Observable` singleton alineado al resto.

## Decisión de producto pendiente (owner)

**¿Forzar actualización para versiones críticas?** El camino sólido NO es iTunes: es extender el **`GET /config` del yala-gateway** (infra ya existente: `gateway/src/config.ts` + `RemoteConfigClient` en `CloudRemoteConfig.swift:198-258`, wire tolerante a campos nuevos) con un campo `minSupportedVersion`/`forceUpdateBelow` → pantalla bloqueante client-side. Precedente conceptual: el schema-gate del sync (`gateway/src/sync/schemaGate.ts`) ya rechaza clientes viejos por `min_version`.

**Caveat clave:** en producción el fetch de `/config` hoy NO corre (`CloudBackendConfig.isConfigured == false` ⇒ `CloudRemoteConfig.swift:18-20, 222`) — habría que activar esa vía en prod (encadenado a D9/encendido del Modo Nube, donde `/config` ya quedará vivo). Cache client-side 5 min + min-interval 6h: un forzado tardaría hasta ~6h en llegar a todos, aceptable para "versión crítica".

## Alcance propuesto del fix (por tramos, decidir cuáles)

- **Tramo UX (barato):** persistir dismiss por versión + re-chequeo en foreground + cooldown de re-aparición.
- **Tramo robustez:** storefront del device, comparador testeado (extraer puro + inyectar defaults), breadcrumb en release.
- **Tramo forzado (feature nueva):** campo en `/config` + pantalla bloqueante. Requiere decisión de producto y espera natural al encendido de `/config` en prod.

## Resolución (2026-07-23, commit `e172d4bd`, branch `2.0.5`)

Método: Fase 1 (confirmación del diagnóstico vía workflow de 5 lectores + decisión owner por AskUserQuestion sobre los 3 tramos + Plan Mode + /review-plan [NECESITA AJUSTES, ajustes aplicados]) → Fase 2 (implementación Opus, validada en **worktree aislado** por sesión paralela editando el mismo working dir).

**Decisiones owner (AskUserQuestion):**
- Tramo forzado: **diseñar COMPLETO pero DARK** (sin deploy del gateway, sin encender el fetch de `/config` en prod).
- Dismiss del banner: **mantener solo-sesión** → el gap #1 (persistencia por versión) queda FUERA a propósito.
- Umbral del forzado: **número de build** (`CFBundleVersion` / `MIN_SUPPORTED_BUILD`).

**Tramo UX** (gap #2): re-chequeo en foreground (`ContentView` `.active`, gateado por `hasCompletedOnboarding`; barato por el cache de 24h). Cierra también la parte within-session del gap #7.

**Tramo robustez** (gaps #3-#6): lógica pura `AppUpdateDecisionLogic` (comparación/cache/URL) testeable; storefront del device vía `Locale.current.region.lowercased()` (gap #3, ya no `country=us`); `defaults`/`session`/`now` inyectables en `AppUpdateService` (gap #4); **fail-closed** cuando la versión instalada es desconocida (gap #5); breadcrumb `AppUpdateBreadcrumb` en release (`os.Logger com.yala/AppUpdate`, sin PII, gap #6). Extra: `trackId` persistido (`appUpdate.trackId`) para rehidratar `appStoreURL` en cold-launch-desde-cache (arregla bug latente del botón del banner) + añadido a `DataWipeService`.

**Tramo forzado (DARK)**: campo `forceUpdate.minSupportedBuild` en `GET /config` del gateway (`config.ts`/`env.ts`/`wrangler.toml`=`0` en staging Y prod, **sin deploy**) → `RemoteFlagsSnapshot.minSupportedBuild` (`CloudRemoteConfig`) → `ForceUpdateDecisionLogic` (fail-open) → `ForceUpdateGate` (`@Observable`, recompute boot/foreground) → `ForceUpdateView` (cover terminal sin dismiss, `.yalaScreenBackground(.panel)`) presentado por `ForceUpdateNetModifier` (molde `SignOutRelaunchNetModifier`, re-presenta si UIKit lo tumba) + blocker `forceUpdate` de **MÁXIMA severidad** en `ContentViewReadinessLogic`. **Inerte en prod** (el fetch de `/config` no corre: `CloudBackendConfig.isConfigured==false`). Seam DEBUG `-uitest-force-required`.

**Gates (validados en worktree aislado de los tests rotos de la sesión paralela):** build Yala Dev + Yala (Release) 0 errores/0 warnings nuevos · **103 tests / 10 suites** (mis 6 suites nuevas + `CloudRemoteConfigTests`/`ContentViewReadinessLogicTests`/`DataWipeServiceTests` ampliados + `LocalizationParityTests`/`StringsdictParityTests`/`BundleLocaleDriftTests`) · gateway `config.test.ts` 9/9 + typecheck · **2 mutantes verificados** (fail-closed removido + `<=min` = rojos) · `validate-coverage` OK · **QA visual sim VERDE** (cover de forzado terminal + banner normal renderizan correctos). l10n ×16 (`appUpdate.force.*`, voseo es-AR, traducción nativa por workflow).

**Coordinación:** el working dir estaba co-editado por otra sesión (Hero/grupos/l10n/`.ckdb`, la de los tests `HeroBucketsCalculatorTests`/`HeroMessageCacheTests` rotos mid-edit). Mis archivos son disjuntos; la validación corrió en un worktree desde HEAD; el commit stageó **solo mis hunks** (Swift/gateway directos; `.strings` vía patch del worktree; `coverage-index` hunk separable) — cero contaminación cruzada, cambios ajenos intactos.

## Diferidos / pendiente owner

- **Deploy del gateway + encender el fetch de `/config` en prod** (encadenado a D9 del Modo Nube). Hasta entonces el forzado es DARK (inerte).
- **App Store ID numérico hardcodeado** como fallback del botón de la pantalla de forzado (hoy usa `appStoreURL`+re-lookup; **necesario ANTES de encender el forzado** para que el botón funcione sin red). No está en el repo.
- **device-QA** del cover de forzado (el sim lo cubre por seam; el flujo real con `/config` vivo requiere device).
- **Retiro del huérfano `appUpdate.dismissButton`** (gap #8, D2): diferido para no clobbear los 16 `.strings` co-editados por la sesión paralela; benigno (el X usa `Action.close`).
- Umbral por `MARKETING_VERSION` (descartado a favor del build number) y soft-nudge / segundo umbral: fuera de scope.

migrated from YalaWiki Bugs/ux_update-banner-appstore-criterios-y-forzado.md @ 1934e8ad
