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
        let indexByName = Dictionary(order.enumerated().map { ($1, $0) },
                                     uniquingKeysWith: { first, _ in first })

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
    @Bindable var insightsViewModel: InsightsViewModel
    let defaultCurrencyCode: String

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

    @State private var weekdaySpending: [WeekdaySpending] = []

    // Custom period picker state
    @State private var showCustomPeriodPicker: Bool = false

    // Debounce task for cashflow + period comparison recalculation.
    // Coalesces rapid onChange bursts (filter changes, bulk transaction inserts).
    @State private var recalcTask: Task<Void, Never>?

    // Trend Insight Card (F4)
    @State private var showUpgradeSheet = false
    @State private var showInsightsConsentAlert = false

    @ScaledMetric(relativeTo: .largeTitle) private var summaryVerticalPadding: CGFloat = 12

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
            VStack(spacing: DS.Spacing.md) {
                heroSummary
                filterBarPanel

                // Hero siempre montado: period menu accesible incluso con 0 tx.
                if hasNoData {
                    YalaEmptyState(
                        icon: "chart.line.uptrend.xyaxis",
                        title: L10n.Empty.noData
                    )
                    .padding(.top, DS.Spacing.xxxxl)
                } else {
                    LazyVStack(spacing: DS.Spacing.xl) {
                        chartsLayout
                        cashFlowWidget
                        weekdayChartSection
                        trendInsightCard            // mueve al final: cierre narrativo
                    }
                    .yalaSafeBottomPadding()
                }
            }
            .padding(.top, DS.Spacing.sm)
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
        .sheet(isPresented: $showUpgradeSheet) {
            UpgradePromptSheet(feature: .smartInsightsAI, context: .proFeature)
        }
        .insightsConsentAlert(isPresented: $showInsightsConsentAlert) {
            Task { await insightsViewModel.triggerAIGeneration() }
        }
    }

    /// Date range of all transactions (for custom period picker limits)
    private var transactionDateRange: (start: Date, end: Date) {
        let sortedDates = allTransactions.map(\.date).sorted()
        let start = sortedDates.first ?? Date.now
        let end = sortedDates.last ?? Date.now
        return (start, end)
    }

    // MARK: - Hero Summary (edge-to-edge, paralelo a InsightsTabView)

    @ViewBuilder
    private var heroSummary: some View {
        let summary = insightsViewModel.insightData?.periodSummary
        let txCount = summary?.transactionCount ?? 0
        let hasRecords = txCount > 0

        VStack(alignment: .center, spacing: DS.Spacing.xs) {
            TrendsPeriodMenu(
                selectedPeriod: trendsViewModel.detailPeriod,
                customDateRange: sessionState.customDateRange,
                onSelect: { sessionState.selectedPeriod = $0 },
                onCustomTapped: { showCustomPeriodPicker = true }
            )
            .equatable()

            if hasRecords, let summary {
                // KPI period-specific (matches Insights hero). Card interno + chart
                // preservan running balance — el hero refleja el agregado del período.
                AmountText(
                    value: heroKPIValue(for: summary),
                    currencyCode: defaultCurrencyCode,
                    font: DS.Typography.heroAmount, secondaryFont: DS.Typography.heroAmountSecondary
                )
                .contentTransition(.numericText())
            }

            if hasRecords, let summary {
                incomeExpenseChips(summary)
            }

            if let summary, let text = heroVariationSubtitle(for: summary) {
                Text(text)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, summaryVerticalPadding)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isHeader)
    }

    /// Subtitle motivacional específico de Trends — describe la variación del
    /// balance del período (no del metric activo). 4 ramas: onset / stable /
    /// up / down. `previousPeriodLabel` viene con prefix "vs " hardcoded en
    /// `PreviousPeriodHelper.formatComparisonText`; lo strippeamos porque las
    /// keys L10n ya incluyen "vs %@" en su forma natural por idioma.
    private func heroVariationSubtitle(for summary: PeriodSummary) -> String? {
        guard summary.transactionCount > 0 else { return nil }

        let prev = strippedComparisonLabel(summary.previousPeriodLabel)

        guard let variation = summary.balanceVariation else {
            // Sin período previo comparable (`.allTime`, primer mes, etc.).
            return L10n.Stats.Trends.heroOnset
        }

        if abs(variation) < 5 {
            return L10n.Stats.Trends.heroStable
        }

        let percent = Int(abs(variation).rounded())
        return variation > 0
            ? L10n.Stats.Trends.heroVarUp(percent, prev)
            : L10n.Stats.Trends.heroVarDown(percent, prev)
    }

    @ViewBuilder
    private func incomeExpenseChips(_ summary: PeriodSummary) -> some View {
        HStack(spacing: DS.Spacing.md) {
            if !sessionState.isExpensesOnlyMode {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "arrow.up.right")
                        .font(DS.Typography.labelSmall)
                        .foregroundStyle(Color.incomeGraph)
                        .accessibilityHidden(true)
                    AmountText(
                        value: summary.totalIncome,
                        currencyCode: defaultCurrencyCode,
                        font: DS.Typography.subheadline, secondaryFont: DS.Typography.captionSmall,
                        tint: .secondary
                    )
                    if appPreferences.showVariations {
                        VariationChip(variation: summary.incomeVariation, size: .small, isExpenseContext: false)
                    }
                }
            }

            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "arrow.down.right")
                    .font(DS.Typography.labelSmall)
                    .foregroundStyle(Color.expenseGraph)
                    .accessibilityHidden(true)
                AmountText(
                    value: summary.totalExpense,
                    currencyCode: defaultCurrencyCode,
                    font: DS.Typography.subheadline, secondaryFont: DS.Typography.captionSmall,
                    tint: .secondary
                )
                if appPreferences.showVariations {
                    VariationChip(variation: summary.expenseVariation, size: .small, isExpenseContext: true)
                }
            }
        }
    }

    // MARK: - Filter Bar (panel style)

    private var filterBarPanel: some View {
        FilterControlBar(
            periodSelector: EmptyView(),
            viewModel: trendsViewModel,
            accounts: accounts,
            categories: categories,
            allSubcategories: allSubcategories,
            tags: tags,
            animationValue: trendsViewModel.detailPeriod,
            panelStyle: true,
            inlinePeriodSelector: false
        )
    }

    // MARK: - Empty Gating

    /// Empty tab cuando no hay data en ninguna sub-sección (incluye cashFlow para
    /// no mostrar empty si solo hay flujo de efectivo agregado).
    private var hasNoData: Bool {
        !hasTrendData
            && !weekdaySpending.contains(where: { $0.average > 0 })
            && cashFlowSummary == nil
    }

    // MARK: - Charts Layout (preserva iPad wide side-by-side)

    @ViewBuilder
    private var chartsLayout: some View {
        let isWide = DS.Adaptive.isWideScreen(sizeClass)
        let hasComparison = appPreferences.showVariations
            && PreviousPeriodHelper.isSelectorVisible(for: trendsViewModel.detailPeriod)

        if isWide && hasComparison {
            HStack(alignment: .top, spacing: DS.Spacing.lg) {
                trendChartSection.frame(maxWidth: .infinity)
                comparisonChartSection.frame(maxWidth: .infinity)
            }
        } else {
            trendChartSection
            if hasComparison {
                comparisonChartSection
            }
        }
    }

    /// Check if there's trend data to display
    private var hasTrendData: Bool {
        !trendsViewModel.trendPoints.isEmpty
    }

    /// Check if there's comparison data to display
    private var hasComparisonData: Bool {
        !currentPeriodPoints.isEmpty
    }

    // MARK: - Trend Chart Section (title + metric selector afuera; header interno simétrico a Comparativa)

    @ViewBuilder
    private var trendChartSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            // Title "Tendencias" + InfoHint + metric selector FUERA del card (consistencia con M/A de Comparativa)
            HStack(spacing: DS.Spacing.xs) {
                Text(L10n.Trend.title)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.primary)
                InfoHintButton(
                    title: L10n.Trend.title,
                    message: L10n.Widget.Hint.trend
                )
                Spacer()
                if !sessionState.isExpensesOnlyMode {
                    metricSelector
                }
            }

            chartCardBody
                .panelCard()
        }
    }

    @ViewBuilder
    private var chartCardBody: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            // Header interno simétrico a comparisonChartBody:
            //   left: trendType.displayName + KPI(.headline) + "vs S/ X" inline
            //   right: VariationChip(.medium) + "vs Abr 26" caption
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(trendsViewModel.selectedMetric.displayName)
                        .font(DS.Typography.subheadlineEmphasized)
                        .foregroundStyle(.thPrimaryText)

                    if hasTrendData {
                        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
                            AmountText(
                                value: currentKPIValue,
                                currencyCode: defaultCurrencyCode,
                                font: DS.Typography.headline
                            )

                            if appPreferences.showVariations
                                && trendsViewModel.detailPeriod != .allTime,
                               let prevTotal = previousPeriodTotal {
                                HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xxs) {
                                    Text("vs")
                                        .font(DS.Typography.caption)
                                        .foregroundStyle(.thSecondaryText)
                                    AmountText(
                                        value: prevTotal,
                                        currencyCode: defaultCurrencyCode,
                                        font: DS.Typography.caption,
                                        tint: .secondary
                                    )
                                }
                            }
                        }
                    }
                }

                Spacer()

                if hasTrendData,
                   appPreferences.showVariations
                    && trendsViewModel.detailPeriod != .allTime {
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
                    chartHeight: 170,
                    liveAnchor: trendsViewModel.trendLiveAnchor
                )
            } else {
                chartEmptyState
            }
        }
    }

    private var chartEmptyState: some View {
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

    // MARK: - Comparison Chart Section (title afuera + M/A derecha + .panelCard)

    @ViewBuilder
    private var comparisonChartSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            // Title FUERA del card + M/A selector a la derecha
            HStack {
                Text(L10n.Stats.Trends.comparisonTitle)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.primary)
                Spacer()
                ComparisonModeSelector()
            }

            comparisonChartBody
                .panelCard()
        }
    }

    @ViewBuilder
    private var comparisonChartBody: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            if hasComparisonData {
                // Header interno: KPI value left + variation chip top-right
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        // Subtítulo principal (simetría con trendChartBody "Saldo/Ingresos/Gastos")
                        Text(periodComparisonTitle)
                            .font(DS.Typography.subheadlineEmphasized)
                            .foregroundStyle(.thPrimaryText)

                        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
                            AmountText(
                                value: currentKPIValue,
                                currencyCode: defaultCurrencyCode,
                                font: DS.Typography.headline
                            )

                            if let prevTotal = previousPeriodTotal {
                                HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xxs) {
                                    Text("vs")
                                        .font(DS.Typography.caption)
                                        .foregroundStyle(.thSecondaryText)
                                    AmountText(
                                        value: prevTotal,
                                        currencyCode: defaultCurrencyCode,
                                        font: DS.Typography.caption,
                                        tint: .secondary
                                    )
                                }
                            }
                        }
                    }

                    Spacer()

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
                    chartHeight: 170,
                    period: trendsViewModel.detailPeriod,
                    comparisonMode: sessionState.comparisonMode
                )
                .padding(.top, DS.Spacing.sm)
            } else {
                chartEmptyState
            }
        }
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

    // MARK: - Trend Insight Card (protagonista única, rule-based Free + AI Pro)

    private var isProUser: Bool {
        FeatureGateService.shared.canAccess(.smartInsightsAI)
    }

    @ViewBuilder
    private var trendInsightCard: some View {
        let txCount = insightsViewModel.insightData?.periodSummary.transactionCount ?? 0

        // Gate: solo aparece con >= 5 tx en período actual
        if txCount >= 5 {
            if isProUser {
                proTrendInsightCard
            } else {
                freeTrendInsightCard
            }
        }
    }

    @ViewBuilder
    private var freeTrendInsightCard: some View {
        let finding = TrendInsightLogic.finding(
            metric: trendsViewModel.selectedMetric,
            currentTotal: currentPeriodTotal,
            previousTotal: previousPeriodTotal
        )

        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(DS.Typography.body)
                    .foregroundStyle(theme.accent)
                    .accessibilityHidden(true)
                Text(L10n.Stats.Trends.insightTitleFree(periodDisplayName))
                    .font(DS.Typography.subheadlineEmphasized)
                    .foregroundStyle(.primary)
            }

            Text(findingText(finding))
                .font(DS.Typography.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(3)

            Button {
                showUpgradeSheet = true
            } label: {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "sparkles")
                        .font(DS.Typography.caption)
                    Text(L10n.Stats.Trends.refineWithAI)
                        .font(DS.Typography.caption)
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.xs)
                .background(theme.accent.opacity(0.12))
                .foregroundStyle(theme.accent)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .panelCard()
    }

    @ViewBuilder
    private var proTrendInsightCard: some View {
        if insightsViewModel.aiActivated {
            if insightsViewModel.isLoadingAI {
                AIInsightCardComponents.loadingPlaceholder(accentColor: theme.accent)
            } else if let aiHero = insightsViewModel.aiInsights?.heroText {
                proAIInsightCard(aiHero: aiHero)
            } else if let error = insightsViewModel.aiError {
                AIInsightCardComponents.errorCard(error)
            }
        } else {
            proPreAIInsightCard
        }
    }

    /// Header consistente entre pre-AI y post-AI (sparkles + "Análisis del período").
    @ViewBuilder
    private var proInsightHeader: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "sparkles")
                .font(DS.Typography.body)
                .foregroundStyle(theme.accent)
                .accessibilityHidden(true)
            Text(L10n.Stats.Trends.insightTitlePro)
                .font(DS.Typography.subheadlineEmphasized)
                .foregroundStyle(.primary)
        }
    }

    @ViewBuilder
    private func proAIInsightCard(aiHero: String) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            proInsightHeader

            Text(AIInsightCardComponents.markdownAttributed(aiHero))
                .font(DS.Typography.subheadline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            // Footer balanceado: tag identitario izquierda + chip "Regenerar" derecha.
            HStack {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "sparkles")
                        .font(DS.Typography.captionSmall)
                    Text(L10n.Stats.Trends.aiFootnote)
                        .font(DS.Typography.captionSmall)
                }
                .foregroundStyle(.secondary)

                Spacer()

                Button {
                    Task { await insightsViewModel.triggerAIGeneration() }
                } label: {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "arrow.clockwise")
                            .font(DS.Typography.caption)
                        Text(L10n.Stats.Trends.regenerate)
                            .font(DS.Typography.caption)
                    }
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.xs)
                    .background(theme.accent.opacity(0.12))
                    .foregroundStyle(theme.accent)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .panelCard()
    }

    @ViewBuilder
    private var proPreAIInsightCard: some View {
        let finding = TrendInsightLogic.finding(
            metric: trendsViewModel.selectedMetric,
            currentTotal: currentPeriodTotal,
            previousTotal: previousPeriodTotal
        )

        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            proInsightHeader

            Text(findingText(finding))
                .font(DS.Typography.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(3)

            Button {
                if appPreferences.aiInsightsConsentAccepted {
                    Task { await insightsViewModel.triggerAIGeneration() }
                } else {
                    showInsightsConsentAlert = true
                }
            } label: {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "sparkles")
                        .font(DS.Typography.caption)
                    Text(L10n.Stats.Trends.generateAI)
                        .font(DS.Typography.caption)
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.xs)
                .background(theme.accent.opacity(0.12))
                .foregroundStyle(theme.accent)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .panelCard()
    }

    /// Mapea TrendInsightFinding → string localizado. La localización vive en el
    /// callsite (helper pure-logic L10n-free).
    private func findingText(_ finding: TrendInsightFinding) -> String {
        let prev = strippedComparisonLabel(comparisonPeriodText)
        let period = periodDisplayName

        switch finding {
        case .onset:
            return L10n.Stats.Trends.Insight.onset(period)
        case .variationUp(let percent, let metric):
            switch metric {
            case .expense: return L10n.Stats.Trends.Insight.varUpExpense(percent, prev)
            case .income:  return L10n.Stats.Trends.Insight.varUpIncome(percent, prev)
            case .balance: return L10n.Stats.Trends.Insight.varUpBalance(percent, prev)
            }
        case .variationDown(let percent, let metric):
            switch metric {
            case .expense: return L10n.Stats.Trends.Insight.varDownExpense(percent, prev)
            case .income:  return L10n.Stats.Trends.Insight.varDownIncome(percent, prev)
            case .balance: return L10n.Stats.Trends.Insight.varDownBalance(percent, prev)
            }
        case .stable(let metric):
            switch metric {
            case .expense: return L10n.Stats.Trends.Insight.stableExpense
            case .income:  return L10n.Stats.Trends.Insight.stableIncome
            case .balance: return L10n.Stats.Trends.Insight.stableBalance
            }
        }
    }

    private var periodDisplayName: String {
        trendsViewModel.detailPeriod.displayName
    }

    /// Strip "vs " hardcoded por `PreviousPeriodHelper.formatComparisonText` —
    /// las keys L10n ya escriben "vs %@" en su forma natural por idioma (JA/ZH
    /// reordenan posicional). El strip evita "vs vs".
    private func strippedComparisonLabel(_ label: String) -> String {
        label.hasPrefix("vs ") ? String(label.dropFirst(3)) : label
    }

    // MARK: - Cash Flow Widget (title + selector afuera, widget interno preserva su card)

    @ViewBuilder
    private var cashFlowWidget: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            // Header FUERA del widget (root VStack global da padding)
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

            // Contenido NO envuelto — CashFlowWidget interno ya tiene su .solidCard(radius: DS.Panel.widgetRadius)
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
            displayMode: mapMetricToTrendType(trendsViewModel.selectedMetric),
            previousAmount: previousTotal,
            comparisonPeriodText: appPreferences.showVariations && trendsViewModel.detailPeriod != .allTime ? comparisonPeriodText : nil,
            showInfoHint: false
        )
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

    // MARK: - Helpers

    /// KPI period-specific para el hero (matches `InsightsTabView.heroSummary`).
    /// Distinto de `currentKPIValue` que para `.balance` retorna el running balance
    /// final del chart (global, no responde al período). El hero usa el agregado del
    /// período para coherencia cross-tab y para que el largeTitle responda al filtro.
    private func heroKPIValue(for summary: PeriodSummary) -> Double {
        switch trendsViewModel.selectedMetric {
        case .balance: return summary.netBalance
        case .income:  return summary.totalIncome
        case .expense: return summary.totalExpense
        }
    }

    private var currentKPIValue: Double {
        // When scrubbing the chart, show the hovered point value (use RAW points)
        if let focusedDate = trendsViewModel.focusedDate,
            let point = trendsViewModel.rawTrendPoints.first(where: {
                Calendar.current.isDate($0.date, inSameDayAs: focusedDate)
            })
        {
            return point.value
        }

        // Otherwise, show metric-specific KPI
        switch trendsViewModel.selectedMetric {
        case .balance:
            // Balance: show the last RAW chart point value (actual end balance, not smoothed)
            return trendsViewModel.rawTrendPoints.last?.value ?? 0
        case .income:
            // Income: show TOTAL income for the period
            return trendsViewModel.totalIncome
        case .expense:
            // Expense: show TOTAL expense for the period
            return trendsViewModel.totalExpense
        }
    }

    private func mapMetricToTrendType(_ metric: TrendMetric) -> TrendType {
        switch metric {
        case .balance: return .balance
        case .income: return .income
        case .expense: return .expense
        }
    }

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

    // MARK: - Weekday Chart Section (title afuera + header interno con KPI estilo Panel-Small)

    @ViewBuilder
    private var weekdayChartSection: some View {
        if weekdaySpending.contains(where: { $0.average > 0 }) {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                // Title de sección FUERA del card (consistencia con Tendencias/Comparativa)
                HStack(spacing: DS.Spacing.xs) {
                    Text(L10n.Insights.weekdayAverage)
                        .font(DS.Typography.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                }

                weekdayCardBody
                    .panelCard()
            }
        }
    }

    @ViewBuilder
    private var weekdayCardBody: some View {
        // Promedio semanal = suma de averages por día (mismo cálculo que Panel small).
        let weeklyAverage = weekdaySpending.reduce(0) { $0 + $1.average }
        let topDay = weekdaySpending.filter { $0.average > 0 }.max(by: { $0.average < $1.average })

        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            // Header interno simétrico a Trend + Comparativa
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(L10n.Panel.WeekdayBar.smallTitle)
                        .font(DS.Typography.subheadlineEmphasized)
                        .foregroundStyle(.thPrimaryText)

                    HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
                        AmountText(
                            value: weeklyAverage,
                            currencyCode: defaultCurrencyCode,
                            font: DS.Typography.headline, secondaryFont: DS.Typography.caption
                        )
                        Text(L10n.Panel.WeekdayBar.perWeekSuffix)
                            .font(DS.Typography.caption)
                            .foregroundStyle(.thSecondaryText)
                    }
                }

                Spacer()

                // Día pico top-right como info secundaria (paralelo a VariationChip+caption)
                if let top = topDay {
                    VStack(alignment: .trailing, spacing: DS.Spacing.xxs) {
                        Text(top.weekdayLongName.capitalized)
                            .font(DS.Typography.subheadline)
                            .foregroundStyle(.thPrimaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        AmountText(
                            value: top.average,
                            currencyCode: defaultCurrencyCode,
                            font: DS.Typography.caption, secondaryFont: DS.Typography.captionSmall,
                            tint: .secondary
                        )
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(L10n.Panel.WeekdayBar.smallTitle): \(top.weekdayLongName.capitalized)")
                }
            }

            WeekdayBarChart(
                data: weekdaySpending,
                currencyCode: defaultCurrencyCode,
                chartHeight: 140
            )
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

        // Override solo en current; previous siempre histórico.
        let trendType = mapMetricToTrendType(trendsViewModel.selectedMetric)
        let liveBalanceOverride = LiveBalanceCalculator.liveBalanceOverride(
            for: trendType,
            interval: currentInterval,
            accounts: eligibleAccounts,
            transactions: allTransactions,
            preferredCurrencyCode: defaultCurrencyCode
        )

        // Calculate current period data
        let currentResult = TrendDataProcessor.processTrendData(
            transactions: filteredTransactions,
            accounts: eligibleAccounts,
            metric: trendType,
            period: trendsViewModel.detailPeriod,
            grouping: .day,
            interval: currentInterval,
            currencyCode: defaultCurrencyCode,
            liveBalanceOverride: liveBalanceOverride
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

        // Calculate previous period data — siempre histórico, sin override.
        let previousResult = TrendDataProcessor.processTrendData(
            transactions: previousFiltered,
            accounts: eligibleAccounts,
            metric: trendType,
            period: trendsViewModel.detailPeriod,
            grouping: .day,
            interval: previousInterval,
            currencyCode: defaultCurrencyCode
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
