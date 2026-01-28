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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(AppTheme(rawValue: userThemeRaw)?.colorScheme)
                .task {
                    // Update exchange rates on app launch
                    await loadExchangeRates()
                    // Load subscription status
                    await loadSubscriptionStatus()
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

    /// Handle incoming URL from Share Extension
    private func handleIncomingURL(_ url: URL) {
        guard url.scheme == "yala" else { return }

        if url.host == "shared-image" {
            checkForPendingSharedImage()
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
}
