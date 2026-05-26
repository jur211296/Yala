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
    /// Branded metadata del invite (n/i/c/m del URL) capturada cuando el invite
    /// llega antes de que bootstrap termine. Drenada junto con `deferredInviteShareURL`.
    var deferredInviteBrandedMetadata: InviteLinkService.BrandedMetadata = .empty
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
            if decision == .waitForHook {
                waitedForSync = true
                _ = await iCloudSyncService.shared.forceFetchAndWait(timeout: 15)
            }
            let waitDuration = Date.now.timeIntervalSince(started)
            migrateShortcutIDsAndRebuildCSVMirrors(
                context: context,
                waitedForSync: waitedForSync,
                waitDuration: waitDuration
            )
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

        // 14.5 (M6). Observe TX imports from CKSync personal — autodelete drafts pendientes Caso A
        // cuyo splitExpenseID ya tiene TX cuenta real (race resuelto por sync).
        observeTransactionsImportedFromSync(context: context)

        // 15. Initialize CKSyncEngine for shared group data (separate groups store)
        SplitSyncManager.shared.setContext(context)
        SplitSyncManager.shared.initialize()

        // 16. Initialize Group Services (GC-03)
        GroupService.shared.setContext(context)
        GroupExpenseService.shared.setContext(context)
        GroupTransactionBridge.shared.setContext(context)

        // 16.4. Cleanup duplicate SplitGroups from CloudKit sync race.
        // Runs sync (not Task) so consumers downstream see canonical groups only.
        SplitGroupDeduplicationService.deduplicateSplitGroups(in: context)

        // 16.4.5. Safety net: hidden groups + removed-self cleanup que el observer pudo perder.
        // Corre ANTES de retryPendingBridges para que el bridge guard `isHiddenForAll` aplique.
        Task { @MainActor in
            await freezeOrphanedGroupsAndRemovedSelves(context: context)
        }

        // 16.4.8. Reconciliar transfer pairs huérfanos (F1 legacy CSV imports + F3 collisions + F5 partner missing).
        // Pure-logic + telemetría. Idempotente — re-launches sin orphans son no-op.
        // Task-wrapped (no sync) para no bloquear cold launch en DBs grandes; downstream steps
        // (16.5 retryPendingBridges, etc.) no dependen del resultado.
        Task { @MainActor in
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
            await reconcileCurrentUserDisplayNameIfNeeded()
        }

        // 16.7. Retry persistente de `leaveShare` que falló por network en sesión previa.
        Task { @MainActor in
            await retryPendingLeaveShares()
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
            let pendingBranded = deferredInviteBrandedMetadata
            deferredInviteBrandedMetadata = .empty
            Task { await acceptShareFromURL(pendingShareURL, brandedMetadata: pendingBranded) }
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
            try context.save()
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
        waitDuration: TimeInterval
    ) {
        let sentinelKey = AppPreferences.Keys.appEntityShortcutIDsMigratedV3
        let regenKey = AppPreferences.Keys.appEntityShortcutIDsRegeneratedV3
        let attemptsKey = AppPreferences.Keys.appEntityShortcutIDsBackfillAttemptsV3
        let maxAttempts = 5
        guard !UserDefaults.standard.bool(forKey: sentinelKey) else { return }

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

            try context.save()

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
            AppRouter.shared.enqueue(.showInviteError(
                String(localized: "groups.invite.linkInvalidDetail")
            ))
            return
        }

        let brandedMetadata = InviteLinkService.extractMetadata(from: url)

        #if DEBUG
        print("AppBootstrapper: Invite link received, CKShare URL: \(shareURL.absoluteString) brandedName=\(brandedMetadata.name ?? "nil")")
        #endif

        if !isInitialized {
            deferredInviteShareURL = shareURL
            deferredInviteBrandedMetadata = brandedMetadata
            #if DEBUG
            print("AppBootstrapper: Deferring invite — not yet initialized")
            #endif
            return
        }

        Task { await acceptShareFromURL(shareURL, brandedMetadata: brandedMetadata) }
    }

    /// A12: Decisión de routing para un share aceptado. Pure function — testeable.
    /// Replica la lógica simétrica con `YalaAppDelegate.userDidAcceptCloudKitShareWith`.
    enum InviteRouteDecision: Equatable {
        /// Invitado nuevo (sin onboarding completo y NO mid-invite): acepta eagerly + muestra invite onboarding.
        case acceptAndShowInviteOnboarding
        /// Todos los demás casos: muestra reconnect con el mode apropiado.
        case showReconnect(mode: ReconnectMode)
    }

    /// Decide el routing tras leer metadata del share + estado local del grupo.
    /// Orden de evaluación: isHiddenForAll (CKShare custom key) > isArchived (CKShare custom key) > member status local > onboarding.
    static func inviteRouteDecision(
        hasCompletedOnboarding: Bool,
        onboardingMode: OnboardingMode,
        isHiddenForAll: Bool = false,
        isArchived: Bool = false,
        currentMemberStatus: SplitMemberStatus? = nil
    ) -> InviteRouteDecision {
        if isHiddenForAll { return .showReconnect(mode: .deletedForAll) }
        if isArchived { return .showReconnect(mode: .archived) }
        if let status = currentMemberStatus {
            switch status {
            case .active: return .showReconnect(mode: .alreadyMember)
            case .pendingApproval: return .showReconnect(mode: .pendingDuplicate)
            case .rejected: return .showReconnect(mode: .rejectedRetry)
            case .left: return .showReconnect(mode: .leftRetry)
            case .removed: return .showReconnect(mode: .removedRetry)
            }
        }
        if !hasCompletedOnboarding && onboardingMode != .groupInvite {
            return .acceptAndShowInviteOnboarding
        }
        return .showReconnect(mode: .standardReconnect)
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

            let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: AppPreferences.Keys.hasCompletedOnboarding)
            // CKShare custom keys (escritas por owner en setArchived / softDelete). Race-tolerant:
            // si key ausente (sync remoto aún no propagó al CKShare custom key) → false →
            // standardReconnect; CKSyncEngine posterior actualiza el SplitGroup record local con
            // el flag autoritativo vía F2 propagation (GroupMetaField.isArchived/isHiddenForAll).
            let isHiddenForAll = (metadata.share[CKShareCustomKey.isHiddenForAll] as? Int) == 1
            let isArchived = (metadata.share[CKShareCustomKey.isArchived] as? Int) == 1
            // Member status local (si ya hubo accept previo en este device).
            let zoneName = metadata.share.recordID.zoneID.zoneName
            let currentMemberStatus = SplitSyncManager.shared.currentMemberStatus(zoneName: zoneName)

            let decision = Self.inviteRouteDecision(
                hasCompletedOnboarding: hasCompletedOnboarding,
                onboardingMode: sessionState.onboardingMode,
                isHiddenForAll: isHiddenForAll,
                isArchived: isArchived,
                currentMemberStatus: currentMemberStatus
            )

            switch decision {
            case .acceptAndShowInviteOnboarding:
                let invite = InviteMetadata(
                    groupName: brandedMetadata.name,
                    groupIcon: brandedMetadata.icon,
                    groupColor: brandedMetadata.color,
                    groupMembers: brandedMetadata.members,
                    shareMetadata: metadata,
                    mode: .standardReconnect
                )
                await SplitSyncManager.shared.acceptShare(metadata: metadata, skipNavigation: true)
                AppRouter.shared.enqueue(.presentGroupInviteOnboarding(invite))
            case .showReconnect(let mode):
                // NO acceptShare eagerly — `GroupReconnectView.onJoin` lo invoca al confirmar (según mode).
                let invite = InviteMetadata(
                    groupName: brandedMetadata.name,
                    groupIcon: brandedMetadata.icon,
                    groupColor: brandedMetadata.color,
                    groupMembers: brandedMetadata.members,
                    shareMetadata: metadata,
                    mode: mode
                )
                AppRouter.shared.enqueue(.presentGroupReconnect(invite))
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
