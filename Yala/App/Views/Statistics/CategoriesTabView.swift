//
//  CategoriesTabView.swift
//  Yala
//
//  Categories tab content with carousel for Categories and Subcategories pie charts.
//

import Charts
import SwiftData
import SwiftUI

/// Categories tab content view.
/// Displays category and subcategory spending breakdown with carousel and filters.
struct CategoriesTabView: View {

    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(SessionState.self) private var sessionState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences

    // MARK: - Data (passed from parent)

    let accounts: [Account]
    let categories: [Category]
    let allSubcategories: [Subcategory]
    let tags: [Tag]
    let allTransactions: [TransactionItem]

    // MARK: - Scheduled Payments (for Sankey "Planificados" branch)

    /// Loaded internally — the parent view doesn't pass these.
    @Query private var scheduledPayments: [ScheduledPayment]

    /// Compound signature that triggers Sankey recompute when any active SP changes
    /// (create / delete / amount edit / nextDueDate edit / kind change / activation toggle / skip toggle).
    private var scheduledPaymentsSignature: Int {
        var hasher = Hasher()
        for sp in scheduledPayments where sp.isActive {
            hasher.combine(sp.id)
            hasher.combine(sp.amount)
            hasher.combine(sp.nextDueDate.timeIntervalSince1970)
            hasher.combine(sp.paymentCategory)
            hasher.combine(sp.transactionType)
            hasher.combine(sp.skippedDatesRaw)
        }
        return hasher.finalize()
    }

    // MARK: - External Dependencies

    @Bindable var viewModel: StatisticsViewModel
    let defaultCurrencyCode: String
    let onNavigateToRecords: () -> Void

    // MARK: - State

    @State private var categorySpending: [CategorySpendingSummary] = []
    @State private var subcategorySpending: [SubcategorySpendingSummary] = []
    @State private var tagSpending: [TagSpendingSummary] = []
    @State private var needTrendPoints: [NeedTrendPoint] = []
    @State private var selectedNeed: SubcategoryNeed?
    @State private var chartsCarouselPosition: String? = "category"
    @State private var listViewType: ListViewType = .categories
    @State private var isListExpanded: Bool = false
    @State private var isSubcategoriesAutomatic: Bool = false  // Track if switch was automatic
    @State private var showCustomPeriodPicker: Bool = false  // Custom period picker sheet
    @State private var isSyncingFilters: Bool = false  // Anti-loop flag for Need sync functions only
    @Namespace private var listSelectorNamespace
    @Namespace private var comparisonSelectorNamespace

    // Period Comparison State (comparisonMode is in SessionState for sync across tabs)
    @State private var previousCategoryTotal: Double? = nil
    @State private var previousSubcategoryTotal: Double? = nil
    @State private var previousTagTotal: Double? = nil
    @State private var previousNeedTotal: Double? = nil
    @State private var previousNeedAmounts: [SubcategoryNeed: Double] = [:]

    // Need Carousel State
    @State private var needCarouselIndex: Int? = 0

    /// Effective category ID for subcategory filtering (uses first selected category or derives parent from subcategory)
    private var effectiveCategoryID: PersistentIdentifier? {
        if let catID = viewModel.selectedCategories.first {
            return catID
        }
        // Derive parent category from selected subcategories
        if let subID = viewModel.selectedSubcategories.first,
           let subcategory = allSubcategories.first(where: { $0.persistentModelID == subID }) {
            return subcategory.category?.persistentModelID
        }
        return nil
    }

    /// Category IDs to use for visual dimming (includes derived parent from subcategory selection)
    private var effectiveCategoryIDsForDim: Set<PersistentIdentifier> {
        if !viewModel.selectedCategories.isEmpty {
            return viewModel.selectedCategories
        }
        if let catID = effectiveCategoryID {
            return [catID]
        }
        return []
    }

    // MARK: - List View Type

    enum ListViewType: String, CaseIterable, Identifiable {
        case categories
        case subcategories

        var id: String { rawValue }

        var title: String {
            switch self {
            case .categories: return L10n.ListViewType.categories
            case .subcategories: return L10n.ListViewType.subcategories
            }
        }

        var iconName: String {
            switch self {
            case .categories: return "square.grid.2x2.fill"
            case .subcategories: return "list.bullet.indent"
            }
        }
    }

    // MARK: - Body

    /// Check if income-only filter is active (need carousel not applicable)
    private var isIncomeMode: Bool {
        viewModel.selectedTransactionNatures == [.income]
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: DS.Spacing.xl) {
                controlBar
                spendingAnalysisHeader
                chartsCarousel
                sankeyWidget
                // Need carousel only shows for expenses (need classification doesn't apply to income)
                if !isIncomeMode {
                    needCarousel
                }
                categoriesListSection
                recentRecordsSection
            }
            .padding(.top, DS.Spacing.sm)
            .yalaSafeBottomPadding()
        }
        .scrollViewGlassEdges()
        .onAppear {
            calculateData()
            recomputeSankey()
        }
        .onChange(of: viewModel.sankeyInputKey) { recomputeSankey() }
        .onChange(of: allTransactions.count) { recomputeSankey() }
        .onChange(of: scheduledPaymentsSignature) { recomputeSankey() }
        .onChange(of: viewModel.detailPeriod) {
            calculateData()
        }
        .onChange(of: viewModel.selectedAccounts) {
            calculateData()
        }
        .onChange(of: viewModel.selectedCategories) {
            calculateData()
        }
        .onChange(of: viewModel.selectedSubcategories) {
            calculateData()
        }
        .onChange(of: viewModel.selectedTags) {
            calculateData()
        }
        .onChange(of: viewModel.selectedNeeds) {
            calculateData()
            syncNeedFilterToSelection()
        }
        .onChange(of: viewModel.selectedTransactionNatures) {
            calculateData()
        }
        .onChange(of: allSubcategories) {
            calculateData()
        }
        .onChange(of: selectedNeed) {
            syncSelectionToNeedFilter()
            calculateData()
        }
        .onChange(of: sessionState.customDateRange) {
            calculateData()
        }
        .onChange(of: sessionState.comparisonMode) {
            // Recalculate previous period data when comparison mode changes
            calculatePreviousPeriodTotals()
        }
        .onChange(of: sessionState.selectedTransactionNatures) {
            // Sync transaction nature filter from SessionState and recalculate
            viewModel.selectedTransactionNatures = sessionState.selectedTransactionNatures
            enforceListViewLock()
            // Reset carousel to first valid page when income mode changes
            chartsCarouselPosition = isIncomeMode ? "subcategory" : "category"
            calculateData()
        }
        .sheet(isPresented: $showCustomPeriodPicker) {
            CustomPeriodPickerSheet(
                minDate: transactionDateRange.start,
                maxDate: transactionDateRange.end,
                currentRange: sessionState.customDateRange
            )
        }
    }

    /// Date range of all transactions (for custom period picker limits)
    private var transactionDateRange: (start: Date, end: Date) {
        let sortedDates = allTransactions.map(\.date).sorted()
        let start = sortedDates.first ?? Date.now
        let end = sortedDates.last ?? Date.now
        return (start, end)
    }

    // MARK: - Control Bar

    private var controlBar: some View {
        FilterControlBar(
            periodSelector: periodSelector,
            viewModel: viewModel,
            accounts: accounts,
            categories: categories,
            allSubcategories: allSubcategories,
            tags: tags,
            animationValue: viewModel.detailPeriod
        )
        .onChange(of: viewModel.hasActiveFilters) {
            if !viewModel.hasActiveFilters {
                selectedNeed = nil
            }
        }
    }

    private var periodSelector: some View {
        TrendsPeriodMenu(
            selectedPeriod: viewModel.detailPeriod,
            customDateRange: sessionState.customDateRange,
            onSelect: { period in
                sessionState.selectedPeriod = period
            },
            onCustomTapped: {
                showCustomPeriodPicker = true
            }
        )
        .equatable()
    }

    // MARK: - Spending Analysis Header

    /// Header with dynamic title based on income/expense mode
    /// Placed outside carousel to avoid disappearing when no previous data
    private var spendingAnalysisHeader: some View {
        HStack {
            Text(isIncomeMode ? L10n.Statistics.incomeAnalysis : L10n.Statistics.spendingAnalysis)
                .font(DS.Typography.headline)
                .foregroundStyle(.primary)

            InfoHintButton(
                title: isIncomeMode ? L10n.Statistics.incomeAnalysis : L10n.Statistics.spendingAnalysis,
                message: isIncomeMode ? L10n.Widget.Hint.incomeAnalysis : L10n.Widget.Hint.spendingAnalysis
            )

            Spacer()

            // M/A Selector (always visible for applicable periods)
            if showComparisonSelector {
                comparisonModeSelector
            }
        }
    }

    /// Determines if comparison selector should be visible (only when appPreferences.showVariations is ON)
    private var showComparisonSelector: Bool {
        appPreferences.showVariations && PreviousPeriodHelper.isSelectorVisible(for: viewModel.detailPeriod)
    }

    /// Comparison mode selector (M/A toggle)
    private var comparisonModeSelector: some View {
        HStack(spacing: DS.Spacing.sm) {
            ForEach(ComparisonMode.allCases) { mode in
                comparisonSelectorButton(for: mode)
            }
        }
    }

    private func comparisonSelectorButton(for mode: ComparisonMode) -> some View {
        let isSelected = sessionState.comparisonMode == mode

        return Button {
            dsWithAnimation(reduceMotion) {
                sessionState.comparisonMode = mode
            }
        } label: {
            Text(mode.shortName)
                .font(DS.Typography.labelSmall)
                .fontWeight(.semibold)
                .foregroundStyle(isSelected ? Color.white : theme.secondaryText)
                .frame(width: 32, height: 32)
                .background {
                    if isSelected {
                        Circle()
                            .fill(theme.accent)
                            .matchedGeometryEffect(id: "comparisonSelector", in: comparisonSelectorNamespace)
                    } else {
                        Circle()
                            .fill(.thSecondaryText.opacity(0.08))
                    }
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Charts Carousel

    /// Number of pages in carousel (varies by income mode and iPad layout)
    private var carouselPageCount: Int {
        let isWide = DS.Adaptive.isWideScreen(sizeClass)
        if isWide {
            // iPad: tags moved to need row, only category + subcategory (or just subcategory in income)
            return isIncomeMode ? 1 : 2
        }
        return isIncomeMode ? 2 : 3
    }

    @ViewBuilder
    private var chartsCarousel: some View {
        let isWide = DS.Adaptive.isWideScreen(sizeClass)

        VStack(spacing: DS.Spacing.sm) {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: DS.Spacing.md) {
                    // Categories Chart - hidden in income mode
                    if !isIncomeMode {
                        categoryChartCard
                            .containerRelativeFrame(.horizontal, count: isWide ? 2 : 1, spacing: isWide ? DS.Spacing.md : 0)
                            .id("category")
                    }

                    // Subcategories Chart
                    subcategoryChartCard
                        .containerRelativeFrame(.horizontal, count: isWide ? 2 : 1, spacing: isWide ? DS.Spacing.md : 0)
                        .id("subcategory")

                    // Tags Chart - on iPad, tags moves next to need
                    if !isWide {
                        tagChartCard
                            .containerRelativeFrame(.horizontal)
                            .id("tags")
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $chartsCarouselPosition)
            .frame(height: 340)

            // Page indicator - hide on iPad (multiple charts already visible)
            if !isWide {
                HStack(spacing: DS.Spacing.sm) {
                    ForEach(0..<carouselPageCount, id: \.self) { page in
                        let pageId = carouselPageIds[page]
                        Circle()
                            .fill(
                                chartsCarouselPosition == pageId
                                    ? theme.primaryText.opacity(0.3)
                                    : theme.secondaryText.opacity(0.2)
                            )
                            .frame(width: 6, height: 6)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    /// IDs for carousel pages based on income mode and iPad layout
    private var carouselPageIds: [String] {
        let isWide = DS.Adaptive.isWideScreen(sizeClass)
        if isWide {
            return isIncomeMode ? ["subcategory"] : ["category", "subcategory"]
        }
        return isIncomeMode ? ["subcategory", "tags"] : ["category", "subcategory", "tags"]
    }

    // MARK: - Category Chart Card

    private var categoryChartCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.none) {
            if categorySpending.isEmpty {
                emptyState(
                    icon: "chart.pie",
                    title: L10n.Statistics.noCategoryData,
                    subtitle: L10n.Statistics.noExpensesInPeriod
                )
                .frame(height: 320)
            } else {
                CategoriesPieWidget(
                    categories: categorySpending,
                    currencyCode: defaultCurrencyCode,
                    selectedCategoryIDs: viewModel.isExcludeMode
                        ? viewModel.selectedCategories  // Exclude: only directly excluded categories
                        : effectiveCategoryIDsForDim,   // Include: dimming with derived parent
                    onSelectCategory: { categoryID in
                        if viewModel.selectedCategories.contains(categoryID) {
                            viewModel.selectedCategories.remove(categoryID)
                        } else {
                            viewModel.selectedCategories = [categoryID]
                        }
                        viewModel.selectedSubcategories.removeAll()
                    },
                    isExcludeMode: viewModel.isExcludeMode,
                    size: .large,
                    period: viewModel.detailPeriod,
                    customRange: sessionState.customDateRange,
                    previousTotalAmount: previousCategoryTotal,
                    comparisonMode: sessionState.comparisonMode,
                    showVariationHeader: appPreferences.showVariations && viewModel.detailPeriod != .allTime
                )
            }
        }
    }

    // MARK: - Subcategory Chart Card

    private var subcategoryChartCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.none) {
            if subcategorySpending.isEmpty {
                emptyState(
                    icon: "chart.pie",
                    title: L10n.Statistics.noSubcategoryData,
                    subtitle: L10n.Statistics.noExpensesInPeriod
                )
                .frame(height: 320)
            } else {
                SubcategoriesPieWidget(
                    subcategories: subcategorySpending,
                    currencyCode: defaultCurrencyCode,
                    selectedCategoryID: effectiveCategoryID,
                    selectedSubcategoryIDs: viewModel.selectedSubcategories,
                    onSelectSubcategory: { subcategoryID in
                        if viewModel.selectedSubcategories.contains(subcategoryID) {
                            viewModel.selectedSubcategories.remove(subcategoryID)
                        } else {
                            viewModel.selectedSubcategories = [subcategoryID]
                        }
                        // Clear category filter — subcategory selection is more specific
                        viewModel.selectedCategories.removeAll()
                    },
                    isExcludeMode: viewModel.isExcludeMode,
                    size: .large,
                    period: viewModel.detailPeriod,
                    customRange: sessionState.customDateRange,
                    previousTotalAmount: previousSubcategoryTotal,
                    comparisonMode: sessionState.comparisonMode,
                    showVariationHeader: appPreferences.showVariations && viewModel.detailPeriod != .allTime
                )
            }
        }
    }

    // MARK: - Tag Chart Card

    private var tagChartCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.none) {
            if tagSpending.isEmpty {
                emptyState(
                    icon: "tag",
                    title: L10n.Empty.noTags,
                    subtitle: L10n.Statistics.noExpensesInPeriod
                )
                .frame(height: 320)
            } else {
                TagsPieWidget(
                    tags: tagSpending,
                    currencyCode: defaultCurrencyCode,
                    selectedTagIDs: viewModel.selectedTags,
                    onSelectTag: { tagID in
                        if viewModel.selectedTags.contains(tagID) {
                            viewModel.selectedTags.remove(tagID)
                        } else {
                            viewModel.selectedTags = [tagID]
                        }
                    },
                    isExcludeMode: viewModel.isExcludeMode,
                    size: .large,
                    period: viewModel.detailPeriod,
                    customRange: sessionState.customDateRange,
                    previousTotalAmount: previousTagTotal,
                    comparisonMode: sessionState.comparisonMode,
                    showVariationHeader: appPreferences.showVariations && viewModel.detailPeriod != .allTime
                )
            }
        }
    }

    // MARK: - Need Carousel

    /// Count of needs with data (for dynamic height calculation)
    private var visibleNeedCount: Int {
        guard !needTrendPoints.isEmpty else { return 3 }
        let essentialTotal = needTrendPoints.reduce(0) { $0 + $1.essential }
        let priorityTotal = needTrendPoints.reduce(0) { $0 + $1.priority }
        let optionalTotal = needTrendPoints.reduce(0) { $0 + $1.optional }
        let unclassifiedTotal = needTrendPoints.reduce(0) { $0 + $1.unclassified }

        var count = 0
        if essentialTotal > 0 { count += 1 }
        if priorityTotal > 0 { count += 1 }
        if optionalTotal > 0 { count += 1 }
        if unclassifiedTotal > 0 { count += 1 }
        return max(count, 3)  // Always show at least 3 bars
    }

    /// Dynamic height based on current carousel page and visible needs
    private var needCarouselHeight: CGFloat {
        if (needCarouselIndex ?? 0) == 0 {
            return 340  // Large chart view
        } else {
            // Compact view: dynamic height based on number of visible needs
            // Each bar ~52 points (row + progress + spacing) + container padding (~56)
            let barHeight: CGFloat = 52
            let containerPadding: CGFloat = 56
            return CGFloat(visibleNeedCount) * barHeight + containerPadding
        }
    }

    @ViewBuilder
    private var sankeyWidget: some View {
        if viewModel.sankeyData.hasFlow {
            @Bindable var prefs = appPreferences
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                sankeyHeader(prefs: $prefs.sankeyLabelMode)
                SankeyChartView(
                    data: viewModel.sankeyData,
                    currencyCode: defaultCurrencyCode,
                    labelMode: $prefs.sankeyLabelMode,
                    selectedCategoryIDs: viewModel.selectedCategories,
                    selectedSubcategoryIDs: viewModel.selectedSubcategories,
                    onTapCategory: { catID in
                        dsWithAnimation(reduceMotion) {
                            toggleSankeyCategory(catID)
                        }
                    },
                    onTapSubcategory: { subID in
                        dsWithAnimation(reduceMotion) {
                            toggleSankeySubcategory(subID)
                        }
                    }
                )
            }
            .solidCard(padding: DS.Card.paddingCompact, radius: DS.Radius.lg)
        }
    }

    private func sankeyHeader(prefs: Binding<SankeyLabelMode>) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(L10n.Statistics.Sankey.title)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(appPreferences.currency(viewModel.sankeyData.totalExpense,
                    currencyCode: defaultCurrencyCode
                ))
                .font(DS.Typography.headline)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            }
            Spacer(minLength: DS.Spacing.sm)
            SankeyLabelModeToggle(mode: prefs)
        }
    }

    private func recomputeSankey() {
        viewModel.calculateSankeyData(
            allTransactions: allTransactions,
            accounts: accounts,
            scheduledPayments: scheduledPayments,
            defaultCurrencyCode: defaultCurrencyCode
        )
    }

    private func toggleSankeyCategory(_ catID: PersistentIdentifier) {
        if viewModel.selectedCategories.contains(catID) {
            viewModel.selectedCategories.remove(catID)
        } else {
            viewModel.selectedCategories = [catID]
            viewModel.selectedSubcategories.removeAll()
        }
    }

    private func toggleSankeySubcategory(_ subID: PersistentIdentifier) {
        if viewModel.selectedSubcategories.contains(subID) {
            viewModel.selectedSubcategories.remove(subID)
        } else {
            viewModel.selectedSubcategories = [subID]
            viewModel.selectedCategories.removeAll()
        }
    }

    @ViewBuilder
    private var needCarousel: some View {
        let isWide = DS.Adaptive.isWideScreen(sizeClass)

        if isWide {
            // iPad: tags pie + need large side by side, no compact need
            HStack(alignment: .top, spacing: DS.Spacing.lg) {
                tagChartCard
                    .frame(maxWidth: .infinity)
                needWidgetLarge
                    .frame(maxWidth: .infinity)
            }
        } else {
            // iPhone: carousel with large/compact need slides
            VStack(spacing: DS.Spacing.sm) {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: DS.Spacing.md) {
                        needWidgetLarge
                            .containerRelativeFrame(.horizontal)
                            .id(0)

                        needWidgetCompact
                            .containerRelativeFrame(.horizontal)
                            .id(1)
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: $needCarouselIndex)
                .frame(height: needCarouselHeight)
                .dsAnimation(.easeInOut(duration: 0.3), value: needCarouselIndex, reduceMotion: reduceMotion)

                HStack(spacing: DS.Spacing.sm) {
                    ForEach(0..<2, id: \.self) { page in
                        Circle()
                            .fill(
                                page == (needCarouselIndex ?? 0)
                                    ? theme.primaryText.opacity(0.3)
                                    : theme.secondaryText.opacity(0.2)
                            )
                            .frame(width: 6, height: 6)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    private var needWidgetLarge: some View {
        NeedTrendWidget(
            trendPoints: needTrendPoints,
            selectedNeed: selectedNeed,
            currencyCode: defaultCurrencyCode,
            size: .large,
            grouping: needGrouping,
            interval: viewModel.panelDateInterval,
            onSelectNeed: { need in
                dsWithAnimation(reduceMotion) {
                    if selectedNeed == need {
                        selectedNeed = nil
                    } else {
                        selectedNeed = need
                    }
                }
            },
            onShowDetail: nil,
            period: viewModel.detailPeriod,
            previousTotalAmount: previousNeedTotal,
            previousAmountByNeed: previousNeedAmounts,
            showVariationHeader: appPreferences.showVariations && viewModel.detailPeriod != .allTime,
            comparisonMode: sessionState.comparisonMode,
            isIncomeMode: viewModel.selectedTransactionNatures == [.income]
        )
    }

    private var needWidgetCompact: some View {
        NeedTrendWidget(
            trendPoints: needTrendPoints,
            selectedNeed: selectedNeed,
            currencyCode: defaultCurrencyCode,
            size: .medium,
            grouping: needGrouping,
            interval: viewModel.panelDateInterval,
            onSelectNeed: { need in
                dsWithAnimation(reduceMotion) {
                    if selectedNeed == need {
                        selectedNeed = nil
                    } else {
                        selectedNeed = need
                    }
                }
            },
            onShowDetail: nil,
            period: viewModel.detailPeriod,
            previousTotalAmount: previousNeedTotal,
            previousAmountByNeed: previousNeedAmounts,
            showVariationHeader: appPreferences.showVariations && viewModel.detailPeriod != .allTime,
            comparisonMode: sessionState.comparisonMode,
            isIncomeMode: viewModel.selectedTransactionNatures == [.income]
        )
    }

    /// Determine grouping for need widget based on selected period
    /// Matches PanelViewModel logic for consistent bar chart grouping
    private var needGrouping: TrendGrouping {
        switch viewModel.detailPeriod {
        case .thisWeek, .last7Days:
            return .day  // Daily bars for week
        case .thisMonth, .lastMonth, .last30Days:
            return .day  // Daily bars for month
        case .thisYear, .lastYear, .allTime, .custom:
            return .month  // Monthly bars for year/all-time/custom
        }
    }

    // MARK: - Categories List Section

    private var categoriesListSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.none) {
            // Header with title and selector
            HStack(alignment: .center) {
                Text(
                    listViewType == .categories
                        ? L10n.Statistics.topCategories : L10n.Statistics.topSubcategories
                )
                .font(DS.Typography.headline)
                .foregroundStyle(.primary)

                Spacer()

                listViewSelector
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.top, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.md)

            // Content based on selected view type
            if listViewType == .categories {
                if categorySpending.isEmpty {
                    emptyState(
                        icon: "chart.bar.xaxis",
                        title: L10n.Empty.noCategories,
                        subtitle: L10n.Statistics.noDataToShow
                    )
                    .frame(height: 200)
                } else {
                    AllCategoriesListContent(
                        categories: categorySpending,
                        currencyCode: defaultCurrencyCode,
                        selectedCategoryIDs: effectiveCategoryIDsForDim,
                        isExcludeMode: viewModel.isExcludeMode,
                        isExpanded: isListExpanded,
                        showVariation: appPreferences.showVariations && viewModel.detailPeriod != .allTime,
                        onToggleExpanded: { isListExpanded.toggle() },
                        onSelectCategory: { categoryID in
                            if viewModel.selectedCategories.contains(categoryID) {
                                viewModel.selectedCategories.remove(categoryID)
                            } else {
                                viewModel.selectedCategories = [categoryID]
                            }
                            viewModel.selectedSubcategories.removeAll()
                        }
                    )
                }
            } else {
                if subcategorySpending.isEmpty {
                    emptyState(
                        icon: "list.bullet.indent",
                        title: L10n.Empty.noSubcategories,
                        subtitle: L10n.Statistics.noDataToShow
                    )
                    .frame(height: 200)
                } else {
                    AllSubcategoriesListContent(
                        subcategories: subcategorySpending,
                        currencyCode: defaultCurrencyCode,
                        selectedCategoryIDs: viewModel.isExcludeMode
                            ? viewModel.selectedCategories
                            : effectiveCategoryIDsForDim,
                        selectedSubcategoryIDs: viewModel.selectedSubcategories,
                        isExcludeMode: viewModel.isExcludeMode,
                        isExpanded: isListExpanded,
                        showVariation: appPreferences.showVariations && viewModel.detailPeriod != .allTime,
                        onToggleExpanded: { isListExpanded.toggle() },
                        onSelectSubcategory: { subcategoryID in
                            if viewModel.selectedSubcategories.contains(subcategoryID) {
                                viewModel.selectedSubcategories.remove(subcategoryID)
                            } else {
                                viewModel.selectedSubcategories = [subcategoryID]
                            }
                            // Clear category filter — subcategory selection is more specific
                            viewModel.selectedCategories.removeAll()
                        }
                    )
                }
            }
        }
        .solidCard()
    }

    private var listViewSelector: some View {
        HStack(spacing: DS.Spacing.sm) {
            ForEach(ListViewType.allCases) { viewType in
                listViewButton(for: viewType)
            }
        }
    }

    private func listViewButton(for viewType: ListViewType) -> some View {
        let isSelected = listViewType == viewType
        let isLocked = shouldLockToSubcategories

        return Button {
            guard !isLocked || viewType == .subcategories else { return }

            dsWithAnimation(reduceMotion) {
                setListViewManually(viewType)
            }
        } label: {
            Image(systemName: viewType.iconName)
                .font(DS.Typography.labelSmall)
                .fontWeight(.semibold)
                .foregroundStyle(isSelected ? Color.white : theme.secondaryText)
                .frame(width: 32, height: 32)
                .background {
                    if isSelected {
                        Circle()
                            .fill(theme.accent)
                            .matchedGeometryEffect(id: "listSelector", in: listSelectorNamespace)
                    } else {
                        Circle()
                            .fill(.thSecondaryText.opacity(0.08))
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(viewType.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .opacity((isLocked && viewType == .categories) ? 0.4 : 1.0)
        .disabled(isLocked && viewType == .categories)
        .accessibilityHint((isLocked && viewType == .categories) ? L10n.Accessibility.categoriesLocked : "")
    }

    // MARK: - List View Auto-switching Logic

    /// Determines if list view should be locked to subcategories
    /// - When a category filter is applied (show only subcategories of that category)
    /// - When income mode is active (category breakdown not useful for income)
    private var shouldLockToSubcategories: Bool {
        if isIncomeMode { return true }
        if viewModel.isExcludeMode { return false }
        return !viewModel.selectedCategories.isEmpty || !viewModel.selectedSubcategories.isEmpty
    }

    /// Enforce list view lock logic based on current category filter
    private func enforceListViewLock() {
        if shouldLockToSubcategories {
            // Lock to subcategories when category filter is applied (automatic)
            if listViewType != .subcategories {
                listViewType = .subcategories
                isSubcategoriesAutomatic = true
            }
        } else {
            // When category filter is cleared, reset to categories ONLY if switch was automatic
            if listViewType == .subcategories && isSubcategoriesAutomatic {
                listViewType = .categories
                isSubcategoriesAutomatic = false
            }
        }
    }

    /// Called when user manually selects a list view type
    private func setListViewManually(_ type: ListViewType) {
        listViewType = type
        // Mark as manual selection (not automatic)
        isSubcategoriesAutomatic = false
    }

    // MARK: - Empty State

    private func emptyState(icon: String, title: String, subtitle: String) -> some View {
        YalaEmptyState(
            icon: icon,
            title: title,
            message: subtitle
        )
    }

    // MARK: - Data Calculation

    private func calculateData() {
        let interval = viewModel.panelDateInterval

        // Build filter criteria for pie charts
        // Include mode: show all categories/subcategories with dim (no filter)
        // Exclude mode: actually exclude selected categories/subcategories from data
        let pieChartCriteria = FilterCriteria(
            selectedAccounts: viewModel.selectedAccounts,
            selectedCategories: viewModel.isExcludeMode ? viewModel.selectedCategories : [],
            selectedSubcategories: viewModel.isExcludeMode ? viewModel.selectedSubcategories : [],
            selectedTags: viewModel.selectedTags,
            selectedNeeds: viewModel.selectedNeeds,
            selectedTransactionNatures: viewModel.selectedTransactionNatures,
            selectedCurrencies: viewModel.selectedCurrencies,
            isExcludeMode: viewModel.isExcludeMode,
            transactionTypeFilter: .all,
            amountCondition: viewModel.amountCondition,
            searchText: viewModel.searchText,
            dateInterval: interval
        )

        // Filter transactions for pie charts (show all categories/subcategories)
        let pieFiltered = FilterService.filterForTrends(
            transactions: allTransactions,
            accounts: accounts,
            criteria: pieChartCriteria
        )

        // Create criteria for need widget (respects cat/subcat filters, but NOT need filter - show all with dim)
        let needCriteria = FilterCriteria(
            selectedAccounts: viewModel.selectedAccounts,
            selectedCategories: viewModel.selectedCategories,
            selectedSubcategories: viewModel.selectedSubcategories,
            selectedTags: viewModel.selectedTags,
            selectedNeeds: [],  // Don't filter by need - show all with dim
            selectedTransactionNatures: viewModel.selectedTransactionNatures,
            selectedCurrencies: viewModel.selectedCurrencies,
            isExcludeMode: viewModel.isExcludeMode,
            transactionTypeFilter: .all,
            amountCondition: viewModel.amountCondition,
            searchText: viewModel.searchText,
            dateInterval: interval
        )

        // Filter transactions for need widget
        let needFiltered = FilterService.filterForTrends(
            transactions: allTransactions,
            accounts: accounts,
            criteria: needCriteria
        )

        // Calculate category spending (show ALL categories, dim applied in widget)
        // Pass transactionNatures filter - empty means show expenses only (default)
        let naturesFilter: Set<TransactionNature>? = viewModel.selectedTransactionNatures.isEmpty
            ? nil  // Default: expense only
            : viewModel.selectedTransactionNatures

        let newCategorySpending = TopSpendingCategoriesCalculator.calculateTopSpending(
            transactions: pieFiltered,
            interval: interval,
            currencyCode: defaultCurrencyCode,
            transactionNatures: naturesFilter,

        )
        if newCategorySpending != categorySpending { categorySpending = newCategorySpending }

        // Calculate subcategory spending - filter by category if one is selected
        let subcategoryTransactions: [TransactionItem]
        if viewModel.isExcludeMode {
            // pieFiltered already excludes the right transactions via pieChartCriteria
            subcategoryTransactions = pieFiltered
        } else if let categoryID = effectiveCategoryID {
            // Filter to only show subcategories of selected category
            subcategoryTransactions = pieFiltered.filter { $0.category?.persistentModelID == categoryID }
        } else {
            subcategoryTransactions = pieFiltered
        }

        let newSubcategorySpending = TopSubcategoriesCalculator.calculateTopSubcategories(
            transactions: subcategoryTransactions,
            interval: interval,
            currencyCode: defaultCurrencyCode,
            categoryFilter: nil,
            transactionNatures: naturesFilter,

        )
        if newSubcategorySpending != subcategorySpending { subcategorySpending = newSubcategorySpending }

        // Calculate tag spending — respects category/subcategory filters but shows ALL tags
        let tagCriteria = FilterCriteria(
            selectedAccounts: viewModel.selectedAccounts,
            selectedCategories: viewModel.selectedCategories,
            selectedSubcategories: viewModel.selectedSubcategories,
            selectedTags: [],  // Don't filter by tag — show all with dim
            selectedNeeds: viewModel.selectedNeeds,
            selectedTransactionNatures: viewModel.selectedTransactionNatures,
            selectedCurrencies: viewModel.selectedCurrencies,
            isExcludeMode: viewModel.isExcludeMode,
            transactionTypeFilter: .all,
            amountCondition: viewModel.amountCondition,
            searchText: viewModel.searchText,
            dateInterval: interval
        )
        let tagFiltered = FilterService.filterForTrends(
            transactions: allTransactions, accounts: accounts, criteria: tagCriteria
        )
        let newTagSpending = TagSpendingCalculator.calculateTopSpending(
            transactions: tagFiltered,
            interval: interval,
            currencyCode: defaultCurrencyCode,
            transactionNatures: naturesFilter
        )
        if newTagSpending != tagSpending { tagSpending = newTagSpending }

        // Calculate need trend data with correct grouping based on period
        // Uses needFiltered (no need filter) so selection = visual dim, not data filter
        let preferredCurrency = CurrencyCode(rawValue: defaultCurrencyCode) ?? .pen
        let newNeedTrendPoints = NeedTrendHelper.calculateTrend(
            transactions: needFiltered,
            grouping: needGrouping,
            interval: interval,
            preferredCurrency: preferredCurrency,

        )
        if newNeedTrendPoints != needTrendPoints { needTrendPoints = newNeedTrendPoints }

        // Apply list view lock logic after data calculation
        enforceListViewLock()

        // Calculate previous period totals for comparison
        calculatePreviousPeriodTotals()
    }

    // MARK: - Previous Period Calculation

    private func calculatePreviousPeriodTotals() {
        // Skip previous period calculation for "All Time" (no meaningful comparison)
        guard viewModel.detailPeriod != .allTime else {
            previousCategoryTotal = nil
            previousSubcategoryTotal = nil
            previousTagTotal = nil
            previousNeedTotal = nil
            previousNeedAmounts = [:]
            return
        }

        // Get previous period interval based on comparison mode
        let previousInterval = PreviousPeriodHelper.previousInterval(
            for: viewModel.detailPeriod,
            mode: sessionState.comparisonMode,
            customRange: sessionState.customDateRange
        )

        // Build filter criteria for previous period
        // Include mode: show all (no filter) for comparison
        // Exclude mode: exclude selected categories/subcategories for consistent comparison
        let criteria = FilterCriteria(
            selectedAccounts: viewModel.selectedAccounts,
            selectedCategories: viewModel.isExcludeMode ? viewModel.selectedCategories : [],
            selectedSubcategories: viewModel.isExcludeMode ? viewModel.selectedSubcategories : [],
            selectedTags: viewModel.selectedTags,
            selectedNeeds: viewModel.selectedNeeds,
            selectedTransactionNatures: viewModel.selectedTransactionNatures,
            selectedCurrencies: viewModel.selectedCurrencies,
            isExcludeMode: viewModel.isExcludeMode,
            transactionTypeFilter: .all,
            amountCondition: viewModel.amountCondition,
            searchText: viewModel.searchText,
            dateInterval: previousInterval
        )

        // Filter transactions for previous period
        let previousFiltered = FilterService.filterForTrends(
            transactions: allTransactions,
            accounts: accounts,
            criteria: criteria
        )

        // Calculate previous period category spending
        // Use same need filter as current period for consistent comparison
        let naturesFilter: Set<TransactionNature>? = viewModel.selectedTransactionNatures.isEmpty
            ? nil
            : viewModel.selectedTransactionNatures

        let previousCategorySpending = TopSpendingCategoriesCalculator.calculateTopSpending(
            transactions: previousFiltered,
            interval: previousInterval,
            currencyCode: defaultCurrencyCode,
            transactionNatures: naturesFilter,

        )
        previousCategoryTotal = previousCategorySpending.reduce(0) { $0 + $1.amount }

        // Populate previousAmount on each category item
        let prevCategoryAmounts = Dictionary(
            uniqueKeysWithValues: previousCategorySpending.map { ($0.category.persistentModelID, $0.amount) }
        )
        for index in categorySpending.indices {
            categorySpending[index].previousAmount = prevCategoryAmounts[categorySpending[index].category.persistentModelID]
        }

        // Calculate previous period subcategory spending (filter by category if selected)
        let prevSubcategoryTransactions: [TransactionItem]
        if viewModel.isExcludeMode {
            // previousFiltered already excludes the right transactions via criteria
            prevSubcategoryTransactions = previousFiltered
        } else if let categoryID = effectiveCategoryID {
            prevSubcategoryTransactions = previousFiltered.filter { $0.category?.persistentModelID == categoryID }
        } else {
            prevSubcategoryTransactions = previousFiltered
        }

        let previousSubcategorySpending = TopSubcategoriesCalculator.calculateTopSubcategories(
            transactions: prevSubcategoryTransactions,
            interval: previousInterval,
            currencyCode: defaultCurrencyCode,
            categoryFilter: nil,
            transactionNatures: naturesFilter,

        )
        previousSubcategoryTotal = previousSubcategorySpending.reduce(0) { $0 + $1.amount }

        // Populate previousAmount on each subcategory item
        let prevSubcategoryAmounts = Dictionary(
            uniqueKeysWithValues: previousSubcategorySpending.compactMap { summary -> (PersistentIdentifier, Double)? in
                guard let id = summary.persistentID else { return nil }
                return (id, summary.amount)
            }
        )
        for index in subcategorySpending.indices {
            if let id = subcategorySpending[index].persistentID {
                subcategorySpending[index].previousAmount = prevSubcategoryAmounts[id]
            }
        }

        // Calculate previous period tag spending — respects category/subcategory filters
        let prevTagCriteria = FilterCriteria(
            selectedAccounts: viewModel.selectedAccounts,
            selectedCategories: viewModel.selectedCategories,
            selectedSubcategories: viewModel.selectedSubcategories,
            selectedTags: [],  // Don't filter by tag — show all
            selectedNeeds: viewModel.selectedNeeds,
            selectedTransactionNatures: viewModel.selectedTransactionNatures,
            selectedCurrencies: viewModel.selectedCurrencies,
            transactionTypeFilter: .all,
            amountCondition: viewModel.amountCondition,
            searchText: viewModel.searchText,
            dateInterval: previousInterval
        )
        let prevTagFiltered = FilterService.filterForTrends(
            transactions: allTransactions, accounts: accounts, criteria: prevTagCriteria
        )
        let previousTagSpending = TagSpendingCalculator.calculateTopSpending(
            transactions: prevTagFiltered,
            interval: previousInterval,
            currencyCode: defaultCurrencyCode,
            transactionNatures: naturesFilter
        )
        previousTagTotal = previousTagSpending.reduce(0) { $0 + $1.amount }

        // Populate previousAmount on each tag item
        let prevTagAmounts = Dictionary(
            uniqueKeysWithValues: previousTagSpending.map { ($0.tag.persistentModelID, $0.amount) }
        )
        for index in tagSpending.indices {
            tagSpending[index].previousAmount = prevTagAmounts[tagSpending[index].tag.persistentModelID]
        }

        // Calculate previous period need trend data
        // Use separate criteria WITHOUT nature filter for consistent comparison
        let prevNeedCriteria = FilterCriteria(
            selectedAccounts: viewModel.selectedAccounts,
            selectedCategories: [],
            selectedSubcategories: [],
            selectedTags: viewModel.selectedTags,
            selectedNeeds: [],  // Don't filter by nature
            selectedTransactionNatures: viewModel.selectedTransactionNatures,
            selectedCurrencies: viewModel.selectedCurrencies,
            isExcludeMode: viewModel.isExcludeMode,
            transactionTypeFilter: .all,
            amountCondition: viewModel.amountCondition,
            searchText: viewModel.searchText,
            dateInterval: previousInterval
        )
        let prevNeedFiltered = FilterService.filterForTrends(
            transactions: allTransactions,
            accounts: accounts,
            criteria: prevNeedCriteria
        )

        let preferredCurrency = CurrencyCode(rawValue: defaultCurrencyCode) ?? .pen
        let previousNeedPoints = NeedTrendHelper.calculateTrend(
            transactions: prevNeedFiltered,
            grouping: needGrouping,
            interval: previousInterval,
            preferredCurrency: preferredCurrency,

        )

        // Calculate totals by nature for previous period
        var prevNeedAmounts: [SubcategoryNeed: Double] = [:]
        var prevNeedTotal: Double = 0
        for point in previousNeedPoints {
            prevNeedAmounts[.essential, default: 0] += point.essential
            prevNeedAmounts[.priority, default: 0] += point.priority
            prevNeedAmounts[.optional, default: 0] += point.optional
            prevNeedAmounts[.unclassified, default: 0] += point.unclassified
            prevNeedTotal += point.total
        }
        previousNeedAmounts = prevNeedAmounts
        previousNeedTotal = prevNeedTotal > 0 ? prevNeedTotal : nil

        // Handle case where there's no data in previous period
        if previousCategoryTotal == 0 { previousCategoryTotal = nil }
        if previousSubcategoryTotal == 0 { previousSubcategoryTotal = nil }
        if previousTagTotal == 0 { previousTagTotal = nil }
    }

    // MARK: - Filter Synchronization

    private func syncSelectionToNeedFilter() {
        guard !isSyncingFilters else { return }
        isSyncingFilters = true
        defer { isSyncingFilters = false }

        if let need = selectedNeed {
            // Replace all selected natures with the new one (single selection)
            viewModel.selectedNeeds = [need]
        } else {
            // Clear all when deselected
            viewModel.selectedNeeds.removeAll()
        }
    }

    private func syncNeedFilterToSelection() {
        guard !isSyncingFilters else { return }
        isSyncingFilters = true
        defer { isSyncingFilters = false }

        if viewModel.selectedNeeds.count == 1 {
            selectedNeed = viewModel.selectedNeeds.first
        } else if viewModel.selectedNeeds.isEmpty {
            selectedNeed = nil
        }
    }

    // MARK: - Recent Records Section

    private var recentRecordsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text(L10n.Statistics.latestRecords)
                .font(DS.Typography.headline)
                .foregroundStyle(.thPrimaryText)

            if viewModel.recentRecords.isEmpty {
                emptyRecordsState
            } else {
                ForEach(viewModel.recentRecords.prefix(5), id: \.persistentModelID) { record in
                    CompactRecordRow(record: record, currencyCode: defaultCurrencyCode)
                }
            }

            Button {
                onNavigateToRecords()
            } label: {
                HStack {
                    Spacer()
                    Text(L10n.Action.viewAll)
                        .font(DS.Typography.headline)
                    Image(systemName: "chevron.right")
                        .font(DS.Typography.caption)
                        .accessibilityHidden(true)
                    Spacer()
                }
                .padding(.vertical, DS.Spacing.md)
                .foregroundStyle(theme.accent)
                .background(theme.accent.opacity(DS.Opacity.subtle))
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .solidCard(padding: DS.Card.padding)
    }

    private var emptyRecordsState: some View {
        VStack(spacing: DS.Spacing.sm) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(DS.Typography.title)
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
            Text(L10n.Statistics.noRecords)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.xl)
    }

}

// MARK: - All Categories List Content

/// Widget that displays all categories (not limited) in a list format
private struct AllCategoriesListContent: View {
    let categories: [CategorySpendingSummary]
    let currencyCode: String
    var selectedCategoryIDs: Set<PersistentIdentifier> = []
    var isExcludeMode: Bool = false
    var isExpanded: Bool
    var showVariation: Bool = true
    var onToggleExpanded: (() -> Void)?
    var onSelectCategory: ((PersistentIdentifier) -> Void)?
    @Environment(\.yalaTheme) private var theme

    /// Visible categories: in exclude mode, excluded items are hidden entirely
    private var visibleCategories: [CategorySpendingSummary] {
        if isExcludeMode && !selectedCategoryIDs.isEmpty {
            return categories.filter { !selectedCategoryIDs.contains($0.category.persistentModelID) }
        }
        return categories
    }

    private var displayedCategories: [CategorySpendingSummary] {
        isExpanded ? visibleCategories : Array(visibleCategories.prefix(10))
    }

    private var showExpandButton: Bool {
        visibleCategories.count > 10
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            if let maxAmount = displayedCategories.first?.amount {
                ForEach(displayedCategories) { summary in
                    let isSelected = selectedCategoryIDs.contains(summary.category.persistentModelID)
                    let isAnySelected = !selectedCategoryIDs.isEmpty
                    // In exclude mode, excluded items are already hidden — no dimming
                    let shouldDim = !isExcludeMode && isAnySelected && !isSelected

                    Button {
                        onSelectCategory?(summary.category.persistentModelID)
                    } label: {
                        CategoryRowView(
                            summary: summary,
                            maxAmount: maxAmount,
                            currencyCode: currencyCode,
                            showVariation: showVariation
                        )
                        .opacity(shouldDim ? 0.3 : 1.0)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                if showExpandButton {
                    Button {
                        onToggleExpanded?()
                    } label: {
                        HStack {
                            Spacer()
                            Text(isExpanded ? L10n.Action.viewLess : L10n.Action.viewAll)
                                .font(DS.Typography.headline)
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(DS.Typography.caption)
                                .accessibilityHidden(true)
                            Spacer()
                        }
                        .padding(.vertical, DS.Spacing.md)
                        .foregroundStyle(theme.accent)
                        .background((theme.accent).opacity(DS.Opacity.subtle))
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, DS.Spacing.xl)
        .padding(.bottom, DS.Spacing.xl)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

// MARK: - All Subcategories List Content

/// Widget that displays all subcategories (not limited) in a list format
private struct AllSubcategoriesListContent: View {
    let subcategories: [SubcategorySpendingSummary]
    let currencyCode: String
    var selectedCategoryIDs: Set<PersistentIdentifier> = []
    var selectedSubcategoryIDs: Set<PersistentIdentifier> = []
    var isExcludeMode: Bool = false
    var isExpanded: Bool
    var showVariation: Bool = true
    var onToggleExpanded: (() -> Void)?
    var onSelectSubcategory: ((PersistentIdentifier) -> Void)?
    @Environment(\.yalaTheme) private var theme

    /// Visible subcategories: in exclude mode, excluded items are hidden entirely
    private var visibleSubcategories: [SubcategorySpendingSummary] {
        if isExcludeMode && !selectedSubcategoryIDs.isEmpty {
            return subcategories.filter {
                guard let id = $0.persistentID else { return true }
                return !selectedSubcategoryIDs.contains(id)
            }
        }
        return subcategories
    }

    private var displayedSubcategories: [SubcategorySpendingSummary] {
        isExpanded ? visibleSubcategories : Array(visibleSubcategories.prefix(10))
    }

    private var showExpandButton: Bool {
        visibleSubcategories.count > 10
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            if let maxAmount = displayedSubcategories.first?.amount {
                ForEach(displayedSubcategories) { summary in
                    let isSelected = summary.persistentID.map { selectedSubcategoryIDs.contains($0) } ?? false
                    let isAnySelected = !selectedSubcategoryIDs.isEmpty

                    // Check if this subcategory belongs to a selected category
                    let belongsToSelectedCategory =
                        selectedCategoryIDs.isEmpty
                        || (summary.category?.persistentModelID).map { selectedCategoryIDs.contains($0) } ?? false

                    // In exclude mode, excluded items are already hidden — only dim for include mode or category mismatch
                    let shouldDim = (!isExcludeMode && isAnySelected && !isSelected) || !belongsToSelectedCategory

                    Button {
                        if let persistentID = summary.persistentID {
                            onSelectSubcategory?(persistentID)
                        }
                    } label: {
                        SubcategoryRowView(
                            summary: summary,
                            maxAmount: maxAmount,
                            currencyCode: currencyCode,
                            showVariation: showVariation
                        )
                        .opacity(shouldDim ? 0.3 : 1.0)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                if showExpandButton {
                    Button {
                        onToggleExpanded?()
                    } label: {
                        HStack {
                            Spacer()
                            Text(isExpanded ? L10n.Action.viewLess : L10n.Action.viewAll)
                                .font(DS.Typography.headline)
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(DS.Typography.caption)
                                .accessibilityHidden(true)
                            Spacer()
                        }
                        .padding(.vertical, DS.Spacing.md)
                        .foregroundStyle(theme.accent)
                        .background((theme.accent).opacity(DS.Opacity.subtle))
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, DS.Spacing.xl)
        .padding(.bottom, DS.Spacing.xl)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

// MARK: - Category Row Component

private struct CategoryRowView: View {
    private static let percentFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .percent
        f.maximumFractionDigits = 1
        return f
    }()

    @Environment(AppPreferences.self) private var appPreferences

    let summary: CategorySpendingSummary
    let maxAmount: Double
    let currencyCode: String
    var showVariation: Bool = true

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            // Icon Circle
            ZStack {
                Circle()
                    .fill(Color(hex: summary.category.colorHex))
                    .frame(width: 40, height: 40)

                Image(systemName: summary.category.iconName ?? "tag.fill")
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.white)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                // Name and Amount
                HStack {
                    Text(summary.category.name)
                        .font(DS.Typography.headline)
                        .foregroundStyle(.primary)

                    Spacer()

                    Text(appPreferences.currency(summary.amount, currencyCode: currencyCode))
                        .font(DS.Typography.headline)
                        .foregroundStyle(.primary)
                }

                // Bar and Percentage
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    // Percentage Text + Variation Chip (inline, chip aligned right)
                    HStack(spacing: DS.Spacing.sm) {
                        Text("\(formattedPercentage(summary.percentage)) \(L10n.Statistics.ofExpense)")
                            .font(DS.Typography.captionSmall)
                            .foregroundStyle(.secondary)

                        Spacer()

                        // Variation chip (aligned to right) - only show when showVariation is true
                        if showVariation {
                            VariationChip(variation: summary.variation, size: .small, showNAWhenNil: true)
                        }
                    }

                    // Bar
                    GeometryReader { geo in
                        let width =
                            maxAmount > 0 ? (summary.amount / maxAmount) * geo.size.width : 0

                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(DS.Semantic.neutralBackground)
                                .frame(height: 6)

                            Capsule()
                                .fill(Color(hex: summary.category.colorHex))
                                .frame(width: width, height: 6)
                        }
                    }
                    .frame(height: 6)
                }
            }
        }
    }

    private func formattedPercentage(_ value: Double) -> String {
        Self.percentFormatter.string(from: NSNumber(value: value / 100.0)) ?? "0%"
    }
}

// MARK: - Subcategory Row Component

private struct SubcategoryRowView: View {
    private static let percentFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .percent
        f.maximumFractionDigits = 1
        return f
    }()

    @Environment(AppPreferences.self) private var appPreferences

    let summary: SubcategorySpendingSummary
    let maxAmount: Double
    let currencyCode: String
    var showVariation: Bool = true

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            // Icon Circle
            ZStack {
                Circle()
                    .fill(Color(hex: summary.colorHex ?? AppConstants.defaultColorHex))
                    .frame(width: 40, height: 40)

                if let subcategory = summary.subcategory {
                    Image(systemName: subcategory.iconName ?? "list.bullet.indent")
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.white)
                        .accessibilityHidden(true)
                } else {
                    Image(systemName: "list.bullet.indent")
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.white)
                        .accessibilityHidden(true)
                }
            }

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                // Name and Amount
                HStack {
                    Text(summary.subcategoryName)
                        .font(DS.Typography.headline)
                        .foregroundStyle(.primary)

                    Spacer()

                    Text(appPreferences.currency(summary.amount, currencyCode: currencyCode))
                        .font(DS.Typography.headline)
                        .foregroundStyle(.primary)
                }

                // Bar and Percentage
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    // Percentage Text + Variation Chip (inline, chip aligned right)
                    HStack(spacing: DS.Spacing.sm) {
                        Text("\(formattedPercentage(summary.percentageOfTotal)) \(L10n.Statistics.ofExpense)")
                            .font(DS.Typography.captionSmall)
                            .foregroundStyle(.secondary)

                        Spacer()

                        // Variation chip (aligned to right) - only show when showVariation is true
                        if showVariation {
                            VariationChip(variation: summary.variation, size: .small, showNAWhenNil: true)
                        }
                    }

                    // Bar
                    GeometryReader { geo in
                        let width =
                            maxAmount > 0 ? (summary.amount / maxAmount) * geo.size.width : 0

                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(DS.Semantic.neutralBackground)
                                .frame(height: 6)

                            Capsule()
                                .fill(Color(hex: summary.colorHex ?? AppConstants.defaultColorHex))
                                .frame(width: width, height: 6)
                        }
                    }
                    .frame(height: 6)
                }
            }
        }
    }

    private func formattedPercentage(_ value: Double) -> String {
        Self.percentFormatter.string(from: NSNumber(value: value / 100.0)) ?? "0%"
    }
}
