//
//  AppBootstrapper.swift
//  Yala
//
//  Centraliza la inicialización de servicios y tareas de arranque.
//  Resuelve ARCH-005: Inicialización dispersa en YalaApp.
//

import CloudKit
import CoreData
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

    // MARK: - Deferred Panel Action

    enum DeferredPanelAction {
        case newTransaction
        case voiceEntry
        case imageEntry
    }

    // MARK: - State

    private(set) var isInitialized = false
    var deferredInboxNotification: PendingInboxNotification?
    var deferredSharedImageURL: URL?
    var deferredPanelAction: DeferredPanelAction?
    var deferredInviteShareURL: URL?
    private var controlActionTask: Task<Void, Never>?
    private var subscriptionCheckTask: Task<Void, Never>?
    private var remoteChangeTask: Task<Void, Never>?
    private var remoteChangeLeadingFired = false
    private var lastNotificationCheckDate = Date.distantPast
    private var lastProcessDuePaymentsDate = Date.distantPast

    /// Whether a fullScreenCover (splash, Face ID, or InboxAlertModal) is blocking sheet presentation
    private var isUIBlocked: Bool {
        !sessionState.isSplashDismissed || BiometricAuthService.shared.isLocked || !sessionState.pendingInboxNotification.isEmpty
    }

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

        // 0. Sync preferences from iCloud (must be FIRST — other services read these)
        PreferenceSyncService.shared.bootstrap()

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

        // 9. Update widget cache
        WidgetDataCache.updateCache(context: context)

        // 10. Register background tasks
        BackgroundTaskManager.shared.registerTasks()

        // 11. Set model container for background tasks and schedule first report task
        BackgroundTaskManager.shared.setModelContainer(container)
        BackgroundTaskManager.shared.scheduleNextReportTask(context: context)

        // 12. Check if any report notifications should be sent now (app launch case)
        await ReportNotificationService.shared.sendDueReports(context: context)

        // 13. Observe CloudKit remote changes to auto-refresh UI
        observeRemoteStoreChanges()

        // 14. Initialize CKSyncEngine for shared group data (separate groups store)
        SplitSyncManager.shared.setContext(context)
        SplitSyncManager.shared.initialize()

        // 15. Initialize Group Services (GC-03)
        GroupService.shared.setContext(context)
        GroupExpenseService.shared.setContext(context)
        GroupTransactionBridge.shared.setContext(context)

        // 16. Initialize Group Notification Service (GC-06)
        GroupNotificationService.shared.setContext(context)

        // 16.5. One-time backfill of SplitShare.groupZoneID for existing shares
        migrateShareGroupZoneIDs(context: context)

        // 17. Initialize User Segment Service (GC-08)
        UserSegmentService.shared.setContext(context)
        UserSegmentService.shared.recalculate()

        // 18. Initialize Nudge Service (GC-09)
        NudgeService.shared.setContext(context)

        isInitialized = true

        // 19. Process deferred invite link (cold launch via universal link)
        if let pendingShareURL = deferredInviteShareURL {
            deferredInviteShareURL = nil
            Task { await acceptShareFromURL(pendingShareURL) }
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

    // MARK: - Scene Phase Handlers

    /// Llamar cuando la app se activa (scenePhase == .active)
    func handleBecameActive(context: ModelContext) {
        // Apply any pending remote CloudKit changes on foreground resume
        sessionState.applyPendingChangesIfNeeded()

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

        // Delay control action check — inbox notification fires at 0.3s,
        // so we wait 0.5s to know if UI will be blocked.
        // Cancel previous task to avoid accumulation on rapid app switches.
        controlActionTask?.cancel()
        controlActionTask = Task {
            do {
                try await Task.sleep(for: .milliseconds(500))
            } catch {
                return
            }
            checkForPendingControlAction()
        }

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

    /// App Group identifier from Info.plist
    private var appGroupID: String {
        Bundle.main.object(forInfoDictionaryKey: "APP_GROUP_IDENTIFIER") as? String ?? "group.com.jurgenschmidt.yala"
    }

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
        case "new-transaction":
            dispatchOrDefer(.newTransaction)
        case "voice-entry":
            dispatchOrDefer(.voiceEntry)
        case "image-entry":
            dispatchOrDefer(.imageEntry)
        default:
            #if DEBUG
            print("AppBootstrapper: Unknown Control Center action: \(action)")
            #endif
        }
    }

    /// Defers action if UI is blocked, otherwise executes immediately.
    private func dispatchOrDefer(_ action: DeferredPanelAction) {
        if isUIBlocked {
            deferredPanelAction = action
            #if DEBUG
            print("AppBootstrapper: Deferring \(action) — UI blocked")
            #endif
        } else {
            executeAction(action)
        }
    }

    /// Executes a panel action, respecting feature toggles and Pro gates.
    private func executeAction(_ action: DeferredPanelAction) {
        switch action {
        case .newTransaction:
            sessionState.shouldShowNewTransaction = true
        case .voiceEntry:
            guard UserDefaults.standard.bool(forKey: "voiceInputEnabled") else { return }
            if FeatureGateService.shared.canAccess(.voiceInput) {
                sessionState.shouldShowVoiceEntry = true
            } else {
                sessionState.shouldShowUpgradeForVoice = true
            }
        case .imageEntry:
            guard UserDefaults.standard.bool(forKey: "imageInputEnabled") else { return }
            if FeatureGateService.shared.canAccess(.imageInput) {
                sessionState.shouldShowImageEntry = true
            } else {
                sessionState.shouldShowUpgradeForImage = true
            }
        }
    }

    /// Llamar cuando cambia needsExchangeRateReload
    func handleExchangeRateReloadRequest(container: ModelContainer) async {
        guard sessionState.needsExchangeRateReload else { return }
        await loadExchangeRates(context: container.mainContext)
        sessionState.needsExchangeRateReload = false
    }

    // MARK: - Deep Link Handling

    /// URL Scheme read from Info.plist (set via Build Settings)
    private var urlScheme: String {
        Bundle.main.object(forInfoDictionaryKey: "URL_SCHEME") as? String ?? "yala"
    }

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
            // Delay to ensure PanelView is mounted and observing before flags are set
            // Covers cold launch from Share Extension where onOpenURL fires before first render
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(500))
                let imageURLs = SharedContainerService.pendingImageURLs()
                guard let firstImageURL = imageURLs.first else { return }

                if self.isUIBlocked {
                    self.deferredSharedImageURL = firstImageURL
                    #if DEBUG
                    print("AppBootstrapper: Deferring shared image — UI blocked")
                    #endif
                } else {
                    self.sessionState.pendingSharedImageURL = firstImageURL
                    self.sessionState.shouldShowSharedImage = true
                }
            }

        case "voice-entry":
            dispatchOrDefer(.voiceEntry)

        case "image-entry":
            dispatchOrDefer(.imageEntry)

        case "new-transaction":
            dispatchOrDefer(.newTransaction)

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
            #if DEBUG
            print("AppBootstrapper: Invalid invite link: \(url.absoluteString)")
            #endif
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
                sessionState.shouldShowGroupInviteOnboarding = true
            } else if hasCompletedOnboarding && UserSegmentService.shared.currentSegment == .dormant {
                await SplitSyncManager.shared.acceptShare(metadata: metadata, skipNavigation: true)
                sessionState.shouldShowGroupReconnect = true
            } else {
                await SplitSyncManager.shared.acceptShare(metadata: metadata)
            }
        } catch {
            #if DEBUG
            print("AppBootstrapper: Failed to accept share from URL: \(error)")
            #endif
            sessionState.inviteErrorDetail = "\(error)"
            sessionState.showInviteError = true
        }
    }

    // MARK: - Deep Link Deferral

    /// Sets deep link immediately if splash is dismissed, otherwise defers until splash ends.
    private func setOrDeferDeepLink(_ destination: DeepLinkDestination) {
        if sessionState.isSplashDismissed {
            sessionState.deepLinkDestination = destination
        } else {
            sessionState.deferredDeepLink = destination
        }
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
            sessionState.shouldShowTrialExpired = true
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
        sessionState.shouldShowDowngradeResolution = true
    }

    /// Reset Pro theme to System if user downgraded from Pro
    private func resetProThemeIfNeeded() {
        guard !FeatureGateService.shared.isProUser else { return }

        let currentTheme = AppTheme(rawValue: UserDefaults.standard.integer(forKey: "userTheme")) ?? .system
        if currentTheme.isPro {
            UserDefaults.standard.set(AppTheme.system.rawValue, forKey: "userTheme")
            #if DEBUG
            print("AppBootstrapper: Reset Pro theme '\(currentTheme.label)' to System")
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

    private func checkForPendingInboxDrafts(context: ModelContext) {
        let lastCheck = UserDefaults.standard.object(forKey: "lastInboxDraftCheckDate") as? Date
                        ?? Date.distantPast

        var notification = PendingInboxNotification()

        // Query 1: Scheduled payments
        let scheduledDescriptor = FetchDescriptor<InboxDraft>(
            predicate: #Predicate<InboxDraft> { draft in
                draft.sourceTypeRaw == "scheduledPayment" &&
                draft.statusRaw == "pending" &&
                draft.createdAt > lastCheck
            }
        )

        // Query 2: Subscriptions
        let subscriptionDescriptor = FetchDescriptor<InboxDraft>(
            predicate: #Predicate<InboxDraft> { draft in
                draft.sourceTypeRaw == "subscription" &&
                draft.statusRaw == "pending" &&
                draft.createdAt > lastCheck
            }
        )

        // Query 3: Automations (applePay + automation)
        let automationDescriptor = FetchDescriptor<InboxDraft>(
            predicate: #Predicate<InboxDraft> { draft in
                (draft.sourceTypeRaw == "applePay" || draft.sourceTypeRaw == "automation") &&
                draft.statusRaw == "pending" &&
                draft.createdAt > lastCheck
            }
        )

        do {
            notification.scheduledPayments = try context.fetchCount(scheduledDescriptor)
            notification.subscriptions = try context.fetchCount(subscriptionDescriptor)
            notification.automations = try context.fetchCount(automationDescriptor)
        } catch {
            #if DEBUG
            print("AppBootstrapper: Error checking inbox drafts: \(error)")
            #endif
        }

        if !notification.isEmpty {
            let delay: Double = 0.3
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(delay))
                guard let self else { return }
                if self.isUIBlocked {
                    self.deferredInboxNotification = notification
                } else {
                    self.sessionState.pendingInboxNotification = notification
                }
            }
        }

        UserDefaults.standard.set(Date.now, forKey: "lastInboxDraftCheckDate")
    }

    private func seedDefaultNotifications(context: ModelContext) {
        // Only seed for existing users who completed onboarding before notification feature
        guard UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") else { return }
        NotificationService.shared.seedDefaultNotificationsIfNeeded(context: context)
    }

    /// Only called from bootstrap() for cold launch without deep link.
    private func checkForPendingSharedImage() {
        let imageURLs = SharedContainerService.pendingImageURLs()
        guard let firstImageURL = imageURLs.first else { return }

        // On cold launch, always defer — splash is still showing
        if isUIBlocked {
            deferredSharedImageURL = firstImageURL
            #if DEBUG
            print("AppBootstrapper: Deferring shared image (cold launch) — UI blocked")
            #endif
        } else {
            sessionState.pendingSharedImageURL = firstImageURL
            sessionState.shouldShowSharedImage = true
        }
    }

    // MARK: - Deferred Action Resolution

    /// Resolves deferred actions after UI blockers (Face ID / InboxAlertModal) dismiss.
    /// Called from ContentView on unlock and inbox dismiss, and from PanelView on image dismiss.
    func showDeferredActionsIfNeeded() {
        // Shared image takes priority (explicit user action from Share Extension)
        if let url = deferredSharedImageURL {
            deferredSharedImageURL = nil
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.3))
                sessionState.pendingSharedImageURL = url
                sessionState.shouldShowSharedImage = true
            }
            // deferredPanelAction will resolve on ImageSelectionView dismiss
            return
        }

        guard let action = deferredPanelAction else { return }
        deferredPanelAction = nil
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.3))
            self.executeAction(action)
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
