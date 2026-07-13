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
            // Unit tests (isRunningTests): el host NO arranca el observer de CloudKit.
            // Los tests usan ModelContext aislados (makeTestContext) o pure-logic.
            // UI tests (isUITesting) SÍ necesitan el ciclo normal → no se gatean.
            if !SwiftDataConfiguration.isRunningTests {
                iCloudSyncService.shared.startObserving()
            }

            // UI-test: aplicar reset/pro/skip-onboarding ANTES del primer render para
            // que hasCompletedOnboarding ya esté resuelto cuando ContentView evalúa
            // checkInitialSyncState. Hacerlo en el .task de bootstrap competía con ese
            // .task y dejaba la app en Welcome Hero. No-op en release (isActive == false).
            #if DEBUG
            if UITestHooks.isActive {
                bootstrapper.applyUITestHooksEarly(context: sharedModelContainer.mainContext)
            }
            #endif
        }
    }

    /// ModelContainer compartido para toda la app.
    /// Tres configs: personal (CloudKit) + groups (local, synced por CKSyncEngine) +
    /// sync-meta (`SyncIdentity` local, nunca CloudKit — Modo Nube I2).
    /// Bajo unit tests `personalConfiguration`/`groupsConfiguration` devuelven stores
    /// in-memory con `cloudKitDatabase: .none` (sin mirror CloudKit), así que crear este
    /// container en el host de tests es barato y NO toca CloudKit.
    var sharedModelContainer: ModelContainer = {
        do {
            // H4: si el cierre de sesión en `.cloud` dejó armado el wipe, ejecutarlo AHORA
            // (pre-mount) — borra archivos de los stores personal+sync-meta y devuelve el
            // device a `.icloud` fresh ANTES de que exista cualquier container.
            SwiftDataConfiguration.performSignOutWipeIfArmed()
            let iCloudWasAvailable = SwiftDataConfiguration.isICloudAvailable()
            SwiftDataConfiguration.markContainerCloudKitState(iCloudWasAvailable)
            return try ModelContainer(
                for: SwiftDataConfiguration.schema,
                configurations: SwiftDataConfiguration.personalConfiguration,
                               SwiftDataConfiguration.groupsConfiguration,
                               SwiftDataConfiguration.syncMetaConfiguration
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
                    // Unit tests: saltar el bootstrap del host por completo (seeding,
                    // CKSyncEngine de grupos, exchange rates, etc.). En sims sin cuenta
                    // iCloud (CI) el CKSyncEngine de grupos genera errores ruidosos. Los
                    // tests usan contextos aislados. UI tests (isUITesting) NO entran al
                    // guard: corren el ciclo normal con su seed.
                    guard !SwiftDataConfiguration.isRunningTests else { return }
                    if !UITestHooks.isActive {
                        try? Tips.configure([
                            .displayFrequency(.immediate)
                        ])
                    }
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
            // Unit tests: el host no corre el ciclo became-active (sin bootstrap/sync).
            guard !SwiftDataConfiguration.isRunningTests else { return }
            if newPhase == .active {
                bootstrapper.handleBecameActive(context: sharedModelContainer.mainContext)
            } else if newPhase == .background {
                // Drop transient router intents. Persistence-backed intents
                // re-emit on next .active via handleBecameActive().
                AppRouter.shared.resetTransients()
            }
        }
    }
}
