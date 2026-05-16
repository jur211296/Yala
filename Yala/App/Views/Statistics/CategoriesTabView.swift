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
    @Bindable var insightsViewModel: InsightsViewModel
    let defaultCurrencyCode: String

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

    // Period Comparison State (comparisonMode is in SessionState for sync across tabs)
    @State private var previousCategoryTotal: Double? = nil
    @State private var previousSubcategoryTotal: Double? = nil
    @State private var previousTagTotal: Double? = nil
    @State private var previousNeedTotal: Double? = nil
    @State private var previousNeedAmounts: [SubcategoryNeed: Double] = [:]

    // Distribution Insight Card (F9b)
    @State private var showUpgradeSheet: Bool = false
    @State private var showInsightsConsentAlert: Bool = false

    // Content mode pill — separa visualizaciones (Gráficas) de tablas (Detalle)
    @State private var contentMode: DistributionContentMode = .charts

    @ScaledMetric(relativeTo: .largeTitle) private var summaryVerticalPadding: CGFloat = 12

    /// Total agregado del período (cache de `categorySpending.reduce`).
    /// Se actualiza en `calculateData()` para evitar O(N) por render del hero.
    @State private var totalAmount: Double = 0

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
        scrollBody
            .sheet(isPresented: $showUpgradeSheet) {
                UpgradePromptSheet(feature: .smartInsightsAI, context: .proFeature)
            }
            .insightsConsentAlert(isPresented: $showInsightsConsentAlert) {
                Task { await insightsViewModel.triggerAIGeneration() }
            }
    }

    @ViewBuilder
    private var scrollBody: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: DS.Spacing.md) {
                heroSummary
                filterBarPanel

                if hasNoData {
                    YalaEmptyState(
                        icon: "chart.pie",
                        title: L10n.Empty.noData
                    )
                    .padding(.top, DS.Spacing.xxxxl)
                } else {
                    LazyVStack(spacing: DS.Spacing.xl) {
                        contentModePill

                        switch contentMode {
                        case .charts:
                            chartsSection
                            sankeyWidget
                            // Need bars no aplican en income mode (need classification es expense-only)
                            if !isIncomeMode {
                                needsLargeSection
                            }
                        case .details:
                            categoriesListSection
                            if !isIncomeMode {
                                needsCompactSection
                            }
                        }

                        distributionInsightCard
                    }
                    .yalaSafeBottomPadding()
                }
            }
            .padding(.top, DS.Spacing.sm)
        }
        .scrollViewGlassEdges()
        .onAppear {
            calculateData()
            recomputeSankey()
        }
        .onChange(of: viewModel.sankeyInputKey) { recomputeSankey() }
        .onChange(of: allTransactions.count) { recomputeSankey() }
        .onChange(of: scheduledPaymentsSignature) { recomputeSankey() }
        .onChange(of: viewModel.detailPeriod) { calculateData() }
        .onChange(of: viewModel.selectedAccounts) { calculateData() }
        .onChange(of: viewModel.selectedCategories) { calculateData() }
        .onChange(of: viewModel.selectedSubcategories) { calculateData() }
        .onChange(of: viewModel.selectedTags) { calculateData() }
        .onChange(of: viewModel.selectedNeeds) {
            calculateData()
            syncNeedFilterToSelection()
        }
        .onChange(of: viewModel.selectedTransactionNatures) { calculateData() }
        .onChange(of: allSubcategories) { calculateData() }
        .onChange(of: selectedNeed) {
            syncSelectionToNeedFilter()
            calculateData()
        }
        .onChange(of: sessionState.customDateRange) { calculateData() }
        .onChange(of: sessionState.comparisonMode) {
            calculatePreviousPeriodTotals()
        }
        .onChange(of: sessionState.selectedTransactionNatures) {
            viewModel.selectedTransactionNatures = sessionState.selectedTransactionNatures
            enforceListViewLock()
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

    // MARK: - Hero Summary (edge-to-edge, paralelo a InsightsTabView/TrendsTabView)

    @ViewBuilder
    private var heroSummary: some View {
        let hasRecords = totalAmount > 0

        VStack(alignment: .center, spacing: DS.Spacing.xs) {
            TrendsPeriodMenu(
                selectedPeriod: viewModel.detailPeriod,
                customDateRange: sessionState.customDateRange,
                onSelect: { sessionState.selectedPeriod = $0 },
                onCustomTapped: { showCustomPeriodPicker = true }
            )
            .equatable()

            if hasRecords {
                AmountText(
                    value: totalAmount,
                    currencyCode: defaultCurrencyCode,
                    size: .hero
                )
                .contentTransition(.numericText())
            }

            if hasRecords, let subtitle = heroDimensionalSubtitle() {
                Text(subtitle)
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

    /// Subtítulo dimensional dinámico. 3 variantes según qué dimensiones tienen data.
    private func heroDimensionalSubtitle() -> String? {
        let catCount = categorySpending.count
        let subCount = subcategorySpending.count
        let tagCount = tagSpending.count
        let activeDims = [catCount > 0, subCount > 0, tagCount > 0].filter { $0 }.count
        switch activeDims {
        case 3: return L10n.Stats.Distribution.heroSubtitle3(catCount, subCount, tagCount)
        case 2 where catCount > 0 && subCount > 0:
            return L10n.Stats.Distribution.heroSubtitle2(catCount, subCount)
        case 1 where catCount > 0:
            return L10n.Stats.Distribution.heroSubtitle1(catCount)
        default: return nil
        }
    }

    // MARK: - Filter Bar (panel style)

    private var filterBarPanel: some View {
        FilterControlBar(
            periodSelector: EmptyView(),
            viewModel: viewModel,
            accounts: accounts,
            categories: categories,
            allSubcategories: allSubcategories,
            tags: tags,
            animationValue: viewModel.detailPeriod,
            panelStyle: true,
            inlinePeriodSelector: false
        )
        .onChange(of: viewModel.hasActiveFilters) {
            if !viewModel.hasActiveFilters { selectedNeed = nil }
        }
    }

    // MARK: - Empty Gating

    /// Empty tab cuando no hay data en ninguna sub-sección.
    private var hasNoData: Bool {
        categorySpending.isEmpty
            && subcategorySpending.isEmpty
            && tagSpending.isEmpty
            && !viewModel.sankeyData.hasFlow
            && needTrendPoints.allSatisfy { $0.total == 0 }
    }

    // MARK: - Analysis Header Section

    /// Header con title dinámico (gasto/ingreso según FilterControlBar global) +
    /// InfoHint + M/A selector. El nature lo controla la FilterControlBar arriba,
    /// no hay toggle propio en esta vista — `isIncomeMode` refleja el filter activo
    /// vía `viewModel.selectedTransactionNatures == [.income]`.
    private var analysisHeaderSection: some View {
        HStack(spacing: DS.Spacing.sm) {
            Text(isIncomeMode ? L10n.Statistics.incomeAnalysis : L10n.Statistics.spendingAnalysis)
                .font(DS.Typography.headline)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            InfoHintButton(
                title: isIncomeMode ? L10n.Statistics.incomeAnalysis : L10n.Statistics.spendingAnalysis,
                message: isIncomeMode ? L10n.Widget.Hint.incomeAnalysis : L10n.Widget.Hint.spendingAnalysis
            )

            Spacer()

            if showComparisonSelector {
                ComparisonModeSelector()
            }
        }
    }

    /// Determines if comparison selector should be visible (only when appPreferences.showVariations is ON)
    private var showComparisonSelector: Bool {
        appPreferences.showVariations && PreviousPeriodHelper.isSelectorVisible(for: viewModel.detailPeriod)
    }

    // MARK: - Content Mode Pill (Gráficas / Detalle)

    private var contentModePill: some View {
        GenericSegmentedPill(
            options: DistributionContentMode.allCases,
            selection: $contentMode,
            labelProvider: { $0.label },
            selectedFillColorProvider: { _ in theme.accent }
        )
    }

    // MARK: - Charts Section (analysisHeader + chartsCarousel)

    /// La sección Charts agrupa los 3 pies (carousel). El analysisHeaderSection
    /// arriba sirve de título — "Análisis del gasto/ingreso" + InfoHint + M/A
    /// selector que controla la comparativa de período mostrada en los pies.
    @ViewBuilder
    private var chartsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            analysisHeaderSection
            chartsCarousel
        }
    }

    /// Number of pages in carousel (siempre 3 pages iPhone; iPad muestra cat+sub en 2-col)
    private var carouselPageCount: Int {
        let isWide = DS.Adaptive.isWideScreen(sizeClass)
        // En iPad: 2 pages (cat+sub side-by-side, luego tag con needs row).
        // En iPhone: 3 pages (cat, sub, tag).
        return isWide ? 2 : 3
    }

    @ViewBuilder
    private var chartsCarousel: some View {
        let isWide = DS.Adaptive.isWideScreen(sizeClass)

        VStack(spacing: DS.Spacing.sm) {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: DS.Spacing.md) {
                    categoryChartCard
                        .containerRelativeFrame(.horizontal, count: isWide ? 2 : 1, spacing: isWide ? DS.Spacing.md : 0)
                        .id("category")

                    subcategoryChartCard
                        .containerRelativeFrame(.horizontal, count: isWide ? 2 : 1, spacing: isWide ? DS.Spacing.md : 0)
                        .id("subcategory")

                    // Tags Chart - on iPad, tags moves next to need (needsLargeSection HStack)
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

            // Page indicator capsule (TX-11) — hide on iPad (multiple charts already visible)
            if !isWide {
                HStack(spacing: DS.Spacing.xs) {
                    ForEach(0..<carouselPageCount, id: \.self) { page in
                        let pageId = carouselPageIds[page]
                        let isActive = chartsCarouselPosition == pageId
                        Capsule()
                            .fill(isActive ? theme.primaryText.opacity(0.6) : theme.secondaryText.opacity(0.25))
                            .frame(width: isActive ? 18 : 6, height: 3)
                            .contentShape(Rectangle().inset(by: -8))
                            .onTapGesture {
                                DS.Haptic.selection()
                                dsWithAnimation(reduceMotion) { chartsCarouselPosition = pageId }
                            }
                            .accessibilityLabel(L10n.Accessibility.pageIndicator(page + 1, carouselPageCount))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    /// IDs for carousel pages. iPad muestra cat+sub side-by-side (page 1) y tag en
    /// la HStack del needsLargeSection. iPhone tiene 3 pages independientes.
    private var carouselPageIds: [String] {
        let isWide = DS.Adaptive.isWideScreen(sizeClass)
        if isWide {
            return ["category", "subcategory"]
        }
        return ["category", "subcategory", "tags"]
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

    // MARK: - Needs Sections (split en Gráficas/Detalle, sin carrusel)

    @ViewBuilder
    private var sankeyWidget: some View {
        if viewModel.sankeyData.hasFlow {
            @Bindable var prefs = appPreferences
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                // Title fuera del card + label mode toggle a la derecha (patrón Trends cashFlowWidget)
                HStack {
                    Text(L10n.Statistics.Sankey.title)
                        .font(DS.Typography.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                    SankeyLabelModeToggle(mode: $prefs.sankeyLabelMode)
                }
                sankeyCardBody.panelCard()
            }
        }
    }

    @ViewBuilder
    private var sankeyCardBody: some View {
        @Bindable var prefs = appPreferences
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            // KPI total estilo Panel-Small header interno
            Text(appPreferences.currency(viewModel.sankeyData.totalExpense, currencyCode: defaultCurrencyCode))
                .font(DS.Typography.headline)
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            SankeyChartView(
                data: viewModel.sankeyData,
                currencyCode: defaultCurrencyCode,
                labelMode: $prefs.sankeyLabelMode,
                selectedCategoryIDs: viewModel.selectedCategories,
                selectedSubcategoryIDs: viewModel.selectedSubcategories,
                onTapCategory: { catID in
                    dsWithAnimation(reduceMotion) { toggleSankeyCategory(catID) }
                },
                onTapSubcategory: { subID in
                    dsWithAnimation(reduceMotion) { toggleSankeySubcategory(subID) }
                }
            )

            if viewModel.shouldShowPlannedHint && viewModel.sankeyData.hasPlannedBranch {
                Text(L10n.Statistics.Sankey.plannedHint)
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
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

    /// Título "Necesidades" fuera del card (patrón consistente entre Large/Compact).
    private var needsHeader: some View {
        HStack {
            Text(L10n.WidgetType.expensesByNeed)
                .font(DS.Typography.headline)
                .foregroundStyle(.primary)
            Spacer()
        }
    }

    /// Sección "Necesidades" en pestaña Gráficas — versión large con barras.
    /// iPad: tags pie + needLarge side-by-side (tag no entra al carousel iPad).
    /// iPhone: solo needLarge (tag vive en carousel iPhone).
    @ViewBuilder
    private var needsLargeSection: some View {
        let isWide = DS.Adaptive.isWideScreen(sizeClass)
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            needsHeader

            if isWide {
                HStack(alignment: .top, spacing: DS.Spacing.lg) {
                    tagChartCard
                        .frame(maxWidth: .infinity)
                    needWidgetLarge
                        .frame(maxWidth: .infinity)
                }
            } else {
                needWidgetLarge
            }
        }
    }

    /// Sección "Necesidades" en pestaña Detalle — versión compact con barras
    /// listadas. Complementa la lista de categorías arriba.
    private var needsCompactSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            needsHeader
            needWidgetCompact
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
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            // Header fuera del card (patrón panel-aligned)
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

            listCardBody.panelCard()
        }
    }

    @ViewBuilder
    private var listCardBody: some View {
        if listViewType == .categories {
            if categorySpending.isEmpty {
                emptyState(
                    icon: "chart.bar.xaxis",
                    title: L10n.Empty.noCategories,
                    subtitle: L10n.Statistics.noDataToShow
                )
                .frame(maxWidth: .infinity, minHeight: 200)
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
                .frame(maxWidth: .infinity, minHeight: 200)
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

    // MARK: - Distribution Insight Card (protagonista AL FINAL, paralelo Trends)
    //
    // V1 limitation documentada: aiInsights.heroText es shared con Trends + Insights
    // (mismo InsightsViewModel.triggerAIGeneration agnóstico a tab). El usuario puede
    // ver "el mismo análisis" cross-tab. V2 dedicará prompt específico de distribución.

    private var isProUser: Bool {
        FeatureGateService.shared.canAccess(.smartInsightsAI)
    }

    @ViewBuilder
    private var distributionInsightCard: some View {
        let txCount = insightsViewModel.insightData?.periodSummary.transactionCount ?? 0
        // Gate: aparece SOLO si tx en período actual >= 5
        if txCount >= 5 {
            if isProUser {
                proDistributionInsightCard
            } else {
                freeDistributionInsightCard
            }
        }
    }

    @ViewBuilder
    private var freeDistributionInsightCard: some View {
        let finding = computeDistributionFinding()

        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "chart.pie")
                    .font(DS.Typography.body)
                    .foregroundStyle(theme.accent)
                    .accessibilityHidden(true)
                Text(L10n.Stats.Distribution.insightTitleFree(periodDisplayName))
                    .font(DS.Typography.subheadlineEmphasized)
                    .foregroundStyle(.primary)
            }

            Text(findingText(finding))
                .font(DS.Typography.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(3)

            Button { showUpgradeSheet = true } label: {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "sparkles").font(DS.Typography.caption)
                    Text(L10n.Stats.Trends.refineWithAI).font(DS.Typography.caption)
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
    private var proDistributionInsightCard: some View {
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

    /// Header consistente entre pre-AI y post-AI (sparkles + título Pro).
    @ViewBuilder
    private var proInsightHeader: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "sparkles")
                .font(DS.Typography.body)
                .foregroundStyle(theme.accent)
                .accessibilityHidden(true)
            Text(L10n.Stats.Distribution.insightTitlePro)
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

            // Footer balanceado: tag identitario izq + chip Regenerar der.
            HStack {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "sparkles")
                        .font(DS.Typography.captionSmall)
                    Text(L10n.Stats.Distribution.aiFootnote)
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
        let finding = computeDistributionFinding()

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
                    Image(systemName: "sparkles").font(DS.Typography.caption)
                    Text(L10n.Stats.Trends.generateAI).font(DS.Typography.caption)
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

    private var periodDisplayName: String {
        viewModel.detailPeriod.displayName
    }

    /// Strip "vs " hardcoded por PreviousPeriodHelper.formatComparisonText.
    private func strippedComparisonLabel(_ label: String) -> String {
        label.hasPrefix("vs ") ? String(label.dropFirst(3)) : label
    }

    private func previousPeriodLabelForInsight() -> String? {
        guard viewModel.detailPeriod != .allTime else { return nil }
        let interval = PreviousPeriodHelper.previousInterval(
            for: viewModel.detailPeriod,
            mode: sessionState.comparisonMode,
            customRange: sessionState.customDateRange
        )
        let raw = PreviousPeriodHelper.formatComparisonText(
            previousInterval: interval,
            period: viewModel.detailPeriod,
            mode: sessionState.comparisonMode
        )
        return strippedComparisonLabel(raw)
    }

    private func computeDistributionFinding() -> DistributionInsightFinding {
        let prevLabel = previousPeriodLabelForInsight()
        let cats: [DistributionCategoryInput] = categorySpending.map {
            DistributionCategoryInput(
                name: $0.category.name,
                amount: $0.amount,
                percentage: $0.percentage,
                previousAmount: $0.previousAmount,
                variation: $0.variation
            )
        }
        let topSub: DistributionTopSubInput? = subcategorySpending.first.map {
            DistributionTopSubInput(
                name: $0.subcategoryName,
                parent: $0.category?.name ?? "",
                percentageOfCategory: $0.percentageOfCategory
            )
        }
        return DistributionInsightLogic.finding(
            categories: cats,
            topSub: topSub,
            previousLabel: prevLabel,
            period: periodDisplayName
        )
    }

    private func findingText(_ finding: DistributionInsightFinding) -> String {
        switch finding {
        case .onset:
            return L10n.Stats.Distribution.Insight.onset(periodDisplayName)
        case .newCategory(let name, let period):
            return L10n.Stats.Distribution.Insight.newCategory(name, period)
        case .concentrated(let percent, let topCat):
            return L10n.Stats.Distribution.Insight.concentrated(percent, topCat)
        case .balanced(let maxPercent):
            return L10n.Stats.Distribution.Insight.balanced(maxPercent)
        case .shifted(let percent, let cat, .up, let prev):
            return L10n.Stats.Distribution.Insight.shiftedUp(percent, cat, prev)
        case .shifted(let percent, let cat, .down, let prev):
            return L10n.Stats.Distribution.Insight.shiftedDown(percent, cat, prev)
        case .topSubFallback(let percent, let sub, let parent):
            return L10n.Stats.Distribution.Insight.topSub(percent, sub, parent)
        }
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
        let newTotal = newCategorySpending.reduce(0) { $0 + $1.amount }
        if newTotal != totalAmount { totalAmount = newTotal }

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

}

// MARK: - DistributionContentMode

/// Pill selector entre visualizaciones (Gráficas) y tablas (Detalle).
/// Reusa `L10n.Stats.Insights.modeDetail` para "Detalle" (idéntico concepto cross-tab).
private enum DistributionContentMode: String, CaseIterable {
    case charts
    case details

    var label: String {
        switch self {
        case .charts:  return L10n.Stats.Distribution.modeCharts
        case .details: return L10n.Stats.Insights.modeDetail
        }
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
        .padding(.bottom, DS.Spacing.md)
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
        .padding(.bottom, DS.Spacing.md)
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
