//
//  AppBootstrapper.swift
//  Yala
//
//  Centraliza la inicialización de servicios y tareas de arranque.
//  Resuelve ARCH-005: Inicialización dispersa en YalaApp.
//

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

    // MARK: - State

    private(set) var isInitialized = false

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

        // 6.5. Cancel any old scheduled dynamic notifications (reports)
        // These use background tasks now, not iOS scheduling
        await NotificationService.shared.cancelDynamicNotifications(context: context)

        // 6.6. Ensure static notifications are scheduled (handles reinstall/update case)
        await ensureNotificationsScheduled(context: context)

        // 7. Check for pending shared images
        checkForPendingSharedImage()

        // 8. Initialize budget alert service
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

        isInitialized = true
    }

    // MARK: - Scene Phase Handlers

    /// Llamar cuando la app se activa (scenePhase == .active)
    func handleBecameActive(context: ModelContext) {
        // Check for pending Control Center action first
        checkForPendingControlAction()

        checkForPendingSharedImage()
        checkForPendingInboxDrafts(context: context)

        // Verify and reschedule notifications if needed
        Task {
            await ensureNotificationsScheduled(context: context)
        }

        // Check if any report notifications should be sent now
        // This handles the case where user opens app during the notification window
        Task {
            await ReportNotificationService.shared.sendDueReports(context: context)
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

        // Process the action as if it were a deep link
        switch action {
        case "panel":
            sessionState.deepLinkDestination = .panel

        case "new-transaction":
            sessionState.shouldShowNewTransaction = true

        case "voice-entry":
            if UserDefaults.standard.bool(forKey: "voiceInputEnabled") {
                if FeatureGateService.shared.canAccess(.voiceInput) {
                    sessionState.shouldShowVoiceEntry = true
                } else {
                    sessionState.shouldShowUpgradeForVoice = true
                }
            }

        case "image-entry":
            if UserDefaults.standard.bool(forKey: "imageInputEnabled") {
                if FeatureGateService.shared.canAccess(.imageInput) {
                    sessionState.shouldShowImageEntry = true
                } else {
                    sessionState.shouldShowUpgradeForImage = true
                }
            }

        default:
            #if DEBUG
            print("AppBootstrapper: Unknown Control Center action: \(action)")
            #endif
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

    /// Procesa URLs entrantes (deep links)
    func handleIncomingURL(_ url: URL) {
        guard url.scheme == urlScheme else { return }

        #if DEBUG
        print("AppBootstrapper: Received deep link: \(url.absoluteString)")
        #endif

        switch url.host {
        case "shared-image":
            checkForPendingSharedImage()

        case "voice-entry":
            if UserDefaults.standard.bool(forKey: "voiceInputEnabled") {
                // Check Pro gate
                if FeatureGateService.shared.canAccess(.voiceInput) {
                    sessionState.shouldShowVoiceEntry = true
                } else {
                    sessionState.shouldShowUpgradeForVoice = true
                    #if DEBUG
                    print("AppBootstrapper: voice-entry blocked - Pro feature")
                    #endif
                }
            } else {
                #if DEBUG
                print("AppBootstrapper: voice-entry blocked - feature disabled")
                #endif
            }

        case "image-entry":
            if UserDefaults.standard.bool(forKey: "imageInputEnabled") {
                // Check Pro gate
                if FeatureGateService.shared.canAccess(.imageInput) {
                    sessionState.shouldShowImageEntry = true
                } else {
                    sessionState.shouldShowUpgradeForImage = true
                    #if DEBUG
                    print("AppBootstrapper: image-entry blocked - Pro feature")
                    #endif
                }
            } else {
                #if DEBUG
                print("AppBootstrapper: image-entry blocked - feature disabled")
                #endif
            }

        case "new-transaction":
            sessionState.shouldShowNewTransaction = true

        case "panel":
            sessionState.deepLinkDestination = .panel

        case "statistics":
            // Check for path like statistics/records or statistics/categories
            if url.pathComponents.contains("records") {
                sessionState.deepLinkDestination = .records
            } else if url.pathComponents.contains("categories") {
                sessionState.deepLinkDestination = .categories
            } else {
                sessionState.deepLinkDestination = .statistics
            }

        case "planning":
            sessionState.deepLinkDestination = .planning

        case "budgets":
            sessionState.deepLinkDestination = .budgets

        default:
            #if DEBUG
            print("AppBootstrapper: Unknown deep link host: \(url.host ?? "nil")")
            #endif
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
        await store.updateSubscriptionStatus()
        sessionState.isProUser = store.isProUser

        // Sync to App Group for widgets
        store.syncToAppGroup()

        // Check for downgrade (user was Pro but no longer is)
        checkForDowngrade()
    }

    /// Check if user has downgraded from Pro and needs to resolve excess items
    private func checkForDowngrade() {
        let store = StoreKitManager.shared

        guard store.justDowngraded else { return }

        #if DEBUG
        print("AppBootstrapper: Detected downgrade from Pro to Free")
        #endif

        // Reset premium app icon if needed
        resetPremiumIconIfNeeded()

        // Mark that we need to show downgrade resolution
        // The actual resolution sheet is shown from ContentView which has access to data
        sessionState.shouldShowDowngradeResolution = true
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                self?.sessionState.pendingInboxNotification = notification
            }
        }

        UserDefaults.standard.set(Date(), forKey: "lastInboxDraftCheckDate")
    }

    private func seedDefaultNotifications(context: ModelContext) {
        // Only seed for existing users who completed onboarding before notification feature
        guard UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") else { return }
        NotificationService.shared.seedDefaultNotificationsIfNeeded(context: context)
    }

    private func checkForPendingSharedImage() {
        let imageURLs = SharedContainerService.pendingImageURLs()
        guard let firstImageURL = imageURLs.first else {
            sessionState.hasPendingSharedImage = false
            sessionState.pendingSharedImageURL = nil
            return
        }

        sessionState.pendingSharedImageURL = firstImageURL
        sessionState.hasPendingSharedImage = true
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

        // Check scheduled payment notifications
        ScheduledPaymentNotificationService.shared.setContext(context)
        await ScheduledPaymentNotificationService.shared.checkAndNotifyOverduePayments()
        await ScheduledPaymentNotificationService.shared.checkAndNotifyDuePayments()
        await ScheduledPaymentNotificationService.shared.checkAndNotifyUpcomingPayments()

        // Cleanup old tracker entries
        ScheduledPaymentNotificationTracker.shared.cleanupOldEntries()
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
