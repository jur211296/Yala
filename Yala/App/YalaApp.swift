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

        let configuration = ModelConfiguration("YalaModel")

        do {
            return try ModelContainer(
                for: schema,
                configurations: configuration
            )
        } catch {
            fatalError("Error al inicializar ModelContainer de Yala: \(error)")
        }
    }()

    @AppStorage("userTheme") private var userThemeRaw: Int = AppTheme.system.rawValue

    /// Bootstrapper centralizado para inicialización y servicios
    private let bootstrapper = AppBootstrapper.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(AppTheme(rawValue: userThemeRaw)?.colorScheme)
                .task {
                    await bootstrapper.bootstrap(container: sharedModelContainer)
                }
                .onChange(of: bootstrapper.sessionState.needsExchangeRateReload) { _, needsReload in
                    if needsReload {
                        Task {
                            await bootstrapper.handleExchangeRateReloadRequest(container: sharedModelContainer)
                        }
                    }
                }
                .onOpenURL { url in
                    bootstrapper.handleIncomingURL(url)
                }
        }
        .modelContainer(sharedModelContainer)
        .environment(bootstrapper.sessionState)
        .environment(bootstrapper.currencyConverter)
        .environment(bootstrapper.exchangeRateService)
        .environment(bootstrapper.imageVisionService)
        .environment(bootstrapper.voiceTranscriptionService)
        .environment(bootstrapper.transcriptionParserService)
        .environment(bootstrapper.draftService)
        .environment(bootstrapper.entityDeletionService)
        .environment(bootstrapper.transactionService)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                bootstrapper.handleBecameActive()
            }
        }
    }
}
