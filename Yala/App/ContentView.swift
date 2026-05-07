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
    @State private var showOnboarding: Bool = false
    @State private var showLanguageSelection: Bool = false
    @State private var showWelcomeChooser: Bool = false
    @State private var showWelcomeRestore: Bool = false
    @State private var showInviteRecovery: Bool = false
    /// Prefilled summary from iCloud restore (rama B). Pasado a OnboardingView
    /// como `prefilledData`. Reseteado tras data wipe para evitar values stale.
    @State private var prefilledOnboardingData: ICloudAccountSummary?
    @State private var showSplash: Bool = true
    @State private var splashOpacity: Double = 1
    /// A4 v3.1: Welcome Hero pre-Chooser (presenta beneficios + corre fetch iCloud invisible).
    @State private var showWelcomeHero: Bool = false
    /// Summary detectado por el Hero. Si tiene data, se muestra alert "Detectamos tu cuenta".
    @State private var detectedICloudSummary: ICloudAccountSummary?
    @State private var showDetectedDataAlert: Bool = false
    /// Positive confirmation toast for reactive events (remote onboarding / restore).
    /// Replaces the noisy "Syncing…" banner. Nil when hidden.
    @State private var positiveToast: String?
    @State private var toastDismissTask: Task<Void, Never>?
    @State private var deduplicationTask: Task<Void, Never>?
    @State private var wipeGraceTask: Task<Void, Never>?
    @State private var remoteWipeTask: Task<Void, Never>?
    @State private var showRemoteWipeAlert: Bool = false
    @State private var showICloudRestartAlert: Bool = false
    @State private var showSyncSettingsSheet: Bool = false
    @State private var showProTrialOffer: Bool = false
    @State private var showWhatsNew: Bool = false
    @State private var whatsNewData: (features: [WhatsNewFeature], version: String)?
    @AppStorage("lastSeenAppVersion") private var lastSeenAppVersion: String = ""
    @State private var isInitialCheckDone: Bool = false
    @State private var showGroupInviteOnboarding: Bool = false
    @State private var showGroupReconnect: Bool = false
    @State private var showFullModeActivation: Bool = false
    /// Inbox alert payload, driven by .contentView drain of .showInboxAlert.
    @State private var activeInboxNotification: PendingInboxNotification = .init()
    /// Group reconnect metadata, carried by .presentGroupReconnect intent.
    @State private var pendingReconnectMetadata: CKShare.Metadata?
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
                    .id(languageVersion) // re-render on .languageDidChange
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
        .fullScreenCover(isPresented: $showLanguageSelection) {
            LanguageSelectionView {
                showLanguageSelection = false
                if !hasCompletedOnboarding {
                    presentNextOnboardingScreen()
                }
            }
            .environment(SessionState.shared)
        }
        // Gate `!showGroupInviteOnboarding`: si un CKShare aterriza mid-chooser,
        // el cover se cierra solo y `hasShownWelcomeChooser` queda en `false` —
        // si el invite onboarding se cancela, el chooser reaparece en el próximo cold launch.
        .fullScreenCover(isPresented: $showWelcomeChooser.gated(by: showGroupInviteOnboarding)) {
            WelcomeChooserView(
                onSelect: { branch in
                    hasShownWelcomeChooser = true
                    showWelcomeChooser = false
                    switch branch {
                    case .new:
                        // A4 v3.2: clean slate para "Soy nuevo". Limpia prefs
                        // residuales del KV-Store del Apple ID (userName, currency)
                        // que sobreviven al uninstall y aparecen pre-llenadas en el
                        // OnboardingView. Solo strings — booleans no se tocan por
                        // riesgo cross-device.
                        OnboardingResetHelper.clearResidualPreferencesForFreshStart()
                        showOnboarding = true
                    case .restore: showWelcomeRestore = true
                    case .invite: showInviteRecovery = true
                    }
                },
                onBack: {
                    // NO setea `hasShownWelcomeChooser` — sigue false hasta tap
                    // consciente en una card del Chooser.
                    showWelcomeChooser = false
                    showWelcomeHero = true
                }
            )
            .environment(SessionState.shared)
        }
        .fullScreenCover(isPresented: $showInviteRecovery) {
            InviteRecoveryView(
                onSuccess: { url in
                    showInviteRecovery = false
                    AppBootstrapper.shared.handleInviteLink(url)
                },
                onBack: {
                    showInviteRecovery = false
                    showWelcomeChooser = true
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
            showWelcomeHero: $showWelcomeHero,
            showWelcomeChooser: $showWelcomeChooser,
            showOnboarding: $showOnboarding,
            showDetectedDataAlert: $showDetectedDataAlert,
            detectedICloudSummary: $detectedICloudSummary,
            prefilledOnboardingData: $prefilledOnboardingData,
            hasShownWelcomeChooser: $hasShownWelcomeChooser,
            hasCompletedOnboarding: $hasCompletedOnboarding,
            showGroupInviteOnboarding: showGroupInviteOnboarding
        ))
        .modifier(GroupInviteModifier(
            showGroupInviteOnboarding: $showGroupInviteOnboarding,
            showGroupReconnect: $showGroupReconnect,
            hasCompletedOnboarding: $hasCompletedOnboarding,
            pendingReconnectMetadata: $pendingReconnectMetadata,
            activeInviteError: $activeInviteError,
            activeGroupSyncError: $activeGroupSyncError
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
                    AppRouter.shared.enqueue(.presentTrialOffer)
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
                    AppRouter.shared.enqueue(.presentInboxSheet)
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
        .onChange(of: authService.isLocked) { _, _ in
            updateContentViewReadiness()
        }
        .onChange(of: SessionState.shared.isWipingData) { _, _ in
            updateContentViewReadiness()
        }
        .onChange(of: AppRouter.shared.revision) { _, _ in
            drainContentViewIntents()
        }
        .onReceive(NotificationCenter.default.publisher(for: .remoteWipeDetected)) { notification in
            // NotificationCenter delivers off the main actor — hop before enqueue.
            let onboardingAlreadyDone = notification.userInfo?[PreferenceSyncService.onboardingAlreadyDoneKey] as? Bool ?? false
            Task { @MainActor in
                AppRouter.shared.enqueue(.remoteWipe(skipOnboarding: onboardingAlreadyDone))
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .remoteOnboardingCompleted)) { _ in
            handleRemoteOnboardingCompleted()
        }
        .onReceive(NotificationCenter.default.publisher(for: .iCloudMismatchDetected)) { _ in
            guard hasCompletedOnboarding else { return }
            AppRouter.shared.enqueue(.iCloudMismatch)
        }
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

    /// Single source of truth for `.contentView` readiness. Called from
    /// `dismissSplash`, `onChange(authService.isLocked)`, and
    /// `onChange(SessionState.shared.isWipingData)`. Idempotent.
    @MainActor
    private func updateContentViewReadiness() {
        let ready = SessionState.shared.isSplashDismissed
                 && !authService.isLocked
                 && !SessionState.shared.isWipingData
        if ready {
            AppRouter.shared.markReady(.contentView)
        } else {
            AppRouter.shared.markUnready(.contentView)
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
        case .presentGroupInviteOnboarding:
            showGroupInviteOnboarding = true
        case .presentGroupReconnect(let invite):
            pendingReconnectMetadata = invite.shareMetadata
            showGroupReconnect = true
        case .showInviteError(let detail):
            activeInviteError = detail
        case .showGroupSyncError(let message):
            activeGroupSyncError = message
        case .iCloudMismatch:
            showICloudRestartAlert = true
        case .remoteWipe(let skipOnboarding):
            handleRemoteWipeSignal(onboardingAlreadyDone: skipOnboarding)
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
    private func checkHasExistingData() -> Bool {
        let accountCount = (try? modelContext.fetchCount(FetchDescriptor<Account>())) ?? 0
        let categoryCount = (try? modelContext.fetchCount(FetchDescriptor<Category>())) ?? 0
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
                    AppRouter.shared.enqueue(.presentTrialOffer)
                }
            } else if let data = whatsNewDataIfPending() {
                AppRouter.shared.enqueue(.presentWhatsNew(features: data.features, version: data.version))
            }
        }
        Task { await AppUpdateService.shared.checkForUpdate() }
        if needsLanguageSelection {
            showLanguageSelection = true
        }
    }

    /// Routing único para presentar la siguiente pantalla del flow inicial.
    /// Usado desde `checkInitialSyncState` + callback de `LanguageSelectionView`.
    /// A4 v3.1: si Chooser no se ha visto, primero va al Hero (que decide entre alert o Chooser).
    private func presentNextOnboardingScreen() {
        if needsLanguageSelection {
            showLanguageSelection = true
        } else if !hasShownWelcomeChooser {
            showWelcomeHero = true
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

// MARK: - Welcome Flow Modifier (A4 v3.1)

/// Encapsula el flow de Welcome: Hero pre-Chooser + alert "Detectamos tu cuenta" + reset
/// del flow cuando llega un CKShare. Extraído a ViewModifier para evitar typecheck timeout
/// en ContentView body — patrón ya usado por `GroupInviteModifier`.
private struct WelcomeFlowModifier: ViewModifier {
    @Binding var showWelcomeHero: Bool
    @Binding var showWelcomeChooser: Bool
    @Binding var showOnboarding: Bool
    @Binding var showDetectedDataAlert: Bool
    @Binding var detectedICloudSummary: ICloudAccountSummary?
    @Binding var prefilledOnboardingData: ICloudAccountSummary?
    @Binding var hasShownWelcomeChooser: Bool
    @Binding var hasCompletedOnboarding: Bool
    let showGroupInviteOnboarding: Bool

    func body(content: Content) -> some View {
        content
            // Welcome Hero pre-Chooser. El user lee cards animadas mientras corre fetch
            // iCloud invisible. Tap "Empezar" → si hay data, alert; si no, Chooser.
            // Gate `!showGroupInviteOnboarding`: si llega CKShare mid-Hero, invite takes over.
            .fullScreenCover(isPresented: $showWelcomeHero.gated(by: showGroupInviteOnboarding)) {
                WelcomeHeroView { decision in
                    showWelcomeHero = false
                    switch decision {
                    case .proceedNoData:
                        showWelcomeChooser = true
                    case .proceedWithData(let summary):
                        detectedICloudSummary = summary
                        showDetectedDataAlert = true
                    }
                }
                .environment(SessionState.shared)
            }
            .alert(
                L10n.Welcome.DetectedData.title,
                isPresented: $showDetectedDataAlert.gated(by: showGroupInviteOnboarding),
                presenting: detectedICloudSummary
            ) { summary in
                Button(L10n.Welcome.DetectedData.loadMyData) {
                    // Alert ES Chooser-equivalent: decisión consciente del user.
                    hasShownWelcomeChooser = true
                    consumeDetectedSummary(summary)
                }
                Button(L10n.Welcome.DetectedData.startFresh) {
                    // User decide explorar las 3 opciones del Chooser. El flag se setea al tap card.
                    showWelcomeChooser = true
                }
            } message: { summary in
                Text(L10n.Welcome.DetectedData.message(
                    summary.accountsCount,
                    summary.transactionsCount,
                    summary.categoriesCount
                ))
            }
            .onChange(of: showGroupInviteOnboarding) { _, newValue in
                // Si llega CKShare, invite onboarding takes over. Reset del flow Hero/alert
                // para evitar resurgir el alert al volver.
                if newValue {
                    showWelcomeHero = false
                    showDetectedDataAlert = false
                    detectedICloudSummary = nil
                }
            }
    }

    /// Replica logic de `WelcomeRestoreView` callbacks SIN re-fetch (alert ya tiene summary).
    private func consumeDetectedSummary(_ summary: ICloudAccountSummary) {
        if summary.isFullyPrefilled {
            // Skip total — mismo side-effect que WelcomeRestoreView.onCompleteSkipAll.
            completeOnboardingAsRestoreSkip()
        } else {
            // Carga prefilled steps — equivalente a WelcomeRestoreView.onContinueWithSummary.
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
    @Binding var showGroupInviteOnboarding: Bool
    @Binding var showGroupReconnect: Bool
    @Binding var hasCompletedOnboarding: Bool
    @Binding var pendingReconnectMetadata: CKShare.Metadata?
    @Binding var activeInviteError: String?
    @Binding var activeGroupSyncError: String?

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
                GroupInviteOnboardingView {
                    hasCompletedOnboarding = true
                    showGroupInviteOnboarding = false
                }
                .environment(SessionState.shared)
            }
            .sheet(isPresented: $showGroupReconnect, onDismiss: {
                pendingReconnectMetadata = nil
            }) {
                GroupReconnectView(
                    onJoin: {
                        let metadata = pendingReconnectMetadata
                        showGroupReconnect = false
                        Task {
                            if let metadata {
                                await SplitSyncManager.shared.acceptShare(metadata: metadata)
                                // Give CKSyncEngine time to fetch group data before navigating (UX).
                                try? await Task.sleep(for: .seconds(2))
                                SessionState.shared.incrementDataVersion()
                            }
                            AppRouter.shared.enqueue(.navigate(.groups))
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
                    MorePlaceholderView()
                }

                // Search tab with .search role - pinned to trailing edge
                Tab(value: .search, role: .search) {
                    GlobalSearchView()
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
            // GC-08: For groupInvite mode, only handle .groups and .groupDetail.
            if sessionState.isGroupInviteMode {
                switch dest {
                case .groups, .groupDetail:
                    break
                default:
                    return
                }
            }
            switch dest {
            case .panel:
                sessionState.selectedMainTab = .panel
            case .statistics:
                sessionState.selectedMainTab = .statistics
            case .records:
                sessionState.selectedDetailTab = .records
                sessionState.selectedMainTab = .statistics
            case .categories:
                sessionState.selectedDetailTab = .categories
                sessionState.selectedMainTab = .statistics
            case .planning:
                sessionState.selectedMainTab = .planning
            case .budgets:
                sessionState.selectedPlanningTab = .budgets
                sessionState.selectedMainTab = .planning
            case .inbox:
                sessionState.selectedMainTab = .panel
                AppRouter.shared.enqueue(.presentInboxSheet)
            case .scheduledPayments:
                sessionState.selectedPlanningTab = .scheduledPayments
                sessionState.selectedMainTab = .planning
            case .recordsStandalone:
                sessionState.temporaryTab = .records
                // UI layout delay — SwiftUI needs a tick between adding
                // the temporary tab and selecting it. Not a sync delay.
                Task {
                    try? await Task.sleep(for: .milliseconds(50))
                    sessionState.selectedMainTab = .records
                }
            case .groups, .groupDetail:
                sessionState.temporaryTab = .groups
                sessionState.enteredViaGroupNotification = true
                if case .groupDetail(let groupID) = dest {
                    sessionState.pendingGroupID = groupID
                }
                Task {
                    try? await Task.sleep(for: .milliseconds(50))
                    sessionState.selectedMainTab = .groups
                }
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

// MARK: - More View

struct MorePlaceholderView: View {
    @Environment(\.yalaTheme) private var theme
    @AppStorage(TabBarConfiguration.storageKey) private var tabConfigJSON: String = TabBarConfiguration.default.toJSON()
    @State private var showProfile = false

    private var tabConfig: TabBarConfiguration {
        TabBarConfiguration.fromJSON(tabConfigJSON)
    }

    /// GC-08: Whether the user is in groupInvite mode
    private var isGroupInviteMode: Bool {
        SessionState.shared.isGroupInviteMode
    }

    /// GC-08: Inactive tabs filtered by mode — groupInvite users don't see full-app tabs
    private var availableInactiveTabs: [ConfigurableTab] {
        if isGroupInviteMode { return [] }
        return tabConfig.inactiveTabs
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()

                ScrollView {
                    VStack(spacing: DS.Spacing.lg) {
                        // GC-08: "Activate Full Yala" button for groupInvite users
                        if isGroupInviteMode {
                            activateFullYalaButton
                        }

                        // Hidden tabs section (not shown for groupInvite)
                        if !availableInactiveTabs.isEmpty {
                            hiddenTabsSection
                        }

                        // Profile button
                        profileButton
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.xxl)
                }
            }
            .navigationTitle(L10n.Tab.more)
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showProfile) {
            ProfileView()
                .transaction { $0.animation = nil }
        }
    }

    // MARK: - Hidden Tabs Section

    private var hiddenTabsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(L10n.More.sections)
                .font(DS.Typography.headline)
                .foregroundStyle(Color.primary.opacity(0.6))
                .padding(.leading, DS.Spacing.xs)

            VStack(spacing: DS.Spacing.none) {
                ForEach(Array(availableInactiveTabs.enumerated()), id: \.element) { index, tab in
                    hiddenTabRow(tab)

                    if index < availableInactiveTabs.count - 1 {
                        Divider()
                            .padding(.leading, DS.FormRow.iconWidth + DS.FormRow.iconSpacing + DS.FormRow.paddingH)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .fill(.thCard)
            )
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .stroke(Color.black.opacity(0.05), lineWidth: 0.8)
            )
            .dsSubtleShadow()
        }
    }

    private func hiddenTabRow(_ tab: ConfigurableTab) -> some View {
        Button {
            // Router handles the temporaryTab → selectedMainTab sequencing.
            // Other tabs (not .records/.groups) don't route through widgets
            // so we keep the direct flow.
            switch tab.appTab {
            case .records:
                AppRouter.shared.enqueue(.navigate(.recordsStandalone))
            case .groups:
                AppRouter.shared.enqueue(.navigate(.groups))
            default:
                SessionState.shared.temporaryTab = tab
                Task {
                    try? await Task.sleep(for: .milliseconds(50))
                    SessionState.shared.selectedMainTab = tab.appTab
                }
            }
        } label: {
            HStack(spacing: DS.FormRow.iconSpacing) {
                Image(systemName: tab.iconName)
                    .font(DS.Typography.label)
                    .foregroundStyle(.white)
                    .frame(width: DS.FormRow.iconWidth, height: DS.FormRow.iconWidth)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(theme.accent)
                    )

                Text(tab.displayName)
                    .font(DS.Typography.body)
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(DS.Typography.chevron)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, DS.FormRow.paddingH)
            .padding(.vertical, DS.FormRow.paddingV)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Activate Full Yala (GC-08)

    private var activateFullYalaButton: some View {
        VStack(spacing: DS.Spacing.none) {
            Button {
                AppRouter.shared.enqueue(.presentFullModeActivation)
            } label: {
                HStack(spacing: DS.FormRow.iconSpacing) {
                    Image(systemName: "sparkles")
                        .font(DS.Typography.label)
                        .foregroundStyle(.white)
                        .frame(width: DS.FormRow.iconWidth, height: DS.FormRow.iconWidth)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(theme.accent)
                        )

                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                        Text(L10n.Groups.Activate.title)
                            .font(DS.Typography.body)
                            .foregroundStyle(.primary)

                        Text(L10n.Groups.Activate.subtitle)
                            .font(DS.Typography.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(DS.Typography.chevron)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, DS.FormRow.paddingH)
                .padding(.vertical, DS.FormRow.paddingV)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .fill(.thCard)
        )
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 0.8)
        )
        .dsSubtleShadow()
    }

    // MARK: - Profile Button

    private var profileButton: some View {
        VStack(spacing: DS.Spacing.none) {
            Button {
                showProfile = true
            } label: {
                HStack(spacing: DS.FormRow.iconSpacing) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(DS.Typography.label)
                        .foregroundStyle(.white)
                        .frame(width: DS.FormRow.iconWidth, height: DS.FormRow.iconWidth)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(DS.Semantic.disabledForeground) // A11Y-DM: gray badge on brand accent bg — visible both modes
                        )

                    Text(L10n.Profile.title)
                        .font(DS.Typography.body)
                        .foregroundStyle(.primary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(DS.Typography.chevron)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, DS.FormRow.paddingH)
                .padding(.vertical, DS.FormRow.paddingV)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("profile_button")
        }
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .fill(.thCard)
        )
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 0.8)
        )
        .dsSubtleShadow()
    }
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
