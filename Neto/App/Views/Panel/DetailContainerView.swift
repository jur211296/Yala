//
//  DetailContainerView.swift
//  Neto
//
//  Unified container for Trends, Categories, and Records with shared navigation.
//

import Charts
import SwiftData
import SwiftUI

// MARK: - Detail Container View

/// Unified container view providing chip-based navigation between Trends, Categories, and Records.
/// Uses RecordsListView's toolbar design and RecordsViewModel for filter state.
struct DetailContainerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(SessionState.self) private var sessionState

    // MARK: - Data Queries

    @Query(sort: \TransactionItem.date, order: .reverse)
    private var allTransactions: [TransactionItem]

    @Query(sort: \Account.name) private var accounts: [Account]
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @Query(sort: \Tag.name) private var tags: [Tag]

    // MARK: - ViewModels

    @State private var recordsViewModel: RecordsViewModel
    @State private var trendsViewModel: TrendsDetailViewModel

    // MARK: - Navigation State

    @State private var selectedTab: DetailViewTab = .records
    @Namespace private var metricNamespace

    // MARK: - UI State

    @State private var showDeleteConfirmation = false
    @State private var showMultiEditPlaceholder = false
    @State private var isPresentingSettings = false

    @AppStorage("defaultCurrencyCode") private var defaultCurrencyCode: String = CurrencyCode.pen
        .rawValue

    // MARK: - Initialization

    init(context: RecordsFilterContext = .empty, initialTab: DetailViewTab = .records) {
        // Note: We now use SessionState as the sole source of truth for global filters
        // (accounts, categories, natures). The context is only used for initial period.
        var cleanContext = context
        cleanContext.period = .thisMonth
        cleanContext.accountID = nil  // Ignore - SessionState is source of truth
        cleanContext.categoryID = nil  // Ignore - SessionState is source of truth
        cleanContext.nature = nil  // Ignore - SessionState is source of truth
        _recordsViewModel = State(initialValue: RecordsViewModel(context: cleanContext))

        // Create TrendsDetailContext without filter values (synced from SessionState on appear)
        let trendsContext = TrendsDetailContext(
            initialMetric: .balance,
            period: .thisMonth,
            accountID: nil,  // Synced from SessionState
            categoryID: nil,  // Synced from SessionState
            subcategoryName: nil,
            nature: nil,  // Synced from SessionState
            dateInterval: nil
        )
        _trendsViewModel = State(initialValue: TrendsDetailViewModel(context: trendsContext))
        _selectedTab = State(initialValue: initialTab)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            PanelBackgroundView()

            VStack(spacing: 0) {
                // Navigation Chips (always visible)
                navigationChipsBar
                    .padding(.vertical, 8)

                // Content based on selected tab
                Group {
                    switch selectedTab {
                    case .trends:
                        trendsContentView
                    case .categories:
                        categoriesPlaceholder
                    case .records:
                        recordsContentView
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // Floating Action Button for new record (only for Records)
            if selectedTab == .records && !recordsViewModel.isSelectionMode {
                newRecordFAB
            }

            // Selection action bar
            if recordsViewModel.isSelectionMode && !recordsViewModel.selectedRecordIDs.isEmpty {
                selectionActionBar
            }
        }
        // Navigation title handled by parent StatisticsView
        .toolbar {
            if recordsViewModel.isSelectionMode {
                selectionModeToolbar
            } else {
                normalModeToolbar
            }
        }
        .navigationBarBackButtonHidden(recordsViewModel.isSelectionMode)
        .tint(.primary)
        .sheet(isPresented: $recordsViewModel.showFiltersSheet) {
            RecordsFiltersView(viewModel: recordsViewModel)
                .onDisappear {
                    refreshRecordsData()
                }
        }
        .sheet(isPresented: $recordsViewModel.showNewTransaction) {
            NewTransactionView()
                .onDisappear {
                    refreshRecordsData()
                }
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
            TrendsFiltersView(viewModel: trendsViewModel)
        }
        .confirmationDialog(
            "¿Eliminar \(recordsViewModel.selectedRecordIDs.count) registro(s)?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Eliminar", role: .destructive) {
                recordsViewModel.deleteSelected(context: modelContext)
                refreshRecordsData()
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Esta acción no se puede deshacer.")
        }
        .alert("Edición múltiple", isPresented: $showMultiEditPlaceholder) {
            Button("Entendido", role: .cancel) {}
        } message: {
            Text("La edición múltiple estará disponible próximamente.")
        }
        .sheet(isPresented: $isPresentingSettings) {
            ProfileView()
        }
        // Bi-directional Filter Synchronization & Data Refresh
        .onRecordsFilterChange(viewModel: recordsViewModel) {
            refreshRecordsData()
            syncFiltersToTrends()
            syncToSessionState()  // Sync to global state
        }
        .onTrendsFilterChange(viewModel: trendsViewModel) {
            calculateTrendsData()
            syncFiltersToRecords()
            syncToSessionState()  // Sync to global state
        }
        .onAppear {
            // Sync all filters from SessionState -> Local ViewModels
            syncFromSessionState()
            refreshRecordsData()
            calculateTrendsData()
        }
        .onChange(of: sessionState.selectedPeriod) {
            // Sync Session -> Local
            syncFromSessionState()
        }
        .onChange(of: sessionState.selectedAccountIDs) {
            // Sync from Panel filter changes
            syncFromSessionState()
            calculateTrendsData()
            refreshRecordsData()
        }
        .onChange(of: sessionState.selectedCategoryIDs) {
            // Sync from Panel filter changes
            syncFromSessionState()
            calculateTrendsData()
            refreshRecordsData()
        }
        .onChange(of: sessionState.selectedNatures) {
            // Sync from Panel filter changes
            syncFromSessionState()
            calculateTrendsData()
            refreshRecordsData()
        }
        .onChange(of: trendsViewModel.selectedMetric) { _, _ in
            calculateTrendsData()
        }
        .onChange(of: trendsViewModel.isAggregatedView) { _, _ in
            calculateTrendsData()
        }
        .onChange(of: trendsViewModel.detailPeriod) { _, _ in
            calculateTrendsData()
        }
        .onChange(of: recordsViewModel.searchText) {
            refreshRecordsData()
        }
    }

    // MARK: - Navigation Chips Bar

    private var navigationChipsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(DetailViewTab.allCases) { tab in
                    navigationChipButton(for: tab)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func navigationChipButton(for tab: DetailViewTab) -> some View {
        let isSelected = selectedTab == tab

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = tab
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: tab.icon)
                    .font(.subheadline)
                Text(tab.rawValue)
                    .font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .foregroundStyle(isSelected ? .white : .primary)
            .background(
                Capsule()
                    .fill(isSelected ? Color.electricIndigo : Color.clear)
            )
            .overlay(
                Capsule()
                    .stroke(Color.netoSecondaryText.opacity(0.2), lineWidth: isSelected ? 0 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Normal Mode Toolbar

    @ToolbarContentBuilder
    private var normalModeToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            HStack(spacing: 16) {
                // Selection button (only for Records) - leftmost
                if selectedTab == .records {
                    Button {
                        recordsViewModel.enterSelectionMode()
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(Color.electricIndigo)
                    }
                }

                // Filters button - middle
                Button {
                    if selectedTab == .records {
                        recordsViewModel.showFiltersSheet = true
                    } else {
                        trendsViewModel.showFiltersSheet = true
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color.electricIndigo)
                }
                .overlay(alignment: .topTrailing) {
                    if selectedTab == .records && recordsViewModel.activeFilterCount > 0 {
                        Circle()
                            .fill(Color.hotPink)
                            .frame(width: 8, height: 8)
                            .offset(x: 2, y: -2)
                    }
                }

                // Profile button - rightmost
                Button {
                    isPresentingSettings = true
                } label: {
                    Image(systemName: "person.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color.electricIndigo)
                }
            }
        }
    }

    // MARK: - Selection Mode Toolbar

    @ToolbarContentBuilder
    private var selectionModeToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Cancelar") {
                recordsViewModel.exitSelectionMode()
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            Button("Seleccionar todo") {
                recordsViewModel.selectAll()
            }
        }
    }

    // MARK: - Trends Content

    private var trendsContentView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 20) {
                controlBar
                chartCard
                recentRecordsSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
    }

    // MARK: - Control Bar (Period Selector + Filter Chips)

    private var controlBar: some View {
        HStack(spacing: 12) {
            // Period dropdown on the left
            periodSelector

            // Filter chips scrollable area
            if trendsViewModel.hasActiveFilters {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        // Account chips - "First +x" format
                        if let chipText = accountsChipText(for: trendsViewModel.selectedAccounts) {
                            FilterChipView(text: chipText) {
                                trendsViewModel.selectedAccounts.removeAll()
                            }
                        }

                        // Category chips - "First +x" format
                        if let chipText = categoriesChipText(
                            categories: trendsViewModel.selectedCategories,
                            subcategories: trendsViewModel.selectedSubcategories
                        ) {
                            FilterChipView(text: chipText) {
                                trendsViewModel.selectedCategories.removeAll()
                                trendsViewModel.selectedSubcategories.removeAll()
                            }
                        }

                        // Tag chips - "First +x" format
                        if let chipText = tagsChipText(for: trendsViewModel.selectedTags) {
                            FilterChipView(text: chipText) {
                                trendsViewModel.selectedTags.removeAll()
                            }
                        }

                        // Nature chips - "First +x" format
                        if let chipText = naturesChipText(for: trendsViewModel.selectedNatures) {
                            FilterChipView(text: chipText) {
                                trendsViewModel.selectedNatures.removeAll()
                            }
                        }

                        // Clear All button if many filters
                        if trendsViewModel.activeFilterCount > 1 {
                            Button {
                                withAnimation {
                                    trendsViewModel.clearFilters()
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
        // Disable layout animation when period changes to prevent clipping
        .animation(nil, value: trendsViewModel.detailPeriod)
    }

    private var metricSelector: some View {
        HStack(spacing: 0) {
            ForEach(TrendMetric.allCases) { metric in
                metricButton(for: metric)
            }
        }
        .padding(3)
        .background(Color.netoSecondaryText.opacity(0.08))
        .clipShape(Capsule())
    }

    private func metricButton(for metric: TrendMetric) -> some View {
        let isSelected = trendsViewModel.selectedMetric == metric

        return Button {
            // Don't use withAnimation here - chart handles its own animation
            // when data changes via onChange -> calculateTrendsData
            trendsViewModel.selectedMetric = metric
        } label: {
            HStack(spacing: 4) {
                Image(systemName: metric.iconName)
                    .font(.caption.weight(.semibold))
                if isSelected {
                    Text(metric.rawValue)
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

    private var periodSelector: some View {
        TrendsPeriodMenu(
            selectedPeriod: trendsViewModel.detailPeriod,  // Display local state
            onSelect: { period in
                // Update Session (triggers onChange)
                sessionState.selectedPeriod = period
            }
        )
        .equatable()
    }

    // MARK: - Filter Chips

    @ViewBuilder

    // MARK: - Chart Card

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with KPI
            chartHeader

            // Chart using TrendChartView (same as Panel)
            if trendsViewModel.isAggregatedView {
                TrendChartView(
                    trendPoints: trendsViewModel.trendPoints,
                    yDomain: trendsViewModel.yDomain,
                    grouping: mapPeriodToGrouping(trendsViewModel.detailPeriod),
                    interval: trendsViewModel.currentInterval,
                    currencyCode: defaultCurrencyCode,
                    trendType: mapMetricToTrendType(trendsViewModel.selectedMetric),
                    focusedDate: $trendsViewModel.focusedDate,
                    period: trendsViewModel.detailPeriod,
                    chartHeight: 220
                )
                .padding(.top, 8)
            } else {
                perAccountChart
            }
        }
        .padding(20)
        .background(Color.netoCard)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.xLarge, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.xLarge, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
    }

    private var chartHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(chartTitle)
                    .font(.headline)
                    .foregroundStyle(Color.netoPrimaryText)

                // Prominent KPI Value
                Text(currentKPIValue)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(kpiValueColor)
                    .padding(.top, 4)
            }

            Spacer()

            // Metric selector moved to top-right of chart
            metricSelector
        }
    }

    private var currentKPIValue: String {
        // Show the value for the focused date if scrubbing
        if let focusedDate = trendsViewModel.focusedDate,
            let point = trendsViewModel.trendPoints.first(where: {
                Calendar.current.isDate($0.date, inSameDayAs: focusedDate)
            })
        {
            return NetoFormatter.currency(value: point.value, currencyCode: defaultCurrencyCode)
        }

        // Otherwise logic depends on metric type
        let value: Double
        switch trendsViewModel.selectedMetric {
        case .balance:
            // For Balance: Show the latest balance value
            value = trendsViewModel.trendPoints.last?.value ?? 0
        case .income:
            // For Income: Show TOTAL income for the period
            value = trendsViewModel.totalIncome
        case .expense:
            // For Expense: Show TOTAL expense for the period (absolute value)
            value = abs(trendsViewModel.totalExpense)
        }
        return NetoFormatter.currency(value: value, currencyCode: defaultCurrencyCode)
    }

    private var kpiValueColor: Color {
        // Always use primary text color like in widget
        return Color.netoPrimaryText
    }

    private func mapPeriodToGrouping(_ period: DetailPeriod) -> TrendGrouping {
        // Always use day grouping so chart data reaches today
        // The x-axis will still display appropriate labels (months for year, days for week/month)
        return .day
    }

    private func mapMetricToTrendType(_ metric: TrendMetric) -> TrendType {
        switch metric {
        case .balance: return .balance
        case .income: return .income
        case .expense: return .expense
        }
    }

    private var chartTitle: String {
        switch trendsViewModel.selectedMetric {
        case .balance: return L10n.Trend.balanceTitle
        case .income: return L10n.Trend.incomeTitle
        case .expense: return L10n.Trend.expenseTitle
        }
    }

    private var viewModeToggle: some View {
        HStack(spacing: 0) {
            Button {
                withAnimation { trendsViewModel.isAggregatedView = true }
            } label: {
                Image(systemName: "chart.xyaxis.line")
                    .font(.caption2.bold())
                    .frame(width: 28, height: 28)
                    .foregroundStyle(trendsViewModel.isAggregatedView ? .primary : .secondary)
                    .background(trendsViewModel.isAggregatedView ? Color.white : Color.clear)
                    .clipShape(Circle())
                    .shadow(
                        color: trendsViewModel.isAggregatedView ? .black.opacity(0.1) : .clear,
                        radius: 2, x: 0, y: 1)
            }
            .buttonStyle(.plain)

            Button {
                withAnimation { trendsViewModel.isAggregatedView = false }
            } label: {
                Image(systemName: "person.2.fill")
                    .font(.caption2.bold())
                    .frame(width: 28, height: 28)
                    .foregroundStyle(!trendsViewModel.isAggregatedView ? .primary : .secondary)
                    .background(!trendsViewModel.isAggregatedView ? Color.white : Color.clear)
                    .clipShape(Circle())
                    .shadow(
                        color: !trendsViewModel.isAggregatedView ? .black.opacity(0.1) : .clear,
                        radius: 2, x: 0, y: 1)
            }
            .buttonStyle(.plain)
        }
        .padding(2)
        .background(Color.netoSecondaryText.opacity(0.1))
        .clipShape(Capsule())
    }

    private func formatAxisDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = AppLocale.current
        switch trendsViewModel.detailPeriod {
        case .thisWeek, .last7Days:
            formatter.dateFormat = "EEE"
        case .thisMonth, .lastMonth, .last30Days:
            formatter.dateFormat = "d"
        case .thisYear, .lastYear, .allTime:
            formatter.dateFormat = "MMM"
        }
        return formatter.string(from: date)
    }

    // MARK: - Per-Account Chart

    private var perAccountChart: some View {
        VStack(spacing: 8) {
            Chart {
                ForEach(trendsViewModel.accountSeries) { series in
                    ForEach(series.points, id: \.date) { point in
                        LineMark(
                            x: .value("Fecha", point.date),
                            y: .value("Monto", point.value)
                        )
                        .foregroundStyle(series.color)
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    }
                }
            }
            .chartYScale(domain: trendsViewModel.yDomain)
            .chartXScale(
                domain: trendsViewModel.currentInterval.start...trendsViewModel.currentInterval.end
            )
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine(stroke: StrokeStyle(dash: [5, 5]))
                        .foregroundStyle(Color.netoSecondaryText.opacity(0.2))
                    if let doubleValue = value.as(Double.self) {
                        AxisValueLabel {
                            Text(NetoFormatter.compactCurrency(value: doubleValue))
                                .font(.caption2)
                                .foregroundStyle(Color.netoSecondaryText)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { value in
                    AxisGridLine()
                        .foregroundStyle(Color.netoSecondaryText.opacity(0.1))
                }
            }
            .frame(height: 180)

            // Legend
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(trendsViewModel.accountSeries) { series in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(series.color)
                                .frame(width: 8, height: 8)
                            Text(series.accountName)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Recent Records Section

    private var recentRecordsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.Records.latest)
                .font(.headline)
                .foregroundStyle(Color.netoPrimaryText)

            if trendsViewModel.recentRecords.isEmpty {
                emptyTrendsRecordsState
            } else {
                ForEach(trendsViewModel.recentRecords.prefix(5), id: \.persistentModelID) {
                    record in
                    recordRow(for: record)
                }
            }

            // "Ver todos" button
            Button {
                withAnimation {
                    selectedTab = .records
                }
            } label: {
                HStack {
                    Spacer()
                    Text("Ver todos")
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
        .padding(20)
        .background(Color.netoCard)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.xLarge, style: .continuous))
    }

    private func recordRow(for record: TransactionItem) -> some View {
        HStack(spacing: 12) {
            // Category icon
            ZStack {
                Circle()
                    .fill(subcategoryColor(for: record).opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: subcategoryIcon(for: record))
                    .font(.callout)
                    .foregroundStyle(subcategoryColor(for: record))
            }

            // Details
            VStack(alignment: .leading, spacing: 3) {
                if let note = record.note, !note.isEmpty {
                    // Line 1: Note
                    Text(note)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.primary)
                        .lineLimit(1)

                    // Line 2: Category • Account
                    let categoryName =
                        record.subcategory?.name ?? record.category?.name ?? "Sin categoría"
                    let accountName = record.account?.name ?? ""

                    Text("\(categoryName) • \(accountName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    // Fallback Line 1: Category
                    Text(record.subcategory?.name ?? record.category?.name ?? "Sin categoría")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.primary)
                        .lineLimit(1)

                    // Fallback Line 2: Account
                    if let account = record.account {
                        Text(account.name)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            // Right Column: Amount + Date
            VStack(alignment: .trailing, spacing: 4) {
                Text(
                    record.amount,
                    format: .currency(code: defaultCurrencyCode).precision(.fractionLength(0))
                )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(record.amount >= 0 ? Color.electricIndigo : Color.hotPink)

                Text(formatRecordDate(record.date))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func formatRecordDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = AppLocale.current
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }

    private func subcategoryColor(for record: TransactionItem) -> Color {
        if let subcategory = record.subcategory {
            return Color(hex: subcategory.colorHex ?? subcategory.category.colorHex)
        }
        return .gray
    }

    private func subcategoryIcon(for record: TransactionItem) -> String {
        guard let category = record.subcategory?.category else { return "circle" }
        return category.isIncome ? "arrow.down" : "arrow.up"
    }

    private var emptyTrendsRecordsState: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text")
                .font(.title2)
                .foregroundStyle(.secondary.opacity(0.5))
            Text("No hay registros recientes")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    // MARK: - Categories Placeholder

    private var categoriesPlaceholder: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "chart.pie")
                .font(.largeTitle)
                .foregroundStyle(.secondary.opacity(0.5))
            Text("Próximamente")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
            Text("La vista de categorías estará disponible en una futura actualización.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }

    // MARK: - Records Content

    private var recordsContentView: some View {
        VStack(spacing: 0) {
            // Control bar with period selector
            recordsControlBar
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

            // Records list
            if recordsViewModel.groupedRecords.isEmpty {
                emptyRecordsState
            } else {
                recordsList
            }
        }
    }

    private var recordsControlBar: some View {
        HStack(spacing: 12) {
            // Period dropdown on the left
            recordsPeriodSelector

            // Filter chips scrollable area
            if recordsViewModel.hasActiveFilters {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        // Account chips - "First +x" format
                        if let chipText = accountsChipText(for: recordsViewModel.selectedAccounts) {
                            FilterChipView(text: chipText) {
                                recordsViewModel.selectedAccounts.removeAll()
                                refreshRecordsData()
                            }
                        }

                        // Category chips - "First +x" format
                        if let chipText = categoriesChipText(
                            categories: recordsViewModel.selectedCategories,
                            subcategories: recordsViewModel.selectedSubcategories
                        ) {
                            FilterChipView(text: chipText) {
                                recordsViewModel.selectedCategories.removeAll()
                                recordsViewModel.selectedSubcategories.removeAll()
                                refreshRecordsData()
                            }
                        }

                        // Tag chips - "First +x" format
                        if let chipText = tagsChipText(for: recordsViewModel.selectedTags) {
                            FilterChipView(text: chipText) {
                                recordsViewModel.selectedTags.removeAll()
                                refreshRecordsData()
                            }
                        }

                        // Nature chips - "First +x" format
                        if let chipText = naturesChipText(for: recordsViewModel.selectedNatures) {
                            FilterChipView(text: chipText) {
                                recordsViewModel.selectedNatures.removeAll()
                                refreshRecordsData()
                            }
                        }

                        // Transaction Type chip (single value, no +x)
                        if recordsViewModel.transactionTypeFilter != .all {
                            FilterChipView(text: recordsViewModel.transactionTypeFilter.displayName)
                            {
                                recordsViewModel.transactionTypeFilter = .all
                                refreshRecordsData()
                            }
                        }

                        // Clear All button if many filters
                        if recordsViewModel.activeFilterCount > 1 {
                            Button {
                                withAnimation {
                                    recordsViewModel.clearFilters()
                                    refreshRecordsData()
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
        // Disable layout animation when period changes
        .animation(nil, value: recordsViewModel.period)
    }

    private var recordsPeriodSelector: some View {
        TrendsPeriodMenu(
            selectedPeriod: recordsViewModel.period,
            onSelect: { period in
                withTransaction(Transaction(animation: nil)) {
                    recordsViewModel.period = period
                }
            }
        )
        .equatable()
    }

    private var recordsList: some View {
        ScrollView {
            LazyVStack(spacing: 8, pinnedViews: [.sectionHeaders]) {
                ForEach(recordsViewModel.groupedRecords, id: \.date) { group in
                    Section {
                        ForEach(group.records, id: \.persistentModelID) { record in
                            RecordRowView(
                                record: record,
                                currencyCode: defaultCurrencyCode,
                                isSelectionMode: recordsViewModel.isSelectionMode,
                                isSelected: recordsViewModel.selectedRecordIDs.contains(
                                    record.persistentModelID),
                                onTap: {
                                    recordsViewModel.editRecord(record)
                                },
                                onToggleSelection: {
                                    recordsViewModel.toggleSelection(record.persistentModelID)
                                }
                            )
                            .padding(.horizontal, 16)
                        }
                    } header: {
                        RecordDateSectionView(date: group.date)
                    }
                }
            }
            .padding(.top, 8)
            .padding(.bottom, recordsViewModel.isSelectionMode ? 80 : 100)
        }
    }

    private var emptyRecordsState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "list.bullet.rectangle")
                .font(.largeTitle)
                .foregroundStyle(.secondary.opacity(0.5))

            Text("No hay registros")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)

            Text(
                recordsViewModel.hasActiveFilters
                    ? "No se encontraron registros con los filtros aplicados."
                    : "Cuando registres movimientos, aparecerán aquí."
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 40)

            if recordsViewModel.hasActiveFilters {
                Button {
                    recordsViewModel.clearFilters()
                    refreshRecordsData()
                } label: {
                    Text("Limpiar filtros")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.electricIndigo)
                }
                .padding(.top, 8)
            }

            Spacer()
        }
    }

    // MARK: - Chip Text Helpers ("First +x" format)

    /// Returns chip text for accounts in "First +x" format (e.g., "BCP +2")
    /// Returns nil if no accounts selected
    private func accountsChipText(for selectedIDs: Set<PersistentIdentifier>) -> String? {
        guard !selectedIDs.isEmpty else { return nil }
        let selectedNames = accounts.filter { selectedIDs.contains($0.persistentModelID) }.map {
            $0.name
        }
        guard !selectedNames.isEmpty else { return nil }
        if selectedNames.count == 1 {
            return selectedNames.first
        }
        return "\(selectedNames.first ?? "") +\(selectedNames.count - 1)"
    }

    /// Returns chip text for categories/subcategories in "First +x" format
    /// Returns nil if none selected
    private func categoriesChipText(
        categories: Set<PersistentIdentifier>,
        subcategories: Set<PersistentIdentifier>
    ) -> String? {
        // Collect all names from selected categories and subcategories
        var names: [String] = []
        for cat in self.categories where categories.contains(cat.persistentModelID) {
            names.append(cat.name)
        }
        // Note: subcategories come from Query if needed, but for simplicity use category names
        guard !names.isEmpty || !subcategories.isEmpty else { return nil }

        let totalCount = categories.count + subcategories.count
        if totalCount == 1 {
            return names.first ?? "Categoría"
        }
        return "\(names.first ?? "Categorías") +\(totalCount - 1)"
    }

    /// Returns chip text for tags in "First +x" format
    /// Returns nil if no tags selected
    private func tagsChipText(for selectedIDs: Set<PersistentIdentifier>) -> String? {
        guard !selectedIDs.isEmpty else { return nil }
        let selectedNames = tags.filter { selectedIDs.contains($0.persistentModelID) }.map {
            $0.name
        }
        guard !selectedNames.isEmpty else { return nil }
        if selectedNames.count == 1 {
            return selectedNames.first
        }
        return "\(selectedNames.first ?? "") +\(selectedNames.count - 1)"
    }

    /// Returns chip text for natures in "First +x" format
    /// Returns nil if no natures selected
    private func naturesChipText(for selectedNatures: Set<SubcategoryNature>) -> String? {
        guard !selectedNatures.isEmpty else { return nil }
        let names = selectedNatures.map { $0.displayName }
        if names.count == 1 {
            return names.first
        }
        return "\(names.first ?? "") +\(names.count - 1)"
    }

    // MARK: - New Record FAB

    private var newRecordFAB: some View {
        VStack {
            Spacer()

            HStack {
                Spacer()

                Button {
                    recordsViewModel.showNewTransaction = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.netoPrimaryText, in: Circle())
                        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
                }
            }
            .padding(.trailing, 20)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Selection Action Bar

    private var selectionActionBar: some View {
        VStack {
            Spacer()

            HStack {
                // Delete button
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "trash")
                        Text("Eliminar")
                            .font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                }

                // Selected count
                Text("\(recordsViewModel.selectedRecordIDs.count) seleccionado(s)")
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)

                // Edit button
                Button {
                    handleEditAction()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "pencil")
                        Text("Editar")
                            .font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
            .background(.ultraThinMaterial)
        }
    }

    // MARK: - Actions

    private func refreshRecordsData() {
        // Defer to allow UI updates first
        DispatchQueue.main.async {
            recordsViewModel.applyFilters(
                transactions: allTransactions,
                accounts: accounts,
                categories: categories,
                tags: tags
            )
        }
    }

    private func calculateTrendsData() {
        // Defer calculation to next run loop to allow UI (Period Selector) to update immediately
        // preventing visual freezes/clipping during the layout transition.
        DispatchQueue.main.async {
            trendsViewModel.calculateTrendData(
                accounts: accounts,
                transactions: allTransactions,
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
            showMultiEditPlaceholder = true
        }
    }

    // MARK: - Synchronization

    private func syncFiltersToTrends() {
        // Sync Period (both now use DetailPeriod)
        if trendsViewModel.detailPeriod != recordsViewModel.period {
            trendsViewModel.detailPeriod = recordsViewModel.period
        }

        // Sync Filters (Only update if different)
        if trendsViewModel.selectedAccounts != recordsViewModel.selectedAccounts {
            trendsViewModel.selectedAccounts = recordsViewModel.selectedAccounts
        }
        if trendsViewModel.selectedCategories != recordsViewModel.selectedCategories {
            trendsViewModel.selectedCategories = recordsViewModel.selectedCategories
        }
        if trendsViewModel.selectedSubcategories != recordsViewModel.selectedSubcategories {
            trendsViewModel.selectedSubcategories = recordsViewModel.selectedSubcategories
        }
        if trendsViewModel.selectedTags != recordsViewModel.selectedTags {
            trendsViewModel.selectedTags = recordsViewModel.selectedTags
        }
        if trendsViewModel.selectedNatures != recordsViewModel.selectedNatures {
            trendsViewModel.selectedNatures = recordsViewModel.selectedNatures
        }
        if trendsViewModel.selectedCurrencies != recordsViewModel.selectedCurrencies {
            trendsViewModel.selectedCurrencies = recordsViewModel.selectedCurrencies
        }
        if trendsViewModel.amountCondition != recordsViewModel.amountCondition {
            trendsViewModel.amountCondition = recordsViewModel.amountCondition
        }
        if trendsViewModel.searchText != recordsViewModel.searchText {
            trendsViewModel.searchText = recordsViewModel.searchText
        }
    }

    private func syncFiltersToRecords() {
        // Sync Period (both now use DetailPeriod)
        if recordsViewModel.period != trendsViewModel.detailPeriod {
            recordsViewModel.period = trendsViewModel.detailPeriod
        }

        // Sync Filters (Only update if different)
        if recordsViewModel.selectedAccounts != trendsViewModel.selectedAccounts {
            recordsViewModel.selectedAccounts = trendsViewModel.selectedAccounts
        }
        if recordsViewModel.selectedCategories != trendsViewModel.selectedCategories {
            recordsViewModel.selectedCategories = trendsViewModel.selectedCategories
        }
        if recordsViewModel.selectedSubcategories != trendsViewModel.selectedSubcategories {
            recordsViewModel.selectedSubcategories = trendsViewModel.selectedSubcategories
        }
        if recordsViewModel.selectedTags != trendsViewModel.selectedTags {
            recordsViewModel.selectedTags = trendsViewModel.selectedTags
        }
        if recordsViewModel.selectedNatures != trendsViewModel.selectedNatures {
            recordsViewModel.selectedNatures = trendsViewModel.selectedNatures
        }
        if recordsViewModel.selectedCurrencies != trendsViewModel.selectedCurrencies {
            recordsViewModel.selectedCurrencies = trendsViewModel.selectedCurrencies
        }
        if recordsViewModel.amountCondition != trendsViewModel.amountCondition {
            recordsViewModel.amountCondition = trendsViewModel.amountCondition
        }
        if recordsViewModel.searchText != trendsViewModel.searchText {
            recordsViewModel.searchText = trendsViewModel.searchText
        }
    }

    // MARK: - SessionState Synchronization

    /// Sync local filters FROM SessionState (call on appear)
    private func syncFromSessionState() {
        // Period
        trendsViewModel.detailPeriod = sessionState.selectedPeriod
        recordsViewModel.period = sessionState.selectedPeriod

        // Accounts
        trendsViewModel.selectedAccounts = sessionState.selectedAccountIDs
        recordsViewModel.selectedAccounts = sessionState.selectedAccountIDs

        // Categories
        trendsViewModel.selectedCategories = sessionState.selectedCategoryIDs
        recordsViewModel.selectedCategories = sessionState.selectedCategoryIDs

        // Subcategories (convert names to actual identifiers if needed)
        // Note: SessionState stores names for Panel compatibility,
        // but TrendsDetailViewModel uses PersistentIdentifier for subcategories
        // For now, clear local subcategories if SessionState has none
        if sessionState.selectedSubcategoryNames.isEmpty {
            trendsViewModel.selectedSubcategories.removeAll()
            recordsViewModel.selectedSubcategories.removeAll()
        }

        // Natures
        trendsViewModel.selectedNatures = sessionState.selectedNatures
        recordsViewModel.selectedNatures = sessionState.selectedNatures
    }

    /// Sync local filters TO SessionState (call after filter changes)
    private func syncToSessionState() {
        // Period
        sessionState.selectedPeriod = trendsViewModel.detailPeriod

        // Accounts (use trends as source of truth)
        sessionState.selectedAccountIDs = trendsViewModel.selectedAccounts

        // Categories
        sessionState.selectedCategoryIDs = trendsViewModel.selectedCategories

        // Natures
        sessionState.selectedNatures = trendsViewModel.selectedNatures
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
            .onChange(of: viewModel.selectedCurrencies) { _, _ in action() }
            .onChange(of: viewModel.amountCondition) { _, _ in action() }
            .onChange(of: viewModel.searchText) { _, _ in action() }
    }

    func onTrendsFilterChange(viewModel: TrendsDetailViewModel, action: @escaping () -> Void)
        -> some View
    {
        self
            // Period is now synced via full state sync
            .onChange(of: viewModel.detailPeriod) { _, _ in action() }
            .onChange(of: viewModel.selectedMetric) { _, _ in action() }
            .onChange(of: viewModel.isAggregatedView) { _, _ in action() }
            .onChange(of: viewModel.selectedAccounts) { _, _ in action() }
            .onChange(of: viewModel.selectedCategories) { _, _ in action() }
            .onChange(of: viewModel.selectedSubcategories) { _, _ in action() }
            .onChange(of: viewModel.selectedTags) { _, _ in action() }
            .onChange(of: viewModel.selectedNatures) { _, _ in action() }
            .onChange(of: viewModel.selectedCurrencies) { _, _ in action() }
            .onChange(of: viewModel.amountCondition) { _, _ in action() }
            .onChange(of: viewModel.searchText) { _, _ in action() }
    }
}
