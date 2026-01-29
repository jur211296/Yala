//
//  YalaApp.swift
//  Yala
//
//  Punto de entrada principal de la aplicación.
//

import StoreKit
import SwiftData
import SwiftUI

@main
struct YalaApp: App {

    @Environment(\.scenePhase) private var scenePhase

    /// ModelContainer compartido para toda la app.
    /// Incluye todas las entidades del modelo de datos.
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Category.self,
            Subcategory.self,
            Tag.self,
            Account.self,
            TransactionItem.self,
            Budget.self,
            ExchangeRate.self,
            FavoritePayment.self,
            ScheduledPayment.self,
            InboxDraft.self,
            MerchantMemory.self,
            NotificationItem.self,
        ])

        // Nombre lógico del contenedor / base de datos
        let configuration = ModelConfiguration("YalaModel")

        do {
            return try ModelContainer(
                for: schema,
                configurations: configuration
            )
        } catch {
            // En una app final deberías manejar el error de forma más robusta.
            fatalError("Error al inicializar ModelContainer de Yala: \(error)")
        }
    }()

    @AppStorage("userTheme") private var userThemeRaw: Int = AppTheme.system.rawValue

    private var sessionState = SessionState.shared
    private var currencyConverter = CurrencyConverter.shared
    private var exchangeRateService = ExchangeRateService.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(AppTheme(rawValue: userThemeRaw)?.colorScheme)
                .task {
                    // Initialize notification delegate early (to show in foreground)
                    _ = NotificationService.shared
                    // Update exchange rates on app launch
                    await loadExchangeRates()
                    // Load subscription status
                    await loadSubscriptionStatus()
                    // Process due scheduled payments (create inbox drafts)
                    processDueScheduledPayments()
                    // Seed default notifications if needed
                    seedDefaultNotifications()
                    // Check for pending shared images on launch
                    checkForPendingSharedImage()
                }
                .onChange(of: sessionState.needsExchangeRateReload) { _, needsReload in
                    if needsReload {
                        Task {
                            await loadExchangeRates()
                            sessionState.needsExchangeRateReload = false
                        }
                    }
                }
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
        }
        // Adjunta el contenedor de modelos a la escena principal.
        .modelContainer(sharedModelContainer)
        .environment(sessionState)
        .environment(currencyConverter)
        .environment(exchangeRateService)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                checkForPendingSharedImage()
            }
        }
    }

    /// Load subscription status and sync to SessionState
    private func loadSubscriptionStatus() async {
        let store = StoreKitManager.shared
        await store.loadProducts()
        await store.updateSubscriptionStatus()
        sessionState.isProUser = store.isProUser
    }

    /// Load exchange rates (used on app launch and after data wipe)
    private func loadExchangeRates() async {
        let context = sharedModelContainer.mainContext

        // First get today's rate
        await ExchangeRateService.shared.updateTodayIfNeeded(context: context)

        // Then preload historical data if needed (first launch or after data wipe)
        await ExchangeRateService.shared.preloadHistoricalIfNeeded(context: context)

        // Update any transactions with provisional exchange rates
        await TransactionUpdateService.updateProvisionalTransactions(context: context)
    }

    /// Handle incoming URL from Share Extension and App Shortcuts
    /// Note: In SwiftUI, onOpenURL doesn't provide source app info.
    /// We validate that features are enabled before activating them.
    private func handleIncomingURL(_ url: URL) {
        guard url.scheme == "yala" else { return }

        #if DEBUG
        print("YalaApp: Received deep link: \(url.absoluteString)")
        #endif

        switch url.host {
        case "shared-image":
            // Share extension - always allowed
            checkForPendingSharedImage()
        case "voice-entry":
            // Only activate if voice input is enabled in settings
            if UserDefaults.standard.bool(forKey: "enableVoiceInput") {
                sessionState.shouldShowVoiceEntry = true
            } else {
                #if DEBUG
                print("YalaApp: voice-entry deep link blocked - feature disabled")
                #endif
            }
        case "image-entry":
            // Only activate if image input is enabled in settings
            if UserDefaults.standard.bool(forKey: "enableImageInput") {
                sessionState.shouldShowImageEntry = true
            } else {
                #if DEBUG
                print("YalaApp: image-entry deep link blocked - feature disabled")
                #endif
            }
        default:
            #if DEBUG
            print("YalaApp: Unknown deep link host: \(url.host ?? "nil")")
            #endif
        }
    }

    /// Process due scheduled payments and create inbox drafts
    private func processDueScheduledPayments() {
        let context = sharedModelContainer.mainContext
        let draftsCreated = ScheduledPaymentDraftService.processDuePayments(context: context)
        if draftsCreated > 0 {
            // Delay to show alert after splash screen dismisses
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                sessionState.pendingScheduledDraftsCount = draftsCreated
            }
        }
    }

    /// Check for pending shared images and trigger UI flow
    private func checkForPendingSharedImage() {
        let imageURLs = SharedContainerService.pendingImageURLs()
        guard let firstImageURL = imageURLs.first else {
            sessionState.hasPendingSharedImage = false
            sessionState.pendingSharedImageURL = nil
            return
        }

        // Set the pending image URL - PanelView will observe and show ImageSelectionView
        sessionState.pendingSharedImageURL = firstImageURL
        sessionState.hasPendingSharedImage = true
    }

    /// Seed default notifications if none exist
    /// Only runs for existing users who already completed onboarding (pre-notification feature)
    @MainActor
    private func seedDefaultNotifications() {
        // Don't seed if onboarding hasn't completed - onboarding will create notifications
        guard UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") else { return }

        let context = sharedModelContainer.mainContext
        NotificationService.shared.seedDefaultNotificationsIfNeeded(context: context)
    }
}
