//
//  YalaApp.swift
//  Yala
//
//  Punto de entrada principal de la aplicación.
//

import StoreKit
import SwiftData
import SwiftUI
import UIKit

@main
struct YalaApp: App {

    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Clear default gray background for paged TabView
        UIView.appearance(whenContainedInInstancesOf: [UIPageViewController.self]).backgroundColor = .clear
        UIScrollView.appearance(whenContainedInInstancesOf: [UIPageViewController.self]).backgroundColor = .clear
    }

    /// ModelContainer compartido para toda la app.
    var sharedModelContainer: ModelContainer = {
        do {
            return try ModelContainer(
                for: SwiftDataConfiguration.schema,
                configurations: SwiftDataConfiguration.configuration
            )
        } catch {
            fatalError("Error al inicializar ModelContainer de Yala: \(error)")
        }
    }()

    @State private var themeManager = ThemeManager()

    /// Bootstrapper centralizado para inicialización y servicios
    private let bootstrapper = AppBootstrapper.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(themeManager.userChoice == .system ? nil : themeManager.resolved.baseColorScheme)
                .tint(themeManager.resolved.accent)
                .environment(\.yalaTheme, themeManager.resolved)
                .environment(themeManager)
                .environment(bootstrapper.sessionState)
                .environment(bootstrapper.currencyConverter)
                .environment(bootstrapper.exchangeRateService)
                .environment(bootstrapper.imageVisionService)
                .environment(bootstrapper.voiceTranscriptionService)
                .environment(bootstrapper.transcriptionParserService)
                .environment(bootstrapper.draftService)
                .environment(bootstrapper.entityDeletionService)
                .environment(bootstrapper.transactionService)
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
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                bootstrapper.handleBecameActive(context: sharedModelContainer.mainContext)
            }
        }
    }
}
