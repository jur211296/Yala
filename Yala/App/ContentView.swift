//
//  ContentView.swift
//  Yala
//
//  Created by Yala Refactoring.
//

import CloudKit
import StoreKit
import SwiftData
import SwiftUI

// MARK: - ContentView (Punto de entrada principal)

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @AppStorage("hasShownWelcomeChooser") private var hasShownWelcomeChooser: Bool = false
    @AppStorage(AppPreferences.Keys.hasShownYalaAIOnboarding) private var hasShownYalaAIOnboarding: Bool = false
    @State private var showOnboarding: Bool = false
    @State private var showLanguageSelection: Bool = false
    @State private var showWelcomeRestore: Bool = false
    // H4: re-entrada a cuenta del Modo Nube desde el Welcome (SIWA → exists → adopt).
    @State private var showWelcomeCloudSignIn: Bool = false
    /// Provider elegido en el chooser para el cover de sign-in de nube (sesión 2 Google).
    /// Cada card lo setea EXPLÍCITO antes de presentar (`.cloudSignIn` → `.apple`).
    @State private var welcomeCloudProvider: CloudSignInProvider = .apple
    // H4 + fix carrera 2026-07-14: DUEÑO ÚNICO del cover de relaunch del sign-out
    // `.cloud`/secundario. ProfileView ya NO presenta (ante la fase cierra su sheet) —
    // dos anchors ante el mismo observable tumbaban ambas cadenas. La presentación se
    // VERIFICA por onAppear del contenido real y se reintenta (SignOutRelaunchNetModifier).
    @State private var showSignOutRelaunchCover: Bool = false
    /// M1: red DURABLE de la VENTANA DE ENTRADA secundaria (descriptor persistido, store del
    /// DUEÑO montado, relaunch pendiente). El cover primario es la fase `.relaunchSecondary`
    /// del welcome; si ese cover muere, este re-presenta (regla toolbar-muerta).
    @State private var showSecondaryEntryRelaunchCover: Bool = false
    @State private var showInviteRecovery: Bool = false
    /// Prefilled summary from iCloud restore (rama B). Pasado a OnboardingView
    /// como `prefilledData`. Reseteado tras data wipe para evitar values stale.
    @State private var prefilledOnboardingData: ICloudAccountSummary?
    @State private var showSplash: Bool = true
    @State private var splashOpacity: Double = 1
    /// Hero + Chooser unificados en un solo cover. El step interno (hero/chooser)
    /// lo maneja `WelcomeFlowContainer` — el ContentView solo decide cuándo
    /// presentar el flow y con qué `initialStep`.
    @State private var showWelcomeFlow: Bool = false
    @State private var welcomeFlowInitialStep: WelcomeFlowStep = .hero
    /// Positive confirmation toast for reactive events (remote onboarding / restore).
    /// Replaces the noisy "Syncing…" banner. Nil when hidden.
    @State private var positiveToast: String?
    @State private var toastDismissTask: Task<Void, Never>?
    @State private var wipeGraceTask: Task<Void, Never>?
    @State private var remoteWipeTask: Task<Void, Never>?
    @State private var showRemoteWipeAlert: Bool = false
    @State private var showICloudRestartAlert: Bool = false
    @State private var showFreshStartWipeAlert: Bool = false
    @State private var showSyncSettingsSheet: Bool = false
    @State private var showProTrialOffer: Bool = false
    @State private var showWhatsNew: Bool = false
    @State private var whatsNewData: (features: [WhatsNewFeature], version: String)?
    @AppStorage("lastSeenAppVersion") private var lastSeenAppVersion: String = ""
    @State private var isInitialCheckDone: Bool = false
    @State private var showGroupInviteOnboarding: Bool = false
    /// Metadata branded del invite (nombre/icono/color del grupo) para
    /// personalizar el welcome de `GroupInviteOnboardingView`.
    @State private var pendingInviteMetadata: InviteMetadata?
    @State private var showGroupReconnect: Bool = false
    /// G4-invites (A2): sheets del flujo backend sign-in → consent → join, drenados de
    /// `.presentGroupsConsent` / `.presentGroupsSignIn`. DARK: con `groupsBackendEnabled`
    /// OFF los intents jamás se submitean.
    @State private var showGroupsConsent: Bool = false
    @State private var showGroupsSignIn: Bool = false
    /// Keying `zoneName` (== group_id backend) del join pendiente que abrió el sheet.
    @State private var pendingGroupsJoinZone: String?
    @State private var showFullModeActivation: Bool = false
    /// Parte F: oferta "cargar tus datos antes de unirte" cuando un returning user
    /// con datos en iCloud (sin wipe) abre un link de invitación.
    @State private var showRestoreOffer: Bool = false
    @State private var pendingOfferInvite: InviteMetadata?
    /// Inbox alert payload, driven by .contentView drain of .showInboxAlert.
    @State private var activeInboxNotification: PendingInboxNotification = .init()
    /// Group reconnect invite (metadata + mode), carried by .presentGroupReconnect intent.
    @State private var pendingReconnectInvite: InviteMetadata?
    /// Invite error detail, carried by .showInviteError intent.
    @State private var activeInviteError: String?
    /// Group bridge/sync error message, carried by .showGroupSyncError intent (P0-1).
    @State private var activeGroupSyncError: String?
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.yalaTheme) private var theme

    /// Lightweight state for existing data detection (replaces @Query to prevent
    /// synchronous SwiftData fetches during iOS snapshot capture — 0x8BADF00D fix).
    @State private var hasExistingData: Bool = false

    /// Increments cuando el idioma cambia (local o sync iCloud). Usado como `.id()`
    /// del root para forzar re-render de strings y formatters localizados.
    @State private var languageVersion: Int = 0
    @Environment(\.modelContext) private var modelContext

    /// Minimum splash duration (2.5 seconds to enjoy the animation)
    private let minimumSplashDuration: Double = 2.5

    var body: some View {
        ZStack {
            // Main content deferred until initial state check completes (~2s after launch).
            // Creating MainTabView during the first commit triggers PanelView data loading
            // synchronously on the main thread. Before the first frame renders, the system
            // considers the app "Background" (WatchdogVisibility), with a 5-second timeout.
            // The heavy SwiftData fetches + calculations exceed that, causing 0x8BADF00D.
            // By waiting for isInitialCheckDone, the first frame (just the splash) renders
            // instantly, promoting the app to Foreground (20s timeout).
            if hasCompletedOnboarding && isInitialCheckDone {
                MainTabView()
                    .environment(SessionState.shared)
                    .modifier(TagCatalogProvider())
                    .id(languageVersion) // re-render on .languageDidChange
                    .accessibilityIdentifier(UITestHooks.shared.rootIdentifier)
            } else {
                theme.background
                    .ignoresSafeArea()
            }

            // Positive toast overlay — only for reactive events (remote onboarding,
            // remote restore). The noisy "Syncing…" banner was removed; failure states
            // are surfaced by SyncStatusBanner below when MainTabView is mounted.
            if let toast = positiveToast {
                Text(toast)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.sm)
                    .glassEffect()
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, DS.Spacing.xxl)
            }

            // Sync status banner overlay — failure/stalled states from iCloudSyncService.
            // Gated to match MainTabView timing: only shows once onboarding/splash/initial
            // check are resolved, avoiding competition with splash, iCloudSyncWaitingView,
            // and onboarding flows.
            if hasCompletedOnboarding && isInitialCheckDone && !showSplash {
                syncStatusBannerOverlay
            }

            // Splash screen overlay — waits for both minimum duration AND initial state check
            if showSplash {
                SplashScreenView()
                    .opacity(splashOpacity)
                    .ignoresSafeArea()
                    .task {
                        try? await Task.sleep(for: .seconds(minimumSplashDuration))
                        // Wait until initial check determines what to show (avoids blank flash)
                        while !isInitialCheckDone {
                            try? await Task.sleep(for: .milliseconds(50))
                        }
                        dismissSplash()
                    }
            }
        }
        .task {
            await checkInitialSyncState()
        }
        .onReceive(NotificationCenter.default.publisher(for: .languageDidChange)) { _ in
            languageVersion &+= 1
        }
        .onChange(of: SessionState.shared.dataVersion) { _, _ in
            // Replaces @Query-based observation. dataVersion increments on CRUD, CloudKit sync,
            // and sheet dismissals — covers all cases where data may have arrived or changed.
            // A4 v3.1: el `wipeGraceTask` (onChange hasExistingData abajo) sigue usando este flag
            // para detectar data desaparecida. El gate isWaitingForSync se eliminó con el rediseño.
            hasExistingData = checkHasExistingData()
        }
        .onChange(of: hasCompletedOnboarding) { _, newValue in
            // Data wipe path: invalida summary stale + respeta el flag del chooser.
            // `performLocalWipeForRemoteSync` resetea `hasShownWelcomeChooser=false` cuando
            // el wipe requiere re-onboarding completo, así que el chooser vuelve a presentarse.
            if !newValue {
                prefilledOnboardingData = nil
                presentNextOnboardingScreen()
            }
        }
        .onChange(of: hasExistingData) { oldValue, newValue in
            if oldValue && !newValue && hasCompletedOnboarding {
                // Data disappeared — debounce 5s before acting (transient CloudKit gap)
                wipeGraceTask?.cancel()
                wipeGraceTask = Task {
                    do {
                        try await Task.sleep(for: .seconds(5))
                        // Data still gone after 5s — ask user
                        showRemoteWipeAlert = true
                    } catch {
                        // Cancelled — data reappeared
                    }
                }
            } else if !oldValue && newValue {
                // Data reappeared — cancel pending wipe grace
                wipeGraceTask?.cancel()
                wipeGraceTask = nil
            }
        }
        .alert(L10n.iCloud.remoteWipeTitle, isPresented: $showRemoteWipeAlert) {
            Button(L10n.iCloud.remoteWipeConfirm, role: .destructive) {
                // Reset seed guards so onboarding can re-create data
                UserDefaults.standard.removeObject(forKey: "seedCategoriesExecuted")
                UserDefaults.standard.removeObject(forKey: "notificationsSeeded")
                hasCompletedOnboarding = false
            }
            Button(L10n.iCloud.remoteWipeCancel, role: .cancel) {}
        } message: {
            Text(L10n.iCloud.remoteWipeMessage)
        }
        .alert(L10n.iCloud.mismatchTitle, isPresented: $showICloudRestartAlert) {
            Button(L10n.iCloud.mismatchAction) {}
        } message: {
            Text(L10n.iCloud.mismatchMessage)
        }
        .alert(L10n.Welcome.FreshStart.alertTitle, isPresented: $showFreshStartWipeAlert) {
            Button(L10n.Welcome.FreshStart.alertConfirm, role: .destructive) {
                do {
                    try DataWipeService.wipeAllUserData(
                        in: modelContext,
                        broadcastSignal: false
                    )
                    hasExistingData = false
                } catch {
                    #if DEBUG
                    print("ContentView: fresh-start wipe failed: \(error)")
                    #endif
                }
                showWelcomeFlow = false
                showOnboarding = true
            }
            // Cancel: user queda en el Chooser (showWelcomeFlow sigue true) —
            // puede elegir Restore/Invite o re-tap "Soy nuevo".
            Button(L10n.Action.cancel, role: .cancel) {}
                .tint(.primary)  // A11Y-DM: el indigo global se pierde sobre el alert del Welcome oscuro
        } message: {
            Text(L10n.Welcome.FreshStart.alertMessage)
        }
        // Parte F: oferta para un returning user con datos al abrir un link de invitación.
        .alert(L10n.Welcome.OfferRestore.title, isPresented: $showRestoreOffer) {
            Button(L10n.Welcome.OfferRestore.loadData) {
                // Cargar datos: el invite queda retenido en PendingInviteStore; tras
                // restaurar se re-emite (reEmitInviteAfterRestore en onContinue/onComplete).
                showRestoreOffer = false
                showWelcomeRestore = true
            }
            Button(L10n.Welcome.OfferRestore.startFresh, role: .destructive) {
                // Empezar de cero: wipe CON señal (lastWipeTimestamp) para que el re-emit
                // vea wipe>onboarding → mini-onboarding de grupos (no vuelve a ofrecer).
                showRestoreOffer = false
                do {
                    try DataWipeService.wipeAllUserData(in: modelContext)
                    hasExistingData = false
                } catch {
                    #if DEBUG
                    print("ContentView: offer-restore fresh-start wipe failed: \(error)")
                    #endif
                }
                reEmitInviteAfterRestore()
            }
            Button(L10n.Action.cancel, role: .cancel) {
                showRestoreOffer = false
                // Decisión consciente: volver al Chooser (el invite sigue en el store).
                if !hasCompletedOnboarding {
                    welcomeFlowInitialStep = .chooser
                    showWelcomeFlow = true
                }
            }
        } message: {
            Text(L10n.Welcome.OfferRestore.message)
        }
        .fullScreenCover(isPresented: $showLanguageSelection) {
            LanguageSelectionView {
                showLanguageSelection = false
                if !hasCompletedOnboarding {
                    presentNextOnboardingScreen()
                }
            }
            .environment(SessionState.shared)
        }
        .fullScreenCover(isPresented: $showInviteRecovery) {
            InviteRecoveryView(
                onSuccess: { url in
                    showInviteRecovery = false
                    AppBootstrapper.shared.handleInviteLink(url)
                },
                onBack: {
                    // Vuelve al WelcomeFlow en step .chooser (donde estaba).
                    returnToWelcomeChooser(dismissing: $showInviteRecovery)
                }
            )
            .environment(SessionState.shared)
        }
        .fullScreenCover(isPresented: $showWelcomeRestore) {
            WelcomeRestoreView(
                onContinueWithSummary: { summary in
                    showWelcomeRestore = false
                    // Destino por onboardingMode restaurado (synced) — RestoreRouter.
                    let destination = RestoreRouter.decide(
                        onboardingMode: OnboardingMode.current(),
                        isFullyPrefilled: summary.isFullyPrefilled
                    )
                    RestoreBreadcrumb.destination(String(describing: destination))
                    MetricsService.canary(.iCloudRestoreOutcome, detail: String(describing: destination))
                    switch destination {
                    case .groupsOnly:
                        // El usuario era "solo grupos": no forzar onboarding personal.
                        OnboardingMode.setCurrent(.groupInvite)
                        SessionState.shared.onboardingMode = .groupInvite
                        completeOnboardingAsRestoreSkip()
                        hasCompletedOnboarding = true
                        reEmitInviteAfterRestore()
                    case .directToApp:
                        completeOnboardingAsRestoreSkip()
                        hasCompletedOnboarding = true
                        reEmitInviteAfterRestore()
                    case .onboarding:
                        prefilledOnboardingData = summary
                        showOnboarding = true
                        // Parte F: el re-emit ocurre en el onComplete del OnboardingView
                        // (hasCompletedOnboarding=true ahí → reconnect, no re-oferta).
                    }
                },
                onStartFresh: {
                    // A4 v3.2 (#9b): clean slate también desde WelcomeRestoreView.
                    // Cubre paths .notFound/.error/.iCloudDisabled → "Empezar
                    // configuración" + confirmation dialog desde state .found.
                    OnboardingResetHelper.clearResidualPreferencesForFreshStart()
                    prefilledOnboardingData = nil
                    showWelcomeRestore = false
                    showOnboarding = true
                },
                onOpenSettings: {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                },
                onBack: {
                    returnToWelcomeChooser(dismissing: $showWelcomeRestore)
                }
            )
            .environment(SessionState.shared)
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView(
                prefilledData: prefilledOnboardingData,
                onCancelFromStep1: {
                    // Resetea `hasShownWelcomeChooser` para que el Hero se vuelva
                    // a presentar (no salta al Chooser automáticamente).
                    showOnboarding = false
                    hasShownWelcomeChooser = false
                    prefilledOnboardingData = nil
                    presentNextOnboardingScreen()
                }
            ) {
                // Set flag BEFORE dismiss — onChange picks it up reliably
                if !FeatureGateService.shared.isProUser {
                    SessionState.shared.needsPostOnboardingTrial = true
                }
                hasCompletedOnboarding = true
                SetupChecklistManager.shared.markAsNewInstall()
                showOnboarding = false
                prefilledOnboardingData = nil
                reEmitInviteAfterRestore()
            }
            .environment(SessionState.shared)
        }
        .modifier(WelcomeFlowModifier(
            showWelcomeFlow: $showWelcomeFlow,
            welcomeFlowInitialStep: $welcomeFlowInitialStep,
            showOnboarding: $showOnboarding,
            showWelcomeRestore: $showWelcomeRestore,
            showInviteRecovery: $showInviteRecovery,
            showWelcomeCloudSignIn: $showWelcomeCloudSignIn,
            welcomeCloudProvider: $welcomeCloudProvider,
            prefilledOnboardingData: $prefilledOnboardingData,
            hasShownWelcomeChooser: $hasShownWelcomeChooser,
            hasCompletedOnboarding: $hasCompletedOnboarding,
            showFreshStartWipeAlert: $showFreshStartWipeAlert,
            hasExistingData: hasExistingData,
            hasLocalDataNow: { checkHasExistingData() },
            showGroupInviteOnboarding: showGroupInviteOnboarding
        ))
        .modifier(SignOutRelaunchNetModifier(
            showRelaunchCover: $showSignOutRelaunchCover
        ))
        .modifier(SecondaryEntryRelaunchNetModifier(
            showRelaunchCover: $showSecondaryEntryRelaunchCover,
            welcomeCloudCoverVisible: showWelcomeCloudSignIn
        ))
        .modifier(GroupsBackendInviteModifier(
            showGroupsConsent: $showGroupsConsent,
            showGroupsSignIn: $showGroupsSignIn,
            pendingGroupsJoinZone: $pendingGroupsJoinZone
        ))
        .modifier(GroupInviteModifier(
            showGroupInviteOnboarding: $showGroupInviteOnboarding,
            pendingInviteMetadata: $pendingInviteMetadata,
            showGroupReconnect: $showGroupReconnect,
            hasCompletedOnboarding: $hasCompletedOnboarding,
            pendingReconnectInvite: $pendingReconnectInvite,
            activeInviteError: $activeInviteError,
            activeGroupSyncError: $activeGroupSyncError,
            showWelcomeFlow: $showWelcomeFlow,
            welcomeFlowInitialStep: $welcomeFlowInitialStep
        ))
        .onChange(of: showOnboarding) { oldValue, newValue in
            // Replaces unreliable fullScreenCover onDismiss for post-onboarding flow.
            // onChange(of:) fires synchronously on @State change — always reliable.
            guard oldValue && !newValue && hasCompletedOnboarding else { return }
            if SessionState.shared.needsPostOnboardingTrial && !FeatureGateService.shared.isProUser {
                // El flag persistido se limpia en el DRAIN (presentación real),
                // no aquí: el intent es transient (drop en background) y limpiarlo
                // al emitir perdía la oferta sin re-emisión posible.
                Task {
                    // Wait for fullScreenCover dismiss animation (~0.35s, UX)
                    try? await Task.sleep(for: .seconds(0.8))
                    await waitForBootstrap()
                    RouterEntryGate.shared.submit(.presentTrialOffer)
                }
            }
        }
        .sheet(isPresented: $showSyncSettingsSheet) {
            ProfileView(initialDestination: .iCloudSync)
                .environment(SessionState.shared)
        }
        .sheet(isPresented: $showProTrialOffer, onDismiss: {
        }) {
            ProTrialOfferSheet {
                showProTrialOffer = false
            }
        }
        .sheet(isPresented: $showWhatsNew, onDismiss: {
            if let data = whatsNewData {
                lastSeenAppVersion = data.version
            }
            whatsNewData = nil
        }) {
            if let data = whatsNewData {
                WhatsNewSheet(features: data.features, version: data.version) {
                    showWhatsNew = false
                }
            }
        }
        .sheet(isPresented: $showFullModeActivation) {
            FullModeActivationView {
                showFullModeActivation = false
            }
            .environment(SessionState.shared)
        }
        // Inbox alert as fullScreenCover (appears over any sheet).
        // Driven by @State set by the .contentView drain handler.
        // Setter real + onDismiss son la red contra teardowns externos (p.ej.
        // UIKit tumba la cadena al cerrar un sheet debajo): sin ellos el estado
        // queda pegado → cover fantasma invisible que bloquea toda la UI y
        // congela la readiness del router (hasActiveInboxAlert).
        .fullScreenCover(isPresented: Binding(
            get: { !activeInboxNotification.isEmpty },
            set: { if !$0 { activeInboxNotification = .init() } }
        ), onDismiss: {
            activeInboxNotification = .init()
        }) {
            InboxAlertModal(
                notification: activeInboxNotification,
                onViewInbox: {
                    RouterEntryGate.shared.submit(.presentInboxSheet)
                },
                onDismiss: {
                    activeInboxNotification = .init()
                }
            )
            .presentationBackground(.clear)
            .environment(SessionState.shared)
        }
        .onAppear {
            themeManager.systemColorScheme = colorScheme
        }
        .onChange(of: colorScheme) { _, newScheme in
            themeManager.systemColorScheme = newScheme
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                // GC-08: Recalculate user segment on each foreground activation
                UserSegmentService.shared.recalculate()
                // Re-emite un invite pendiente persistido si su intent transient fue
                // dropeado por resetTransients en background. `isPresenting` evita
                // re-presentar cuando el cover de invite/reconnect ya está abierto.
                AppBootstrapper.shared.reEmitPendingInviteIfNeeded(
                    isPresenting: showGroupInviteOnboarding || showGroupReconnect || showRestoreOffer
                )
                // Cinturón del join intent: cubre "grupo ya local pero el reconcile
                // de boot se difirió por quiescencia". El propio reconciler gatea
                // por quiescencia y hace no-op sin intents.
                Task { @MainActor in
                    await GroupJoinReconciler.reconcile(trigger: .foreground)
                }
                // Batch "salir de todos mis grupos" (D10): reanuda un batch a medio ejecutar al volver a
                // foreground. No-op sin trabajo pendiente; el orquestador gatea por quiescencia por grupo.
                Task { @MainActor in
                    await GroupBatchLeaveOrchestrator.resume(trigger: .foreground)
                }
            // El exit-on-background del relaunch terminal (decisión owner UX 2026-07-14)
            // vive en YalaApp, NO aquí: el `\.scenePhase` de ContentView es POR-ESCENA
            // (iPad multi-ventana: ocultar una ventana mataría el proceso con otra
            // visible); el de YalaApp es el AGREGADO del proceso y ya guarda tests.
            default:
                break
            }
        }
        .onChange(of: SessionState.shared.isWipingData) { _, _ in updateContentViewReadiness() }
        // Fix carrera 2026-07-14: la fase de sign-out alimenta el blocker `signOutRelaunch`
        // como condición viva — cinturón explícito de recompute (leerla en el snapshot ya
        // registra el tracking @Observable; esto la hace grep-able junto a isWipingData).
        .onChange(of: CloudSessionSignOut.shared.phase) { _, _ in updateContentViewReadiness() }
        // Cross-node: un sheet de MainTabView visible bloquea las presentaciones
        // del shell (el cover del inbox alert no debe montarse encima y ser
        // tumbado por su dismiss — variante cross-node del bug TestFlight).
        .onChange(of: SessionState.shared.isMainTabModalVisible) { _, _ in updateContentViewReadiness() }
        // Shell-level modal flags gate readiness via pure-logic
        // ContentViewReadinessLogic. Encapsulated in a ViewModifier to keep
        // ContentView's body within the type-checker's budget.
        .readinessGateObservers(
            showOnboarding: showOnboarding,
            showWelcomeFlow: showWelcomeFlow,
            showLanguageSelection: showLanguageSelection,
            showWelcomeRestore: showWelcomeRestore,
            showInviteRecovery: showInviteRecovery,
            showWelcomeCloudSignIn: showWelcomeCloudSignIn,
            // Fix carrera 2026-07-14: la condición viva (la FASE) ES el blocker; el @State del
            // cover es la red visual — si la presentación tarda/falla, el router queda contenido igual.
            showSignOutRelaunch: showSignOutRelaunchCover
                || CloudSessionSignOut.shared.phase == .awaitingRelaunch,
            // M1: la condición viva (statics) ES el blocker; el @State del cover es la red visual.
            secondaryEntryRelaunch: showSecondaryEntryRelaunchCover
                || (SecondarySessionStore.isActive() && !SwiftDataConfiguration.secondaryStoreMounted),
            showFreshStartWipeAlert: showFreshStartWipeAlert,
            showRemoteWipeAlert: showRemoteWipeAlert,
            showICloudRestartAlert: showICloudRestartAlert,
            showRestoreOffer: showRestoreOffer,
            hasActiveInviteError: activeInviteError != nil,
            hasActiveGroupSyncError: activeGroupSyncError != nil,
            activeInboxNotification: activeInboxNotification,
            showGroupInviteOnboarding: showGroupInviteOnboarding,
            showGroupReconnect: showGroupReconnect,
            showGroupsConsent: showGroupsConsent,
            showGroupsSignIn: showGroupsSignIn,
            showFullModeActivation: showFullModeActivation,
            showProTrialOffer: showProTrialOffer,
            showWhatsNew: showWhatsNew,
            showSyncSettingsSheet: showSyncSettingsSheet,
            recompute: updateContentViewReadiness
        )
        .onChange(of: AppRouter.shared.revision) { _, _ in
            drainContentViewIntents()
        }
        // .remoteOnboardingCompleted: dual-path. The intent goes through
        // RouterEntryGate too, but the readiness gate blocks .contentView
        // drain while showOnboarding=true — which is precisely when we need
        // the signal to fire (to dismiss that onboarding view from the
        // remote-completion event). Keep this observer to bypass the gate.
        .onReceive(NotificationCenter.default.publisher(for: .remoteOnboardingCompleted)) { _ in
            handleRemoteOnboardingCompleted()
        }
    }

    /// Cierra el sub-flow del Welcome (Rama B o C) y devuelve al user al Chooser.
    /// Usado por callbacks `onBack` de `InviteRecoveryView` y `WelcomeRestoreView`.
    private func returnToWelcomeChooser(dismissing flag: Binding<Bool>) {
        flag.wrappedValue = false
        welcomeFlowInitialStep = .chooser
        showWelcomeFlow = true
    }

    private func dismissSplash() {
        withAnimation(.easeOut(duration: 0.4)) {
            splashOpacity = 0
        }
        Task {
            try? await Task.sleep(for: .milliseconds(400))
            showSplash = false
            SessionState.shared.isSplashDismissed = true

            // Router drains queued intents once readiness flips.
            updateContentViewReadiness()
            // B4-04: el handoff splash→welcome no genera revision bump (markUnready
            // no bumpea), así que el .onChange(revision) no re-dispara el drain. Un
            // re-peek explícito aquí permite que un group invite encolado durante el
            // splash cierre la cadena welcome y se presente.
            drainContentViewIntents()
        }
    }

    // MARK: - Router Consumer

    /// Builds the current shell readiness snapshot from @State + SessionState.
    /// Single source for both `updateContentViewReadiness` and the welcome-chain
    /// teardown decision in `drainContentViewIntents`.
    @MainActor
    private func currentShellReadinessState() -> ShellReadinessState {
        ShellReadinessState(
            isSplashDismissed: SessionState.shared.isSplashDismissed,
            isWipingData: SessionState.shared.isWipingData,
            showOnboarding: showOnboarding,
            showWelcomeFlow: showWelcomeFlow,
            showLanguageSelection: showLanguageSelection,
            showWelcomeRestore: showWelcomeRestore,
            showInviteRecovery: showInviteRecovery,
            showWelcomeCloudSignIn: showWelcomeCloudSignIn,
            // Fix carrera 2026-07-14: la condición viva (la FASE) ES el blocker; el @State del
            // cover es la red visual — si la presentación tarda/falla, el router queda contenido igual.
            showSignOutRelaunch: showSignOutRelaunchCover
                || CloudSessionSignOut.shared.phase == .awaitingRelaunch,
            // M1: la condición viva (statics) ES el blocker; el @State del cover es la red visual.
            secondaryEntryRelaunch: showSecondaryEntryRelaunchCover
                || (SecondarySessionStore.isActive() && !SwiftDataConfiguration.secondaryStoreMounted),
            showFreshStartWipeAlert: showFreshStartWipeAlert,
            showRemoteWipeAlert: showRemoteWipeAlert,
            showICloudRestartAlert: showICloudRestartAlert,
            showRestoreOffer: showRestoreOffer,
            hasActiveInviteError: activeInviteError != nil,
            hasActiveGroupSyncError: activeGroupSyncError != nil,
            hasActiveInboxAlert: !activeInboxNotification.isEmpty,
            showGroupInviteOnboarding: showGroupInviteOnboarding,
            showGroupReconnect: showGroupReconnect,
            showGroupsConsent: showGroupsConsent,
            showGroupsSignIn: showGroupsSignIn,
            showFullModeActivation: showFullModeActivation,
            showProTrialOffer: showProTrialOffer,
            showWhatsNew: showWhatsNew,
            showSyncSettingsSheet: showSyncSettingsSheet,
            isMainTabModalVisible: SessionState.shared.isMainTabModalVisible
        )
    }

    /// Single source of truth for `.contentView` readiness. Called from every
    /// flag that can block shell presentation. Delegates to pure-logic
    /// `ContentViewReadinessLogic.isReady(state:)` so the gating matrix is
    /// testable independently of SwiftUI state.
    @MainActor
    private func updateContentViewReadiness() {
        let state = currentShellReadinessState()
        let currentBlocker = ContentViewReadinessLogic.blocker(state: state)
        // Publica el blocker para los guards de drain de .mainTab/.panel
        // (Clase D): con el shell tapado, sus intents esperan en cola.
        // Choke point único — SessionState.shellModalBlocker no tiene otro escritor.
        if SessionState.shared.shellModalBlocker != currentBlocker {
            SessionState.shared.shellModalBlocker = currentBlocker
        }
        let ready = currentBlocker == nil
        if ready {
            AppRouter.shared.markReady(.contentView)
        } else {
            AppRouter.shared.markUnready(.contentView)
            if let blocker = currentBlocker {
                #if DEBUG
                print("ContentView readiness blocked by: \(blocker)")
                #endif
                // Throttle telemetry: only fire for non-trivial blockers (skip splash/lock
                // which are common boot states; surface user-visible modals only).
                let surfacedBlockers: Set<String> = [
                    "activeInboxAlert", "groupInviteOnboarding", "groupReconnect",
                    "fullModeActivation", "remoteWipeAlert", "iCloudRestartAlert",
                    "freshStartWipeAlert", "restoreOffer", "inviteError",
                    "groupSyncError"
                ]
                if surfacedBlockers.contains(blocker) {
                    MetricsService.routingReadinessBlocked(blocker: blocker)
                }
            }
        }
    }

    /// Drains one `.contentView` intent per revision bump. Single-intent
    /// drain — handler may enqueue new intents, they process next tick.
    @MainActor
    private func drainContentViewIntents() {
        // B4-04: un intent que supersede la cadena welcome (group invite/reconnect)
        // está diseñado para REEMPLAZARLA, no apilarse. El cover del WelcomeFlow
        // bloquea el readiness que necesita drenar ese intent → deadlock: el welcome
        // bloquea el propio intent que lo cerraría. Si la cadena welcome es el ÚNICO
        // blocker, ciérrala para que el drain (y la presentación) procedan.
        if let next = AppRouter.shared.peekNext(for: .contentView),
           next.supersedesWelcomeChain,
           ContentViewReadinessLogic.isBlockedSolelyByWelcomeChain(state: currentShellReadinessState()) {
            dismissWelcomeChainForSupersedingIntent(for: next.id)
            updateContentViewReadiness()  // recompute síncrono → markReady(.contentView)
        }
        guard let intent = AppRouter.shared.drainNext(for: .contentView) else { return }
        switch intent {
        case .showInboxAlert(let notif):
            activeInboxNotification = notif
            // Presentación real → recién ahora se queman las firmas de los drafts
            // (consume-once persistente). Ver commitPendingInboxAlertSignatures.
            AppBootstrapper.shared.commitPendingInboxAlertSignatures()
        case .presentTrialOffer:
            showProTrialOffer = true
            // Drain == presentación real (mismo nodo que ancla el sheet, y con la
            // matriz completa solo drena con el anchor libre). Limpiar aquí — y no
            // en los productores — permite re-emitir tras un drop transient.
            SessionState.shared.needsPostOnboardingTrial = false
        case .presentWhatsNew(let features, let version):
            whatsNewData = (features: features, version: version)
            showWhatsNew = true
        case .presentGroupInviteOnboarding(let invite):
            pendingInviteMetadata = invite
            showGroupInviteOnboarding = true
        case .presentGroupReconnect(let invite):
            pendingReconnectInvite = invite
            showGroupReconnect = true
        case .offerRestoreBeforeInvite(let invite):
            pendingOfferInvite = invite
            showRestoreOffer = true
        case .showInviteError(let detail):
            activeInviteError = detail
        case .showGroupSyncError(let message):
            activeGroupSyncError = message
        case .iCloudMismatch:
            showICloudRestartAlert = true
        case .remoteWipe(let skipOnboarding):
            handleRemoteWipeSignal(onboardingAlreadyDone: skipOnboarding)
        case .remoteOnboardingCompleted:
            handleRemoteOnboardingCompleted()
        case .presentFullModeActivation:
            showFullModeActivation = true
        // G4-invites (A2): flujo backend sign-in → consent → (onboarding fresco) → join.
        // DARK: con `groupsBackendEnabled` OFF los intents jamás se submitean. Las vistas
        // (GroupsBackendInviteModifier) son sheets del MISMO anchor — entran a la matriz
        // (`groupsConsent`/`groupsSignIn`) y el drain se retiene mientras un nodo superior tape.
        case .presentGroupsConsent(let zone):
            pendingGroupsJoinZone = zone
            showGroupsConsent = true
        case .presentGroupsSignIn(let zone):
            pendingGroupsJoinZone = zone
            showGroupsSignIn = true
        case .presentGroupBackendInviteOnboarding(let zone):
            // Condición viva al drenar (regla del repo): el intent pudo quedar retenido bajo
            // un cover; si el onboarding YA se completó mientras tanto, no re-presentar —
            // continuar el flujo directo (join).
            if !hasCompletedOnboarding {
                pendingInviteMetadata = nil  // backend: sin CKShare metadata — visual genérico
                showGroupInviteOnboarding = true
            } else {
                Task { @MainActor in
                    await GroupBackendInviteEntryHandler.continueFlow(zoneName: zone)
                }
            }
        default:
            break
        }
    }

    /// Cierra los 4 covers de la cadena welcome para que un intent que la
    /// supersede (group invite/reconnect) pueda presentarse sin colisión —
    /// `showWelcomeRestore`/`showInviteRecovery`/`showLanguageSelection` NO están
    /// gateados, así que dejarlos abiertos apilaría dos covers (UI invisible).
    /// `showOnboarding` se excluye a propósito (ver `welcomeChainBlockers`). El
    /// `onDismiss` del reconnect sheet reabre welcome si hace falta. Llamado solo
    /// cuando `isBlockedSolelyByWelcomeChain` es true.
    @MainActor
    private func dismissWelcomeChainForSupersedingIntent(for intentID: String) {
        showLanguageSelection = false
        showWelcomeFlow = false
        showWelcomeRestore = false
        showInviteRecovery = false
        MetricsService.routingWelcomeChainSuperseded(intentID: intentID)
    }

    /// Wait for AppBootstrapper to finish (StoreKit products, exchange rates, etc.)
    private func waitForBootstrap() async {
        for _ in 0..<20 {
            if AppBootstrapper.shared.isInitialized { break }
            do { try await Task.sleep(for: .milliseconds(500)) } catch { break }
        }
        #if DEBUG
        print("ContentView: Bootstrap wait done — products=\(StoreKitManager.shared.products.count), initialized=\(AppBootstrapper.shared.isInitialized)")
        #endif
    }

    /// Lightweight check — fetchCount doesn't materialize objects or trigger observation.
    /// Excluye entidades system (A0-Bridge crea cuenta virtual `Grupos [moneda]` y categorías
    /// `Grupos`/`Cobros de grupos` en bootstrap antes del onboarding). Contarlas reportaría
    /// "has data" en fresh installs sin data real del usuario.
    private func checkHasExistingData() -> Bool {
        let accountDescriptor = FetchDescriptor<Account>(
            predicate: #Predicate<Account> { !$0.isSystemAccount }
        )
        let categoryDescriptor = FetchDescriptor<Category>(
            predicate: #Predicate<Category> { !$0.isSystem }
        )
        let accountCount = (try? modelContext.fetchCount(accountDescriptor)) ?? 0
        let categoryCount = (try? modelContext.fetchCount(categoryDescriptor)) ?? 0
        return accountCount > 0 || categoryCount > 0
    }

    /// Show a positive confirmation toast for ~3s. Used for remote onboarding
    /// completed and remote restore completed — the only events where a brief
    /// "your data is here" reassurance is worth interrupting the silent sync rule.
    private func showPositiveToast(_ text: String) {
        withAnimation(.easeInOut) { positiveToast = text }
        toastDismissTask?.cancel()
        toastDismissTask = Task {
            try? await Task.sleep(for: .seconds(3))
            withAnimation(.easeInOut) { positiveToast = nil }
        }
    }


    // MARK: - Cross-Device Wipe Handling

    private func handleRemoteWipeSignal(onboardingAlreadyDone: Bool) {
        let remoteWipe = NSUbiquitousKeyValueStore.default.double(forKey: "lastWipeTimestamp")
        let decision = RemoteWipeSignalDecider.decide(
            hasCompletedOnboarding: hasCompletedOnboarding,
            isWipingData: SessionState.shared.isWipingData,
            hasRemoteWipeTimestamp: remoteWipe > 0
        )

        if decision.shouldMarkSignalsAsProcessed {
            // A4 v3.2: fresh-install con KV-Store contaminado por install previa.
            // Marcar timestamps localmente para que checkForRemoteWipeSignal no
            // re-postee la notif en próximos launches. Bug #6 P0.
            markRemoteSignalsAsProcessed()
        }

        guard decision.shouldProcess else { return }

        // Cancel the hasExistingData-based wipe grace to avoid double-alert
        wipeGraceTask?.cancel()
        wipeGraceTask = nil
        showRemoteWipeAlert = false

        performLocalWipeForRemoteSync(skipOnboarding: onboardingAlreadyDone)
    }

    /// Idempotencia para el guard fresh-install: marca AMBOS timestamps remotos
    /// (wipe + onboarding) como procesados localmente para que tanto el "Caso A"
    /// (`.remoteWipeDetected`) como el "Caso B" (`.remoteOnboardingCompleted`)
    /// de `PreferenceSyncService.checkForRemoteWipeSignal` queden silenciados.
    private func markRemoteSignalsAsProcessed() {
        let iKV = NSUbiquitousKeyValueStore.default
        let local = UserDefaults.standard
        let remoteWipe = iKV.double(forKey: "lastWipeTimestamp")
        let remoteOnboarding = iKV.double(forKey: "lastOnboardingTimestamp")
        if remoteWipe > 0 {
            local.set(remoteWipe, forKey: "lastKnownWipeTimestamp")
        }
        if remoteOnboarding > 0 {
            local.set(remoteOnboarding, forKey: "lastKnownOnboardingTimestamp")
        }
    }

    private func handleRemoteOnboardingCompleted() {
        // Only act if this device is mid-onboarding — otherwise ignore
        guard showOnboarding else { return }
        // A4 v3.2: simetría con handleRemoteWipeSignal — si user está mid-onboarding
        // pero hasCompletedOnboarding=false (este device no completó setup), ignorar
        // signal del KV-Store. User debe terminar onboarding aquí. Bug #6 P0.
        guard hasCompletedOnboarding else { return }
        showOnboarding = false
        showPositiveToast(L10n.iCloud.remoteOnboardingCompleted)
    }

    private func performLocalWipeForRemoteSync(skipOnboarding: Bool) {
        remoteWipeTask?.cancel()
        remoteWipeTask = Task {
            let sessionState = SessionState.shared
            sessionState.resetToDefaults()
            sessionState.isWipingData = true

            // Wait for MainTabView to dismount (prevents @Query crash)
            try? await Task.sleep(for: .milliseconds(500))

            do {
                try DataWipeService.wipeAllUserData(
                    in: modelContext,
                    broadcastSignal: false  // Reactive wipe — don't re-signal
                )
                themeManager.resetToDefaults()
            } catch {
                #if DEBUG
                print("ContentView: Remote wipe failed: \(error)")
                #endif
            }

            // Let SwiftData settle
            try? await Task.sleep(for: .milliseconds(200))

            sessionState.isWipingData = false

            if skipOnboarding {
                hasCompletedOnboarding = true
                showPositiveToast(L10n.iCloud.remoteRestoreCompleted)
            } else {
                // Reset chooser flag: tras wipe completo, el user vuelve a ver las 3 ramas.
                hasShownWelcomeChooser = false
                hasShownYalaAIOnboarding = false  // tras wipe vuelve a verse el onboarding del chat
                hasCompletedOnboarding = false  // onChange triggers onboarding
            }
        }
    }

    /// Whether the device language needs an in-app override
    private var needsLanguageSelection: Bool {
        !LanguageManager.deviceLanguageIsSupported && LanguageManager.overrideLanguage == nil
    }

    /// Returns What's New data if version changed and features exist.
    /// Nil otherwise. Used to enqueue `.presentWhatsNew` router intent.
    private func whatsNewDataIfPending() -> (features: [WhatsNewFeature], version: String)? {
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        guard !currentVersion.isEmpty, currentVersion != lastSeenAppVersion,
              let features = WhatsNewConfig.features(for: currentVersion) else { return nil }
        return (features: features, version: currentVersion)
    }

    /// Check initial state and decide whether to show language selection, hero, chooser
    /// or main app. Runs during splash so el wait es invisible.
    ///
    /// A4 v3.1: NO hace autopromote por data en iCloud. NO espera 8s con spinner.
    /// El fetch de iCloud lo hace `WelcomeHeroView` invisible mientras el user lee
    /// las cards animadas. Decisión consciente del user — no se carga data sin tap explícito.
    private func checkInitialSyncState() async {
        // GC-08: If group invite onboarding is pending, skip normal flow entirely.
        // The CKShare was already accepted eagerly — just let the invite UI take over.
        if showGroupInviteOnboarding {
            isInitialCheckDone = true
            return
        }

        hasExistingData = checkHasExistingData()
        IntentSignalBreadcrumb.initialSyncChecked(hasExistingData: hasExistingData)

        if hasCompletedOnboarding {
            // Returning user este device — ya completó onboarding antes.
            runReturningUserPostChecks()
            isInitialCheckDone = true
            return
        }

        // First launch este device — Hero/Chooser es decisión consciente del user.
        // NO se autopromueve por data en iCloud (eso lo decide el user en el alert post-Hero).
        presentNextOnboardingScreen()
        isInitialCheckDone = true
    }

    /// Post-checks de returning user: trial pendiente, What's New, language, app update.
    /// Extraído para SSOT — antes vivía inline en `checkInitialSyncState`.
    private func runReturningUserPostChecks() {
        // GC-08: Skip trial/What's New for groupInvite users — they have no context yet
        if !SessionState.shared.isGroupInviteMode {
            if SessionState.shared.needsPostOnboardingTrial && !FeatureGateService.shared.isProUser {
                // Flag limpiado en el drain (presentación real) — ver onChange(showOnboarding).
                Task {
                    await waitForBootstrap()
                    RouterEntryGate.shared.submit(.presentTrialOffer)
                }
            } else if let data = whatsNewDataIfPending() {
                RouterEntryGate.shared.submit(.presentWhatsNew(features: data.features, version: data.version))
            }
        }
        Task { await AppUpdateService.shared.checkForUpdate() }
        if needsLanguageSelection {
            showLanguageSelection = true
        }
    }

    /// Parte F: tras restaurar/onboarding desde la oferta de invitación, re-emite el
    /// invite retenido en `PendingInviteStore` (si lo hay). Idempotente — no-op si no
    /// hay invite pendiente. Con `hasCompletedOnboarding=true` ya, `inviteRouteDecision`
    /// da `.standardReconnect` (no re-oferta); tras wipe da el mini-onboarding de grupos.
    private func reEmitInviteAfterRestore() {
        Task { @MainActor in
            AppBootstrapper.shared.reEmitPendingInviteIfNeeded(isPresenting: false)
        }
    }

    /// Routing único para presentar la siguiente pantalla del flow inicial.
    /// Si Chooser no se ha visto, presenta el flow Welcome (Hero+Chooser unificado).
    private func presentNextOnboardingScreen() {
        #if DEBUG
        // uitest: ir directo al OnboardingView (salta Welcome Hero/Chooser) para
        // testear el flujo de onboarding aislado.
        if UITestHooks.startAtOnboarding {
            showOnboarding = true
            return
        }
        // uitest: presentar el cover de GroupInviteOnboarding directo (CKShare no
        // funciona en sim). `-uitest-join-phase` congela la fase del tracker para
        // testear cada step determinista.
        if UITestHooks.startAtInviteOnboarding {
            if let phase = UITestHooks.joinPhaseOverride {
                GroupJoinIntentTracker.shared._uitestForcePhase(named: phase)
            }
            showGroupInviteOnboarding = true
            return
        }
        #endif
        if needsLanguageSelection {
            showLanguageSelection = true
        } else if !hasShownWelcomeChooser {
            welcomeFlowInitialStep = .hero
            showWelcomeFlow = true
        } else {
            showOnboarding = true
        }
    }

    /// Extracted from body so the overlay isn't recreated on every ContentView
    /// body recompute (dataVersion changes, etc.).
    private var syncStatusBannerOverlay: some View {
        SyncStatusBannerHost { showSyncSettingsSheet = true }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            // Offset below the inline nav bar so the pill doesn't cover the title.
            .padding(.top, 48)
    }

    // A4 v3.1: `iCloudSyncWaitingView` eliminada. El fetch de iCloud ahora corre
    // invisible dentro de `WelcomeHeroView` mientras el user lee las cards animadas.
}

// MARK: - Welcome Flow Modifier

/// Encapsula el flow Welcome con Hero + Chooser unificados en un solo
/// `fullScreenCover` (sin frame "azul vacío" entre ambos). El alert
/// "Detectamos tu cuenta" vive dentro del `WelcomeFlowContainer`.
private struct WelcomeFlowModifier: ViewModifier {
    @Binding var showWelcomeFlow: Bool
    @Binding var welcomeFlowInitialStep: WelcomeFlowStep
    @Binding var showOnboarding: Bool
    @Binding var showWelcomeRestore: Bool
    @Binding var showInviteRecovery: Bool
    @Binding var showWelcomeCloudSignIn: Bool
    /// Provider del cover de sign-in de nube (sesión 2): cada card del chooser lo setea
    /// EXPLÍCITO antes de presentar — jamás se hereda el valor del intento anterior.
    @Binding var welcomeCloudProvider: CloudSignInProvider
    @Binding var prefilledOnboardingData: ICloudAccountSummary?
    @Binding var hasShownWelcomeChooser: Bool
    @Binding var hasCompletedOnboarding: Bool
    @Binding var showFreshStartWipeAlert: Bool
    let hasExistingData: Bool
    /// S5 del review adversarial: el guard cross-cuenta evalúa datos locales EN el
    /// momento de la decisión (fetch vivo), no el snapshot `hasExistingData` — el
    /// mirror de iCloud puede estar re-importando en background durante el Welcome.
    let hasLocalDataNow: @MainActor () -> Bool
    let showGroupInviteOnboarding: Bool

    func body(content: Content) -> some View {
        content
            // Cover único Hero+Chooser. Gate `!showGroupInviteOnboarding`: si
            // llega CKShare, el cover se cierra y `hasShownWelcomeChooser` queda
            // false — el flow reaparece desde el Hero en el próximo cold launch
            // si el invite onboarding se cancela.
            .fullScreenCover(isPresented: $showWelcomeFlow.gated(by: showGroupInviteOnboarding)) {
                WelcomeFlowContainer(
                    initialStep: welcomeFlowInitialStep,
                    onSelectBranch: { branch in
                        hasShownWelcomeChooser = true
                        switch branch {
                        case .new:
                            // Limpia prefs residuales del KV-Store del Apple ID
                            // (userName, currency) que sobreviven al uninstall.
                            OnboardingResetHelper.clearResidualPreferencesForFreshStart()
                            // Segunda barrera vs data residual: el alert "Detectamos tu
                            // cuenta" del Hero cubre el caso iCloud-con-data, pero falla
                            // en (1) sim sin iCloud, (2) timeout del fetch, (3) CloudKit
                            // mirror sync que llega post-Hero. Si hay data al momento del
                            // tap, pedir confirmation explícito antes de wipe.
                            if hasExistingData {
                                showFreshStartWipeAlert = true
                                // welcomeFlow sigue visible hasta resolver el alert
                            } else {
                                showWelcomeFlow = false
                                showOnboarding = true
                            }
                        case .restore:
                            showWelcomeFlow = false
                            showWelcomeRestore = true
                        case .invite:
                            showWelcomeFlow = false
                            showInviteRecovery = true
                        }
                    },
                    onLoadMyData: {
                        // Alert "Detectamos tu cuenta" → "Cargar mis datos":
                        // decisión consciente equivalente a "Ya tengo cuenta" del Chooser.
                        // El RestoreView hace el fetch completo (con quiescencia) y decide
                        // el destino; no usamos un summary prematuro del Hero.
                        hasShownWelcomeChooser = true
                        showWelcomeFlow = false
                        showWelcomeRestore = true
                    },
                    onSelectExistingOption: { option in
                        // H4: sub-elección de "Ya tengo una cuenta" (o su bypass — hoy en
                        // prod DARK siempre .restoreICloud = flujo restore actual intacto).
                        hasShownWelcomeChooser = true
                        switch option {
                        case .restoreICloud:
                            showWelcomeFlow = false
                            showWelcomeRestore = true
                        case .cloudSignIn:
                            welcomeCloudProvider = .apple  // EXPLÍCITO (jamás heredar el previo)
                            showWelcomeFlow = false
                            showWelcomeCloudSignIn = true
                        case .googleSignIn:
                            welcomeCloudProvider = .google
                            showWelcomeFlow = false
                            showWelcomeCloudSignIn = true
                        }
                    }
                )
                .environment(SessionState.shared)
            }
            // H4: re-entrada a una cuenta del Modo Nube (SIWA → exists → adopt).
            // Gate group-invite (mismo patrón que el cover del flow) + onDismiss de
            // respaldo (C2): si UIKit tumba el cover sin terminal, reabrir el chooser
            // — jamás dejar al usuario en pantalla vacía con onboarding incompleto.
            .fullScreenCover(
                isPresented: $showWelcomeCloudSignIn.gated(by: showGroupInviteOnboarding),
                onDismiss: {
                    if !hasCompletedOnboarding && !showGroupInviteOnboarding {
                        welcomeFlowInitialStep = .chooser
                        showWelcomeFlow = true
                    }
                }
            ) {
                WelcomeCloudSignInView(
                    provider: welcomeCloudProvider,
                    hasLocalDataNow: hasLocalDataNow,
                    onAdoptStarted: {
                        // TEMPRANO (antes de conducir la máquina): cierra el hazard
                        // kill-mid-adopt → el seed del onboarding jamás corre sobre una
                        // cuenta existente; un kill aterriza en MainTab con la card de
                        // Almacenamiento reflejando el estado real del adopt.
                        completeOnboardingAsRestoreSkip()
                        hasCompletedOnboarding = true
                    },
                    onSecondaryEntryFlagsMarked: {
                        // M1 (D1, decisión owner): flags SÍ, trial NO (la invitada no recibe
                        // la oferta del device del dueño) ni markAsNewInstall (el checklist
                        // es estado device-global del dueño).
                        UserDefaults.standard.set(true, forKey: AppPreferences.Keys.hasCompletedOnboarding)
                        hasCompletedOnboarding = true
                    },
                    onFinishedToApp: {
                        showWelcomeCloudSignIn = false
                    },
                    onBack: {
                        showWelcomeCloudSignIn = false
                        welcomeFlowInitialStep = .chooser
                        showWelcomeFlow = true
                    }
                )
            }
    }
}

// MARK: - Sign-out relaunch net (H4, C1 del review adversarial + fix carrera 2026-07-14)

/// DUEÑO ÚNICO del cover terminal del cierre de sesión `.cloud`/secundario (`awaitingRelaunch`
/// = wipe de boot ARMADO). ProfileView ya NO presenta (ante la fase solo cierra su sheet):
/// dos anchors ante el mismo observable eran una carrera de reconciliación — UIKit no
/// presenta dos veces y tumbaba AMBAS cadenas dejando el flag en `true` sin onDismiss
/// (red muerta, app usable con el wipe armado; bug device 2026-07-14).
///
/// Verificación de presentación EFECTIVA: el flag NO prueba nada — solo el `onAppear` del
/// contenido real (`coverDidAppear`) confirma que UIKit presentó. El primer intento puede
/// caer con la sheet de Profile aún cerrándose → el verify loop reintenta (toggle
/// false→true, cadencias en `RelaunchNetLogic`) hasta `satisfied` o el cap del ciclo.
/// `signOutRelaunch` es además blocker de la matriz por CONDICIÓN VIVA (la fase, no este
/// flag) — el router queda contenido desde la transición aunque el cover tarde en llegar.
private struct SignOutRelaunchNetModifier: ViewModifier {
    @Binding var showRelaunchCover: Bool

    /// true SOLO cuando el onAppear del contenido real disparó (única prueba de presentación).
    @State private var coverDidAppear = false
    @State private var verifyTask: Task<Void, Never>?
    @Environment(\.scenePhase) private var scenePhase

    private var phase: CloudSessionSignOut.Phase { CloudSessionSignOut.shared.phase }

    func body(content: Content) -> some View {
        content
            .onAppear {
                if phase == .awaitingRelaunch { arm() }
            }
            .onChange(of: phase) { _, newPhase in
                if newPhase == .awaitingRelaunch { arm() }
            }
            // Ciclo FRESCO al volver a foreground con la condición armada y sin cover
            // (el cap de intentos es por-ciclo, no de por vida).
            .onChange(of: scenePhase) { _, newScene in
                if newScene == .active && phase == .awaitingRelaunch && !coverDidAppear { arm() }
            }
            .fullScreenCover(
                isPresented: $showRelaunchCover,
                onDismiss: {
                    // Terminal: si UIKit lo tumbara, re-presentar (regla toolbar-muerta).
                    coverDidAppear = false
                    if CloudSessionSignOut.shared.phase == .awaitingRelaunch { arm() }
                }
            ) {
                SignOutRelaunchView()
                    .onAppear {
                        // Presentación REAL confirmada (dispara al inicio de la animación;
                        // idempotente ante doble onAppear). Jamás se toggla un cover vivo.
                        coverDidAppear = true
                        verifyTask?.cancel()
                        verifyTask = nil
                    }
            }
    }

    private func arm() {
        showRelaunchCover = true
        // Cancel-before-start: un solo verify loop vivo — dos loops togglando el mismo
        // binding reproducirían la carrera que este fix mata.
        verifyTask?.cancel()
        verifyTask = runRelaunchNetVerifyLoop(
            net: "signout",
            armed: { CloudSessionSignOut.shared.phase == .awaitingRelaunch },
            coverDidAppear: { coverDidAppear },
            setCover: { showRelaunchCover = $0 }
        )
    }
}

// MARK: - Secondary entry relaunch net (M1, molde C1)

/// Red DURABLE de la VENTANA DE ENTRADA secundaria (descriptor persistido, store del DUEÑO
/// montado): el cover primario es la fase `.relaunchSecondary` DENTRO del welcome cloud cover;
/// si ese cover muere por cualquier vía (con los flags de onboarding ya puestos, el onDismiss
/// del container no reabre nada → la app quedaría usable sobre el store del dueño), este anchor
/// re-presenta el cover terminal. `secondaryEntryRelaunch` es además blocker de la matriz.
/// Mismo hardening de presentación efectiva que `SignOutRelaunchNetModifier` (la ENTRADA M1
/// comparte la suposición refutada en device: "SwiftUI materializa la presentación pendiente
/// al despejarse el anchor" — falso). Triggers propios (statics + señal del welcome cover);
/// lo compartido es la decisión pura (`RelaunchNetLogic`) y el loop (`runRelaunchNetVerifyLoop`).
private struct SecondaryEntryRelaunchNetModifier: ViewModifier {
    @Binding var showRelaunchCover: Bool
    /// El flag del welcome cloud cover — su caída con la ventana armada dispara la red.
    let welcomeCloudCoverVisible: Bool

    /// true SOLO cuando el onAppear del contenido real disparó (única prueba de presentación).
    @State private var coverDidAppear = false
    @State private var verifyTask: Task<Void, Never>?
    @Environment(\.scenePhase) private var scenePhase

    private var isArmedUnmounted: Bool {
        SecondarySessionStore.isActive() && !SwiftDataConfiguration.secondaryStoreMounted
    }

    func body(content: Content) -> some View {
        content
            .onAppear {
                if isArmedUnmounted { arm() }
            }
            .onChange(of: welcomeCloudCoverVisible) { _, visible in
                if !visible && isArmedUnmounted { arm() }
            }
            // Ciclo FRESCO al volver a foreground (cap por-ciclo, no de por vida).
            .onChange(of: scenePhase) { _, newScene in
                if newScene == .active && isArmedUnmounted && !coverDidAppear
                    && !welcomeCloudCoverVisible { arm() }
            }
            .fullScreenCover(
                isPresented: $showRelaunchCover,
                onDismiss: {
                    // Terminal: si UIKit lo tumbara, re-presentar (regla toolbar-muerta).
                    coverDidAppear = false
                    if isArmedUnmounted { arm() }
                }
            ) {
                SignOutRelaunchView()
                    .onAppear {
                        // Presentación REAL confirmada (idempotente). Jamás togglar un cover vivo.
                        coverDidAppear = true
                        verifyTask?.cancel()
                        verifyTask = nil
                    }
            }
    }

    private func arm() {
        showRelaunchCover = true
        // Cancel-before-start: un solo verify loop vivo.
        verifyTask?.cancel()
        verifyTask = runRelaunchNetVerifyLoop(
            net: "secondaryEntry",
            armed: {
                SecondarySessionStore.isActive()
                    && !SwiftDataConfiguration.secondaryStoreMounted
            },
            coverDidAppear: { coverDidAppear },
            setCover: { showRelaunchCover = $0 }
        )
    }
}

/// Verify loop COMPARTIDO de las dos redes de relaunch terminal (un solo punto de verdad
/// del reintento — la decisión pura vive en `RelaunchNetLogic`, los triggers en cada
/// modifier). El closure `coverDidAppear` lee el `@State` del modifier en el momento de
/// cada chequeo; `setCover` escribe su binding.
@MainActor
fileprivate func runRelaunchNetVerifyLoop(
    net: String,
    armed: @escaping @MainActor () -> Bool,
    coverDidAppear: @escaping @MainActor () -> Bool,
    setCover: @escaping @MainActor (Bool) -> Void
) -> Task<Void, Never> {
    Task { @MainActor in
        try? await Task.sleep(for: RelaunchNetLogic.initialVerifyDelay)
        var attempt = 0
        while !Task.isCancelled {
            switch RelaunchNetLogic.verdict(
                armed: armed(),
                coverDidAppear: coverDidAppear(),
                attempt: attempt
            ) {
            case .standDown, .satisfied:
                return
            case .exhausted:
                CloudSyncBreadcrumb.relaunchNetExhausted(net: net)
                MetricsService.canary(.relaunchNetExhausted, detail: net)
                return
            case .retry:
                // Cede un runloop y re-chequea antes de togglar: el onAppear del cover
                // pudo encolarse justo antes del verdict (presentación aceptada a ~ms del
                // deadline) — jamás tumbar un cover recién vivo.
                await Task.yield()
                guard !Task.isCancelled, !coverDidAppear() else { return }
                attempt += 1
                CloudSyncBreadcrumb.relaunchNetRetried(net: net, attempt: attempt)
                setCover(false)
                try? await Task.sleep(for: RelaunchNetLogic.toggleGap)
                guard !Task.isCancelled else { return }
                setCover(true)
                try? await Task.sleep(for: RelaunchNetLogic.retryInterval)
            }
        }
    }
}

// MARK: - Helpers (file-private SSOT)

/// Side-effect de `WelcomeRestoreView.onCompleteSkipAll` (rama fullyPrefilled):
/// setea trial pendiente, completion flag y new-install marker.
fileprivate func completeOnboardingAsRestoreSkip() {
    if !FeatureGateService.shared.isProUser {
        SessionState.shared.needsPostOnboardingTrial = true
    }
    UserDefaults.standard.set(true, forKey: AppPreferences.Keys.hasCompletedOnboarding)
    SetupChecklistManager.shared.markAsNewInstall()
}

/// Binding gate: el flag solo se refleja `true` si `inhibitor == false`.
/// Setear el binding a `false` siempre llega al storage. Centraliza el patrón
/// "auto-cerrar Hero/alert/chooser cuando llega un CKShare" en el flow de
/// onboarding A4 v3.1.
fileprivate extension Binding where Value == Bool {
    func gated(by inhibitor: Bool) -> Binding<Bool> {
        Binding(
            get: { wrappedValue && !inhibitor },
            set: { wrappedValue = $0 }
        )
    }
}

// MARK: - Group Invite Modifier (GC-08)

/// Extracted to a ViewModifier to avoid type-checker complexity in ContentView body.
private struct GroupInviteModifier: ViewModifier {

    /// Handler del CTA de GroupReconnectView según el mode del invite. Cada mode dispara
    /// una acción distinta: archived no debe llegar acá (CTA es solo dismiss); alreadyMember/
    /// pendingDuplicate solo navegan; los retry modes (rejected/left/removed) aceptan el
    /// share + reactivan al member como pending.
    @MainActor
    /// Grace period tras `acceptShare` para que CKSyncEngine fetch + propague el grupo
    /// antes de navegar — sin esto el detalle abre vacío.
    private static let postAcceptGracePeriod: Duration = .seconds(2)

    static func handleReconnectJoin(invite: InviteMetadata) async {
        let metadata = invite.shareMetadata
        let zoneName = metadata.share.recordID.zoneID.zoneName

        switch invite.mode {
        case .archived, .deletedForAll:
            // .deletedForAll (FU-02): el CTA solo dismissa, nunca llega aquí. Defensa-en-profundidad.
            return

        case .alreadyMember:
            if let group = SplitSyncManager.shared.group(for: zoneName) {
                RouterEntryGate.shared.submit(.navigate(.groupDetail(groupID: group.id.uuidString)))
            } else {
                RouterEntryGate.shared.submit(.navigate(.groups))
            }

        case .pendingDuplicate:
            RouterEntryGate.shared.submit(.navigate(.groups))

        case .rejectedRetry, .leftRetry, .removedRetry:
            await acceptAndSettle(metadata: metadata)
            // `group(for:)` y `ensureCurrentUserMemberExists` operan ambos sobre el mainContext
            // compartido (el sync ya no usa un contexto dedicado) → mismo contexto, sin riesgo cross-context.
            if let group = SplitSyncManager.shared.group(for: zoneName) {
                do {
                    _ = try await GroupService.shared.ensureCurrentUserMemberExists(in: group, reactivateInactive: true)
                } catch {
                    #if DEBUG
                    print("ContentView: ensureCurrentUserMemberExists retry failed: \(error)")
                    #endif
                }
            }
            RouterEntryGate.shared.submit(.navigate(.groups))

        case .standardReconnect:
            await acceptAndSettle(metadata: metadata)
            RouterEntryGate.shared.submit(.navigate(.groups))
        }
    }

    private static func acceptAndSettle(metadata: CKShare.Metadata) async {
        await SplitSyncManager.shared.acceptShare(metadata: metadata)
        try? await Task.sleep(for: postAcceptGracePeriod)
        SessionState.shared.incrementDataVersion()
    }

    @Binding var showGroupInviteOnboarding: Bool
    @Binding var pendingInviteMetadata: InviteMetadata?
    @Binding var showGroupReconnect: Bool
    @Binding var hasCompletedOnboarding: Bool
    @Binding var pendingReconnectInvite: InviteMetadata?
    @Binding var activeInviteError: String?
    @Binding var activeGroupSyncError: String?
    @Binding var showWelcomeFlow: Bool
    @Binding var welcomeFlowInitialStep: WelcomeFlowStep

    func body(content: Content) -> some View {
        content
            .alert(
                String(localized: "groups.invite.linkInvalidTitle"),
                isPresented: Binding(
                    get: { activeInviteError != nil },
                    set: { if !$0 { activeInviteError = nil } }
                )
            ) {
                Button(String(localized: "common.ok"), role: .cancel) {}
            } message: {
                Text((activeInviteError?.isEmpty ?? true)
                     ? String(localized: "groups.invite.linkInvalidDetail")
                     : (activeInviteError ?? ""))
            }
            .alert(
                String(localized: "groups.bridge.alertTitle"),
                isPresented: Binding(
                    get: { activeGroupSyncError != nil },
                    set: { if !$0 { activeGroupSyncError = nil } }
                )
            ) {
                Button(String(localized: "common.ok"), role: .cancel) {}
            } message: {
                Text(activeGroupSyncError ?? "")
            }
            .fullScreenCover(isPresented: $showGroupInviteOnboarding) {
                GroupInviteOnboardingView(inviteMetadata: pendingInviteMetadata) { outcome in
                    // Consumo del invite pendiente según el outcome: en abandono con
                    // error RECUPERABLE se conserva para que el re-emit de cold
                    // launch/foreground reintente el accept (TTL 24h).
                    if GroupInviteOnboardingLogic.shouldClearPendingInvite(outcome: outcome) {
                        PendingInviteStore.clear()
                    }
                    // El setup silencioso ya corrió (nombre/moneda): no re-onboardear
                    // en ningún outcome; el join intent sigue trabajando en background.
                    hasCompletedOnboarding = true
                    showGroupInviteOnboarding = false
                    pendingInviteMetadata = nil
                }
                .environment(SessionState.shared)
            }
            .sheet(isPresented: $showGroupReconnect, onDismiss: {
                // Consumo del invite pendiente al cerrar el reconnect (X / swipe / CTA).
                // Incondicional y antes de reabrir welcome → no re-emerge.
                PendingInviteStore.clear()
                pendingReconnectInvite = nil
                // Pre-onboarding: user llegó al sheet vía Chooser → InviteRecoveryView →
                // handleInviteLink. Cualquier dismiss (X, swipe down, CTA) sin reabrir
                // Chooser deja pantalla vacía.
                if !hasCompletedOnboarding && !showWelcomeFlow {
                    welcomeFlowInitialStep = .chooser
                    showWelcomeFlow = true
                }
            }) {
                if let invite = pendingReconnectInvite {
                    GroupReconnectView(
                        invite: invite,
                        onJoin: {
                            let captured = invite
                            showGroupReconnect = false
                            Task { @MainActor in
                                await Self.handleReconnectJoin(invite: captured)
                            }
                        },
                        onDismiss: {
                            showGroupReconnect = false
                        }
                    )
                    .environment(SessionState.shared)
                }
            }
    }
}

// MARK: - TabView Principal con Search Role (iOS 18+)

struct MainTabView: View {
    @Bindable private var sessionState: SessionState
    @Environment(\.requestReview) private var requestReview
    @Environment(\.yalaTheme) private var theme
    @Environment(\.modelContext) private var modelContext
    @State private var searchText: String = ""
    @AppStorage(TabBarConfiguration.storageKey) private var tabConfigJSON: String = TabBarConfiguration.default.toJSON()
    /// Gate beta de Grupos (validación v2.0.1). @AppStorage directo: reacciona al
    /// desbloqueo desde la card de "Más", el gate o `CKShareEntryHandler` (invitados).
    @AppStorage(AppPreferences.Keys.groupsBetaUnlocked) private var groupsBetaUnlocked = false
    /// Gate "Grupos necesita iCloud" (§i.8(c)2): singleton observado — leer `status`
    /// (stored) en el branch `.groups` registra la dependencia; `isAccountAvailable`
    /// es computed y @Observable no la trackea. Patrón iCloudSyncSettingsView.
    @State private var syncService = iCloudSyncService.shared

    // On-demand data for downgrade resolution (replaces @Query to prevent 0x8BADF00D)
    @State private var downgradeAccounts: [Account] = []
    @State private var downgradeBudgets: [Budget] = []
    @State private var showDowngradeResolution = false
    @State private var showTrialExpired = false
    /// Milestone number for the upgrade sheet — also drives sheet
    /// presentation (non-nil → shown). Carried by .presentMilestoneUpgrade.
    @State private var activeMilestone: Int?

    private var tabConfig: TabBarConfiguration {
        TabBarConfiguration.fromJSON(tabConfigJSON)
    }

    /// Tabs to show: mode-aware config + temporary tab (if set and not already active)
    private var visibleTabs: [ConfigurableTab] {
        let secondary = SecondarySessionStore.isActive()
        let modeConfig = TabBarConfiguration.forMode(
            sessionState.onboardingMode, stored: tabConfig, secondarySessionActive: secondary,
            groupsBackendEnabled: CloudSyncFlags.groupsBackendEnabled)
        var tabs = modeConfig.activeTabs
        // M1 / D8: el temporaryTab tampoco puede colar `.groups` en secundaria con el canal backend
        // APAGADO (grupos = iCloud del dueño); con el flag ON la invitada ve sus propios grupos ⇒ se permite.
        if let temp = sessionState.temporaryTab, !tabs.contains(temp),
           !(secondary && temp == .groups && !CloudSyncFlags.groupsBackendEnabled) {
            tabs.append(temp)
        }
        return tabs
    }

    /// iPhone's tab bar shows at most 5 items; anything beyond collapses into
    /// iOS's native "More" controller (stray back chevron + ugly system list).
    /// configurables + More + Search reaches 6 once a temporary tab pushes the
    /// configurable count to 4, so we drop Search there.
    ///
    /// Edge case: navigating *from* Search to a hidden tab sets `temporaryTab`
    /// synchronously while `selectMainTab` defers `selectedMainTab` ~50ms, so the
    /// selection can briefly point at an unmounted Search tab; it self-heals once
    /// `selectedMainTab` lands on the destination. Keeping Search mounted during
    /// that window would push the bar back to 6 items, so the transient is
    /// accepted over re-triggering iOS's native More.
    private var showsSearchTab: Bool {
        visibleTabs.count <= 3
    }

    init() {
        // Get SessionState from the environment wrapper
        // This is initialized here to work with @Bindable
        _sessionState = Bindable(wrappedValue: SessionState.shared)
    }

    var body: some View {
        // IMPORTANT: When wiping data, completely unmount the TabView to deactivate all @Query observers
        // This prevents crashes from SwiftUI trying to access invalidated model instances
        if sessionState.isWipingData {
            wipingDataView
        } else {
            TabView(selection: $sessionState.selectedMainTab) {
                // Dynamic tabs based on configuration + temporary tab
                ForEach(visibleTabs) { tab in
                    Tab(tab.displayName, systemImage: tab.iconName, value: tab.appTab) {
                        viewForTab(tab)
                    }
                }

                Tab(L10n.Tab.more, systemImage: "ellipsis", value: .more) {
                    MoreView()
                }

                // Search tab with .search role - pinned to trailing edge.
                // Hidden past the 5-item limit while a temporary tab is active.
                if showsSearchTab {
                    Tab(value: .search, role: .search) {
                        GlobalSearchView()
                    }
                }
            }
            .tint(theme.accent)
            .tabBarMinimizeBehavior(.onScrollDown)
            .transaction { $0.animation = nil }
            // M1: fase real de la hidratación de la sesión secundaria (no-op para el dueño).
            .overlay(alignment: .top) { SecondaryHydrationBanner() }
            .sheet(isPresented: $showDowngradeResolution) {
                DowngradeResolutionSheet(
                    accounts: downgradeAccounts,
                    budgets: downgradeBudgets
                ) {
                    showDowngradeResolution = false
                }
            }
            .sheet(isPresented: $showTrialExpired) {
                UpgradePromptSheet(feature: .voiceInput, context: .trialExpired, source: "trialExpired")
                    // One-shot quemado al PRESENTARSE de verdad (no en el drain):
                    // si el sheet queda tapado por un cover superior, el flag sigue
                    // false y el productor re-emite en el próximo foreground.
                    // En el callsite (no dentro de UpgradePromptSheet: multi-contexto).
                    .onAppear { ProUpsellService.shared.markTrialExpiredSheetShown() }
            }
            .sheet(item: Binding(
                get: { activeMilestone.map(MilestoneIdentifier.init) },
                set: { activeMilestone = $0?.value }
            )) { wrapper in
                MilestoneUpgradeSheet(milestone: wrapper.value)
            }
            .routerConsumer(.mainTab) {
                drainMainTabIntents()
            }
            // Re-drain al liberarse el shell (cerrar un cover superior no bumpea
            // revision — mismo racional que el gate del ChatSheet en PanelShell).
            .onChange(of: sessionState.shellModalBlocker) { _, newBlocker in
                if newBlocker == nil { drainMainTabIntents() }
            }
            .onChange(of: showDowngradeResolution) { _, _ in publishMainTabModalVisibilityAndRedrain() }
            .onChange(of: showTrialExpired) { _, _ in publishMainTabModalVisibilityAndRedrain() }
            .onChange(of: activeMilestone) { _, _ in publishMainTabModalVisibilityAndRedrain() }
        }
    }

    /// True mientras un sheet propio de MainTabView está presentado.
    private var ownModalVisible: Bool {
        showDowngradeResolution || showTrialExpired || activeMilestone != nil
    }

    /// Publica la visibilidad para el guard de `.panel` y la matriz del shell,
    /// y re-drena al cerrar un sheet propio (el siguiente intent retenido entra).
    private func publishMainTabModalVisibilityAndRedrain() {
        if sessionState.isMainTabModalVisible != ownModalVisible {
            sessionState.isMainTabModalVisible = ownModalVisible
        }
        if !ownModalVisible { drainMainTabIntents() }
    }

    /// Drain peek-first de `.mainTab` (Clase D): un intent que presenta un sheet
    /// propio se RETIENE en cola mientras el shell esté tapado o ya haya un
    /// sheet propio arriba — antes se consumía a ciegas y el sheet se seteaba
    /// tapado (one-shots quemados sin verse, presentaciones "que saltan").
    private func drainMainTabIntents() {
        guard let next = AppRouter.shared.peekNext(for: .mainTab) else { return }
        let decision = RouterConsumerGateLogic.mainTabDecision(
            intent: next,
            shellBlocker: sessionState.shellModalBlocker,
            ownModalVisible: ownModalVisible
        )
        guard decision == .drain else {
            // Canario D4: solo los flags PUBLICADOS pueden quedar pegados
            // (shellModalBlocker); ownModalVisible es @State local atado a
            // sheets reales que SwiftUI resetea en el dismiss.
            if let blocker = sessionState.shellModalBlocker {
                RouterHoldCanary.shared.noteHold(intentID: next.id, blocker: blocker, consumer: "mainTab")
            }
            #if DEBUG
            print("MainTabView drain hold: \(next.id) por \(sessionState.shellModalBlocker ?? "ownModal")")
            #endif
            return
        }
        guard let intent = AppRouter.shared.drainNext(for: .mainTab) else { return }
        RouterHoldCanary.shared.noteDrained(intentID: intent.id)
        handleMainTabIntent(intent)
    }

    private func handleMainTabIntent(_ intent: RouterIntent) {
        switch intent {
        case .navigate(let dest):
            // GC-08 guard centralizado en SessionState.selectMainTab — los
            // intents no-groups en modo groupInvite se descartan ahí.
            switch dest {
            case .panel:
                sessionState.selectMainTab(.panel)
            case .statistics:
                sessionState.selectMainTab(.statistics)
            case .records:
                sessionState.selectedDetailTab = .records
                sessionState.selectMainTab(.statistics)
            case .categories:
                sessionState.selectedDetailTab = .categories
                sessionState.selectMainTab(.statistics)
            case .planning:
                sessionState.selectMainTab(.planning)
            case .budgets:
                sessionState.selectedPlanningTab = .budgets
                sessionState.selectMainTab(.planning)
            case .inbox:
                sessionState.selectMainTab(.panel)
                RouterEntryGate.shared.submit(.presentInboxSheet)
            case .scheduledPayments:
                sessionState.selectedPlanningTab = .scheduledPayments
                sessionState.selectMainTab(.planning)
            case .recordsStandalone:
                sessionState.selectMainTab(.records)
            case .groups, .groupDetail:
                sessionState.enteredViaGroupNotification = true
                if case .groupDetail(let groupID) = dest {
                    sessionState.pendingGroupID = groupID
                }
                sessionState.selectMainTab(.groups)
            }
        case .presentDowngradeResolution:
            do {
                let accounts = try modelContext.fetch(FetchDescriptor<Account>())
                let budgets = try modelContext.fetch(
                    FetchDescriptor<Budget>(predicate: #Predicate { $0.isActive })
                )
                let activeAccounts = accounts.filter { !$0.isArchived }
                if activeAccounts.count > 2 || budgets.count > 3 {
                    downgradeAccounts = accounts
                    downgradeBudgets = budgets
                    showDowngradeResolution = true
                }
            } catch {
                // No presentar con datos parciales: el productor re-encola en el
                // siguiente cold launch mientras la condición de downgrade persista.
                #if DEBUG
                print("ContentView: fetch downgrade falló: \(error)")
                #endif
            }
        case .presentTrialExpired:
            // El one-shot se quema en el onAppear del sheet, no aquí: .mainTab
            // drena aunque un cover superior lo tape y quemarlo drenado-tapado
            // perdía el aviso de expiración PARA SIEMPRE.
            showTrialExpired = true
        case .presentMilestoneUpgrade(let milestone):
            activeMilestone = milestone
        case .requestAppStoreReview:
            let action = requestReview
            Task {
                try? await Task.sleep(for: .seconds(1))  // UX delay, not sync
                action()
                ReviewPromptService.recordPromptShown()
            }
        default:
            break
        }
    }

    @ViewBuilder
    private func viewForTab(_ tab: ConfigurableTab) -> some View {
        switch tab {
        case .panel:
            PanelShell()
        case .statistics:
            StatisticsView()
        case .planning:
            PlanningView()
        case .records:
            RecordsStandaloneView()
        case .reports:
            FinancialReportView()
        case .groups:
            // `isAccountAvailable` es COMPUTED (@Observable no la trackea); `status` es
            // stored y transiciona vía NSUbiquityIdentityDidChange → leerlo registra la
            // dependencia que re-evalúa este branch cuando la cuenta iCloud cambia.
            let _ = syncService.status
            if GroupsBetaGateLogic.shouldShowGate(isUnlocked: groupsBetaUnlocked,
                                                  isGroupInviteMode: sessionState.isGroupInviteMode) {
                GroupsBetaGateView()
            } else if !CloudSyncFlags.groupsBackendEnabled,
                      GroupsICloudAvailabilityGateLogic.shouldShowGate(
                          isAccountAvailable: syncService.isAccountAvailable,
                          isUITest: UITestHooks.isActive
                      ) {
                // M1 / D8 (G5-C): el gate CloudKit-era (sin iCloud del OS) se RETIRA bajo el flag — el
                // canal grupos→backend no exige la cuenta iCloud del sistema. Con flag OFF (TODO device
                // prod hoy) es byte-idéntico. La lógica pura y la vista NO se borran (retiro real post-G6).
                GroupsICloudUnavailableView()
            } else {
                GroupsContainerView()
            }
        }
    }

    private var wipingDataView: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: DS.Spacing.xl) {
                ProgressView()
                    .scaleEffect(1.5)

                Text(L10n.Settings.deletingData)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// `.sheet(item:)` requires Identifiable — this wraps Int so milestone
/// presentation binds to `activeMilestone: Int?` directly.
private struct MilestoneIdentifier: Identifiable {
    let value: Int
    var id: Int { value }
}

// MARK: - App Tab Enum

enum AppTab: Hashable {
    case panel
    case statistics
    case planning
    case more
    case search
    case records
    case reports
    case groups
}


#Preview {
    ContentView()
        .modelContainer(
            for: [
                Account.self,
                TransactionItem.self,
                Category.self,
                Subcategory.self,
                Tag.self,
                Budget.self,
                ExchangeRate.self,
            ], inMemory: true)
}
