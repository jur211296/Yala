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
    @Environment(\.scenePhase) private var scenePhase

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
    @State private var recalculateTask: Task<Void, Never>?
    @State private var pendingReload = false
    @State private var isInBackground = false
    /// Gate para `calculateFinancialScore`: el score depende solo de
    /// dataVersion + mes en curso, no de filtros/periodo. Evita los 2 fetches
    /// de SwiftData (`loadPaidAmounts`) en cada cambio de chip.
    @State private var lastScoreSignature: Int = 0
    private let isFromSearch: Bool  // Skip session sync when coming from global search

    @Environment(AppPreferences.self) private var appPreferences

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
    @State private var showYalaAIOnboarding = false
    @State private var pendingOpenChatAfterOnboarding = false

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
                    showYalaAIOnboarding: $showYalaAIOnboarding,
                    pendingOpenChatAfterOnboarding: $pendingOpenChatAfterOnboarding,
                    modelContext: modelContext,
                    recalculateData: recalculateData,
                    reloadAndRecalculate: reloadAndRecalculate
                )
            )
            .appliesPendingRemoteChanges(sessionState)
            .onAppear {
                dataViewModel.setContext(modelContext)
                performRecalculation()
            }
            .onDisappear { recalculateTask?.cancel() }
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .background, .inactive:
                    isInBackground = true
                    recalculateTask?.cancel()
                case .active:
                    guard UIApplication.shared.applicationState == .active else { return }
                    isInBackground = false
                    reloadAndRecalculate()
                @unknown default:
                    break
                }
            }
            .task {
                if selectedTab != sessionState.selectedDetailTab {
                    selectedTab = sessionState.selectedDetailTab
                }
            }
            .onChange(of: sessionState.selectedDetailTab) { _, newValue in
                if selectedTab != newValue { selectedTab = newValue }
            }
            .onChange(of: selectedTab) { _, newTab in
                if sessionState.selectedDetailTab != newTab {
                    sessionState.selectedDetailTab = newTab
                }
                // .categories también consume insightData.periodSummary (gate >=5 tx
                // del Distribution Insight Card) — disparar recalculation también ahí.
                if newTab == .insights || newTab == .categories {
                    scheduleRecalculation(reload: false)
                }
            }
            .onChange(of: sessionState.selectedMainTab) { _, newTab in
                // Sync filters when navigating to Statistics tab (view may already be mounted)
                if newTab == .statistics && !isFromSearch {
                    recalculateData()
                }
            }
            .onChange(of: dataViewModel.allTransactions) {
                recalculateData()
            }
            .onChange(of: sessionState.dataVersion) { _, _ in
                reloadAndRecalculate()
            }
            .onChange(of: sessionState.comparisonMode) { recalculateData() }
            .onChange(of: appPreferences.insightsTone) { recalculateData() }
            .onChange(of: appPreferences.insightsFocus) { recalculateData() }
            .modifier(
                DetailContainerObservers(
                    sessionState: sessionState,
                    trendsViewModel: trendsViewModel,
                    categories: dataViewModel.categories,
                    subcategories: dataViewModel.allSubcategories,
                    recalculateData: recalculateData
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
                            chatConsentAccepted: appPreferences.aiChatConsentAccepted,
                            chatFABVisible: appPreferences.chatFABVisible,
                            onVoiceTap: { showVoiceRecording = true },
                            onImageTap: { showImageSelection = true },
                            onManualTap: { recordsViewModel.showNewTransaction = true },
                            onUpgradeVoice: { showUpgradeForVoice = true },
                            onUpgradeImage: { showUpgradeForImage = true },
                            onChatTap: {
                                switch YalaAIOnboardingLogic.nextScreen(
                                    consentAccepted: appPreferences.aiChatConsentAccepted,
                                    onboardingShown: appPreferences.hasShownYalaAIOnboarding
                                ) {
                                case .onboarding: showYalaAIOnboarding = true
                                case .chat:       showChatSheet = true
                                case .consent:    showChatConsentAlert = true
                                }
                            },
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
        .yalaScreenBackground()
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
                defaultCurrencyCode: appPreferences.defaultCurrencyCode.rawValue,
                viewModel: insightsViewModel,
                trendsViewModel: trendsViewModel
            )
            .accessibilityIdentifier("stats_tab_insights")
        case .trends:
            TrendsTabView(
                accounts: dataViewModel.accounts,
                categories: dataViewModel.categories,
                allSubcategories: dataViewModel.allSubcategories,
                tags: dataViewModel.tags,
                allTransactions: dataViewModel.allTransactions,
                trendsViewModel: trendsViewModel,
                insightsViewModel: insightsViewModel,
                defaultCurrencyCode: appPreferences.defaultCurrencyCode.rawValue
            )
            .accessibilityIdentifier("stats_tab_trends")
        case .categories:
            CategoriesTabView(
                accounts: dataViewModel.accounts,
                categories: dataViewModel.categories,
                allSubcategories: dataViewModel.allSubcategories,
                tags: dataViewModel.tags,
                allTransactions: dataViewModel.allTransactions,
                viewModel: trendsViewModel,
                insightsViewModel: insightsViewModel,
                defaultCurrencyCode: appPreferences.defaultCurrencyCode.rawValue
            )
            .accessibilityIdentifier("stats_tab_categories")
        case .records:
            RecordsTabView(
                viewModel: recordsViewModel,
                accounts: dataViewModel.accounts,
                categories: dataViewModel.categories,
                tags: dataViewModel.tags,
                subcategories: dataViewModel.allSubcategories,
                transactionDateRange: dataViewModel.computeTransactionDateRange(),
                defaultCurrencyCode: appPreferences.defaultCurrencyCode.rawValue,
                onFilterChange: { recalculateData() }
            )
            .accessibilityIdentifier("stats_tab_records")
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
        .accessibilityIdentifier("detail_chip_\(tab.rawValue.lowercased())")
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
                    .accessibilityIdentifier("records_select_button")
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
                .accessibilityIdentifier("filters_toolbar_button")
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
                .accessibilityIdentifier("bulk_edit_button")
            }
            .padding(.vertical, DS.Spacing.sm)
            .padding(.horizontal, DS.Spacing.lg)
            .solidCard(radius: DS.Radius.lg)
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.md)
        }
    }

    // MARK: - Actions

    /// Filter changes — recalculate from cache, NO DB fetch
    private func recalculateData() {
        scheduleRecalculation(reload: false)
    }

    /// Data mutations (dataVersion, sheet dismiss) — reload DB + recalculate
    private func reloadAndRecalculate() {
        scheduleRecalculation(reload: true)
    }

    /// Debounced recalculation (150ms). `pendingReload` ensures a reload request isn't lost
    /// if a subsequent calculate-only call arrives within the debounce window.
    /// Background guard: skip scheduling while scenePhase is background/inactive — pendingReload
    /// is preserved so the next foreground reloadAndRecalculate picks it up. The
    /// `applicationState` check mirrors PanelView and prevents work during snapshot time.
    private func scheduleRecalculation(reload: Bool) {
        if reload { pendingReload = true }
        guard !isInBackground, UIApplication.shared.applicationState == .active else { return }
        recalculateTask?.cancel()
        recalculateTask = Task { @MainActor in
            do { try await Task.sleep(for: .milliseconds(150)) } catch { return }
            guard !Task.isCancelled else { return }
            if pendingReload {
                dataViewModel.loadData()
                pendingReload = false
            }
            performCalculation()
        }
    }

    /// Initial onAppear calculation. `setContext` already fetched if the context was new,
    /// so this only runs the synchronous calc pass. Subsequent reloads go through
    /// `reloadAndRecalculate` (dataVersion / scene foreground).
    private func performRecalculation() {
        performCalculation()
    }

    /// Runs all calculations from cached ViewModel data (no SwiftData fetch).
    private func performCalculation() {
        recordsViewModel.applyFilters(
            transactions: dataViewModel.allTransactions,
            accounts: dataViewModel.accounts,
            categories: dataViewModel.categories,
            tags: dataViewModel.tags
        )
        trendsViewModel.calculateTrendData(
            accounts: dataViewModel.accounts,
            transactions: dataViewModel.allTransactions,
            allTags: dataViewModel.tags,
            defaultCurrencyCode: appPreferences.defaultCurrencyCode.rawValue
        )
        // Distribution Insight Card también requiere insightData.periodSummary
        // para el gate >=5 tx — calcular cuando estamos en cualquiera de las 2 tabs.
        if selectedTab == .insights || selectedTab == .categories {
            calculateInsightsData()
        }
    }

    private func calculateInsightsData() {
        guard selectedTab == .insights || selectedTab == .categories else { return }
        insightsViewModel.calculateInsightsData(
            transactions: dataViewModel.allTransactions,
            accounts: dataViewModel.accounts,
            categories: dataViewModel.categories,
            budgets: dataViewModel.budgets,
            scheduledPayments: dataViewModel.scheduledPayments,
            period: sessionState.selectedPeriod,
            criteria: trendsViewModel.filterCriteria(withTagCatalog: dataViewModel.tags),
            currencyCode: appPreferences.defaultCurrencyCode.rawValue,
            customRange: sessionState.customDateRange,
            comparisonMode: sessionState.comparisonMode
        )

        // Salud Financiera period-aware. El score depende de dataVersion +
        // período seleccionado (interval). Cambios de filtros (cuenta/categoría/
        // etiqueta) NO afectan al score — solo el dataset y el interval lo hacen.
        // El gate evita re-fetches SwiftData de `loadPaidAmounts` en cada cambio
        // de chip de filtro.
        let scoreInterval = trendsViewModel.detailPeriod.dateInterval(
            customRange: trendsViewModel.customDateRange
        )
        var scoreHasher = Hasher()
        scoreHasher.combine(sessionState.dataVersion)
        scoreHasher.combine(scoreInterval.start)
        scoreHasher.combine(scoreInterval.end)
        let scoreSignature = scoreHasher.finalize()
        if scoreSignature != lastScoreSignature {
            lastScoreSignature = scoreSignature
            let activePayments = dataViewModel.scheduledPayments.filter(\.isActive)
            let paidAmounts = ScheduledPaymentPaidStatusHelper.loadPaidAmounts(
                for: activePayments,
                interval: scoreInterval,
                context: modelContext
            )
            insightsViewModel.calculateFinancialScore(
                transactions: dataViewModel.allTransactions,
                budgets: dataViewModel.budgets,
                scheduledPayments: dataViewModel.scheduledPayments,
                accounts: dataViewModel.accounts,
                paidAmounts: paidAmounts,
                period: trendsViewModel.detailPeriod,
                customRange: trendsViewModel.customDateRange,
                preferredCurrencyCode: appPreferences.defaultCurrencyCode.rawValue
            )
        }

        // Reset AI state on context change (button must be pressed again)
        insightsViewModel.resetAIState()

        // Store context for on-demand AI generation via button
        let criteria = trendsViewModel.filterCriteria(withTagCatalog: dataViewModel.tags)
        insightsViewModel.storeGenerationContext(
            period: sessionState.selectedPeriod,
            filterHash: criteria.hashValue,
            txnCount: dataViewModel.allTransactions.count,
            currencyCode: appPreferences.defaultCurrencyCode.rawValue,
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
}

// MARK: - Preview

#Preview {
    NavigationStack {
        DetailContainerView()
    }
    .previewAppPreferences()
}

// MARK: - View Helpers

// MARK: - ViewModifiers to break up expression complexity

/// Encapsulates sheet presentations to reduce body complexity
private struct DetailContainerSheets: ViewModifier {
    @Environment(AppPreferences.self) private var appPreferences
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
    @Binding var showYalaAIOnboarding: Bool
    @Binding var pendingOpenChatAfterOnboarding: Bool
    let modelContext: ModelContext
    let recalculateData: () -> Void
    let reloadAndRecalculate: () -> Void

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $recordsViewModel.showFiltersSheet) {
                RecordsFiltersView(recordsViewModel: recordsViewModel)
                    .onDisappear { recalculateData() }
            }
            .sheet(isPresented: $recordsViewModel.showNewTransaction) {
                NewTransactionView()
                    .presentationDetents([.large])
                    .onDisappear { reloadAndRecalculate() }
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
            .yalaAIOnboardingSheet(
                isPresented: $showYalaAIOnboarding,
                pendingOpenChat: $pendingOpenChatAfterOnboarding,
                showChatSheet: $showChatSheet,
                launcher: .stats,
                onPersistFlag: { appPreferences.hasShownYalaAIOnboarding = true }
            )
            .sheet(isPresented: $showUpgradeForChat) {
                UpgradePromptSheet(feature: .chatAssistant, context: .proFeature)
            }
            .chatConsentAlert(isPresented: $showChatConsentAlert) {
                switch YalaAIOnboardingLogic.nextScreen(
                    consentAccepted: true,
                    onboardingShown: appPreferences.hasShownYalaAIOnboarding
                ) {
                case .onboarding: showYalaAIOnboarding = true
                case .chat:       showChatSheet = true
                case .consent:    break
                }
            }
            .sheet(isPresented: $recordsViewModel.showEditTransaction) {
                if let transaction = recordsViewModel.editingTransaction {
                    NewTransactionView(transactionToEdit: transaction)
                        .presentationDetents([.large])
                        .onDisappear {
                            recordsViewModel.editingTransaction = nil
                            reloadAndRecalculate()
                        }
                }
            }
            .sheet(isPresented: $trendsViewModel.showFiltersSheet) {
                RecordsFiltersView(recordsViewModel: recordsViewModel)
                    .onDisappear { recalculateData() }
            }
            .confirmationDialog(
                L10n.Records.deleteConfirmTitle(recordsViewModel.selectedRecordIDs.count),
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button(L10n.Action.delete, role: .destructive) {
                    recordsViewModel.deleteSelected(context: modelContext)
                    reloadAndRecalculate()
                }
                Button(L10n.Action.cancel, role: .cancel) {}
            } message: {
                Text(L10n.Common.cannotUndo)
            }
            .sheet(isPresented: $showBulkEditSheet) {
                BulkEditSheet(
                    viewModel: recordsViewModel,
                    selectedCount: recordsViewModel.selectedRecordIDs.count,
                    onComplete: reloadAndRecalculate
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
    let categories: [Category]
    let subcategories: [Subcategory]
    let recalculateData: () -> Void

    func body(content: Content) -> some View {
        content
            .modifier(SessionStateObservers(
                sessionState: sessionState,
                categories: categories,
                subcategories: subcategories,
                recalculateData: recalculateData
            ))
            // isAggregatedView is local to StatisticsViewModel (not a SessionState proxy)
            .onChange(of: trendsViewModel.isAggregatedView) { _, _ in recalculateData() }
    }
}

/// SessionState onChange observers — split to reduce type-checker complexity.
private struct SessionStateObservers: ViewModifier {
    let sessionState: SessionState
    let categories: [Category]
    let subcategories: [Subcategory]
    let recalculateData: () -> Void

    func body(content: Content) -> some View {
        content
            .onChange(of: sessionState.selectedPeriod) { recalculateData() }
            .onChange(of: sessionState.selectedAccountIDs) { recalculateData() }
            .onChange(of: sessionState.selectedCategoryIDs) {
                if !sessionState.isExcludeMode && !sessionState.selectedCategoryIDs.isEmpty {
                    let selectedCats = categories.filter {
                        sessionState.selectedCategoryIDs.contains($0.persistentModelID)
                    }
                    if !selectedCats.isEmpty && selectedCats.allSatisfy({ !$0.isIncome }) {
                        sessionState.selectedTransactionNatures = [.expense]
                    }
                }
                recalculateData()
            }
            .onChange(of: sessionState.selectedNeeds) {
                if !sessionState.isExcludeMode && !sessionState.selectedNeeds.isEmpty {
                    sessionState.selectedTransactionNatures = [.expense]
                }
                recalculateData()
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
                recalculateData()
            }
            .onChange(of: sessionState.selectedTags) { recalculateData() }
            .onChange(of: sessionState.selectedCurrencies) { recalculateData() }
            .onChange(of: sessionState.selectedTransactionNatures) { recalculateData() }
            .onChange(of: sessionState.amountCondition) { recalculateData() }
            .onChange(of: sessionState.searchText) { recalculateData() }
            .onChange(of: sessionState.isExcludeMode) { recalculateData() }
            .onChange(of: sessionState.selectedTrendMetric) { recalculateData() }
            .onChange(of: sessionState.customDateRange) { recalculateData() }
    }
}
