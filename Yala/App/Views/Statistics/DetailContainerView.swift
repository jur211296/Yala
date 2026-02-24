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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.yalaTheme) private var theme

    // MARK: - ViewModels

    @State private var dataViewModel = DetailContainerViewModel()
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
    @AppStorage("imageInputEnabled") private var imageInputEnabled: Bool = false

    /// Voice recording sheet
    @State private var showVoiceRecording = false

    /// Image selection sheet
    @State private var showImageSelection = false

    /// FAB menu expanded state
    @State private var showFABMenu = false

    /// Upgrade prompt sheets for Pro features
    @State private var showUpgradeForVoice = false
    @State private var showUpgradeForImage = false

    // MARK: - Pro Feature Gates

    private var isVoiceLocked: Bool {
        !FeatureGateService.shared.canAccess(.voiceInput)
    }

    private var isImageLocked: Bool {
        !FeatureGateService.shared.canAccess(.imageInput)
    }

    /// Check if voice input can be used (requires accounts and subcategories)
    private var canUseVoiceInput: Bool {
        dataViewModel.canUseVoiceInput
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

        let initialMetric: TrendMetric = SessionState.shared.isExpensesOnlyMode ? .expense : .balance
        let trendsContext = StatisticsContext(
            initialMetric: initialMetric,
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
                    showImageSelection: $showImageSelection,
                    showUpgradeForVoice: $showUpgradeForVoice,
                    showUpgradeForImage: $showUpgradeForImage,
                    modelContext: modelContext,
                    refreshRecordsData: refreshRecordsData,
                    calculateTrendsData: calculateTrendsData
                )
            )
            .onRecordsFilterChange(viewModel: recordsViewModel) {
                refreshRecordsData()
            }
            .onTrendsFilterChange(viewModel: trendsViewModel) {
                calculateTrendsData()
            }
            .onAppear {
                dataViewModel.setContext(modelContext)
                refreshRecordsData()
                calculateTrendsData()
            }
            .onChange(of: sessionState.selectedMainTab) { _, newTab in
                // Close FAB menu when navigating away from Statistics
                if showFABMenu {
                    showFABMenu = false
                }
                // Sync filters when navigating to Statistics tab (view may already be mounted)
                if newTab == .statistics && !isFromSearch {
                    calculateTrendsData()
                    refreshRecordsData()
                }
            }
            .onChange(of: dataViewModel.allTransactions) {
                // Recalculate when transactions change (e.g., initial balance modified)
                calculateTrendsData()
                refreshRecordsData()
            }
            .onChange(of: sessionState.dataVersion) { _, _ in
                refreshRecordsData()
                calculateTrendsData()
            }
            .modifier(
                DetailContainerObservers(
                    sessionState: sessionState,
                    trendsViewModel: trendsViewModel,
                    recordsViewModel: recordsViewModel,
                    categories: dataViewModel.categories,
                    subcategories: dataViewModel.allSubcategories,
                    handleSessionStateFilterChange: handleSessionStateFilterChange,
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
                accounts: dataViewModel.accounts,
                categories: dataViewModel.categories,
                allSubcategories: dataViewModel.allSubcategories,
                tags: dataViewModel.tags,
                allTransactions: dataViewModel.allTransactions,
                trendsViewModel: trendsViewModel,
                defaultCurrencyCode: defaultCurrencyCode,
                onNavigateToRecords: { selectedTab = .records }
            )
        case .categories:
            CategoriesTabView(
                accounts: dataViewModel.accounts,
                categories: dataViewModel.categories,
                allSubcategories: dataViewModel.allSubcategories,
                tags: dataViewModel.tags,
                allTransactions: dataViewModel.allTransactions,
                viewModel: trendsViewModel,
                defaultCurrencyCode: defaultCurrencyCode,
                onNavigateToRecords: { selectedTab = .records }
            )
        case .records:
            RecordsTabView(
                viewModel: recordsViewModel,
                accounts: dataViewModel.accounts,
                categories: dataViewModel.categories,
                tags: dataViewModel.tags,
                subcategories: dataViewModel.allSubcategories,
                transactionDateRange: dataViewModel.computeTransactionDateRange(),
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
                    .font(DS.Typography.subheadline)
                Text(tab.title)
                    .font(DS.Typography.label)
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.sm)
            .foregroundStyle(isSelected ? .white : .primary)
            .background(
                Capsule()
                    .fill(isSelected ? theme.accent : Color.clear)
            )
            .glassEffect(isSelected ? .clear : .regular.interactive(), in: .capsule)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Normal Mode Toolbar

    @ToolbarContentBuilder
    private var normalModeToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            HStack(spacing: DS.Spacing.md) {
                // Selection button (only for Records)
                if selectedTab == .records {
                    Button {
                        recordsViewModel.enterSelectionMode()
                    } label: {
                        Image(systemName: "checklist")
                            .font(DS.Typography.body).fontWeight(.medium)
                            .foregroundStyle(.thToolbarIcon)
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
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(DS.Typography.body).fontWeight(.medium)
                        .foregroundStyle(.thToolbarIcon)
                }
                .overlay(alignment: .topTrailing) {
                    let showIndicator = (selectedTab == .records && recordsViewModel.activeFilterCount > 0) ||
                                       (selectedTab == .trends && trendsViewModel.activeFilterCount > 0) ||
                                       (selectedTab == .categories && trendsViewModel.activeFilterCount > 0)

                    if showIndicator {
                        Circle()
                            .fill(Color.hotPink)
                            .frame(width: 8, height: 8)
                            .offset(x: 2, y: -2)
                    }
                }
            }
        }

        // iOS 26 spacer creates separate glass groups
        ToolbarSpacer(.fixed, placement: .topBarTrailing)

        ProfileToolbarItem {
            isPresentingSettings = true
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
            let allSelected = recordsViewModel.selectedRecordIDs.count ==
                recordsViewModel.groupedRecords.flatMap(\.records).count
            Button(allSelected ? L10n.Export.deselectAll : L10n.Export.selectAll) {
                if allSelected {
                    recordsViewModel.deselectAll()
                } else {
                    recordsViewModel.selectAll()
                }
            }
        }
    }

    // MARK: - New Record FAB

    @ViewBuilder
    private var newRecordFAB: some View {
        let fabBackground = canUseVoiceInput ? theme.accent : DS.Semantic.disabledForeground.opacity(0.5)
        let hasMultipleInputs = (voiceInputEnabled && imageInputEnabled) ||
                                (voiceInputEnabled && !imageInputEnabled) ||
                                (!voiceInputEnabled && imageInputEnabled)

        if hasMultipleInputs && canUseVoiceInput {
            VStack {
                Spacer()
                HStack {
                    Spacer()
            // Custom FAB with popup menu above
            VStack(alignment: .trailing, spacing: DS.Spacing.md) {
                // Menu options (shown when expanded)
                if showFABMenu {
                    VStack(spacing: DS.Spacing.sm) {
                        // Voice option (if enabled)
                        if voiceInputEnabled {
                            fabMenuButton(
                                icon: "waveform",
                                text: L10n.Panel.fabVoice,
                                color: .hotPink,
                                isLocked: isVoiceLocked
                            ) {
                                dsWithAnimation(reduceMotion) {
                                    showFABMenu = false
                                }
                                if isVoiceLocked {
                                    showUpgradeForVoice = true
                                } else {
                                    showVoiceRecording = true
                                }
                            }
                        }

                        // Image option (if enabled)
                        if imageInputEnabled {
                            fabMenuButton(
                                icon: "photo",
                                text: L10n.Panel.fabImage,
                                color: .teal,
                                isLocked: isImageLocked
                            ) {
                                dsWithAnimation(reduceMotion) {
                                    showFABMenu = false
                                }
                                if isImageLocked {
                                    showUpgradeForImage = true
                                } else {
                                    showImageSelection = true
                                }
                            }
                        }

                        // Manual option (always shown)
                        fabMenuButton(
                            icon: "square.and.pencil",
                            text: L10n.Panel.fabManual,
                            color: .electricIndigo
                        ) {
                            dsWithAnimation(reduceMotion) {
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
                    DS.Haptic.medium()
                    dsWithAnimation(reduceMotion) {
                        showFABMenu.toggle()
                    }
                } label: {
                    Image(systemName: showFABMenu ? "xmark" : "plus")
                        .font(DS.Typography.title)
                        .foregroundStyle(.white)
                        .frame(width: DS.Button.fabSize, height: DS.Button.fabSize)
                        .background(showFABMenu ? DS.Semantic.disabledForeground : fabBackground)
                        .clipShape(Circle())
                        .rotationEffect(.degrees(showFABMenu ? 90 : 0))
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive())
                .shadow(color: Color.black.opacity(0.20), radius: 20, x: 0, y: 10)
            }
            .padding(.trailing, DS.Spacing.xl)
            .padding(.bottom, DS.Spacing.xxl)
                }
            }
        } else {
            VStack {
                Spacer()
                HStack {
                    Spacer()
            // Simple FAB (no special inputs enabled)
            Button {
                if canUseVoiceInput {
                    recordsViewModel.showNewTransaction = true
                }
            } label: {
                Image(systemName: "plus")
                    .font(DS.Typography.title)
                    .foregroundStyle(.white)
                    .frame(width: DS.Button.fabSize, height: DS.Button.fabSize)
                    .background(fabBackground)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive())
            .shadow(color: Color.black.opacity(0.20), radius: 20, x: 0, y: 10)
            .padding(.trailing, DS.Spacing.xl)
            .padding(.bottom, DS.Spacing.xxl)
            .disabled(!canUseVoiceInput)
            .accessibilityHint(!canUseVoiceInput ? L10n.Accessibility.createAccountFirst : "")
                }
            }
        }
    }

    private func fabMenuButton(
        icon: String,
        text: String,
        color: Color,
        isLocked: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            DS.Haptic.selection()
            action()
        } label: {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: icon)
                    .font(DS.Typography.headline)
                    .frame(width: DS.Button.fabMenuIconSize)

                Text(text)
                    .font(DS.Typography.headline)

                if isLocked {
                    ProBadge(size: .small)
                }

                Spacer(minLength: 0)
            }
            .foregroundStyle(.white)
            .frame(width: DS.Button.fabMenuWidth)
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
            .background(isLocked ? DS.Semantic.disabledForeground : color)
            .clipShape(Capsule())
            .shadow(color: (isLocked ? DS.Semantic.disabledForeground : color).opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .phaseAnimator(reduceMotion ? [false] : [false, true]) { content, phase in
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
                        .font(DS.Typography.headline)
                        .foregroundStyle(.red)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(L10n.Action.delete)
                .buttonStyle(.plain)

                Spacer()

                // Selection count
                Text("\(recordsViewModel.selectedRecordIDs.count) \(L10n.Common.selected)")
                    .font(DS.Typography.headline)

                Spacer()

                // Edit button
                Button {
                    handleEditAction()
                } label: {
                    Image(systemName: "pencil")
                        .font(DS.Typography.headline)
                        .foregroundStyle(theme.accent)
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
            // Reload fresh data from SwiftData before applying filters
            // This ensures deleted/modified transactions are reflected immediately
            dataViewModel.loadData()
            recordsViewModel.applyFilters(
                transactions: dataViewModel.allTransactions,
                accounts: dataViewModel.accounts,
                categories: dataViewModel.categories,
                tags: dataViewModel.tags
            )
        }
    }

    private func calculateTrendsData() {
        DispatchQueue.main.async {
            trendsViewModel.calculateTrendData(
                accounts: dataViewModel.accounts,
                transactions: dataViewModel.allTransactions,
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

        calculateTrendsData()
        refreshRecordsData()
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
    @Binding var showImageSelection: Bool
    @Binding var showUpgradeForVoice: Bool
    @Binding var showUpgradeForImage: Bool
    let modelContext: ModelContext
    let refreshRecordsData: () -> Void
    let calculateTrendsData: () -> Void

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $recordsViewModel.showFiltersSheet) {
                RecordsFiltersView(recordsViewModel: recordsViewModel)
                    .onDisappear { refreshRecordsData() }
            }
            .sheet(isPresented: $recordsViewModel.showNewTransaction) {
                NewTransactionView()
                    .onDisappear { refreshRecordsData() }
            }
            .sheet(isPresented: $showVoiceRecording) {
                VoiceRecordingView()
            }
            .sheet(isPresented: $showImageSelection) {
                ImageSelectionView()
            }
            .sheet(isPresented: $showUpgradeForVoice) {
                UpgradePromptSheet(feature: .voiceInput, context: .proFeature)
            }
            .sheet(isPresented: $showUpgradeForImage) {
                UpgradePromptSheet(feature: .imageInput, context: .proFeature)
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
                RecordsFiltersView(recordsViewModel: recordsViewModel)
                    .onDisappear {
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
    let handleSessionStateFilterChange: () -> Void
    let calculateTrendsData: () -> Void
    let refreshRecordsData: () -> Void

    func body(content: Content) -> some View {
        content
            .onChange(of: sessionState.selectedPeriod) { handleSessionStateFilterChange() }
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
                    if !selectedSubs.isEmpty && selectedSubs.allSatisfy({ !$0.safeCategory.isIncome }) {
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
                calculateTrendsData()
            }
            .onChange(of: sessionState.customDateRange) {
                calculateTrendsData()
                refreshRecordsData()
            }
            .onChange(of: trendsViewModel.selectedMetric) { _, _ in
                calculateTrendsData()
            }
            .onChange(of: trendsViewModel.isAggregatedView) { _, _ in calculateTrendsData() }
            .onChange(of: trendsViewModel.detailPeriod) { _, _ in calculateTrendsData() }
            .onChange(of: recordsViewModel.searchText) { refreshRecordsData() }
    }
}
