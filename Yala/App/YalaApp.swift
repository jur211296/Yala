//
//  YalaApp.swift
//  Yala
//
//  Punto de entrada principal de la aplicación.
//

import StoreKit
import SwiftData
import SwiftUI
import TipKit
import UIKit

@main
struct YalaApp: App {

    @UIApplicationDelegateAdaptor(YalaAppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Clear default gray background for paged TabView
        UIView.appearance(whenContainedInInstancesOf: [UIPageViewController.self]).backgroundColor = .clear
        UIScrollView.appearance(whenContainedInInstancesOf: [UIPageViewController.self]).backgroundColor = .clear

        // Start observing CloudKit container events before the ModelContainer
        // fires its first .setup event. Idempotent — safe even if called again.
        MainActor.assumeIsolated {
            iCloudSyncService.shared.startObserving()
        }
    }

    /// ModelContainer compartido para toda la app.
    /// Dos configs: personal (CloudKit) + groups (local, synced por CKSyncEngine).
    var sharedModelContainer: ModelContainer = {
        do {
            let iCloudWasAvailable = SwiftDataConfiguration.isICloudAvailable()
            SwiftDataConfiguration.markContainerCloudKitState(iCloudWasAvailable)
            return try ModelContainer(
                for: SwiftDataConfiguration.schema,
                configurations: SwiftDataConfiguration.personalConfiguration,
                               SwiftDataConfiguration.groupsConfiguration
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
                .saturation(themeManager.resolved.mapsColorsToGrayscale ? 0 : 1)
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
                .environment(bootstrapper.appPreferences)
                .task {
                    try? Tips.configure([
                        .displayFrequency(.immediate)
                    ])
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
            } else if newPhase == .background {
                // F2: drop transient router intents when app backgrounds.
                // Persistence-backed intents re-emit on next .active via
                // AppBootstrapper.handleBecameActive().
                AppRouter.shared.resetTransients()
            }
        }
    }
}
