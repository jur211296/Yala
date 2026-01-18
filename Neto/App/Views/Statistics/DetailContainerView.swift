//
//  DetailContainerView.swift
//  Neto
//
//  Unified container for Trends, Categories, and Records with shared navigation.
//  Located in Statistics as it's the primary drill-down view from the Statistics tab.
//

import SwiftData
import SwiftUI

// MARK: - Detail Container View

/// Unified container view providing chip-based navigation between Trends, Categories, and Records.
/// Uses extracted TrendsTabView and CategoriesTabView components for their respective content.
struct DetailContainerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(SessionState.self) private var sessionState

    // MARK: - Data Queries

    @Query(sort: \TransactionItem.date, order: .reverse)
    private var allTransactions: [TransactionItem]

    @Query(sort: \Account.name) private var accounts: [Account]
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @Query(sort: \Subcategory.name) private var allSubcategories: [Subcategory]
    @Query(sort: \Tag.name) private var tags: [Tag]

    // MARK: - ViewModels

    @State private var recordsViewModel: RecordsViewModel
    @State private var trendsViewModel: StatisticsViewModel

    // MARK: - Navigation State

    @State private var selectedTab: DetailViewTab = .records

    // MARK: - UI State

    @State private var showDeleteConfirmation = false
    @State private var showMultiEditPlaceholder = false
    @State private var isPresentingSettings = false
    @State private var isSyncingState = false  // Anti-loop flag for session sync
    private let isFromSearch: Bool  // Skip session sync when coming from global search

    @AppStorage("defaultCurrencyCode") private var defaultCurrencyCode: String = CurrencyCode.pen
        .rawValue

    // MARK: - Initialization

    init(context: RecordsFilterContext = .empty, initialTab: DetailViewTab = .records) {
        self.isFromSearch = context.isFromSearch
        var cleanContext = context
        // Only reset period and filters when NOT coming from search
        // When from search, respect the passed period (.allTime) and searchText
        if !context.isFromSearch {
            cleanContext.period = .thisMonth
            cleanContext.accountID = nil
            cleanContext.categoryID = nil
            cleanContext.nature = nil
        }
        _recordsViewModel = State(initialValue: RecordsViewModel(context: cleanContext))

        let trendsContext = StatisticsContext(
            initialMetric: .balance,
            period: .thisMonth,
            accountID: nil,
            categoryID: nil,
            subcategoryName: nil,
            nature: nil,
            dateInterval: nil
        )
        _trendsViewModel = State(initialValue: StatisticsViewModel(context: trendsContext))
        _selectedTab = State(initialValue: initialTab)
    }

    // MARK: - Body

    var body: some View {
        mainContent
            .toolbar {
                if recordsViewModel.isSelectionMode {
                    selectionModeToolbar
                } else {
                    normalModeToolbar
                }
            }
            .navigationBarBackButtonHidden(recordsViewModel.isSelectionMode)
            .tint(.primary)
            .modifier(
                DetailContainerSheets(
                    recordsViewModel: recordsViewModel,
                    trendsViewModel: trendsViewModel,
                    showDeleteConfirmation: $showDeleteConfirmation,
                    showMultiEditPlaceholder: $showMultiEditPlaceholder,
                    isPresentingSettings: $isPresentingSettings,
                    modelContext: modelContext,
                    refreshRecordsData: refreshRecordsData,
                    syncFiltersToTrends: syncFiltersToTrends,
                    calculateTrendsData: calculateTrendsData
                )
            )
            .onRecordsFilterChange(viewModel: recordsViewModel) {
                refreshRecordsData()
                syncFiltersToTrends()
                syncToSessionState()
            }
            .onTrendsFilterChange(viewModel: trendsViewModel) {
                calculateTrendsData()
                syncFiltersToRecords()
                syncToSessionState()
            }
            .onAppear {
                if !isFromSearch { syncFromSessionState() }
                refreshRecordsData()
                calculateTrendsData()
            }
            .onChange(of: allTransactions) {
                // Recalculate when transactions change (e.g., initial balance modified)
                calculateTrendsData()
                refreshRecordsData()
            }
            .modifier(
                DetailContainerObservers(
                    sessionState: sessionState,
                    trendsViewModel: trendsViewModel,
                    recordsViewModel: recordsViewModel,
                    syncFromSessionState: syncFromSessionState,
                    handleSessionStateFilterChange: handleSessionStateFilterChange,
                    syncToSessionState: syncToSessionState,
                    calculateTrendsData: calculateTrendsData,
                    refreshRecordsData: refreshRecordsData
                ))
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ZStack {
            PanelBackgroundView()

            tabContent
                .safeAreaInset(edge: .top) {
                    navigationChipsBar
                        .padding(.vertical, DS.Spacing.sm)
                }

            if selectedTab == .records && !recordsViewModel.isSelectionMode {
                newRecordFAB
            }

            if recordsViewModel.isSelectionMode && !recordsViewModel.selectedRecordIDs.isEmpty {
                selectionActionBar
            }
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .trends:
            TrendsTabView(
                trendsViewModel: trendsViewModel,
                defaultCurrencyCode: defaultCurrencyCode,
                onNavigateToRecords: { selectedTab = .records }
            )
        case .categories:
            CategoriesTabView(
                viewModel: trendsViewModel,
                defaultCurrencyCode: defaultCurrencyCode,
                onNavigateToRecords: { selectedTab = .records }
            )
        case .records:
            RecordsTabView(
                viewModel: recordsViewModel,
                accounts: accounts,
                categories: categories,
                tags: tags,
                defaultCurrencyCode: defaultCurrencyCode,
                onFilterChange: { refreshRecordsData() }
            )
        }
    }

    // MARK: - Navigation Chips Bar

    private var navigationChipsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.sm) {
                ForEach(DetailViewTab.allCases) { tab in
                    navigationChipButton(for: tab)
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
        }
    }

    @ViewBuilder
    private func navigationChipButton(for tab: DetailViewTab) -> some View {
        let isSelected = selectedTab == tab

        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = tab
            }
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: tab.icon)
                    .font(.subheadline)
                Text(tab.title)
                    .font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.sm)
            .foregroundStyle(isSelected ? .white : .primary)
            .background(
                Capsule()
                    .fill(isSelected ? Color.electricIndigo : Color.clear)
            )
            .glassEffect(isSelected ? .clear : .regular.interactive(), in: .capsule)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Normal Mode Toolbar

    @ToolbarContentBuilder
    private var normalModeToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            HStack(spacing: DS.Spacing.lg) {
                // Selection button (only for Records)
                if selectedTab == .records {
                    Button {
                        recordsViewModel.enterSelectionMode()
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(Color.electricIndigo)
                    }
                }

                // Filters button
                Button {
                    if selectedTab == .records {
                        recordsViewModel.showFiltersSheet = true
                    } else {
                        trendsViewModel.showFiltersSheet = true
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color.electricIndigo)
                }
                .overlay(alignment: .topTrailing) {
                    if selectedTab == .records && recordsViewModel.activeFilterCount > 0 {
                        Circle()
                            .fill(Color.hotPink)
                            .frame(width: 8, height: 8)
                            .offset(x: 2, y: -2)
                    }
                }

                // Profile button
                Button {
                    isPresentingSettings = true
                } label: {
                    Image(systemName: "person.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color.electricIndigo)
                }
            }
        }
    }

    // MARK: - Selection Mode Toolbar

    @ToolbarContentBuilder
    private var selectionModeToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button(L10n.Common.cancel) {
                recordsViewModel.exitSelectionMode()
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            Button(L10n.Export.selectAll) {
                recordsViewModel.selectAll()
            }
        }
    }

    // MARK: - New Record FAB

    private var newRecordFAB: some View {
        VStack {
            Spacer()

            HStack {
                Spacer()

                Button {
                    recordsViewModel.showNewTransaction = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.electricIndigo)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive())
                .shadow(color: Color.black.opacity(0.20), radius: 20, x: 0, y: 10)
            }
            .padding(.trailing, DS.Spacing.xl)
            .padding(.bottom, DS.Spacing.xxl)
        }
    }

    // MARK: - Selection Action Bar

    private var selectionActionBar: some View {
        VStack {
            Spacer()

            HStack {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    VStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "trash")
                        Text(L10n.Tag.delete)
                            .font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                }

                Text("\(recordsViewModel.selectedRecordIDs.count) \(L10n.Common.selected)")
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)

                Button {
                    handleEditAction()
                } label: {
                    VStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "pencil")
                        Text(L10n.Favorites.edit)
                            .font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, DS.Spacing.md)
            .padding(.horizontal, DS.Spacing.xl)
            .background(.ultraThinMaterial)
        }
    }

    // MARK: - Actions

    private func refreshRecordsData() {
        DispatchQueue.main.async {
            recordsViewModel.applyFilters(
                transactions: allTransactions,
                accounts: accounts,
                categories: categories,
                tags: tags
            )
        }
    }

    private func calculateTrendsData() {
        DispatchQueue.main.async {
            trendsViewModel.calculateTrendData(
                accounts: accounts,
                transactions: allTransactions,
                defaultCurrencyCode: defaultCurrencyCode,
                context: modelContext
            )
        }
    }

    private func handleEditAction() {
        let flatTransactions = recordsViewModel.groupedRecords.flatMap { $0.records }
        let action = recordsViewModel.editSelectedRecords(transactions: flatTransactions)

        switch action {
        case .none:
            break
        case .single(let record):
            recordsViewModel.editingTransaction = record
            recordsViewModel.showEditTransaction = true
            recordsViewModel.exitSelectionMode()
        case .multiple:
            showMultiEditPlaceholder = true
        }
    }

    /// Handles changes to session state filter properties
    private func handleSessionStateFilterChange() {
        guard !isSyncingState else { return }
        isSyncingState = true
        defer { isSyncingState = false }

        syncFromSessionState()
        calculateTrendsData()
        refreshRecordsData()
    }

    // MARK: - Synchronization

    private func syncFiltersToTrends() {
        if trendsViewModel.detailPeriod != recordsViewModel.period {
            trendsViewModel.detailPeriod = recordsViewModel.period
        }
        if trendsViewModel.selectedAccounts != recordsViewModel.selectedAccounts {
            trendsViewModel.selectedAccounts = recordsViewModel.selectedAccounts
        }
        if trendsViewModel.selectedCategories != recordsViewModel.selectedCategories {
            trendsViewModel.selectedCategories = recordsViewModel.selectedCategories
        }
        if trendsViewModel.selectedSubcategories != recordsViewModel.selectedSubcategories {
            trendsViewModel.selectedSubcategories = recordsViewModel.selectedSubcategories
        }
        if trendsViewModel.selectedTags != recordsViewModel.selectedTags {
            trendsViewModel.selectedTags = recordsViewModel.selectedTags
        }
        if trendsViewModel.selectedNatures != recordsViewModel.selectedNatures {
            trendsViewModel.selectedNatures = recordsViewModel.selectedNatures
        }
        if trendsViewModel.selectedCurrencies != recordsViewModel.selectedCurrencies {
            trendsViewModel.selectedCurrencies = recordsViewModel.selectedCurrencies
        }
        if trendsViewModel.amountCondition != recordsViewModel.amountCondition {
            trendsViewModel.amountCondition = recordsViewModel.amountCondition
        }
        if trendsViewModel.searchText != recordsViewModel.searchText {
            trendsViewModel.searchText = recordsViewModel.searchText
        }
    }

    private func syncFiltersToRecords() {
        if recordsViewModel.period != trendsViewModel.detailPeriod {
            recordsViewModel.period = trendsViewModel.detailPeriod
        }
        if recordsViewModel.selectedAccounts != trendsViewModel.selectedAccounts {
            recordsViewModel.selectedAccounts = trendsViewModel.selectedAccounts
        }
        if recordsViewModel.selectedCategories != trendsViewModel.selectedCategories {
            recordsViewModel.selectedCategories = trendsViewModel.selectedCategories
        }
        if recordsViewModel.selectedSubcategories != trendsViewModel.selectedSubcategories {
            recordsViewModel.selectedSubcategories = trendsViewModel.selectedSubcategories
        }
        if recordsViewModel.selectedTags != trendsViewModel.selectedTags {
            recordsViewModel.selectedTags = trendsViewModel.selectedTags
        }
        if recordsViewModel.selectedNatures != trendsViewModel.selectedNatures {
            recordsViewModel.selectedNatures = trendsViewModel.selectedNatures
        }
        if recordsViewModel.selectedCurrencies != trendsViewModel.selectedCurrencies {
            recordsViewModel.selectedCurrencies = trendsViewModel.selectedCurrencies
        }
        if recordsViewModel.amountCondition != trendsViewModel.amountCondition {
            recordsViewModel.amountCondition = trendsViewModel.amountCondition
        }
        if recordsViewModel.searchText != trendsViewModel.searchText {
            recordsViewModel.searchText = trendsViewModel.searchText
        }
    }

    private func syncFromSessionState() {
        guard !isSyncingState else { return }
        isSyncingState = true
        defer { isSyncingState = false }

        trendsViewModel.detailPeriod = sessionState.selectedPeriod
        recordsViewModel.period = sessionState.selectedPeriod

        // Sync custom date range for custom period
        trendsViewModel.customDateRange = sessionState.customDateRange
        recordsViewModel.customDateRange = sessionState.customDateRange

        trendsViewModel.selectedAccounts = sessionState.selectedAccountIDs
        recordsViewModel.selectedAccounts = sessionState.selectedAccountIDs

        trendsViewModel.selectedCategories = sessionState.selectedCategoryIDs
        recordsViewModel.selectedCategories = sessionState.selectedCategoryIDs

        // Convert subcategory names to PersistentIdentifiers
        // Sync subcategory IDs directly (no name-to-ID conversion needed now)
        trendsViewModel.selectedSubcategories = sessionState.selectedSubcategoryIDs
        recordsViewModel.selectedSubcategories = sessionState.selectedSubcategoryIDs

        trendsViewModel.selectedNatures = sessionState.selectedNatures
        recordsViewModel.selectedNatures = sessionState.selectedNatures

        // Sync tags
        trendsViewModel.selectedTags = sessionState.selectedTags
        recordsViewModel.selectedTags = sessionState.selectedTags

        // Sync currencies
        trendsViewModel.selectedCurrencies = sessionState.selectedCurrencies
        recordsViewModel.selectedCurrencies = sessionState.selectedCurrencies

        // Sync amount condition
        trendsViewModel.amountCondition = sessionState.amountCondition
        recordsViewModel.amountCondition = sessionState.amountCondition

        // Sync search text
        trendsViewModel.searchText = sessionState.searchText
        recordsViewModel.searchText = sessionState.searchText

        // Sync trend metric from SessionState
        trendsViewModel.selectedMetric = sessionState.selectedTrendMetric
    }

    private func syncToSessionState() {
        guard !isSyncingState else { return }
        isSyncingState = true
        defer { isSyncingState = false }

        sessionState.selectedPeriod = trendsViewModel.detailPeriod
        sessionState.selectedAccountIDs = trendsViewModel.selectedAccounts
        sessionState.selectedCategoryIDs = trendsViewModel.selectedCategories
        sessionState.selectedNatures = trendsViewModel.selectedNatures

        // Sync subcategory IDs directly (no ID-to-name conversion needed now)
        sessionState.selectedSubcategoryIDs = trendsViewModel.selectedSubcategories

        // Sync tags
        sessionState.selectedTags = trendsViewModel.selectedTags

        // Sync currencies
        sessionState.selectedCurrencies = trendsViewModel.selectedCurrencies

        // Sync amount condition
        sessionState.amountCondition = trendsViewModel.amountCondition

        // Sync search text
        sessionState.searchText = trendsViewModel.searchText

        // Sync trend metric to SessionState
        sessionState.selectedTrendMetric = trendsViewModel.selectedMetric
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        DetailContainerView()
    }
}

// MARK: - View Helpers

extension View {
    fileprivate func onRecordsFilterChange(
        viewModel: RecordsViewModel, action: @escaping () -> Void
    ) -> some View {
        self
            .onChange(of: viewModel.period) { _, _ in action() }
            .onChange(of: viewModel.selectedAccounts) { _, _ in action() }
            .onChange(of: viewModel.selectedCategories) { _, _ in action() }
            .onChange(of: viewModel.selectedSubcategories) { _, _ in action() }
            .onChange(of: viewModel.selectedTags) { _, _ in action() }
            .onChange(of: viewModel.selectedNatures) { _, _ in action() }
            .onChange(of: viewModel.selectedCurrencies) { _, _ in action() }
            .onChange(of: viewModel.amountCondition) { _, _ in action() }
            .onChange(of: viewModel.searchText) { _, _ in action() }
    }

    func onTrendsFilterChange(viewModel: StatisticsViewModel, action: @escaping () -> Void)
        -> some View
    {
        self
            .onChange(of: viewModel.detailPeriod) { _, _ in action() }
            .onChange(of: viewModel.selectedMetric) { _, _ in action() }
            .onChange(of: viewModel.isAggregatedView) { _, _ in action() }
            .onChange(of: viewModel.selectedAccounts) { _, _ in action() }
            .onChange(of: viewModel.selectedCategories) { _, _ in action() }
            .onChange(of: viewModel.selectedSubcategories) { _, _ in action() }
            .onChange(of: viewModel.selectedTags) { _, _ in action() }
            .onChange(of: viewModel.selectedNatures) { _, _ in action() }
            .onChange(of: viewModel.selectedCurrencies) { _, _ in action() }
            .onChange(of: viewModel.amountCondition) { _, _ in action() }
            .onChange(of: viewModel.searchText) { _, _ in action() }
    }
}

// MARK: - ViewModifiers to break up expression complexity

/// Encapsulates sheet presentations to reduce body complexity
private struct DetailContainerSheets: ViewModifier {
    @Bindable var recordsViewModel: RecordsViewModel
    @Bindable var trendsViewModel: StatisticsViewModel
    @Binding var showDeleteConfirmation: Bool
    @Binding var showMultiEditPlaceholder: Bool
    @Binding var isPresentingSettings: Bool
    let modelContext: ModelContext
    let refreshRecordsData: () -> Void
    let syncFiltersToTrends: () -> Void
    let calculateTrendsData: () -> Void

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $recordsViewModel.showFiltersSheet) {
                RecordsFiltersView(viewModel: recordsViewModel)
                    .onDisappear { refreshRecordsData() }
            }
            .sheet(isPresented: $recordsViewModel.showNewTransaction) {
                NewTransactionView()
                    .onDisappear { refreshRecordsData() }
            }
            .sheet(isPresented: $recordsViewModel.showEditTransaction) {
                if let transaction = recordsViewModel.editingTransaction {
                    NewTransactionView(transactionToEdit: transaction)
                        .onDisappear {
                            recordsViewModel.editingTransaction = nil
                            refreshRecordsData()
                        }
                }
            }
            .sheet(isPresented: $trendsViewModel.showFiltersSheet) {
                RecordsFiltersView(viewModel: recordsViewModel)
                    .onDisappear {
                        syncFiltersToTrends()
                        calculateTrendsData()
                    }
            }
            .confirmationDialog(
                L10n.Records.deleteConfirmTitle(recordsViewModel.selectedRecordIDs.count),
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button(L10n.Action.delete, role: .destructive) {
                    recordsViewModel.deleteSelected(context: modelContext)
                    refreshRecordsData()
                }
                Button(L10n.Action.cancel, role: .cancel) {}
            } message: {
                Text(L10n.Common.cannotUndo)
            }
            .alert(L10n.Action.multipleEdit, isPresented: $showMultiEditPlaceholder) {
                Button(L10n.Common.understood, role: .cancel) {}
            } message: {
                Text(L10n.Common.comingSoon)
            }
            .sheet(isPresented: $isPresentingSettings) {
                ProfileView()
            }
    }
}

/// Encapsulates onChange observers to reduce body complexity
private struct DetailContainerObservers: ViewModifier {
    let sessionState: SessionState
    @Bindable var trendsViewModel: StatisticsViewModel
    @Bindable var recordsViewModel: RecordsViewModel
    let syncFromSessionState: () -> Void
    let handleSessionStateFilterChange: () -> Void
    let syncToSessionState: () -> Void
    let calculateTrendsData: () -> Void
    let refreshRecordsData: () -> Void

    func body(content: Content) -> some View {
        content
            .onChange(of: sessionState.selectedPeriod) { syncFromSessionState() }
            .onChange(of: sessionState.selectedAccountIDs) { handleSessionStateFilterChange() }
            .onChange(of: sessionState.selectedCategoryIDs) { handleSessionStateFilterChange() }
            .onChange(of: sessionState.selectedNatures) { handleSessionStateFilterChange() }
            .onChange(of: sessionState.selectedSubcategoryIDs) {
                handleSessionStateFilterChange()
            }
            .onChange(of: sessionState.selectedTags) { handleSessionStateFilterChange() }
            .onChange(of: sessionState.selectedCurrencies) { handleSessionStateFilterChange() }
            .onChange(of: sessionState.amountCondition) { handleSessionStateFilterChange() }
            .onChange(of: sessionState.searchText) { handleSessionStateFilterChange() }
            .onChange(of: sessionState.selectedTrendMetric) {
                syncFromSessionState()
                calculateTrendsData()
            }
            .onChange(of: sessionState.customDateRange) {
                syncFromSessionState()
                calculateTrendsData()
                refreshRecordsData()
            }
            .onChange(of: trendsViewModel.selectedMetric) { _, _ in
                syncToSessionState()
                calculateTrendsData()
            }
            .onChange(of: trendsViewModel.isAggregatedView) { _, _ in calculateTrendsData() }
            .onChange(of: trendsViewModel.detailPeriod) { _, _ in calculateTrendsData() }
            .onChange(of: recordsViewModel.searchText) { refreshRecordsData() }
    }
}
