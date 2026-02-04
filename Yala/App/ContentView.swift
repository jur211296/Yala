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
    @State private var showSplash: Bool = true
    @State private var splashOpacity: Double = 1
    @State private var isWaitingForSync: Bool = false
    @Environment(\.scenePhase) private var scenePhase

    /// Query to detect existing data (for iCloud sync detection)
    @Query private var accounts: [Account]

    private let authService = BiometricAuthService.shared

    /// Minimum splash duration (2.5 seconds to enjoy the animation)
    private let minimumSplashDuration: Double = 2.5

    /// Check if there's existing data (accounts synced from iCloud or local)
    private var hasExistingData: Bool {
        !accounts.isEmpty
    }

    var body: some View {
        ZStack {
            // iCloud sync loading view (when waiting for data)
            if isWaitingForSync {
                cloudSyncLoadingView
            } else {
                // Main content (always rendered underneath)
                MainTabView()
            }

            // Splash screen overlay
            if showSplash {
                SplashScreenView()
                    .opacity(splashOpacity)
                    .ignoresSafeArea()
                    .onAppear {
                        // Dismiss splash after minimum duration
                        DispatchQueue.main.asyncAfter(deadline: .now() + minimumSplashDuration) {
                            dismissSplash()
                        }
                    }
            }
        }
        .task {
            await checkInitialSyncState()
        }
        .onChange(of: accounts.count) { _, newCount in
            // Detect when data arrives from iCloud
            if isWaitingForSync && newCount > 0 {
                isWaitingForSync = false
                hasCompletedOnboarding = true
            }
        }
        .onChange(of: hasCompletedOnboarding) { _, newValue in
            // React to data wipe: show onboarding when flag is reset
            if !newValue && !isWaitingForSync {
                showOnboarding = true
            }
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView {
                showOnboarding = false
            }
        }
        // Biometric lock as fullScreenCover (covers everything including sheets)
        .fullScreenCover(isPresented: Binding(
            get: { authService.isLocked && !showSplash },
            set: { _ in }  // Dismiss handled by BiometricLockOverlay.authenticate()
        )) {
            BiometricLockOverlay()
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
            .background(ClearBackgroundView())
        }
        .onAppear {
            // Lock on initial launch if biometric is enabled
            authService.lockOnLaunchIfNeeded()
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
    }

    private func dismissSplash() {
        withAnimation(.easeOut(duration: 0.4)) {
            splashOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            showSplash = false
        }
    }

    /// Check initial sync state and decide whether to show onboarding or wait for iCloud data
    private func checkInitialSyncState() async {
        // Guard: if already completed onboarding, nothing to do
        guard !hasCompletedOnboarding else { return }

        // Small delay to let @Query hydrate with local data
        try? await Task.sleep(for: .milliseconds(200))

        // If there's already data (from iCloud or local), mark as completed
        if hasExistingData {
            hasCompletedOnboarding = true
            return
        }

        // If no iCloud available, show onboarding directly
        guard SwiftDataConfiguration.isICloudAvailable() else {
            showOnboarding = true
            return
        }

        // iCloud available but no data yet: wait for sync
        isWaitingForSync = true

        // Timeout of 5 seconds
        try? await Task.sleep(for: .seconds(5))

        // If still waiting and no data arrived, show onboarding
        if isWaitingForSync && !hasExistingData {
            isWaitingForSync = false
            showOnboarding = true
        }
    }

    /// Loading view shown while waiting for iCloud sync
    @ViewBuilder
    private var cloudSyncLoadingView: some View {
        VStack(spacing: DS.Spacing.xl) {
            ProgressView()
                .scaleEffect(1.5)

            Text(L10n.iCloud.syncingData)
                .font(.headline)

            Text(L10n.iCloud.syncingDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(DS.Spacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.yalaBackground)
    }
}

// MARK: - TabView Principal con Search Role (iOS 18+)

struct MainTabView: View {
    @Bindable private var sessionState: SessionState
    @State private var searchText: String = ""
    @AppStorage(TabBarConfiguration.storageKey) private var tabConfigJSON: String = TabBarConfiguration.default.toJSON()

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
            .tint(Color.electricIndigo)
            .transaction { $0.animation = nil }
            .onChange(of: sessionState.hasPendingSharedImage) { _, hasPending in
                // Navigate to Panel when shared image is pending (from Share Extension)
                if hasPending && sessionState.selectedMainTab != .panel {
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
                }

                // Clear after handling
                sessionState.deepLinkDestination = nil
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
        }
    }

    private var wipingDataView: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)

                Text(L10n.Settings.deletingData)
                    .font(.headline)
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
}

// MARK: - More View

struct MorePlaceholderView: View {
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
                    VStack(spacing: 16) {
                        // Hidden tabs section
                        if !tabConfig.inactiveTabs.isEmpty {
                            hiddenTabsSection
                        }

                        // Profile button
                        profileButton
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 24)
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
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.More.sections)
                .font(.headline)
                .foregroundStyle(Color.primary.opacity(0.6))
                .padding(.leading, 6)

            VStack(spacing: 0) {
                ForEach(Array(tabConfig.inactiveTabs.enumerated()), id: \.element) { index, tab in
                    hiddenTabRow(tab)

                    if index < tabConfig.inactiveTabs.count - 1 {
                        Divider()
                            .padding(.leading, 52)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.yalaCard)
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.black.opacity(0.05), lineWidth: 0.8)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 6)
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
            HStack(spacing: 12) {
                Image(systemName: tab.iconName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.electricIndigo)
                    )

                Text(tab.displayName)
                    .font(.body)
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Profile Button

    private var profileButton: some View {
        VStack(spacing: 0) {
            Button {
                showProfile = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.gray)
                        )

                    Text(L10n.Profile.title)
                        .font(.body)
                        .foregroundStyle(.primary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.yalaCard)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 0.8)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 6)
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
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text(L10n.Common.loading)
                            .font(.subheadline)
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
    @Environment(SessionState.self) private var sessionState
    @Binding var searchText: String
    let transactions: [TransactionItem]  // Passed from parent

    @State private var selectedFilter: SearchFilter = .all
    @State private var editingTransaction: TransactionItem?

    @AppStorage("defaultCurrencyCode") private var defaultCurrencyCode: String = "PEN"

    // MARK: - Filtered Results

    private var filteredResults: [TransactionItem] {
        // If no search text, show all (limited to 20)
        guard !searchText.isEmpty else {
            return Array(transactions.prefix(20))
        }

        let lowercasedSearch = searchText.lowercased()

        return transactions.filter { transaction in
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
        guard !searchText.isEmpty else { return transactions.count }

        let lowercasedSearch = searchText.lowercased()

        return transactions.filter { transaction in
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

            VStack(spacing: 0) {
                // Filter chips (only show when searching)
                if !searchText.isEmpty {
                    filterChipsBar
                        .padding(.top, 8)
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
            HStack(spacing: 8) {
                ForEach(SearchFilter.allCases) { filter in
                    filterChip(for: filter)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private func filterChip(for filter: SearchFilter) -> some View {
        let isSelected = selectedFilter == filter

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedFilter = filter
            }
        } label: {
            Text(filter.rawValue)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.electricIndigo : Color.clear)
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
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                // Header with count and Ver todo
                if !filteredResults.isEmpty && !searchText.isEmpty {
                    HStack {
                        Text("\(totalMatchingCount) resultados")
                            .font(.caption)
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
                            HStack(spacing: 4) {
                                Text(L10n.Action.viewAll)
                                Image(systemName: "arrow.right")
                            }
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.electricIndigo)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                }

                // Grouped results by date
                ForEach(groupedResults, id: \.date) { group in
                    Section {
                        ForEach(group.records, id: \.persistentModelID) { record in
                            SearchResultRow(record: record, currencyCode: defaultCurrencyCode) {
                                editingTransaction = record
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 4)
                        }
                    } header: {
                        SearchDateSectionHeader(date: group.date)
                    }
                }

                // No results message
                if filteredResults.isEmpty && !searchText.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundStyle(.tertiary)

                        Text(L10n.Search.noResults)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Text(L10n.Search.tryAnotherTerm)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                }
            }
            .padding(.bottom, 20)
        }
        .scrollDismissesKeyboard(.immediately)
    }
}

// MARK: - Search Date Section Header

struct SearchDateSectionHeader: View {
    let date: Date

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = AppLocale.current

        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return L10n.Date.today
        } else if calendar.isDateInYesterday(date) {
            return L10n.Date.yesterday
        } else {
            formatter.dateFormat = "d MMM yyyy"
            return formatter.string(from: date).replacingOccurrences(of: ".", with: "")
        }
    }

    var body: some View {
        HStack {
            Text(formattedDate)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }
}

// MARK: - Search Filter Enum

enum SearchFilter: String, CaseIterable, Identifiable {
    case all = "Todo"
    case note = "Nota"
    case category = "Categoría"
    case subcategory = "Subcategoría"
    case account = "Cuenta"
    case nature = "Naturaleza"
    case tag = "Etiqueta"

    var id: String { rawValue }
}

// MARK: - Search Result Row

struct SearchResultRow: View {
    let record: TransactionItem
    let currencyCode: String
    let onTap: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 12) {
                // Icon
                subcategoryIcon

                // Content
                VStack(alignment: .leading, spacing: 3) {
                    Text(
                        record.note ?? record.subcategory?.name ?? record.category?.name
                            ?? L10n.Common.uncategorized
                    )
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                    let categoryName = record.subcategory?.name ?? record.category?.name ?? ""
                    let accountName = record.account?.name ?? ""

                    if !categoryName.isEmpty || !accountName.isEmpty {
                        Text("\(categoryName) • \(accountName)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Amount
                Text(formattedAmount)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(amountColor)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14))
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
                .font(.callout.weight(.medium))
                .foregroundStyle(.white)
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(Color.yalaCard)
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.06),
                radius: 6,
                x: 0,
                y: 3
            )
    }

    private var formattedAmount: String {
        YalaFormatter.currency(value: record.amount, currencyCode: record.currencyCode)
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
