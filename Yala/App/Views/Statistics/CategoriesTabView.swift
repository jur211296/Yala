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
    @ScaledMetric(relativeTo: .largeTitle) private var scaledEmptyIconSize: CGFloat = 48

    // MARK: - Settings

    @AppStorage("showVariations") private var showVariations: Bool = true

    // MARK: - Data (passed from parent)

    let accounts: [Account]
    let categories: [Category]
    let allSubcategories: [Subcategory]
    let tags: [Tag]
    let allTransactions: [TransactionItem]

    // MARK: - External Dependencies

    @Bindable var viewModel: StatisticsViewModel
    let defaultCurrencyCode: String
    let onNavigateToRecords: () -> Void

    // MARK: - State

    @State private var categorySpending: [CategorySpendingSummary] = []
    @State private var subcategorySpending: [SubcategorySpendingSummary] = []
    @State private var tagSpending: [TagSpendingSummary] = []
    @State private var natureTrendPoints: [NatureTrendPoint] = []
    @State private var selectedNature: SubcategoryNature?
    @State private var chartsCarouselPosition: String? = "category"
    @State private var listViewType: ListViewType = .categories
    @State private var isListExpanded: Bool = false
    @State private var isSubcategoriesAutomatic: Bool = false  // Track if switch was automatic
    @State private var showCustomPeriodPicker: Bool = false  // Custom period picker sheet
    @State private var isSyncingFilters: Bool = false  // Anti-loop flag for Nature sync functions only
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
        }
        .onChange(of: viewModel.selectedSubcategories) {
            calculateData()
        }
        .onChange(of: viewModel.selectedTags) {
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
                                }
                            )
                        } else if !viewModel.selectedCategories.isEmpty {
                            // Chip from category selection (pie chart or SessionState)
                            let selectedCats = categories.filter { viewModel.selectedCategories.contains($0.persistentModelID) }
                            if let firstCat = selectedCats.first {
                                FilterChipView(
                                    categoryName: firstCat.name,
                                    iconName: firstCat.iconName,
                                    colorHex: firstCat.colorHex,
                                    count: selectedCats.count,
                                    onClear: {
                                        viewModel.selectedCategories.removeAll()
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
                        // Only show when exactly 1 selected (hidden in expenses-only mode - always expense, non-clearable)
                        if !sessionState.isExpensesOnlyMode,
                            viewModel.selectedTransactionNatures.count == 1,
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
                                dsWithAnimation(reduceMotion) {
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

    /// Determines if comparison selector should be visible (only when showVariations is ON)
    private var showComparisonSelector: Bool {
        showVariations && PreviousPeriodHelper.isSelectorVisible(for: viewModel.detailPeriod)
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
            // iPad: tags moved to nature row, only category + subcategory (or just subcategory in income)
            return isIncomeMode ? 1 : 2
        }
        return isIncomeMode ? 2 : 3
    }

    @ViewBuilder
    private var chartsCarousel: some View {
        let isWide = DS.Adaptive.isWideScreen(sizeClass)

        VStack(spacing: DS.Spacing.sm) {
            GeometryReader { geo in
                let totalWidth = geo.size.width
                let spacing: CGFloat = DS.Spacing.md
                let cardWidth = isWide ? (totalWidth - spacing) / 2 : totalWidth

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

                        // Tags Chart - on iPad, tags moves next to nature
                        if !isWide {
                            tagChartCard
                                .frame(width: cardWidth)
                                .id("tags")
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: $chartsCarouselPosition)
                .frame(width: totalWidth)
            }
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
                    selectedCategoryIDs: effectiveCategoryIDsForDim,
                    onSelectCategory: { categoryID in
                        if viewModel.selectedCategories.contains(categoryID) {
                            viewModel.selectedCategories.remove(categoryID)
                        } else {
                            viewModel.selectedCategories = [categoryID]
                        }
                        viewModel.selectedSubcategories.removeAll()
                    },
                    size: .large,
                    period: viewModel.detailPeriod,
                    customRange: sessionState.customDateRange,
                    previousTotalAmount: previousCategoryTotal,
                    comparisonMode: sessionState.comparisonMode,
                    showVariationHeader: showVariations && viewModel.detailPeriod != .allTime
                )
            }
        }
        .background(.thCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .stroke(DS.Colors.borderSubtle, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(DS.Opacity.faint), radius: 10, x: 0, y: 5)
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
                    size: .large,
                    period: viewModel.detailPeriod,
                    customRange: sessionState.customDateRange,
                    previousTotalAmount: previousSubcategoryTotal,
                    comparisonMode: sessionState.comparisonMode,
                    showVariationHeader: showVariations && viewModel.detailPeriod != .allTime
                )
            }
        }
        .background(.thCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .stroke(DS.Colors.borderSubtle, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(DS.Opacity.faint), radius: 10, x: 0, y: 5)
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
                    size: .large,
                    period: viewModel.detailPeriod,
                    customRange: sessionState.customDateRange,
                    previousTotalAmount: previousTagTotal,
                    comparisonMode: sessionState.comparisonMode,
                    showVariationHeader: showVariations && viewModel.detailPeriod != .allTime
                )
            }
        }
        .background(.thCard)
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

    @ViewBuilder
    private var natureCarousel: some View {
        let isWide = DS.Adaptive.isWideScreen(sizeClass)

        if isWide {
            // iPad: tags pie + nature large side by side, no compact nature
            HStack(alignment: .top, spacing: DS.Spacing.lg) {
                tagChartCard
                    .frame(maxWidth: .infinity)
                natureWidgetLarge
                    .frame(maxWidth: .infinity)
            }
        } else {
            // iPhone: carousel with large/compact nature slides
            VStack(spacing: DS.Spacing.sm) {
                GeometryReader { geo in
                    let totalWidth = geo.size.width
                    let spacing: CGFloat = DS.Spacing.md

                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(alignment: .top, spacing: spacing) {
                            natureWidgetLarge
                                .frame(width: totalWidth)
                                .id(0)

                            natureWidgetCompact
                                .frame(width: totalWidth)
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

                HStack(spacing: DS.Spacing.sm) {
                    ForEach(0..<2, id: \.self) { page in
                        Circle()
                            .fill(
                                page == (natureCarouselIndex ?? 0)
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

    private var natureWidgetLarge: some View {
        NatureTrendWidget(
            trendPoints: natureTrendPoints,
            selectedNature: selectedNature,
            currencyCode: defaultCurrencyCode,
            size: .large,
            grouping: natureGrouping,
            interval: viewModel.panelDateInterval,
            onSelectNature: { nature in
                dsWithAnimation(reduceMotion) {
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
            showVariationHeader: showVariations && viewModel.detailPeriod != .allTime,
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
                dsWithAnimation(reduceMotion) {
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
            showVariationHeader: showVariations && viewModel.detailPeriod != .allTime,
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
                        isExpanded: isListExpanded,
                        showVariation: showVariations && viewModel.detailPeriod != .allTime,
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
                        selectedCategoryIDs: effectiveCategoryIDsForDim,
                        selectedSubcategoryIDs: viewModel.selectedSubcategories,
                        isExpanded: isListExpanded,
                        showVariation: showVariations && viewModel.detailPeriod != .allTime,
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
        .background(.thCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .stroke(DS.Colors.borderSubtle, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(DS.Opacity.faint), radius: 10, x: 0, y: 5)
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
        .opacity((isLocked && viewType == .categories) ? 0.4 : 1.0)
        .disabled(isLocked && viewType == .categories)
    }

    // MARK: - List View Auto-switching Logic

    /// Determines if list view should be locked to subcategories
    /// - When a category filter is applied (show only subcategories of that category)
    /// - When income mode is active (category breakdown not useful for income)
    private var shouldLockToSubcategories: Bool {
        !viewModel.selectedCategories.isEmpty || !viewModel.selectedSubcategories.isEmpty || isIncomeMode
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
                .font(.system(size: scaledEmptyIconSize))
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                .foregroundStyle(.secondary)
            Text(title)
                .font(DS.Typography.headline)
                .foregroundStyle(.secondary)
            Text(subtitle)
                .font(DS.Typography.subheadline)
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
                    Spacer()
                }
                .padding(.vertical, DS.Spacing.md)
                .foregroundStyle(theme.accent)
                .background(theme.accent.opacity(DS.Opacity.subtle))
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(DS.Card.padding)
        .background(.thCard)
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
                .font(DS.Typography.title)
                .foregroundStyle(.tertiary)
            Text(L10n.Statistics.noRecords)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.xl)
    }

    private func clearAllFilters() {
        viewModel.clearFilters()
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
        viewModel.selectedCategories.map { CategoryChip(categoryID: $0) }
    }

    private var selectedSubcategoryChips: [SubcategoryChip] {
        viewModel.selectedSubcategories.compactMap { subcategoryID in
            guard let subcategory = allSubcategories.first(where: {
                $0.persistentModelID == subcategoryID
            }) else { return nil }
            let categoryColor = subcategory.safeCategory.colorHex
            return SubcategoryChip(
                id: subcategory.name,
                name: subcategory.name,
                iconName: subcategory.iconName,
                colorHex: (subcategory.colorHex?.isEmpty == false
                    ? subcategory.colorHex : nil) ?? categoryColor,
                subcategoryID: subcategoryID
            )
        }
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
        viewModel.hasActiveFilters
    }

    private var activeFilterCount: Int {
        var count = 0
        if !viewModel.selectedAccounts.isEmpty { count += 1 }
        if !viewModel.selectedCategories.isEmpty { count += 1 }
        if !viewModel.selectedSubcategories.isEmpty { count += 1 }
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
    var selectedCategoryIDs: Set<PersistentIdentifier> = []
    var isExpanded: Bool
    var showVariation: Bool = true
    var onToggleExpanded: (() -> Void)?
    var onSelectCategory: ((PersistentIdentifier) -> Void)?
    @Environment(\.yalaTheme) private var theme

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
                    let isSelected = selectedCategoryIDs.contains(summary.category.persistentModelID)
                    let isAnySelected = !selectedCategoryIDs.isEmpty
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
                                .font(DS.Typography.headline)
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(DS.Typography.caption)
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
    var isExpanded: Bool
    var showVariation: Bool = true
    var onToggleExpanded: (() -> Void)?
    var onSelectSubcategory: ((PersistentIdentifier) -> Void)?
    @Environment(\.yalaTheme) private var theme

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
                    let isSelected = summary.persistentID.map { selectedSubcategoryIDs.contains($0) } ?? false
                    let isAnySelected = !selectedSubcategoryIDs.isEmpty

                    // Check if this subcategory belongs to a selected category
                    let belongsToSelectedCategory =
                        selectedCategoryIDs.isEmpty
                        || (summary.category?.persistentModelID).map { selectedCategoryIDs.contains($0) } ?? false

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
                                .font(DS.Typography.headline)
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(DS.Typography.caption)
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
            }

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                // Name and Amount
                HStack {
                    Text(summary.category.name)
                        .font(DS.Typography.headline)
                        .foregroundStyle(.primary)

                    Spacer()

                    Text(YalaFormatter.currency(value: summary.amount, currencyCode: currencyCode))
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
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.white)
                } else {
                    Image(systemName: "list.bullet.indent")
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.white)
                }
            }

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                // Name and Amount
                HStack {
                    Text(summary.subcategoryName)
                        .font(DS.Typography.headline)
                        .foregroundStyle(.primary)

                    Spacer()

                    Text(YalaFormatter.currency(value: summary.amount, currencyCode: currencyCode))
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
