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
    @Environment(SessionState.self) private var sessionState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Data Queries

    @Query(sort: \Account.name, order: .forward) private var accounts: [Account]
    @Query(sort: \Category.name, order: .forward) private var categories: [Category]
    @Query(sort: \Subcategory.name, order: .forward) private var allSubcategories: [Subcategory]
    @Query(sort: \Tag.name, order: .forward) private var tags: [Tag]
    @Query(sort: \TransactionItem.date, order: .reverse) private var allTransactions:
        [TransactionItem]

    // MARK: - External Dependencies

    @Bindable var viewModel: StatisticsViewModel
    let defaultCurrencyCode: String
    let onNavigateToRecords: () -> Void

    // MARK: - State

    @State private var categorySpending: [CategorySpendingSummary] = []
    @State private var subcategorySpending: [SubcategorySpendingSummary] = []
    @State private var tagSpending: [TagSpendingSummary] = []
    @State private var natureTrendPoints: [NatureTrendPoint] = []
    @State private var selectedCategoryID: PersistentIdentifier?
    @State private var selectedSubcategoryID: PersistentIdentifier?
    @State private var selectedTagID: PersistentIdentifier?
    @State private var selectedNature: SubcategoryNature?
    @State private var chartsCarouselPosition: String? = "category"
    @State private var listViewType: ListViewType = .categories
    @State private var isListExpanded: Bool = false
    @State private var isSubcategoriesAutomatic: Bool = false  // Track if switch was automatic
    @State private var showCustomPeriodPicker: Bool = false  // Custom period picker sheet
    @State private var isSyncingFilters: Bool = false  // Anti-loop flag for sync functions
    @Namespace private var listSelectorNamespace
    @Namespace private var comparisonSelectorNamespace

    // Period Comparison State (comparisonMode is in SessionState for sync across tabs)
    @State private var previousCategoryTotal: Double? = nil
    @State private var previousSubcategoryTotal: Double? = nil
    @State private var previousTagTotal: Double? = nil
    @State private var previousNatureTotal: Double? = nil
    @State private var previousNatureAmounts: [SubcategoryNature: Double] = [:]

    // Nature Carousel State
    @State private var natureCarouselIndex: Int? = 0

    /// Effective category ID combining local selection and SessionState sync
    private var effectiveCategoryID: PersistentIdentifier? {
        selectedCategoryID ?? viewModel.selectedCategories.first
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

    /// Check if income-only filter is active (nature carousel not applicable)
    private var isIncomeMode: Bool {
        viewModel.selectedTransactionNatures == [.income]
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: DS.Spacing.xl) {
                controlBar
                spendingAnalysisHeader
                chartsCarousel
                // Nature carousel only shows for expenses (nature classification doesn't apply to income)
                if !isIncomeMode {
                    natureCarousel
                }
                categoriesListSection
                recentRecordsSection
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.top, DS.Spacing.sm)
            .yalaSafeBottomPadding()
        }
        .onAppear {
            // Sync local selection state from viewModel filters (may come from SessionState)
            syncCategoryFilterToSelection()
            syncSubcategoryFilterToSelection()
            calculateData()
        }
        .onChange(of: viewModel.detailPeriod) {
            calculateData()
        }
        .onChange(of: viewModel.selectedAccounts) {
            calculateData()
        }
        .onChange(of: viewModel.selectedCategories) {
            calculateData()
            syncCategoryFilterToSelection()
        }
        .onChange(of: viewModel.selectedSubcategories) {
            calculateData()
            syncSubcategoryFilterToSelection()
        }
        .onChange(of: viewModel.selectedTags) {
            syncTagFilterToSelection()
            calculateData()
        }
        .onChange(of: viewModel.selectedNatures) {
            calculateData()
            syncNatureFilterToSelection()
        }
        .onChange(of: viewModel.selectedTransactionNatures) {
            calculateData()
        }
        .onChange(of: allSubcategories) {
            // Recalculate when subcategories change (nature edited, etc.)
            calculateData()
        }
        .onChange(of: selectedCategoryID) {
            syncSelectionToCategoryFilter()
            calculateData()
        }
        .onChange(of: selectedSubcategoryID) {
            syncSelectionToSubcategoryFilter()
            calculateData()
        }
        .onChange(of: selectedTagID) {
            syncSelectionToTagFilter()
            calculateData()
        }
        .onChange(of: selectedNature) {
            syncSelectionToNatureFilter()
            calculateData()
        }
        .onChange(of: sessionState.customDateRange) {
            // Sync custom date range and recalculate
            viewModel.syncCustomRangeFromSessionState(sessionState)
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
        let start = sortedDates.first ?? Date()
        let end = sortedDates.last ?? Date()
        return (start, end)
    }

    // MARK: - Control Bar

    private var controlBar: some View {
        HStack(spacing: DS.Spacing.md) {
            periodSelector

            if hasActiveFilters {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DS.Spacing.sm) {
                        // Account chips (with icon)
                        ForEach(selectedAccountChips, id: \.id) { chip in
                            FilterChipView(
                                accountName: chip.name,
                                count: chip.count,
                                onClear: {
                                    viewModel.selectedAccounts.removeAll()
                                }
                            )
                        }

                        // Category chip - show when category selected from pie or via filter
                        if let catChip = aggregatedCategoryChip(
                            selectedSubcategories: viewModel.selectedSubcategories,
                            allSubcategories: allSubcategories
                        ) {
                            // Chip from subcategory filter (shows parent category)
                            FilterChipView(
                                categoryName: catChip.name,
                                iconName: catChip.iconName,
                                colorHex: catChip.colorHex,
                                count: catChip.count,
                                onClear: {
                                    viewModel.selectedCategories.removeAll()
                                    viewModel.selectedSubcategories.removeAll()
                                    selectedCategoryID = nil
                                }
                            )
                        } else if let categoryID = selectedCategoryID,
                                  let category = categories.first(where: { $0.persistentModelID == categoryID }) {
                            // Chip from direct category selection (pie chart)
                            FilterChipView(
                                categoryName: category.name,
                                iconName: category.iconName,
                                colorHex: category.colorHex,
                                count: 1,
                                onClear: {
                                    viewModel.selectedCategories.removeAll()
                                    selectedCategoryID = nil
                                }
                            )
                        } else if !viewModel.selectedCategories.isEmpty {
                            // Chip from external filter (SessionState sync)
                            let selectedCats = categories.filter { viewModel.selectedCategories.contains($0.persistentModelID) }
                            if let firstCat = selectedCats.first {
                                FilterChipView(
                                    categoryName: firstCat.name,
                                    iconName: firstCat.iconName,
                                    colorHex: firstCat.colorHex,
                                    count: selectedCats.count,
                                    onClear: {
                                        viewModel.selectedCategories.removeAll()
                                        selectedCategoryID = nil
                                    }
                                )
                            }
                        }

                        // Subcategory chip - show when subcategory selected from pie or via filter
                        if let subChip = aggregatedSubcategoryChip(
                            selectedSubcategories: viewModel.selectedSubcategories,
                            allSubcategories: allSubcategories
                        ) {
                            // Chip from subcategory filter
                            FilterChipView(
                                subcategoryName: subChip.name,
                                iconName: subChip.iconName,
                                colorHex: subChip.colorHex,
                                count: subChip.count,
                                onClear: {
                                    viewModel.selectedSubcategories.removeAll()
                                    selectedSubcategoryID = nil
                                }
                            )
                        } else if let subcategoryID = selectedSubcategoryID,
                                  let subcategory = subcategorySpending.first(where: { $0.persistentID == subcategoryID })?.subcategory {
                            // Chip from direct subcategory selection (pie chart)
                            FilterChipView(
                                subcategoryName: subcategory.name,
                                iconName: subcategory.iconName,
                                colorHex: subcategory.colorHex,
                                count: 1,
                                onClear: {
                                    viewModel.selectedSubcategories.removeAll()
                                    selectedSubcategoryID = nil
                                }
                            )
                        }

                        // Tag chips (individual with color dots)
                        ForEach(selectedTagChips, id: \.id) { chip in
                            FilterChipView(
                                tagName: chip.name,
                                iconName: chip.iconName,
                                colorHex: chip.colorHex,
                                onClear: {
                                    viewModel.selectedTags.remove(chip.tagID)
                                }
                            )
                        }

                        // Nature chips (individual with color dots)
                        ForEach(Array(viewModel.selectedNatures), id: \.rawValue) { nature in
                            FilterChipView(
                                nature: nature,
                                onClear: {
                                    viewModel.selectedNatures.remove(nature)
                                }
                            )
                        }

                        // Transaction nature chip (income/expense with color dot)
                        // Only show when exactly 1 selected
                        if viewModel.selectedTransactionNatures.count == 1,
                            let nature = viewModel.selectedTransactionNatures.first
                        {
                            FilterChipView(
                                transactionNature: nature,
                                onClear: {
                                    viewModel.selectedTransactionNatures.removeAll()
                                    sessionState.selectedTransactionNatures.removeAll()
                                }
                            )
                        }

                        // Currency chips
                        ForEach(Array(viewModel.selectedCurrencies), id: \.self) { currency in
                            FilterChipView(
                                currencyCode: currency.rawValue,
                                onClear: {
                                    viewModel.selectedCurrencies.remove(currency)
                                    sessionState.selectedCurrencies.remove(currency)
                                }
                            )
                        }

                        // Amount chip
                        if viewModel.amountCondition.isActive {
                            FilterChipView(
                                amountText: viewModel.amountCondition.displayText,
                                onClear: {
                                    viewModel.amountCondition = .any
                                    sessionState.amountCondition = .any
                                }
                            )
                        }

                        // Search/Note chip
                        if !viewModel.searchText.isEmpty {
                            FilterChipView(
                                noteText: viewModel.searchText,
                                onClear: {
                                    viewModel.searchText = ""
                                    sessionState.searchText = ""
                                }
                            )
                        }

                        // Clear all button
                        if activeFilterCount > 1 {
                            Button {
                                withAnimation {
                                    clearAllFilters()
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            Spacer()
        }
        .animation(nil, value: viewModel.detailPeriod)
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
                .font(.headline)
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

    /// Determines if comparison selector should be visible
    private var showComparisonSelector: Bool {
        PreviousPeriodHelper.isSelectorVisible(for: viewModel.detailPeriod)
    }

    /// Comparison mode selector (M/A toggle)
    private var comparisonModeSelector: some View {
        HStack(spacing: 0) {
            ForEach(ComparisonMode.allCases) { mode in
                comparisonSelectorButton(for: mode)
            }
        }
        .padding(DS.Spacing.xxs)
        .background(Color.yalaSecondaryText.opacity(0.08))
        .clipShape(Capsule())
    }

    private func comparisonSelectorButton(for mode: ComparisonMode) -> some View {
        let isSelected = sessionState.comparisonMode == mode

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                sessionState.comparisonMode = mode
            }
        } label: {
            Text(mode.shortName)
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .foregroundStyle(isSelected ? .white : Color.yalaSecondaryText)
                .background(
                    Group {
                        if isSelected {
                            Capsule()
                                .fill(Color.electricIndigo)
                                .matchedGeometryEffect(
                                    id: "comparisonSelector", in: comparisonSelectorNamespace)
                        }
                    }
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Charts Carousel

    /// Number of pages in carousel (2 when income mode, 3 otherwise)
    private var carouselPageCount: Int {
        isIncomeMode ? 2 : 3
    }

    private var chartsCarousel: some View {
        VStack(spacing: DS.Spacing.sm) {
            GeometryReader { geo in
                let totalWidth = geo.size.width
                let spacing: CGFloat = DS.Spacing.md
                let cardWidth = totalWidth

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: spacing) {
                        // Categories Chart - hidden in income mode
                        if !isIncomeMode {
                            categoryChartCard
                                .frame(width: cardWidth)
                                .id("category")
                        }

                        // Subcategories Chart
                        subcategoryChartCard
                            .frame(width: cardWidth)
                            .id("subcategory")

                        // Tags Chart
                        tagChartCard
                            .frame(width: cardWidth)
                            .id("tags")
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: $chartsCarouselPosition)
                .frame(width: totalWidth)
            }
            .frame(height: 340)

            // Page indicator - dynamic count based on income mode
            HStack(spacing: DS.Spacing.sm) {
                ForEach(0..<carouselPageCount, id: \.self) { page in
                    let pageId = carouselPageIds[page]
                    Circle()
                        .fill(
                            chartsCarouselPosition == pageId
                                ? Color.yalaPrimaryText.opacity(0.3)
                                : Color.yalaSecondaryText.opacity(0.2)
                        )
                        .frame(width: 6, height: 6)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    /// IDs for carousel pages based on income mode
    private var carouselPageIds: [String] {
        isIncomeMode ? ["subcategory", "tags"] : ["category", "subcategory", "tags"]
    }

    // MARK: - Category Chart Card

    private var categoryChartCard: some View {
        VStack(alignment: .leading, spacing: 0) {
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
                    selectedCategoryID: effectiveCategoryID,
                    onSelectCategory: { categoryID in
                        if effectiveCategoryID == categoryID {
                            selectedCategoryID = nil
                            viewModel.selectedCategories.removeAll()
                        } else {
                            selectedCategoryID = categoryID
                            viewModel.selectedCategories = [categoryID]
                        }
                    },
                    size: .large,
                    period: viewModel.detailPeriod,
                    customRange: sessionState.customDateRange,
                    previousTotalAmount: previousCategoryTotal,
                    comparisonMode: sessionState.comparisonMode,
                    showVariationHeader: viewModel.detailPeriod != .allTime
                )
            }
        }
        .background(Color.yalaCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .stroke(DS.Colors.borderSubtle, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(DS.Opacity.faint), radius: 10, x: 0, y: 5)
    }

    // MARK: - Subcategory Chart Card

    private var subcategoryChartCard: some View {
        VStack(alignment: .leading, spacing: 0) {
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
                    selectedSubcategoryIDs: selectedSubcategoryID.map { Set([$0]) } ?? [],
                    onSelectSubcategory: { subcategoryID in
                        if selectedSubcategoryID == subcategoryID {
                            selectedSubcategoryID = nil
                        } else {
                            selectedSubcategoryID = subcategoryID
                        }
                    },
                    size: .large,
                    period: viewModel.detailPeriod,
                    customRange: sessionState.customDateRange,
                    previousTotalAmount: previousSubcategoryTotal,
                    comparisonMode: sessionState.comparisonMode,
                    showVariationHeader: viewModel.detailPeriod != .allTime
                )
            }
        }
        .background(Color.yalaCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .stroke(DS.Colors.borderSubtle, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(DS.Opacity.faint), radius: 10, x: 0, y: 5)
    }

    // MARK: - Tag Chart Card

    private var tagChartCard: some View {
        VStack(alignment: .leading, spacing: 0) {
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
                    selectedTagID: selectedTagID,
                    onSelectTag: { tagID in
                        if selectedTagID == tagID {
                            selectedTagID = nil
                        } else {
                            selectedTagID = tagID
                        }
                    },
                    size: .large,
                    period: viewModel.detailPeriod,
                    customRange: sessionState.customDateRange,
                    previousTotalAmount: previousTagTotal,
                    comparisonMode: sessionState.comparisonMode,
                    showVariationHeader: viewModel.detailPeriod != .allTime
                )
            }
        }
        .background(Color.yalaCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .stroke(DS.Colors.borderSubtle, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(DS.Opacity.faint), radius: 10, x: 0, y: 5)
    }

    // MARK: - Nature Carousel

    /// Count of natures with data (for dynamic height calculation)
    private var visibleNatureCount: Int {
        guard !natureTrendPoints.isEmpty else { return 3 }
        let essentialTotal = natureTrendPoints.reduce(0) { $0 + $1.essential }
        let priorityTotal = natureTrendPoints.reduce(0) { $0 + $1.priority }
        let optionalTotal = natureTrendPoints.reduce(0) { $0 + $1.optional }
        let unclassifiedTotal = natureTrendPoints.reduce(0) { $0 + $1.unclassified }

        var count = 0
        if essentialTotal > 0 { count += 1 }
        if priorityTotal > 0 { count += 1 }
        if optionalTotal > 0 { count += 1 }
        if unclassifiedTotal > 0 { count += 1 }
        return max(count, 3)  // Always show at least 3 bars
    }

    /// Dynamic height based on current carousel page and visible natures
    private var natureCarouselHeight: CGFloat {
        if (natureCarouselIndex ?? 0) == 0 {
            return 340  // Large chart view
        } else {
            // Compact view: dynamic height based on number of visible natures
            // Each bar ~52 points (row + progress + spacing) + container padding (~56)
            let barHeight: CGFloat = 52
            let containerPadding: CGFloat = 56
            return CGFloat(visibleNatureCount) * barHeight + containerPadding
        }
    }

    private var natureCarousel: some View {
        VStack(spacing: DS.Spacing.sm) {
            GeometryReader { geo in
                let totalWidth = geo.size.width
                let spacing: CGFloat = DS.Spacing.md
                let cardWidth = totalWidth

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: spacing) {
                        // Slide 1: Large (Chart + Legend)
                        natureWidgetLarge
                            .frame(width: cardWidth)
                            .id(0)

                        // Slide 2: Medium (Compact Bars)
                        natureWidgetCompact 
                            .frame(width: cardWidth)
                            .id(1)
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: $natureCarouselIndex)
                .frame(width: totalWidth)
            }
            .frame(height: natureCarouselHeight)
            .dsAnimation(.easeInOut(duration: 0.3), value: natureCarouselIndex, reduceMotion: reduceMotion)

            // Page indicator
            HStack(spacing: DS.Spacing.sm) {
                ForEach(0..<2, id: \.self) { page in
                    Circle()
                        .fill(
                            page == (natureCarouselIndex ?? 0)
                                ? Color.yalaPrimaryText.opacity(0.3)
                                : Color.yalaSecondaryText.opacity(0.2)
                        )
                        .frame(width: 6, height: 6)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var natureWidgetLarge: some View {
        NatureTrendWidget(
            trendPoints: natureTrendPoints,
            selectedNature: selectedNature,
            currencyCode: defaultCurrencyCode,
            size: .large,
            grouping: natureGrouping,
            interval: viewModel.panelDateInterval,
            onSelectNature: { nature in
                withAnimation(.easeInOut(duration: 0.2)) {
                    if selectedNature == nature {
                        selectedNature = nil
                    } else {
                        selectedNature = nature
                    }
                }
            },
            onShowDetail: nil,
            period: viewModel.detailPeriod,
            previousTotalAmount: previousNatureTotal,
            previousAmountByNature: previousNatureAmounts,
            showVariationHeader: viewModel.detailPeriod != .allTime,
            comparisonMode: sessionState.comparisonMode,
            isIncomeMode: viewModel.selectedTransactionNatures == [.income]
        )
    }

    private var natureWidgetCompact: some View {
        NatureTrendWidget(
            trendPoints: natureTrendPoints,
            selectedNature: selectedNature,
            currencyCode: defaultCurrencyCode,
            size: .medium,
            grouping: natureGrouping,
            interval: viewModel.panelDateInterval,
            onSelectNature: { nature in
                withAnimation(.easeInOut(duration: 0.2)) {
                    if selectedNature == nature {
                        selectedNature = nil
                    } else {
                        selectedNature = nature
                    }
                }
            },
            onShowDetail: nil,
            period: viewModel.detailPeriod,
            previousTotalAmount: previousNatureTotal,
            previousAmountByNature: previousNatureAmounts,
            showVariationHeader: viewModel.detailPeriod != .allTime,
            comparisonMode: sessionState.comparisonMode,
            isIncomeMode: viewModel.selectedTransactionNatures == [.income]
        )
    }

    /// Determine grouping for nature widget based on selected period
    /// Matches PanelViewModel logic for consistent bar chart grouping
    private var natureGrouping: TrendGrouping {
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
        VStack(alignment: .leading, spacing: 0) {
            // Header with title and selector
            HStack(alignment: .center) {
                Text(
                    listViewType == .categories
                        ? L10n.Statistics.topCategories : L10n.Statistics.topSubcategories
                )
                .font(.headline)
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
                        selectedCategoryID: effectiveCategoryID,
                        isExpanded: isListExpanded,
                        showVariation: viewModel.detailPeriod != .allTime,
                        onToggleExpanded: { isListExpanded.toggle() },
                        onSelectCategory: { categoryID in
                            if effectiveCategoryID == categoryID {
                                selectedCategoryID = nil
                                viewModel.selectedCategories.removeAll()
                            } else {
                                selectedCategoryID = categoryID
                                viewModel.selectedCategories = [categoryID]
                            }
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
                        selectedCategoryID: effectiveCategoryID,
                        selectedSubcategoryID: selectedSubcategoryID,
                        isExpanded: isListExpanded,
                        showVariation: viewModel.detailPeriod != .allTime,
                        onToggleExpanded: { isListExpanded.toggle() },
                        onSelectSubcategory: { subcategoryID in
                            if selectedSubcategoryID == subcategoryID {
                                selectedSubcategoryID = nil
                            } else {
                                selectedSubcategoryID = subcategoryID
                            }
                        }
                    )
                }
            }
        }
        .background(Color.yalaCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .stroke(DS.Colors.borderSubtle, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(DS.Opacity.faint), radius: 10, x: 0, y: 5)
    }

    private var listViewSelector: some View {
        HStack(spacing: 0) {
            ForEach(ListViewType.allCases) { viewType in
                listViewButton(for: viewType)
            }
        }
        .padding(DS.Spacing.xxs)
        .background(Color.yalaSecondaryText.opacity(0.08))
        .clipShape(Capsule())
    }

    private func listViewButton(for viewType: ListViewType) -> some View {
        let isSelected = listViewType == viewType
        let isLocked = shouldLockToSubcategories

        return Button {
            // Only allow change if not locked to subcategories
            // OR if trying to switch to subcategories (always allowed)
            guard !isLocked || viewType == .subcategories else { return }

            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                setListViewManually(viewType)
            }
        } label: {
            Image(systemName: viewType.iconName)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, DS.Spacing.sm)
                .foregroundStyle(isSelected ? .white : Color.yalaSecondaryText)
                .background(
                    Group {
                        if isSelected {
                            Capsule()
                                .fill(Color.electricIndigo)
                                .matchedGeometryEffect(
                                    id: "listSelector", in: listSelectorNamespace)
                        }
                    }
                )
        }
        .buttonStyle(.plain)
        .opacity((isLocked && viewType == .categories) ? 0.4 : 1.0)  // Dim locked button
        .disabled(isLocked && viewType == .categories)  // Disable locked button
    }

    // MARK: - List View Auto-switching Logic

    /// Determines if list view should be locked to subcategories
    /// - When a category filter is applied (show only subcategories of that category)
    /// - When income mode is active (category breakdown not useful for income)
    private var shouldLockToSubcategories: Bool {
        !viewModel.selectedCategories.isEmpty || isIncomeMode
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
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(DS.Card.padding)
    }

    // MARK: - Data Calculation

    private func calculateData() {
        let interval = viewModel.panelDateInterval

        // Build filter criteria for pie charts (WITHOUT category/subcategory filter - show all with dim)
        let pieChartCriteria = FilterCriteria(
            selectedAccounts: viewModel.selectedAccounts,
            selectedCategories: [],  // Don't filter by category - show all in pie with dim
            selectedSubcategories: [],  // Don't filter by subcategory - show all in pie with dim
            selectedTags: viewModel.selectedTags,
            selectedNatures: viewModel.selectedNatures,
            selectedTransactionNatures: viewModel.selectedTransactionNatures,
            selectedCurrencies: viewModel.selectedCurrencies,
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

        // Create criteria for nature widget (respects cat/subcat filters, but NOT nature filter - show all with dim)
        let natureCriteria = FilterCriteria(
            selectedAccounts: viewModel.selectedAccounts,
            selectedCategories: viewModel.selectedCategories,
            selectedSubcategories: viewModel.selectedSubcategories,
            selectedTags: viewModel.selectedTags,
            selectedNatures: [],  // Don't filter by nature - show all with dim
            selectedTransactionNatures: viewModel.selectedTransactionNatures,
            selectedCurrencies: viewModel.selectedCurrencies,
            transactionTypeFilter: .all,
            amountCondition: viewModel.amountCondition,
            searchText: viewModel.searchText,
            dateInterval: interval
        )

        // Filter transactions for nature widget
        let natureFiltered = FilterService.filterForTrends(
            transactions: allTransactions,
            accounts: accounts,
            criteria: natureCriteria
        )

        // Calculate category spending (show ALL categories, dim applied in widget)
        // Pass transactionNatures filter - empty means show expenses only (default)
        let naturesFilter: Set<TransactionNature>? = viewModel.selectedTransactionNatures.isEmpty
            ? nil  // Default: expense only
            : viewModel.selectedTransactionNatures

        categorySpending = TopSpendingCategoriesCalculator.calculateTopSpending(
            transactions: pieFiltered,
            interval: interval,
            currencyCode: defaultCurrencyCode,
            transactionNatures: naturesFilter,
            context: modelContext
        )

        // Calculate subcategory spending - filter by category if one is selected
        let subcategoryTransactions: [TransactionItem]
        if let categoryID = effectiveCategoryID {
            // Filter to only show subcategories of selected category
            subcategoryTransactions = pieFiltered.filter { $0.category?.persistentModelID == categoryID }
        } else {
            subcategoryTransactions = pieFiltered
        }

        subcategorySpending = TopSubcategoriesCalculator.calculateTopSubcategories(
            transactions: subcategoryTransactions,
            interval: interval,
            currencyCode: defaultCurrencyCode,
            categoryFilter: nil,
            transactionNatures: naturesFilter,
            context: modelContext
        )

        // Calculate tag spending (show ALL tags, dim applied in widget)
        tagSpending = TagSpendingCalculator.calculateTopSpending(
            transactions: pieFiltered,
            interval: interval,
            currencyCode: defaultCurrencyCode,
            transactionNatures: naturesFilter
        )

        // Calculate nature trend data with correct grouping based on period
        // Uses natureFiltered (no nature filter) so selection = visual dim, not data filter
        let preferredCurrency = CurrencyCode(rawValue: defaultCurrencyCode) ?? .pen
        natureTrendPoints = NatureTrendHelper.calculateTrend(
            transactions: natureFiltered,
            grouping: natureGrouping,
            interval: interval,
            preferredCurrency: preferredCurrency,
            context: modelContext
        )

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
            previousNatureTotal = nil
            previousNatureAmounts = [:]
            return
        }

        // Get previous period interval based on comparison mode
        let previousInterval = PreviousPeriodHelper.previousInterval(
            for: viewModel.detailPeriod,
            mode: sessionState.comparisonMode,
            customRange: sessionState.customDateRange
        )

        // Build filter criteria for previous period (WITHOUT category filter - compare all)
        let criteria = FilterCriteria(
            selectedAccounts: viewModel.selectedAccounts,
            selectedCategories: [],  // Don't filter by category for comparison
            selectedSubcategories: [],  // Don't filter by subcategory for comparison
            selectedTags: viewModel.selectedTags,
            selectedNatures: viewModel.selectedNatures,
            selectedTransactionNatures: viewModel.selectedTransactionNatures,
            selectedCurrencies: viewModel.selectedCurrencies,
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
        // Use same nature filter as current period for consistent comparison
        let naturesFilter: Set<TransactionNature>? = viewModel.selectedTransactionNatures.isEmpty
            ? nil
            : viewModel.selectedTransactionNatures

        let previousCategorySpending = TopSpendingCategoriesCalculator.calculateTopSpending(
            transactions: previousFiltered,
            interval: previousInterval,
            currencyCode: defaultCurrencyCode,
            transactionNatures: naturesFilter,
            context: modelContext
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
        if let categoryID = effectiveCategoryID {
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
            context: modelContext
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

        // Calculate previous period tag spending
        let previousTagSpending = TagSpendingCalculator.calculateTopSpending(
            transactions: previousFiltered,
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

        // Calculate previous period nature trend data
        // Use separate criteria WITHOUT nature filter for consistent comparison
        let prevNatureCriteria = FilterCriteria(
            selectedAccounts: viewModel.selectedAccounts,
            selectedCategories: [],
            selectedSubcategories: [],
            selectedTags: viewModel.selectedTags,
            selectedNatures: [],  // Don't filter by nature
            selectedTransactionNatures: viewModel.selectedTransactionNatures,
            selectedCurrencies: viewModel.selectedCurrencies,
            transactionTypeFilter: .all,
            amountCondition: viewModel.amountCondition,
            searchText: viewModel.searchText,
            dateInterval: previousInterval
        )
        let prevNatureFiltered = FilterService.filterForTrends(
            transactions: allTransactions,
            accounts: accounts,
            criteria: prevNatureCriteria
        )

        let preferredCurrency = CurrencyCode(rawValue: defaultCurrencyCode) ?? .pen
        let previousNaturePoints = NatureTrendHelper.calculateTrend(
            transactions: prevNatureFiltered,
            grouping: natureGrouping,
            interval: previousInterval,
            preferredCurrency: preferredCurrency,
            context: modelContext
        )

        // Calculate totals by nature for previous period
        var prevNatureAmounts: [SubcategoryNature: Double] = [:]
        var prevNatureTotal: Double = 0
        for point in previousNaturePoints {
            prevNatureAmounts[.essential, default: 0] += point.essential
            prevNatureAmounts[.priority, default: 0] += point.priority
            prevNatureAmounts[.optional, default: 0] += point.optional
            prevNatureAmounts[.unclassified, default: 0] += point.unclassified
            prevNatureTotal += point.total
        }
        previousNatureAmounts = prevNatureAmounts
        previousNatureTotal = prevNatureTotal > 0 ? prevNatureTotal : nil

        // Handle case where there's no data in previous period
        if previousCategoryTotal == 0 { previousCategoryTotal = nil }
        if previousSubcategoryTotal == 0 { previousSubcategoryTotal = nil }
        if previousTagTotal == 0 { previousTagTotal = nil }
    }

    // MARK: - Filter Synchronization

    /// Sync chart selection to ViewModel filters (chart -> top filters)
    private func syncSelectionToCategoryFilter() {
        guard !isSyncingFilters else { return }
        isSyncingFilters = true
        defer { isSyncingFilters = false }

        if let categoryID = selectedCategoryID {
            // Add to ViewModel's selected categories if not already there
            if !viewModel.selectedCategories.contains(categoryID) {
                viewModel.selectedCategories.insert(categoryID)
            }
            // Clear subcategory selection when category changes
            selectedSubcategoryID = nil
            viewModel.selectedSubcategories.removeAll()
        } else {
            // If deselected, remove from ViewModel
            // But only if it was the only one selected
            if viewModel.selectedCategories.count == 1 {
                viewModel.selectedCategories.removeAll()
            }
        }
    }

    private func syncSelectionToSubcategoryFilter() {
        guard !isSyncingFilters else { return }
        isSyncingFilters = true
        defer { isSyncingFilters = false }

        if let subcategoryID = selectedSubcategoryID {
            // Find the subcategory by persistentID
            if let subcategory = subcategorySpending.first(where: { $0.persistentID == subcategoryID })?
                .subcategory
            {
                if !viewModel.selectedSubcategories.contains(subcategory.persistentModelID) {
                    viewModel.selectedSubcategories.insert(subcategory.persistentModelID)
                }
                // Also ensure parent category is selected
                let parentCategory = subcategory.category
                if !viewModel.selectedCategories.contains(parentCategory.persistentModelID) {
                    viewModel.selectedCategories.insert(parentCategory.persistentModelID)
                }
                selectedCategoryID = parentCategory.persistentModelID
            }
        } else {
            // If deselected subcategory, remove from ViewModel
            if viewModel.selectedSubcategories.count == 1 {
                viewModel.selectedSubcategories.removeAll()
            }
        }
    }

    private func syncSelectionToTagFilter() {
        guard !isSyncingFilters else { return }
        isSyncingFilters = true
        defer { isSyncingFilters = false }

        if let tagID = selectedTagID {
            if !viewModel.selectedTags.contains(tagID) {
                viewModel.selectedTags.insert(tagID)
            }
        } else {
            if viewModel.selectedTags.count == 1 {
                viewModel.selectedTags.removeAll()
            }
        }
    }

    /// Sync ViewModel filters to chart selection (top filters -> chart)
    private func syncCategoryFilterToSelection() {
        guard !isSyncingFilters else { return }
        isSyncingFilters = true
        defer { isSyncingFilters = false }

        if viewModel.selectedCategories.count == 1 {
            selectedCategoryID = viewModel.selectedCategories.first
        } else if viewModel.selectedCategories.isEmpty {
            selectedCategoryID = nil
        }
    }

    private func syncSubcategoryFilterToSelection() {
        guard !isSyncingFilters else { return }
        isSyncingFilters = true
        defer { isSyncingFilters = false }

        if viewModel.selectedSubcategories.count == 1 {
            // Find the subcategory name from the ID
            if let subcategoryID = viewModel.selectedSubcategories.first,
                let subcategory = subcategorySpending.first(where: {
                    $0.subcategory?.persistentModelID == subcategoryID
                })
            {
                selectedSubcategoryID = subcategory.persistentID
            }
        } else if viewModel.selectedSubcategories.isEmpty {
            selectedSubcategoryID = nil
        }
    }

    private func syncSelectionToNatureFilter() {
        guard !isSyncingFilters else { return }
        isSyncingFilters = true
        defer { isSyncingFilters = false }

        if let nature = selectedNature {
            // Replace all selected natures with the new one (single selection)
            viewModel.selectedNatures = [nature]
        } else {
            // Clear all when deselected
            viewModel.selectedNatures.removeAll()
        }
    }

    private func syncNatureFilterToSelection() {
        guard !isSyncingFilters else { return }
        isSyncingFilters = true
        defer { isSyncingFilters = false }

        if viewModel.selectedNatures.count == 1 {
            selectedNature = viewModel.selectedNatures.first
        } else if viewModel.selectedNatures.isEmpty {
            selectedNature = nil
        }
    }

    private func syncTagFilterToSelection() {
        guard !isSyncingFilters else { return }
        isSyncingFilters = true
        defer { isSyncingFilters = false }

        if viewModel.selectedTags.count == 1 {
            selectedTagID = viewModel.selectedTags.first
        } else if viewModel.selectedTags.isEmpty {
            selectedTagID = nil
        }
    }

    // MARK: - Recent Records Section

    private var recentRecordsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text(L10n.Statistics.latestRecords)
                .font(.headline)
                .foregroundStyle(Color.yalaPrimaryText)

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
                        .font(.subheadline.weight(.semibold))
                    Image(systemName: "chevron.right")
                        .font(.caption)
                    Spacer()
                }
                .padding(.vertical, DS.Spacing.md)
                .foregroundStyle(Color.electricIndigo)
                .background(Color.electricIndigo.opacity(DS.Opacity.subtle))
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(DS.Card.padding)
        .background(Color.yalaCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .stroke(DS.Colors.borderSubtle, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(DS.Opacity.faint), radius: 10, x: 0, y: 5)
    }

    private var emptyRecordsState: some View {
        VStack(spacing: DS.Spacing.sm) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.title2)
                .foregroundStyle(.tertiary)
            Text(L10n.Statistics.noRecords)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.xl)
    }

    private func clearAllFilters() {
        viewModel.clearFilters()
        selectedCategoryID = nil
        selectedSubcategoryID = nil
        selectedNature = nil
    }

    // MARK: - Chip Data Structures

    private struct CategoryChip: Identifiable {
        let id = UUID()
        let categoryID: PersistentIdentifier
    }

    private struct SubcategoryChip: Identifiable {
        let id: String
        let name: String
        let iconName: String?
        let colorHex: String?
        let subcategoryID: PersistentIdentifier?
    }

    private var selectedCategoryChips: [CategoryChip] {
        var chips: [CategoryChip] = []

        // From ViewModel
        for categoryID in viewModel.selectedCategories {
            chips.append(CategoryChip(categoryID: categoryID))
        }

        // From local selection (if not already in ViewModel)
        if let localCategoryID = selectedCategoryID,
            !viewModel.selectedCategories.contains(localCategoryID)
        {
            chips.append(CategoryChip(categoryID: localCategoryID))
        }

        return chips
    }

    private var selectedSubcategoryChips: [SubcategoryChip] {
        var chips: [SubcategoryChip] = []

        // From ViewModel - use allSubcategories Query to find details
        for subcategoryID in viewModel.selectedSubcategories {
            if let subcategory = allSubcategories.first(where: {
                $0.persistentModelID == subcategoryID
            }) {
                let categoryColor = subcategory.category.colorHex
                chips.append(
                    SubcategoryChip(
                        id: subcategory.name,
                        name: subcategory.name,
                        iconName: subcategory.iconName,
                        colorHex: (subcategory.colorHex?.isEmpty == false
                            ? subcategory.colorHex : nil) ?? categoryColor,
                        subcategoryID: subcategoryID
                    ))
            }
        }

        // From local selection (if not already added via ViewModel)
        if let localSubcategoryID = selectedSubcategoryID,
            !viewModel.selectedSubcategories.contains(localSubcategoryID),
            let summary = subcategorySpending.first(where: { $0.persistentID == localSubcategoryID })
        {
            chips.append(
                SubcategoryChip(
                    id: summary.id,
                    name: summary.subcategoryName,
                    iconName: summary.subcategory?.iconName,
                    colorHex: summary.colorHex,
                    subcategoryID: summary.subcategory?.persistentModelID
                ))
        }

        return chips
    }

    // MARK: - Tag Chip Data

    private struct TagChip: Identifiable {
        let id: PersistentIdentifier
        let tagID: PersistentIdentifier
        let name: String
        let iconName: String
        let colorHex: String?
    }

    private var selectedTagChips: [TagChip] {
        tags.filter { viewModel.selectedTags.contains($0.persistentModelID) }
            .map {
                TagChip(
                    id: $0.persistentModelID,
                    tagID: $0.persistentModelID,
                    name: $0.name,
                    iconName: $0.iconName,
                    colorHex: $0.colorHex
                )
            }
    }

    // MARK: - Filter Helpers

    private var hasActiveFilters: Bool {
        viewModel.hasActiveFilters || selectedCategoryID != nil || selectedSubcategoryID != nil
    }

    private var activeFilterCount: Int {
        var count = 0
        if !viewModel.selectedAccounts.isEmpty { count += 1 }
        if !viewModel.selectedCategories.isEmpty || selectedCategoryID != nil { count += 1 }
        if !viewModel.selectedSubcategories.isEmpty || selectedSubcategoryID != nil { count += 1 }
        if !viewModel.selectedTags.isEmpty { count += 1 }
        if !viewModel.selectedNatures.isEmpty { count += 1 }
        return count
    }

    // MARK: - Chip Helpers

    private struct AccountChip: Identifiable {
        let id = UUID()
        let name: String
        let count: Int
    }

    private var selectedAccountChips: [AccountChip] {
        guard !viewModel.selectedAccounts.isEmpty else { return [] }
        let selectedAccountsList =
            accounts
            .filter { viewModel.selectedAccounts.contains($0.persistentModelID) }
        guard !selectedAccountsList.isEmpty else { return [] }

        // Return a single chip with the first account name and total count
        if let firstName = selectedAccountsList.first?.name {
            return [AccountChip(name: firstName, count: selectedAccountsList.count)]
        }
        return []
    }

    private var tagsChipText: String? {
        guard !viewModel.selectedTags.isEmpty else { return nil }
        let names = tags.filter { viewModel.selectedTags.contains($0.persistentModelID) }.map {
            $0.name
        }
        guard !names.isEmpty else { return nil }
        return names.count == 1 ? names.first : "\(names.first ?? "") +\(names.count - 1)"
    }

    private var naturesChipText: String? {
        guard !viewModel.selectedNatures.isEmpty else { return nil }
        let names = viewModel.selectedNatures.map { $0.displayName }
        return names.count == 1 ? names.first : "\(names.first ?? "") +\(names.count - 1)"
    }
}

// MARK: - All Categories List Content

/// Widget that displays all categories (not limited) in a list format
private struct AllCategoriesListContent: View {
    let categories: [CategorySpendingSummary]
    let currencyCode: String
    var selectedCategoryID: PersistentIdentifier?
    var isExpanded: Bool
    var showVariation: Bool = true
    var onToggleExpanded: (() -> Void)?
    var onSelectCategory: ((PersistentIdentifier) -> Void)?

    private var displayedCategories: [CategorySpendingSummary] {
        isExpanded ? categories : Array(categories.prefix(10))
    }

    private var showExpandButton: Bool {
        categories.count > 10
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            if let maxAmount = categories.first?.amount {
                ForEach(displayedCategories) { summary in
                    let isSelected = selectedCategoryID == summary.category.persistentModelID
                    let isAnySelected = selectedCategoryID != nil
                    let shouldDim = isAnySelected && !isSelected

                    CategoryRowView(
                        summary: summary,
                        maxAmount: maxAmount,
                        currencyCode: currencyCode,
                        showVariation: showVariation
                    )
                    .opacity(shouldDim ? 0.3 : 1.0)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onSelectCategory?(summary.category.persistentModelID)
                    }
                }

                if showExpandButton {
                    Button {
                        onToggleExpanded?()
                    } label: {
                        HStack {
                            Spacer()
                            Text(isExpanded ? L10n.Action.viewLess : L10n.Action.viewAll)
                                .font(.subheadline.weight(.semibold))
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption)
                            Spacer()
                        }
                        .padding(.vertical, DS.Spacing.md)
                        .foregroundStyle(Color.electricIndigo)
                        .background(Color.electricIndigo.opacity(0.1))
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
    var selectedCategoryID: PersistentIdentifier?
    var selectedSubcategoryID: PersistentIdentifier?
    var isExpanded: Bool
    var showVariation: Bool = true
    var onToggleExpanded: (() -> Void)?
    var onSelectSubcategory: ((PersistentIdentifier) -> Void)?

    private var displayedSubcategories: [SubcategorySpendingSummary] {
        isExpanded ? subcategories : Array(subcategories.prefix(10))
    }

    private var showExpandButton: Bool {
        subcategories.count > 10
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            if let maxAmount = subcategories.first?.amount {
                ForEach(displayedSubcategories) { summary in
                    let isSelected = selectedSubcategoryID == summary.persistentID
                    let isAnySelected = selectedSubcategoryID != nil

                    // Check if this subcategory belongs to the selected category
                    let belongsToSelectedCategory =
                        selectedCategoryID == nil
                        || summary.category?.persistentModelID == selectedCategoryID

                    // Dim if:
                    // 1. There's a subcategory selected and this isn't it, OR
                    // 2. There's a category selected and this subcategory doesn't belong to it
                    let shouldDim = (isAnySelected && !isSelected) || !belongsToSelectedCategory

                    SubcategoryRowView(
                        summary: summary,
                        maxAmount: maxAmount,
                        currencyCode: currencyCode,
                        showVariation: showVariation
                    )
                    .opacity(shouldDim ? 0.3 : 1.0)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if let persistentID = summary.persistentID {
                            onSelectSubcategory?(persistentID)
                        }
                    }
                }

                if showExpandButton {
                    Button {
                        onToggleExpanded?()
                    } label: {
                        HStack {
                            Spacer()
                            Text(isExpanded ? L10n.Action.viewLess : L10n.Action.viewAll)
                                .font(.subheadline.weight(.semibold))
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption)
                            Spacer()
                        }
                        .padding(.vertical, DS.Spacing.md)
                        .foregroundStyle(Color.electricIndigo)
                        .background(Color.electricIndigo.opacity(0.1))
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
                    .font(.subheadline)
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                // Name and Amount
                HStack {
                    Text(summary.category.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Spacer()

                    Text(YalaFormatter.currency(value: summary.amount, currencyCode: currencyCode))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                }

                // Bar and Percentage
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    // Percentage Text + Variation Chip (inline, chip aligned right)
                    HStack(spacing: DS.Spacing.sm) {
                        Text("\(formattedPercentage(summary.percentage)) \(L10n.Statistics.ofExpense)")
                            .font(.caption2)
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
                                .fill(Color.gray.opacity(0.1))
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
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: value / 100.0)) ?? "0%"
    }
}

// MARK: - Subcategory Row Component

private struct SubcategoryRowView: View {
    let summary: SubcategorySpendingSummary
    let maxAmount: Double
    let currencyCode: String
    var showVariation: Bool = true

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            // Icon Circle
            ZStack {
                Circle()
                    .fill(Color(hex: summary.colorHex ?? "#6366F1"))
                    .frame(width: 40, height: 40)

                if let subcategory = summary.subcategory {
                    Image(systemName: subcategory.iconName ?? "list.bullet.indent")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                } else {
                    Image(systemName: "list.bullet.indent")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                }
            }

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                // Name and Amount
                HStack {
                    Text(summary.subcategoryName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Spacer()

                    Text(YalaFormatter.currency(value: summary.amount, currencyCode: currencyCode))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                }

                // Bar and Percentage
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    // Percentage Text + Variation Chip (inline, chip aligned right)
                    HStack(spacing: DS.Spacing.sm) {
                        Text("\(formattedPercentage(summary.percentageOfTotal)) \(L10n.Statistics.ofExpense)")
                            .font(.caption2)
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
                                .fill(Color.gray.opacity(0.1))
                                .frame(height: 6)

                            Capsule()
                                .fill(Color(hex: summary.colorHex ?? "#6366F1"))
                                .frame(width: width, height: 6)
                        }
                    }
                    .frame(height: 6)
                }
            }
        }
    }

    private func formattedPercentage(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: value / 100.0)) ?? "0%"
    }
}
