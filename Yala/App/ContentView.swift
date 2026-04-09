//
//  ContentView.swift
//  Yala
//
//  Created by Yala Refactoring.
//

import StoreKit
import SwiftData
import SwiftUI

// MARK: - ContentView (Punto de entrada principal)

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @State private var showOnboarding: Bool = false
    @State private var showLanguageSelection: Bool = false
    @State private var showSplash: Bool = true
    @State private var splashOpacity: Double = 1
    @State private var showICloudDataFound: Bool = false
    @State private var isWaitingForSync: Bool = false
    @State private var showSyncBanner: Bool = false
    @State private var syncDismissTask: Task<Void, Never>?
    @State private var deduplicationTask: Task<Void, Never>?
    @State private var wipeGraceTask: Task<Void, Never>?
    @State private var remoteWipeTask: Task<Void, Never>?
    @State private var showRemoteWipeAlert: Bool = false
    @State private var showProTrialOffer: Bool = false
    @State private var showWhatsNew: Bool = false
    @State private var whatsNewData: (features: [WhatsNewFeature], version: String)?
    @AppStorage("lastSeenAppVersion") private var lastSeenAppVersion: String = ""
    @State private var isInitialCheckDone: Bool = false
    @State private var showGroupInviteOnboarding: Bool = false
    @State private var showGroupReconnect: Bool = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.yalaTheme) private var theme

    /// Queries to detect existing data (for iCloud sync detection)
    @Query private var accounts: [Account]
    @Query private var categories: [Category]
    @Environment(\.modelContext) private var modelContext

    private let authService = BiometricAuthService.shared

    /// Minimum splash duration (2.5 seconds to enjoy the animation)
    private let minimumSplashDuration: Double = 2.5

    /// Check if there's existing data (accounts or categories synced from iCloud or local)
    private var hasExistingData: Bool {
        !accounts.isEmpty || !categories.isEmpty
    }

    var body: some View {
        ZStack {
            // Main content only when onboarding is done; static background otherwise
            if hasCompletedOnboarding {
                MainTabView()
                    .environment(SessionState.shared)
            } else if isWaitingForSync {
                iCloudSyncWaitingView
            } else {
                theme.background
                    .ignoresSafeArea()
            }

            // Sync banner overlay
            if showSyncBanner {
                HStack(spacing: DS.Spacing.sm) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text(L10n.iCloud.syncingBanner)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.sm)
                .glassEffect()
                .transition(.move(edge: .top).combined(with: .opacity))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, DS.Spacing.xxl)
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
        .onChange(of: accounts.count + categories.count) { _, newTotal in
            // R3: Only show "data found" alert on sync-wait screen, NOT mid-onboarding.
            // If user is mid-onboarding, their explicit choices (currency, period) are better
            // than auto-detected defaults. CategoryDeduplicationService handles seed overlap.
            if isWaitingForSync && newTotal > 0 {
                showICloudDataFound = true
            }
            // Activate sync banner when data arrives (not during wipe)
            if newTotal > 0 && !SessionState.shared.isWipingData {
                withAnimation(.easeInOut) { showSyncBanner = true }
            }
            // Auto-dismiss: if no changes for 5 seconds, hide banner
            scheduleSyncBannerDismiss()
        }
        .onChange(of: hasCompletedOnboarding) { _, newValue in
            // React to data wipe: show onboarding when flag is reset
            if !newValue {
                showOnboarding = true
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
        .alert(L10n.iCloud.dataFoundTitle, isPresented: $showICloudDataFound) {
            Button(L10n.iCloud.dataFoundAction) {
                PreferenceSyncService.shared.applyDetectedDefaultsIfNeeded()
                showOnboarding = false
                hasCompletedOnboarding = true
            }
        } message: {
            Text(L10n.iCloud.dataFoundMessage)
        }
        .fullScreenCover(isPresented: $showLanguageSelection) {
            LanguageSelectionView {
                showLanguageSelection = false
                // Only show onboarding if the user hasn't completed it before
                if !hasCompletedOnboarding {
                    showOnboarding = true
                }
            }
            .environment(SessionState.shared)
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView {
                // Set flag BEFORE dismiss — onChange picks it up reliably
                if !FeatureGateService.shared.isProUser {
                    SessionState.shared.needsPostOnboardingTrial = true
                }
                hasCompletedOnboarding = true
                SetupChecklistManager.shared.markAsNewInstall()
                showOnboarding = false
            }
            .environment(SessionState.shared)
        }
        .modifier(GroupInviteModifier(
            showGroupInviteOnboarding: $showGroupInviteOnboarding,
            showGroupReconnect: $showGroupReconnect,
            hasCompletedOnboarding: $hasCompletedOnboarding
        ))
        .onChange(of: showOnboarding) { oldValue, newValue in
            // Replaces unreliable fullScreenCover onDismiss for post-onboarding flow.
            // onChange(of:) fires synchronously on @State change — always reliable.
            guard oldValue && !newValue && hasCompletedOnboarding else { return }
            if SessionState.shared.needsPostOnboardingTrial && !FeatureGateService.shared.isProUser {
                SessionState.shared.needsPostOnboardingTrial = false
                Task {
                    // Wait for fullScreenCover dismiss animation (~0.35s)
                    try? await Task.sleep(for: .seconds(0.8))
                    await waitForBootstrap()
                    showProTrialOffer = true
                }
            }
        }
        .sheet(isPresented: $showProTrialOffer) {
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
        // Biometric lock as fullScreenCover (covers everything including sheets)
        .fullScreenCover(isPresented: Binding(
            get: { authService.isLocked && !showSplash },
            set: { _ in }  // Dismiss handled by BiometricLockOverlay.authenticate()
        )) {
            BiometricLockOverlay()
                .environment(SessionState.shared)
        }
        // Inbox alert as fullScreenCover (appears over any sheet)
        .fullScreenCover(isPresented: Binding(
            get: { !SessionState.shared.pendingInboxNotification.isEmpty },
            set: { _ in }
        )) {
            InboxAlertModal(
                notification: SessionState.shared.pendingInboxNotification,
                onViewInbox: {
                    SessionState.shared.shouldShowInbox = true
                },
                onDismiss: {
                    SessionState.shared.pendingInboxNotification = .init()
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
        .onChange(of: authService.isLocked) { _, isLocked in
            if !isLocked {
                if let deferred = AppBootstrapper.shared.deferredInboxNotification {
                    AppBootstrapper.shared.deferredInboxNotification = nil
                    Task {
                        try? await Task.sleep(for: .seconds(0.3))
                        SessionState.shared.pendingInboxNotification = deferred
                    }
                    // Panel actions resolve when inbox modal dismisses (onChange below)
                } else {
                    // No inbox to show — resolve panel actions directly
                    AppBootstrapper.shared.showDeferredActionsIfNeeded()
                }
            }
        }
        .onChange(of: SessionState.shared.pendingInboxNotification.isEmpty) { oldEmpty, newEmpty in
            if !oldEmpty && newEmpty {
                // Inbox modal just dismissed — show any deferred panel actions
                AppBootstrapper.shared.showDeferredActionsIfNeeded()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .remoteWipeDetected)) { notification in
            let onboardingAlreadyDone = notification.userInfo?[PreferenceSyncService.onboardingAlreadyDoneKey] as? Bool ?? false
            handleRemoteWipeSignal(onboardingAlreadyDone: onboardingAlreadyDone)
        }
        .onReceive(NotificationCenter.default.publisher(for: .remoteOnboardingCompleted)) { _ in
            handleRemoteOnboardingCompleted()
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

            // Resolve deferred deep link (navigation-only targets like panel, statistics, etc.)
            if let deferred = SessionState.shared.deferredDeepLink {
                SessionState.shared.deferredDeepLink = nil
                try? await Task.sleep(for: .milliseconds(300))
                SessionState.shared.deepLinkDestination = deferred
            }

            // Resolve deferred inbox notification (scheduled payments, subscriptions)
            if let notification = AppBootstrapper.shared.deferredInboxNotification {
                AppBootstrapper.shared.deferredInboxNotification = nil
                try? await Task.sleep(for: .milliseconds(300))
                SessionState.shared.pendingInboxNotification = notification
            } else {
                // No inbox to show — resolve sheet actions (shared image, voice, new transaction)
                AppBootstrapper.shared.showDeferredActionsIfNeeded()
            }
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

    /// Schedule sync banner auto-dismiss after 5 seconds of no data changes
    private func scheduleSyncBannerDismiss() {
        syncDismissTask?.cancel()
        syncDismissTask = Task {
            do {
                try await Task.sleep(for: .seconds(5))
                withAnimation(.easeInOut) { showSyncBanner = false }
            } catch {
                // Task cancelled — a new change arrived, dismiss rescheduled
            }
        }
    }

    // MARK: - Cross-Device Wipe Handling

    private func handleRemoteWipeSignal(onboardingAlreadyDone: Bool) {
        // Don't react to our own wipe
        guard !SessionState.shared.isWipingData else { return }

        // Cancel the hasExistingData-based wipe grace to avoid double-alert
        wipeGraceTask?.cancel()
        wipeGraceTask = nil
        showRemoteWipeAlert = false

        performLocalWipeForRemoteSync(skipOnboarding: onboardingAlreadyDone)
    }

    private func handleRemoteOnboardingCompleted() {
        // Only act if this device is mid-onboarding — otherwise ignore
        guard showOnboarding else { return }
        hasCompletedOnboarding = true
        showOnboarding = false
        withAnimation(.easeInOut) { showSyncBanner = true }
        scheduleSyncBannerDismiss()
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
                withAnimation(.easeInOut) { showSyncBanner = true }
                scheduleSyncBannerDismiss()
            } else {
                hasCompletedOnboarding = false  // onChange triggers onboarding
            }
        }
    }

    /// Whether the device language needs an in-app override
    private var needsLanguageSelection: Bool {
        !LanguageManager.deviceLanguageIsSupported && LanguageManager.overrideLanguage == nil
    }

    /// Prepares What's New data if version changed and features exist.
    /// Returns true if there's something to show.
    private func prepareWhatsNewIfNeeded() -> Bool {
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        guard !currentVersion.isEmpty, currentVersion != lastSeenAppVersion,
              let features = WhatsNewConfig.features(for: currentVersion) else { return false }
        whatsNewData = (features: features, version: currentVersion)
        return true
    }

    /// Check initial state and decide whether to show language selection, onboarding, or go straight to app.
    /// Runs during splash so the wait is invisible to the user.
    private func checkInitialSyncState() async {
        // GC-08: If group invite onboarding is pending, skip normal flow entirely.
        // The CKShare was already accepted eagerly — just let the invite UI take over.
        if SessionState.shared.shouldShowGroupInviteOnboarding {
            isInitialCheckDone = true
            return
        }

        // Wait during splash to give iCloud time to deliver data
        do {
            try await Task.sleep(for: .seconds(2))
        } catch {
            // Task cancelled, continue with state check
        }

        if hasCompletedOnboarding || hasExistingData {
            // Returning user (data from iCloud or previous install)
            // R6 mitigation: hasCompletedOnboarding is per-device (not synced).
            // If iCloud data exists but flag is false (reinstall without backup),
            // auto-promote here. Late arrivals handled by dedup service + onChange.
            if hasExistingData {
                hasCompletedOnboarding = true
            }
            // GC-08: Skip trial/What's New for groupInvite users — they have no context yet
            if !SessionState.shared.isGroupInviteMode {
                if SessionState.shared.needsPostOnboardingTrial && !FeatureGateService.shared.isProUser {
                    // Returning user — check for pending trial (app was killed before trial could show)
                    SessionState.shared.needsPostOnboardingTrial = false
                    Task {
                        await waitForBootstrap()
                        showProTrialOffer = true
                    }
                } else if prepareWhatsNewIfNeeded() {
                    showWhatsNew = true
                }
            }
            // Check for app updates (non-blocking)
            Task { await AppUpdateService.shared.checkForUpdate() }
            // Still check if language selection is needed (new feature, per-device)
            if needsLanguageSelection {
                showLanguageSelection = true
            }
            isInitialCheckDone = true
            return
        }

        // No data yet — if iCloud is available, wait for sync before showing onboarding
        if SwiftDataConfiguration.isICloudAvailable() {
            isWaitingForSync = true

            for _ in 0..<4 { // 4 × 2s = 8s max (was 15 × 2s = 30s; late data handled by dedup + onChange)
                do {
                    try await Task.sleep(for: .seconds(2))
                } catch {
                    break // Task cancelled
                }
                let txCount: Int
                do {
                    txCount = try modelContext.fetchCount(FetchDescriptor<TransactionItem>())
                } catch {
                    #if DEBUG
                    print("ContentView: Error fetching transaction count: \(error)")
                    #endif
                    txCount = 0
                }
                if hasExistingData || txCount > 0 {
                    hasCompletedOnboarding = true
                    isWaitingForSync = false
                    isInitialCheckDone = true
                    scheduleDeduplication()
                    if !SessionState.shared.isWipingData {
                        withAnimation(.easeInOut) { showSyncBanner = true }
                        scheduleSyncBannerDismiss()
                    }
                    return
                }
            }

            // Timeout: proceed to onboarding — schedule dedup for late sync arrival
            isWaitingForSync = false
            scheduleDeduplication()
        }

        if needsLanguageSelection {
            showLanguageSelection = true
        } else {
            showOnboarding = true
        }
        isInitialCheckDone = true
    }

    /// Inline view shown while waiting for iCloud sync on a new device
    private var iCloudSyncWaitingView: some View {
        ZStack {
            theme.background
                .ignoresSafeArea()

            VStack(spacing: DS.Spacing.xl) {
                ProgressView()
                    .scaleEffect(1.5)


                VStack(spacing: DS.Spacing.sm) {
                    Text(L10n.iCloud.syncingData)
                        .font(DS.Typography.headline)
                        .foregroundStyle(.primary)

                    Text(L10n.iCloud.syncingDescription)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Button {
                    isWaitingForSync = false
                    scheduleDeduplication()
                    if needsLanguageSelection {
                        showLanguageSelection = true
                    } else {
                        showOnboarding = true
                    }
                } label: {
                    Text(L10n.iCloud.syncingSkip)
                        .font(DS.Typography.label)
                        .foregroundStyle(.secondary)
                }
                .accessibilityHint(L10n.Accessibility.skipSync)
                .padding(.top, DS.Spacing.lg)
            }
            .padding(.horizontal, DS.Spacing.xxl)
        }
    }
}

// MARK: - Group Invite Modifier (GC-08)

/// Extracted to a ViewModifier to avoid type-checker complexity in ContentView body.
private struct GroupInviteModifier: ViewModifier {
    @Binding var showGroupInviteOnboarding: Bool
    @Binding var showGroupReconnect: Bool
    @Binding var hasCompletedOnboarding: Bool
    @State private var showInviteError: Bool = false

    func body(content: Content) -> some View {
        content
            .alert("Enlace no válido", isPresented: $showInviteError) {
                Button("OK", role: .cancel) {}
            } message: {
                // TODO: Revertir a mensaje genérico antes de release
                Text(SessionState.shared.inviteErrorDetail.isEmpty
                     ? "El enlace de invitación ya no es válido o ha expirado."
                     : SessionState.shared.inviteErrorDetail)
            }
            .onChange(of: SessionState.shared.showInviteError) { _, show in
                if show {
                    showInviteError = true
                    SessionState.shared.showInviteError = false
                }
            }
            .fullScreenCover(isPresented: $showGroupInviteOnboarding) {
                GroupInviteOnboardingView {
                    hasCompletedOnboarding = true
                    showGroupInviteOnboarding = false
                    SessionState.shared.shouldShowGroupInviteOnboarding = false
                }
                .environment(SessionState.shared)
            }
            .sheet(isPresented: $showGroupReconnect, onDismiss: {
                SessionState.shared.clearPendingInviteMetadata()
            }) {
                GroupReconnectView(
                    onJoin: {
                        showGroupReconnect = false
                        Task {
                            if let metadata = SessionState.shared.pendingShareMetadata {
                                await SplitSyncManager.shared.acceptShare(metadata: metadata)
                                // Give CKSyncEngine time to fetch group data before navigating
                                try? await Task.sleep(for: .seconds(2))
                                SessionState.shared.incrementDataVersion()
                            }
                            SessionState.shared.deepLinkDestination = .groups
                        }
                    },
                    onDismiss: {
                        showGroupReconnect = false
                    }
                )
                .environment(SessionState.shared)
            }
            .onChange(of: SessionState.shared.shouldShowGroupInviteOnboarding) { _, shouldShow in
                if shouldShow { showGroupInviteOnboarding = true }
            }
            .onChange(of: SessionState.shared.shouldShowGroupReconnect) { _, shouldShow in
                if shouldShow { showGroupReconnect = true }
            }
    }
}

// MARK: - TabView Principal con Search Role (iOS 18+)

struct MainTabView: View {
    @Bindable private var sessionState: SessionState
    @Environment(\.requestReview) private var requestReview
    @Environment(\.yalaTheme) private var theme
    @State private var searchText: String = ""
    @AppStorage(TabBarConfiguration.storageKey) private var tabConfigJSON: String = TabBarConfiguration.default.toJSON()

    // Queries for downgrade resolution
    @Query private var allAccounts: [Account]
    @Query private var allBudgets: [Budget]
    @State private var showDowngradeResolution = false
    @State private var showTrialExpired = false
    @State private var showMilestoneUpgrade = false

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
            .transaction { $0.animation = nil }
            .onChange(of: sessionState.shouldShowSharedImage) { _, shouldShow in
                // Navigate to Panel when shared image arrives (from Share Extension)
                // GC-08: Skip if panel is not available (groupInvite mode)
                if shouldShow && sessionState.selectedMainTab != .panel && !sessionState.isGroupInviteMode {
                    sessionState.selectedMainTab = .panel
                }
            }
            .onChange(of: sessionState.deepLinkDestination) { _, destination in
                // Handle deep links from widgets
                guard let destination = destination else { return }

                // GC-08: For groupInvite mode, only handle .groups and .groupDetail deep links
                if sessionState.isGroupInviteMode {
                    switch destination {
                    case .groups, .groupDetail:
                        break // Handle below
                    default:
                        sessionState.deepLinkDestination = nil
                        return
                    }
                }

                switch destination {
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
                    sessionState.shouldShowInbox = true
                case .scheduledPayments:
                    sessionState.selectedPlanningTab = .scheduledPayments
                    sessionState.selectedMainTab = .planning
                case .recordsStandalone:
                    sessionState.temporaryTab = .records
                    Task {
                        try? await Task.sleep(for: .milliseconds(50))
                        sessionState.selectedMainTab = .records
                    }
                case .groups, .groupDetail:
                    sessionState.temporaryTab = .groups
                    sessionState.enteredViaGroupNotification = true
                    if case .groupDetail(let groupID) = destination {
                        sessionState.pendingGroupID = groupID
                    }
                    Task {
                        try? await Task.sleep(for: .milliseconds(50))
                        sessionState.selectedMainTab = .groups
                    }
                }

                // Clear after handling
                sessionState.deepLinkDestination = nil
            }
            .onChange(of: sessionState.shouldRequestReview) { _, shouldShow in
                if shouldShow {
                    sessionState.shouldRequestReview = false
                    let action = requestReview
                    Task {
                        try? await Task.sleep(for: .seconds(1))
                        action()
                        ReviewPromptService.recordPromptShown()
                        TelemetryService.track(.reviewPromptShown)
                    }
                }
            }
            .onChange(of: sessionState.shouldShowDowngradeResolution) { _, shouldShow in
                // Show downgrade resolution sheet when triggered by AppBootstrapper
                if shouldShow {
                    // Check if there's actual excess before showing
                    let activeAccounts = allAccounts.filter { !$0.isArchived }
                    let activeBudgets = allBudgets.filter { $0.isActive }

                    if activeAccounts.count > 2 || activeBudgets.count > 3 {
                        showDowngradeResolution = true
                    }
                    sessionState.shouldShowDowngradeResolution = false
                }
            }
            .sheet(isPresented: $showDowngradeResolution) {
                DowngradeResolutionSheet(
                    accounts: allAccounts,
                    budgets: allBudgets
                ) {
                    showDowngradeResolution = false
                }
            }
            .onChange(of: sessionState.shouldShowTrialExpired) { _, shouldShow in
                if shouldShow {
                    showTrialExpired = true
                    sessionState.shouldShowTrialExpired = false
                    ProUpsellService.shared.markTrialExpiredSheetShown()
                }
            }
            .sheet(isPresented: $showTrialExpired) {
                UpgradePromptSheet(feature: .voiceInput, context: .trialExpired, source: "trialExpired")
            }
            .onChange(of: sessionState.pendingMilestoneUpgrade) { _, milestone in
                if milestone != nil {
                    showMilestoneUpgrade = true
                }
            }
            .sheet(isPresented: $showMilestoneUpgrade, onDismiss: {
                sessionState.pendingMilestoneUpgrade = nil
            }) {
                if let milestone = sessionState.pendingMilestoneUpgrade {
                    MilestoneUpgradeSheet(milestone: milestone)
                }
            }
        }
    }

    @ViewBuilder
    private func viewForTab(_ tab: ConfigurableTab) -> some View {
        switch tab {
        case .panel:
            PanelView()
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
    @State private var showFullModeActivation = false

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
        .sheet(isPresented: $showFullModeActivation) {
            FullModeActivationView {
                showFullModeActivation = false
            }
            .environment(SessionState.shared)
        }
        .onChange(of: SessionState.shared.shouldOpenProfile) { _, shouldOpen in
            if shouldOpen {
                showProfile = true
                SessionState.shared.shouldOpenProfile = false
            }
        }
        .onChange(of: SessionState.shared.shouldOpenFullModeActivation) { _, shouldOpen in
            if shouldOpen {
                showFullModeActivation = true
                SessionState.shared.shouldOpenFullModeActivation = false
            }
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
            // Set temporary tab first, then navigate after SwiftUI adds the tab
            SessionState.shared.temporaryTab = tab
            // Small delay to let TabView add the new tab before selecting it
            Task {
                try? await Task.sleep(for: .milliseconds(50))
                SessionState.shared.selectedMainTab = tab.appTab
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
                showFullModeActivation = true
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
