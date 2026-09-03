//
//  AppBootstrapper.swift
//  Yala
//
//  Centraliza la inicialización de servicios y tareas de arranque.
//  Resuelve ARCH-005: Inicialización dispersa en YalaApp.
//

import CloudKit
import CoreData
import GoogleSignIn
import OSLog
import SwiftData
import SwiftUI
import UserNotifications
import WidgetKit

/// Centraliza la inicialización de la app y gestión del ciclo de vida.
@MainActor
final class AppBootstrapper {

    // MARK: - Singleton

    static let shared = AppBootstrapper()

    // MARK: - Services (for @Environment injection)

    let sessionState = SessionState.shared
    let currencyConverter = CurrencyConverter.shared
    let exchangeRateService = ExchangeRateService.shared
    let imageVisionService = ImageVisionService.shared
    let voiceTranscriptionService = VoiceTranscriptionService.shared
    let transcriptionParserService = TranscriptionParserService.shared
    let draftService = DraftService.shared
    let entityDeletionService = EntityDeletionService.shared
    let transactionService = TransactionService.shared
    let budgetAlertService = BudgetAlertService.shared
    /// M1: la puerta de dominio decide si estas 76 properties viven en el cajón del dueño o en el de
    /// la visita. Es el ÚNICO constructor de producción — el resto son `#Preview`.
    let appPreferences = AppPreferences(defaults: SessionDefaults.current)

    // MARK: - Panel Action (Control Center / widgets)

    enum PanelAction {
        case newTransaction
        case voiceEntry
        case imageEntry
    }

    // MARK: - State

    private(set) var isInitialized = false
    private var subscriptionCheckTask: Task<Void, Never>?
    /// C-8: sync del entitlement de CUENTA, fuera del camino crítico del boot (hace red).
    private var accountEntitlementTask: Task<Void, Never>?
    private var remoteChangeTask: Task<Void, Never>?
    private var remoteChangeLeadingFired = false
    private var lastNotificationCheckDate = Date.distantPast
    private var lastProcessDuePaymentsDate = Date.distantPast
    private let logger = Logger(subsystem: "com.yala", category: "Bootstrap")
    /// Cached on the main actor so the `.transactionsImportedFromSync` observer
    /// can resolve it without capturing a non-Sendable `ModelContext` in its
    /// `@Sendable` callback closure.
    private var raceCleanerModelContext: ModelContext?
    /// Cached on the main actor so the `.NSPersistentStoreRemoteChange` observer
    /// can run the subcategory dedup without capturing a non-Sendable `ModelContext`.
    private var remoteChangeModelContext: ModelContext?
    /// Token del observer del fan-out del Modo Nube (paso 14.7, DARK). Retenido para poder removerlo
    /// (fix MENOR del review de I9: descartarlo con `_ =` lo hacía irremovible).
    private var cloudSyncFanOutObserver: NSObjectProtocol?

    /// **R4: los cuatro observers de `NotificationCenter` de este bootstrap se instalan UNA vez por
    /// PROCESO, no una vez por bootstrap.** Hasta el swap de persona in-process las dos cosas eran lo
    /// mismo (`bootstrap` corta en `isInitialized` y nadie lo reponía), y ninguno de los cuatro guarda su
    /// token ⇒ un segundo bootstrap los duplicaría y no habría forma de retirarlos: cada
    /// `.NSPersistentStoreRemoteChange` dispararía dos veces el coalescing, y el race-cleaner correría
    /// dos veces por import. Ninguno de ellos captura el `ModelContext` (leen la propiedad del singleton,
    /// que el swap sí repone), así que sobrevivir al remonte es correcto — lo que no puede es multiplicarse.
    private var lifecycleObserversInstalled = false

    // MARK: - Initialization

    private init() {
        // Private to enforce singleton
    }

    // MARK: - Bootstrap

    /// Ejecuta todas las tareas de inicialización al arrancar la app.
    /// Llamar desde el .task{} de YalaApp.
    func bootstrap(container: ModelContainer) async {
        IntentSignalBreadcrumb.bootstrapEntered(alreadyInitialized: isInitialized)
        guard !isInitialized else { return }

        // El shell no drena intents (ni monta covers) hasta que el arranque asienta: un
        // `fullScreenCover` montado con el bootstrap en curso se queda pegado y la app deja
        // de responder a los taps (blocker `bootstrapPending` de la matriz de readiness —
        // ver `SessionState.isBootstrapSettled`). `defer` y no una asignación al final:
        // ningún camino de salida puede dejar el shell bloqueado para siempre.
        defer { SessionState.shared.isBootstrapSettled = true }

        let context = container.mainContext

        let uiTestActive = UITestHooks.isActive
        // Nota: applyUITestHooksEarly (reset/pro/skip-onboarding) se aplica en
        // YalaApp.init(), ANTES del primer render — no aquí. En el .task de bootstrap
        // competía con el .task de ContentView.checkInitialSyncState, que leía
        // hasCompletedOnboarding=false y presentaba el Welcome Hero (cover sticky)
        // antes de que el flag se seteara → la app quedaba atascada en Welcome.

        // 0.0. CRITICAL: One-shot wipe de Cash Flow (bug sync 1.2.6 — ver CashFlowWipeService)
        //      Debe ir PRIMERO para minimizar ventana con outbox CloudKit corrupta en juego.
        //      Pérdida acotada a config local de Cash Flow (feature Pro nueva que nunca sincronizó).
        CashFlowWipeService.wipeCashFlowDataIfNeeded(in: context)

        // 0. Sync preferences from iCloud (must be FIRST — other services read these)
        if !uiTestActive { PreferenceSyncService.shared.bootstrap() }

        // 0.1. Migración one-shot del override de idioma (UserDefaults.standard → App Group)
        //      Idempotente vía sentinel; sólo corre la primera vez post-update.
        LanguageManager.bootstrapMigrationIfNeeded()

        // 0.2. Cleanup one-shot del Keychain del antiguo bloqueo biométrico in-app (removido).
        //      Idempotente vía sentinel; no toca SwiftData.
        cleanupBiometricKeychainIfNeeded()

        // 0.5. Telemetría propia mínima (sustituye TelemetryDeck): arranque + ping diario
        //      (usuarios activos/día, dedup UTC client-side) + drain del spool de canarios.
        //      Bajo `-uitest` start() es no-op (guard interno) — cero red en XCUITests.
        MetricsService.start()
        MetricsService.dailyActivePingIfNeeded()

        // 0.55. Track session for upsell frequency capping
        ProUpsellService.shared.incrementSessionCount()

        // 0.6. Record first launch date for review prompt timing
        ReviewPromptService.recordFirstLaunchIfNeeded()

        // 1. Initialize notification delegate (must be early for foreground display)
        _ = NotificationService.shared

        // 2. Load exchange rates (required for currency display)
        await loadExchangeRates(context: context)

        // 2.5. Migración Live Balance multi-divisa diferida — bulk recalc
        //      puede ser O(N) sobre miles de tx. Lanzamos en background tras
        //      bootstrap para no bloquear UI en cold launch.
        Task { @MainActor in
            await migrateToLiveBalanceIfNeeded(context: context)
        }

        // 3. Load subscription status
        await loadSubscriptionStatus()

        // 4. Process due scheduled payments (create inbox drafts)
        if !uiTestActive { processDueScheduledPayments(context: context) }

        // 4b. Materializar gastos de Apple Pay / dictados de Siri encolados por sus intents
        // (App Group → InboxDraft). Los intents ya no tocan SwiftData; la app crea los borradores
        // aquí (gateado por quiescencia). El refresh de UI lo cubre el `incrementDataVersion()` del
        // final del bootstrap.
        if !uiTestActive {
            ApplePayDraftService.processPending(context: context)
            SiriDraftService.processPending(context: context)
            // Refrescar la caché que lee el intent de Siri (subcategorías para el LLM + divisa + si
            // hay cuentas). Read-only (no save) → seguro aunque el import de CloudKit siga en curso;
            // converge en cada foreground.
            SiriIntentContextCache.refresh(context: context, defaultCurrency: appPreferences.defaultCurrencyCode.rawValue)
        }

        // 5. Check for pending inbox drafts and notify user
        if !uiTestActive { checkForPendingInboxDrafts(context: context) }

        // 6. Seed default notifications for existing users
        seedDefaultNotifications(context: context)

        // 6.1. Deduplicate notifications (R9: handles CloudKit race during onboarding)
        NotificationService.shared.deduplicateNotifications(context: context)

        // 6.5. Cancel any old scheduled dynamic notifications (reports)
        // These use background tasks now, not iOS scheduling
        await NotificationService.shared.cancelDynamicNotifications(context: context)

        // 6.55. One-shot: toggle maestro de pagos honesto (decisión owner D2 2026-07-22).
        // DEBE correr ANTES de ensureNotificationsScheduled — con el gate ya honesto, un item
        // inactivo silenciaría este primer pass y el usuario perdería el día.
        ScheduledPaymentNotificationService.flipMasterToggleIfNeeded(context: context)

        // 6.6. Ensure static notifications are scheduled (handles reinstall/update case)
        await ensureNotificationsScheduled(context: context)

        // 7. Clean up stale pending images (>24h). La RECUPERACIÓN de imágenes pendientes
        // (checkForPendingSharedImage) se movió a post-`isInitialized` (paso 21, abajo):
        // correrla aquí la difería porque `isInitialized == false` → RouterEntryGate manda el
        // `.presentSharedImage` (no-serializable) al buffer, que lo descarta en silencio →
        // "no hace nada" en cold launch. Ver Bugs/qa_cold-launch-share-image-no-registro.
        SharedContainerService.clearOldPendingImages(olderThan: 86400)

        // 8. Initialize services with context
        currencyConverter.setContext(context)
        budgetAlertService.setContext(context)
        // DraftService se usa fuera del flujo del Inbox (opt-in de gastos/liquidaciones de
        // grupo), por lo que necesita el contexto desde el arranque y no solo just-in-time
        // como lo seteaban las vistas del Inbox.
        draftService.setContext(context)

        // 8.5. Migración V3: regen UUIDs + re-encode CSV mirrors en una sola save atómica.
        // Gated al hook `iCloudFirstImportCompleted` para garantizar que M2M está
        // hidratada antes de re-encodear (cierra el "flash vacío" causado por la
        // ventana lazy de CloudKit en cold launch). Task no-blocking — UI renderiza
        // antes de que la migración complete; mientras corre los readers usan el
        // resolver con fallback M2M.
        Task { @MainActor in
            let started = Date.now
            let decision = MigrationGateLogic.shouldWaitForCloudKit(
                isAccountAvailable: iCloudSyncService.shared.isAccountAvailable,
                hasCompletedFirstImport: iCloudSyncService.shared.hasCompletedFirstImport
            )
            var waitedForSync = false
            var importSettled = true
            if decision == .waitForHook {
                waitedForSync = true
                importSettled = await iCloudSyncService.shared.forceFetchAndWait(timeout: 15)
            }
            let waitDuration = Date.now.timeIntervalSince(started)
            migrateShortcutIDsAndRebuildCSVMirrors(
                context: context,
                waitedForSync: waitedForSync,
                importSettled: importSettled,
                waitDuration: waitDuration
            )
            // Cleanup de subcategorías duplicadas (post-migración: el re-sync masivo que
            // dispara la regen de shortcutID ya convergió aquí). Gateado por quiescencia.
            // También reporta posibles duplicados de Account/Tag (telemetría detectora).
            CategoryDeduplicationService.runDedupIfQuiescent(in: context)
            // Seed diferido de defaults de Panel: en `AppPreferences.init` se difirió para no
            // clobbear la config que el sync aún no había bajado. Aquí (post-hook, o sin cuenta
            // iCloud vía el gate de arriba) la decisión sobre fresh-vs-existente ya es segura.
            PanelPreferencesMigration.runIfNeeded(appPreferences: appPreferences)
        }

        // 9. Update widget cache
        WidgetDataCache.updateCache(context: context)

        // 10. Register background tasks
        BackgroundTaskManager.shared.registerTasks()

        // 11. Set model container for background tasks and schedule first report task
        BackgroundTaskManager.shared.setModelContainer(container)
        BackgroundTaskManager.shared.scheduleNextReportTask(context: context)
        // Siembra inicial del widget-refresh — sin esto el request NUNCA entra a la cola: su único
        // otro submit vive DENTRO de su propio handler (re-programación), que jamás corre si nadie
        // sembró la primera vez (bug latente cazado en device durante el spike S7, 2026-07-09).
        // `submit` reemplaza el request pendiente por identifier → re-sembrar en cada boot es seguro.
        BackgroundTaskManager.shared.scheduleWidgetRefresh()

        // 12. Check if any report notifications should be sent now (app launch case)
        await ReportNotificationService.shared.sendDueReports(context: context)

        // 12.5–14.5. Los cuatro observers del ciclo de vida. **R4: por PROCESO, no por bootstrap** — el
        // swap de persona vuelve a llamar a `bootstrap` con el container nuevo y ninguno de los cuatro
        // guarda su token, así que reinstalarlos sería duplicarlos sin poder retirarlos. Las dos
        // propiedades de contexto que alimentan a dos de ellos SÍ se reponen en cada bootstrap (abajo),
        // que es lo que hace correcto que el observer sobreviva al remonte.
        raceCleanerModelContext = context
        remoteChangeModelContext = context
        if !lifecycleObserversInstalled {
            lifecycleObserversInstalled = true
            // 12.5. Observe exchange rate updates to invalidate the latest-rates cache
            observeExchangeRateUpdates()
            // 13. Observe CloudKit remote changes to auto-refresh UI
            observeRemoteStoreChanges()
            // 14. Observe iCloud account changes — detect mismatch if container was created without CloudKit
            observeICloudAccountChanges()
            // 14.5 (M6). Observe TX imports from CKSync personal — autodelete drafts pendientes Caso A
            // cuyo splitExpenseID ya tiene TX cuenta real (race resuelto por sync).
            observeTransactionsImportedFromSync()
        }

        // 14.55 B1 (SIWA revoke 5.1.1(v)): composición de PRODUCCIÓN del hook de canje — el ÚNICO punto
        // que instala el closure real (AJUSTE #2 del brief: CloudAuthService no depende de
        // CloudAccountClient; el default nil = no-op). Gateado como 14.6: desde D-R1 paso 1 el gate está
        // ABIERTO también en producción, así que el hook se instala ahí — pero sin sign-in no se dispara
        // nunca. ContentView espera este bootstrap antes de mostrar UI → el hook está instalado antes de
        // cualquier sign-in interactivo.
        if CloudBackendConfig.isConfigured {
            SIWAExchangeSeam.installProductionHook()
        }

        // 14.56 Remote-config del Modo Nube (DIFERIDOS #34): fetch fire-and-forget de GET /config
        // (kill-switch de las ENTRADAS, §j.1/§j.2). Gateado por `isConfigured` —ABIERTO en producción
        // desde D-R1 paso 1: ÉSTE es el único tráfico nuevo que trajo aquel commit, y es deseado, porque
        // aquí viaja el aviso de versión obligatoria— y por `!uiTestActive` (hermeticidad: los XCUITests
        // no tocan red, como los pasos hermanos; bajo uitest los getters ya devuelven el default).
        // Coalescente con min-interval 6 h. Jamás bloquea el boot; el snapshot se lee en el
        // siguiente render de las superficies gateadas.
        if CloudBackendConfig.isConfigured && !uiTestActive {
            Task { await RemoteConfigClient.shared.refreshIfDue() }
        }

        // 14.6 Modo Nube — coordinator de migración (I14, P4). Dueño único del `MigrationRunner`. Gateado
        // por `CloudBackendConfig.isConfigured` (abierto en los dos schemes desde D-R1 paso 1: en
        // producción SÍ se instancia, y con fase `notStarted` sin efectos pendientes decide `.none`). Retoma una
        // migración/reversa matada a medias (journal transicional o efectos pendientes) ANTES del 14.7 y,
        // al quedar la fase estable, re-arranca el runtime del dominio (que P0 pudo cortar por fase
        // transicional). `startShared` del 14.7 es idempotente (no re-arranca si ya corre).
        if CloudBackendConfig.isConfigured {
            CloudMigrationController.configureShared(context: context)
            Task { await CloudMigrationController.shared?.resumeIfNeeded() }
        }

        // 14.7 Modo Nube runtime (I9). El gate del dominio (P0) lo corta en `.icloud` o en fase transicional
        // (default de producción HOY): ni observer, ni arranque, ni red. Va ANTES del paso 15 de Grupos
        // (no toca Grupos). El fan-out post-apply se cablea a la UI vía `.cloudSyncAppliedRemoteChanges`
        // (espejo del observer de CloudKit del paso 13 — `markRemoteChangePending`).
        if CloudSyncFlags.syncRuntimeEnabled {
            if cloudSyncFanOutObserver == nil {
                cloudSyncFanOutObserver = NotificationCenter.default.addObserver(
                    forName: .cloudSyncAppliedRemoteChanges, object: nil, queue: .main
                ) { _ in
                    Task { @MainActor in SessionState.shared.markRemoteChangePending() }
                }
            }
            Task { await CloudSyncRuntime.startShared(context: context) }
        }

        // 15. Canal de sync de Grupos → backend. Era el paso donde además arrancaba el CKSyncEngine de
        // Grupos; la Fase 3 se llevó ese transporte y con él el gate de sesión SECUNDARIA que lo protegía
        // (el engine estaba atado al Apple ID del OS, así que en secundaria habría sincronizado los grupos
        // del DUEÑO). El canal backend no tiene ese problema —va por el `sub` de la sesión Yala— y por eso
        // su propia condición ya contemplaba a la invitada.
        // G2 (DARK): NO-OP salvo con `groupsBackendEnabled` ON (jamás
        // en producción esta fase) — el guard interno retorna antes de tocar red o modelos.
        // M1 / D8 (G5-C): con el flag ON la sesión secundaria SÍ arranca el canal backend (sus grupos, su
        // sesión; el `currentUserIDProvider` = sub de la invitada + el espejo owner-scoped la aíslan).
        // `startIfEligible` re-gatea por flag+sesión internamente; con flag OFF la condición reproduce el
        // guard de secundaria de antes (byte-idéntico).
        if !uiTestActive && (CloudSyncFlags.groupsBackendEnabled || !SecondarySessionStore.isActive()) {
            GroupsSyncClient.shared.startIfEligible(context: context)
        }

        // G8-2 (DARK): re-registro del push token de grupos al arrancar el canal (cubre el orden
        // token-antes-de-sesión y el boot). Self-gateado por flag+sesión → no-op total con el flag OFF.
        if !uiTestActive { PushTokenRegistrar.shared.attemptUpload() }

        // 16. Initialize Group Services (GC-03)
        GroupService.shared.setContext(context)
        GroupExpenseService.shared.setContext(context)
        GroupTransactionBridge.shared.setContext(context)
        BridgeModeResolver.shared.setAppPreferences(appPreferences)

        // 16.4. Cleanup duplicate SplitGroups from CloudKit sync race.
        // Runs sync (not Task) so consumers downstream see canonical groups only.
        SplitGroupDeduplicationService.deduplicateSplitGroups(in: context)

        // 16.4.1. Cleanup duplicate GroupBridgePreference records (CloudKit sync race
        // entre devices que crean override simultáneamente). Sync — el resolver consulta
        // el override desde el primer bridge call post-boot, mejor que no haya dups.
        GroupBridgePreferenceDeduplicationService.deduplicate(in: context)

        // 16.4.2. Cleanup overrides huérfanos (grupos abandonados o `isHiddenForAll==true`
        // que el observer/leaveGroup pudo perder por crash). Defensivo idempotente.
        Task { @MainActor in
            do {
                let descriptor = FetchDescriptor<SplitGroup>(
                    predicate: #Predicate<SplitGroup> { $0.isHiddenForAll == false }
                )
                let activeGroups = try context.fetch(descriptor)
                let activeZoneIDs = Set(activeGroups.map(\.cloudKitZoneID))
                try BridgeModeResolver.shared.clearOrphanOverrides(
                    activeZoneIDs: activeZoneIDs,
                    in: context
                )
            } catch {
                #if DEBUG
                print("AppBootstrapper: clearOrphanOverrides failed: \(error)")
                #endif
            }
        }

        // 16.4.4. **RETIRADO en la Fase 3.** Aquí se retomaba `GroupsIdentityPurgeIntent`, la purga del
        // dominio Grupos por cambio de Apple ID que se hubiera diferido. Su armador Y su drenador vivían los
        // dos DENTRO de `SplitSyncManager` (el retome era suyo; solo el call-site estaba aquí), así que el
        // borrado del transporte se lleva el mecanismo entero — no queda una intención sin drenador, queda
        // sin intención: nadie arma ya esa purga. Lo que la motivaba era el boot-guard de identidad iCloud,
        // que también muere con el transporte; el dominio de Grupos del canal vivo se aísla por el `sub` de
        // la sesión Yala, no por el Apple ID del OS. **Declarado como pérdida en el commit 1 de la Fase 3:**
        // un device que se actualice con el intent YA ARMADO en disco no ejecuta esa purga.
        //
        // El commit 2 borró además el TIPO (`GroupsIdentityPurgeIntent.swift`): sin armador, sin drenador y
        // sin un solo call-site, era la familia de `AppAttestClient.ensureRegistered()` — un tipo vivo
        // prometiendo una garantía que nadie ejerce. La key `yala.groups.pendingIdentityPurge` sobrevive
        // en el `UserDefaults` de quien la tuviera armada; es inerte, ya no la lee nadie.

        // 16.4.5. Safety net: hidden groups + removed-self cleanup que el observer pudo perder.
        // Corre ANTES de retryPendingBridges para que el bridge guard `isHiddenForAll` aplique.
        Task { @MainActor in
            guard await awaitPersonalStoreReady() else {
                SaveBreadcrumb.deferred("AppBootstrapper.freezeOrphanedGroups", "import not quiescent")
                return
            }
            await freezeOrphanedGroupsAndRemovedSelves(context: context)
        }

        // 16.4.8. Reconciliar transfer pairs huérfanos (F1 legacy CSV imports + F3 collisions + F5 partner missing).
        // Pure-logic + telemetría. Idempotente — re-launches sin orphans son no-op.
        // Task-wrapped (no sync) para no bloquear cold launch en DBs grandes; downstream steps
        // (16.5 retryPendingBridges, etc.) no dependen del resultado.
        Task { @MainActor in
            guard await awaitPersonalStoreReady() else {
                SaveBreadcrumb.deferred("AppBootstrapper.reconcileTransferPairs", "import not quiescent")
                return
            }
            TransferPairReconcileService.reconcileTransferPairs(in: context)
        }

        // 16.5. Retry bridge operations that failed in a previous launch
        Task { @MainActor in
            await retryPendingBridges(context: context)
        }

        // 16.5.5. Barrido de transacciones/borradores puenteados cuyo gasto o liquidación de grupo ya no
        // existe. DESPUÉS de `retryPendingBridges` en la lista, pero los dos son Tasks independientes y no
        // hay orden garantizado entre ellos — no lo necesitan: el retry CREA puentes que le faltan a un
        // gasto vivo y el barrido solo toca punteros que no resuelven, así que no compiten por ninguna
        // fila. Gateado por quiescencia como el resto de boot-saves del store personal, e idempotente sin
        // sentinel: es también la red que recoge lo que un des-puenteo del sync no llegara a hacer.
        //
        // DOS gates y son de cosas DISTINTAS, por eso van los dos: `awaitPersonalStoreReady` dice que es
        // seguro SALVAR el store personal; `awaitGroupsChannelEvidence` dice que el canal de Grupos ya
        // entregó, que es lo único que convierte «el gasto no está en el store» en «el gasto no existe».
        // Sin el segundo, el barrido corre siempre ANTES del primer pull —`startIfEligible` es síncrono en
        // el paso G2 y su ciclo tarda un viaje de red— y decidiría con el store de Grupos a medio poblar.
        Task { @MainActor in
            guard await awaitPersonalStoreReady() else {
                SaveBreadcrumb.deferred("AppBootstrapper.orphanedBridgedTxSweep", "import not quiescent")
                return
            }
            guard await awaitGroupsChannelEvidence(context: context) else {
                SaveBreadcrumb.deferred("AppBootstrapper.orphanedBridgedTxSweep", "groups channel not fresh")
                return
            }
            OrphanedBridgedTxSweeper.sweep(context: context)
        }

        // 16.5.6. Retirada de los grupos de la era CloudKit (C3): se ocultan y se suelta el puente personal
        // que colgaba de ellos. Su transporte murió en la Fase 3 y desde C4 (`ad291c7f`) ya no puede nacer
        // ninguno más, así que este barrido no puede llevarse un grupo recién creado.
        //
        // UN SOLO gate, y la diferencia con el barrido de arriba no es un descuido: `awaitPersonalStoreReady`
        // hace falta porque esto SALVA el store personal, pero `awaitGroupsChannelEvidence` NO, porque la
        // pregunta es otra. Aquel decide «este gasto no existe», que es una afirmación sobre lo que un canal
        // todavía podría entregar; este decide «esta zona no pertenece a ningún canal vivo», y eso es estable:
        // un grupo del backend lleva `isBackendGroup = true` desde el instante en que su fila existe (las dos
        // ramas de `GroupsSyncClient.applyGroupMeta` y `GroupBackendMembershipService.createGroup`), y un
        // device recién instalado tiene el store de Grupos vacío ⇒ cero zonas ⇒ cero trabajo.
        //
        // Sin orden respecto del barrido de huérfanas, y no hace falta: sus conjuntos de zonas son DISJUNTOS
        // por construcción — aquel excluye las zonas sin canal backend, este actúa solo sobre ellas.
        Task { @MainActor in
            guard await awaitPersonalStoreReady() else {
                SaveBreadcrumb.deferred("AppBootstrapper.legacyGroupsRetirement", "import not quiescent")
                return
            }
            // Fixture B2 (`-uitest-seed dead-pointer`): retire() en ESTE boot nilea
            // splitExpenseID y Mini vería una TX personal (falso verde del AC c).
            // Solo DEBUG + uitest + ese perfil. Release siempre retira. Producto intacto.
            #if DEBUG
            if UITestHooks.isActive, UITestHooks.seedProfile == "dead-pointer" {
                return
            }
            #endif
            LegacyGroupsRetirement.retire(context: context)
        }

        // 16.6. A13: Reconcile current user's displayName across groups.
        // Covers kill-app between acceptShare and performSilentSetup (SplitMember
        // would otherwise stay with the "Usuario" default forever). Idempotent.
        Task { @MainActor in
            guard await awaitPersonalStoreReady() else {
                SaveBreadcrumb.deferred("AppBootstrapper.reconcileCurrentUserDisplayName", "import not quiescent")
                return
            }
            await reconcileCurrentUserDisplayNameIfNeeded()
        }

        // 16.8. Reconciliar join intents pendientes (PendingJoinStore): members de
        // zonas aceptadas cuyo SplitMember no llegó a nacer (kill-app / zona que
        // materializó tarde). El save del ensure comitea el mainContext compartido
        // → gated por quiescencia (patrón retryPendingBridges). Idempotente: si no
        // asienta, el propio reconciler difiere y reintenta en foreground/fetch.
        Task { @MainActor in
            guard await awaitPersonalStoreReady() else {
                SaveBreadcrumb.deferred("AppBootstrapper.groupJoinReconcile", "import not quiescent")
                return
            }
            await GroupJoinReconciler.reconcile(trigger: .boot, context: context)
        }

        // 16.8.6. Batch "salir de todos mis grupos" (D10): reanuda un batch a medio ejecutar (kill-safe). DARK
        // (flag ON) y solo si quedó trabajo no-terminal en el intent persistido. Gateado por QUIESCENCIA (los
        // pasos mutan el mainContext compartido — el orquestador re-gatea por grupo, pero esperamos el import
        // como los demás Tasks de boot).
        if CloudSyncFlags.groupsBackendEnabled && !uiTestActive && GroupBatchLeaveStore.hasUnfinishedWork() {
            Task { @MainActor in
                guard await awaitPersonalStoreReady() else {
                    SaveBreadcrumb.deferred("AppBootstrapper.groupBatchLeaveResume", "import not quiescent")
                    return
                }
                await GroupBatchLeaveOrchestrator.resume(trigger: .boot, context: context)
            }
        }

        // Seed current iCloud user identity for groups and refresh local membership flags.
        // Fase 2 bis: entra por `GroupICloudIdentitySeed` (canal nuevo), NO por la fachada del transporte.
        // Este Task es el ÚNICO camino que puebla la identidad en CADA arranque —el resto la lee— así que
        // atarlo a un símbolo que la Fase 3 borra dejaba la key sin escritor en instalación fresca.
        Task { @MainActor in
            // Best-effort a propósito (era un `try?`, ahora con log dentro del seam): sin iCloud el canal
            // backend sigue resolviendo la identidad por el `sub` de la cuenta Yala.
            await GroupICloudIdentitySeed.seedIfNeededBestEffort()
            guard await awaitPersonalStoreReady() else {
                SaveBreadcrumb.deferred("AppBootstrapper.refreshCurrentUserFlags", "import not quiescent")
                return
            }
            await GroupService.shared.refreshCurrentUserFlags()
        }

        // 16.9. C1 — el registro del consent de Grupos contra la cuenta.
        //
        // Tres cosas en una sola llamada, todas idempotentes y todas no-op sin sesión: adoptar el consent
        // LEGACY de este device (el que vivía en el iKV del Apple ID y nunca llegó a Yala) sellándolo con
        // el `sub`, RETOMAR el intent durable de una aceptación que no consiguió red, y traerse el consent
        // que esta persona ya dio en otro device.
        //
        // SIN `awaitPersonalStoreReady`, al revés que sus vecinos, y no por descuido: aquí no hay ningún
        // `save()` sobre el `mainContext` compartido —es `UserDefaults` y un request— así que el gate de
        // quiescencia no tiene nada que proteger, y esperarlo solo retrasaría el registro (o lo perdería
        // entero en un arranque cuyo import no se asienta, que es justo la cohorte que peor lo lleva).
        Task { @MainActor in
            await GroupsConsentRegistrar.shared.handleSignIn()
        }

        // 17. Initialize Group Notification Service (GC-06)
        GroupNotificationService.shared.setContext(context)

        // 17.5. One-time backfill of SplitShare.groupZoneID for existing shares.
        // D2: gated on the personal first import (same mechanism as the V3 migration / group sync
        // gate) — this save touches the personal mainContext and must not land on a half-imported
        // graph. Idempotent: if the import doesn't settle in time, the sentinel stays unset and it
        // retries next launch.
        Task { @MainActor in
            guard await awaitPersonalStoreReady() else { return }
            migrateShareGroupZoneIDs(context: context)
        }

        // 18. Initialize User Segment Service (GC-08)
        UserSegmentService.shared.setContext(context)
        UserSegmentService.shared.recalculate()

        // 19. Initialize Nudge Service (GC-09)
        NudgeService.shared.setContext(context)

        isInitialized = true

        // Los servicios de Grupos recién recibieron su contexto (paso 16). Una vista de Grupos ya
        // montada (tab inicial de "Solo Grupos") pudo hacer su primer `loadData()` con el contexto
        // aún nil y quedar vacía. Un bump de dataVersion dispara su `.onChange` → recarga con éxito,
        // sin que el usuario tenga que cambiar de tab.
        SessionState.shared.incrementDataVersion()

        #if DEBUG
        if uiTestActive { await applyUITestSeed(context: context) }
        #endif

        // 20. Drain DeferredIntentBuffer: re-submit any RouterIntent that
        // arrived during pre-bootstrap or mid-onboarding.
        RouterEntryGate.shared.drainDeferredBuffer()

        // 21. Recuperar imagen compartida pendiente (share extension → PendingImages/).
        // DEBE correr post-`isInitialized` y DESPUÉS del drain: así `submit(.presentSharedImage)`
        // pasa el gate y encola en AppRouter (el consumer .panel la drena al montarse) en vez
        // de diferirse a un buffer que no serializa el intent. Espeja la red de invites del
        // paso 19. Ver Bugs/qa_cold-launch-share-image-no-registro.
        checkForPendingSharedImage(site: "bootstrap")

        #if DEBUG
        // Trigger del spike device S2 (purga de History en `.icloud` REAL — patrón UITestHooks).
        // NO depende de `syncRuntimeEnabled`: el spike mide si `deleteHistory` sobre el container
        // compartido invalida el token del mirror personal de NSPersistentCloudKitContainer (y el del
        // CKSyncEngine de Grupos) en un device con datos reales. Lo corre el OWNER con el launch arg
        // EXACTO `-spike-s2-purge-history` (guion en el vault). Engine efímero: solo necesita el
        // helper + el corte seguro (outbox vacío en `.icloud` hoy → corte = now).
        if ProcessInfo.processInfo.arguments.contains("-spike-s2-purge-history") {
            let spikeEngine = CloudSyncEngine()
            let purged = spikeEngine.purgeHistoryOnce(context: context)
            logger.notice("Spike S2: purgeHistoryOnce purged=\(purged ?? 0, privacy: .public)")
        }
        #endif
    }

    #if DEBUG
    // MARK: - UI Test Hooks

    /// Aplicado desde `YalaApp.init()` cuando `-uitest`: reset / Pro / skip-onboarding.
    /// Orden: reset (wipe) primero; skip-onboarding re-setea sus flags tras el wipe.
    /// Se invoca antes del primer render para que `hasCompletedOnboarding` ya esté
    /// resuelto cuando ContentView decide qué pantalla mostrar.
    func applyUITestHooksEarly(context: ModelContext) {
        if UITestHooks.shouldReset {
            do {
                try DataWipeService.wipeAllUserData(in: context, reseedInitialData: false, broadcastSignal: false)
            } catch {
                print("UITestHooks: reset error: \(error)")
            }
            // `wipeAllUserData` preserva los modelos de grupos a propósito (el wipe real de
            // Settings no borra grupos compartidos — el usuario los abandona). En uitest sí
            // los limpiamos para aislar corridas: si no, re-sembrar el perfil `.grupos`
            // apilaría grupos duplicados ("Viaje a Cusco" x2) encima del residual.
            DevSeedGroups.reset(in: context)
            // Estado limpio entre tests: el wipe de SwiftData no toca UserDefaults, así que
            // un test que reordena/oculta tabs (TabBarConfigView) contaminaría a los demás.
            // Restaurar el tab bar al default (`[.panel, .statistics, .planning]`).
            UserDefaults.standard.removeObject(forKey: TabBarConfiguration.storageKey)
            // Mismo motivo (UserDefaults sobrevive al wipe): limpiar flags de uitest que
            // contaminarían corridas posteriores con fallos engañosos:
            //  · `expensesOnlyMode` oculta el chip de Ingresos (InsightsTabView) → rompería el
            //    XCUI de clasificación income/expense. Se resetea también la copia YA construida
            //    en SessionState (leída de UserDefaults en su init, antes de este reset).
            //  · `seededGroupIDKey` stale apuntaría a un grupo ya borrado (stale ≠ nil) → el
            //    token `seeded-first` del deep link rutearía a un grupo fantasma.
            SessionDefaults.current.removeObject(forKey: AppPreferences.Keys.expensesOnlyMode)
            SessionState.shared.isExpensesOnlyMode = false
            UserDefaults.standard.removeObject(forKey: UITestHooks.seededGroupIDKey)
            //  · usageFocus (D1): un `.groupsOnly` de una corrida previa reduciría la shell a
            //    solo-Grupos y contaminaría los tests que esperan la app completa (stale ≠ nil).
            UserDefaults.standard.removeObject(forKey: AppPreferences.Keys.usageFocus)
            //  · Remote-config (DIFERIDOS #34): el snapshot/toggle de una corrida manual en el
            //    mismo sim es estado pegajoso de la MISMA clase (los getters ya cortan bajo
            //    uitest — esto es limpieza de cinturón para corridas manuales posteriores).
            #if DEV_BUILD
            UserDefaults.standard.removeObject(forKey: CloudRemoteFlags.debugForceOffKey)
            #endif
            UserDefaults.standard.removeObject(forKey: CloudRemoteConfigStore.snapshotKey)
            //  · Telemetría propia: spool/guard-del-día/one-shots de registro son keys `metrics.*`
            //    pegajosas de `.standard` (misma clase que el snapshot de remote-config). El
            //    servicio NO arranca bajo uitest, pero una corrida manual previa las deja.
            MetricsService.resetLocalState()
            //  · Consent de Grupos (`-uitest-groups-consent`): su snapshot (y las 2 keys del formato
            //    anterior a C1, que un simulador viejo puede seguir teniendo) son UserDefaults de la
            //    MISMA clase pegajosa. Sin esto, una corrida CON el arg dejaría el consent aceptado
            //    para la siguiente, y un test que espera ver el gate de consent pasaría en verde sin
            //    haberlo ejercitado nunca. Se limpian aquí y se re-siembra abajo si el arg viene.
            GroupsConsentState.clear()
            //  · C2 · el latch «este device tuvo sesión de Grupos alguna vez». Es de la MISMA clase
            //    pegajosa y peor: es MONOTÓNICO, así que una sola corrida con `-uitest-fake-cloud-session`
            //    lo arma —el `onAppear` del tab lo hace— y desde ahí TODAS las siguientes verían el empty
            //    state de re-entrada donde debe salir el de alta, en verde y sin haberlo ejercitado. Y lo
            //    heredaría también un arranque manual del simulador.
            UserDefaults.standard.removeObject(forKey: GroupsSessionHistoryMarker.key)
        }
        // M4 · sesión secundaria (M1) determinista, EFÍMERA y sin rastro en disco. Va la PRIMERA de las
        // incondicionales porque no es un estado más: decide el MODO EFECTIVO de todo el proceso
        // (`CloudSyncFlags.storageMode` → `.cloud`) y con él la mitad de los gates que corren debajo.
        // Incondicional —no solo cuando el arg viene— por la misma razón que sus dos vecinos: la purga
        // tiene que correr en TODOS los launches, y aquí más, porque nadie más borra esa key (ni el
        // bloque de reset de arriba ni `DataWipeService`, que excluye `cloudSync.*` a propósito).
        UITestEphemeralDefaults.applySecondarySession(UITestHooks.secondarySession)
        // Estado Pro determinista según el launch arg, EFÍMERO y sin rastro en disco.
        // Va incondicional (no solo bajo `-uitest-reset`): también hay que fijar el estado
        // en los launches con `reset: false`, y la purga tiene que correr en TODOS.
        // Esto era `toggleDevProTier()`, que persistía `dev.forceProTier` y contaminaba al
        // host de unit tests —mismo bundle `.dev`— hasta ponerlo en rojo. El porqué completo
        // está en `StoreKitManager.applyUITestProTier(_:)`.
        StoreKitManager.shared.applyUITestProTier(UITestHooks.forcePro)
        // Onboarding + Welcome Chooser dados por vistos, EFÍMERO y sin rastro en disco. Igual que
        // la línea de arriba, va incondicional: los launches que SÍ quieren ver el onboarding
        // necesitan la purga tanto como estos la necesitan puesta. Esto eran cuatro
        // `UserDefaults.standard.set(true, forKey:)` que persistían y no limpiaba nadie, así que
        // tras cualquier XCUITest abrir la app A MANO en ese simulador saltaba las dos pantallas.
        // El porqué completo está en `UITestEphemeralDefaults`.
        UITestEphemeralDefaults.applyOnboardingAlreadySeen(
            UITestHooks.skipOnboarding || UITestHooks.forceGroupInvite
        )
        // Modo solo-grupos determinista: onboarding saltado (arriba) + onboardingMode=.groupInvite
        // + tab Grupos seleccionado. El init de SessionState no deriva el tab, así que se
        // setea explícitamente (idempotente; no-op en release vía hasArg).
        if UITestHooks.forceGroupInvite {
            OnboardingMode.setCurrent(.groupInvite)
            SessionState.shared.onboardingMode = .groupInvite
            SessionState.shared.selectedMainTab = .groups
        }
        // `-uitest-groups-consent`: consent de Grupos por sembrado DIRECTO de su snapshot local. NO se usa
        // `GroupsConsentRegistrar.register()` a propósito: ese camino arma el intent durable y lanza un
        // request al gateway, y un XCUITest no debe registrar consents contra ninguna cuenta.
        //
        // El snapshot va SIN sellar (`userID: nil`), que es lo correcto y no un atajo: el simulador nunca
        // tiene sesión de nube real —`-uitest-fake-cloud-session` fuerza `hasSession` y deja
        // `currentUserID` en `nil` a propósito, para que el tráfico HTTP siga en CERO— así que no hay `sub`
        // con el que sellarlo. `GroupsConsentDecisionLogic` acepta el snapshot sin sello mientras no haya
        // una sesión que lo CONTRADIGA, que es exactamente este caso. Va DESPUÉS del bloque de reset, que
        // borra el snapshot.
        if UITestHooks.groupsConsentAccepted {
            GroupsConsentState.write(GroupsConsentSnapshot(
                userID: nil, textVersion: GroupsConsentText.version, acceptedAt: Date()))
        }
        // El What's New de la versión corriente se marca visto en todo arranque
        // uitest: con contenido publicado para la versión (WhatsNewConfig), el sheet
        // intercepta el primer tap de cualquier XCUITest post-onboarding.
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        UserDefaults.standard.set(currentVersion, forKey: "lastSeenAppVersion")

        // Adopción del dominio Grupos dada por hecha en uitest: los XCUITests prueban la
        // funcionalidad de Grupos, no el acto de adoptarla, y con el sello del handover puesto un
        // dominio no adoptado deja el bridge cerrado (`GroupsDomainAdoptionLogic.isBridgeAllowed`).
        // EFÍMERO y con purga: esto era un `set(true, forKey:)` que NADIE limpiaba jamás
        // —`removeUserPreferenceKeys` excluye esta key a propósito— así que una sola corrida
        // dejaba Grupos adoptado para siempre en el simulador, también en arranques manuales.
        UITestEphemeralDefaults.applyGroupsBetaUnlocked()

        // Centinela del seed de categorías: purga de lo que dejaron las corridas ANTERIORES. Que
        // esta corrida no lo vuelva a escribir lo garantiza el namespacing por store de
        // `CategorySeedSentinel` — bajo `-uitest` el centinela vivo es otra key, porque el store
        // es otro (`YalaModel-UITest`) y `UserDefaults.standard` no. Sin esto, un arranque manual
        // con el store personal VACÍO hacía early-return y se quedaba sin categorías.
        UITestEphemeralDefaults.purgeCategorySeedSentinel()

        // `-uitest-fake-icloud`: simula cuenta iCloud disponible (+ import asentado) para
        // ejercitar en sim los flujos gated por `isAccountAvailable` (onboarding "Solo
        // grupos", prompts de restore). Debe aplicarse ANTES de `bootstrap()` (este método
        // corre desde `YalaApp.init`) para que el guard del onboarding y los gates de boot
        // lo vean. No habilita CloudKit real (el store uitest es `.none`). La variante
        // standalone `-fake-icloud` (sin `-uitest`, para device-qa agentic) vive en
        // `YalaApp.init` — este método SOLO corre bajo `-uitest`.
        #if DEBUG
        if UITestHooks.fakeICloudAvailable {
            iCloudSyncService.shared._uiTestSimulateAvailableAccount()
        }
        #endif

        // Deep link en cold launch (PRE-init): `-uitest-deeplink-url <url>` entra por
        // `handleIncomingURL` ANTES de que bootstrap ponga `isInitialized` → el intent
        // notification-like se DIFIERE al DeferredIntentBuffer y se re-emite en el drain
        // (bootstrap paso 20), ejercitando el fix del deep link `yala://groups/<id>` perdido
        // en cold launch (`ba8513e5`). El token `seeded-first` se resuelve al id del primer
        // grupo sembrado en una corrida previa (persistido en `seededGroupIDKey`).
        // El scheme se NORMALIZA al del build (`WidgetURLHelper.urlScheme` = `yala` en prod,
        // `yaladev` en Yala Dev): el test no puede conocerlo (corre en otro proceso) y
        // `handleIncomingURL` hace early-return si el scheme no coincide.
        if let raw = UITestHooks.deeplinkURL {
            var resolved = raw
            if let seededID = UserDefaults.standard.string(forKey: UITestHooks.seededGroupIDKey) {
                resolved = resolved.replacingOccurrences(of: "seeded-first", with: seededID)
            }
            #if DEBUG
            if resolved.contains("seeded-first") {
                // Diagnóstico: el token quedó sin resolver (no hay seededGroupID persistido —
                // ¿faltó sembrar 'grupos' en un launch previo?). El deep link no resolverá a un
                // grupo; sin esto el fallo del test sería un timeout opaco en group_members_button.
                print("UITestHooks: -uitest-deeplink-url con token 'seeded-first' pero sin seededGroupID persistido — el deep link no resolverá a un grupo.")
            }
            #endif
            if var components = URLComponents(string: resolved) {
                components.scheme = WidgetURLHelper.urlScheme
                if let url = components.url {
                    handleIncomingURL(url)
                }
            }
        }
    }

    /// Tras `-uitest-reset`, DataWipeService borra `secondaryCurrencies`. El gráfico
    /// del Panel solo monta con al menos una secundaria. USD+EUR basta para Mini.
    /// Ticket: Bugs/qa_cloud-fx-rates-blob-dos-caras.md (F1).
    static func restoreUITestSecondaryCurrencies(into defaults: UserDefaults) {
        defaults.set("USD,EUR", forKey: AppPreferences.Keys.secondaryCurrencies)
    }

    /// Seed de datos UI-test al final del bootstrap + señal `uitest_ready`.
    private func applyUITestSeed(context: ModelContext) async {
        defer { UITestHooks.shared.markReady() }
        // Excluyente con `-uitest-seed-desync`: el seed aleatorio del perfil contaminaría los
        // totales del XCUI de clasificación → si ambos flags están, gana el desync (aislado).
        if let raw = UITestHooks.seedProfile, !UITestHooks.seedDesync {
            let profile = DevSeedProfile(rawValue: raw) ?? .realista
            await DevSeedService().seed(in: context, profile: profile)
            // Tras `-uitest-reset`, DataWipeService borra `secondaryCurrencies` y el
            // gráfico del Panel no monta (empty state). Mismo patrón que skip-onboarding
            // re-setea flags tras el wipe. USD+EUR basta: el seed ya escribe esas tasas.
            // Ticket: Bugs/qa_cloud-fx-rates-blob-dos-caras.md (F1 Mini QA).
            Self.restoreUITestSecondaryCurrencies(into: SessionDefaults.current)
            SessionState.shared.needsExchangeRateWidgetRefresh = true
        }
        // Seed desync AISLADO (excluyente con `-uitest-seed`): 4 TX con signo↔categoría
        // desincronizada para el XCUI de clasificación income/expense por categoría.
        if UITestHooks.seedDesync {
            await DevSeedService().seedDesyncFixtures(
                in: context,
                currencyCode: appPreferences.defaultCurrencyCode.rawValue
            )
        }
        // Deeplink simulado en uitest: encola la navegación al tab destino (el gate la
        // drena cuando el routing esté listo). Ejercita el wiring de tabs ocultos.
        if let dest = uitestDeeplinkDestination() {
            RouterEntryGate.shared.submit(.navigate(dest))
        }
        // InboxAlertModal simulado en uitest: encola `.showInboxAlert` con un payload de
        // muestra (mismo path que el sync real, ver checkInboxDraftsAndNotify) para poder
        // testear el modal sin depender de un evento de CloudKit.
        if UITestHooks.showInboxAlert {
            RouterEntryGate.shared.submit(.showInboxAlert(
                PendingInboxNotification(scheduledPayments: 2, subscriptions: 1, automations: 1)
            ))
        }
        // ProTrialOfferSheet simulado en uitest (escenario paywall + alert en cola).
        if UITestHooks.showTrialOffer {
            RouterEntryGate.shared.submit(.presentTrialOffer)
        }
        // UpdateAvailableBanner simulado en uitest: fuerza el estado sin red.
        if UITestHooks.forceUpdateBanner {
            AppUpdateService.shared.forceUpdateAvailableForUITest()
        }
        // Pantalla de forzado (min-version) simulada en uitest: fuerza el cover terminal sin red.
        if UITestHooks.forceUpdateRequired {
            ForceUpdateGate.shared._forceRequiredForUITest()
        }
        // Consentimiento IA en uitest: destraba la navegación a voz/imagen Pro sin el
        // alert de consentimiento (no graba/transcribe; solo abre la vista).
        if UITestHooks.aiConsent {
            appPreferences.aiDataConsentAccepted = true
        }
        // Pantalla de retención D1 en uitest: arma el cover (con deuda) sin ejecutar el wipe real.
        if UITestHooks.retentionDemo {
            SessionState.shared.groupsRetentionHasDebt = true
            SessionState.shared.groupsRetentionPending = true
        }
    }

    /// Mapea `-uitest-deeplink <target>` a un DeepLinkDestination (solo uitest/DEBUG).
    private func uitestDeeplinkDestination() -> DeepLinkDestination? {
        guard let target = UITestHooks.deeplinkTarget else { return nil }
        switch target {
        case "panel": return .panel
        case "statistics": return .statistics
        case "records": return .recordsStandalone
        case "categories": return .categories
        case "planning": return .planning
        case "budgets": return .budgets
        case "groups": return .groups
        case "inbox": return .inbox
        case "scheduledPayments": return .scheduledPayments
        default: return nil
        }
    }
    #endif

    // MARK: - R4 · swap de persona in-process (quiesce + re-bootstrap)

    /// **Fase de QUIESCE del swap: suelta todas las referencias al container que NO cuelgan de la
    /// jerarquía de vistas.** Desmontar la UI se lleva los 37 ViewModels y los 67 `@Query`; esto se lleva
    /// lo otro — los singletons de proceso, el journal, el canal de Grupos y las cuatro piezas de la
    /// migración, que retienen su `ModelContext` con `let` y por eso se sueltan tirando su dueño entero.
    ///
    /// **Esto NO es «la lista de retenedores», y confundirlo sería repetir el error que el spike R3
    /// refutó.** El spec §1.11 enumeró 62 propiedades y las trató como si cerraran la cuestión; el eje 1c
    /// midió que **una fila `@Model` retenida mantiene vivo el container por sí sola**, así que la lista no
    /// se puede cerrar por inspección y este método no puede garantizar nada. Lo que decide es el canario
    /// de `PersonalSwapReleaseLogic` — esto solo maximiza sus posibilidades de salir verde.
    ///
    /// **El orden importa en un solo punto**: los teardowns del motor personal y del canal de Grupos van
    /// ANTES de soltar sus instancias, para que ningún ciclo en vuelo siga escribiendo sobre un store que
    /// está a punto de borrarse. Los llama el coordinador de sign-out antes de invocar esto; aquí se
    /// repiten por idempotencia, porque este método también tiene que ser correcto si se invoca solo.
    func releaseModelContextsForSwap() {
        // Motores: cortar la generación PRIMERO, soltar la instancia después.
        CloudSyncRuntime.shared?.teardownGuestSession()
        CloudSyncRuntime.releaseSharedForSwap()
        GroupsSyncClient.shared.teardownForSignOut()
        GroupsSyncClient.shared.releaseContextForSwap()
        // Las 4 piezas `let` de la migración se van con su dueño (no son re-inyectables).
        CloudMigrationController.releaseSharedForSwap()
        // Journal + BGTasks.
        BackgroundTaskManager.shared.releaseModelContainerForSwap()
        // Servicios de proceso con contexto inyectado.
        currencyConverter.setContext(nil)
        budgetAlertService.setContext(nil)
        draftService.setContext(nil)
        entityDeletionService.setContext(nil)
        transactionService.setContext(nil)
        ScheduledPaymentNotificationService.shared.setContext(nil)
        NudgeService.shared.setContext(nil)
        UserSegmentService.shared.setContext(nil)
        GroupService.shared.setContext(nil)
        GroupExpenseService.shared.setContext(nil)
        GroupTransactionBridge.shared.setContext(nil)
        GroupNotificationService.shared.setContext(nil)
        // Los dos contextos que alimentan a los observers de proceso (los observers NO se retiran: son
        // por-proceso y leen estas propiedades, que el re-bootstrap repone).
        raceCleanerModelContext = nil
        remoteChangeModelContext = nil
        // Tareas de boot que podrían tocar el contexto viejo tras el remonte.
        remoteChangeTask?.cancel()
        remoteChangeTask = nil
        subscriptionCheckTask?.cancel()
        subscriptionCheckTask = nil
        accountEntitlementTask?.cancel()
        accountEntitlementTask = nil
    }

    /// **Re-ejecuta el arranque completo sobre el container NUEVO tras un swap verificado.**
    ///
    /// Reponer `isInitialized` no es un atajo: tras el wipe el device ESTÁ recién instalado —store vacío,
    /// onboarding y preferencias reseteados— y el arranque que le corresponde es exactamente el de una
    /// instalación fresca, que es este. Lo que hace que sea seguro repetirlo es que los cuatro observers de
    /// `NotificationCenter` se instalan por PROCESO (`lifecycleObserversInstalled`) y no aquí.
    ///
    /// `isBootstrapSettled` se baja a propósito antes de empezar: es el blocker `bootstrapPending` de la
    /// matriz de readiness, y un cover montado con el bootstrap en curso se queda PEGADO (medido en iOS
    /// 27.0). El `defer` de `bootstrap` lo vuelve a subir.
    func rebootstrapAfterSwap(container: ModelContainer) async {
        isInitialized = false
        iCloudMismatchAlreadyDetected = false
        SessionState.shared.isBootstrapSettled = false
        await bootstrap(container: container)
    }

    // MARK: - Exchange Rate Cache Invalidation

    /// Subscribes to `.yalaExchangeRatesUpdated` posted by `ExchangeRateService`
    /// after persisting fresh rates. Invalidates the in-memory cache so
    /// subsequent `convertWithLatestRate` calls read updated data.
    private func observeExchangeRateUpdates() {
        NotificationCenter.default.addObserver(
            forName: .yalaExchangeRatesUpdated,
            object: nil,
            queue: .main
        ) { _ in
            CurrencyConverter.shared.invalidateLatestRatesCache()
        }
    }

    // MARK: - iCloud Mismatch Detection

    private func observeICloudAccountChanges() {
        NotificationCenter.default.addObserver(
            forName: .NSUbiquityIdentityDidChange,
            object: nil,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                AppBootstrapper.shared.checkForICloudMismatch()
            }
        }
    }

    // MARK: - M6: Race Cleaner Hook

    /// Subscribe a `.transactionsImportedFromSync` (cada import successful de CKSync personal).
    /// Dispara `GroupBridgeRaceCleaner` para borrar drafts pendientes Caso A obsoletos —
    /// su TX cuenta real ya llegó vía sync personal, el draft ya no aplica.
    private func observeTransactionsImportedFromSync() {
        NotificationCenter.default.addObserver(
            forName: .transactionsImportedFromSync,
            object: nil,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                guard let context = AppBootstrapper.shared.raceCleanerModelContext else { return }
                _ = GroupBridgeRaceCleaner.cleanupPendingDraftsWithMatchingTX(in: context)
            }
        }
    }

    private var iCloudMismatchAlreadyDetected = false

    private func checkForICloudMismatch() {
        guard !iCloudMismatchAlreadyDetected else { return }

        // R1 (relanzamiento cero): la decisión vive en `SwiftDataConfiguration.shouldOfferICloudRestart`
        // (pura, testeable) e incluye el término R9. Sus dos primeros inputs son testigos de lo que ESTE
        // proceso MONTÓ —no si había cuenta iCloud al arrancar, ni qué modo dice la key AHORA—: esta función
        // corre en cada vuelta a primer plano, y la reversa cambia el modo en caliente sin remontar.
        if SwiftDataConfiguration.shouldOfferICloudRestart(
            mountedDecision: SwiftDataConfiguration.personalStoreMountedDecision,
            mountedWithMirroring: SwiftDataConfiguration.containerWasCreatedWithCloudKit(),
            iCloudAvailableNow: SwiftDataConfiguration.isICloudAvailable()) {
            iCloudMismatchAlreadyDetected = true
            #if DEBUG
            print("AppBootstrapper: iCloud mismatch — container was local, iCloud now available")
            #endif
            // Original guard preserved: don't surface the restart alert while
            // the user is still mid-onboarding (the alert was originally gated
            // by `hasCompletedOnboarding` in the ContentView observer).
            if UserDefaults.standard.bool(forKey: AppPreferences.Keys.hasCompletedOnboarding) {
                RouterEntryGate.shared.submit(.iCloudMismatch)
            }
        }
    }

    // MARK: - Remote Change Observation

    private func observeRemoteStoreChanges() {
        NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: nil,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                let bootstrapper = AppBootstrapper.shared

                // Leading edge: fire immediately on first notification in a burst
                if !bootstrapper.remoteChangeLeadingFired {
                    bootstrapper.remoteChangeLeadingFired = true
                    bootstrapper.sessionState.markRemoteChangePending()
                    IntentSignalBreadcrumb.remoteChangeFired(edge: "leading")
                    #if DEBUG
                    print("AppBootstrapper: Remote CloudKit change — leading edge")
                    #endif
                }

                // Trailing edge: coalesce within 3-second window, then reset
                bootstrapper.remoteChangeTask?.cancel()
                bootstrapper.remoteChangeTask = Task { @MainActor in
                    try? await Task.sleep(for: .seconds(3))
                    guard !Task.isCancelled else { return }
                    bootstrapper.remoteChangeLeadingFired = false
                    bootstrapper.sessionState.markRemoteChangePending()
                    IntentSignalBreadcrumb.remoteChangeFired(edge: "trailing")
                    // Dedup en oleadas: el burst de sync acabó. Gateado por feature flag +
                    // quiescencia (runDedupIfQuiescent decide si la actividad cesó de verdad).
                    if !UserDefaults.standard.bool(forKey: AppPreferences.Keys.subcatDedupRemoteHookDisabled),
                       let ctx = bootstrapper.remoteChangeModelContext {
                        CategoryDeduplicationService.runDedupIfQuiescent(in: ctx)
                    }
                    // Import asentado (3s de quietud): materializar gastos de Apple Pay / dictados de
                    // Siri que se difirieron al abrir con el import activo; refrescar si crearon alguno.
                    if let ctx = bootstrapper.remoteChangeModelContext {
                        let applePayCreated = ApplePayDraftService.processPending(context: ctx)
                        let siriCreated = SiriDraftService.processPending(context: ctx)
                        if applePayCreated > 0 || siriCreated > 0 {
                            bootstrapper.sessionState.incrementDataVersion()
                        }
                    }
                    #if DEBUG
                    print("AppBootstrapper: Remote CloudKit change — trailing edge")
                    #endif
                }
            }
        }
        IntentSignalBreadcrumb.observerRegistered()
    }

    // MARK: - One-Time Migrations

    /// Key persistida (device-global) del contador de DEFERs CONSECUTIVOS del gate de boot-save.
    /// Prefijo `cloudSync.*` → SOBREVIVE los sweeps de sign-out (`DataWipeService.removeUserPreferenceKeys`
    /// es una lista EXPLÍCITA y no lo incluye) — intencional: mide una patología a nivel de DEVICE, no
    /// data de usuario. OJO semántica: los ~8 boot-tasks concurrentes COMPARTEN este contador y sus
    /// resoluciones/DEFERs se interlean (un resolve intercalado lo resetea) → el umbral ≥3 puede
    /// alcanzarse DENTRO de un solo boot y es una señal SUAVE, no un conteo estricto "boot-tras-boot".
    /// Aun así, en H-2026-07-18-8 (todos los boot-saves diferidos para siempre → device semi-funcional)
    /// NINGÚN save resuelve → cero resets → el contador sube sostenido: la firma sigue siendo clara.
    private static let bootSaveDeferCountKey = "cloudSync.quiescenceDeferredBootCount"

    /// Gate for early-boot mainContext saves (retryPendingBridges, migrateShareGroupZoneIDs, y el resto
    /// de los ~8 boot-tasks que pasan por aquí vía `awaitPersonalStoreReady`).
    /// Un `save()` del mainContext personal mientras el import de CloudKit está en curso puede disparar
    /// el `_assertionFailure` interno de SwiftData (trap NO atrapable → crash-loop de restore de iCloud).
    /// Devuelve true cuando es seguro; false → el caller difiere (idempotente, reintenta al próximo
    /// arranque). La decisión (por tick) la resuelve `BootSaveGateLogic.decide` (verdad única testeable)
    /// por TRES caminos, TODOS protegiendo el invariante del restore:
    ///  - sin cuenta → sin mirror CloudKit → no hay grafo a medio importar → seguro.
    ///  - `hasCompletedFirstImport && isImportQuiescent` (fast-path INTACTO) → el import real ocurrió y
    ///    quedó quieto → seguro. Protege el restore genuino: mientras baja (hasObservedImportActivity=true
    ///    pero firstImport aún no), `isImportQuiescent` es false → sigue esperando.
    ///  - EMPTY-STORE (H-8): pasó la gracia de 60s Y jamás se observó `.importEvent` Y está quiescente
    ///    Y NO hay NINGUNA fase `.syncing` en vuelo (`status.isSyncing` — cubre `.setup`/`.exporting`,
    ///    que `isImportQuiescent` no ve). Abre el gate para el store que NADA importa (el fresh-start
    ///    wipe cuyos datos ya están todos en el server → `hasCompletedFirstImport` jamás vuelve a true);
    ///    un store vacío está ocioso, así que el guard extra no reintroduce el hang de H-8. SUPUESTO
    ///    (no garantía) + residual: ver doc de `BootSaveGateLogic.Decision.runEmptyStore` — un restore
    ///    cuyo primer `.import` llega >60s con NADA activo en el tick abriría el gate PRE-import; ese
    ///    save cae sobre el grafo local pre-import, que NO es la condición del crash (el crash es save
    ///    DURANTE import activo sobre grafo a medio importar, device-confirmed 2026-06-22).
    /// El hard-cap de `resolveWaitByQuiescence` se pasa SIEMPRE `false` (dentro de `BootSaveGateLogic`):
    /// promover un ENGINE de grupos export-only al tope es inofensivo, pero forzar un SAVE con un import
    /// genuinamente colgado (`isImporting` → no-quiescente) ES el crash. Por eso el tope total del poll
    /// (120s) solo TERMINA LA ESPERA (→ DEFER), jamás fuerza el save. El `forceFetchAndWait(15s)` inicial
    /// cuenta hacia la gracia de 60s (medida desde la entrada de la función).
    private func awaitPersonalImportForBootSave() async -> Bool {
        let start = Date()
        let noImportGrace: TimeInterval = 60
        let totalPollCap: TimeInterval = 120
        let pollInterval: TimeInterval = 2

        func gateDecision() -> BootSaveGateLogic.Decision {
            BootSaveGateLogic.decide(
                isAccountAvailable: iCloudSyncService.shared.isAccountAvailable,
                hasCompletedFirstImport: iCloudSyncService.shared.hasCompletedFirstImport,
                hasObservedImportActivity: iCloudSyncService.shared.hasObservedImportActivity,
                isQuiescent: iCloudSyncService.shared.isImportQuiescent,
                // El forceFetchAndWait(15s) inicial YA transcurrió cuando llegamos al poll → cuenta
                // hacia la gracia porque medimos elapsed desde `start`.
                noImportGraceElapsed: Date().timeIntervalSince(start) >= noImportGrace,
                // `status.isSyncing` = CUALQUIER fase `.syncing` (setup/importing/exporting) —
                // endurece el escape empty-store contra un `.setup` largo que `isImportQuiescent`
                // no ve (solo chequea `.syncing(.importing)`).
                isSyncingAnyPhase: iCloudSyncService.shared.status.isSyncing
            )
        }

        // 1) Esperar el primer import (restore lento). Estos ≤15s cuentan hacia la gracia de 60s.
        if MigrationGateLogic.shouldWaitForCloudKit(
            isAccountAvailable: iCloudSyncService.shared.isAccountAvailable,
            hasCompletedFirstImport: iCloudSyncService.shared.hasCompletedFirstImport
        ) == .waitForHook {
            _ = await iCloudSyncService.shared.forceFetchAndWait(timeout: 15)
        }

        // 2) Poll hasta que el gate resuelva .run o se agote el tope total (→ DEFER, jamás forzar).
        //    Un import genuinamente colgado mantiene `isQuiescent=false` → nunca resuelve → DEFER al tope.
        while gateDecision() == .wait && Date().timeIntervalSince(start) < totalPollCap {
            try? await Task.sleep(for: .seconds(pollInterval))
        }

        let decision = gateDecision()
        recordBootSaveGateOutcome(decision)
        return decision.isRun
    }

    /// Visibilidad de H-8 (dirección d del owner): contador persistido device-global de DEFERs
    /// consecutivos + breadcrumb con snapshot para desambiguar en Console el sub-modo
    /// (ningún-import vs import-colgado). Canario a los ≥3 (una vez por proceso vía `canaryOnce`).
    /// El ≥3 es señal SUAVE: los ~8 call-sites concurrentes comparten el contador y puede alcanzarse
    /// dentro de UN solo boot (ver doc de `bootSaveDeferCountKey`) — el canario dice "varios boot-saves
    /// difirieron sin que nada resolviera entremedio", no "N boots consecutivos rotos".
    /// Espeja el `cloudkitGroupSyncNoImportPromote` de grupos para la rama empty-store.
    private func recordBootSaveGateOutcome(_ decision: BootSaveGateLogic.Decision) {
        let defaults = UserDefaults.standard
        let key = Self.bootSaveDeferCountKey

        guard decision.isRun else {
            // DEFER real (agotó el tope). Incrementa el contador consecutivo device-global.
            let count = defaults.integer(forKey: key) + 1
            defaults.set(count, forKey: key)
            let observedActivity = iCloudSyncService.shared.hasObservedImportActivity
            let isImporting = iCloudSyncService.shared.status.isImporting
            logger.notice("boot-save gate DEFERRED (consecutive=\(count, privacy: .public)) hasObservedImportActivity=\(observedActivity, privacy: .public) isImporting=\(isImporting, privacy: .public)")
            if count >= 3 {
                MetricsService.canaryOnce(
                    .cloudBootSaveDeferredRepeatedly,
                    key: "boot",
                    detail: "activity=\(observedActivity)|importing=\(isImporting)",
                    value: Double(count)
                )
            }
            return
        }

        // Resolvió → red sana: resetea el contador consecutivo.
        if defaults.integer(forKey: key) != 0 { defaults.set(0, forKey: key) }
        if decision == .runEmptyStore {
            // Espejo del `cloudkitGroupSyncNoImportPromote` de grupos: el gate abrió porque NINGÚN import
            // apareció dentro de la gracia (store vacío / fresh-start wipe), no porque el import se asentara.
            logger.notice("boot-save gate resolved via empty-store escape (no personal import appeared within grace)")
        }
    }

    /// Wrapper de "el store personal está listo para un boot-save", enrutado por `StorageMode` (I9, R2).
    /// En `.icloud` (SIEMPRE hoy) DELEGA 1:1 a `awaitPersonalImportForBootSave` → cero cambio de
    /// comportamiento. En `.cloud` (I10/I11) espera al motor: primer pull asentado + apply quieto
    /// (`SyncQuiescenceCoordinator`). Los call-sites internos de boot-save llaman a ESTE wrapper para que
    /// la coexistencia futura no exija tocarlos de nuevo. `awaitPersonalImportForBootSave` se mantiene
    /// (lo llama el wrapper).
    private func awaitPersonalStoreReady() async -> Bool {
        switch StorageModeSignalRouter.quiescenceSource(mode: CloudSyncFlags.storageMode) {
        case .icloudImport:
            return await awaitPersonalImportForBootSave()
        case .cloudEngine:
            // El motor Modo Nube es la autoridad. Espera el primer pull asentado + apply quieto, con el
            // mismo tope/poll que el import de CloudKit (idempotente: el caller difiere si no asienta).
            let coordinator = SyncQuiescenceCoordinator.shared
            func safe() -> Bool { coordinator.hasCompletedFirstPull && coordinator.isPersonalApplyQuiescent }
            var waited: TimeInterval = 0
            let pollInterval: TimeInterval = 2
            let quiescenceHardCap: TimeInterval = 120
            while !safe() && waited < quiescenceHardCap {
                do {
                    try await Task.sleep(for: .seconds(pollInterval))
                } catch {
                    // Task cancelado: NO busy-spinear el resto del cap — devolver el valor conservador
                    // (el caller difiere; regla "nunca try? que silencia").
                    return false
                }
                waited += pollInterval
            }
            return safe()
        }
    }

    /// Espera acotada a que el canal de Grupos dé EVIDENCIA de haber entregado, antes de dejar barrer
    /// huérfanas. Molde de `CloudSessionSignOut.awaitPersonalQuiescenceForGroupsSignOut` (poll 2 s,
    /// hard-cap, fail-CERRADO en cancelación).
    ///
    /// **Por qué hace falta esperar y no basta con preguntar.** El gate de frescura
    /// (`GroupChannelFreshnessGate`) exige que el canal haya agotado su entrega, y en el arranque eso aún no
    /// ha pasado: `GroupsSyncClient.startIfEligible` corre SÍNCRONO en el paso G2 pero su primer
    /// `syncCycleOnce` incluye un viaje de red, y los engines de CloudKit arrancan export-only hasta que el
    /// import personal se asienta. Preguntar sin esperar daría «no fresco» en TODOS los arranques y el
    /// barrido no repararía nunca nada — que es la forma de romperlo sin que ningún test se ponga rojo.
    ///
    /// **Sale en cuanto ALGUNA zona es fresca**, no cuando lo son todas: el barrido decide por zona, así que
    /// una zona rezagada no debe retener la limpieza de las demás — se queda para el próximo arranque.
    ///
    /// Agotar el tope devuelve `false` y NO barre: perder una limpieza es reversible, destruir una
    /// transacción no. Con el canal apagado (kill-switch, sesión caducada, snapshot de remote-config
    /// ausente) esto es lo que ocurre en cada arranque, y es el comportamiento correcto; el canario
    /// `bridgedTxOrphanSweepDeferred` lo hace visible cuando además había candidatas.
    private func awaitGroupsChannelEvidence(context: ModelContext) async -> Bool {
        let pollInterval: TimeInterval = 2
        let hardCap: TimeInterval = 60

        // Sin nada puenteado no hay nada que esperar: el barrido sale en su primer guard. Se mide UNA vez
        // (el bridge no crea filas mientras esperamos sin que el canal haya entregado, que es justo la
        // condición que estamos esperando).
        do {
            let txs = try context.fetchCount(FetchDescriptor<TransactionItem>(
                predicate: #Predicate { $0.splitExpenseID != nil || $0.splitSettlementID != nil }))
            let drafts = try context.fetchCount(FetchDescriptor<InboxDraft>(
                predicate: #Predicate { $0.splitExpenseID != nil || $0.splitSettlementID != nil }))
            if txs == 0 && drafts == 0 { return true }
        } catch {
            #if DEBUG
            print("AppBootstrapper: conteo de filas puenteadas falló: \(error)")
            #endif
            // El barrido hace sus propios fetches y aborta si fallan — dejarle decidir a él.
            return true
        }

        func anyZoneIsFresh() -> Bool {
            GroupChannelFreshness.verdictsByZone(context: context).values.contains { $0.isFresh }
        }

        var waited: TimeInterval = 0
        while !anyZoneIsFresh() && waited < hardCap {
            do {
                try await Task.sleep(for: .seconds(pollInterval))
            } catch {
                return false  // Task cancelado → conservador (regla "nunca try? que silencia").
            }
            waited += pollInterval
        }
        return anyZoneIsFresh()
    }

    private func migrateShareGroupZoneIDs(context: ModelContext) {
        let migKey = "Yala_SplitShareGroupZoneID_v1"
        guard !UserDefaults.standard.bool(forKey: migKey) else { return }
        do {
            let unsetZoneID = ""
            let desc = FetchDescriptor<SplitShare>(predicate: #Predicate { $0.groupZoneID == unsetZoneID })
            let orphans = try context.fetch(desc)
            guard !orphans.isEmpty else {
                UserDefaults.standard.set(true, forKey: migKey)
                return
            }
            let expenses = try context.fetch(FetchDescriptor<SplitExpense>())
            // `uniquingKeysWith` evita un trap fatal si CloudKit sync trae dos
            // SplitExpense con el mismo `id` (UUID sin @Attribute(.unique) por compat).
            let lookup = Dictionary(expenses.map { ($0.id, $0.groupZoneID) },
                                    uniquingKeysWith: { first, _ in first })
            for share in orphans {
                if let zone = lookup[share.expenseID], !zone.isEmpty {
                    share.groupZoneID = zone
                }
            }
            SaveBreadcrumb.willSave("AppBootstrapper.migrateShareGroupZoneIDs")
            try context.save()
            SaveBreadcrumb.didSave("AppBootstrapper.migrateShareGroupZoneIDs")
            UserDefaults.standard.set(true, forKey: migKey)
            #if DEBUG
            print("AppBootstrapper: Backfilled groupZoneID for \(orphans.count) SplitShare records")
            #endif
        } catch {
            #if DEBUG
            print("AppBootstrapper: SplitShare migration failed: \(error) — will retry next launch")
            #endif
        }
    }

    /// Retries pending bridge operations from previous launches.
    /// Bound by `maxAttempts` per expense and `maxPerLaunch` total to keep cold-launch latency capped.
    /// Silent on retry-fail (the user already saw an alert at the original failure);
    /// flag stays true for the next launch until `maxAttempts` is exhausted.
    @MainActor
    func retryPendingBridges(context: ModelContext) async {
        // El bridge crea TransactionItems personales y guarda el mainContext — diferir hasta que el
        // import personal esté QUIESCENTE (`awaitPersonalImportForBootSave` espera el primer import + la
        // ventana de quietud, no solo el primer evento), para que el `save()` no caiga sobre un grafo a
        // medio importar (`_assertionFailure`). Idempotente: `bridgePending` queda true y reintenta al
        // próximo arranque si el import no se asentó.
        guard await awaitPersonalStoreReady() else {
            logger.notice("retryPendingBridges deferred — personal import not quiescent")
            return
        }
        // Gate de dominio (handover): con Grupos cerrado en este dispositivo la cola NO se toca —
        // ni se bridgea ni se consumen `bridgeAttempts`. Los flags `bridgePending` quedan intactos
        // y la cola se drena entera el día que el usuario abra Grupos (idempotente, mismo
        // contrato que el diferido por quiescencia de arriba). El corte duro vive en
        // `GroupTransactionBridge.bridgeExpense`; esto solo evita quemar los 3 intentos contra
        // una puerta cerrada.
        guard GroupTransactionBridge.isDomainOpenForBridge() else {
            logger.notice("retryPendingBridges skipped — groups domain sealed for a new user on this device")
            return
        }

        // Caso REMOTO, antes de la cola del Caso A: gastos y liquidaciones que bajaron por sync —por
        // CUALQUIERA de los dos canales, CloudKit y backend— y cuyo bridge no llegó a ocurrir (el proceso
        // murió en la ventana del import, o el bridge lanzó). Su intención NO puede vivir en una fila
        // —marcarla exige el `save()` que esa ventana prohíbe— así que vive en `GroupsPendingBridgeIntent`
        // y se retoma aquí, DENTRO de esta función y no en un Task hermano: los Tasks de boot resuelven su
        // gate cada uno por su cuenta, y uno que llegara después del fetch de abajo retrasaría el bridge un
        // arranque entero. Hereda los dos gates de arriba, que es justo lo que necesita (el bridge salva el
        // mainContext compartido).
        //
        // El `onBridged` ponía al día el camino rápido en memoria del transporte CloudKit. La Fase 3 se
        // llevó ese argumento y el retome sigue en pie, que es exactamente lo que su diseño prometía.
        GroupsPendingBridgeResume.resumeIfNeeded(context: context)

        let descriptor = FetchDescriptor<SplitExpense>(
            predicate: #Predicate { $0.bridgePending == true }
        )
        do {
            let pending = try context.fetch(descriptor)
            guard !pending.isEmpty else { return }

            // Reset one-time de bridgeAttempts para los gastos ya marcados pendientes ANTES del
            // fix de resolución de subcategorías de sistema por idioma: un usuario pudo agotar
            // los 3 intentos reabriendo la app, dejando el gasto sin reintentar pese a que ahora
            // sí se puede resolver. El flag se persiste SOLO tras el `save()` exitoso (abajo), para
            // que un fallo de save no consuma el reset sin haberlo aplicado.
            let attemptsResetFlagKey = "didResetBridgeAttemptsForLocaleFixV1"
            let didResetAttempts = !UserDefaults.standard.bool(forKey: attemptsResetFlagKey)
            if didResetAttempts {
                for expense in pending { expense.bridgeAttempts = 0 }
                logger.info("One-time bridgeAttempts reset (locale-fix) for \(pending.count, privacy: .public) pending expenses")
            }

            let maxAttempts = 3
            let maxPerLaunch = 20
            let batch = Array(pending.prefix(maxPerLaunch))
            logger.info("Retrying bridge for \(batch.count, privacy: .public) of \(pending.count, privacy: .public) pending expenses")

            for expense in batch {
                guard expense.bridgeAttempts < maxAttempts else {
                    logger.error("Bridge retry exhausted for expense \(expense.id, privacy: .public) after \(expense.bridgeAttempts, privacy: .public) attempts")
                    continue
                }

                let zoneID = expense.groupZoneID
                let groupDescriptor = FetchDescriptor<SplitGroup>(
                    predicate: #Predicate { $0.cloudKitZoneID == zoneID }
                )
                guard let group = try context.fetch(groupDescriptor).first else {
                    logger.error("Bridge retry: group not found for expense \(expense.id, privacy: .public)")
                    continue
                }

                expense.bridgeAttempts += 1
                do {
                    // shouldSave:false — save once at the end of the loop instead of
                    // per-expense to avoid N widget rebuilds + N budget checks on launch.
                    // M6: isRemoteSync=true porque el retry no tiene cuenta del user en memoria.
                    // Si Caso A `.full/.completed` y no hay TX real previa: crea draft con hint.
                    try GroupTransactionBridge.shared.bridgeExpense(
                        expense,
                        in: group,
                        accountForCurrentUser: nil,
                        isRemoteSync: true,
                        shouldSave: false
                    )
                    expense.bridgePending = false
                    expense.bridgeAttempts = 0
                } catch {
                    logger.error("Bridge retry failed for \(expense.id, privacy: .public) (attempt \(expense.bridgeAttempts, privacy: .public)): \(error.localizedDescription, privacy: .public)")
                }
            }
            SaveBreadcrumb.willSave("AppBootstrapper.retryPendingBridges")
            try context.save()
            SaveBreadcrumb.didSave("AppBootstrapper.retryPendingBridges")
            // Marca el reset one-time como hecho solo tras persistir (save exitoso arriba).
            if didResetAttempts {
                UserDefaults.standard.set(true, forKey: attemptsResetFlagKey)
            }
        } catch {
            logger.error("retryPendingBridges fetch failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Boot-time safety net para grupos hidden + removed-self que perdieron el observer
    /// del sync engine (app cerrada al momento del fetch remoto). Idempotente:
    /// `freezeForSoftDelete` y `performRemovedSelfCleanup` son no-op si ya están limpios.
    @MainActor
    func freezeOrphanedGroupsAndRemovedSelves(context: ModelContext) async {
        // 1) Hidden groups: dispara freezeForSoftDelete para preservar rastro financiero.
        do {
            let hiddenGroups = try context.fetch(FetchDescriptor<SplitGroup>(
                predicate: #Predicate { $0.isHiddenForAll == true }
            ))
            for group in hiddenGroups {
                if GroupTransactionBridge.shared.isReady {
                    do {
                        try GroupTransactionBridge.shared.freezeForSoftDelete(group: group)
                    } catch {
                        #if DEBUG
                        logger.error("freezeOrphanedGroups: freezeForSoftDelete failed for \(group.cloudKitZoneID, privacy: .public): \(error.localizedDescription, privacy: .public)")
                        #endif
                    }
                }
            }
        } catch {
            #if DEBUG
            logger.error("freezeOrphanedGroups: hidden fetch failed: \(error.localizedDescription, privacy: .public)")
            #endif
        }

        // 2) Removed-self: current user con status=.removed → flow simétrico a leaveGroup.
        do {
            let removedRaw = SplitMemberStatus.removed.rawValue
            let removedSelfMembers = try context.fetch(FetchDescriptor<SplitMember>(
                predicate: #Predicate { $0.isCurrentUser == true && $0.status == removedRaw }
            ))
            for member in removedSelfMembers {
                await GroupService.shared.performRemovedSelfCleanup(zoneName: member.groupZoneID)
            }
        } catch {
            #if DEBUG
            logger.error("freezeOrphanedGroups: removed-self fetch failed: \(error.localizedDescription, privacy: .public)")
            #endif
        }
    }

    /// A13: Reconcile current user's `displayName` across all SplitMembers if a real
    /// name was already set (UserDefaults `userName`) but a previous onboarding flow
    /// was interrupted (e.g. kill-app between `acceptShare` and `performSilentSetup`).
    /// Idempotent — `updateCurrentUserDisplayName` is a no-op when nothing differs.
    @MainActor
    func reconcileCurrentUserDisplayNameIfNeeded() async {
        let realName = (SessionDefaults.current.string(forKey: AppPreferences.Keys.userName) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !realName.isEmpty else { return }

        do {
            try await GroupService.shared.updateCurrentUserDisplayName(realName)
        } catch {
            logger.error("Reconcile displayName failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Scene Phase Handlers

    /// Skips the first `.active` (that's the cold launch, already covered by appLaunched);
    /// subsequent ones are genuine warm resumes.
    private var hasSeenInitialActive = false

    /// Llamar cuando la app se activa (scenePhase == .active)
    func handleBecameActive(context: ModelContext) {
        // H4 (S2 del review): con el wipe de sign-out ARMADO (sesión cerrada, esperando
        // relaunch) NADA debe escribir en el store — el boot siguiente lo BORRA y el
        // runtime ya está muerto (nadie pushearía lo escrito). Congela los drains de
        // intents App Group (Apple Pay/Siri), reconciles y demás side-effects de
        // foreground. Las colas App Group NO se consumen aquí: el boot-cleanup las PURGA
        // (`AppGroupInboundPurge`, ver su header) para que no se materialicen en la cuenta
        // siguiente — no las conserva para drenarlas tras el relanzamiento.
        guard !StorageModePersistence.isSignOutWipeArmed() else { return }
        // M1: mismo freeze para el wipe SECUNDARIO armado (store condenado) y para la
        // VENTANA DE ENTRADA (descriptor activo con el store del DUEÑO montado — los drains
        // materializarían pendientes en el store del dueño pre-relaunch).
        guard !SecondarySessionStore.isWipeArmed() else { return }
        if SecondarySessionStore.isActive() && !SwiftDataConfiguration.secondaryStoreMounted { return }

        // Warm start: ping diario (dedup por día UTC — solo el primero del día encola)
        // + drain del spool de canarios pendientes (offline previo / kill).
        if hasSeenInitialActive {
            MetricsService.dailyActivePingIfNeeded()
        } else {
            hasSeenInitialActive = true
        }

        // Apply any pending remote CloudKit changes on foreground resume
        sessionState.applyPendingChangesIfNeeded()

        // Modo Nube runtime (I9, DARK): dispara un ciclo inmediato / re-evalúa stop-states. Inerte con
        // el flag apagado (y sin `shared` asignado, que solo lo pone el wiring del paso 14.7).
        if CloudSyncFlags.syncRuntimeEnabled {
            CloudSyncRuntime.shared?.handleBecameActive()
        }

        // H-2026-07-18-4 (DARK): re-arranque del canal de Grupos → backend si su loop propio murió en
        // silencio (401 transitorio en la ventana de expiry → sessionExpired → break loop; el startIfEligible
        // solo corría en cold boot y NADA lo re-arrancaba hasta relaunch). Mismo gate que el call-site del
        // cold boot (appLaunched paso G2). Idempotente por single-instance (loopTask != nil ⇒ no-op) y
        // D8-safe por el guard de mount-mismatch de startIfEligible. Con el flag OFF es NO-OP TEMPRANO
        // (startIfEligible retorna en su primer guard flag+sesión) → byte-idéntico a producción hoy.
        if !UITestHooks.isActive
            && (CloudSyncFlags.groupsBackendEnabled || !SecondarySessionStore.isActive()) {
            GroupsSyncClient.shared.startIfEligible(context: context, trigger: "foreground")
        }

        // Modo Nube auth (I7c, mitigación #23): re-chequea la credencial de Apple al foreground; si fue
        // revocada, cierra la sesión local. Desde D-R1 paso 1 el guard `isConfigured` pasa también en
        // producción, así que `.shared` se instancia; sin sign-in previo es un no-op (no hay appleUserID
        // capturado). Sin side-effects fuera de eso.
        if CloudBackendConfig.isConfigured {
            Task { await CloudAuthService.shared.refreshCredentialStateIfNeeded() }
        }

        // #36 (H1 corrida I14): re-kick de una migración/reversa APARCADA — el resume de boot era
        // one-shot (quiescencia vencida o push transient a mitad de página → aparcada EN SILENCIO
        // hasta tocar "Retomar"). Corre DESPUÉS de los freeze-guards de la cabecera (sign-out wipe /
        // wipe secundario / ventana de entrada M1) y decide por pure-logic (`MigrationForegroundRekick`,
        // no-op puro con fase estable). En producción `shared` ya existe (D-R1 paso 1), pero la fase de
        // todo el parque de 2.x es `notStarted` ⇒ sigue siendo no-op.
        if CloudBackendConfig.isConfigured {
            Task { await CloudMigrationController.shared?.rekickIfParked() }
        }

        // Check if iCloud became available after container was created without it
        checkForICloudMismatch()

        // Re-verify subscription status on foreground resume
        subscriptionCheckTask?.cancel()
        subscriptionCheckTask = Task {
            await refreshSubscriptionStatus()
        }

        // Process due scheduled payments (creates inbox drafts for warm resume)
        // Throttle: skip if bootstrap just ran (< 30 seconds ago) to prevent duplicate drafts
        let shouldProcessPayments = Date.now.timeIntervalSince(lastProcessDuePaymentsDate) > 30.0
        if shouldProcessPayments {
            processDueScheduledPayments(context: context)
        }
        // Materializar gastos de Apple Pay / dictados de Siri encolados por sus intents; refrescar
        // UI si crearon alguno (Bandeja/Registros reaccionan a `dataVersion`).
        let applePayCreated = ApplePayDraftService.processPending(context: context)
        let siriCreated = SiriDraftService.processPending(context: context)
        if applePayCreated > 0 || siriCreated > 0 {
            sessionState.incrementDataVersion()
        }
        // Refrescar la caché de contexto del intent de Siri (subcategorías/divisa/cuentas).
        SiriIntentContextCache.refresh(context: context, defaultCurrency: appPreferences.defaultCurrencyCode.rawValue)
        // Espeja el gate de bootstrap (paso del check inicial): en UITest el
        // alert de inbox solo se dispara vía el hook explícito -uitest-inbox-alert.
        // La re-emisión del hook aquí es load-bearing: el intent es transient y
        // la emisión temprana del bootstrap puede caer en un blip de scenePhase
        // (resetTransients) antes del primer drain — dedup por id cubre duplicados.
        if UITestHooks.isActive {
            if UITestHooks.showInboxAlert {
                RouterEntryGate.shared.submit(.showInboxAlert(
                    PendingInboxNotification(scheduledPayments: 2, subscriptions: 1, automations: 1)
                ))
            }
            if UITestHooks.showTrialOffer {
                RouterEntryGate.shared.submit(.presentTrialOffer)
            }
        } else {
            checkForPendingInboxDrafts(context: context)
        }

        checkForPendingControlAction()

        // Recuperar imagen compartida pendiente al volver a foreground (imagen compartida con
        // la app en background, o re-presentación si un intento previo se interrumpió). El gate
        // exige `isInitialized`, así que un `.active` temprano que racee con bootstrap no hace
        // nada aquí (el paso 21 de bootstrap lo cubre).
        checkForPendingSharedImage(site: "becameActive")

        // Drain buffered intents (notif taps that arrived mid-onboarding
        // while app was foregrounded but blocked).
        RouterEntryGate.shared.drainDeferredBuffer()

        // Skip notification checks if bootstrap just ran (< 5 seconds ago)
        let shouldCheckNotifications = Date.now.timeIntervalSince(lastNotificationCheckDate) > 5.0

        if shouldCheckNotifications {
            Task {
                // Reintento del flip one-shot si el boot lo difirió por quiescencia del import
                // (restore de iCloud): sin este pass, esperaría hasta el próximo cold launch.
                ScheduledPaymentNotificationService.flipMasterToggleIfNeeded(context: context)
                await ensureNotificationsScheduled(context: context)
                await ReportNotificationService.shared.sendDueReports(context: context)
            }
        }
    }

    // MARK: - Control Center Action Handling

    /// App Group identifier from shared helper.
    private var appGroupID: String { WidgetURLHelper.appGroupIdentifier }

    /// Checks for and processes pending Control Center widget actions
    private func checkForPendingControlAction() {
        #if DEBUG
        print("AppBootstrapper: Checking for pending Control Center action in App Group: \(appGroupID)")
        #endif

        guard let defaults = UserDefaults(suiteName: appGroupID) else {
            #if DEBUG
            print("AppBootstrapper: Could not access App Group UserDefaults")
            #endif
            return
        }

        guard let action = defaults.string(forKey: "pendingControlAction") else {
            #if DEBUG
            print("AppBootstrapper: No pending Control Center action found")
            #endif
            return
        }

        // Clear the action immediately to prevent re-processing
        defaults.removeObject(forKey: "pendingControlAction")
        defaults.synchronize()

        #if DEBUG
        print("AppBootstrapper: Processing Control Center action: \(action)")
        #endif

        switch action {
        case "panel":
            setOrDeferDeepLink(.panel)
        case "voice-entry":
            executeAction(.voiceEntry)
        case "image-entry":
            executeAction(.imageEntry)
        default:
            #if DEBUG
            print("AppBootstrapper: Unknown Control Center action: \(action)")
            #endif
        }
    }

    /// Enqueues a panel-action intent, respecting feature toggles and Pro gates.
    /// Router handles readiness gating — intents queued while splash/wipe
    /// active drain automatically when consumers become ready.
    private func executeAction(_ action: PanelAction) {
        switch action {
        case .newTransaction:
            RouterEntryGate.shared.submit(.presentNewTransaction)
        case .voiceEntry:
            guard FeatureGateService.shared.canAccess(.voiceInput) else {
                RouterEntryGate.shared.submit(.presentUpgradeSheet(.voice))
                return
            }
            if SessionDefaults.current.bool(forKey: AppPreferences.Keys.aiDataConsentAccepted) {
                RouterEntryGate.shared.submit(.presentVoiceEntry)
            } else {
                RouterEntryGate.shared.submit(.requestAIConsent(.voice))
            }
        case .imageEntry:
            guard FeatureGateService.shared.canAccess(.imageInput) else {
                RouterEntryGate.shared.submit(.presentUpgradeSheet(.image))
                return
            }
            if SessionDefaults.current.bool(forKey: AppPreferences.Keys.aiDataConsentAccepted) {
                RouterEntryGate.shared.submit(.presentImageEntry)
            } else {
                RouterEntryGate.shared.submit(.requestAIConsent(.image))
            }
        }
    }

    /// Llamar cuando cambia needsExchangeRateReload
    func handleExchangeRateReloadRequest(container: ModelContainer) async {
        guard sessionState.needsExchangeRateReload else { return }
        await loadExchangeRates(context: container.mainContext)
        sessionState.needsExchangeRateReload = false
    }

    // MARK: - Unified shortcutID + CSV Mirror Migration (V3)

    /// Regenera UUIDs en `Account.shortcutID`, `Subcategory.shortcutID` y `Tag.id`,
    /// y rehidrata los CSV mirrors de Budget/TransactionItem/InboxDraft/FavoritePayment/
    /// ScheduledPayment desde M2M — todo en una sola save atómica.
    ///
    /// Estrategia por field:
    /// - `Tag.id` sin historia de persistencia confiable → regeneramos TODOS.
    ///   La heurística por duplicados falla con count==1 (UUID volátil pero único).
    /// - `Account.shortcutID` / `Subcategory.shortcutID` pueden tener UUIDs
    ///   estables sincronizados cross-device → heurística por duplicados preserva
    ///   los únicos (mantiene Atajos guardados).
    ///
    /// CSV mirrors:
    /// - M2M no-nil → encode UUIDs y escribir CSV (fresh state).
    /// - M2M nil (lazy hydration en curso) → nuke CSV stale + `sawRace=true`
    ///   para que el sentinel NO se marque y el próximo launch reintente.
    ///
    /// Atomicidad: si `save()` throwea, sentinel no se toca → próximo launch
    /// reintenta limpio. Si `sawRace=true`, sentinel tampoco se toca.
    ///
    /// Retry: el backfill CSV tiene cap `maxAttempts=5`; tras 5 launches con race
    /// persistente, el sentinel principal se marca igual y el resto queda al
    /// auto-heal lazy de `resolvedXIDs(scheduleBackfill: true)`. Esto evita el
    /// caso patológico donde una M2M `nil` permanente forzaría a `regenerateAllUUIDs`
    /// a reasignar Tag.id en cada cold launch indefinidamente (rompiendo Atajos
    /// cross-device). La regen tiene su propio sentinel `appEntityShortcutIDsRegeneratedV3`
    /// que se marca tras el primer save exitoso, independiente del race del backfill.
    private func migrateShortcutIDsAndRebuildCSVMirrors(
        context: ModelContext,
        waitedForSync: Bool,
        importSettled: Bool,
        waitDuration: TimeInterval
    ) {
        let sentinelKey = AppPreferences.Keys.appEntityShortcutIDsMigratedV3
        let regenKey = AppPreferences.Keys.appEntityShortcutIDsRegeneratedV3
        let attemptsKey = AppPreferences.Keys.appEntityShortcutIDsBackfillAttemptsV3
        let maxAttempts = 5
        guard !UserDefaults.standard.bool(forKey: sentinelKey) else { return }
        // Si esperamos el primer import de CloudKit pero hizo timeout, los records pueden
        // estar incompletos → diferir (retry next launch). Regenerar sobre datos parciales y
        // marcar el sentinel es irrecuperable: el sentinel bloquea re-runs, y los records que
        // lleguen después quedan con el UUID colapsado sin sanar. Backstop repetible:
        // `CategoryDeduplicationService.repairCollapsedIdentityUUIDs`; el backfill diferido lo
        // cubre el auto-heal lazy de CSV.
        guard !MigrationGateLogic.shouldDeferMigration(waitedForSync: waitedForSync, importSettled: importSettled) else {
            #if DEBUG
            print("AppBootstrapper: migrateShortcutIDsAndRebuildCSVMirrors deferred — CloudKit import didn't settle within timeout")
            #endif
            return
        }

        do {
            let accounts = try context.fetch(FetchDescriptor<Account>())
            let subcategories = try context.fetch(FetchDescriptor<Subcategory>())
            let tags = try context.fetch(FetchDescriptor<Tag>())

            // Regen sentinel: si ya corrió en un launch previo, NO re-regenerar
            // (preserva Tag.id cross-device estable aunque el backfill aún no converge).
            let regenAlreadyRan = UserDefaults.standard.bool(forKey: regenKey)
            // DIFERIDOS #29 (§5): en `.cloud` SALTAR la regeneración masiva — la patología del default
            // colapsado es CloudKit-specific; el applier del motor asigna ids explícitos del backend, y una
            // reinstalación post-cutover (sentinels de UserDefaults perdidos) ejecutaría `regenerateAllUUIDs`
            // sobre TODOS los tags pulleados → remap masivo injustificado. El backstop repetible
            // `repairCollapsedIdentityUUIDs` (ahora CON emisión de remap) cubre colisiones residuales legítimas.
            // Los sub-pasos de CSV backfill de abajo se CONSERVAN.
            //
            // INTENCIONAL (MENOR 6 del review): el skip QUEMA el `regenKey` igual (se marca tras el save de
            // abajo) — incluso tras una REVERSA §h posterior (device de vuelta en `.icloud`) la regeneración
            // masiva JAMÁS debe correr sobre ese corpus: los datos vienen del backend con ids explícitos
            // por-fila (sin la patología del default colapsado), el backstop quirúrgico cubre cualquier
            // colisión real, y un mass-regen post-reversa sería exactamente el path peligroso (remap masivo
            // de identidades ya sincronizadas). Quemar el sentinel aquí es el comportamiento deseado.
            let skipRegenInCloud = CloudSyncFlags.storageMode == .cloud
            let accountsRegen: Int
            let subsRegen: Int
            let tagsRegen: Int
            if regenAlreadyRan || skipRegenInCloud {
                accountsRegen = 0
                subsRegen = 0
                tagsRegen = 0
                if skipRegenInCloud && !regenAlreadyRan && !tags.isEmpty {
                    CloudSyncBreadcrumb.identityRemapRegenSkippedInCloud(tags: tags.count)
                }
            } else {
                accountsRegen = regenerateDuplicateUUIDs(accounts, keyPath: \.shortcutID)
                subsRegen = regenerateDuplicateUUIDs(subcategories, keyPath: \.shortcutID)
                tagsRegen = regenerateAllUUIDs(tags, keyPath: \.id)
            }

            var sawRace = false

            // Budget: per-relation decision (M2M nil → nuke stale, M2M non-nil → encode).
            let budgets = try context.fetch(FetchDescriptor<Budget>())
            for budget in budgets {
                let plan = MigrationBackfillLogic.planForBudget(
                    accounts: budget.accounts,
                    subcategories: budget.subcategories,
                    tags: budget.tags
                )
                switch plan.accountIDsAction {
                case .writeFromM2M: budget.setAccountIDs(from: budget.accounts ?? [])
                case .nukeStale: budget.accountIDs = nil
                }
                switch plan.subcategoryIDsAction {
                case .writeFromM2M: budget.setSubcategoryIDs(from: budget.subcategories ?? [])
                case .nukeStale: budget.subcategoryIDs = nil
                }
                switch plan.tagIDsAction {
                case .writeFromM2M: budget.setTagIDs(from: budget.tags ?? [])
                case .nukeStale: budget.tagIDs = nil
                }
                if plan.sawRace { sawRace = true }
            }

            // TX/Draft/Favorite/Scheduled: escribir CSV directo SIN reasignar M2M
            // (reasignar marcaría dirty cada record → sync storm en cuentas grandes).
            let txs = try context.fetch(FetchDescriptor<TransactionItem>())
            for tx in txs {
                switch MigrationBackfillLogic.decideAction(m2m: tx.tags) {
                case .writeFromM2M: tx.tagIDs = CSVMirrorCodec.encode((tx.tags ?? []).map(\.id))
                case .nukeStale: tx.tagIDs = nil; sawRace = true
                }
            }
            let drafts = try context.fetch(FetchDescriptor<InboxDraft>())
            for draft in drafts {
                switch MigrationBackfillLogic.decideAction(m2m: draft.tags) {
                case .writeFromM2M: draft.tagIDs = CSVMirrorCodec.encode((draft.tags ?? []).map(\.id))
                case .nukeStale: draft.tagIDs = nil; sawRace = true
                }
            }
            let favorites = try context.fetch(FetchDescriptor<FavoritePayment>())
            for favorite in favorites {
                switch MigrationBackfillLogic.decideAction(m2m: favorite.tags) {
                case .writeFromM2M: favorite.tagIDs = CSVMirrorCodec.encode((favorite.tags ?? []).map(\.id))
                case .nukeStale: favorite.tagIDs = nil; sawRace = true
                }
            }
            let scheduled = try context.fetch(FetchDescriptor<ScheduledPayment>())
            for payment in scheduled {
                switch MigrationBackfillLogic.decideAction(m2m: payment.tags) {
                case .writeFromM2M: payment.tagIDs = CSVMirrorCodec.encode((payment.tags ?? []).map(\.id))
                case .nukeStale: payment.tagIDs = nil; sawRace = true
                }
            }

            SaveBreadcrumb.willSave("AppBootstrapper.migrateShortcutIDsAndRebuildCSVMirrors")
            try context.save()
            SaveBreadcrumb.didSave("AppBootstrapper.migrateShortcutIDsAndRebuildCSVMirrors")

            // Regen sentinel se marca SIEMPRE tras save exitoso (idempotente desde
            // segundo launch). Evita re-regenerar Tag.id si el backfill aún no converge.
            UserDefaults.standard.set(true, forKey: regenKey)

            // Sentinel principal: marca convergencia o cap de retries (whichever first).
            // Tras maxAttempts, se acepta el estado actual y se cede al auto-heal lazy.
            let attempts = UserDefaults.standard.integer(forKey: attemptsKey)
            if !sawRace || attempts + 1 >= maxAttempts {
                UserDefaults.standard.set(true, forKey: sentinelKey)
                UserDefaults.standard.removeObject(forKey: attemptsKey)
                AppPreferences.Keys.LegacyKeys.v2MigrationSentinels.forEach {
                    UserDefaults.standard.removeObject(forKey: $0)
                }
            } else {
                UserDefaults.standard.set(attempts + 1, forKey: attemptsKey)
            }

            MetricsService.canary(
                .appEntityShortcutIDsRegenerated,
                detail: "acc=\(accountsRegen)|sub=\(subsRegen)|tag=\(tagsRegen)|wait=\(migrationWaitBucket(waitDuration))|race=\(sawRace)",
                value: Double(accountsRegen + subsRegen + tagsRegen)
            )

            #if DEBUG
            print("AppBootstrapper: migrateShortcutIDsAndRebuildCSVMirrors — regen accounts=\(accountsRegen)/\(accounts.count), subs=\(subsRegen)/\(subcategories.count), tags=\(tagsRegen)/\(tags.count); CSV \(budgets.count) budgets + \(txs.count) txs + \(drafts.count) drafts + \(favorites.count) favorites + \(scheduled.count) scheduled (sawRace=\(sawRace), sentinel=\(sawRace ? "deferred" : "set"))")
            #endif
        } catch {
            #if DEBUG
            print("AppBootstrapper: migrateShortcutIDsAndRebuildCSVMirrors error: \(error)")
            #endif
            // Do NOT mark sentinel — retry next launch.
        }
    }

    /// Privacy-friendly wait-duration buckets — no exact timings.
    private func migrationWaitBucket(_ seconds: TimeInterval) -> String {
        switch seconds {
        case ..<0.1: return "lt_100ms"  // .runNow path
        case ..<1: return "lt_1s"
        case ..<3: return "1_3s"
        case ..<10: return "3_10s"
        default: return "gt_10s"
        }
    }

    // MARK: - Deep Link Handling

    /// URL Scheme from shared helper.
    private var urlScheme: String { WidgetURLHelper.urlScheme }

    /// Procesa URLs entrantes (deep links y universal links)
    func handleIncomingURL(_ url: URL) {
        // Google Sign-In (sesión 1): el SDK consume su callback (scheme = reversed client ID). Va
        // PRIMERO — el guard de `urlScheme` de abajo descartaría ese scheme. No-op barato para URLs
        // ajenas; sin orden-dependencia con invites (un invite link jamás es del scheme de Google).
        if GIDSignIn.sharedInstance.handle(url) { return }

        // Universal link: https://yala-app.pe/invite?s=...
        if InviteLinkService.isInviteLink(url) {
            handleInviteLink(url)
            return
        }

        guard url.scheme == urlScheme else { return }

        #if DEBUG
        print("AppBootstrapper: Received deep link: \(url.absoluteString)")
        #endif

        switch url.host {
        case "shared-image":
            if let firstImageURL = SharedContainerService.pendingImageURLs().first {
                enqueueSharedImage(firstImageURL)
            }

        case "voice-entry":
            executeAction(.voiceEntry)

        case "image-entry":
            executeAction(.imageEntry)

        case "new-transaction":
            executeAction(.newTransaction)

        case "panel":
            setOrDeferDeepLink(.panel)

        case "statistics":
            if url.pathComponents.contains("records") {
                setOrDeferDeepLink(.records)
            } else if url.pathComponents.contains("categories") {
                setOrDeferDeepLink(.categories)
            } else {
                setOrDeferDeepLink(.statistics)
            }

        case "planning":
            setOrDeferDeepLink(.planning)

        case "budgets":
            setOrDeferDeepLink(.budgets)

        case "records":
            setOrDeferDeepLink(.recordsStandalone)

        case "groups":
            if let groupID = url.pathComponents.last, groupID != "/" {
                setOrDeferDeepLink(.groupDetail(groupID: groupID))
            } else {
                setOrDeferDeepLink(.groups)
            }

        default:
            #if DEBUG
            print("AppBootstrapper: Unknown deep link host: \(url.host ?? "nil")")
            #endif
        }
    }

    // MARK: - Invite Link Handling

    /// Procesa un universal link de invitación de grupo.
    /// Acceso internal para que YalaAppDelegate pueda llamarlo.
    func handleInviteLink(_ url: URL) {
        handleInviteLink(url, didRefreshFlags: false)
    }

    /// Enrutado por CANAL. **El parser backend se evalúa SIN gatear por el flag y ANTES del camino
    /// CKShare**, y ese orden es el invariante — ver `GroupInviteChannelRoutingLogic`, que lleva el
    /// porqué completo. Resumen de lo que costó (device, 2026-07-31): el gate `if
    /// CloudSyncFlags.groupsBackendEnabled` prometía «con el flag OFF, byte-idéntico al camino
    /// CKShare», pero un link backend NO cae al `guard let shareURL else` de abajo —
    /// `extractShareURL` LO ACEPTA, porque su `s` decodifica a `…/invite?g=..&t=..`, una URL válida,
    /// y el guard host/path valida el URL EXTERIOR. ⇒ el invite backend se colaba al canal CKShare
    /// disfrazado y moría sin una sola línea de UI.
    ///
    /// `didRefreshFlags` solo lo pone a `true` la continuación de `.refreshFlagsThenRetry`.
    private func handleInviteLink(_ url: URL, didRefreshFlags: Bool) {
        let backendInvite = InviteLinkService.extractBackendInvite(from: url)

        switch GroupInviteChannelRoutingLogic.route(
            isBackendLink: backendInvite != nil,
            flagEnabled: CloudSyncFlags.groupsBackendEnabled,
            didRefreshFlags: didRefreshFlags
        ) {
        case .ckShare:
            // **Fase 3: este canal ya no existe.** Un link de CKShare no puede unir a nadie —el transporte
            // que aceptaba el share se borró—, así que la rama INFORMA en vez de quedarse muda. Un apagón
            // silencioso aquí (tapear un enlace y que no pase nada) es el peor modo de fallo de esta épica,
            // y el copy correcto es el mismo de `.backendUnavailable`: el enlace no es inválido, el canal
            // que lo servía es el que ya no está.
            // El copy de `.showInviteError` («ya no es válido o expiró; pídele al admin que regenere uno»)
            // es LITERALMENTE cierto aquí, al revés que en `.backendUnavailable`: el enlace regenerado
            // será del canal backend y ese sí funciona. Por eso este camino no reusa
            // `groups.invite.channelUnavailable`, cuyo «guardamos tu solicitud» sería falso — aquí no se
            // persiste ningún intent.
            logger.error("Invite: CKShare link but that channel no longer exists (Fase 3) — informing user")
            MetricsService.canary(.groupJoinIntentDeferred, detail: "ckShareChannelRemoved")
            RouterEntryGate.shared.submit(.showInviteError(
                String(localized: "groups.invite.linkInvalidDetail")
            ))

        case .backend:
            // `route` devuelve `.backend` solo con `isBackendLink == true` ⇒ el guard no es
            // alcanzable; está por no forzar el unwrap (regla inviolable del repo).
            guard let backendInvite else { return }
            enterBackendInvite(groupID: backendInvite.groupID, token: backendInvite.token, url: url)

        case .refreshFlagsThenRetry:
            guard let backendInvite else { return }
            // El intent va ANTES del await: si el refresh no vuelve (red muerta, kill del proceso),
            // la intención del usuario ya está en disco y el reconciler la retoma en el siguiente
            // boot/foreground con el flag ya encendido. `force: true` NO es cosmético — sin él
            // `refreshIfDue` es un no-op en el caso EXACTO del bug («fetcheé hace menos de 6 h»);
            // y es acción de usuario con intención explícita, no un poll, así que no toca
            // `refreshMinInterval` para nadie más. El spam queda acotado por el guard `inFlight`
            // del cliente y porque esta rama exige link backend Y flag OFF.
            persistBackendInviteIntent(groupID: backendInvite.groupID, token: backendInvite.token)
            logger.notice("Invite: backend link with flag OFF → forcing remote-config refresh")
            Task { @MainActor in
                await RemoteConfigClient.shared.refreshIfDue(force: true)
                self.handleInviteLink(url, didRefreshFlags: true)
            }

        case .backendUnavailable:
            guard let backendInvite else { return }
            // Idempotente (upsert que preserva displayName/currency): cubre el caso de que esta rama
            // se alcance sin haber pasado por la anterior.
            persistBackendInviteIntent(groupID: backendInvite.groupID, token: backendInvite.token)
            logger.error("Invite: backend link but channel still OFF after refresh — intent kept, informing user")
            MetricsService.canary(.groupJoinIntentDeferred, detail: "backendChannelOff")
            // `.showGroupSyncError` y NO `.showInviteError`: el título de ese último está hardcodeado
            // a `groups.invite.linkInvalidTitle` («Enlace no válido»), que aquí sería FALSO — el
            // enlace es perfecto, lo que está apagado es el canal — y mandaría al invitado a pedir
            // uno nuevo que tampoco funcionaría. Mismo criterio que `handleJoinError`, que reserva
            // `showInviteError` para el `invalidInvite` de verdad.
            RouterEntryGate.shared.submit(.showGroupSyncError(
                String(localized: "groups.invite.channelUnavailable")
            ))
        }
    }

    /// Adopción del dominio + intent DURABLE + canario. Es el par exacto que ya hacían el cold path
    /// y `GroupBackendInviteEntryHandler.handle`; extraído porque ahora hay un tercer llamador (flag
    /// OFF). La adopción va aquí y no solo en `handle` porque el reconciler completa el join vía
    /// `drive`, que no lo toca: sin esto el invitado entraría al grupo y, en un dispositivo sellado
    /// por «empiezo de cero», sus gastos no llegarían nunca a su Panel.
    private func persistBackendInviteIntent(groupID: String, token: String) {
        UserDefaults.standard.set(true, forKey: AppPreferences.Keys.groupsBetaUnlocked)
        GroupBackendInviteEntryHandler.persistIntent(groupID: groupID, token: token)
        // `canaryOnce` y NO `canary`: el camino `.refreshFlagsThenRetry` persiste el intent y DESPUÉS
        // re-entra en `handleInviteLink`, así que un solo tap pasaba por aquí y luego por el emisor de
        // `GroupBackendInviteEntryHandler.handle` — DOS eventos por una sola intención, y justo en la
        // cohorte del rollout (flag remoto stale) que es la que uno querría medir. La clave es el
        // `groupID` para que una invitación a OTRO grupo sí cuente; el dedup es por sesión de proceso,
        // así que un reintento tras relanzar también cuenta, que es correcto: es otro intento.
        // El otro emisor usa esta MISMA clave a propósito — cambiar una sin la otra reabre el doble conteo.
        MetricsService.canaryOnce(.groupJoinIntentPersisted, key: groupID)
    }

    /// Canal backend con el flag ON (comportamiento previo de la rama C2, sin cambios).
    private func enterBackendInvite(groupID: String, token: String, url: URL) {
        if !isInitialized {
            // R4: persistir el intent backend y RETORNAR — el trigger boot del reconciler lo completa
            // (el link backend JAMÁS cae al deferral CKShare del camino CKShare). M1: alineado con el
            // warm handle() — desbloquea beta, o el invitado cold-launch quedaría detrás del beta gate
            // sin ver su grupo.
            persistBackendInviteIntent(groupID: groupID, token: token)
            #if DEBUG
            print("AppBootstrapper: Deferring BACKEND invite (persisted) — not yet initialized")
            #endif
            return
        }
        let branded = InviteLinkService.extractMetadata(from: url)
        Task { @MainActor in
            await GroupBackendInviteEntryHandler.handle(
                groupID: groupID,
                token: token,
                branded: branded,
                source: .universalLink
            )
        }
    }

    /// A12: Decisión de routing para un share aceptado. Pure function — testeable.
    ///
    /// **HUÉRFANA en producción desde la Fase 3**, declarado: su consumidor era `CKShareEntryHandler`, que
    /// murió con el transporte. Se conserva porque `ReconnectMode` y su tabla siguen describiendo la UI de
    /// reconexión que el canal backend usa, y podarla es decisión de producto, no del compilador.
    enum InviteRouteDecision: Equatable {
        /// Invitado nuevo (sin onboarding completo y NO mid-invite): acepta eagerly + muestra invite onboarding.
        case acceptAndShowInviteOnboarding
        /// Todos los demás casos: muestra reconnect con el mode apropiado.
        case showReconnect(mode: ReconnectMode)
        /// Parte F: returning user con datos en iCloud (sin wipe) → ofrecer cargar
        /// sus datos antes de unirse al grupo.
        case offerRestoreThenInvite
    }

    /// Decide el routing tras leer metadata del share + estado local del grupo.
    /// Orden de evaluación: isHiddenForAll > isArchived > !hasCompletedOnboarding > member status > default.
    ///
    /// Fresh users (no completaron onboarding) priorizan el invite onboarding silencioso
    /// — `detectFinalStep` cubre todos los memberStatus (pending → step 3, active → step 2,
    /// rejected → reactivate via `ensureCurrentUserMemberExists`). Si memberStatus ganara,
    /// el user quedaría en `GroupReconnectView` con CTA "Volver al inicio" → Chooser, sin
    /// llegar nunca al tab Grupos.
    static func inviteRouteDecision(
        hasCompletedOnboarding: Bool,
        onboardingMode: OnboardingMode,
        isHiddenForAll: Bool = false,
        isArchived: Bool = false,
        currentMemberStatus: SplitMemberStatus? = nil,
        hasReturningSignal: Bool = false
    ) -> InviteRouteDecision {
        if isHiddenForAll { return .showReconnect(mode: .deletedForAll) }
        if isArchived { return .showReconnect(mode: .archived) }
        if !hasCompletedOnboarding && onboardingMode != .groupInvite {
            // Parte F: returning user con datos en iCloud (sin wipe) → ofrecer cargar
            // antes de unirse. Sin señal → invite onboarding directo (modo solo-grupos).
            if hasReturningSignal { return .offerRestoreThenInvite }
            return .acceptAndShowInviteOnboarding
        }
        if let status = currentMemberStatus {
            switch status {
            case .active: return .showReconnect(mode: .alreadyMember)
            case .pendingApproval: return .showReconnect(mode: .pendingDuplicate)
            case .rejected: return .showReconnect(mode: .rejectedRetry)
            case .left: return .showReconnect(mode: .leftRetry)
            case .removed: return .showReconnect(mode: .removedRetry)
            }
        }
        return .showReconnect(mode: .standardReconnect)
    }

    /// `true` si el error de fetch/accept del share es transitorio (red) y vale la
    /// pena reintentar — vs permanente (share borrado, sin permiso, link inválido),
    /// donde se limpia el store. Espejo de la filosofía de `PendingLeaveShareTracker`
    /// (persistir para reintentar ante fallos de red).
    nonisolated static func isRecoverableInviteFetchError(_ error: Error) -> Bool {
        guard let ckError = error as? CKError else { return false }
        switch ckError.code {
        case .networkUnavailable, .networkFailure, .serviceUnavailable,
             .requestRateLimited, .zoneBusy:
            return true
        default:
            return false
        }
    }

    // MARK: - Deep Link Deferral

    private func setOrDeferDeepLink(_ destination: DeepLinkDestination) {
        RouterEntryGate.shared.submit(.navigate(destination))
    }

    // MARK: - Private Bootstrap Tasks

    private func loadExchangeRates(context: ModelContext) async {
        // Get today's rate
        await ExchangeRateService.shared.updateTodayIfNeeded(context: context)

        // Preload historical data if needed (first launch or after data wipe)
        await ExchangeRateService.shared.preloadHistoricalIfNeeded(context: context)

        // Barrido one-shot: devuelve a la cola las transacciones que el código viejo selló con un 1:1
        // envenenado. Va JUSTO ANTES del reparador y después de refrescar las tasas, para que lo que
        // reabra se arregle en este mismo arranque en vez de esperar al siguiente.
        TransactionUpdateService.repairLegacyOneToOneRatesIfNeeded(context: context)

        // Update transactions with provisional exchange rates
        await TransactionUpdateService.updateProvisionalTransactions(context: context)
    }

    /// Clave UserDefaults del flag idempotente de la migración Live Balance.
    // MARK: - Biometric keychain cleanup (removed in-app lock)

    private static let biometricKeychainCleanedKey = "biometricKeychainCleanedV1"

    /// One-shot: borra los items de Keychain que dejó el antiguo bloqueo biométrico
    /// in-app (removido). El Keychain SOBREVIVE a la desinstalación, así que sin esto
    /// quedarían huérfanos para siempre. Idempotente (SecItemDelete de algo inexistente
    /// es no-op); el sentinel sólo evita re-ejecutarlo en cada cold launch. No toca
    /// SwiftData → no requiere gate de quiescencia.
    private func cleanupBiometricKeychainIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: Self.biometricKeychainCleanedKey) else { return }
        KeychainService.delete(forKey: "biometricEnabled")
        KeychainService.delete(forKey: "biometricLockTimeout")
        UserDefaults.standard.set(true, forKey: Self.biometricKeychainCleanedKey)
        #if DEBUG
        print("[AppBootstrapper] Cleaned up orphaned biometric keychain items")
        #endif
    }

    private static let liveBalanceMigrationKey = "hasMigratedToLiveBalance"

    /// Migración v2.0 (épico Live Balance multi-divisa): recalcula
    /// `amountInPreferredCurrency` para TODAS las transacciones existentes
    /// para limpiar snapshots inconsistentes (en particular saldos iniciales
    /// pre-fix B1). El flag `hasMigratedToLiveBalance` solo se setea tras
    /// éxito — si falla por offline o error, próxima apertura reintenta.
    private func migrateToLiveBalanceIfNeeded(context: ModelContext) async {
        guard !UserDefaults.standard.bool(forKey: Self.liveBalanceMigrationKey) else { return }

        // Gate de quiescencia: el bulk recalc (`CurrencyChangeService.updateAllTransactions`) guarda
        // `TransactionItem` (store personal); durante el import del restore dispararía el assert.
        // Espera a que el import asiente y corre esta sesión; si no asienta, NO setea el flag → reintenta.
        guard await awaitPersonalStoreReady() else {
            SaveBreadcrumb.deferred("AppBootstrapper.migrateToLiveBalance", "import not quiescent")
            return
        }

        do {
            SaveBreadcrumb.willSave("AppBootstrapper.migrateToLiveBalance")
            try await CurrencyChangeService.shared.updateAllTransactions(
                to: CurrencyDefaults.currentPreferred,
                context: context,
                onProgress: { progress in
                    #if DEBUG
                    if Int(progress * 100) % 25 == 0 {
                        print("[LiveBalance] migration: \(Int(progress * 100))%")
                    }
                    #endif
                }
            )
            SaveBreadcrumb.didSave("AppBootstrapper.migrateToLiveBalance")
            // Solo marca completo si el store siguió quieto durante TODO el recalc. Si un lote del
            // import llegó a mitad, `ExchangeRateService.persistRate` pudo diferir tasas (cache
            // incompleta) → NO marcar el flag, reintentar al próximo arranque (evita conversiones stale).
            guard iCloudSyncService.shared.isImportQuiescent else {
                SaveBreadcrumb.deferred("AppBootstrapper.migrateToLiveBalance", "import resumed mid-migration — will retry")
                return
            }
            UserDefaults.standard.set(true, forKey: Self.liveBalanceMigrationKey)
            #if DEBUG
            print("[LiveBalance] migration completed successfully")
            #endif
        } catch {
            #if DEBUG
            print("[LiveBalance] migration failed: \(error). Will retry next launch.")
            #endif
            // NO setear flag → próxima apertura reintentará
        }
    }

    private func loadSubscriptionStatus() async {
        let store = StoreKitManager.shared
        await store.loadProducts()
        await refreshSubscriptionStatus()
    }

    /// Re-checks entitlements (local StoreKit cache, no network) and syncs state.
    /// Used by both cold launch and foreground resume.
    private func refreshSubscriptionStatus() async {
        let store = StoreKitManager.shared
        await store.updateSubscriptionStatus()

        // C-8: el derecho de la CUENTA se sincroniza FUERA de este camino — `refreshSubscriptionStatus`
        // se espera secuencialmente en el paso 3 del bootstrap, y `sync()` hace RED: dejarlo aquí ataría
        // el cold launch a la latencia del gateway. El resultado llega por el mismo método (una sola
        // reentrada: tras un sync exitoso el throttle de `shouldRefresh` devuelve false, así que la
        // segunda pasada no vuelve a lanzarlo).
        scheduleAccountEntitlementSync()

        if sessionState.isProUser != store.isProUser {
            sessionState.isProUser = store.isProUser
        }

        checkForDowngrade()

        // Track trial status for upsell service
        if store.isInTrial {
            ProUpsellService.shared.recordTrialStarted()
        }

        // Check for trial expired (shows sheet once). Suprimido en UITest: las
        // emisiones automáticas de monetización presentan sheets no deterministas
        // sobre los flujos bajo test (mismo precedente que checkForPendingInboxDrafts
        // en bootstrap). Post-gate Clase D estos intents encolados SÍ presentan —
        // en baseline quedaban en cola sin drenar y los tests pasaban de suerte.
        if ProUpsellService.shared.shouldShowTrialExpiredSheet(), !UITestHooks.isActive {
            RouterEntryGate.shared.submit(.presentTrialExpired)
        }
    }

    /// C-8: vincula/refresca el derecho de la cuenta en background y, SOLO si cambió, vuelve a
    /// derivar el estado de suscripción (que re-espeja `SessionState`, re-evalúa el downgrade y el
    /// sheet de trial). En producción sigue siendo un no-op inmediato sin tocar la red, pero desde D-R1
    /// paso 1 corta un guard más abajo: `isConfigured` ya pasa, y lo que devuelve `false` es la ausencia
    /// de `userID` (no hay sesión de nube). Task único cancelable — boot y foreground pueden coincidir.
    private func scheduleAccountEntitlementSync() {
        accountEntitlementTask?.cancel()
        accountEntitlementTask = Task { @MainActor in
            guard await AccountEntitlementService.shared.sync(), !Task.isCancelled else { return }
            await refreshSubscriptionStatus()
        }
    }

    /// Check if user has downgraded from Pro and needs to resolve excess items
    private func checkForDowngrade() {
        let store = StoreKitManager.shared

        guard store.justDowngraded else { return }

        #if DEBUG
        print("AppBootstrapper: Detected downgrade from Pro to Free")
        #endif

        // Reset premium app icon and theme if needed
        resetPremiumIconIfNeeded()
        resetProThemeIfNeeded()

        // Mark that we need to show downgrade resolution
        // The actual resolution sheet is shown from ContentView which has access to data
        // (suprimido en UITest — ver nota en refreshSubscriptionStatus).
        if !UITestHooks.isActive {
            RouterEntryGate.shared.submit(.presentDowngradeResolution)
        }
    }

    /// Reset Pro theme to System if user downgraded from Pro
    private func resetProThemeIfNeeded() {
        guard !FeatureGateService.shared.isProUser else { return }

        let currentTheme = AppTheme(rawValue: SessionDefaults.current.integer(forKey: "userTheme")) ?? .liquidGlass
        if currentTheme.isPro {
            SessionDefaults.current.set(AppTheme.liquidGlass.rawValue, forKey: "userTheme")
            #if DEBUG
            print("AppBootstrapper: Reset Pro theme '\(currentTheme.label)' to Liquid Glass")
            #endif
        }
    }

    /// Reset app icon to Original if user is Free and has premium icon
    private func resetPremiumIconIfNeeded() {
        guard !FeatureGateService.shared.isProUser else { return }

        let currentIconName = UIApplication.shared.alternateIconName

        // If user has an alternate icon set (premium), reset to default
        if currentIconName != nil {
            UIApplication.shared.setAlternateIconName(nil) { error in
                #if DEBUG
                if let error = error {
                    print("AppBootstrapper: Failed to reset app icon: \(error)")
                } else {
                    print("AppBootstrapper: Reset premium icon to Original")
                }
                #endif
            }
        }
    }

    private func processDueScheduledPayments(context: ModelContext) {
        // Only create drafts, notification is handled by checkForPendingInboxDrafts
        _ = ScheduledPaymentDraftService.processDuePayments(context: context)
        lastProcessDuePaymentsDate = Date.now
    }

    /// Signature key for processed inbox draft idempotency. Per-draft stable
    /// across syncs: `createdAt.timeIntervalSince1970 + "-" + sourceTypeRaw`.
    /// Capped at 500 entries (FIFO evict).
    private static let processedSignaturesKey = "processedInboxDraftSignatures"
    private static let processedSignaturesCap = 500

    /// Firmas del último check, pendientes de quemar al presentarse el alert.
    private var pendingInboxSignaturesToBurn: [String] = []

    private func inboxDraftSignature(_ draft: InboxDraft) -> String {
        "\(draft.createdAt.timeIntervalSince1970)-\(draft.sourceTypeRaw)"
    }

    private func loadProcessedInboxSignatures() -> [String] {
        UserDefaults.standard.stringArray(forKey: Self.processedSignaturesKey) ?? []
    }

    private func saveProcessedInboxSignatures(_ signatures: [String]) {
        var bounded = signatures
        if bounded.count > Self.processedSignaturesCap {
            bounded.removeFirst(bounded.count - Self.processedSignaturesCap)
        }
        UserDefaults.standard.set(bounded, forKey: Self.processedSignaturesKey)
    }

    private func checkForPendingInboxDrafts(context: ModelContext) {
        // Idempotency via per-draft signatures (createdAt + sourceType).
        // Legacy Date-based watermark is dropped on migration — the first
        // post-upgrade check emits an alert for all real pending drafts
        // (no silent suppression).
        SessionDefaults.current.removeObject(forKey: "lastInboxDraftCheckDate")

        var processed = Set(loadProcessedInboxSignatures())

        let pendingDescriptor = FetchDescriptor<InboxDraft>(
            predicate: #Predicate<InboxDraft> { $0.statusRaw == "pending" }
        )

        var notification = PendingInboxNotification()
        var newSignatures: [String] = []

        do {
            let drafts = try context.fetch(pendingDescriptor)
            for draft in drafts {
                let sig = inboxDraftSignature(draft)
                guard !processed.contains(sig) else { continue }
                processed.insert(sig)
                newSignatures.append(sig)
                switch draft.sourceTypeRaw {
                case "scheduledPayment":
                    notification.scheduledPayments += 1
                case "subscription":
                    notification.subscriptions += 1
                case "applePay", "automation":
                    notification.automations += 1
                default:
                    break
                }
            }
        } catch {
            #if DEBUG
            print("AppBootstrapper: Error checking inbox drafts: \(error)")
            #endif
        }

        // Las firmas se queman en el DRAIN (presentación real del alert), no aquí:
        // quemarlas al emitir perdía la alerta para siempre si el intent transient
        // se dropeaba en background o el cover colisionaba. Retenidas en memoria;
        // una re-corrida del productor antes del drain recomputa el mismo set.
        pendingInboxSignaturesToBurn = newSignatures

        if !notification.isEmpty {
            // Enqueue — readiness gating handles splash timing.
            RouterEntryGate.shared.submit(.showInboxAlert(notification))
        }
    }

    /// Quema las firmas del último `checkForPendingInboxDrafts` — llamado por el
    /// drain de `.showInboxAlert` en ContentView cuando el alert SÍ se presenta.
    /// Residual aceptado: si el gate dropea el alert (inbox sheet visible /
    /// supersession por navigate(.inbox)), las firmas no se queman y drafts aún
    /// `pending` pueden re-alertar en el próximo foreground (molestia > pérdida).
    func commitPendingInboxAlertSignatures() {
        guard !pendingInboxSignaturesToBurn.isEmpty else { return }
        var all = loadProcessedInboxSignatures()
        all.append(contentsOf: pendingInboxSignaturesToBurn)
        saveProcessedInboxSignatures(all)
        pendingInboxSignaturesToBurn = []
    }

    private func seedDefaultNotifications(context: ModelContext) {
        // Only seed for existing users who completed onboarding before notification feature
        guard UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") else { return }
        NotificationService.shared.seedDefaultNotificationsIfNeeded(context: context)
    }

    /// Drena `PendingImages/` (share extension) en una ventana ready y re-emite el intent de
    /// presentación. Llamado desde `bootstrap()` (post-`isInitialized`) y `handleBecameActive`.
    /// Gateado por `SharedImageRecoveryGate`: solo re-emite cuando el `submit(.presentSharedImage)`
    /// pasará el readiness gate (init + onboarding + no-lock); en caso contrario la imagen
    /// persiste en el App Group y se reintenta en la próxima ventana. `site` es solo para el
    /// breadcrumb de diagnóstico. Ver Bugs/qa_cold-launch-share-image-no-registro.
    private func checkForPendingSharedImage(site: String) {
        let pending = SharedContainerService.pendingImageURLs().first
        let willReEmit = SharedImageRecoveryGate.shouldReEmit(
            hasPendingImage: pending != nil,
            isInitialized: isInitialized,
            hasCompletedOnboarding: UserDefaults.standard.bool(forKey: AppPreferences.Keys.hasCompletedOnboarding)
        )
        SharedImageBreadcrumb.checked(site: site, found: pending != nil, willReEmit: willReEmit)
        guard willReEmit, let firstImageURL = pending else { return }
        enqueueSharedImage(firstImageURL)
    }

    /// Routes a shared-image URL through the router. Panel navigation and
    /// sheet presentation are separate intents so the mainTab consumer can
    /// switch tabs before the panel consumer presents the sheet (consumer
    /// gate K prevents flicker). The URL also lands in SessionState because
    /// ImageSelectionView reads it directly from there. If AI data consent is
    /// not accepted, presentation is deferred until the user accepts via the
    /// `aiConsentAlert` (whose callback opens the same image sheet).
    private func enqueueSharedImage(_ url: URL) {
        sessionState.pendingSharedImageURL = url
        RouterEntryGate.shared.submit(.navigate(.panel))
        if SessionDefaults.current.bool(forKey: AppPreferences.Keys.aiDataConsentAccepted) {
            RouterEntryGate.shared.submit(.presentSharedImage(url))
        } else {
            RouterEntryGate.shared.submit(.requestAIConsent(.image))
        }
    }

    // MARK: - Notification Management

    /// Verifies permissions and reschedules notifications if needed.
    /// Handles: reinstall, iOS update, and permission re-enabling.
    private func ensureNotificationsScheduled(context: ModelContext) async {
        let status = await NotificationService.shared.checkPermissionStatus()
        guard status == .authorized || status == .provisional else { return }

        // Check pending requests in the system
        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()

        // Get active notifications from database
        let activeItems = fetchActiveNotifications(context: context)

        // If there are active items but fewer pending (reinstall/update case), reschedule
        if !activeItems.isEmpty && pending.count < activeItems.count {
            await NotificationService.shared.rescheduleAllNotifications(items: activeItems)
        }

        // Check scheduled payment notifications (single call fetches data once)
        ScheduledPaymentNotificationService.shared.setContext(context)
        await ScheduledPaymentNotificationService.shared.checkAllPaymentNotifications()

        // Check credit card payment reminders
        await ScheduledPaymentNotificationService.shared.checkAndNotifyCreditCardPayments()

        // Re-plan de las summaries diarias AGENDADAS (canal híbrido D1): convergencia
        // idempotente en cada boot/foreground — también absorbe cambios remotos de CloudSync.
        await ScheduledPaymentNotificationService.shared.replanSummaries()

        // Cleanup old tracker entries
        ScheduledPaymentNotificationTracker.shared.cleanupOldEntries()

        // Check budget alert notifications
        BudgetAlertService.shared.setContext(context)
        await BudgetAlertService.shared.checkBudgetsAndNotify()
        BudgetAlertTracker.shared.cleanupOldEntries()

        lastNotificationCheckDate = Date.now
    }

    /// Fetches active NotificationItems from database
    private func fetchActiveNotifications(context: ModelContext) -> [NotificationItem] {
        let descriptor = FetchDescriptor<NotificationItem>(
            predicate: #Predicate { $0.isActive }
        )

        do {
            return try context.fetch(descriptor)
        } catch {
            #if DEBUG
            print("AppBootstrapper: Error fetching active notifications: \(error)")
            #endif
            return []
        }
    }
}
