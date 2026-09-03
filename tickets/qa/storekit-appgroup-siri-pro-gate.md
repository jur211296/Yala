---
id: storekit-appgroup-siri-pro-gate
status: qa
priority: high
area: "subscription, intents, app-group"
created: 2026-07-17
updated: 2026-09-02
source: YalaWiki/Bugs/qa_storekit-appgroup-siri-pro-gate.md
---


# StoreKitManager escribía `isProUser` a un App Group no-entitled — gate Pro de SiriNatural roto

> [!todo] IMPLEMENTADO (2026-07-17, commit `944f53c9`) — **pasos 1 y 2 de la QA son corribles en simulador**; solo la ruta por voz necesita device

## Lo que le pasaba al usuario

Un usuario que **había pagado Pro** invocaba el atajo de Siri para apuntar un gasto hablando, y la
app le contestaba que esa función necesita Pro. No era un caso raro: le pasaba a **todo** usuario Pro,
en todas las invocaciones, desde abril de 2026. La suscripción funcionaba con normalidad dentro de la
app; lo único roto era el atajo.

## El bug (evidencia técnica)

`StoreKitManager.syncToAppGroup()` escribía el flag `isProUser` al suite hardcodeado
`"group.com.yala.shared"`, que **no está en los entitlements** (el canónico es
`group.com.jurgenschmidt.yala[.dev]`). Un suite no-entitled NO devuelve `nil` en
`UserDefaults(suiteName:)` — crea un plist **local al sandbox** que ningún otro lector ve, por eso el
guard con su print de fallo jamás saltó.

El único lector cross-proceso de esa key es el **gate Pro de SiriNatural**, en `perform()` de
`SiriNaturalEntryIntent` (`Yala/App/Intents/QuickExpenseIntent.swift`): la lectura del App Group está
en la **línea 207** y el `return` con el diálogo `proRequired` en la **209** (medido contra el árbol de
hoy, HEAD `553b91c9`; la coordenada `:220` que traía este ticket cae dentro del bloque de comentarios
del guard de cuenta, líneas 219-222). Lee del canónico vía `WidgetURLHelper.appGroupIdentifier`
→ `?? false` siempre → **todo usuario Pro que invoca SiriNatural recibía `pro_required`**. Los widgets
no leen la key (el doc-comment "for widgets" era stale).

## Historia (git)

- `655c912a` (2026-02-05): StoreKitManager nace con el suite hardcodeado.
- `7700b2df`: el intent SiriNatural nace leyendo **el mismo** suite hardcodeado → funcionaba (mismo proceso, mismo plist local).
- `b1e724a0` (flow review, item G14-SV-02): corrige el **lector** al canónico… pero nadie tocó el escritor. **Roto desde entonces (~abril 2026).**

Señal en telemetría: `intentFailed` con `error: "pro_required"` de usuarios que sí son Pro. Ese evento
ya no existe — ver el paso 3 tachado más abajo.

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

## Por qué esto no se puede aparcar: el arreglo nunca ha salido

**Medido hoy:** `git tag --contains 944f53c9` no devuelve **ningún** tag. El tag más reciente alcanzable
desde el commit del fix es `v1.2.7` (`git describe` → `v1.2.7-1090-g944f53c9`), de 2026-04-21, o sea
**anterior al propio bug que arregla**. Los tags de la serie 2.0.x (`v2.0.2`/`v2.0.3`/`v2.0.4`) viven en
una línea que no contiene el fix y que tampoco es ancestro de `HEAD`.

Consecuencia para el usuario: **cualquiera que hoy tenga instalada una versión publicada de Yala y sea
Pro sigue viendo «necesitas Pro» al usar el atajo de Siri.** El arreglo existe en el repo desde julio y
no ha llegado a nadie. No es un ticket de verificación cosmética: es un fallo vivo en manos de los
usuarios, esperando el siguiente release.

*(No he medido si salió alguna build de TestFlight sin tag. Lo medido es que ningún tag lo contiene.)*

## Un camino con el mismo síntoma que el fix NO cubre

**Usuario Pro que reinstala la app y usa el atajo antes de abrirla ni una vez** → vuelve a ver
«necesitas Pro».

Verificado leyendo quién escribe la key y cuándo:

- El **único** escritor del flag en el App Group es `StoreKitManager.syncToAppGroup()`
  (`Yala/App/Services/StoreKitManager.swift`, el `set` en la línea 405). Medido: en todo `Yala/` no hay
  otro `set` sobre `AppPreferences.Keys.isProUser` en ese suite.
- Todos sus llamadores están dentro del propio `StoreKitManager` y los dispara la app: el cold launch /
  foreground resume vía `AppBootstrapper.refreshSubscriptionStatus()` (llama a
  `store.updateSubscriptionStatus()`), la compra, el restore y los toggles de dev.
- `QuickExpenseIntent.swift` **no contiene ni una referencia** a `StoreKitManager`,
  `FeatureGateService`, `updateSubscriptionStatus` ni `AppBootstrapper` (medido: grep en cero). El
  intent solo **lee**, y con `?? false`.

Es decir: el flag es una caché que únicamente rellena el arranque de la app. Tras una reinstalación el
contenedor del App Group llega vacío (esto último lo **infiero** del comportamiento de iOS al
desinstalar, no es medible en este repo), así que hasta el primer arranque la key no existe y la
lectura cae al `?? false` — mismo diálogo, misma frustración, causa distinta.

No hace falta arreglarlo dentro de esta QA, pero sí anotarlo: si en el paso 1 se prueba sobre una
instalación limpia sin haber abierto la app, el gate fallará y **no será una regresión del fix**.

## QA

Pasos 1 y 2 se drenan en el **simulador**, sin device. Comprobado en esta Mac: el único runtime
instalado es **iOS 26.5 (23F77)** y su `RuntimeRoot` trae `Shortcuts.app`, `ShortcutsUI.app`,
`ShortcutsViewService.app` y `Siri.app`, así que el atajo se puede lanzar a mano desde Atajos. El
toggle **«Simular Pro»** existe en el Perfil de Yala Dev (`ProfileView.swift`, `devProToggleRow`, bajo
`#if DEBUG`) y llama a `StoreKitManager.toggleDevProTier()`, que a su vez hace `syncToAppGroup()` — o
sea, el toggle sí propaga el flag al App Group que lee el intent, que es justo lo que el paso 1 mide.
El **device solo hace falta para la ruta por voz** (hablarle a Siri de verdad).

1. Yala Dev con «Simular Pro» ON → lanzar el atajo SiriNatural con texto desde Atajos → **debe pasar el
   gate** y encolar el draft (antes: diálogo Pro requerido incluso en Dev).
2. Usuario Free → mismo atajo → sigue recibiendo el diálogo Pro (sin regresión del gate).
3. ~~Post-release: el rate de `intentFailed`/`pro_required` en TelemetryDeck debe caer.~~
   **INEJECUTABLE — no lo intentes.** TelemetryDeck se purgó entero el 2026-07-17 (`d460480b`) y el
   evento `intentFailed` no existe: medido hoy, **cero ocurrencias** en todo el árbol de código
   (`*.swift`, `*.plist`, `*.entitlements`, `*.pbxproj`, `*.json`) — solo sobrevive citado en tickets.
   El dashboard que pide este paso ya no existe.

   **Consecuencia, y es la parte que importa:** este bug lo detectó esa señal. Hoy el gate Pro sigue en
   el mismo sitio y **no emite nada** — en toda la carpeta `Yala/App/Intents/` no hay una sola
   referencia a `MetricsService` (medido). Una regresión idéntica sería **invisible hasta que la
   reporte un usuario**, y ese usuario ya habría pagado por algo que no le funciona. El sustituto no es
   otro panel: es el test de regresión que ya dejó el fix (`YalaTests/StoreKitManagerAppGroupTests.swift`,
   con su guard anti-drift). Reponer la señal o ratificar el test como la red que queda se decide en
   → `tickets/backlog/canarios-y-breadcrumbs-sin-emisor.md`.

migrated from YalaWiki Bugs/qa_storekit-appgroup-siri-pro-gate.md @ 1934e8ad
