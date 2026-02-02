//
//  AppBootstrapper.swift
//  Yala
//
//  Centraliza la inicialización de servicios y tareas de arranque.
//  Resuelve ARCH-005: Inicialización dispersa en YalaApp.
//

import SwiftData
import SwiftUI

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

        // 7. Check for pending shared images
        checkForPendingSharedImage()

        // 8. Initialize budget alert service
        budgetAlertService.setContext(context)

        isInitialized = true
    }

    // MARK: - Scene Phase Handlers

    /// Llamar cuando la app se activa (scenePhase == .active)
    func handleBecameActive(context: ModelContext) {
        checkForPendingSharedImage()
        checkForPendingInboxDrafts(context: context)
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
            if UserDefaults.standard.bool(forKey: "enableVoiceInput") {
                sessionState.shouldShowVoiceEntry = true
            } else {
                #if DEBUG
                print("AppBootstrapper: voice-entry blocked - feature disabled")
                #endif
            }

        case "image-entry":
            if UserDefaults.standard.bool(forKey: "enableImageInput") {
                sessionState.shouldShowImageEntry = true
            } else {
                #if DEBUG
                print("AppBootstrapper: image-entry blocked - feature disabled")
                #endif
            }

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
}
