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
            // El `if let` no relaja nada: en el arranque el host SIEMPRE trae container (solo es `nil`
            // dentro de la ventana del swap, que no puede solaparse con el init del `App`).
            if UITestHooks.isActive, let container = PersonalContainerHost.shared.container {
                bootstrapper.applyUITestHooksEarly(context: container.mainContext)
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
    ///
    /// **R4: el container dejó de ser una constante de este `struct` y pasó a ser ESTADO de proceso**
    /// (`PersonalContainerHost`). El cuerpo que lo construía —los cuatro hooks pre-mount en su orden
    /// congelado y la captura del testigo— se movió ENTERO al host, sin partirlo: el swap de persona
    /// remonta por ese mismo camino, y una copia habría podido divergir del arranque.
    private let containerHost = PersonalContainerHost.shared

    /// Compat de lectura para los call-sites de esta pantalla. **`nil` SOLO durante la ventana del swap**,
    /// que es exactamente cuando no hay jerarquía montada que pueda pedirlo.
    private var sharedModelContainer: ModelContainer? { containerHost.container }

    @State private var themeManager = ThemeManager()

    /// Bootstrapper centralizado para inicialización y servicios
    private let bootstrapper = AppBootstrapper.shared

    var body: some Scene {
        WindowGroup {
            // **R4 · la ventana del swap.** Con el container soltado NO se monta la jerarquía: es lo que
            // se lleva los 37 ViewModels y los 67 `@Query` que retienen filas del store viejo, y sin eso
            // el release verificado no tiene ninguna posibilidad de salir verde (spike R3, eje 1c: una
            // fila `@Model` retenida mantiene vivo el container por sí sola).
            //
            // Lo que se muestra mientras tanto es el MISMO cover terminal del cierre de sesión, así que
            // para el usuario no hay corte visual: la pantalla que ya estaba puesta sigue puesta, y si el
            // swap aborta se queda ahí pidiendo el relanzamiento de siempre.
            if let container = containerHost.container {
                rootView(container: container)
                    // El remonte cambia de container: sin `id` SwiftUI reusaría vistas cuyo estado interno
                    // (ViewModels con filas del store anterior) sobreviviría al swap — filas huérfanas que
                    // siguen legibles en memoria tras morir su store, que es la forma de mentir que el
                    // eje 1c midió.
                    .id(containerHost.generation)
                    .modelContainer(container)
            } else {
                SignOutRelaunchView()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            handleScenePhase(newPhase)
        }
    }

    @ViewBuilder
    private func rootView(container: ModelContainer) -> some View {
        ContentView()
            // M1 · el store por defecto de TODOS los `@AppStorage` del árbol, en un solo sitio: son 11
            // y ninguno hay que tocar. Se resuelve UNA vez al montar la raíz, y ese congelado es
            // deliberado (cláusula 3 del contrato de `SessionDefaults`): un `@AppStorage` que
            // re-apuntara durante la ventana de entrada leería un cajón todavía vacío,
            // `hasCompletedOnboarding` daría `false` y montaría la cadena Welcome bajo el cover de
            // relanzamiento — el brick que el mount prohíbe.
            .defaultAppStorage(SessionDefaults.current)
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
                await bootstrapper.bootstrap(container: container)
            }
            .onChange(of: bootstrapper.sessionState.needsExchangeRateReload) { _, needsReload in
                if needsReload {
                    Task {
                        await bootstrapper.handleExchangeRateReloadRequest(container: container)
                    }
                }
            }
            .onOpenURL { url in
                bootstrapper.handleIncomingURL(url)
            }
    }

    private func handleScenePhase(_ newPhase: ScenePhase) {
        // Unit tests: el host no corre el ciclo became-active (sin bootstrap/sync).
        guard !SwiftDataConfiguration.isRunningTests else { return }
        if newPhase == .active {
            // Durante la ventana del swap no hay contexto, y tampoco hay nada que reactivar: la app
            // está entre dos stores. El ciclo normal vuelve con el remonte.
            if let container = sharedModelContainer {
                bootstrapper.handleBecameActive(context: container.mainContext)
            }
        } else if newPhase == .background {
            // Decisión owner UX 2026-07-14: con un relaunch terminal pendiente (sign-out
            // `.cloud`/secundario, ventana de ENTRADA secundaria, o —desde R0— el terminal
            // del Welcome que pide reabrir para encender el mirror; todo lo persistente ya
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
                    && !SwiftDataConfiguration.secondaryStoreMounted,
                // R0 · `peek` y JAMÁS `consume`: retirar aquí el destino dejaría al usuario que pidió
                // restaurar de iCloud aterrizando en el onboarding normal tras reabrir, con su elección
                // perdida — que es exactamente el daño para el que R2 lo hizo durable. Lo consume el
                // encaminamiento del arranque siguiente (`ContentView`), que es quien lo honra.
                welcomeMirrorRelaunchArmed: WelcomePendingDestinationStore.peek() != nil
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
