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
    @State private var insightsViewModel = InsightsViewModel()

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
    @AppStorage("aiDataConsentAccepted") private var aiDataConsentAccepted: Bool = false
    @AppStorage(InsightTone.storageKey) private var toneSetting: String = InsightTone.normal.rawValue
    @AppStorage(InsightFocus.storageKey) private var focusSetting: String = InsightFocus.balanced.rawValue
    @State private var showAIConsentAlert = false
    @State private var pendingAIInput: PendingAIInput = .voice

    /// Voice recording sheet
    @State private var showVoiceRecording = false

    /// Image selection sheet
    @State private var showImageSelection = false

    /// Upgrade prompt sheets for Pro features
    @State private var showUpgradeForVoice = false
    @State private var showUpgradeForImage = false

    /// Chat Assistant
    @State private var showChatSheet = false
    @State private var showUpgradeForChat = false
    @State private var showChatConsentAlert = false
    @AppStorage("aiChatConsentAccepted") private var aiChatConsentAccepted: Bool = false
    @AppStorage("chatAssistantEnabled") private var chatAssistantEnabled: Bool = false
    @AppStorage("chatFABVisible") private var chatFABVisible: Bool = true

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

    init(context: RecordsFilterContext = .empty, initialTab: DetailViewTab = .insights) {
        self.isFromSearch = context.isFromSearch
        var cleanContext = context
        // Only reset period and filters when NOT coming from search
        // When from search, respect the passed period (.allTime) and searchText
        if !context.isFromSearch {
            cleanContext.period = .thisMonth
            cleanContext.accountID = nil
            cleanContext.categoryID = nil
            cleanContext.need = nil
        }
        _recordsViewModel = State(initialValue: RecordsViewModel(context: cleanContext))

        let initialMetric: TrendMetric = SessionState.shared.isExpensesOnlyMode ? .expense : .balance
        let trendsContext = StatisticsContext(
            initialMetric: initialMetric,
            period: .thisMonth,
            accountID: nil,
            categoryID: nil,
            subcategoryName: nil,
            need: nil,
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
                    showChatSheet: $showChatSheet,
                    showUpgradeForChat: $showUpgradeForChat,
                    showChatConsentAlert: $showChatConsentAlert,
                    aiChatConsentAccepted: $aiChatConsentAccepted,
                    chatAssistantEnabled: $chatAssistantEnabled,
                    modelContext: modelContext,
                    refreshRecordsData: refreshRecordsData,
                    calculateTrendsData: calculateTrendsData,
                    calculateInsightsData: calculateInsightsData
                )
            )
            .onRecordsFilterChange(viewModel: recordsViewModel) {
                refreshRecordsData()
            }
            .onTrendsFilterChange(viewModel: trendsViewModel) {
                calculateTrendsData()
                calculateInsightsData()
            }
            .appliesPendingRemoteChanges(sessionState)
            .onAppear {
                dataViewModel.setContext(modelContext)
                refreshRecordsData()
                calculateTrendsData()
                calculateInsightsData()
            }
            .onChange(of: selectedTab) { _, _ in
                calculateInsightsData()
            }
            .onChange(of: sessionState.selectedMainTab) { _, newTab in
                // Sync filters when navigating to Statistics tab (view may already be mounted)
                if newTab == .statistics && !isFromSearch {
                    calculateTrendsData()
                    refreshRecordsData()
                    calculateInsightsData()
                }
            }
            .onChange(of: dataViewModel.allTransactions) {
                // Recalculate when transactions change (e.g., initial balance modified)
                calculateTrendsData()
                refreshRecordsData()
                if selectedTab == .insights { calculateInsightsData() }
            }
            .onChange(of: sessionState.dataVersion) { _, _ in
                refreshRecordsData()
                calculateTrendsData()
                if selectedTab == .insights { calculateInsightsData() }
            }
            .onChange(of: sessionState.comparisonMode) {
                if selectedTab == .insights { calculateInsightsData() }
            }
            .onChange(of: toneSetting) { calculateInsightsData() }
            .onChange(of: focusSetting) { calculateInsightsData() }
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
            .aiConsentAlert(isPresented: $showAIConsentAlert, pendingInput: $pendingAIInput) { input in
                switch input {
                case .voice: showVoiceRecording = true
                case .image: showImageSelection = true
                }
            }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ZStack {
            PanelBackgroundView()

            VStack(spacing: DS.Spacing.none) {
                // Contextual guide for current statistics tab
                statisticsGuide
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.top, DS.Spacing.xs)

                tabContent
            }
            .safeAreaInset(edge: .top) {
                navigationChipsBar
                    .padding(.vertical, DS.Spacing.sm)
            }

            if selectedTab == .records && !recordsViewModel.isSelectionMode {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        FABStackView(
                            canUseVoiceInput: canUseVoiceInput,
                            isVoiceLocked: isVoiceLocked,
                            isImageLocked: isImageLocked,
                            isChatLocked: !FeatureGateService.shared.canAccess(.chatAssistant),
                            chatConsentAccepted: aiChatConsentAccepted,
                            chatEnabled: chatAssistantEnabled,
                            chatFABVisible: chatFABVisible,
                            onVoiceTap: { showVoiceRecording = true },
                            onImageTap: { showImageSelection = true },
                            onManualTap: { recordsViewModel.showNewTransaction = true },
                            onUpgradeVoice: { showUpgradeForVoice = true },
                            onUpgradeImage: { showUpgradeForImage = true },
                            onChatTap: { showChatSheet = true },
                            onUpgradeChat: { showUpgradeForChat = true },
                            onChatConsentNeeded: { showChatConsentAlert = true }
                        )
                    }
                }
            }

            if recordsViewModel.isSelectionMode && !recordsViewModel.selectedRecordIDs.isEmpty {
                selectionActionBar
            }
        }
    }

    @ViewBuilder
    private var statisticsGuide: some View {
        switch selectedTab {
        case .insights:
            ContextualGuideBanner.insights()
        case .trends:
            ContextualGuideBanner.trends()
        case .categories:
            ContextualGuideBanner.categories()
        case .records:
            ContextualGuideBanner.records()
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .insights:
            InsightsTabView(
                accounts: dataViewModel.accounts,
                categories: dataViewModel.categories,
                allSubcategories: dataViewModel.allSubcategories,
                tags: dataViewModel.tags,
                allTransactions: dataViewModel.allTransactions,
                budgets: dataViewModel.budgets,
                scheduledPayments: dataViewModel.scheduledPayments,
                defaultCurrencyCode: defaultCurrencyCode,
                viewModel: insightsViewModel,
                trendsViewModel: trendsViewModel
            )
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
                    .accessibilityHidden(true)
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
                    .accessibilityLabel(L10n.Action.select)
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
                .accessibilityLabel(L10n.Accessibility.filters)
                .overlay(alignment: .topTrailing) {
                    let showIndicator = (selectedTab == .records && recordsViewModel.activeFilterCount > 0) ||
                                       (selectedTab == .trends && trendsViewModel.activeFilterCount > 0) ||
                                       (selectedTab == .categories && trendsViewModel.activeFilterCount > 0) ||
                                       (selectedTab == .insights && trendsViewModel.activeFilterCount > 0)

                    if showIndicator {
                        Circle()
                            .fill(Color.hotPink)
                            .frame(width: 8, height: 8)
                            .offset(x: 2, y: -2)
                            .accessibilityHidden(true)
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
                        .foregroundStyle(DS.Semantic.errorForeground)
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
                .accessibilityLabel(L10n.Action.edit)
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
        Task { @MainActor in
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
        Task { @MainActor in
            trendsViewModel.calculateTrendData(
                accounts: dataViewModel.accounts,
                transactions: dataViewModel.allTransactions,
                defaultCurrencyCode: defaultCurrencyCode
            )
        }
    }

    private func calculateInsightsData() {
        guard selectedTab == .insights else { return }
        insightsViewModel.calculateInsightsData(
            transactions: dataViewModel.allTransactions,
            accounts: dataViewModel.accounts,
            categories: dataViewModel.categories,
            budgets: dataViewModel.budgets,
            scheduledPayments: dataViewModel.scheduledPayments,
            period: sessionState.selectedPeriod,
            criteria: trendsViewModel.filterCriteria,
            currencyCode: defaultCurrencyCode,
            customRange: sessionState.customDateRange,
            comparisonMode: sessionState.comparisonMode
        )

        // Reset AI state on context change (button must be pressed again)
        insightsViewModel.resetAIState()

        // Store context for on-demand AI generation via button
        let criteria = trendsViewModel.filterCriteria
        insightsViewModel.storeGenerationContext(
            period: sessionState.selectedPeriod,
            filterHash: criteria.hashValue,
            txnCount: dataViewModel.allTransactions.count,
            currencyCode: defaultCurrencyCode,
            comparisonMode: sessionState.comparisonMode,
            criteria: criteria,
            accounts: dataViewModel.accounts,
            categories: dataViewModel.categories,
            tags: dataViewModel.tags
        )
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
        calculateInsightsData()
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
            .onChange(of: viewModel.selectedNeeds) { _, _ in action() }
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
            .onChange(of: viewModel.selectedNeeds) { _, _ in action() }
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
    @Binding var showChatSheet: Bool
    @Binding var showUpgradeForChat: Bool
    @Binding var showChatConsentAlert: Bool
    @Binding var aiChatConsentAccepted: Bool
    @Binding var chatAssistantEnabled: Bool
    let modelContext: ModelContext
    let refreshRecordsData: () -> Void
    let calculateTrendsData: () -> Void
    let calculateInsightsData: () -> Void

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $recordsViewModel.showFiltersSheet) {
                RecordsFiltersView(recordsViewModel: recordsViewModel)
                    .onDisappear { refreshRecordsData() }
            }
            .sheet(isPresented: $recordsViewModel.showNewTransaction) {
                NewTransactionView()
                    .presentationDetents([.large])
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
            .sheet(isPresented: $showChatSheet) {
                ChatSheetView()
            }
            .sheet(isPresented: $showUpgradeForChat) {
                UpgradePromptSheet(feature: .chatAssistant, context: .proFeature)
            }
            .alert(L10n.AIConsent.chatTitle, isPresented: $showChatConsentAlert) {
                Button(L10n.AIConsent.accept) {
                    aiChatConsentAccepted = true
                    chatAssistantEnabled = true
                    showChatSheet = true
                }
                Button(L10n.AIConsent.privacyPolicy) {
                    UIApplication.shared.open(AppConstants.privacyURL)
                }
                Button(L10n.Action.cancel, role: .cancel) {}
            } message: {
                Text(L10n.AIConsent.chatMessage)
            }
            .sheet(isPresented: $recordsViewModel.showEditTransaction) {
                if let transaction = recordsViewModel.editingTransaction {
                    NewTransactionView(transactionToEdit: transaction)
                        .presentationDetents([.large])
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
                        calculateInsightsData()
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
            .modifier(SessionStateObservers(
                sessionState: sessionState,
                categories: categories,
                subcategories: subcategories,
                handleSessionStateFilterChange: handleSessionStateFilterChange,
                calculateTrendsData: calculateTrendsData,
                refreshRecordsData: refreshRecordsData
            ))
            .modifier(ViewModelObservers(
                trendsViewModel: trendsViewModel,
                recordsViewModel: recordsViewModel,
                calculateTrendsData: calculateTrendsData,
                refreshRecordsData: refreshRecordsData
            ))
    }
}

/// SessionState onChange observers — split to reduce type-checker complexity.
private struct SessionStateObservers: ViewModifier {
    let sessionState: SessionState
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
                if !sessionState.isExcludeMode && !sessionState.selectedCategoryIDs.isEmpty {
                    let selectedCats = categories.filter {
                        sessionState.selectedCategoryIDs.contains($0.persistentModelID)
                    }
                    if !selectedCats.isEmpty && selectedCats.allSatisfy({ !$0.isIncome }) {
                        sessionState.selectedTransactionNatures = [.expense]
                    }
                }
                handleSessionStateFilterChange()
            }
            .onChange(of: sessionState.selectedNeeds) {
                if !sessionState.isExcludeMode && !sessionState.selectedNeeds.isEmpty {
                    sessionState.selectedTransactionNatures = [.expense]
                }
                handleSessionStateFilterChange()
            }
            .onChange(of: sessionState.selectedSubcategoryIDs) {
                if !sessionState.isExcludeMode && !sessionState.selectedSubcategoryIDs.isEmpty {
                    let selectedSubs = subcategories.filter {
                        sessionState.selectedSubcategoryIDs.contains($0.persistentModelID)
                    }
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
            .onChange(of: sessionState.isExcludeMode) { handleSessionStateFilterChange() }
            .onChange(of: sessionState.selectedTrendMetric) {
                calculateTrendsData()
            }
            .onChange(of: sessionState.customDateRange) {
                calculateTrendsData()
                refreshRecordsData()
            }
    }
}

/// ViewModel onChange observers — split to reduce type-checker complexity.
private struct ViewModelObservers: ViewModifier {
    @Bindable var trendsViewModel: StatisticsViewModel
    @Bindable var recordsViewModel: RecordsViewModel
    let calculateTrendsData: () -> Void
    let refreshRecordsData: () -> Void

    func body(content: Content) -> some View {
        content
            .onChange(of: trendsViewModel.selectedMetric) { _, _ in
                calculateTrendsData()
            }
            .onChange(of: trendsViewModel.isAggregatedView) { _, _ in calculateTrendsData() }
            .onChange(of: trendsViewModel.detailPeriod) { _, _ in calculateTrendsData() }
            .onChange(of: recordsViewModel.searchText) { refreshRecordsData() }
    }
}
