---
id: applepay-shortcut-warm-launch-empty-data
status: qa
area: "intents, apple-pay, app-lifecycle, groups-bridge"
created: 2026-07-01
updated: 2026-08-26
source: YalaWiki/Bugs/ok_applepay-shortcut-ios27-warm-launch-datos-vacios.md
---


> [!success] Resolución (2026-07-02) — commit `db397ce7`
> **La premisa "regresión de iOS 27" quedó DESCARTADA por investigación con fuentes primarias de Apple.** No es iOS 27: `openAppWhenRun` se deprecó en iOS **26.0** (no 27); `IntentExecutionTargets` (nuevo en 27) es inerte sin App Intents extension (los intents de Yala viven en el target de la app). La **causa raíz** es el patrón documentado de **dos `NSPersistentCloudKitContainer` `.private` sobre el mismo store** (TN3163/TN3164, Apple DTS lo confirmó como bug; radar FB13278891; conocido desde 2023). El "todo en 0" específico del warm launch es el **conflicto in-process (error CloudKit 134410)** entre el 2º container `.private` del intent y el de la app viva. Ver `## Implementación` abajo. Detalle del research en el plan `~/.claude/plans/reflective-sprouting-gray.md`.

> [!warning] Actualización (2026-07-04) — `db397ce7` NO bastó; cura de raíz aplicada
> El fix del 2-jul (config `.none` para el container del intent) calmó el error 134410 pero **no eliminó la 2ª conexión al store**: en TestFlight reapareció con otra cara — warm launch = solo Panel poblado (bandeja/registros vacíos), cold launch = todo en 0, recuperable cerrando y reabriendo (los datos NUNCA se pierden; era un problema de *lectura*, no de borrado). Diagnóstico confirmado en device con el owner (el intent notifica y guarda bien; el draft aparece tras un 2º cold launch). **Cura de raíz (2026-07-04):** el intent **deja de tocar SwiftData** — encola el pago crudo en App Group y la app crea el `InboxDraft` al abrir (gateado por quiescencia). Sin 2ª conexión → sin ventana de reconciliación. Ver `## Implementación → 2026-07-04` abajo.

# Bug: Automatización Apple Pay deja la app en un estado "vacío" (bandeja + todos los datos en 0) hasta forzar cierre + cold launch — ~~regresión aparente de iOS 27~~ (DESCARTADO: patrón dual-container, ver Resolución)

## Descripcion

Al pagar con Apple Pay, el Shortcut/Automatización de Wallet ("Apple Pay") se ejecuta correctamente: llega la notificación local de éxito ("Registraste un gasto..."), y el `InboxDraft` se guarda en SwiftData (confirmado por código — ver más abajo, y porque el draft SÍ aparece tras el cold launch posterior).

El problema aparece cuando el usuario, **sin haber matado el proceso**, abre la app tocando el ícono poco después de que la automatización corrió. En ese momento:

- La bandeja (Inbox) aparece **vacía** — no muestra el draft de Apple Pay que sí se guardó, y potencialmente tampoco muestra drafts previos que ya existían.
- **Todos los datos de la app aparecen en 0 o "borrados"** — el reporte del owner sugiere que esto no es solo el Inbox: el Panel/saldos también se ven afectados.
- **Requiere forzar el cierre completo de la app (swipe-up en el App Switcher) y volver a abrirla desde cero (cold launch)** para que todo vuelva a la normalidad — en ese momento sí aparece la transacción de Apple Pay en la bandeja con normalidad, y el resto de los datos vuelve a verse bien.

Debería pasar: al abrir la app tras la automatización, el usuario debería ver sus datos normales (sin necesidad de cold launch) y, en el peor caso, el draft de Apple Pay simplemente podría no estar reflejado aún — pero **nunca** debería verse "todo en 0".

El owner cree que esto es una regresión nueva de **iOS 27** — antes (con el mismo código de `ApplePayTransactionIntent`, que no ha cambiado desde el fix de `5ce1e43f` del 2026-06-08) el flujo funcionaba sin este síntoma.

**Nota de alcance**: este NO es el bug ya cerrado de "No se pudo ejecutar el atajo" (commits `53a8dda3` + `5ce1e43f`, 2026-06-08) — ese bug era sobre el *feedback del Shortcut* con pantalla bloqueada (iOS reportaba fallo pese a que el draft se guardaba). Ese fix (quitar `ProvidesDialog`/`ShowsSnippetView`, feedback 100% por notificación) sigue vigente y el código no cambió. Este bug es sobre qué ve el usuario **dentro de la app** al abrirla después, y es nuevo con iOS 27 según el reporte.

## Pasos para Reproducir

1. Configurar la automatización de Wallet "Apple Pay" con `ApplePayTransactionIntent` (Yala/App/Intents/QuickExpenseIntent.swift:78-349), como ya está documentado en QA-SCENARIOS.md Sección 23.
2. Pagar con Apple Pay (activa la automatización). Con pantalla bloqueada o no — el reporte no lo especifica, pero por el fix previo (`5ce1e43f`) sabemos que corre con pantalla bloqueada sin traer UI a foreground (`openAppWhenRun = false`).
3. Confirmar que llega la notificación local de éxito.
4. **Sin matar el proceso de la app** (no swipe-up en App Switcher), tocar el ícono de Yala para abrirla.
5. Observar: Inbox vacío, datos en 0/borrados.
6. Forzar cierre completo (swipe-up) y volver a abrir (cold launch).
7. Observar: todo normal, incluyendo la transacción de Apple Pay en la bandeja.

## Contexto

- **Dispositivo**: iPhone físico (Apple Pay requiere device real, no se puede reproducir en Simulador — Apple Pay no funciona en Simulator).
- **iOS**: 27.
- **Build**: 32 (2.0.1).
- **Frecuencia**: siempre, según el reporte del owner. Aparenta ser una regresión nueva de iOS 27 (mismo código, comportamiento distinto).

## Investigación de código (evidencia real, archivo:línea)

### 1. `ApplePayTransactionIntent` — qué hace y cómo obtiene su `ModelContainer`

Archivo: `Yala/App/Intents/QuickExpenseIntent.swift:78-349`.

- **`static var openAppWhenRun: Bool = false`** (línea 83). Confirma la hipótesis de CLAUDE.md: es el único de los 5 intents del archivo con esta config en un contexto de automatización real (background); `SiriNaturalEntryIntent` también es `false` (línea 358) pero se invoca manualmente por Siri en foreground/desbloqueado.
- **`openAppWhenRun` está DEPRECATED en iOS 27** (confirmado vía Apple docs, `developer.apple.com/documentation/appintents/appintent/openappwhenrun`): *"Deprecated — Please provide 'supportedModes' instead"*. Apple explica que `openAppWhenRun = true` es el equivalente legacy retrocompatible de `supportedModes = .foreground(...)`; por simetría, `openAppWhenRun = false` es el equivalente legacy de `supportedModes = .background` (*"Specify background to run the action entirely in the background"*). Yala sigue usando la API vieja — sigue compilando y funcionando (la superficie deprecada se mantiene por compat), pero **el comportamiento subyacente en runtime ahora pasa por el nuevo modelo `IntentModes`/`IntentExecutionTargets` internamente**, introducido con iOS/iPadOS 26 y **extendido con `IntentExecutionTargets` explícitamente en iOS/iPadOS 27** (ambos confirmados vía Apple docs — ver sección "Hipótesis iOS 27" abajo).
- **`perform()` (líneas 114-248) NO usa el `ModelContainer`/`ModelContext` de la app principal.** Crea su **propio** `ModelContainer` (líneas 124-129):
  ```swift
  container = try ModelContainer(
      for: SwiftDataConfiguration.personalSchema,
      configurations: SwiftDataConfiguration.personalConfiguration
  )
  ```
  Esto es idéntico al patrón de `SiriNaturalEntryIntent` (líneas 392-395) — **todos los intents de este archivo crean su propio container**, nunca reciben el de `YalaApp.sharedModelContainer`. Usa `context.save()` (línea 222) sobre ese container propio para persistir el `InboxDraft`.
- **CRÍTICO: `SwiftDataConfiguration.personalConfiguration` (Yala/Utils/SwiftDataConfiguration.swift:188-210) usa el MISMO `databaseName`** que la app principal usa para construir `sharedModelContainer` (comentario explícito en el código, línea 187: *"Personal data — CloudKit synced (**same databaseName = same SQLite file**)"*). Es decir: el Intent y la app abren **dos `ModelContainer`/`NSPersistentCloudKitContainer` DISTINTOS apuntando al MISMO archivo SQLite en disco**, ambos con `cloudKitDatabase: .private(cloudKitContainerIdentifier)` (línea 206) — cada uno con su propio `NSPersistentStoreCoordinator` y su propio mirror de CloudKit.
- El Intent **NO incrementa `SessionState.shared.dataVersion`** ni dispara ninguna notificación custom de Yala al terminar. Su único efecto observable para el resto de la app es: (a) el `context.save()` local sobre el store físico compartido, y (b) el efecto indirecto de ese `save()` sobre CloudKit (export async posterior) y sobre cualquier otro coordinator que esté escuchando el mismo store en disco.

### 2. Punto de entrada de la app — `YalaApp.swift` y el bootstrap

Archivo: `Yala/App/YalaApp.swift`.

- `sharedModelContainer` (líneas 52-64) es un `ModelContainer` **separado** del que construye el Intent, aunque apunte al mismo store físico. Se construye una sola vez en el `init` lazy de la propiedad, en el momento en que el sistema instancia `YalaApp` (que ocurre siempre que el proceso arranca, ya sea por tap del ícono O por un App Intent en background).
- El bootstrap real de la app (`AppBootstrapper.bootstrap(container:)`, Yala/App/AppBootstrapper.swift:79) se dispara **solo** desde `.task { await bootstrapper.bootstrap(container: sharedModelContainer) }` dentro del `WindowGroup { ContentView() }` (YalaApp.swift:89-102). **Este `.task` vive en el `WindowGroup`/`Scene`, no en el `init()` de `YalaApp` ni en `AppDelegate.didFinishLaunchingWithOptions`.**
- **`AppBootstrapper.bootstrap(container:)` tiene el guard de "una sola vez" que pregunta la hipótesis del usuario**: `Yala/App/AppBootstrapper.swift:80`:
  ```swift
  func bootstrap(container: ModelContainer) async {
      guard !isInitialized else { return }
      ...
      isInitialized = true   // línea 335
  }
  ```
  `AppBootstrapper.shared` es un singleton `@MainActor final class` (línea 19-23). `isInitialized` (línea 49) es `private(set)`, en memoria, sin persistencia — solo se resetea si el **proceso** muere.
- **Confirmado por código: el bootstrap completo (`AppBootstrapper.bootstrap`) NUNCA corre durante la ejecución de `ApplePayTransactionIntent.perform()`.** El Intent es una `struct` standalone que no referencia `AppBootstrapper`, `ContentView`, ni `sharedModelContainer` — construye todo lo que necesita desde cero (su propio `ModelContainer`) y no pasa por el `WindowGroup`. Esto significa que **si el sistema lanza el proceso de la app para correr el Intent, el `WindowGroup`/`Scene` no necesariamente se activa**, y por lo tanto el `.task` de bootstrap no se dispara — deja a `AppBootstrapper.isInitialized == false` en ese momento.
- **`YalaAppDelegate.application(_:didFinishLaunchingWithOptions:)` (Yala/App/YalaAppDelegate.swift:15-23) solo registra APNs** (`application.registerForRemoteNotifications()`) — no tiene ninguna lógica de refresh de datos ni de bootstrap. No aporta ninguna señal adicional sobre si la Scene se creó o no.

**Confirmado**: existe el guard de "una sola vez" que la hipótesis #3 preguntaba, y confirmado que el código del Intent no lo dispara. **No confirmado con 100% de certeza** (no hay forma de verificarlo solo con lectura de código — requiere device QA con logs) si, cuando el usuario abre la app después, el sistema:
- (a) reutiliza el proceso ya-vivo del Intent y crea la `Scene`/`WindowGroup` por primera vez en ese proceso (en cuyo caso el `.task` de bootstrap SÍ correría normalmente, esta vez sí, al montar `ContentView` por primera vez — y el guard `isInitialized` sería irrelevante porque sería la primera invocación real), o
- (b) el sistema mata el proceso del Intent al terminar y lanza uno nuevo al abrir la app (cold launch real, sin el síntoma reportado), o
- (c) alguna variante intermedia donde la Scene se "reconecta" a un estado parcialmente inicializado.

El hallazgo más importante de esta investigación es que **(a) es plausible y coherente con toda la evidencia recolectada** — ver "Hipótesis iOS 27" abajo.

### 3. Guards de "solo una vez" en `AppBootstrapper.swift`

Buscados y encontrados, además de `isInitialized`:
- `hasSeenInitialActive` (línea 823) — gatea telemetría de warm-resume (`.appResumed`), no afecta refresh de datos.
- `remoteChangeLeadingFired` (línea 57) — debounce de `.NSPersistentStoreRemoteChange` (ver sección 6 abajo, es relevante).
- Ningún guard de "una sola vez" bloquea o condiciona el refresh de UI de forma que explique directamente el síntoma — pero **la AUSENCIA de un guard que SÍ debería recargar en este escenario es la causa más probable** (ver sección 4-5).

### 4. Cómo leen datos los ViewModels — Inbox, Panel, ContentView

Este es el hallazgo central. **La arquitectura de refresh de UI en Yala NO usa `@Query`** (confirmado en múltiples sitios — comentarios explícitos en el código lo dicen), sino ViewModels `@Observable` con `loadData()` explícito, disparado por triggers puntuales:

**`ContentView.swift`** (Yala/App/ContentView.swift):
- `hasExistingData: @State private var hasExistingData: Bool = false` (línea 73) — controla si se considera que el usuario tiene datos. Comentario explícito (línea 71-72): *"Lightweight state for existing data detection (replaces @Query to prevent synchronous SwiftData fetches during iOS snapshot capture — 0x8BADF00D fix)"*.
- Solo se recalcula en 3 sitios: `.task { checkInitialSyncState() }` (línea 143-145, corre UNA VEZ por instancia de View), `.onChange(of: SessionState.shared.dataVersion)` (línea 149-155), y dentro de `checkInitialSyncState()` mismo (línea 821).
- **`.onChange(of: scenePhase)` (líneas 451-468) — el handler que corre en cada `.active` — NO llama a `checkHasExistingData()`, NO llama a `checkInitialSyncState()`, NO incrementa `dataVersion`.** Solo hace: lock biométrico (`authService.appDidEnterForeground()`), recalcular segmento de usuario, y re-emitir invites de grupo pendientes. **No hay ningún mecanismo que refresque `hasExistingData` o el estado general de la UI al volver a foreground.**
- `MainTabView()` solo se monta si `hasCompletedOnboarding && isInitialCheckDone` (línea 94) — si por algún motivo `isInitialCheckDone` fuera `false` en el momento en que `ContentView` se vuelve a evaluar (ej. si la Scene se re-crea desde cero con `@State` en sus valores default), se vería el fondo vacío (`theme.background.ignoresSafeArea()`, línea 101-102) en vez de `MainTabView` — coherente parcialmente con "todo en 0/vacío", aunque no exactamente ("vacío" visualmente, no "0" en cifras).

**`InboxViewModel.swift`** (Yala/App/ViewModels/InboxViewModel.swift):
- `setContext(_ context:)` (líneas 53-57): `loadData()` **solo se llama la PRIMERA vez** que se invoca `setContext` con un `context` distinto al ya almacenado (`isNewContext`).
- **`InboxView.swift`** (Yala/App/Views/Inbox/InboxView.swift): `@State private var viewModel = InboxViewModel()` (línea 27) — el ViewModel vive y muere con la instancia de `InboxView`. Refresh: `.task { viewModel.setContext(modelContext) }` (línea 366-368, corre una vez) + `.onChange(of: sessionState.dataVersion) { viewModel.loadData() }` (línea 369-371). **Comentario explícito (líneas 363-365)**: *"Note: NO .appliesPendingRemoteChanges here — InboxView is always presented as a sheet, and mutating @Observable during sheet transition causes watchdog 0x8BADF00D. Reacts to remote changes via .onChange below."* — es decir, **el Inbox depende EXCLUSIVAMENTE de `sessionState.dataVersion`, nunca de `scenePhase`.**

**`PanelView.swift`** (contraste importante): SÍ tiene manejo de `scenePhase` (líneas 278-289):
```swift
.onChange(of: scenePhase) { _, newPhase in
    switch newPhase {
    case .background, .inactive:
        viewModel.setBackground(true)
    case .active:
        guard UIApplication.shared.applicationState == .active else { return }
        viewModel.setBackground(false)
        viewModel.reloadAndRecalculate()
    ...
    }
}
```
Este SÍ recarga en cada `.active` — pero con un **guard adicional `UIApplication.shared.applicationState == .active`** que, si es `false` en el momento exacto del callback, hace `return` sin recargar. Este guard fue introducido a propósito en el commit `261124e4` ("fix: watchdog 0x8BADF00D — robust background guard...", 2026-04-12), cuyo mensaje dice explícitamente: *"Robust background detection: UIApplication.applicationState guard + .inactive phase handling"* — **evidencia de que YA hubo un bug previo documentado donde `scenePhase == .active` se disparaba mientras `UIApplication.applicationState` todavía NO era realmente `.active`** (un estado transitorio/race conocido de iOS). Esto es un patrón defensivo pre-existente para un race YA VISTO antes, en un área de la API que Apple pudo haber movido/cambiado su timing en iOS 27.

### 5. `SessionState.dataVersion` — el mecanismo de refresh real

Archivo: `Yala/App/Models/SessionState.swift`.
- `SessionState.shared` (línea 81) es un **singleton**. Nunca se reinicializa salvo que el proceso muera.
- `dataVersion: Int = 0` (línea 430), incrementado por `incrementDataVersion()` (línea 435-437) o indirectamente por `applyPendingChangesIfNeeded()` (líneas 444-449), que solo actúa si `hasPendingRemoteChanges == true` (marcado por `markRemoteChangePending()`, línea 439-442).
- `markRemoteChangePending()` es llamado **exclusivamente** desde `AppBootstrapper.observeRemoteStoreChanges` (Yala/App/AppBootstrapper.swift:537-575), un observer de la notificación **`.NSPersistentStoreRemoteChange`**.
- **`AppBootstrapper.handleBecameActive(context:)` (línea 826-875), llamado en cada `scenePhase == .active` desde `YalaApp.swift:118-119`, SÍ llama `sessionState.applyPendingChangesIfNeeded()` (línea 835)** — pero esto solo dispara un refresh si `hasPendingRemoteChanges` ya estaba en `true` de ANTES (puesto por el observer de remote change). Si el observer nunca se disparó (porque nunca se registró — ver sección 6), esto es un no-op.

### 6. El eslabón que conecta todo: `.NSPersistentStoreRemoteChange` y el guard `isInitialized`

`AppBootstrapper.observeRemoteStoreChanges(context:)` (línea 537) es el **único** mecanismo que traduce "otro coordinator escribió en el mismo store SQLite" en "refrescar la UI de Yala". Se registra en el **paso 13 del bootstrap** (línea 214: `observeRemoteStoreChanges(context: context)`), dentro de `AppBootstrapper.bootstrap(container:)`.

**Esto cierra el círculo de la hipótesis central**: si `bootstrap()` nunca corrió durante la ejecución del Intent (porque el `.task` del `WindowGroup` nunca se disparó — el Intent no monta Scene), entonces **el observer de `.NSPersistentStoreRemoteChange` NUNCA se registró** en ese proceso hasta que, en algún momento posterior, algo dispare el `.task` de bootstrap. Si el `context.save()` del Intent (que sí escribe en el store físico compartido) ocurre **antes** de que el observer esté registrado, la notificación de remote-change se pierde por completo para ese proceso — nadie la escuchó. El draft SÍ existe en disco, pero `SessionState.dataVersion` nunca se incrementa para reflejarlo, y ningún ViewModel recarga.

Esto explicaría por qué el Inbox aparece vacío/desactualizado tras el warm-open — pero **no explica por sí solo "todos los datos en 0"**, que sugiere algo más agresivo que "simplemente no se refrescó" (que dejaría ver los datos VIEJOS, no CEROS). Para ese síntoma más severo, la hipótesis más plausible que la evidencia soporta es una variante distinta:

- **Si el sistema SÍ reutiliza el proceso vivo del Intent y crea la `Scene`/`ContentView` por primera vez recién cuando el usuario abre la app** (opción (a) de la sección 2), entonces el `.task { checkInitialSyncState() }` de `ContentView` **SÍ correría en ese momento** — sería la primera vez, con `@State hasExistingData = false` por defecto (línea 73) hasta que `checkHasExistingData()` (línea 674-684) complete su fetch. Ese fetch es rápido y síncrono (`fetchCount`), así que normalmente no debería demorar visiblemente. **Pero** si en ese preciso momento el `NSPersistentStoreCoordinator` del `sharedModelContainer` de la app está en medio de reconciliar el cambio recién escrito por el coordinator DEL INTENT sobre el mismo store físico (el equivalente a una ventana de "import" de un segundo escritor concurrente sobre el mismo SQLite, mecánicamente análogo — aunque no idéntico — a la ventana de import de CloudKit que CLAUDE.md documenta extensamente como causa de datos "colapsados"/vacíos durante restores), los fetches de `checkHasExistingData()` y de los ViewModels podrían devolver conteos transitoriamente en 0 mientras el store aún no ha "asentado" el merge del segundo coordinator. Este es el patrón EXACTO que CLAUDE.md ya documenta como causa raíz recurrente de "datos vacíos/colapsados" en el subsistema de sync de Grupos (ventana lazy de CloudKit, gate de quiescencia, `_assertionFailure` en saves concurrentes) — aquí el mecanismo sería análogo pero a nivel de dos coordinators LOCALES (Intent + app) escribiendo/leyendo el mismo SQLite, no CloudKit.
- Esto es **consistente** con que un cold launch posterior arregle todo: un cold launch real crea un solo `NSPersistentStoreCoordinator` desde cero, sin ningún otro coordinator "vivo" compitiendo por el mismo store en ese instante, así que no hay ventana de reconciliación pendiente.

### 7. Hipótesis iOS 27 — evidencia de documentación oficial de Apple

Se confirmaron 3 datos concretos vía `developer.apple.com` que son coherentes con (pero no prueban de forma concluyente) un cambio de comportamiento en iOS 27:

1. **`openAppWhenRun` está deprecated desde iOS 27**, reemplazado por `supportedModes`/`IntentModes`. Yala sigue usando la API vieja.
2. **`IntentExecutionTargets`, nuevo en iOS/iPadOS 27 (beta)**: *"A set of options that describes which process performs an intent or entity query... By default, the system performs an intent or entity query using any available target."* Esto confirma que Apple introdujo en iOS 27 un modelo explícito de "qué proceso ejecuta el intent" que no existía antes de forma pública — sugiriendo que la lógica interna de selección/reuso de proceso para App Intents cambió en esta versión.
3. **iOS & iPadOS 27 Beta 2 Release Notes, sección UIKit**: *"When linked on iOS 27... you can use `UIScene.extendStateRestoration` and `UIScene.completeStateRestoration` to extend state restoration for `UIScene.ActivationState.background` to `UIScene.ActivationState.foreground` lifecycle transitions."* — esto confirma **oficialmente que Apple tocó el modelo de transición de escena `background → foreground` en iOS 27**, introduciendo un mecanismo nuevo de "state restoration extendida" justo para esa transición.
4. **iOS & iPadOS 27 Beta 2 Release Notes, sección SwiftData**: *"Fixed: You might experience a deadlock for @Query when saving a ModelContext on a background actor while scheduling new async tasks for a ModelActor."* — no es idéntico al escenario de Yala (Yala no usa `@Query` en los ViewModels afectados ni `ModelActor`), pero es una señal adicional de que **hubo inestabilidad conocida en SwiftData específicamente en el cruce "guardar en background + tareas async concurrentes"** durante el ciclo de betas de iOS 27 — la forma general del patrón del Intent (`@MainActor func perform() async throws` que hace `context.save()` mientras la app puede tener sus propios `Task`s corriendo).

**No se encontró** ningún "Known Issue" en las release notes que mencione explícitamente App Intents + relanzamiento de app + datos vacíos/SwiftData — esto no descarta el bug (Apple no documenta exhaustivamente cambios de comportamiento de lifecycle en background), simplemente significa que no hay confirmación pública 1:1.

### 8. `.NSPersistentStoreRemoteChange` no dispara ningún `SessionState.incrementDataVersion()` desde el propio Intent

Confirmado explícitamente por lectura completa de `QuickExpenseIntent.swift`: el Intent nunca llama a `SessionState`, `AppRouter`, `RouterEntryGate`, ni posta ninguna `NotificationCenter` notification propia de Yala. Su único rastro para el resto del sistema es el `context.save()` sobre el store físico compartido — deja todo el trabajo de "avisar a la UI" al mecanismo pasivo de `.NSPersistentStoreRemoteChange`, que (sección 6) depende de que el observer ya esté registrado, cosa que solo pasa tras `AppBootstrapper.bootstrap()`.

## Hipótesis investigadas — resumen

| # | Hipótesis | Estado |
|---|---|---|
| 1 | El Intent usa un `ModelContainer` propio, no el de la app | **CONFIRMADO** (QuickExpenseIntent.swift:124-129) |
| 2 | Ambos containers (Intent + app) apuntan al mismo archivo SQLite | **CONFIRMADO** (SwiftDataConfiguration.swift:187, comentario explícito "same databaseName = same SQLite file") |
| 3 | Existe un guard "solo una vez" (`isInitialized`) que podría dejar el bootstrap a medias | **CONFIRMADO que existe**, pero **NO CONFIRMADO** que sea la causa directa — el Intent no invoca `AppBootstrapper` en absoluto, así que no hay "bootstrap a medias" en el sentido de que el guard bloquee un segundo intento; el problema es más bien que el bootstrap real (que registra el observer de remote-change) puede no haber corrido TODAVÍA cuando el usuario abre la app |
| 4 | El Inbox depende de `sessionState.dataVersion`, no de `scenePhase`, por diseño consciente (0x8BADF00D) | **CONFIRMADO** (InboxView.swift:363-371, comentario explícito) |
| 5 | El Panel SÍ recarga en `scenePhase == .active`, pero con un guard `UIApplication.applicationState == .active` que puede fallar en el momento exacto de una reconexión de escena atípica | **CONFIRMADO que el guard existe y por qué** (commit `261124e4`); **NO CONFIRMADO** si este guard específicamente falla en el escenario del bug (requiere logs de device) |
| 6 | iOS 27 cambió el modelo de ejecución de App Intents en background (deprecación de `openAppWhenRun`, nuevo `IntentExecutionTargets`) y el modelo de transición de escena `background→foreground` (`UIScene.extendStateRestoration`) | **CONFIRMADO documentalmente que Apple hizo estos cambios en iOS 27**; **NO CONFIRMADO** que sean la causa exacta del síntoma reportado (no hay Known Issue público 1:1) |
| 7 | El Intent deja al store en un estado de "reconciliación pendiente" entre dos coordinators concurrentes sobre el mismo SQLite, análogo a la ventana de import de CloudKit ya documentada en CLAUDE.md para otros bugs de "datos colapsados" | **HIPÓTESIS PLAUSIBLE Y CONSISTENTE con toda la evidencia recolectada**, pero **NO CONFIRMADA** — requeriría instrumentación en device (breadcrumbs / logs de Console.app) para verse en vivo, análogo al patrón `SaveBreadcrumb`/`SubcategoryDedupGate` que Yala ya usa para diagnosticar timing races de CloudKit |
| 8 | El Intent silencia/pisa el `SessionState`/`dataVersion` de la app de alguna forma | **DESCARTADO** — el Intent no toca `SessionState` en absoluto, ni para bien ni para mal; el problema es la AUSENCIA de aviso, no un aviso incorrecto |

## Fix

- **Causa raíz**: no se pudo confirmar al 100% sin device QA instrumentado, pero la evidencia de código apunta con alta confianza a una combinación de dos factores:
  1. **Arquitectural, pre-existente pero latente**: el `ApplePayTransactionIntent` opera sobre un `ModelContainer` propio, desacoplado del `sharedModelContainer` de la app, y no notifica a `SessionState`/`AppRouter` de ningún modo — el único canal de aviso es pasivo (`.NSPersistentStoreRemoteChange`), y ese canal solo está armado tras `AppBootstrapper.bootstrap()`, que solo corre cuando la `Scene`/`WindowGroup` se monta — algo que el Intent (con `openAppWhenRun = false` / modo background) puede no disparar.
  2. **Disparador nuevo en iOS 27**: los cambios documentados de Apple en el modelo de ejecución de App Intents (deprecación de `openAppWhenRun`, `IntentExecutionTargets` explícito) y en la transición de escena `background → foreground` (`UIScene.extendStateRestoration`) son coherentes con que iOS 27 cambiara **cuándo y cómo** el sistema reutiliza el proceso que corrió el Intent al abrir la app después — probablemente haciendo más común el escenario "proceso ya vivo, Scene se crea por primera vez ahora" (que antes podía resolverse casi siempre con un proceso nuevo/cold launch real), exponiendo la fragilidad arquitectural del punto 1.

- **Solución propuesta** (en orden de robustez, no mutuamente excluyentes):

  1. **Hacer que `ApplePayTransactionIntent` (y los otros intents que crean su propio `ModelContainer`) avisen explícitamente a la app tras `context.save()`.** El patrón más simple y de menor riesgo: tras el `save()` exitoso (QuickExpenseIntent.swift:222), postear una `Darwin notification` cross-process (`CFNotificationCenterPostNotification` con `CFNotificationCenterGetDarwinNotifyCenter()`) o escribir un flag en `UserDefaults(suiteName: WidgetURLHelper.appGroupIdentifier)` (patrón YA usado en el mismo archivo para `LastUsedAccountStore`, líneas 653-666, y en `AppBootstrapper.checkForPendingControlAction`, línea 883-922) que la app lea al volver a foreground. Esto es más confiable que depender de `.NSPersistentStoreRemoteChange` porque no depende de que el observer ya esté armado — la app puede chequear el flag activamente en `ContentView.onChange(of: scenePhase) case .active` (línea 455) o en `AppBootstrapper.handleBecameActive` (línea 826), sin importar el orden de boot.

  2. **Hacer que `ContentView`/`AppBootstrapper` sean robustos a una reconexión de Scene con el bootstrap incompleto.** Esto ataca la causa raíz #2 de la tabla: agregar un chequeo explícito en `ContentView.onChange(of: scenePhase) case .active` (línea 455) que, si `!AppBootstrapper.shared.isInitialized`, dispare (o espere) el bootstrap antes de asumir que los datos actuales son correctos — en vez de confiar ciegamente en que `.task { checkInitialSyncState() }` ya corrió. Esto sería el equivalente arquitectónico, para este subsistema, del gate de quiescencia (`isImportQuiescent`/`SubcategoryDedupGate`) que CLAUDE.md documenta para el sync de Grupos y de CloudKit — aquí el "import en curso" sería "el otro coordinator (Intent) puede haber escrito hace instantes".

  3. **Migrar `InboxView`/`PanelView`/`ContentView.hasExistingData` a recargar de forma defensiva también en `scenePhase == .active`**, no solo vía `sessionState.dataVersion`, con el mismo guard robusto que ya usa `PanelView` (`UIApplication.applicationState == .active`) pero verificado/endurecido para iOS 27 — es posible que ese guard necesite una re-verificación con un pequeño delay o un segundo chequeo (patrón `Task { try? await Task.sleep(...); if applicationState == .active { reload() } }`) si el timing exacto de cuándo `applicationState` se pone `.active` cambió en iOS 27. **Nota**: esto NO se puede confirmar ni descartar sin device QA con logs — es una hipótesis de mitigación, no un fix verificado.

  4. **Instrumentación mínima antes de cualquier fix** (recomendado primero, dado que la causa raíz no está 100% confirmada): añadir un breadcrumb tipo `SaveBreadcrumb` (patrón ya existente en `AppBootstrapper.swift`, ej. líneas 635-637, 722-724 — Logger fuera de `#if DEBUG`, sin PII) en: (a) `ApplePayTransactionIntent.perform()` justo antes/después del `context.save()`, con timestamp; (b) `AppBootstrapper.bootstrap()` al entrar y al setear `isInitialized = true`; (c) `ContentView.checkInitialSyncState()` al entrar; (d) el observer de `.NSPersistentStoreRemoteChange`. Esto permitiría, en el próximo reporte del owner, leer Console.app y confirmar EXACTAMENTE la secuencia real de eventos (¿el bootstrap corrió antes o después del save del Intent? ¿se registró el observer? ¿se disparó `.NSPersistentStoreRemoteChange`?) sin necesidad de adivinar. Es el mismo enfoque que ya se usó exitosamente para diagnosticar la saga de crashes de sync de Grupos (`project_groups_sync_crash_saga`, ver CLAUDE.md "Decisiones Recientes" 2026-06-21 a 2026-06-22).

## Riesgo de reproducción

- **Apple Pay no funciona en Simulador** — este bug es 100% device-only. No hay forma de reproducirlo ni verificar el fix en `/device-qa` (que usa simulador).
- Reproducirlo en device real implica pagar con Apple Pay real (transacción con dinero real, aunque sea de monto mínimo) — no destructivo para los datos de la app en sí, pero sí tiene un costo/fricción real para quien lo prueba (no es gratis como un test en simulador).
- El escenario específico a reproducir es sensible al timing: "abrir la app justo después de la automatización, SIN matar el proceso antes". Si se prueba con demasiada demora entre el pago y el intento de abrir la app, es posible que iOS ya haya suspendido/matado el proceso del Intent de forma normal, y el usuario obtenga un cold launch real sin el síntoma — lo que podría dar un falso negativo ("ya no reproduce") sin que el bug esté realmente arreglado.
- **Recomendación de QA controlado**: pedir al owner (o a quien reproduzca) que, en el próximo intento, antes de tocar el ícono de Yala, abra brevemente la app de **Ajustes** de iOS y vuelva a Home — esto no mata el proceso de Yala pero da una ventana de tiempo controlada para observar si el síntoma depende de "cuánto tiempo pasó" desde la automatización. También sería valioso pedir capturar el log de Console.app (macOS conectado al iPhone, filtro por proceso `Yala`) durante la reproducción — especialmente si se aplica el punto 4 de la solución propuesta (instrumentación) antes del próximo intento de reproducción.
- Como el owner reporta que el fix "antes funcionaba bien" y esto es "nuevo con iOS 27", vale la pena verificar primero si el dispositivo de prueba está en una build de iOS 27 **beta** (dado que las release notes de iOS 27 consultadas en esta investigación son de "Beta 2") — si es así, existe la posibilidad adicional (no investigada aquí, fuera del alcance del código de Yala) de que sea un bug transitorio de una beta de iOS que Apple corrija en releases posteriores de iOS 27, sin que Yala necesite cambiar nada. Esto no exime de aplicar las mitigaciones de robustez propuestas (que son buena práctica de cualquier forma), pero es un dato relevante a confirmar con el owner antes de invertir en el fix completo.

## Implementación

### 2026-07-02 — `db397ce7`

**Resumen:** el bug NO era una regresión de iOS 27. Un research con fuentes primarias de Apple (2 agentes, docs + WWDC + release notes) confirmó que la causa raíz es el patrón dual-container: el `ApplePayTransactionIntent` (y `SiriNaturalEntryIntent`) creaba su propio `ModelContainer` con `personalConfiguration` = `cloudKitDatabase: .private` sobre el MISMO archivo SQLite que el `sharedModelContainer` de la app. En warm launch, con el proceso de la app vivo, el 2º container `.private` choca con el 1º en el mismo proceso → **error CloudKit 134410** ("another instance actively syncing with CloudKit in this process") → el store queda en mal estado → todos los datos en 0 hasta que un cold launch reinicia el proceso. Es el anti-patrón que Apple documenta en TN3164 ("Avoid synchronizing a store with multiple persistent containers"). Además, aunque el observer de `.NSPersistentStoreRemoteChange` existiera, solo marca pending (no incrementa `dataVersion`), y un merge que aterriza estando ya en foreground no se aplicaba hasta navegar → bandeja stale.

**Decisión de profundidad (owner):** fix *targeted*, NO el single-container textbook. Unificar en el `sharedModelContainer` sería lo más correcto per Apple, pero el intent corre en un proceso background sin el bootstrap ni el gating de quiescencia → escribir en el `mainContext` compartido durante el import de CloudKit dispararía el crash-loop `_assertionFailure`/SIGTRAP que costó semanas domar en el sync de Grupos.

**Archivos modificados:**
- `Yala/Utils/SwiftDataConfiguration.swift` — nueva `personalLocalWriteConfiguration` (mismo `databaseName`, `cloudKitDatabase: .none`). NO se tocó `personalConfiguration` (la app sigue `.private` = único dueño del sync).
- `Yala/App/Intents/QuickExpenseIntent.swift` — ambos intents usan la config `.none`; marcan `PendingIntentSaveSignal` tras el save (antes de notificar); breadcrumb de creación de container (canario del 134410).
- `Yala/App/Intents/PendingIntentSaveSignal.swift` (nuevo) — señal cross-launch en App Group UserDefaults (timestamp).
- `Yala/App/AppBootstrapper.swift` — consume la señal en `handleBecameActive` (→ `markRemoteChangePending` + `scheduleIntentSaveRefire`) y red en `bootstrap()`; `scheduleIntentSaveRefire` (re-fire bounded ~10s que drena el merge tardío); breadcrumbs en el observer y en la entrada del bootstrap.
- `Yala/App/Models/SessionState.swift` — `applyPendingChangesIfNeeded()` ahora `@discardableResult -> Bool` (corte temprano del re-fire).
- `Yala/App/Logic/IntentSignalBreadcrumb.swift` (nuevo) — instrumentación Console.app (category `IntentSignal`, fuera de `#if DEBUG`, sin PII).
- `Yala/Services/TelemetryService.swift` — canario `intentSaveSignalConsumed`.
- `Yala/App/ContentView.swift` — breadcrumb `initialSyncChecked` en `checkInitialSyncState`.

**Decisiones técnicas:**
- **Config `.none` para los intents** en vez de compartir el container: mata el conflicto 134410 sin importar la delicada arquitectura de dos stores de la app. La app exporta los writes del intent a CloudKit vía persistent history en su próximo run (single-owner, per TN3164). **Cambio de comportamiento**: el gasto llega a CloudKit al abrir la app, no desde el proceso del intent — intrascendente para un borrador que se aprueba in-app, pero a validar cross-device.
- **Re-fire bounded, no timing-hack:** drena `applyPendingChangesIfNeeded` mientras estamos en foreground para capturar el merge del coordinator cuando aterriza (un `fetch` no hace pull; solo el apply refresca). Cuelga del mecanismo LOCAL de remote-change, NO de `waitForImportQuiescence` (que es del import de CloudKit remoto). Se quitó un backstop incondicional que forzaba un reload completo redundante ~10s tras cada warm launch (hallazgo del `/code-review high`).
- **Instrumentación primaria:** dado que el bug solo reproduce en device real, los breadcrumbs confirman en Console.app la secuencia (`SIGNAL SET` → `SIGNAL CHECK found` → `REMOTE-CHANGE fired` → `REFIRE applied` → `INITIAL-SYNC hasExistingData`). Si sale `found=true` + `hasExistingData=false` persistente → escalación documentada (catch-up de persistent history / `HistoryObserver` iOS 27).

**Tests añadidos:**
- `PendingIntentSaveSignalTests` (5) — `mark`/`consume`/last-write-wins/garbage-no-numérico/`ageBucket`. El e2e del warm launch es device-only (Apple Pay no existe en simulador + los tests e2e de `AppBootstrapper` crashean el runner).

**Escalación documentada (si la QA device revela que el refresh no basta):** catch-up explícito de persistent history en foreground (`HistoryObserver` iOS 27 con fallback manual iOS 26). No implementado — la instrumentación decide.

### 2026-07-04 — refactor: el intent deja de tocar SwiftData (cura de raíz)

**Resumen:** el fix `db397ce7` (config `.none`) NO bastó. En TestFlight el owner reprodujo: warm launch → solo Panel poblado (bandeja/registros vacíos); cold launch inmediato → todo en 0; recuperable cerrando y reabriendo. Diagnóstico en device: el intent **funciona** (notifica siempre y el draft aparece tras un 2º cold launch) → no está roto; el problema es la **ventana de reconciliación** entre las dos conexiones al mismo SQLite (la app `.private` + el container del intent) al abrir la app justo después del atajo. `.none` calmó el 134410 pero la 2ª conexión seguía. Los datos nunca se pierden (problema de lectura).

**Cura de raíz:** el `ApplePayTransactionIntent` **ya no crea `ModelContainer` ni guarda el `InboxDraft`**. Solo parsea el monto (puro), **encola el pago crudo en App Group** y notifica. La **app** —único dueño del store— crea el `InboxDraft` al abrir, gateada por la quiescencia del import de CloudKit (mismo gate que `ScheduledPaymentDraftService`, evita el crash `_assertionFailure`/SIGTRAP). Sin 2ª conexión → desaparece toda la familia de síntomas (134410, "solo Panel", "todo en 0") y se arregla el refresh (la app crea el draft y sube `dataVersion`).

**Cambio de comportamiento (aceptado por el owner):** el gasto se **crea al abrir la app**, no en el instante del pago; la notificación sigue siendo inmediata. Varios pagos sin abrir la app se acumulan; si el import de CloudKit está activo al abrir, la creación se difiere al próximo arranque quiescente / trailing-edge (el pago persiste, idempotente).

**Alcance:** solo Apple Pay. `SiriNaturalEntryIntent` comparte el mecanismo (`.none` + su container) pero es más delicado (LLM + diálogo) → ticket aparte (`qa_siri-intent-dual-container-refactor`). Por eso NO se borró `personalLocalWriteConfiguration` / `PendingIntentSaveSignal` / `scheduleIntentSaveRefire` (los usa Siri).

**Archivos:**
- NUEVOS: `Yala/App/Intents/ApplePayAmountParser.swift` (parseo puro, sin SwiftData), `Yala/App/Intents/ApplePayPendingStore.swift` (cola App Group, **una key por pago** — no lista, para evitar el race read-modify-write cross-process intent↔app), `Yala/App/Services/ApplePayDraftService.swift` (materializa con `peek`/`remove`-tras-save, gate de quiescencia).
- MODIFICADOS: `QuickExpenseIntent.swift` (adelgazado + guard de monto cero), `AppBootstrapper.swift` (3 sitios: bootstrap, handleBecameActive, trailing-edge del observer de remote-change), `AppPreferences.swift` (key `pendingApplePayExpenses`), `TelemetryService.swift` (eventos `applePayPayloadMaterialized` / `applePayPayloadDropped`).

**Code-review `high` (5 ángulos) → 4 fixes aplicados:** (1) **race cross-process** — la cola pasó de lista-en-una-key a **una key por pago** + consume-after-save (nunca borra antes del save durable) → sin perder ni duplicar pagos; (2) `catch` de encode/decode sin log → `#if DEBUG` (regla inviolable); (3) código de divisa al final validado contra `CurrencyCode` (antes `"$50 FEE"` tomaba "FEE"); (4) guard de monto cero (auth/hold de $0 ya no crea borrador espurio). Descartados tras verificar: refresh cubierto por el trailing-edge, exclusión de cuentas de sistema preservada, TOCTOU del gate = patrón aceptado del proyecto.

**Canario nuevo:** `intentSaveSignalConsumed` (documentado antes como canario de Apple Pay) ahora solo refleja **Siri**; el canario de Apple Pay pasa a ser **`applePayPayloadMaterialized`** (y `applePayPayloadDropped` para payloads corruptos/cero).

**Verificación:** build Yala + Yala Dev verde (0 warnings); 20 tests unitarios verdes (`ApplePayAmountParserTests`, `ApplePayPendingStoreTests` — incluye anti-duplicado, consume-after-save, corrupto, divisa inválida); smoke test de arranque en simulador OK (bootstrap con `processPending` sobre cola vacía no rompe el arranque). **El e2e real (pago Apple Pay) es device-only → PENDIENTE TestFlight.**

**QA TestFlight (device):** matriz — (a) pago + abrir en **warm** → datos poblados y borrador en Bandeja SIN cerrar/reabrir; (b) pago + **cold** launch → ídem; (c) **varios pagos** sin abrir → aparecen todos; (d) pago con **iCloud sincronizando** al abrir → el borrador aparece en cuanto el import se asienta (trailing-edge). Plan: `~/.claude/plans/crystalline-kindling-kitten.md`.

migrated from YalaWiki Bugs/ok_applepay-shortcut-ios27-warm-launch-datos-vacios.md @ 1934e8ad
