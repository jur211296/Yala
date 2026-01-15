//
//  TrendsTabView.swift
//  Neto
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
    @Environment(SessionState.self) private var sessionState

    // MARK: - Data Queries

    @Query private var accounts: [Account]
    @Query(sort: \Category.name, order: .forward) private var categories: [Category]
    @Query(sort: \Subcategory.name, order: .forward) private var allSubcategories: [Subcategory]
    @Query(sort: \Tag.name, order: .forward) private var tags: [Tag]
    @Query(sort: \TransactionItem.date, order: .reverse) private var allTransactions:
        [TransactionItem]

    // MARK: - Persistent Sort Order (matches Profile/Accounts view)

    @AppStorage("accountsSortOrderNames") private var accountsSortOrderNamesRaw: String = ""

    /// Account names in user-defined order (pipe-separated)
    private var accountsSortOrderNames: [String] {
        accountsSortOrderNamesRaw.split(separator: "|").map(String.init)
    }

    /// Sort accounts by user-defined order (from AccountsSettingsListView)
    private func sortedAccountIDs(_ ids: [PersistentIdentifier]) -> [PersistentIdentifier] {
        let order = accountsSortOrderNames
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

    // Trend charts carousel state
    @State private var trendChartsCarouselPosition: Int = 0

    // Custom period picker state
    @State private var showCustomPeriodPicker: Bool = false

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
            VStack(spacing: 20) {
                controlBar
                trendChartsCarousel
                cashFlowWidget
                recentRecordsSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
        .onAppear {
            // Sync metric from SessionState on appear
            trendsViewModel.syncMetricFromSessionState(sessionState)
            calculateCashFlowData()
            calculatePeriodComparisonData()
        }
        .onChange(of: trendsViewModel.detailPeriod) {
            calculateCashFlowData()
            calculatePeriodComparisonData()
        }
        .onChange(of: trendsViewModel.selectedAccounts) {
            calculateCashFlowData()
            calculatePeriodComparisonData()
        }
        .onChange(of: trendsViewModel.selectedCategories) {
            calculateCashFlowData()
            calculatePeriodComparisonData()
        }
        .onChange(of: trendsViewModel.selectedSubcategories) {
            calculateCashFlowData()
            calculatePeriodComparisonData()
        }
        .onChange(of: trendsViewModel.selectedTags) {
            calculateCashFlowData()
            calculatePeriodComparisonData()
        }
        .onChange(of: trendsViewModel.selectedNatures) {
            calculateCashFlowData()
            calculatePeriodComparisonData()
        }
        .onChange(of: trendsViewModel.selectedMetric) {
            calculatePeriodComparisonData()
        }
        .onChange(of: trendsViewModel.selectedMetric) {
            // Sync metric to SessionState when it changes
            trendsViewModel.syncMetricToSessionState(sessionState)
        }
        .onChange(of: sessionState.selectedTrendMetric) {
            // Sync metric from SessionState when it changes in other views
            trendsViewModel.syncMetricFromSessionState(sessionState)
        }
        .onChange(of: sessionState.customDateRange) {
            // Sync custom date range and recalculate
            trendsViewModel.syncCustomRangeFromSessionState(sessionState)
        }
        // NOTE: Removed .onChange(of: allTransactions) - it caused crashes during data wipe
        // CashFlow updates via other onChange triggers (period, filters, etc.)
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
        HStack(spacing: 12) {
            periodSelector

            if trendsViewModel.hasActiveFilters {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        // Account chips (with icon)
                        ForEach(selectedAccountChips, id: \.id) { chip in
                            FilterChipView(
                                accountName: chip.name,
                                count: chip.count,
                                onClear: {
                                    trendsViewModel.selectedAccounts.removeAll()
                                }
                            )
                        }

                        // Category chip (aggregated - one chip max)
                        if let catChip = aggregatedCategoryChip(
                            selectedSubcategories: trendsViewModel.selectedSubcategories,
                            allSubcategories: allSubcategories
                        ) {
                            FilterChipView(
                                categoryName: catChip.name,
                                iconName: catChip.iconName,
                                colorHex: catChip.colorHex,
                                count: catChip.count,
                                onClear: {
                                    // Clear both categories and subcategories
                                    trendsViewModel.selectedCategories.removeAll()
                                    trendsViewModel.selectedSubcategories.removeAll()
                                }
                            )
                        }

                        // Subcategory chip (aggregated - one chip max)
                        if let subChip = aggregatedSubcategoryChip(
                            selectedSubcategories: trendsViewModel.selectedSubcategories,
                            allSubcategories: allSubcategories
                        ) {
                            FilterChipView(
                                subcategoryName: subChip.name,
                                iconName: subChip.iconName,
                                colorHex: subChip.colorHex,
                                count: subChip.count,
                                onClear: {
                                    trendsViewModel.selectedSubcategories.removeAll()
                                }
                            )
                        }

                        // Tag chips (with color dots, like nature chips)
                        ForEach(selectedTagChips, id: \.id) { chip in
                            FilterChipView(
                                tagName: chip.name,
                                colorHex: chip.colorHex,
                                onClear: {
                                    trendsViewModel.selectedTags.remove(chip.tagID)
                                }
                            )
                        }

                        // Nature chips (with color dots)
                        ForEach(selectedNatureChips, id: \.nature.rawValue) { chipData in
                            FilterChipView(
                                nature: chipData.nature,
                                onClear: {
                                    trendsViewModel.selectedNatures.remove(chipData.nature)
                                }
                            )
                        }

                        // Currency chips
                        ForEach(Array(trendsViewModel.selectedCurrencies), id: \.self) { currency in
                            FilterChipView(
                                currencyCode: currency.rawValue,
                                onClear: {
                                    trendsViewModel.selectedCurrencies.remove(currency)
                                    sessionState.selectedCurrencies.remove(currency)
                                }
                            )
                        }

                        // Amount chip
                        if trendsViewModel.amountCondition.isActive {
                            FilterChipView(
                                amountText: trendsViewModel.amountCondition.displayText,
                                onClear: {
                                    trendsViewModel.amountCondition = .any
                                    sessionState.amountCondition = .any
                                }
                            )
                        }

                        // Search/Note chip
                        if !trendsViewModel.searchText.isEmpty {
                            FilterChipView(
                                noteText: trendsViewModel.searchText,
                                onClear: {
                                    trendsViewModel.searchText = ""
                                    sessionState.searchText = ""
                                }
                            )
                        }

                        if trendsViewModel.activeFilterCount > 1 {
                            Button {
                                withAnimation { trendsViewModel.clearFilters() }
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
        .animation(nil, value: trendsViewModel.detailPeriod)
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

    // MARK: - Chart Card

    // MARK: - Trend Charts Carousel

    private var trendChartsCarousel: some View {
        VStack(spacing: 12) {
            TabView(selection: $trendChartsCarouselPosition) {
                // Trends Chart Card (Page 0)
                chartCard
                    .tag(0)

                // Period Comparison Card (Page 1) - only if not All Time
                if trendsViewModel.detailPeriod != .allTime {
                    periodComparisonCard
                        .tag(1)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 330)

            // Page indicators (centered)
            if trendsViewModel.detailPeriod != .allTime {
                HStack(spacing: 8) {
                    ForEach(0..<2, id: \.self) { index in
                        Circle()
                            .fill(
                                trendChartsCarouselPosition == index
                                    ? Color.netoPrimaryText : Color.netoSecondaryText.opacity(0.3)
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

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            chartHeader

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
            .padding(.top, 8)
        }
        .padding(DS.Card.padding)
        .background(Color.netoCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(DS.Opacity.faint), radius: 10, x: 0, y: 5)
    }

    private var periodComparisonCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.Statistics.periodComparison)
                    .font(.headline)
                    .foregroundStyle(Color.netoPrimaryText)

                Text(comparisonSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(Color.netoSecondaryText)
            }

            // Chart
            PeriodComparisonChartView(
                currentPeriodPoints: currentPeriodPoints,
                previousPeriodPoints: previousPeriodPoints,
                yDomain: comparisonYDomain,
                grouping: .day,
                interval: trendsViewModel.currentInterval,
                currencyCode: defaultCurrencyCode,
                trendType: mapMetricToTrendType(trendsViewModel.selectedMetric),
                chartHeight: 220
            )
            .padding(.top, 8)
        }
        .padding(DS.Card.padding)
        .background(Color.netoCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(DS.Opacity.faint), radius: 10, x: 0, y: 5)
    }

    private var comparisonSubtitle: String {
        let currentInterval = trendsViewModel.currentInterval
        let previousInterval = getPreviousPeriodInterval(for: trendsViewModel.detailPeriod)

        let formatter = DateFormatter()
        formatter.locale = AppLocale.current

        let period = trendsViewModel.detailPeriod

        switch period {
        case .thisWeek, .last7Days:
            // Format: "5-11 dic vs 28 nov-4 dic"
            formatter.dateFormat = "d MMM"
            let currentStart = formatter.string(from: currentInterval.start).replacingOccurrences(
                of: ".", with: "")
            formatter.dateFormat = "d MMM"
            let currentEnd = formatter.string(from: currentInterval.end).replacingOccurrences(
                of: ".", with: "")
            let previousStart = formatter.string(from: previousInterval.start).replacingOccurrences(
                of: ".", with: "")
            formatter.dateFormat = "d MMM"
            let previousEnd = formatter.string(from: previousInterval.end).replacingOccurrences(
                of: ".", with: "")
            return "\(currentStart)-\(currentEnd) vs \(previousStart)-\(previousEnd)"

        case .thisMonth, .lastMonth:
            // Format: "Diciembre 25 vs Noviembre 25"
            formatter.dateFormat = "MMMM yy"
            let currentMonth = formatter.string(from: currentInterval.start).capitalized
                .replacingOccurrences(of: ".", with: "")
            let previousMonth = formatter.string(from: previousInterval.start).capitalized
                .replacingOccurrences(of: ".", with: "")
            return "\(currentMonth) vs \(previousMonth)"

        case .thisYear, .lastYear:
            // Format: "2025 vs 2024"
            formatter.dateFormat = "yyyy"
            let currentYear = formatter.string(from: currentInterval.start)
            let previousYear = formatter.string(from: previousInterval.start)
            return "\(currentYear) vs \(previousYear)"

        case .last30Days:
            // Format: "5 dic-3 ene vs 6 nov-5 dic"
            formatter.dateFormat = "d MMM"
            let currentStart = formatter.string(from: currentInterval.start).replacingOccurrences(
                of: ".", with: "")
            let currentEnd = formatter.string(from: currentInterval.end).replacingOccurrences(
                of: ".", with: "")
            let previousStart = formatter.string(from: previousInterval.start).replacingOccurrences(
                of: ".", with: "")
            let previousEnd = formatter.string(from: previousInterval.end).replacingOccurrences(
                of: ".", with: "")
            return "\(currentStart)-\(currentEnd) vs \(previousStart)-\(previousEnd)"

        case .allTime, .custom:
            return ""
        }
    }

    private var chartHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(chartTitle)
                    .font(.headline)
                    .foregroundStyle(Color.netoPrimaryText)

                Text(currentKPIValue)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color.netoPrimaryText)
                    .padding(.top, 4)
            }

            Spacer()

            metricSelector
        }
    }

    private var metricSelector: some View {
        HStack(spacing: 0) {
            // When locked to expense (filters applied), only show expense button
            // Otherwise show all options
            ForEach(availableMetrics) { metric in
                metricButton(for: metric)
            }
        }
        .padding(3)
        .background(Color.netoSecondaryText.opacity(0.08))
        .clipShape(Capsule())
        .animation(.easeInOut(duration: 0.2), value: trendsViewModel.isMetricLockedToExpense)
    }

    /// Returns available metrics based on filter state
    private var availableMetrics: [TrendMetric] {
        if trendsViewModel.isMetricLockedToExpense {
            return [.expense]  // Only expense when filters are applied
        }
        return TrendMetric.allCases
    }

    private func metricButton(for metric: TrendMetric) -> some View {
        let isSelected = trendsViewModel.selectedMetric == metric
        let isLocked = trendsViewModel.isMetricLockedToExpense

        return Button {
            // Only allow change if not locked
            if !isLocked {
                // Change metric manually (marks as user selection, not automatic)
                trendsViewModel.setMetricManually(metric)
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: metric.iconName)
                    .font(.caption.weight(.semibold))
                if isSelected {
                    Text(metric.displayName)
                        .font(.caption.weight(.semibold))
                }
            }
            .padding(.horizontal, isSelected ? 12 : 10)
            .padding(.vertical, 8)
            .foregroundStyle(isSelected ? .white : metric.color)
            .background(
                Group {
                    if isSelected {
                        Capsule()
                            .fill(metric.color)
                            .matchedGeometryEffect(id: "metricSelector", in: metricNamespace)
                    }
                }
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Cash Flow Widget

    @ViewBuilder
    private var cashFlowWidget: some View {
        VStack(spacing: DS.Spacing.sm) {
            // Header with selector
            HStack {
                Text(L10n.CashFlow.title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                cashFlowViewSelector
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.top, DS.Spacing.lg)

            // Content based on view type
            switch cashFlowViewType {
            case .total:
                if let summary = cashFlowSummary {
                    CashFlowWidget(
                        summary: summary,
                        size: .large,
                        period: trendsViewModel.detailPeriod.rawValue,
                        grouping: cashFlowGrouping,
                        interval: trendsViewModel.panelDateInterval,
                        onShowDetail: nil,
                        customTitle: "Total",
                        displayMode: convertMetricToTrendType(trendsViewModel.selectedMetric)
                    )
                }

            case .byAccount:
                cashFlowByAccountCarousel

            case .byCurrency:
                cashFlowByCurrencyCarousel
            }
        }
    }

    private var cashFlowViewSelector: some View {
        HStack(spacing: 0) {
            ForEach(CashFlowViewType.allCases) { viewType in
                cashFlowViewButton(for: viewType)
            }
        }
        .padding(3)
        .background(Color.netoSecondaryText.opacity(0.08))
        .clipShape(Capsule())
    }

    private func cashFlowViewButton(for viewType: CashFlowViewType) -> some View {
        let isSelected = cashFlowViewType == viewType

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                cashFlowViewType = viewType
                // Reset carousel positions when switching view type
                if viewType == .byAccount,
                    let firstAccount = sortedAccountIDs(Array(cashFlowByAccount.keys)).first
                {
                    accountCarouselPosition = firstAccount
                }
                if viewType == .byCurrency,
                    let firstCurrency = cashFlowByCurrency.keys.sorted(by: { code1, code2 in
                        // Preferred currency first, then by total amount
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
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .foregroundStyle(isSelected ? .white : Color.netoSecondaryText)
                .background(
                    Group {
                        if isSelected {
                            Capsule()
                                .fill(Color.electricIndigo)
                                .matchedGeometryEffect(
                                    id: "cashFlowSelector", in: cashFlowSelectorNamespace)
                        }
                    }
                )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var cashFlowByAccountCarousel: some View {
        // Sort by user-defined order (same as Profile/Accounts view)
        let accountIDs = sortedAccountIDs(Array(cashFlowByAccount.keys))

        if !accountIDs.isEmpty {
            VStack(spacing: DS.Spacing.sm) {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 0) {
                        ForEach(accountIDs, id: \.self) { accountID in
                            if let account = accounts.first(where: {
                                $0.persistentModelID == accountID
                            }),
                                let summary = cashFlowByAccount[accountID]
                            {
                                cashFlowCard(
                                    summary: summary,
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
                    HStack(spacing: 6) {
                        ForEach(Array(accountIDs.enumerated()), id: \.element) { index, accountID in
                            Circle()
                                .fill(
                                    accountCarouselPosition == accountID
                                        ? Color.netoPrimaryText.opacity(0.3)
                                        : Color.netoSecondaryText.opacity(0.2)
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
                    LazyHStack(alignment: .top, spacing: 0) {
                        ForEach(currencyCodes, id: \.self) { currencyCode in
                            if let summary = cashFlowByCurrency[currencyCode] {
                                cashFlowCard(
                                    summary: summary,
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
                    HStack(spacing: 6) {
                        ForEach(currencyCodes, id: \.self) { currencyCode in
                            Circle()
                                .fill(
                                    currencyCarouselPosition == currencyCode
                                        ? Color.netoPrimaryText.opacity(0.3)
                                        : Color.netoSecondaryText.opacity(0.2)
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

    private func cashFlowCard(summary: CashFlowSummary, title: String, currencyCode: String)
        -> some View
    {
        CashFlowWidget(
            summary: summary,
            size: .large,
            period: trendsViewModel.detailPeriod.rawValue,
            grouping: cashFlowGrouping,
            interval: trendsViewModel.panelDateInterval,
            onShowDetail: nil,
            customTitle: title,
            displayMode: convertMetricToTrendType(trendsViewModel.selectedMetric)
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
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.Statistics.latestRecords)
                .font(.headline)
                .foregroundStyle(Color.netoPrimaryText)

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
                        .font(.subheadline.weight(.semibold))
                    Image(systemName: "chevron.right")
                        .font(.caption)
                    Spacer()
                }
                .padding(.vertical, 12)
                .foregroundStyle(Color.electricIndigo)
                .background(Color.electricIndigo.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(DS.Card.padding)
        .background(Color.netoCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
    }

    private var emptyRecordsState: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.title2)
                .foregroundStyle(.tertiary)
            Text(L10n.Records.noRecords)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: - Helpers

    private var currentKPIValue: String {
        // When scrubbing the chart, show the hovered point value (use RAW points)
        if let focusedDate = trendsViewModel.focusedDate,
            let point = trendsViewModel.rawTrendPoints.first(where: {
                Calendar.current.isDate($0.date, inSameDayAs: focusedDate)
            })
        {
            return NetoFormatter.currency(value: point.value, currencyCode: defaultCurrencyCode)
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
        return NetoFormatter.currency(value: value, currencyCode: defaultCurrencyCode)
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

    // MARK: - Chip Data Structures

    private struct AccountChip: Identifiable {
        let id = UUID()
        let name: String
        let count: Int
    }

    private struct CategoryChip: Identifiable {
        let id = UUID()
        let categoryID: PersistentIdentifier
    }

    private struct SubcategoryChip: Identifiable {
        let id = UUID()
        let name: String
        let iconName: String?
        let colorHex: String?
        let subcategoryID: PersistentIdentifier?
    }

    private struct NatureChipData: Identifiable {
        let id = UUID()
        let nature: SubcategoryNature
    }

    private var selectedAccountChips: [AccountChip] {
        guard !trendsViewModel.selectedAccounts.isEmpty else { return [] }
        let selectedAccountsList =
            accounts
            .filter { trendsViewModel.selectedAccounts.contains($0.persistentModelID) }
        guard !selectedAccountsList.isEmpty else { return [] }

        // Return a single chip with the first account name and total count
        if let firstName = selectedAccountsList.first?.name {
            return [AccountChip(name: firstName, count: selectedAccountsList.count)]
        }
        return []
    }

    private var selectedCategoryChips: [CategoryChip] {
        trendsViewModel.selectedCategories.map { CategoryChip(categoryID: $0) }
    }

    private var selectedSubcategoryChips: [SubcategoryChip] {
        var chips: [SubcategoryChip] = []
        for subcategoryID in trendsViewModel.selectedSubcategories {
            // Use allSubcategories Query directly to avoid SwiftData lazy loading issues
            if let subcategory = allSubcategories.first(where: {
                $0.persistentModelID == subcategoryID
            }) {
                // Get parent category color as fallback
                let categoryColor = subcategory.category.colorHex
                chips.append(
                    SubcategoryChip(
                        name: subcategory.name,
                        iconName: subcategory.iconName,
                        colorHex: (subcategory.colorHex?.isEmpty == false
                            ? subcategory.colorHex : nil) ?? categoryColor,
                        subcategoryID: subcategoryID
                    ))
            }
        }
        return chips
    }

    private var selectedNatureChips: [NatureChipData] {
        trendsViewModel.selectedNatures.map { NatureChipData(nature: $0) }
    }

    private struct TagChip: Identifiable {
        let id: PersistentIdentifier
        let tagID: PersistentIdentifier
        let name: String
        let colorHex: String?
    }

    private var selectedTagChips: [TagChip] {
        tags.filter { trendsViewModel.selectedTags.contains($0.persistentModelID) }
            .map {
                TagChip(
                    id: $0.persistentModelID, tagID: $0.persistentModelID, name: $0.name,
                    colorHex: $0.colorHex)
            }
    }

    private var tagsChipText: String? {
        guard !trendsViewModel.selectedTags.isEmpty else { return nil }
        let names = tags.filter { trendsViewModel.selectedTags.contains($0.persistentModelID) }.map
        { $0.name }
        guard !names.isEmpty else { return nil }
        return names.count == 1 ? names.first : "\(names.first ?? "") +\(names.count - 1)"
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
        let fetchedTransactions = try? modelContext.fetch(FetchDescriptor<TransactionItem>())
        let effectiveInterval: DateInterval
        if trendsViewModel.detailPeriod == .allTime {
            let dates = (fetchedTransactions ?? []).map(\.date)
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
            selectedNatures: trendsViewModel.selectedNatures,
            selectedCurrencies: trendsViewModel.selectedCurrencies,
            transactionTypeFilter: .all,
            amountCondition: trendsViewModel.amountCondition,
            searchText: trendsViewModel.searchText,
            dateInterval: interval
        )

        // Filter transactions (reuse fetchedTransactions from above)
        let filtered = FilterService.filterForTrends(
            transactions: fetchedTransactions ?? [],
            accounts: accounts,
            criteria: criteria
        )

        // 1. Calculate TOTAL cash flow data
        cashFlowSummary = CashFlowCalculator.calculateCashFlow(
            transactions: filtered,
            interval: interval,
            grouping: cashFlowGrouping,
            currencyCode: defaultCurrencyCode,
            context: modelContext
        )

        // 2. Calculate cash flow BY ACCOUNT
        var byAccount: [PersistentIdentifier: CashFlowSummary] = [:]
        for account in accounts {
            // Filter transactions for this specific account
            let accountTransactions = filtered.filter { tx in
                tx.account?.persistentModelID == account.persistentModelID
            }

            // Calculate cash flow for this account in its native currency
            let summary = CashFlowCalculator.calculateCashFlow(
                transactions: accountTransactions,
                interval: interval,
                grouping: cashFlowGrouping,
                currencyCode: account.currencyCode,
                context: modelContext
            )

            byAccount[account.persistentModelID] = summary
        }
        cashFlowByAccount = byAccount

        // 3. Calculate cash flow BY CURRENCY
        var byCurrency: [String: CashFlowSummary] = [:]

        // Get unique currencies from filtered transactions
        let currencies = Set(filtered.map { $0.currencyCode })

        for currencyCode in currencies {
            // Filter transactions for this specific currency
            let currencyTransactions = filtered.filter { tx in
                tx.currencyCode == currencyCode
            }

            // Calculate cash flow for this currency
            let summary = CashFlowCalculator.calculateCashFlow(
                transactions: currencyTransactions,
                interval: interval,
                grouping: cashFlowGrouping,
                currencyCode: currencyCode,
                context: modelContext
            )

            byCurrency[currencyCode] = summary
        }
        cashFlowByCurrency = byCurrency
    }

    // MARK: - Period Comparison Data Calculation

    private func calculatePeriodComparisonData() {
        // Skip calculation for All Time period
        guard trendsViewModel.detailPeriod != .allTime else {
            currentPeriodPoints = []
            previousPeriodPoints = []
            comparisonYDomain = 0...1
            return
        }

        let currentInterval = trendsViewModel.panelDateInterval
        let previousInterval = getPreviousPeriodInterval(for: trendsViewModel.detailPeriod)

        // Calculate current period data
        let currentResult = TrendDataProcessor.processTrendData(
            transactions: allTransactions,
            accounts: accounts,
            metric: convertMetricToTrendType(trendsViewModel.selectedMetric),
            period: trendsViewModel.detailPeriod,
            grouping: .day,
            interval: currentInterval,
            currencyCode: defaultCurrencyCode,
            context: modelContext
        )

        // Calculate previous period data
        let previousResult = TrendDataProcessor.processTrendData(
            transactions: allTransactions,
            accounts: accounts,
            metric: convertMetricToTrendType(trendsViewModel.selectedMetric),
            period: trendsViewModel.detailPeriod,
            grouping: .day,
            interval: previousInterval,
            currencyCode: defaultCurrencyCode,
            context: modelContext
        )

        // Update state
        currentPeriodPoints = currentResult.points
        previousPeriodPoints = previousResult.points

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

    private func getPreviousPeriodInterval(for period: DetailPeriod) -> DateInterval {
        let currentInterval = period.dateInterval()
        let duration = currentInterval.duration
        let previousStart = currentInterval.start.addingTimeInterval(-duration)

        // Previous period should end at d-1 (one day before current period starts)
        let calendar = Calendar.current
        let previousEnd =
            calendar.date(byAdding: .day, value: -1, to: currentInterval.start)
            ?? currentInterval.start

        return DateInterval(start: previousStart, end: previousEnd)
    }
}

// MARK: - Compact Record Row

/// Compact record row matching RecentRecordsWidget layout exactly
struct CompactRecordRow: View {
    let record: TransactionItem
    let currencyCode: String

    var body: some View {
        HStack(spacing: 10) {
            // Icon
            subcategoryIcon(size: 36)

            // Left column: Note/Category and Date
            VStack(alignment: .leading, spacing: 2) {
                // Line 1: Note (bold) or Subcategory as fallback
                if let note = record.note, !note.isEmpty {
                    Text(note)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    // Line 2: Subcategory • Date
                    Text(secondaryLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text(record.subcategory?.name ?? record.category?.name ?? L10n.Common.uncategorized)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    // Date as secondary
                    Text(shortDateFormat)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Right column: Amount + Nature
            VStack(alignment: .trailing, spacing: 4) {
                Text(formattedAmount)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(amountColor)

                // Nature indicator (if available)
                if let subcategory = record.subcategory {
                    natureIndicator(for: subcategory.nature)
                }
            }
        }
    }

    // MARK: - Nature Indicator

    private func natureIndicator(for nature: SubcategoryNature) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(nature.color)
                .frame(width: 6, height: 6)

            Text(nature.displayName)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(nature.color.opacity(0.1))
        )
    }

    // MARK: - Subcategory Icon

    private func subcategoryIcon(size iconSize: CGFloat) -> some View {
        let colorHex =
            record.subcategory?.colorHex
            ?? record.category?.colorHex
            ?? "#6366F1"

        let iconName =
            record.subcategory?.iconName
            ?? record.category?.iconName
            ?? "tag.fill"

        return ZStack {
            Circle()
                .fill(Color(hex: colorHex))
                .frame(width: iconSize, height: iconSize)

            Image(systemName: iconName)
                .font(.system(size: iconSize * 0.4))
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

    private var shortDateFormat: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es")
        formatter.dateFormat = "d MMM"
        return formatter.string(from: record.date).replacingOccurrences(of: ".", with: "")
    }

    private var formattedAmount: String {
        NetoFormatter.currency(value: record.amount, currencyCode: record.currencyCode)
    }
}
