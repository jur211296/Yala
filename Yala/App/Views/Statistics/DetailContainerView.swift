//
//  DetailContainerView.swift
//  Yala
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
    @State private var showBulkEditSheet = false
    @State private var isPresentingSettings = false
    @State private var isSyncingState = false  // Anti-loop flag for session sync
    private let isFromSearch: Bool  // Skip session sync when coming from global search

    @AppStorage("defaultCurrencyCode") private var defaultCurrencyCode: String = CurrencyCode.pen
        .rawValue
    @AppStorage("voiceInputEnabled") private var voiceInputEnabled: Bool = false

    /// Voice recording sheet
    @State private var showVoiceRecording = false

    /// FAB menu expanded state
    @State private var showFABMenu = false

    /// Check if voice input can be used (requires accounts and subcategories)
    private var canUseVoiceInput: Bool {
        let hasActiveAccounts = accounts.contains { !$0.isArchived }
        let hasVisibleSubcategories = allSubcategories.contains { $0.isVisible }
        return hasActiveAccounts && hasVisibleSubcategories
    }

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
                    showBulkEditSheet: $showBulkEditSheet,
                    isPresentingSettings: $isPresentingSettings,
                    showVoiceRecording: $showVoiceRecording,
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
            .onChange(of: sessionState.selectedMainTab) { _, newTab in
                // Sync filters when navigating to Statistics tab (view may already be mounted)
                if newTab == .statistics && !isFromSearch {
                    syncFromSessionState()
                    calculateTrendsData()
                    refreshRecordsData()
                }
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
                    categories: categories,
                    subcategories: allSubcategories,
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
            // Disable animations to prevent navigation title flickering
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
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
        let fabBackground = canUseVoiceInput ? Color.electricIndigo : Color.gray.opacity(0.5)

        return VStack {
            Spacer()

            HStack {
                Spacer()

                if voiceInputEnabled && canUseVoiceInput {
                    // Custom FAB with popup menu above
                    VStack(alignment: .trailing, spacing: DS.Spacing.md) {
                        // Menu options (shown when expanded)
                        if showFABMenu {
                            VStack(spacing: DS.Spacing.sm) {
                                fabMenuButton(
                                    icon: "waveform",
                                    text: L10n.Panel.fabVoice,
                                    color: .electricIndigo
                                ) {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                        showFABMenu = false
                                    }
                                    showVoiceRecording = true
                                }

                                fabMenuButton(
                                    icon: "square.and.pencil",
                                    text: L10n.Panel.fabManual,
                                    color: .hotPink
                                ) {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                        showFABMenu = false
                                    }
                                    recordsViewModel.showNewTransaction = true
                                }
                            }
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.8, anchor: .bottomTrailing).combined(with: .opacity),
                                removal: .scale(scale: 0.8, anchor: .bottomTrailing).combined(with: .opacity)
                            ))
                        }

                        // FAB button
                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                showFABMenu.toggle()
                            }
                        } label: {
                            Image(systemName: showFABMenu ? "xmark" : "plus")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 56, height: 56)
                                .background(showFABMenu ? Color.gray : fabBackground)
                                .clipShape(Circle())
                                .rotationEffect(.degrees(showFABMenu ? 90 : 0))
                        }
                        .buttonStyle(.plain)
                        .glassEffect(.regular.interactive())
                        .shadow(color: Color.black.opacity(0.20), radius: 20, x: 0, y: 10)
                    }
                } else {
                    Button {
                        if canUseVoiceInput {
                            recordsViewModel.showNewTransaction = true
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 56, height: 56)
                            .background(fabBackground)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive())
                    .shadow(color: Color.black.opacity(0.20), radius: 20, x: 0, y: 10)
                    .disabled(!canUseVoiceInput)
                }
            }
            .padding(.trailing, DS.Spacing.xl)
            .padding(.bottom, DS.Spacing.xxl)
        }
    }

    private func fabMenuButton(icon: String, text: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 24)

                Text(text)
                    .font(.subheadline.weight(.semibold))

                Spacer(minLength: 0)
            }
            .foregroundStyle(.white)
            .frame(width: 140)
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
            .background(color)
            .clipShape(Capsule())
            .shadow(color: color.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .phaseAnimator([false, true]) { content, phase in
            content
                .scaleEffect(phase ? 1.03 : 1.0)
        } animation: { _ in
            .easeInOut(duration: 0.6).repeatForever(autoreverses: true)
        }
    }

    // MARK: - Selection Action Bar

    private var selectionActionBar: some View {
        VStack {
            Spacer()

            HStack(spacing: DS.Spacing.xl) {
                // Delete button
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.red)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)

                Spacer()

                // Selection count
                Text("\(recordsViewModel.selectedRecordIDs.count) \(L10n.Common.selected)")
                    .font(.subheadline.weight(.semibold))

                Spacer()

                // Edit button
                Button {
                    handleEditAction()
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Color.electricIndigo)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, DS.Spacing.sm)
            .padding(.horizontal, DS.Spacing.lg)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.md)
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
            showBulkEditSheet = true
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
        // SSOT Refactor: Both trendsViewModel and recordsViewModel have computed properties
        // that read/write directly from SessionState.shared. They're always in sync.
        // This function is kept as a no-op for backward compatibility.
    }

    private func syncFiltersToRecords() {
        // SSOT Refactor: Both trendsViewModel and recordsViewModel have computed properties
        // that read/write directly from SessionState.shared. They're always in sync.
        // This function is kept as a no-op for backward compatibility.
    }

    private func syncFromSessionState() {
        // SSOT Refactor: All viewModel filter properties are now computed properties
        // that read/write directly from SessionState.shared. No sync needed.
        // This function is kept as a no-op for backward compatibility with existing callers.
    }

    private func syncToSessionState() {
        // SSOT Refactor: All viewModel filter properties are now computed properties
        // that read/write directly from SessionState.shared. No sync needed.
        // This function is kept as a no-op for backward compatibility with existing callers.
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
            .onChange(of: viewModel.selectedTransactionNatures) { _, _ in action() }
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
            .onChange(of: viewModel.selectedTransactionNatures) { _, _ in action() }
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
    @Binding var showBulkEditSheet: Bool
    @Binding var isPresentingSettings: Bool
    @Binding var showVoiceRecording: Bool
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
            .sheet(isPresented: $showVoiceRecording) {
                VoiceRecordingView()
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
            .sheet(isPresented: $showBulkEditSheet) {
                BulkEditSheet(
                    viewModel: recordsViewModel,
                    selectedCount: recordsViewModel.selectedRecordIDs.count,
                    onComplete: refreshRecordsData
                )
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
    let categories: [Category]
    let subcategories: [Subcategory]
    let syncFromSessionState: () -> Void
    let handleSessionStateFilterChange: () -> Void
    let syncToSessionState: () -> Void
    let calculateTrendsData: () -> Void
    let refreshRecordsData: () -> Void

    func body(content: Content) -> some View {
        content
            .onChange(of: sessionState.selectedPeriod) { syncFromSessionState() }
            .onChange(of: sessionState.selectedAccountIDs) { handleSessionStateFilterChange() }
            .onChange(of: sessionState.selectedCategoryIDs) {
                // Auto-select expense filter only if ALL selected categories are expense (not income)
                if !sessionState.selectedCategoryIDs.isEmpty {
                    let selectedCats = categories.filter {
                        sessionState.selectedCategoryIDs.contains($0.persistentModelID)
                    }
                    // Only set expense if we found matching categories AND all are expense categories
                    if !selectedCats.isEmpty && selectedCats.allSatisfy({ !$0.isIncome }) {
                        sessionState.selectedTransactionNatures = [.expense]
                    }
                }
                handleSessionStateFilterChange()
            }
            .onChange(of: sessionState.selectedNatures) {
                // Natures (esencial, prioritaria, etc.) are only for expenses
                if !sessionState.selectedNatures.isEmpty {
                    sessionState.selectedTransactionNatures = [.expense]
                }
                handleSessionStateFilterChange()
            }
            .onChange(of: sessionState.selectedSubcategoryIDs) {
                // Auto-select expense filter only if ALL selected subcategories belong to expense categories
                if !sessionState.selectedSubcategoryIDs.isEmpty {
                    let selectedSubs = subcategories.filter {
                        sessionState.selectedSubcategoryIDs.contains($0.persistentModelID)
                    }
                    // Only set expense if we found matching subcategories AND all are from expense categories
                    if !selectedSubs.isEmpty && selectedSubs.allSatisfy({ !$0.category.isIncome }) {
                        sessionState.selectedTransactionNatures = [.expense]
                    }
                }
                handleSessionStateFilterChange()
            }
            .onChange(of: sessionState.selectedTags) { handleSessionStateFilterChange() }
            .onChange(of: sessionState.selectedCurrencies) { handleSessionStateFilterChange() }
            .onChange(of: sessionState.selectedTransactionNatures) { handleSessionStateFilterChange() }
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
