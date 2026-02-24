//
//  ContentView.swift
//  Yala
//
//  Created by Yala Refactoring.
//

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
    @State private var showRemoteWipeAlert: Bool = false
    @State private var showProTrialOffer: Bool = false
    @State private var isInitialCheckDone: Bool = false
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
        .fullScreenCover(isPresented: $showOnboarding, onDismiss: {
            // Show trial offer after onboarding completes (only for eligible non-Pro users)
            if hasCompletedOnboarding && !FeatureGateService.shared.isProUser {
                Task {
                    let eligible = await StoreKitManager.shared.isEligibleForIntroOffer()
                    if eligible {
                        showProTrialOffer = true
                    }
                }
            }
        }) {
            OnboardingView {
                showOnboarding = false
            }
            .environment(SessionState.shared)
        }
        .sheet(isPresented: $showProTrialOffer) {
            ProTrialOfferSheet {
                showProTrialOffer = false
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
            default:
                break
            }
        }
        .onChange(of: authService.isLocked) { _, isLocked in
            if !isLocked, let deferred = AppBootstrapper.shared.deferredInboxNotification {
                AppBootstrapper.shared.deferredInboxNotification = nil
                Task {
                    try? await Task.sleep(for: .seconds(0.3))
                    SessionState.shared.pendingInboxNotification = deferred
                }
            }
        }
    }

    private func dismissSplash() {
        withAnimation(.easeOut(duration: 0.4)) {
            splashOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            showSplash = false
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

    /// Whether the device language needs an in-app override
    private var needsLanguageSelection: Bool {
        !LanguageManager.deviceLanguageIsSupported && LanguageManager.overrideLanguage == nil
    }

    /// Check initial state and decide whether to show language selection, onboarding, or go straight to app.
    /// Runs during splash so the wait is invisible to the user.
    private func checkInitialSyncState() async {
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

            for _ in 0..<15 { // 15 × 2s = 30s max (CloudKit cold sync can take 30-60s)
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

// MARK: - TabView Principal con Search Role (iOS 18+)

struct MainTabView: View {
    @Bindable private var sessionState: SessionState
    @Environment(\.yalaTheme) private var theme
    @State private var searchText: String = ""
    @AppStorage(TabBarConfiguration.storageKey) private var tabConfigJSON: String = TabBarConfiguration.default.toJSON()

    // Queries for downgrade resolution
    @Query private var allAccounts: [Account]
    @Query private var allBudgets: [Budget]
    @State private var showDowngradeResolution = false

    private var tabConfig: TabBarConfiguration {
        TabBarConfiguration.fromJSON(tabConfigJSON)
    }

    /// Tabs to show: active tabs + temporary tab (if set and not already active)
    private var visibleTabs: [ConfigurableTab] {
        var tabs = tabConfig.activeTabs
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
                if shouldShow && sessionState.selectedMainTab != .panel {
                    sessionState.selectedMainTab = .panel
                }
            }
            .onChange(of: sessionState.deepLinkDestination) { _, destination in
                // Handle deep links from widgets
                guard let destination = destination else { return }

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
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        sessionState.selectedMainTab = .records
                    }
                }

                // Clear after handling
                sessionState.deepLinkDestination = nil
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
}

// MARK: - More View

struct MorePlaceholderView: View {
    @Environment(\.yalaTheme) private var theme
    @AppStorage(TabBarConfiguration.storageKey) private var tabConfigJSON: String = TabBarConfiguration.default.toJSON()
    @State private var showProfile = false

    private var tabConfig: TabBarConfiguration {
        TabBarConfiguration.fromJSON(tabConfigJSON)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()

                ScrollView {
                    VStack(spacing: DS.Spacing.lg) {
                        // Hidden tabs section
                        if !tabConfig.inactiveTabs.isEmpty {
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
                ForEach(Array(tabConfig.inactiveTabs.enumerated()), id: \.element) { index, tab in
                    hiddenTabRow(tab)

                    if index < tabConfig.inactiveTabs.count - 1 {
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
            .shadow(color: Color.black.opacity(0.04), radius: DS.Radius.md, x: 0, y: 6)
        }
    }

    private func hiddenTabRow(_ tab: ConfigurableTab) -> some View {
        Button {
            // Set temporary tab first, then navigate after SwiftUI adds the tab
            SessionState.shared.temporaryTab = tab
            // Small delay to let TabView add the new tab before selecting it
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
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
                                .fill(Color.gray)
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
        .shadow(color: Color.black.opacity(0.04), radius: DS.Radius.md, x: 0, y: 6)
    }
}

// MARK: - Global Search View

struct GlobalSearchView: View {
    @State private var searchText: String = ""
    @State private var isSearchActive: Bool = false
    @State private var isDataReady: Bool = false

    // Load data here to avoid glitch during search activation
    @Query(sort: \TransactionItem.date, order: .reverse) private var allTransactions:
        [TransactionItem]

    var body: some View {
        NavigationStack {
            ZStack {
                // Background for both states
                PanelBackgroundView()

                if isDataReady {
                    SearchContentView(searchText: $searchText, transactions: allTransactions)
                } else {
                    // Loading state - subtle animation
                    VStack(spacing: DS.Spacing.lg) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text(L10n.Common.loading)
                            .font(DS.Typography.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(L10n.Common.search)
            .navigationBarTitleDisplayMode(.large)
        }
        .searchable(
            text: $searchText,
            isPresented: $isSearchActive,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: L10n.Common.search
        )
        .task {
            // Delay to let Query load, then reveal content smoothly
            do {
                try await Task.sleep(for: .milliseconds(300))
            } catch {
                // Task cancelled - continue with animation anyway
            }
            await MainActor.run {
                withAnimation(.easeIn(duration: 0.2)) {
                    isDataReady = true
                }
                isSearchActive = true
            }
        }
    }
}

// MARK: - Search Content View

struct SearchContentView: View {
    @Environment(\.yalaTheme) private var theme
    @Environment(SessionState.self) private var sessionState
    @Binding var searchText: String
    let transactions: [TransactionItem]  // Passed from parent

    @State private var selectedFilter: SearchFilter = .all
    @State private var editingTransaction: TransactionItem?

    @AppStorage("defaultCurrencyCode") private var defaultCurrencyCode: String = "PEN"

    // MARK: - Filtered Results

    private var filteredResults: [TransactionItem] {
        // Pre-filter: exclude income transactions in expenses-only mode
        let baseTransactions: [TransactionItem]
        if sessionState.isExpensesOnlyMode {
            baseTransactions = transactions.filter { $0.category?.isIncome != true }
        } else {
            baseTransactions = transactions
        }

        // If no search text, show all (limited to 20)
        guard !searchText.isEmpty else {
            return Array(baseTransactions.prefix(20))
        }

        let lowercasedSearch = searchText.lowercased()

        return baseTransactions.filter { transaction in
            switch selectedFilter {
            case .all:
                // Search in all fields
                let noteMatch = transaction.note?.lowercased().contains(lowercasedSearch) ?? false
                let categoryMatch =
                    transaction.category?.name.lowercased().contains(lowercasedSearch) ?? false
                let subcategoryMatch =
                    transaction.subcategory?.name.lowercased().contains(lowercasedSearch) ?? false
                let accountMatch =
                    transaction.account?.name.lowercased().contains(lowercasedSearch) ?? false
                let tagMatch = (transaction.tags ?? []).contains {
                    $0.name.lowercased().contains(lowercasedSearch)
                }
                return noteMatch || categoryMatch || subcategoryMatch || accountMatch || tagMatch
            case .note:
                return transaction.note?.lowercased().contains(lowercasedSearch) ?? false
            case .category:
                return transaction.category?.name.lowercased().contains(lowercasedSearch) ?? false
            case .subcategory:
                return transaction.subcategory?.name.lowercased().contains(lowercasedSearch)
                    ?? false
            case .account:
                return transaction.account?.name.lowercased().contains(lowercasedSearch) ?? false
            case .nature:
                return transaction.subcategory?.nature.displayName.lowercased()
                    .contains(lowercasedSearch) ?? false
            case .tag:
                return (transaction.tags ?? []).contains { $0.name.lowercased().contains(lowercasedSearch) }
            }
        }
        .prefix(20)
        .map { $0 }
    }

    // Total count for "Ver todo" (without limit)
    private var totalMatchingCount: Int {
        // Pre-filter: exclude income transactions in expenses-only mode
        let baseTransactions: [TransactionItem]
        if sessionState.isExpensesOnlyMode {
            baseTransactions = transactions.filter { $0.category?.isIncome != true }
        } else {
            baseTransactions = transactions
        }

        guard !searchText.isEmpty else { return baseTransactions.count }

        let lowercasedSearch = searchText.lowercased()

        return baseTransactions.filter { transaction in
            switch selectedFilter {
            case .all:
                let noteMatch = transaction.note?.lowercased().contains(lowercasedSearch) ?? false
                let categoryMatch =
                    transaction.category?.name.lowercased().contains(lowercasedSearch) ?? false
                let subcategoryMatch =
                    transaction.subcategory?.name.lowercased().contains(lowercasedSearch) ?? false
                let accountMatch =
                    transaction.account?.name.lowercased().contains(lowercasedSearch) ?? false
                let tagMatch = (transaction.tags ?? []).contains {
                    $0.name.lowercased().contains(lowercasedSearch)
                }
                return noteMatch || categoryMatch || subcategoryMatch || accountMatch || tagMatch
            case .note:
                return transaction.note?.lowercased().contains(lowercasedSearch) ?? false
            case .category:
                return transaction.category?.name.lowercased().contains(lowercasedSearch) ?? false
            case .subcategory:
                return transaction.subcategory?.name.lowercased().contains(lowercasedSearch)
                    ?? false
            case .account:
                return transaction.account?.name.lowercased().contains(lowercasedSearch) ?? false
            case .nature:
                return transaction.subcategory?.nature.displayName.lowercased().contains(
                    lowercasedSearch) ?? false
            case .tag:
                return (transaction.tags ?? []).contains { $0.name.lowercased().contains(lowercasedSearch) }
            }
        }.count
    }

    // MARK: - Grouped Results by Date

    private var groupedResults: [(date: Date, records: [TransactionItem])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredResults) { record in
            calendar.startOfDay(for: record.date)
        }
        return grouped.sorted { $0.key > $1.key }
            .map { (date: $0.key, records: $0.value) }
    }

    var body: some View {
        ZStack {
            PanelBackgroundView()

            VStack(spacing: DS.Spacing.none) {
                // Filter chips (only show when searching)
                if !searchText.isEmpty {
                    filterChipsBar
                        .padding(.top, DS.Spacing.sm)
                }

                // Always show results (all or filtered)
                searchResultsView
            }
        }
        .sheet(item: $editingTransaction) { transaction in
            NewTransactionView(transactionToEdit: transaction)
        }
    }

    // MARK: - Filter Chips Bar

    private var filterChipsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.sm) {
                ForEach(SearchFilter.allCases) { filter in
                    filterChip(for: filter)
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.sm)
        }
    }

    private func filterChip(for filter: SearchFilter) -> some View {
        let isSelected = selectedFilter == filter

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedFilter = filter
            }
        } label: {
            Text(filter.displayName)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)
                .background(
                    Capsule()
                        .fill(isSelected ? theme.accent : Color.clear)
                )
                .overlay(
                    Capsule()
                        .stroke(Color.secondary.opacity(0.3), lineWidth: isSelected ? 0 : 1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Search Results

    private var searchResultsView: some View {
        ScrollView {
            LazyVStack(spacing: DS.Spacing.none, pinnedViews: [.sectionHeaders]) {
                // Header with count and Ver todo
                if !filteredResults.isEmpty && !searchText.isEmpty {
                    HStack {
                        Text(L10n.Search.resultsCount(totalMatchingCount))
                            .font(DS.Typography.caption)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Button {
                            // Navigate to Statistics > Records with search filter applied
                            sessionState.searchText = searchText
                            sessionState.selectedPeriod = .allTime
                            sessionState.navigateToDetail(.records)
                            // Clear local state - SessionState is now the source of truth
                            searchText = ""
                        } label: {
                            HStack(spacing: DS.Spacing.xs) {
                                Text(L10n.Action.viewAll)
                                Image(systemName: "arrow.right")
                            }
                            .font(DS.Typography.label)
                            .foregroundStyle(theme.accent)
                        }
                    }
                    .padding(.horizontal, DS.Spacing.xl)
                    .padding(.top, DS.Spacing.sm)
                    .padding(.bottom, DS.Spacing.md)
                }

                // Grouped results by date
                ForEach(groupedResults, id: \.date) { group in
                    Section {
                        ForEach(group.records, id: \.persistentModelID) { record in
                            SearchResultRow(record: record, currencyCode: defaultCurrencyCode) {
                                editingTransaction = record
                            }
                            .padding(.horizontal, DS.Spacing.lg)
                            .padding(.vertical, DS.Spacing.xs)
                        }
                    } header: {
                        SearchDateSectionHeader(date: group.date)
                    }
                }

                // No results message
                if filteredResults.isEmpty && !searchText.isEmpty {
                    YalaEmptyState.noResults()
                        .padding(.top, DS.Spacing.xxxl)
                }
            }
            .padding(.bottom, DS.Spacing.xl)
        }
        .scrollDismissesKeyboard(.immediately)
    }
}

// MARK: - Search Date Section Header

struct SearchDateSectionHeader: View {
    let date: Date

    private static let sectionDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = AppLocale.current
        f.dateFormat = "d MMM yyyy"
        return f
    }()

    private var formattedDate: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return L10n.Date.today
        } else if calendar.isDateInYesterday(date) {
            return L10n.Date.yesterday
        } else {
            return Self.sectionDateFormatter.string(from: date).replacingOccurrences(of: ".", with: "")
        }
    }

    var body: some View {
        HStack {
            Text(formattedDate)
                .font(DS.Typography.labelSmall)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Spacer()
        }
        .padding(.horizontal, DS.Spacing.xl)
        .padding(.vertical, DS.Spacing.sm)
    }
}

// MARK: - Search Filter Enum

enum SearchFilter: String, CaseIterable, Identifiable {
    case all
    case note
    case category
    case subcategory
    case account
    case nature
    case tag

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all: return L10n.Search.Filter.all
        case .note: return L10n.Search.Filter.note
        case .category: return L10n.Search.Filter.category
        case .subcategory: return L10n.Search.Filter.subcategory
        case .account: return L10n.Search.Filter.account
        case .nature: return L10n.Search.Filter.nature
        case .tag: return L10n.Search.Filter.tag
        }
    }
}

// MARK: - Search Result Row

struct SearchResultRow: View {
    let record: TransactionItem
    let currencyCode: String
    let onTap: () -> Void

    @Environment(\.yalaTheme) private var theme

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: DS.Spacing.md) {
                // Icon
                subcategoryIcon

                // Content
                VStack(alignment: .leading, spacing: 3) { // DS: intentional non-token value
                    Text(
                        record.note ?? record.subcategory?.name ?? record.category?.name
                            ?? L10n.Common.uncategorized
                    )
                    .font(DS.Typography.label)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                    let categoryName = record.subcategory?.name ?? record.category?.name ?? ""
                    let accountName = record.account?.name ?? ""

                    if !categoryName.isEmpty || !accountName.isEmpty {
                        Text("\(categoryName) • \(accountName)")
                            .font(DS.Typography.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Amount
                Text(formattedAmount)
                    .font(DS.Typography.headline)
                    .foregroundStyle(amountColor)
            }
            .padding(.vertical, DS.Spacing.md)
            .padding(.horizontal, DS.Spacing.md)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card))
        }
        .buttonStyle(.plain)
    }

    private var subcategoryIcon: some View {
        let colorHex = record.category?.colorHex ?? "#6366F1"
        let iconName = record.subcategory?.iconName ?? record.category?.iconName ?? "tag.fill"

        return ZStack {
            Circle()
                .fill(Color(hex: colorHex))
                .frame(width: 40, height: 40)

            Image(systemName: iconName)
                .font(DS.Typography.label)
                .foregroundStyle(.white)
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: DS.Radius.card)
            .fill(.thCard)
            .shadow(
                color: Color.black.opacity(theme.shadowOpacity),
                radius: 6,
                x: 0,
                y: 3
            )
    }

    private var formattedAmount: String {
        YalaFormatter.currency(value: record.amount, currencyCode: record.currencyCode, forceFullPrecision: true)
    }

    private var amountColor: Color {
        let isIncome = record.category?.isIncome ?? (record.amount >= 0)
        return isIncome ? Color.electricIndigo : Color.hotPink
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
