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
    @State private var deduplicationTask: Task<Void, Never>?
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
    @State private var showFullModeActivation: Bool = false
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

    private let authService = BiometricAuthService.shared

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
            // onboarding, and biometric lock flows.
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
        } message: {
            Text(L10n.Welcome.FreshStart.alertMessage)
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
                    prefilledOnboardingData = summary
                    showWelcomeRestore = false
                    showOnboarding = true
                },
                onCompleteSkipAll: {
                    completeOnboardingAsRestoreSkip()
                    showWelcomeRestore = false
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
            }
            .environment(SessionState.shared)
        }
        .modifier(WelcomeFlowModifier(
            showWelcomeFlow: $showWelcomeFlow,
            welcomeFlowInitialStep: $welcomeFlowInitialStep,
            showOnboarding: $showOnboarding,
            showWelcomeRestore: $showWelcomeRestore,
            showInviteRecovery: $showInviteRecovery,
            prefilledOnboardingData: $prefilledOnboardingData,
            hasShownWelcomeChooser: $hasShownWelcomeChooser,
            hasCompletedOnboarding: $hasCompletedOnboarding,
            showFreshStartWipeAlert: $showFreshStartWipeAlert,
            hasExistingData: hasExistingData,
            showGroupInviteOnboarding: showGroupInviteOnboarding
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
                SessionState.shared.needsPostOnboardingTrial = false
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
        // Biometric lock as fullScreenCover (covers everything including sheets)
        .fullScreenCover(isPresented: Binding(
            get: { authService.isLocked && !showSplash },
            set: { _ in }  // Dismiss handled by BiometricLockOverlay.authenticate()
        )) {
            BiometricLockOverlay()
                .environment(SessionState.shared)
        }
        // Inbox alert as fullScreenCover (appears over any sheet).
        // Driven by @State set by the .contentView drain handler.
        .fullScreenCover(isPresented: Binding(
            get: { !activeInboxNotification.isEmpty },
            set: { _ in }
        )) {
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
            authService.lockOnLaunchIfNeeded()
        }
        .onChange(of: colorScheme) { _, newScheme in
            themeManager.systemColorScheme = newScheme
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                authService.appDidEnterBackground()
            case .active:
                authService.appDidEnterForeground()
                // GC-08: Recalculate user segment on each foreground activation
                UserSegmentService.shared.recalculate()
            default:
                break
            }
        }
        .onChange(of: authService.isLocked) { _, newLocked in
            updateContentViewReadiness()
            // When biometric unlocks, drain the DeferredIntentBuffer so any
            // notification taps that arrived while locked land now — without
            // waiting for the next background→foreground cycle.
            if !newLocked {
                RouterEntryGate.shared.drainDeferredBuffer()
            }
        }
        .onChange(of: SessionState.shared.isWipingData) { _, _ in updateContentViewReadiness() }
        // Shell-level modal flags gate readiness via pure-logic
        // ContentViewReadinessLogic. Encapsulated in a ViewModifier to keep
        // ContentView's body within the type-checker's budget.
        .readinessGateObservers(
            showOnboarding: showOnboarding,
            showWelcomeFlow: showWelcomeFlow,
            showLanguageSelection: showLanguageSelection,
            showWelcomeRestore: showWelcomeRestore,
            showInviteRecovery: showInviteRecovery,
            showFreshStartWipeAlert: showFreshStartWipeAlert,
            showRemoteWipeAlert: showRemoteWipeAlert,
            showICloudRestartAlert: showICloudRestartAlert,
            activeInboxNotification: activeInboxNotification,
            showGroupInviteOnboarding: showGroupInviteOnboarding,
            showGroupReconnect: showGroupReconnect,
            showFullModeActivation: showFullModeActivation,
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
        }
    }

    // MARK: - Router Consumer

    /// Single source of truth for `.contentView` readiness. Called from every
    /// flag that can block shell presentation. Delegates to pure-logic
    /// `ContentViewReadinessLogic.isReady(state:)` so the gating matrix is
    /// testable independently of SwiftUI state.
    @MainActor
    private func updateContentViewReadiness() {
        let state = ShellReadinessState(
            isSplashDismissed: SessionState.shared.isSplashDismissed,
            isLocked: authService.isLocked,
            isWipingData: SessionState.shared.isWipingData,
            showOnboarding: showOnboarding,
            showWelcomeFlow: showWelcomeFlow,
            showLanguageSelection: showLanguageSelection,
            showWelcomeRestore: showWelcomeRestore,
            showInviteRecovery: showInviteRecovery,
            showFreshStartWipeAlert: showFreshStartWipeAlert,
            showRemoteWipeAlert: showRemoteWipeAlert,
            showICloudRestartAlert: showICloudRestartAlert,
            hasActiveInboxAlert: !activeInboxNotification.isEmpty,
            showGroupInviteOnboarding: showGroupInviteOnboarding,
            showGroupReconnect: showGroupReconnect,
            showFullModeActivation: showFullModeActivation
        )
        let ready = ContentViewReadinessLogic.isReady(state: state)
        if ready {
            AppRouter.shared.markReady(.contentView)
        } else {
            AppRouter.shared.markUnready(.contentView)
            if let blocker = ContentViewReadinessLogic.blocker(state: state) {
                #if DEBUG
                print("ContentView readiness blocked by: \(blocker)")
                #endif
                // Throttle telemetry: only fire for non-trivial blockers (skip splash/lock
                // which are common boot states; surface user-visible modals only).
                let surfacedBlockers: Set<String> = [
                    "activeInboxAlert", "groupInviteOnboarding", "groupReconnect",
                    "fullModeActivation", "remoteWipeAlert", "iCloudRestartAlert",
                    "freshStartWipeAlert"
                ]
                if surfacedBlockers.contains(blocker) {
                    TelemetryService.routingReadinessBlocked(blocker: blocker)
                }
            }
        }
    }

    /// Drains one `.contentView` intent per revision bump. Single-intent
    /// drain — handler may enqueue new intents, they process next tick.
    @MainActor
    private func drainContentViewIntents() {
        guard let intent = AppRouter.shared.drainNext(for: .contentView) else { return }
        switch intent {
        case .showInboxAlert(let notif):
            activeInboxNotification = notif
        case .presentTrialOffer:
            showProTrialOffer = true
        case .presentWhatsNew(let features, let version):
            whatsNewData = (features: features, version: version)
            showWhatsNew = true
        case .presentGroupInviteOnboarding(let invite):
            pendingInviteMetadata = invite
            showGroupInviteOnboarding = true
        case .presentGroupReconnect(let invite):
            pendingReconnectInvite = invite
            showGroupReconnect = true
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
        default:
            break
        }
    }

    /// Schedule one-shot dedup after a delay (at most once per launch)
    private func scheduleDeduplication() {
        guard deduplicationTask == nil else { return }
        deduplicationTask = Task {
            do {
                try await Task.sleep(for: .seconds(10))
                CategoryDeduplicationService.deduplicateSeedCategories(in: modelContext)
            } catch {
                // Task cancelled
            }
        }
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
                SessionState.shared.needsPostOnboardingTrial = false
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
    @Binding var prefilledOnboardingData: ICloudAccountSummary?
    @Binding var hasShownWelcomeChooser: Bool
    @Binding var hasCompletedOnboarding: Bool
    @Binding var showFreshStartWipeAlert: Bool
    let hasExistingData: Bool
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
                    onLoadMyData: { summary in
                        // Alert "Detectamos tu cuenta" → "Cargar mis datos":
                        // decisión consciente equivalente a tap card del Chooser.
                        hasShownWelcomeChooser = true
                        showWelcomeFlow = false
                        consumeDetectedSummary(summary)
                    }
                )
                .environment(SessionState.shared)
            }
    }

    /// Replica logic de `WelcomeRestoreView` callbacks SIN re-fetch (alert ya tiene summary).
    private func consumeDetectedSummary(_ summary: ICloudAccountSummary) {
        if summary.isFullyPrefilled {
            completeOnboardingAsRestoreSkip()
        } else {
            prefilledOnboardingData = summary
            showOnboarding = true
        }
    }
}

// MARK: - Helpers (file-private SSOT)

/// Side-effect compartido entre `WelcomeRestoreView.onCompleteSkipAll` (callback en
/// ContentView body) y `WelcomeFlowModifier.consumeDetectedSummary` (rama
/// fullyPrefilled). Setea trial pendiente, completion flag y new-install marker.
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
                GroupInviteOnboardingView(inviteMetadata: pendingInviteMetadata) {
                    hasCompletedOnboarding = true
                    showGroupInviteOnboarding = false
                    pendingInviteMetadata = nil
                }
                .environment(SessionState.shared)
            }
            .sheet(isPresented: $showGroupReconnect, onDismiss: {
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
        let modeConfig = TabBarConfiguration.forMode(sessionState.onboardingMode, stored: tabConfig)
        var tabs = modeConfig.activeTabs
        if let temp = sessionState.temporaryTab, !tabs.contains(temp) {
            tabs.append(temp)
        }
        return tabs
    }

    /// iPhone's tab bar shows at most 5 items; anything beyond collapses into
    /// iOS's native "More" controller (stray back chevron + ugly system list).
    /// configurables + More + Search reaches 6 once a temporary tab pushes the
    /// configurable count to 4, so we drop Search there. Safe to unmount:
    /// selecting `.search` clears `temporaryTab` (see SessionState.selectedMainTab
    /// `didSet`), so the selection binding never targets an absent Search tab.
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
            }
            .sheet(item: Binding(
                get: { activeMilestone.map(MilestoneIdentifier.init) },
                set: { activeMilestone = $0?.value }
            )) { wrapper in
                MilestoneUpgradeSheet(milestone: wrapper.value)
            }
            .routerConsumer(.mainTab) {
                guard let intent = AppRouter.shared.drainNext(for: .mainTab) else { return }
                handleMainTabIntent(intent)
            }
        }
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
            let accounts = (try? modelContext.fetch(FetchDescriptor<Account>())) ?? []
            let budgets = (try? modelContext.fetch(
                FetchDescriptor<Budget>(predicate: #Predicate { $0.isActive })
            )) ?? []
            let activeAccounts = accounts.filter { !$0.isArchived }
            if activeAccounts.count > 2 || budgets.count > 3 {
                downgradeAccounts = accounts
                downgradeBudgets = budgets
                showDowngradeResolution = true
            }
        case .presentTrialExpired:
            showTrialExpired = true
            ProUpsellService.shared.markTrialExpiredSheetShown()
        case .presentMilestoneUpgrade(let milestone):
            activeMilestone = milestone
        case .requestAppStoreReview:
            let action = requestReview
            Task {
                try? await Task.sleep(for: .seconds(1))  // UX delay, not sync
                action()
                ReviewPromptService.recordPromptShown()
                TelemetryService.track(.reviewPromptShown)
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
            GroupsContainerView()
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
