//
//  AppBootstrapper.swift
//  Yala
//
//  Centraliza la inicialización de servicios y tareas de arranque.
//  Resuelve ARCH-005: Inicialización dispersa en YalaApp.
//

import CloudKit
import CoreData
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
    let appPreferences = AppPreferences()

    // MARK: - Panel Action (Control Center / widgets)

    enum PanelAction {
        case newTransaction
        case voiceEntry
        case imageEntry
    }

    // MARK: - State

    private(set) var isInitialized = false
    /// Guard runtime (NO persistido) contra procesamiento concurrente de un invite:
    /// el re-emit (cold launch + foreground) y un `handleInviteLink` warm podrían
    /// lanzar `acceptShareFromURL` en paralelo. Runtime-only — un re-launch debe
    /// poder reintentar. El invite pendiente vive en `PendingInviteStore` (persistente).
    private var isProcessingInvite = false
    private var subscriptionCheckTask: Task<Void, Never>?
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

    // MARK: - Initialization

    private init() {
        // Private to enforce singleton
    }

    // MARK: - Bootstrap

    /// Ejecuta todas las tareas de inicialización al arrancar la app.
    /// Llamar desde el .task{} de YalaApp.
    func bootstrap(container: ModelContainer) async {
        guard !isInitialized else { return }

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

        // 0.5. Configure analytics (no-op if API key missing)
        TelemetryService.configure()
        TelemetryService.track(.appLaunched)

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

        // 5. Check for pending inbox drafts and notify user
        if !uiTestActive { checkForPendingInboxDrafts(context: context) }

        // 6. Seed default notifications for existing users
        seedDefaultNotifications(context: context)

        // 6.1. Deduplicate notifications (R9: handles CloudKit race during onboarding)
        NotificationService.shared.deduplicateNotifications(context: context)

        // 6.5. Cancel any old scheduled dynamic notifications (reports)
        // These use background tasks now, not iOS scheduling
        await NotificationService.shared.cancelDynamicNotifications(context: context)

        // 6.6. Ensure static notifications are scheduled (handles reinstall/update case)
        await ensureNotificationsScheduled(context: context)

        // 7. Check for pending shared images (cold launch without deep link)
        checkForPendingSharedImage()

        // 7.5. Clean up stale pending images (>24h)
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

        // 12. Check if any report notifications should be sent now (app launch case)
        await ReportNotificationService.shared.sendDueReports(context: context)

        // 12.5. Observe exchange rate updates to invalidate the latest-rates cache
        observeExchangeRateUpdates()

        // 13. Observe CloudKit remote changes to auto-refresh UI
        observeRemoteStoreChanges(context: context)

        // 14. Observe iCloud account changes — detect mismatch if container was created without CloudKit
        observeICloudAccountChanges()

        // 14.5 (M6). Observe TX imports from CKSync personal — autodelete drafts pendientes Caso A
        // cuyo splitExpenseID ya tiene TX cuenta real (race resuelto por sync).
        observeTransactionsImportedFromSync(context: context)

        // 15. Initialize CKSyncEngine for shared group data (separate groups store)
        SplitSyncManager.shared.setContext(context)
        if !uiTestActive { SplitSyncManager.shared.initialize() }

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

        // 16.4.5. Safety net: hidden groups + removed-self cleanup que el observer pudo perder.
        // Corre ANTES de retryPendingBridges para que el bridge guard `isHiddenForAll` aplique.
        Task { @MainActor in
            guard await awaitPersonalImportForBootSave() else {
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
            guard await awaitPersonalImportForBootSave() else {
                SaveBreadcrumb.deferred("AppBootstrapper.reconcileTransferPairs", "import not quiescent")
                return
            }
            TransferPairReconcileService.reconcileTransferPairs(in: context)
        }

        // 16.5. Retry bridge operations that failed in a previous launch
        Task { @MainActor in
            await retryPendingBridges(context: context)
        }

        // 16.6. A13: Reconcile current user's displayName across groups.
        // Covers kill-app between acceptShare and performSilentSetup (SplitMember
        // would otherwise stay with the "Usuario" default forever). Idempotent.
        Task { @MainActor in
            guard await awaitPersonalImportForBootSave() else {
                SaveBreadcrumb.deferred("AppBootstrapper.reconcileCurrentUserDisplayName", "import not quiescent")
                return
            }
            await reconcileCurrentUserDisplayNameIfNeeded()
        }

        // 16.7. Retry persistente de `leaveShare` que falló por network en sesión previa.
        Task { @MainActor in
            await retryPendingLeaveShares()
        }

        // Seed current iCloud user identity for groups and refresh local membership flags.
        Task { @MainActor in
            _ = try? await GroupUserIdentityService.shared.currentUserRecordName()
            guard await awaitPersonalImportForBootSave() else {
                SaveBreadcrumb.deferred("AppBootstrapper.refreshCurrentUserFlags", "import not quiescent")
                return
            }
            await GroupService.shared.refreshCurrentUserFlags()
        }

        // 17. Initialize Group Notification Service (GC-06)
        GroupNotificationService.shared.setContext(context)

        // 17.5. One-time backfill of SplitShare.groupZoneID for existing shares.
        // D2: gated on the personal first import (same mechanism as the V3 migration / group sync
        // gate) — this save touches the personal mainContext and must not land on a half-imported
        // graph. Idempotent: if the import doesn't settle in time, the sentinel stays unset and it
        // retries next launch.
        Task { @MainActor in
            guard await awaitPersonalImportForBootSave() else { return }
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

        // 19. Re-emit pending invite (cold launch via universal link / native share).
        // Reads PendingInviteStore (persistent) — covers invites that arrived
        // pre-bootstrap AND invites dropped by resetTransients in a prior session.
        reEmitPendingInviteIfNeeded(isPresenting: false)

        // 20. Drain DeferredIntentBuffer: re-submit any RouterIntent that
        // arrived during pre-bootstrap, biometric lock, or mid-onboarding.
        RouterEntryGate.shared.drainDeferredBuffer()
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
        }
        // Estado Pro determinista según el launch arg, idempotente entre tests.
        // `devForceProTier` se persiste en UserDefaults (`dev.forceProTier`) y el wipe
        // de SwiftData no lo toca → sin esto, un test con `-uitest-pro` dejaría Pro
        // "pegajoso" para los siguientes, rompiendo las verificaciones de gating free.
        if StoreKitManager.shared.devForceProTier != UITestHooks.forcePro {
            StoreKitManager.shared.toggleDevProTier()
        }
        if UITestHooks.skipOnboarding {
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
            UserDefaults.standard.set(true, forKey: "hasShownWelcomeChooser")
        }
        // Modo solo-grupos determinista: onboarding saltado + onboardingMode=.groupInvite
        // + tab Grupos seleccionado. El init de SessionState no deriva el tab, así que se
        // setea explícitamente (idempotente; no-op en release vía hasArg).
        if UITestHooks.forceGroupInvite {
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
            UserDefaults.standard.set(true, forKey: "hasShownWelcomeChooser")
            OnboardingMode.setCurrent(.groupInvite)
            SessionState.shared.onboardingMode = .groupInvite
            SessionState.shared.selectedMainTab = .groups
        }
        // El What's New de la versión corriente se marca visto en todo arranque
        // uitest: con contenido publicado para la versión (WhatsNewConfig), el sheet
        // intercepta el primer tap de cualquier XCUITest post-onboarding.
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        UserDefaults.standard.set(currentVersion, forKey: "lastSeenAppVersion")

        // Gate beta de Grupos (validación v2.0.1, TEMPORAL): los XCUITests prueban la
        // funcionalidad de Grupos, no el gate del código beta. Desbloquear en uitest
        // evita que GroupsBetaGateView intercepte DeeplinkRoutingUITests / GroupsSmokeUITests.
        if UITestHooks.isActive {
            UserDefaults.standard.set(true, forKey: AppPreferences.Keys.groupsBetaUnlocked)
        }
    }

    /// Seed de datos UI-test al final del bootstrap + señal `uitest_ready`.
    private func applyUITestSeed(context: ModelContext) async {
        defer { UITestHooks.shared.markReady() }
        if let raw = UITestHooks.seedProfile {
            let profile = DevSeedProfile(rawValue: raw) ?? .realista
            await DevSeedService().seed(in: context, profile: profile)
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
        // UpdateAvailableBanner simulado en uitest: fuerza el estado sin red.
        if UITestHooks.forceUpdateBanner {
            AppUpdateService.shared.forceUpdateAvailableForUITest()
        }
        // Consentimiento IA en uitest: destraba la navegación a voz/imagen Pro sin el
        // alert de consentimiento (no graba/transcribe; solo abre la vista).
        if UITestHooks.aiConsent {
            appPreferences.aiDataConsentAccepted = true
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
    private func observeTransactionsImportedFromSync(context: ModelContext) {
        raceCleanerModelContext = context
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

        let wasCreatedWithCloudKit = SwiftDataConfiguration.containerWasCreatedWithCloudKit
        let isNowAvailable = SwiftDataConfiguration.isICloudAvailable()

        if !wasCreatedWithCloudKit && isNowAvailable {
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

    private func observeRemoteStoreChanges(context: ModelContext) {
        remoteChangeModelContext = context
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
                    // Dedup en oleadas: el burst de sync acabó. Gateado por feature flag +
                    // quiescencia (runDedupIfQuiescent decide si la actividad cesó de verdad).
                    if !UserDefaults.standard.bool(forKey: AppPreferences.Keys.subcatDedupRemoteHookDisabled),
                       let ctx = bootstrapper.remoteChangeModelContext {
                        CategoryDeduplicationService.runDedupIfQuiescent(in: ctx)
                    }
                    #if DEBUG
                    print("AppBootstrapper: Remote CloudKit change — trailing edge")
                    #endif
                }
            }
        }
    }

    // MARK: - One-Time Migrations

    /// Gate for early-boot mainContext saves (retryPendingBridges, migrateShareGroupZoneIDs).
    /// Un `save()` del mainContext personal mientras el import de CloudKit está en curso puede disparar
    /// el `_assertionFailure` interno de SwiftData. Devuelve true cuando es seguro: (1) espera el primer
    /// import si está pendiente, y (2) ADEMÁS espera la **quiescencia** del store (sin import en curso +
    /// ventana de quietud) — porque el primer importEvent es una señal PREMATURA en un restore
    /// multi-lote (NSPersistentCloudKitContainer sigue importando después). Devuelve false si no se
    /// asienta dentro del tope → el caller difiere (idempotente, reintenta al próximo arranque).
    private func awaitPersonalImportForBootSave() async -> Bool {
        // "Seguro para boot-save" = no hay cuenta (sin CloudKit), O el primer import YA ocurrió Y el
        // store está quieto. Exigir `hasCompletedFirstImport` es clave: `isImportQuiescent` por sí solo
        // es `true` ANTES de que el import arranque (`lastImportDate==nil`) → proceder ahí sería
        // prematuro en un restore donde el import aún no empezó (mismo invariante que
        // `resolveWaitByQuiescence`). Sin cuenta no hay grafo a medio importar → seguro de inmediato.
        func safeToBootSave() -> Bool {
            !iCloudSyncService.shared.isAccountAvailable
                || (iCloudSyncService.shared.hasCompletedFirstImport && iCloudSyncService.shared.isImportQuiescent)
        }
        // 1) Esperar el primer import (restore lento).
        if MigrationGateLogic.shouldWaitForCloudKit(
            isAccountAvailable: iCloudSyncService.shared.isAccountAvailable,
            hasCompletedFirstImport: iCloudSyncService.shared.hasCompletedFirstImport
        ) == .waitForHook {
            _ = await iCloudSyncService.shared.forceFetchAndWait(timeout: 15)
        }
        // 2) Esperar la quiescencia (no por el primer evento — por el final del import multi-lote).
        var waited: TimeInterval = 0
        let pollInterval: TimeInterval = 2
        let quiescenceHardCap: TimeInterval = 120
        while !safeToBootSave() && waited < quiescenceHardCap {
            try? await Task.sleep(for: .seconds(pollInterval))
            waited += pollInterval
        }
        return safeToBootSave()
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
        guard await awaitPersonalImportForBootSave() else {
            logger.notice("retryPendingBridges deferred — personal import not quiescent")
            return
        }
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

    /// Retry de `leaveShare` que falló en sesiones previas (network/offline). Itera
    /// `PendingLeaveShareTracker.all()`; entries que succeden se quitan, las que vuelven a
    /// fallar permanecen para el siguiente boot.
    @MainActor
    func retryPendingLeaveShares() async {
        let entries = PendingLeaveShareTracker.all()
        guard !entries.isEmpty else { return }
        for entry in entries {
            do {
                try await SplitZoneManager(syncManager: .shared).leaveShareByZone(
                    zoneName: entry.zoneName,
                    ownerName: entry.zoneOwnerName
                )
                PendingLeaveShareTracker.remove(entry)
                #if DEBUG
                logger.info("retryPendingLeaveShares: succeeded for \(entry.zoneName, privacy: .public)")
                #endif
            } catch {
                #if DEBUG
                logger.error("retryPendingLeaveShares: failed for \(entry.zoneName, privacy: .public): \(error.localizedDescription, privacy: .public). Mantengo en tracker.")
                #endif
            }
        }
    }

    /// A13: Reconcile current user's `displayName` across all SplitMembers if a real
    /// name was already set (UserDefaults `userName`) but a previous onboarding flow
    /// was interrupted (e.g. kill-app between `acceptShare` and `performSilentSetup`).
    /// Idempotent — `updateCurrentUserDisplayName` is a no-op when nothing differs.
    @MainActor
    func reconcileCurrentUserDisplayNameIfNeeded() async {
        let realName = (UserDefaults.standard.string(forKey: AppPreferences.Keys.userName) ?? "")
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
        // Warm-start telemetry
        if hasSeenInitialActive {
            TelemetryService.track(.appResumed)
        } else {
            hasSeenInitialActive = true
        }

        // Apply any pending remote CloudKit changes on foreground resume
        sessionState.applyPendingChangesIfNeeded()

        // Prefetch group changes on foreground resume (the group CKSyncEngines don't auto-fetch
        // without a handled push). Debounced + quiescence-gated inside syncNow. This pulls the data
        // down; a mounted Groups view refreshes it on its next appear / pull-to-refresh (the fetch
        // handler's markRemoteChangePending drives the deferred refresh, same as the rest of the app).
        Task { await SplitSyncManager.shared.syncNow() }

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
        checkForPendingInboxDrafts(context: context)

        checkForPendingControlAction()

        // Drain buffered intents (notif taps that arrived during lock /
        // mid-onboarding while app was foregrounded but blocked).
        RouterEntryGate.shared.drainDeferredBuffer()

        // Skip notification checks if bootstrap just ran (< 5 seconds ago)
        let shouldCheckNotifications = Date.now.timeIntervalSince(lastNotificationCheckDate) > 5.0

        if shouldCheckNotifications {
            Task {
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
    /// Router handles readiness gating — intents queued while splash/lock/wipe
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
            if UserDefaults.standard.bool(forKey: AppPreferences.Keys.aiDataConsentAccepted) {
                RouterEntryGate.shared.submit(.presentVoiceEntry)
            } else {
                RouterEntryGate.shared.submit(.requestAIConsent(.voice))
            }
        case .imageEntry:
            guard FeatureGateService.shared.canAccess(.imageInput) else {
                RouterEntryGate.shared.submit(.presentUpgradeSheet(.image))
                return
            }
            if UserDefaults.standard.bool(forKey: AppPreferences.Keys.aiDataConsentAccepted) {
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
            let accountsRegen: Int
            let subsRegen: Int
            let tagsRegen: Int
            if regenAlreadyRan {
                accountsRegen = 0
                subsRegen = 0
                tagsRegen = 0
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

            TelemetryService.track(
                .appEntityShortcutIDsRegenerated,
                parameters: [
                    "accounts": "\(accountsRegen)",
                    "subcategories": "\(subsRegen)",
                    "tags": "\(tagsRegen)",
                    "budgets": "\(budgets.count)",
                    "txs": "\(txs.count)",
                    "drafts": "\(drafts.count)",
                    "favorites": "\(favorites.count)",
                    "scheduled": "\(scheduled.count)",
                    "waitedForSync": "\(waitedForSync)",
                    "waitDuration_bucket": migrationWaitBucket(waitDuration),
                    "sawRace": "\(sawRace)",
                ]
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
        guard let shareURL = InviteLinkService.extractShareURL(from: url) else {
            logger.error("Invalid invite link: \(url.absoluteString, privacy: .public)")
            RouterEntryGate.shared.submit(.showInviteError(
                String(localized: "groups.invite.linkInvalidDetail")
            ))
            return
        }

        let brandedMetadata = InviteLinkService.extractMetadata(from: url)

        #if DEBUG
        print("AppBootstrapper: Invite link received, CKShare URL: \(shareURL.absoluteString) brandedName=\(brandedMetadata.name ?? "nil")")
        #endif

        if !isInitialized {
            // Persistente (no in-memory) → el invite sobrevive un kill antes de que
            // bootstrap corra. El paso 19 lo procesa vía `reEmitPendingInviteIfNeeded`.
            PendingInviteStore.save(PendingInviteEntry(shareURL: shareURL, branded: brandedMetadata))
            #if DEBUG
            print("AppBootstrapper: Deferring invite (persisted) — not yet initialized")
            #endif
            return
        }

        processInvite(shareURL: shareURL, branded: brandedMetadata)
    }

    /// A12: Decisión de routing para un share aceptado. Pure function — testeable.
    /// Replica la lógica simétrica con `YalaAppDelegate.userDidAcceptCloudKitShareWith`.
    enum InviteRouteDecision: Equatable {
        /// Invitado nuevo (sin onboarding completo y NO mid-invite): acepta eagerly + muestra invite onboarding.
        case acceptAndShowInviteOnboarding
        /// Todos los demás casos: muestra reconnect con el mode apropiado.
        case showReconnect(mode: ReconnectMode)
        /// Parte F: returning user con datos en iCloud (sin wipe) → ofrecer cargar
        /// sus datos antes de unirse al grupo. El invite queda en PendingInviteStore.
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

    /// Re-emite el invite pendiente persistido si procede. Llamado en cold launch
    /// (bootstrap paso 19, `isPresenting: false`) y en foreground
    /// (`ContentView` `.active`, con el estado real de presentación).
    func reEmitPendingInviteIfNeeded(isPresenting: Bool) {
        // Simetría con el guard de `handleInviteLink`: no procesar pre-bootstrap
        // (routing leería SessionState/onboardingMode aún sin inicializar). El paso
        // 19 corre post-`isInitialized`; un `.active` temprano de ContentView se
        // difiere hasta ese paso (o al siguiente foreground warm).
        guard isInitialized else { return }
        guard let entry = PendingInviteStore.current(),
              let resolved = entry.resolved(),
              Self.shouldReEmitInvite(
                  storeHasEntry: true,
                  isProcessing: isProcessingInvite,
                  queueHasInviteIntent: AppRouter.shared.contains(where: Self.isInviteIntent),
                  isPresenting: isPresenting
              )
        else { return }
        TelemetryService.inviteReEmittedFromStore()
        processInvite(shareURL: resolved.url, branded: resolved.branded)
    }

    /// Pure-logic del guard de re-emisión. Re-emite solo si hay un invite pendiente,
    /// no hay otro procesamiento en vuelo, no hay ya un intent de invite encolado, y
    /// no hay un invite presentándose (cover abierto) — esto último evita la
    /// re-presentación espuria que el clear-on-complete causaría con el cover abierto.
    nonisolated static func shouldReEmitInvite(
        storeHasEntry: Bool,
        isProcessing: Bool,
        queueHasInviteIntent: Bool,
        isPresenting: Bool
    ) -> Bool {
        storeHasEntry && !isProcessing && !queueHasInviteIntent && !isPresenting
    }

    /// `true` si el intent es uno de los de invite de grupo (guard del re-emit).
    nonisolated static func isInviteIntent(_ intent: RouterIntent) -> Bool {
        switch intent {
        case .presentGroupInviteOnboarding, .presentGroupReconnect, .offerRestoreBeforeInvite: return true
        default: return false
        }
    }

    /// Lanza `acceptShareFromURL` con guard de concurrencia. El `guard` es síncrono
    /// en MainActor → un segundo llamador lo ve de inmediato y aborta. El flag se
    /// libera siempre vía `defer`, aunque el fetch/accept lance.
    private func processInvite(shareURL: URL, branded: InviteLinkService.BrandedMetadata) {
        guard !isProcessingInvite else { return }
        isProcessingInvite = true
        Task { @MainActor in
            defer { isProcessingInvite = false }
            await acceptShareFromURL(shareURL, brandedMetadata: branded)
        }
    }

    /// Acepta un CKShare a partir de su URL.
    /// A12: Comportamiento simétrico con `YalaAppDelegate.userDidAcceptCloudKitShareWith`.
    /// `brandedMetadata` lleva nombre/icono/color del grupo extraídos del URL
    /// branded para personalizar el banner de invitación.
    private func acceptShareFromURL(
        _ shareURL: URL,
        brandedMetadata: InviteLinkService.BrandedMetadata = .empty
    ) async {
        do {
            let metadata = try await InviteLinkService.fetchShareMetadata(for: shareURL)

            // CKShare acceptance + routing centralised in CKShareEntryHandler.
            await CKShareEntryHandler.handle(
                metadata: metadata,
                branded: brandedMetadata,
                source: .universalLink
            )
        } catch {
            logger.error("Failed to accept share from URL: \(error.localizedDescription, privacy: .public)")
            if Self.isRecoverableInviteFetchError(error) {
                // Red transitoria: NO limpiar el store ni mostrar error — el re-emit
                // reintentará en el próximo foreground (acotado por el TTL de 24h).
                #if DEBUG
                logger.debug("acceptShareFromURL: recoverable network error — will retry on next foreground")
                #endif
            } else {
                // Permanente (share borrado, sin permiso, link inválido): limpia el
                // store para no re-loopear y notifica al usuario.
                PendingInviteStore.clear()
                RouterEntryGate.shared.submit(.showInviteError(
                    String(localized: "groups.invite.linkInvalidDetail")
                ))
            }
        }
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

        // Update transactions with provisional exchange rates
        await TransactionUpdateService.updateProvisionalTransactions(context: context)
    }

    /// Clave UserDefaults del flag idempotente de la migración Live Balance.
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
        guard await awaitPersonalImportForBootSave() else {
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

        if sessionState.isProUser != store.isProUser {
            sessionState.isProUser = store.isProUser
        }

        checkForDowngrade()

        // Track trial status for upsell service
        if store.isInTrial {
            ProUpsellService.shared.recordTrialStarted()
        }

        // Check for trial expired (shows sheet once)
        if ProUpsellService.shared.shouldShowTrialExpiredSheet() {
            RouterEntryGate.shared.submit(.presentTrialExpired)
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
        RouterEntryGate.shared.submit(.presentDowngradeResolution)
    }

    /// Reset Pro theme to System if user downgraded from Pro
    private func resetProThemeIfNeeded() {
        guard !FeatureGateService.shared.isProUser else { return }

        let currentTheme = AppTheme(rawValue: UserDefaults.standard.integer(forKey: "userTheme")) ?? .liquidGlass
        if currentTheme.isPro {
            UserDefaults.standard.set(AppTheme.liquidGlass.rawValue, forKey: "userTheme")
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
        UserDefaults.standard.removeObject(forKey: "lastInboxDraftCheckDate")

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

        if !newSignatures.isEmpty {
            var all = loadProcessedInboxSignatures()
            all.append(contentsOf: newSignatures)
            saveProcessedInboxSignatures(all)
        }

        if !notification.isEmpty {
            // Enqueue — readiness gating handles splash/biometric timing.
            RouterEntryGate.shared.submit(.showInboxAlert(notification))
        }
    }

    private func seedDefaultNotifications(context: ModelContext) {
        // Only seed for existing users who completed onboarding before notification feature
        guard UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") else { return }
        NotificationService.shared.seedDefaultNotificationsIfNeeded(context: context)
    }

    /// Only called from bootstrap() for cold launch without deep link.
    private func checkForPendingSharedImage() {
        guard let firstImageURL = SharedContainerService.pendingImageURLs().first else { return }
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
        if UserDefaults.standard.bool(forKey: AppPreferences.Keys.aiDataConsentAccepted) {
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
