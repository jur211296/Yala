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
    /// Invite share URL buffered before bootstrap completes. Drained inside bootstrap().
    var deferredInviteShareURL: URL?
    private var subscriptionCheckTask: Task<Void, Never>?
    private var remoteChangeTask: Task<Void, Never>?
    private var remoteChangeLeadingFired = false
    private var lastNotificationCheckDate = Date.distantPast
    private var lastProcessDuePaymentsDate = Date.distantPast
    private let logger = Logger(subsystem: "com.yala", category: "Bootstrap")

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

        // 0.0. CRITICAL: One-shot wipe de Cash Flow (bug sync 1.2.6 — ver CashFlowWipeService)
        //      Debe ir PRIMERO para minimizar ventana con outbox CloudKit corrupta en juego.
        //      Pérdida acotada a config local de Cash Flow (feature Pro nueva que nunca sincronizó).
        CashFlowWipeService.wipeCashFlowDataIfNeeded(in: context)

        // 0. Sync preferences from iCloud (must be FIRST — other services read these)
        PreferenceSyncService.shared.bootstrap()

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
        processDueScheduledPayments(context: context)

        // 5. Check for pending inbox drafts and notify user
        checkForPendingInboxDrafts(context: context)

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

        // 8.5. Persist shortcutIDs de legacy entities (one-shot por device).
        // Diferido a Task no-blocking para no añadir latencia al cold launch — el
        // único consumidor (AppEntities en Atajos) no se invoca en los primeros
        // segundos del launch. Sentinel garantiza idempotencia.
        Task { @MainActor in
            persistAppEntityShortcutIDsIfNeeded(context: context)
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
        observeRemoteStoreChanges()

        // 14. Observe iCloud account changes — detect mismatch if container was created without CloudKit
        observeICloudAccountChanges()

        // 15. Initialize CKSyncEngine for shared group data (separate groups store)
        SplitSyncManager.shared.setContext(context)
        SplitSyncManager.shared.initialize()

        // 16. Initialize Group Services (GC-03)
        GroupService.shared.setContext(context)
        GroupExpenseService.shared.setContext(context)
        GroupTransactionBridge.shared.setContext(context)

        // 16.5. Retry bridge operations that failed in a previous launch
        Task { @MainActor in
            await retryPendingBridges(context: context)
        }

        // Seed current iCloud user identity for groups and refresh local membership flags.
        Task { @MainActor in
            _ = try? await GroupUserIdentityService.shared.currentUserRecordName()
            await GroupService.shared.refreshCurrentUserFlags()
        }

        // 17. Initialize Group Notification Service (GC-06)
        GroupNotificationService.shared.setContext(context)

        // 17.5. One-time backfill of SplitShare.groupZoneID for existing shares
        migrateShareGroupZoneIDs(context: context)

        // 18. Initialize User Segment Service (GC-08)
        UserSegmentService.shared.setContext(context)
        UserSegmentService.shared.recalculate()

        // 19. Initialize Nudge Service (GC-09)
        NudgeService.shared.setContext(context)

        isInitialized = true

        // 19. Process deferred invite link (cold launch via universal link)
        if let pendingShareURL = deferredInviteShareURL {
            deferredInviteShareURL = nil
            Task { await acceptShareFromURL(pendingShareURL) }
        }
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
            NotificationCenter.default.post(name: .iCloudMismatchDetected, object: nil)
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
                    #if DEBUG
                    print("AppBootstrapper: Remote CloudKit change — trailing edge")
                    #endif
                }
            }
        }
    }

    // MARK: - One-Time Migrations

    /// Backfill SplitShare.groupZoneID for shares created before the field was added.
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
            let lookup = Dictionary(uniqueKeysWithValues: expenses.map { ($0.id, $0.groupZoneID) })
            for share in orphans {
                if let zone = lookup[share.expenseID], !zone.isEmpty {
                    share.groupZoneID = zone
                }
            }
            try context.save()
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
        let descriptor = FetchDescriptor<SplitExpense>(
            predicate: #Predicate { $0.bridgePending == true }
        )
        do {
            let pending = try context.fetch(descriptor)
            guard !pending.isEmpty else { return }
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
                    try GroupTransactionBridge.shared.bridgeExpense(expense, in: group, shouldSave: false)
                    expense.bridgePending = false
                    expense.bridgeAttempts = 0
                } catch {
                    logger.error("Bridge retry failed for \(expense.id, privacy: .public) (attempt \(expense.bridgeAttempts, privacy: .public)): \(error.localizedDescription, privacy: .public)")
                }
            }
            try context.save()
        } catch {
            logger.error("retryPendingBridges fetch failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Scene Phase Handlers

    /// Llamar cuando la app se activa (scenePhase == .active)
    func handleBecameActive(context: ModelContext) {
        // Apply any pending remote CloudKit changes on foreground resume
        sessionState.applyPendingChangesIfNeeded()

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
            AppRouter.shared.enqueue(.presentNewTransaction)
        case .voiceEntry:
            guard FeatureGateService.shared.canAccess(.voiceInput) else {
                AppRouter.shared.enqueue(.presentUpgradeSheet(.voice))
                return
            }
            if UserDefaults.standard.bool(forKey: AppPreferences.Keys.aiDataConsentAccepted) {
                AppRouter.shared.enqueue(.presentVoiceEntry)
            } else {
                AppRouter.shared.enqueue(.requestAIConsent(.voice))
            }
        case .imageEntry:
            guard FeatureGateService.shared.canAccess(.imageInput) else {
                AppRouter.shared.enqueue(.presentUpgradeSheet(.image))
                return
            }
            if UserDefaults.standard.bool(forKey: AppPreferences.Keys.aiDataConsentAccepted) {
                AppRouter.shared.enqueue(.presentImageEntry)
            } else {
                AppRouter.shared.enqueue(.requestAIConsent(.image))
            }
        }
    }

    /// Llamar cuando cambia needsExchangeRateReload
    func handleExchangeRateReloadRequest(container: ModelContainer) async {
        guard sessionState.needsExchangeRateReload else { return }
        await loadExchangeRates(context: container.mainContext)
        sessionState.needsExchangeRateReload = false
    }

    // MARK: - AppEntity shortcutID Migration

    /// One-shot pass to persist `shortcutID` UUIDs on legacy `Account` and `Subcategory`
    /// entities. Without this, SwiftData genera el UUID default al cargar pero no persiste
    /// hasta el siguiente save de la entity — cada cold launch regeneraría UUIDs distintos
    /// y los atajos guardados con UUID viejo caerían al legacy fallback (lookup por name).
    /// Sentinel `appEntityShortcutIDsMigratedV1` evita re-ejecución.
    private func persistAppEntityShortcutIDsIfNeeded(context: ModelContext) {
        let key = AppPreferences.Keys.appEntityShortcutIDsMigratedV1
        guard !UserDefaults.standard.bool(forKey: key) else { return }

        do {
            let accounts = try context.fetch(FetchDescriptor<Account>())
            let subcategories = try context.fetch(FetchDescriptor<Subcategory>())

            // Touch each entity to force SwiftData to mark it dirty and persist the default UUID.
            // Reading shortcutID is enough to materialize it; assigning to itself ensures the change
            // is tracked even if SwiftData would optimize away a pure read.
            for account in accounts { account.shortcutID = account.shortcutID }
            for subcategory in subcategories { subcategory.shortcutID = subcategory.shortcutID }

            try context.save()
            UserDefaults.standard.set(true, forKey: key)

            #if DEBUG
            print("AppBootstrapper: F4 persistAppEntityShortcutIDs — \(accounts.count) accounts + \(subcategories.count) subcategories migrated")
            #endif
        } catch {
            #if DEBUG
            print("AppBootstrapper: F4 persistAppEntityShortcutIDs error: \(error)")
            #endif
            // Do NOT mark sentinel — retry next launch.
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
            AppRouter.shared.enqueue(.showInviteError(
                String(localized: "groups.invite.linkInvalidDetail")
            ))
            return
        }

        #if DEBUG
        print("AppBootstrapper: Invite link received, CKShare URL: \(shareURL.absoluteString)")
        #endif

        if !isInitialized {
            deferredInviteShareURL = shareURL
            #if DEBUG
            print("AppBootstrapper: Deferring invite — not yet initialized")
            #endif
            return
        }

        Task { await acceptShareFromURL(shareURL) }
    }

    /// Acepta un CKShare a partir de su URL, reutilizando la lógica de segmentos del AppDelegate.
    private func acceptShareFromURL(_ shareURL: URL) async {
        do {
            let metadata = try await InviteLinkService.fetchShareMetadata(for: shareURL)

            let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")

            if !hasCompletedOnboarding && sessionState.onboardingMode != .groupInvite {
                await SplitSyncManager.shared.acceptShare(metadata: metadata, skipNavigation: true)
                let invite = InviteMetadata(
                    groupName: nil, groupIcon: nil, groupColor: nil, groupMembers: nil,
                    shareMetadata: metadata
                )
                AppRouter.shared.enqueue(.presentGroupInviteOnboarding(invite))
            } else if hasCompletedOnboarding
                && UserSegmentService.shared.hasRecalculatedAfterFirstImport
                && UserSegmentService.shared.currentSegment == .dormant {
                await SplitSyncManager.shared.acceptShare(metadata: metadata, skipNavigation: true)
                let invite = InviteMetadata(
                    groupName: nil, groupIcon: nil, groupColor: nil, groupMembers: nil,
                    shareMetadata: metadata
                )
                AppRouter.shared.enqueue(.presentGroupReconnect(invite))
            } else {
                await SplitSyncManager.shared.acceptShare(metadata: metadata)
            }
        } catch {
            logger.error("Failed to accept share from URL: \(error.localizedDescription, privacy: .public)")
            AppRouter.shared.enqueue(.showInviteError(
                String(localized: "groups.invite.linkInvalidDetail")
            ))
        }
    }

    // MARK: - Deep Link Deferral

    private func setOrDeferDeepLink(_ destination: DeepLinkDestination) {
        AppRouter.shared.enqueue(.navigate(destination))
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

        do {
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
            AppRouter.shared.enqueue(.presentTrialExpired)
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
        AppRouter.shared.enqueue(.presentDowngradeResolution)
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
            AppRouter.shared.enqueue(.showInboxAlert(notification))
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
        AppRouter.shared.enqueue(.navigate(.panel))
        if UserDefaults.standard.bool(forKey: AppPreferences.Keys.aiDataConsentAccepted) {
            AppRouter.shared.enqueue(.presentSharedImage(url))
        } else {
            AppRouter.shared.enqueue(.requestAIConsent(.image))
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
