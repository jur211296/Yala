//
//  TrendsTabView.swift
//  Yala
//
//  Trends tab content extracted from DetailContainerView.
//  Displays trend chart, metric selector, and recent records.
//

import Charts
import SwiftData
import SwiftUI

/// Trends tab content view.
/// This view displays the trend chart, control bar, and recent records section.
struct TrendsTabView: View {

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

    /// Sort accounts by user-defined order (from AccountsSettingsListView)
    private func sortedAccountIDs(_ ids: [PersistentIdentifier]) -> [PersistentIdentifier] {
        let order = appPreferences.accountsSortOrderNames
        let indexByName = Dictionary(uniqueKeysWithValues: order.enumerated().map { ($1, $0) })

        return ids.sorted { id1, id2 in
            let name1 = accounts.first(where: { $0.persistentModelID == id1 })?.name ?? ""
            let name2 = accounts.first(where: { $0.persistentModelID == id2 })?.name ?? ""

            let idx1 = indexByName[name1]
            let idx2 = indexByName[name2]

            switch (idx1, idx2) {
            case (let x?, let y?): return x < y
            case (_?, nil): return true
            case (nil, _?): return false
            default: return name1 < name2
            }
        }
    }

    // MARK: - External Dependencies

    @Bindable var trendsViewModel: StatisticsViewModel
    let defaultCurrencyCode: String
    let onNavigateToRecords: () -> Void

    // MARK: - State

    @Namespace private var metricNamespace
    @Namespace private var cashFlowSelectorNamespace
    @State private var showFilterBlockedMessage: Bool = false
    @State private var cashFlowSummary: CashFlowSummary?
    @State private var cashFlowByAccount: [PersistentIdentifier: CashFlowSummary] = [:]
    @State private var cashFlowByCurrency: [String: CashFlowSummary] = [:]
    @State private var cashFlowViewType: CashFlowViewType = .total
    @State private var accountCarouselPosition: PersistentIdentifier?
    @State private var currencyCarouselPosition: String?

    // Period Comparison State
    @State private var currentPeriodPoints: [BarPoint] = []
    @State private var previousPeriodPoints: [BarPoint] = []
    @State private var comparisonYDomain: ClosedRange<Double> = 0...1

    // Variation Totals (for VariationChip)
    @State private var currentPeriodTotal: Double = 0
    @State private var previousPeriodTotal: Double? = nil

    // CashFlow Previous Period (for VariationChip)
    @State private var previousCashFlowSummary: CashFlowSummary?
    @State private var previousCashFlowByAccount: [PersistentIdentifier: CashFlowSummary] = [:]
    @State private var previousCashFlowByCurrency: [String: CashFlowSummary] = [:]

    // Trend charts carousel state
    @State private var trendChartsCarouselPosition: Int = 0

    @State private var weekdaySpending: [WeekdaySpending] = []

    // Custom period picker state
    @State private var showCustomPeriodPicker: Bool = false

    // Debounce task for cashflow + period comparison recalculation.
    // Coalesces rapid onChange bursts (filter changes, bulk transaction inserts).
    @State private var recalcTask: Task<Void, Never>?

    // MARK: - Cash Flow View Type

    enum CashFlowViewType: String, CaseIterable, Identifiable {
        case total
        case byAccount
        case byCurrency

        var id: String { rawValue }

        var title: String {
            switch self {
            case .total: return L10n.CashFlowViewType.total
            case .byAccount: return L10n.CashFlowViewType.byAccount
            case .byCurrency: return L10n.CashFlowViewType.byCurrency
            }
        }

        var iconName: String {
            switch self {
            case .total: return "chart.bar.fill"
            case .byAccount: return "building.columns.fill"
            case .byCurrency: return "dollarsign.circle.fill"
            }
        }
    }

    // MARK: - Body

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: DS.Spacing.xl) {
                controlBar
                trendsHeader
                trendChartsCarousel
                cashFlowWidget
                weekdayChartSection
                recentRecordsSection
            }
            .padding(.top, DS.Spacing.sm)
            .yalaSafeBottomPadding()
        }
        .scrollViewGlassEdges()
        .onAppear {
            // Initial computation must be synchronous so the first render shows real data
            // rather than empty placeholders. Subsequent updates go through the debounce.
            calculateCashFlowData()
            calculatePeriodComparisonData()
            calculateWeekdayData()
        }
        .onDisappear { recalcTask?.cancel() }
        .onChange(of: trendsViewModel.detailPeriod)            { scheduleTrendsRecalc() }
        .onChange(of: trendsViewModel.selectedAccounts)        { scheduleTrendsRecalc() }
        .onChange(of: trendsViewModel.selectedCategories)      { scheduleTrendsRecalc() }
        .onChange(of: trendsViewModel.selectedSubcategories)   { scheduleTrendsRecalc() }
        .onChange(of: trendsViewModel.selectedTags)            { scheduleTrendsRecalc() }
        .onChange(of: trendsViewModel.selectedNeeds)           { scheduleTrendsRecalc() }
        .onChange(of: trendsViewModel.selectedMetric)          { scheduleTrendsRecalc() }
        .onChange(of: sessionState.comparisonMode)             { scheduleTrendsRecalc() }
        .onChange(of: sessionState.selectedTransactionNatures) { scheduleTrendsRecalc() }
        // Use count instead of full array to avoid crashes during data wipe.
        // Longer debounce (300ms) tolerates bulk inserts (import, draft dedup).
        .onChange(of: allTransactions.count)                   { scheduleTrendsRecalc(debounceMs: 300) }
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
            viewModel: trendsViewModel,
            accounts: accounts,
            categories: categories,
            allSubcategories: allSubcategories,
            tags: tags,
            animationValue: trendsViewModel.detailPeriod
        )
    }

    private var periodSelector: some View {
        TrendsPeriodMenu(
            selectedPeriod: trendsViewModel.detailPeriod,
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

    // MARK: - Trends Header

    /// Header with title "Tendencias", metric selector (balance/ing/gas), and comparison mode selector (P-1/A-1)
    /// Placed outside carousel, similar to CategoriesTabView
    private var trendsHeader: some View {
        HStack {
            Text(L10n.Trend.title)
                .font(DS.Typography.headline)
                .foregroundStyle(.primary)

            InfoHintButton(
                title: L10n.Trend.title,
                message: L10n.Widget.Hint.trend
            )

            Spacer()

            // Metric selector (hidden in expenses-only mode)
            if !sessionState.isExpensesOnlyMode {
                metricSelector
            }

            // Comparison mode selector (hidden when appPreferences.showVariations is OFF or for periods where only one mode makes sense)
            if appPreferences.showVariations && PreviousPeriodHelper.isSelectorVisible(for: trendsViewModel.detailPeriod) {
                ComparisonModeSelector()
            }
        }
    }

    // MARK: - Trend Charts Carousel

    @ViewBuilder
    private var trendChartsCarousel: some View {
        let isWide = DS.Adaptive.isWideScreen(sizeClass)
        let hasTwoCharts = appPreferences.showVariations && trendsViewModel.detailPeriod != .allTime

        VStack(spacing: DS.Spacing.md) {
            if isWide && hasTwoCharts {
                // iPad: show both charts side by side
                HStack(alignment: .top, spacing: DS.Spacing.lg) {
                    chartCard
                        .frame(maxWidth: .infinity)
                    periodComparisonCard
                        .frame(maxWidth: .infinity)
                }
                .frame(height: 330)
            } else {
                // iPhone or single chart: paging TabView
                TabView(selection: $trendChartsCarouselPosition) {
                    chartCard
                        .tag(0)

                    if hasTwoCharts {
                        periodComparisonCard
                            .tag(1)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 330)

                // Page indicators - only on compact with 2 pages
                if hasTwoCharts {
                    HStack(spacing: DS.Spacing.sm) {
                        ForEach(0..<2, id: \.self) { index in
                            Circle()
                                .fill(
                                    trendChartsCarouselPosition == index
                                        ? theme.primaryText : theme.secondaryText.opacity(0.3)
                                )
                                .frame(width: 6, height: 6)
                                .animation(
                                    .easeInOut(duration: 0.2), value: trendChartsCarouselPosition)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    /// Check if there's no trend data to display
    private var hasTrendData: Bool {
        !trendsViewModel.trendPoints.isEmpty
    }

    /// Check if there's comparison data to display
    private var hasComparisonData: Bool {
        !currentPeriodPoints.isEmpty
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            // Header with variation chip (only show full header when there's data)
            if hasTrendData {
                HStack(alignment: .top) {
                    chartHeader

                    Spacer()

                    // Variation chip with "vs period" text below (hidden for All Time or when appPreferences.showVariations is OFF)
                    if appPreferences.showVariations && trendsViewModel.detailPeriod != .allTime {
                        VStack(alignment: .trailing, spacing: DS.Spacing.xxs) {
                            VariationChip(
                                currentAmount: currentPeriodTotal,
                                previousAmount: previousPeriodTotal,
                                size: .medium,
                                showNAWhenNil: true,
                                isExpenseContext: trendsViewModel.selectedMetric == .expense
                            )

                            Text(comparisonPeriodText)
                                .font(DS.Typography.captionSmall)
                                .foregroundStyle(.thSecondaryText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            } else {
                // Simple title when no data
                Text(chartTitle)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.thPrimaryText)
            }

            if hasTrendData {
                TrendChartView(
                    trendPoints: trendsViewModel.trendPoints,
                    rawPoints: trendsViewModel.rawTrendPoints,
                    yDomain: trendsViewModel.yDomain,
                    grouping: .day,
                    interval: trendsViewModel.currentInterval,
                    currencyCode: defaultCurrencyCode,
                    trendType: mapMetricToTrendType(trendsViewModel.selectedMetric),
                    focusedDate: $trendsViewModel.focusedDate,
                    period: trendsViewModel.detailPeriod,
                    chartHeight: 220
                )
                .padding(.top, DS.Spacing.sm)
            } else {
                trendEmptyState
            }
        }
        .solidCard(padding: DS.Card.padding)
    }

    private var trendEmptyState: some View {
        YalaEmptyState(
            icon: "chart.line.uptrend.xyaxis",
            title: L10n.Empty.noData
        )
        .frame(height: 220)
    }

    private var comparisonEmptyState: some View {
        YalaEmptyState(
            icon: "chart.line.uptrend.xyaxis",
            title: L10n.Empty.noData
        )
        .frame(height: 220)
    }

    /// Dynamic title for period comparison card based on comparison mode
    private var periodComparisonTitle: String {
        switch sessionState.comparisonMode {
        case .month:
            return L10n.Statistics.vsPreviousPeriod
        case .year:
            return L10n.Statistics.vsPreviousYear
        }
    }

    private var periodComparisonCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            // Header with KPI and variation chip (only show full header when there's data)
            if hasComparisonData {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Text(periodComparisonTitle)
                            .font(DS.Typography.headline)
                            .foregroundStyle(.thPrimaryText)

                        // KPI value with "vs" previous
                        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
                            Text(currentKPIValue)
                                .font(DS.Typography.headline)
                                .foregroundStyle(.thPrimaryText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)

                            if let prevTotal = previousPeriodTotal {
                                Text("vs \(appPreferences.number(prevTotal))")
                                    .font(DS.Typography.caption)
                                    .foregroundStyle(.thSecondaryText)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                        }
                        .padding(.top, DS.Spacing.xs)
                    }

                    Spacer()

                    // Variation chip with "vs period" text below
                    VStack(alignment: .trailing, spacing: DS.Spacing.xxs) {
                        VariationChip(
                            currentAmount: currentPeriodTotal,
                            previousAmount: previousPeriodTotal,
                            size: .medium,
                            showNAWhenNil: true,
                            isExpenseContext: trendsViewModel.selectedMetric == .expense
                        )

                        Text(comparisonPeriodText)
                            .font(DS.Typography.captionSmall)
                            .foregroundStyle(.thSecondaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .accessibilityElement(children: .combine)
                }
            } else {
                // Simple title when no data
                Text(periodComparisonTitle)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.thPrimaryText)
            }

            // Chart or empty state
            if hasComparisonData {
                PeriodComparisonChartView(
                    currentPeriodPoints: currentPeriodPoints,
                    previousPeriodPoints: previousPeriodPoints,
                    yDomain: comparisonYDomain,
                    grouping: .day,
                    currentInterval: trendsViewModel.currentInterval,
                    previousInterval: PreviousPeriodHelper.previousInterval(
                        for: trendsViewModel.detailPeriod,
                        mode: sessionState.comparisonMode,
                        customRange: sessionState.customDateRange
                    ),
                    currencyCode: defaultCurrencyCode,
                    trendType: mapMetricToTrendType(trendsViewModel.selectedMetric),
                    chartHeight: 220,
                    period: trendsViewModel.detailPeriod,
                    comparisonMode: sessionState.comparisonMode
                )
                .padding(.top, DS.Spacing.sm)
            } else {
                comparisonEmptyState
            }
        }
        .solidCard(padding: DS.Card.padding)
    }

    /// Short comparison period text (e.g., "vs Nov 25") for display below chips
    private var comparisonPeriodText: String {
        guard trendsViewModel.detailPeriod != .allTime else { return "" }

        let previousInterval = PreviousPeriodHelper.previousInterval(
            for: trendsViewModel.detailPeriod,
            mode: sessionState.comparisonMode,
            customRange: sessionState.customDateRange
        )

        return PreviousPeriodHelper.formatComparisonText(
            previousInterval: previousInterval,
            period: trendsViewModel.detailPeriod,
            mode: sessionState.comparisonMode
        )
    }

    private var chartHeader: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(chartTitle)
                .font(DS.Typography.headline)
                .foregroundStyle(.thPrimaryText)

            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
                Text(currentKPIValue)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.thPrimaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                // Show previous period value for comparison (hidden for All Time or when appPreferences.showVariations is OFF)
                if appPreferences.showVariations && trendsViewModel.detailPeriod != .allTime,
                   let prevTotal = previousPeriodTotal {
                    Text("vs \(appPreferences.number(prevTotal))")
                        .font(DS.Typography.caption)
                        .foregroundStyle(.thSecondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .padding(.top, DS.Spacing.xs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Check if any category/subcategory/need filters are active
    /// In exclude mode, these filters remove items rather than restricting to them,
    /// so they don't imply a specific nature context
    private var hasCategoryFilters: Bool {
        guard !sessionState.isExcludeMode else { return false }
        return !sessionState.selectedCategoryIDs.isEmpty
            || !sessionState.selectedSubcategoryIDs.isEmpty
            || !sessionState.selectedNeeds.isEmpty
    }

    private var metricSelector: some View {
        HStack(spacing: DS.Spacing.sm) {
            ForEach(TrendMetric.allCases) { metric in
                metricButton(for: metric)
            }
        }
        .filterBlockedPopover(
            isPresented: $showFilterBlockedMessage,
            title: L10n.Trend.filterBlockedTitle,
            message: L10n.Trend.filterBlockedMessage
        )
    }

    private func metricButton(for metric: TrendMetric) -> some View {
        let isSelected = trendsViewModel.selectedMetric == metric
        let isBlocked: Bool = {
            guard hasCategoryFilters else { return false }
            guard let nature = sessionState.activeFilterNature else { return false }
            switch nature {
            case .expense: return metric != .expense
            case .income: return metric != .income
            }
        }()

        return Button {
            if isBlocked {
                showFilterBlockedMessage = true
            } else {
                switch metric {
                case .balance:
                    sessionState.selectedTransactionNatures.removeAll()
                    trendsViewModel.selectedTransactionNatures.removeAll()
                case .income:
                    sessionState.selectedTransactionNatures = [.income]
                    trendsViewModel.selectedTransactionNatures = [.income]
                case .expense:
                    sessionState.selectedTransactionNatures = [.expense]
                    trendsViewModel.selectedTransactionNatures = [.expense]
                }
            }
        } label: {
            Image(systemName: metric.iconName)
                .font(DS.Typography.labelSmall)
                .fontWeight(.semibold)
                .foregroundStyle(isSelected ? .white : (isBlocked ? metric.color.opacity(0.4) : metric.color))
                .frame(width: 32, height: 32)
                .background {
                    if isSelected {
                        Circle()
                            .fill(metric.color)
                            .matchedGeometryEffect(id: "metricSelector", in: metricNamespace)
                    } else {
                        Circle()
                            .fill(.thSecondaryText.opacity(0.08))
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(metric == .balance ? L10n.Accessibility.metricBalance : metric == .income ? L10n.Accessibility.metricIncome : L10n.Accessibility.metricExpense)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Cash Flow Widget

    @ViewBuilder
    private var cashFlowWidget: some View {
        VStack(spacing: DS.Spacing.sm) {
            // Header with selector
            HStack {
                Text(L10n.CashFlow.title)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.primary)

                InfoHintButton(
                    title: L10n.WidgetType.cashFlow,
                    message: L10n.Widget.Hint.cashFlow
                )

                Spacer()

                cashFlowViewSelector
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.top, DS.Spacing.lg)

            // Content based on view type
            switch cashFlowViewType {
            case .total:
                if let summary = cashFlowSummary {
                    cashFlowCard(
                        summary: summary,
                        previousSummary: previousCashFlowSummary,
                        title: "Total",
                        currencyCode: defaultCurrencyCode
                    )
                } else {
                    cashFlowEmptyState
                }

            case .byAccount:
                if cashFlowByAccount.isEmpty {
                    cashFlowEmptyState
                } else {
                    cashFlowByAccountCarousel
                }

            case .byCurrency:
                if cashFlowByCurrency.isEmpty {
                    cashFlowEmptyState
                } else {
                    cashFlowByCurrencyCarousel
                }
            }
        }
    }

    private var cashFlowEmptyState: some View {
        YalaEmptyState(
            icon: "chart.bar.fill",
            title: L10n.Empty.noData
        )
        .frame(height: 200)
        .solidCard()
    }

    private var cashFlowViewSelector: some View {
        HStack(spacing: DS.Spacing.sm) {
            ForEach(CashFlowViewType.allCases) { viewType in
                cashFlowViewButton(for: viewType)
            }
        }
    }

    private func cashFlowViewButton(for viewType: CashFlowViewType) -> some View {
        let isSelected = cashFlowViewType == viewType

        return Button {
            dsWithAnimation(reduceMotion) {
                cashFlowViewType = viewType
                if viewType == .byAccount,
                    let firstAccount = sortedAccountIDs(Array(cashFlowByAccount.keys)).first
                {
                    accountCarouselPosition = firstAccount
                }
                if viewType == .byCurrency,
                    let firstCurrency = cashFlowByCurrency.keys.sorted(by: { code1, code2 in
                        if code1 == defaultCurrencyCode { return true }
                        if code2 == defaultCurrencyCode { return false }
                        let total1 =
                            (cashFlowByCurrency[code1]?.totalIncome ?? 0)
                            + (cashFlowByCurrency[code1]?.totalExpense ?? 0)
                        let total2 =
                            (cashFlowByCurrency[code2]?.totalIncome ?? 0)
                            + (cashFlowByCurrency[code2]?.totalExpense ?? 0)
                        return total1 > total2
                    }).first
                {
                    currencyCarouselPosition = firstCurrency
                }
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
                            .matchedGeometryEffect(id: "cashFlowSelector", in: cashFlowSelectorNamespace)
                    } else {
                        Circle()
                            .fill(.thSecondaryText.opacity(0.08))
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(viewType.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var cashFlowByAccountCarousel: some View {
        // Sort by user-defined order (same as Profile/Accounts view)
        let accountIDs = sortedAccountIDs(Array(cashFlowByAccount.keys))

        if !accountIDs.isEmpty {
            VStack(spacing: DS.Spacing.sm) {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: DS.Spacing.none) {
                        ForEach(accountIDs, id: \.self) { accountID in
                            if let account = accounts.first(where: {
                                $0.persistentModelID == accountID
                            }),
                                let summary = cashFlowByAccount[accountID]
                            {
                                cashFlowCard(
                                    summary: summary,
                                    previousSummary: previousCashFlowByAccount[accountID],
                                    title: account.name,
                                    currencyCode: account.currencyCode
                                )
                                .containerRelativeFrame(.horizontal)
                            }
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: $accountCarouselPosition)

                // Page indicator
                if accountIDs.count > 1 {
                    HStack(spacing: DS.Spacing.xs) {
                        ForEach(Array(accountIDs.enumerated()), id: \.element) { index, accountID in
                            Circle()
                                .fill(
                                    accountCarouselPosition == accountID
                                        ? theme.primaryText.opacity(0.3)
                                        : theme.secondaryText.opacity(0.2)
                                )
                                .frame(width: 6, height: 6)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, DS.Spacing.md)
                }
            }
            .onAppear {
                if accountCarouselPosition == nil, let first = accountIDs.first {
                    accountCarouselPosition = first
                }
            }
        }
    }

    @ViewBuilder
    private var cashFlowByCurrencyCarousel: some View {
        // Sort: preferred currency first, then by descending total amount
        let currencyCodes = Array(
            cashFlowByCurrency.keys.sorted(by: { code1, code2 in
                // Preferred currency always first
                if code1 == defaultCurrencyCode { return true }
                if code2 == defaultCurrencyCode { return false }
                // Then by descending total (income + expense)
                let total1 =
                    (cashFlowByCurrency[code1]?.totalIncome ?? 0)
                    + (cashFlowByCurrency[code1]?.totalExpense ?? 0)
                let total2 =
                    (cashFlowByCurrency[code2]?.totalIncome ?? 0)
                    + (cashFlowByCurrency[code2]?.totalExpense ?? 0)
                return total1 > total2
            }))

        if !currencyCodes.isEmpty {
            VStack(spacing: DS.Spacing.sm) {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: DS.Spacing.none) {
                        ForEach(currencyCodes, id: \.self) { currencyCode in
                            if let summary = cashFlowByCurrency[currencyCode] {
                                cashFlowCard(
                                    summary: summary,
                                    previousSummary: previousCashFlowByCurrency[currencyCode],
                                    title: Locale.current.localizedString(
                                        forCurrencyCode: currencyCode)?.capitalized ?? currencyCode,
                                    currencyCode: currencyCode
                                )
                                .containerRelativeFrame(.horizontal)
                            }
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: $currencyCarouselPosition)

                // Page indicator
                if currencyCodes.count > 1 {
                    HStack(spacing: DS.Spacing.xs) {
                        ForEach(currencyCodes, id: \.self) { currencyCode in
                            Circle()
                                .fill(
                                    currencyCarouselPosition == currencyCode
                                        ? theme.primaryText.opacity(0.3)
                                        : theme.secondaryText.opacity(0.2)
                                )
                                .frame(width: 6, height: 6)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, DS.Spacing.md)
                }
            }
            .onAppear {
                if currencyCarouselPosition == nil, let first = currencyCodes.first {
                    currencyCarouselPosition = first
                }
            }
        }
    }

    private func cashFlowCard(
        summary: CashFlowSummary,
        previousSummary: CashFlowSummary?,
        title: String,
        currencyCode: String
    ) -> some View {
        // Calculate previous total based on selected metric (only when appPreferences.showVariations is ON)
        let previousTotal: Double? = {
            guard appPreferences.showVariations else { return nil }
            guard trendsViewModel.detailPeriod != .allTime else { return nil }
            guard let prev = previousSummary else { return nil }
            switch trendsViewModel.selectedMetric {
            case .balance:
                return prev.netFlow
            case .income:
                return prev.totalIncome > 0 ? prev.totalIncome : nil
            case .expense:
                return prev.totalExpense > 0 ? prev.totalExpense : nil
            }
        }()

        return CashFlowWidget(
            summary: summary,
            size: .large,
            period: trendsViewModel.detailPeriod.rawValue,
            grouping: cashFlowGrouping,
            interval: trendsViewModel.panelDateInterval,
            onShowDetail: nil,
            customTitle: title,
            displayMode: convertMetricToTrendType(trendsViewModel.selectedMetric),
            previousAmount: previousTotal,
            comparisonPeriodText: appPreferences.showVariations && trendsViewModel.detailPeriod != .allTime ? comparisonPeriodText : nil,
            showInfoHint: false
        )
    }

    /// Convert TrendMetric (Statistics) to TrendType (Panel) for CashFlowWidget compatibility
    private func convertMetricToTrendType(_ metric: TrendMetric) -> TrendType {
        switch metric {
        case .balance: return .balance
        case .income: return .income
        case .expense: return .expense
        }
    }

    /// Determine grouping for cash flow widget based on selected period
    /// Matches PanelViewModel logic for consistent bar chart grouping
    private var cashFlowGrouping: TrendGrouping {
        switch trendsViewModel.detailPeriod {
        case .thisWeek, .last7Days:
            return .day  // Daily bars for week
        case .thisMonth, .lastMonth, .last30Days:
            return .day  // Daily bars for month
        case .thisYear, .lastYear, .allTime, .custom:
            return .month  // Monthly bars for year/all-time/custom
        }
    }

    // MARK: - Recent Records Section

    private var recentRecordsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text(L10n.Statistics.latestRecords)
                .font(DS.Typography.headline)
                .foregroundStyle(.thPrimaryText)

            if trendsViewModel.recentRecords.isEmpty {
                emptyRecordsState
            } else {
                ForEach(trendsViewModel.recentRecords.prefix(5), id: \.persistentModelID) {
                    record in
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
                .background(theme.accent.opacity(0.1))
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
            Text(L10n.Records.noRecords)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.xl)
    }

    // MARK: - Helpers

    private var currentKPIValue: String {
        // When scrubbing the chart, show the hovered point value (use RAW points)
        if let focusedDate = trendsViewModel.focusedDate,
            let point = trendsViewModel.rawTrendPoints.first(where: {
                Calendar.current.isDate($0.date, inSameDayAs: focusedDate)
            })
        {
            return appPreferences.currency(point.value, currencyCode: defaultCurrencyCode)
        }

        // Otherwise, show metric-specific KPI
        let value: Double
        switch trendsViewModel.selectedMetric {
        case .balance:
            // Balance: show the last RAW chart point value (actual end balance, not smoothed)
            value = trendsViewModel.rawTrendPoints.last?.value ?? 0
        case .income:
            // Income: show TOTAL income for the period
            value = trendsViewModel.totalIncome
        case .expense:
            // Expense: show TOTAL expense for the period
            value = trendsViewModel.totalExpense
        }
        return appPreferences.currency(value, currencyCode: defaultCurrencyCode)
    }

    private var chartTitle: String {
        switch trendsViewModel.selectedMetric {
        case .balance: return L10n.Trend.balanceTitle
        case .income: return L10n.Trend.incomeTitle
        case .expense: return L10n.Trend.expenseTitle
        }
    }

    private func mapMetricToTrendType(_ metric: TrendMetric) -> TrendType {
        switch metric {
        case .balance: return .balance
        case .income: return .income
        case .expense: return .expense
        }
    }

    // MARK: - Chip Text Helpers

    // MARK: - Debounced Recalculation

    /// Debounces `calculateCashFlowData` + `calculatePeriodComparisonData` so rapid onChange
    /// bursts (filter changes, bulk transaction inserts) collapse into a single pass.
    /// Default 200ms for filter changes; use 300ms for `allTransactions.count` to tolerate imports.
    private func scheduleTrendsRecalc(debounceMs: Int = 200) {
        recalcTask?.cancel()
        recalcTask = Task { @MainActor in
            do { try await Task.sleep(for: .milliseconds(debounceMs)) } catch { return }
            guard !Task.isCancelled else { return }
            calculateCashFlowData()
            calculatePeriodComparisonData()
            calculateWeekdayData()
        }
    }

    // MARK: - Weekday Spending Calculation

    /// Calcula el promedio de gasto por día de la semana respetando los filtros activos.
    /// Reusa el patrón de `calculateCashFlowData` (mismo intervalo + criteria).
    private func calculateWeekdayData() {
        guard !allTransactions.isEmpty else {
            weekdaySpending = []
            return
        }

        let baseInterval = trendsViewModel.panelDateInterval
        let effectiveInterval: DateInterval = {
            guard trendsViewModel.detailPeriod == .allTime else { return baseInterval }
            let dates = allTransactions.map(\.date)
            guard let first = dates.min(), let last = dates.max() else { return baseInterval }
            let calendar = Calendar.current
            let start = calendar.startOfDay(for: first)
            let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: last)) ?? last
            return DateInterval(start: start, end: end)
        }()

        let criteria = FilterCriteria(
            selectedAccounts: trendsViewModel.selectedAccounts,
            selectedCategories: trendsViewModel.selectedCategories,
            selectedSubcategories: trendsViewModel.selectedSubcategories,
            selectedTags: trendsViewModel.selectedTags,
            selectedNeeds: trendsViewModel.selectedNeeds,
            selectedCurrencies: trendsViewModel.selectedCurrencies,
            isExcludeMode: trendsViewModel.isExcludeMode,
            transactionTypeFilter: .all,
            amountCondition: trendsViewModel.amountCondition,
            searchText: trendsViewModel.searchText,
            dateInterval: effectiveInterval
        )

        let filtered = FilterService.filterForTrends(
            transactions: allTransactions,
            accounts: accounts,
            criteria: criteria
        )

        let result = WeekdaySpendingCalculator.calculate(
            transactions: filtered,
            interval: effectiveInterval,
            currencyCode: defaultCurrencyCode
        )
        if result != weekdaySpending { weekdaySpending = result }
    }

    // MARK: - Weekday Chart Section

    @ViewBuilder
    private var weekdayChartSection: some View {
        if weekdaySpending.contains(where: { $0.average > 0 }) {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text(L10n.Insights.weekdayAverage)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.thPrimaryText)

                WeekdayBarChart(
                    data: weekdaySpending,
                    currencyCode: defaultCurrencyCode
                )
                .solidCard(padding: DS.Spacing.lg)
            }
        }
    }

    // MARK: - Cash Flow Data Calculation

    private func calculateCashFlowData() {
        // Skip if no transactions (likely during data wipe)
        guard !allTransactions.isEmpty else {
            cashFlowSummary = nil
            cashFlowByAccount = [:]
            cashFlowByCurrency = [:]
            return
        }

        let baseInterval = trendsViewModel.panelDateInterval

        // For All Time, calculate effective interval based on actual transactions
        let fetchedTransactions = allTransactions
        let effectiveInterval: DateInterval
        if trendsViewModel.detailPeriod == .allTime {
            let dates = fetchedTransactions.map(\.date)
            if let firstDate = dates.min(), let lastDate = dates.max() {
                let calendar = Calendar.current
                let start = calendar.startOfDay(for: firstDate)
                let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: lastDate)) ?? lastDate
                effectiveInterval = DateInterval(start: start, end: end)
            } else {
                effectiveInterval = baseInterval
            }
        } else {
            effectiveInterval = baseInterval
        }
        let interval = effectiveInterval

        // Build filter criteria
        let criteria = FilterCriteria(
            selectedAccounts: trendsViewModel.selectedAccounts,
            selectedCategories: trendsViewModel.selectedCategories,
            selectedSubcategories: trendsViewModel.selectedSubcategories,
            selectedTags: trendsViewModel.selectedTags,
            selectedNeeds: trendsViewModel.selectedNeeds,
            selectedCurrencies: trendsViewModel.selectedCurrencies,
            isExcludeMode: trendsViewModel.isExcludeMode,
            transactionTypeFilter: .all,
            amountCondition: trendsViewModel.amountCondition,
            searchText: trendsViewModel.searchText,
            dateInterval: interval
        )

        // Filter transactions (reuse fetchedTransactions from above)
        let filtered = FilterService.filterForTrends(
            transactions: fetchedTransactions,
            accounts: accounts,
            criteria: criteria
        )

        // 1. Calculate TOTAL cash flow data
        let newCashFlow = CashFlowCalculator.calculateCashFlow(
            transactions: filtered,
            interval: interval,
            grouping: cashFlowGrouping,
            currencyCode: defaultCurrencyCode,

        )
        if newCashFlow != cashFlowSummary { cashFlowSummary = newCashFlow }

        // 2. Calculate cash flow BY ACCOUNT (single-pass grouping: O(n) instead of O(a×n))
        let groupedByAccount = Dictionary(grouping: filtered) { $0.account?.persistentModelID }
        var byAccount: [PersistentIdentifier: CashFlowSummary] = [:]
        for account in accounts {
            let accountTransactions = groupedByAccount[account.persistentModelID] ?? []
            let summary = CashFlowCalculator.calculateCashFlow(
                transactions: accountTransactions,
                interval: interval,
                grouping: cashFlowGrouping,
                currencyCode: account.currencyCode,
    
            )
            byAccount[account.persistentModelID] = summary
        }
        if byAccount != cashFlowByAccount { cashFlowByAccount = byAccount }

        // 3. Calculate cash flow BY CURRENCY (single-pass grouping: O(n) instead of O(c×n))
        let groupedByCurrency = Dictionary(grouping: filtered) { $0.currencyCode }
        var byCurrency: [String: CashFlowSummary] = [:]
        for (currencyCode, currencyTransactions) in groupedByCurrency {
            let summary = CashFlowCalculator.calculateCashFlow(
                transactions: currencyTransactions,
                interval: interval,
                grouping: cashFlowGrouping,
                currencyCode: currencyCode,
    
            )
            byCurrency[currencyCode] = summary
        }
        if byCurrency != cashFlowByCurrency { cashFlowByCurrency = byCurrency }

        // 4. Calculate PREVIOUS period cash flow for variation chip
        calculatePreviousCashFlow(fetchedTransactions: fetchedTransactions)
    }

    /// Calculate previous period cash flow summary for VariationChip
    private func calculatePreviousCashFlow(fetchedTransactions: [TransactionItem]) {
        // Skip for All Time period
        guard trendsViewModel.detailPeriod != .allTime else {
            previousCashFlowSummary = nil
            previousCashFlowByAccount = [:]
            previousCashFlowByCurrency = [:]
            return
        }

        let previousInterval = PreviousPeriodHelper.previousInterval(
            for: trendsViewModel.detailPeriod,
            mode: sessionState.comparisonMode,
            customRange: sessionState.customDateRange
        )

        // Build filter criteria for previous period (same filters as current period)
        let previousCriteria = FilterCriteria(
            selectedAccounts: trendsViewModel.selectedAccounts,
            selectedCategories: trendsViewModel.selectedCategories,
            selectedSubcategories: trendsViewModel.selectedSubcategories,
            selectedTags: trendsViewModel.selectedTags,
            selectedNeeds: trendsViewModel.selectedNeeds,
            selectedCurrencies: trendsViewModel.selectedCurrencies,
            isExcludeMode: trendsViewModel.isExcludeMode,
            transactionTypeFilter: .all,
            amountCondition: trendsViewModel.amountCondition,
            searchText: trendsViewModel.searchText,
            dateInterval: previousInterval
        )

        // Filter transactions for previous period
        let previousFiltered = FilterService.filterForTrends(
            transactions: fetchedTransactions,
            accounts: accounts,
            criteria: previousCriteria
        )

        // 1. Calculate TOTAL previous period cash flow
        previousCashFlowSummary = CashFlowCalculator.calculateCashFlow(
            transactions: previousFiltered,
            interval: previousInterval,
            grouping: cashFlowGrouping,
            currencyCode: defaultCurrencyCode,

        )

        // 2. Calculate previous period cash flow BY ACCOUNT (single-pass grouping)
        let prevGroupedByAccount = Dictionary(grouping: previousFiltered) { $0.account?.persistentModelID }
        var byAccount: [PersistentIdentifier: CashFlowSummary] = [:]
        for account in accounts {
            let accountTransactions = prevGroupedByAccount[account.persistentModelID] ?? []
            let summary = CashFlowCalculator.calculateCashFlow(
                transactions: accountTransactions,
                interval: previousInterval,
                grouping: cashFlowGrouping,
                currencyCode: account.currencyCode,
    
            )
            byAccount[account.persistentModelID] = summary
        }
        previousCashFlowByAccount = byAccount

        // 3. Calculate previous period cash flow BY CURRENCY (single-pass grouping)
        let prevGroupedByCurrency = Dictionary(grouping: previousFiltered) { $0.currencyCode }
        var byCurrency: [String: CashFlowSummary] = [:]
        for (currencyCode, currencyTransactions) in prevGroupedByCurrency {
            let summary = CashFlowCalculator.calculateCashFlow(
                transactions: currencyTransactions,
                interval: previousInterval,
                grouping: cashFlowGrouping,
                currencyCode: currencyCode,
    
            )
            byCurrency[currencyCode] = summary
        }
        previousCashFlowByCurrency = byCurrency
    }

    // MARK: - Period Comparison Data Calculation

    private func calculatePeriodComparisonData() {
        // Skip calculation for All Time period
        guard trendsViewModel.detailPeriod != .allTime else {
            currentPeriodPoints = []
            previousPeriodPoints = []
            comparisonYDomain = 0...1
            currentPeriodTotal = 0
            previousPeriodTotal = nil
            return
        }

        let currentInterval = trendsViewModel.panelDateInterval
        let previousInterval = PreviousPeriodHelper.previousInterval(
            for: trendsViewModel.detailPeriod,
            mode: sessionState.comparisonMode,
            customRange: sessionState.customDateRange
        )

        // Get eligible accounts (archived accounts still count; same as StatisticsViewModel)
        let eligibleAccounts = accounts.filter { account in
            !account.excludeFromStatistics
                && (trendsViewModel.selectedAccounts.isEmpty
                    || trendsViewModel.selectedAccounts.contains(account.persistentModelID))
        }

        // For balance: we need ALL transactions (no date filter) to calculate running balance
        // For income/expense: we only need transactions in the period
        let isBalanceMetric = trendsViewModel.selectedMetric == .balance

        // Base criteria WITHOUT date interval (for balance) or WITH date interval (for income/expense)
        let baseCriteria = FilterCriteria(
            selectedAccounts: trendsViewModel.selectedAccounts,
            selectedCategories: trendsViewModel.selectedCategories,
            selectedSubcategories: trendsViewModel.selectedSubcategories,
            selectedTags: trendsViewModel.selectedTags,
            selectedNeeds: trendsViewModel.selectedNeeds,
            selectedCurrencies: trendsViewModel.selectedCurrencies,
            isExcludeMode: trendsViewModel.isExcludeMode,
            transactionTypeFilter: .all,
            amountCondition: trendsViewModel.amountCondition,
            searchText: trendsViewModel.searchText,
            dateInterval: isBalanceMetric ? nil : currentInterval
        )

        // For balance: filter by account/category but NOT by date, pass ALL transactions
        // For income/expense: filter by date too
        let filteredTransactions = FilterService.filterForTrends(
            transactions: allTransactions,
            accounts: accounts,
            criteria: baseCriteria
        )

        // Calculate current period data
        let currentResult = TrendDataProcessor.processTrendData(
            transactions: filteredTransactions,
            accounts: eligibleAccounts,
            metric: convertMetricToTrendType(trendsViewModel.selectedMetric),
            period: trendsViewModel.detailPeriod,
            grouping: .day,
            interval: currentInterval,
            currencyCode: defaultCurrencyCode,

        )

        // For previous period with income/expense, we need separate filtering
        let previousFiltered: [TransactionItem]
        if isBalanceMetric {
            // Same transactions, processor will use different interval
            previousFiltered = filteredTransactions
        } else {
            // Filter for previous period date range
            let previousCriteria = FilterCriteria(
                selectedAccounts: trendsViewModel.selectedAccounts,
                selectedCategories: trendsViewModel.selectedCategories,
                selectedSubcategories: trendsViewModel.selectedSubcategories,
                selectedTags: trendsViewModel.selectedTags,
                selectedNeeds: trendsViewModel.selectedNeeds,
                selectedCurrencies: trendsViewModel.selectedCurrencies,
                isExcludeMode: trendsViewModel.isExcludeMode,
                transactionTypeFilter: .all,
                amountCondition: trendsViewModel.amountCondition,
                searchText: trendsViewModel.searchText,
                dateInterval: previousInterval
            )
            previousFiltered = FilterService.filterForTrends(
                transactions: allTransactions,
                accounts: accounts,
                criteria: previousCriteria
            )
        }

        // Calculate previous period data
        let previousResult = TrendDataProcessor.processTrendData(
            transactions: previousFiltered,
            accounts: eligibleAccounts,
            metric: convertMetricToTrendType(trendsViewModel.selectedMetric),
            period: trendsViewModel.detailPeriod,
            grouping: .day,
            interval: previousInterval,
            currencyCode: defaultCurrencyCode,

        )

        // Update state with equality guards
        if currentResult.points != currentPeriodPoints { currentPeriodPoints = currentResult.points }
        if previousResult.points != previousPeriodPoints { previousPeriodPoints = previousResult.points }

        // Calculate totals for VariationChip
        let newCurrentTotal = currentResult.points.last?.value ?? 0
        if newCurrentTotal != currentPeriodTotal { currentPeriodTotal = newCurrentTotal }
        let prevTotal = previousResult.points.last?.value ?? 0
        let newPreviousTotal: Double? = previousResult.points.isEmpty ? nil : prevTotal
        if newPreviousTotal != previousPeriodTotal { previousPeriodTotal = newPreviousTotal }

        // Calculate combined Y domain
        let allValues =
            currentResult.points.map { $0.value } + previousResult.points.map { $0.value }
        if let minValue = allValues.min(), let maxValue = allValues.max() {
            let padding = (maxValue - minValue) * 0.1
            comparisonYDomain = (minValue - padding)...(maxValue + padding)
        } else {
            comparisonYDomain = 0...1
        }
    }

}

// MARK: - Compact Record Row

/// Compact record row matching RecentRecordsWidget layout exactly
struct CompactRecordRow: View {
    @Environment(AppPreferences.self) private var appPreferences

    let record: TransactionItem
    let currencyCode: String

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            // Icon
            subcategoryIcon(size: 36)

            // Left column: Note/Category and Date
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                // Line 1: Note (bold) or Subcategory as fallback
                if let note = record.note, !note.isEmpty {
                    Text(note)
                        .font(DS.Typography.label)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    // Line 2: Subcategory • Date
                    Text(secondaryLine)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text(record.subcategory?.name ?? record.category?.name ?? L10n.Common.uncategorized)
                        .font(DS.Typography.label)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    // Date as secondary
                    Text(shortDateFormat)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Right column: Amount + Nature
            VStack(alignment: .trailing, spacing: DS.Spacing.xs) {
                Text(formattedAmount)
                    .font(DS.Typography.headline)
                    .foregroundStyle(amountColor)

                // Nature indicator (if available)
                if let subcategory = record.subcategory {
                    needIndicator(for: subcategory.need)
                }
            }
        }
    }

    // MARK: - Nature Indicator

    private func needIndicator(for need: SubcategoryNeed) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            Circle()
                .fill(need.color)
                .frame(width: 6, height: 6)

            Text(need.displayName)
                .font(DS.Typography.labelTiny)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, DS.Spacing.xs)
        .padding(.vertical, DS.Spacing.xxs)
        .background(
            Capsule()
                .fill(need.color.opacity(0.1))
        )
    }

    // MARK: - Subcategory Icon

    private func subcategoryIcon(size iconSize: CGFloat) -> some View {
        let colorHex =
            record.subcategory?.colorHex
            ?? record.category?.colorHex
            ?? AppConstants.defaultColorHex

        let iconName =
            record.subcategory?.iconName
            ?? record.category?.iconName
            ?? "tag.fill"

        return ZStack {
            Circle()
                .fill(Color(hex: colorHex))
                .frame(width: iconSize, height: iconSize)

            Image(systemName: iconName)
                .font(.system(size: iconSize * 0.4)) // A11Y-DT: fixed size — icon from caller parameter
                .foregroundStyle(.white)
        }
    }

    // MARK: - Helpers

    private var secondaryLine: String {
        var parts: [String] = []

        // Show subcategory/category
        if record.note != nil && !(record.note?.isEmpty ?? true) {
            if let subcategory = record.subcategory {
                parts.append(subcategory.name)
            } else if let category = record.category {
                parts.append(category.name)
            }
        }

        // Then date
        parts.append(shortDateFormat)

        return parts.joined(separator: " • ")
    }

    private var amountColor: Color {
        let isIncome = record.category?.isIncome ?? (record.amount >= 0)
        return isIncome ? Color.electricIndigo : Color.hotPink
    }

    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "d MMM"
        return formatter
    }()

    private var shortDateFormat: String {
        Self.shortDateFormatter.string(from: record.date).replacing(".", with: "")
    }

    private var formattedAmount: String {
        appPreferences.currency(record.amount, currencyCode: record.currencyCode, forceFullPrecision: true)
    }
}
