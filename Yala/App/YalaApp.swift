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
            // `-fake-icloud` (standalone, SIN `-uitest`): mismo seam de cuenta simulada
            // para el device-qa AGENTIC en sim — agent-device/XcodeBuildMCP lanzan la app
            // sin `-uitest` (applyUITestHooksEarly no corre) y el sim no tiene cuenta
            // iCloud, así que el gate "Grupos necesita iCloud" (§i.8(c)2) taparía todo el
            // QA de Grupos. Fuerza también hasCompletedFirstImport=true
            // (SplitSyncStartGate → .startNow) — deseable en QA. No-op en release.
            if ProcessInfo.processInfo.arguments.contains("-fake-icloud") {
                iCloudSyncService.shared._uiTestSimulateAvailableAccount()
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
            // M1: si el sign-out SECUNDARIO dejó armado su wipe, borrar los archivos
            // `-Secondary` + limpiar el descriptor ANTES de decidir el mount (los archivos
            // y keys del dueño no se tocan). Va PRIMERO: desarma la sesión secundaria para
            // que el mount de abajo vuelva al store del dueño.
            SwiftDataConfiguration.performSecondaryWipeIfArmed()
            // H4: si el cierre de sesión en `.cloud` dejó armado el wipe, ejecutarlo AHORA
            // (pre-mount) — borra archivos de los stores personal+sync-meta y devuelve el
            // device a `.icloud` fresh ANTES de que exista cualquier container.
            SwiftDataConfiguration.performSignOutWipeIfArmed()
            // G5-B: si el cierre de sesión SOLO-GRUPOS dejó armado su wipe, borrar AHORA (pre-mount)
            // los archivos del store de grupos ÚNICAMENTE — el personal, sync-meta, onboarding, prefs
            // y storageMode no se tocan (device sigue en `.icloud`). Con el flag OFF el arm jamás existe.
            SwiftDataConfiguration.performGroupsOnlySignOutWipeIfArmed()
            // M1: primer boot de una sesión secundaria — purga E2E-M1 de las superficies App
            // Group del dueño + cancelación de sus notifs + healing de flags (one-shot).
            SwiftDataConfiguration.performSecondaryEntryTasksIfNeeded()
            // R1 (relanzamiento cero): el testigo durable guarda la DECISIÓN de mount, no la
            // DISPONIBILIDAD de iCloud. Evaluar `personalConfiguration` PRIMERO no es cosmético: es lo
            // que captura la decisión, y sin esa captura previa aquí se registraría el default.
            let personalConfiguration = SwiftDataConfiguration.personalConfiguration
            SwiftDataConfiguration.markContainerCloudKitState(
                decision: SwiftDataConfiguration.personalStoreMountedDecision)
            return try ModelContainer(
                for: SwiftDataConfiguration.schema,
                configurations: personalConfiguration,
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
                    guard !SwiftDataConfiguration.isRunningTests else {
                        // Sin bootstrap nadie libera el blocker `bootstrapPending` y el shell
                        // del host quedaría sin drenar un solo intent en toda la corrida.
                        SessionState.shared.isBootstrapSettled = true
                        return
                    }
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
                // Decisión owner UX 2026-07-14: con un relaunch terminal pendiente (sign-out
                // `.cloud`/secundario o ventana de ENTRADA secundaria — todo lo persistente ya
                // se escribió), terminar el proceso al ir a background: el próximo launch corre
                // el cleanup pre-mount y aterriza en Welcome sin pedir matar la app a mano.
                // También es la red FINAL del cover terminal (la ventana peligrosa no sobrevive
                // un background). Vive AQUÍ y no en ContentView porque este scenePhase es el
                // AGREGADO del proceso (en ContentView es por-escena — iPad multi-ventana:
                // ocultar una ventana mataría el proceso con otra visible) y el guard
                // isRunningTests de arriba aplica (jamás exit(0) bajo tests). exit(0)
                // programático está desaconsejado por Apple pero es práctica aceptada en
                // background para reinicios obligatorios; JAMÁS en foreground
                // (RelaunchNetLogic solo lo permite en `.background`, no `.inactive`).
                if RelaunchNetLogic.shouldExitOnBackground(
                    scenePhase: newPhase,
                    signOutPhase: CloudSessionSignOut.shared.phase,
                    secondaryEntryArmedUnmounted: SecondarySessionStore.isActive()
                        && !SwiftDataConfiguration.secondaryStoreMounted
                ) {
                    CloudSyncBreadcrumb.relaunchExitOnBackground()
                    exit(0)
                }
                // Drop transient router intents. Persistence-backed intents
                // re-emit on next .active via handleBecameActive().
                AppRouter.shared.resetTransients()
            }
        }
    }
}
