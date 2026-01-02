//
//  TrendDetailView.swift
//  Neto
//
//  Vista de detalle de tendencias (Saldo, Ingreso o Gasto)
//  Accesible desde la tarjeta de Tendencia en el Panel
//

import Charts
import SwiftData
import SwiftUI

struct TrendDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // MARK: - Data Queries

    @Query(sort: \Account.name, order: .forward) private var accounts: [Account]
    @Query(sort: \TransactionItem.date, order: .reverse)
    private var transactions: [TransactionItem]
    @Query private var categories: [Category]

    // MARK: - State

    @State private var viewModel: TrendsDetailViewModel

    @AppStorage("defaultCurrencyCode") private var defaultCurrencyCodeRaw: String = CurrencyCode.pen
        .rawValue

    // MARK: - Navigation State

    @State private var showCategoriesPlaceholder = false
    @Namespace private var namespace

    // MARK: - Initialization

    init(context: TrendsDetailContext) {
        _viewModel = State(initialValue: TrendsDetailViewModel(context: context))
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            PanelBackgroundView()

            VStack(spacing: 0) {
                // Pinned Navigation Tabs
                VStack(spacing: 0) {
                    tabsBar
                }
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)  // distinct header area

                // Content
                Group {
                    switch viewModel.selectedTab {
                    case .trends:
                        VStack(spacing: 0) {
                            // Metric Selector & Chart (NOT inside ScrollView)
                            VStack(spacing: 16) {
                                metricSelector
                                chartCard
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)

                            // Only Recent Records scroll
                            ScrollView(.vertical, showsIndicators: false) {
                                recentRecordsSection
                                    .padding(.horizontal, 16)
                                    .padding(.top, 16)
                                    .padding(.bottom, 100)
                            }
                        }
                    case .categories:
                        categoriesPlaceholder
                    case .records:
                        RecordsListView(
                            context: viewModel.buildRecordsContext(),
                            isEmbedded: true
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                // Only show main filter button if NOT in records mode (records has its own filters)
                if viewModel.selectedTab != .records {
                    filterButton
                }
            }
        }
        .sheet(isPresented: $viewModel.showFiltersSheet) {
            TrendsFiltersView(viewModel: viewModel)
        }
        .onAppear {
            calculateData()
        }
        // Note: selectedMetric onChange removed - calculation now happens synchronously in metricButton
        .onChange(of: viewModel.detailPeriod) { _, _ in
            calculateData()
        }
    }

    // MARK: - Navigation Title

    private var navigationTitle: String {
        switch viewModel.selectedTab {
        case .trends:
            return "Tendencias"
        case .categories:
            return "Categorías"
        case .records:
            return "Registros"
        }
    }

    // MARK: - Tabs Bar

    private var tabsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(DetailViewTab.allCases) { tab in
                    tabButton(for: tab)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private func tabButton(for tab: DetailViewTab) -> some View {
        let isSelected = viewModel.selectedTab == tab

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.selectedTab = tab
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

    // MARK: - Trends Content

    private var trendsContent: some View {
        VStack(spacing: 20) {
            // Metric Selector
            metricSelector

            // Chart Card
            chartCard

            // Recent Records Section
            recentRecordsSection
        }
    }

    // MARK: - Metric Selector

    private var metricSelector: some View {
        HStack(spacing: 0) {
            ForEach(TrendMetric.allCases) { metric in
                metricButton(for: metric)
            }
        }
        .padding(2)  // Tighter padding
        .background(Color.netoSecondaryText.opacity(0.1))  // Glassy background
        .clipShape(Capsule())  // Liquid shape
    }

    private func metricButton(for metric: TrendMetric) -> some View {
        Button {
            // IMPORTANT: Change metric and recalculate synchronously
            // This ensures data and metric are always in sync when SwiftUI renders
            viewModel.selectedMetric = metric
            calculateData()  // Synchronous calculation before animation frame

            // Apply animation after data is ready
            withAnimation(.interpolatingSpring(stiffness: 300, damping: 30)) {
                // Force SwiftUI to re-evaluate (empty to trigger view update with new data)
            }
        } label: {
            Text(metric.rawValue)
                .font(
                    .caption.weight(viewModel.selectedMetric == metric ? .bold : .medium)
                )
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .foregroundStyle(
                    viewModel.selectedMetric == metric ? .white : Color.netoSecondaryText
                )
                .background(
                    Group {
                        if viewModel.selectedMetric == metric {
                            Capsule()
                                .fill(metric.color)
                                .matchedGeometryEffect(id: "MetricTab", in: namespace)
                        }
                    }
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Chart Card

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(chartTitle)
                        .font(.headline)
                        .foregroundStyle(Color.netoPrimaryText)

                    // KPI Value
                    Text(
                        NetoFormatter.currency(
                            value: viewModel.totalMetricValue, currencyCode: defaultCurrencyCodeRaw)
                    )
                    .font(.title2.weight(.bold))
                    .foregroundStyle(viewModel.selectedMetric.color)

                    Text(chartSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Toggle removed
            }

            // Chart
            aggregatedChart
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

    private var chartTitle: String {
        switch viewModel.selectedMetric {
        case .balance:
            return L10n.Trend.balanceTitle
        case .income:
            return L10n.Trend.incomeTitle
        case .expense:
            return L10n.Trend.expenseTitle
        }
    }

    private var chartSubtitle: String {
        let formatter = DateFormatter()
        formatter.locale = AppLocale.current
        formatter.dateFormat = "d MMM"
        let start = formatter.string(from: viewModel.chartDomain.lowerBound)  // Use actual chart start
        let end = formatter.string(from: viewModel.chartDomain.upperBound)
        return "\(start) - \(end)"
    }

    // MARK: - Aggregated Chart

    @ViewBuilder
    private var aggregatedChart: some View {
        // Show empty state if no data for the period
        if viewModel.trendPoints.isEmpty {
            emptyChartState
        } else if viewModel.dataMetric != viewModel.selectedMetric {
            // Data is stale (from previous metric) - show loading indicator briefly
            // This prevents showing Balance data with Income color during recalculation
            ProgressView()
                .frame(height: 250)
                .frame(maxWidth: .infinity)
        } else {
            // Data and metric are in sync - safe to render
            // Use dataMetric for color to ensure data and color always match
            let trendType: TrendType =
                viewModel.dataMetric == .balance
                ? .balance
                : (viewModel.dataMetric == .income ? .income : .expense)

            TrendChartView(
                trendPoints: viewModel.trendPoints,
                yDomain: viewModel.yDomain,
                grouping: viewModel.trendGrouping,
                interval: viewModel.currentInterval,
                currencyCode: defaultCurrencyCodeRaw,
                trendType: trendType,
                focusedDate: .constant(nil),
                period: viewModel.detailPeriod,
                chartHeight: 250
            )
        }
    }

    private var emptyChartState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.downtrend.xyaxis")
                .font(.system(size: 40))
                .foregroundStyle(Color.netoSecondaryText.opacity(0.5))

            Text("Sin datos para este período")
                .font(.subheadline)
                .foregroundStyle(Color.netoSecondaryText)
        }
        .frame(height: 250)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Recent Records Section

    private var recentRecordsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.Records.latest)
                .font(.headline)
                .foregroundStyle(Color.netoPrimaryText)

            if viewModel.recentRecords.isEmpty {
                emptyRecordsState
            } else {
                recordsList
            }

            // "Ver todos" button
            Button {
                withAnimation {
                    viewModel.selectedTab = .records
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
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.xLarge, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
    }

    private var emptyRecordsState: some View {
        VStack(spacing: 8) {
            Image(systemName: "list.bullet.rectangle")
                .font(.title2)
                .foregroundStyle(.secondary.opacity(0.5))

            Text("No hay registros en este periodo")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private var recordsList: some View {
        VStack(spacing: 0) {
            ForEach(viewModel.recentRecords) { record in
                recordRow(for: record)

                if record.id != viewModel.recentRecords.last?.id {
                    Divider()
                        .padding(.leading, 52)
                }
            }
        }
    }

    private func recordRow(for record: TransactionItem) -> some View {
        HStack(spacing: 12) {
            // Subcategory icon
            ZStack {
                Circle()
                    .fill(subcategoryColor(for: record).opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: subcategoryIcon(for: record))
                    .font(.callout)
                    .foregroundStyle(subcategoryColor(for: record))
            }

            VStack(alignment: .leading, spacing: 3) {
                if let note = record.note, !note.isEmpty {
                    // Line 1: Note
                    Text(note)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.netoPrimaryText)
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
                        .foregroundStyle(Color.netoPrimaryText)
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

            VStack(alignment: .trailing, spacing: 4) {
                Text(
                    NetoFormatter.currency(value: record.amount, currencyCode: record.currencyCode)
                )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(record.amount >= 0 ? Color.electricIndigo : Color.hotPink)

                Text(formatRecordDate(record.date))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 10)
    }

    // MARK: - Categories Placeholder

    private var categoriesPlaceholder: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "chart.pie")
                .font(.system(size: 60))
                .foregroundStyle(.secondary.opacity(0.5))

            VStack(spacing: 8) {
                Text("Próximamente")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color.netoPrimaryText)

                Text("La vista detallada de categorías estará disponible pronto.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 400)
    }

    // MARK: - Filter Button

    private var filterButton: some View {
        Button {
            viewModel.showFiltersSheet = true
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(viewModel.hasActiveFilters ? Color.electricIndigo : .primary)
        }
    }

    // MARK: - Helpers

    private func calculateData() {
        viewModel.calculateTrendData(
            accounts: accounts,
            transactions: transactions,
            defaultCurrencyCode: defaultCurrencyCodeRaw,
            context: modelContext
        )
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
}

// MARK: - Trends Filters View

struct TrendsFiltersView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var viewModel: TrendsDetailViewModel

    // MARK: - Data Queries

    @Query(sort: \Account.name) private var allAccounts: [Account]
    @Query(sort: \Category.sortOrder) private var allCategories: [Category]
    @Query(sort: \Tag.name) private var allTags: [Tag]
    @Query(sort: \Subcategory.sortOrder) private var allSubcategories: [Subcategory]

    // MARK: - Sheet Presentation State

    @State private var showAccountsSheet = false
    @State private var showCategoriesSheet = false
    @State private var showTagsSheet = false

    // MARK: - Categories State

    @State private var expandedCategories: Set<Category> = []

    // MARK: - Computed Properties

    private var activeAccounts: [Account] {
        allAccounts.filter { !$0.isArchived }
    }

    private var activeTags: [Tag] {
        allTags.filter { $0.isActive }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()

                ScrollView {
                    VStack(spacing: 24) {
                        SectionBox(title: "Opciones de filtrado") {
                            VStack(spacing: 0) {
                                accountsContent
                                Divider().padding(.leading, 16)
                                categoriesContent
                                Divider().padding(.leading, 16)
                                tagsContent
                                Divider().padding(.leading, 16)
                                naturesContent
                                Divider().padding(.leading, 16)
                                currencyContent
                                Divider().padding(.leading, 16)
                                amountContent
                                Divider().padding(.leading, 16)
                                noteContent
                            }
                        }
                    }
                    .padding(.vertical, 24)
                    .padding(.horizontal, 16)
                }
            }
            .navigationTitle("Filtros")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.headline)
                            .foregroundStyle(.black)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Aplicar") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.brandPrimary)
                }
            }
            .sheet(isPresented: $showAccountsSheet) {
                accountsSheetView
            }
            .sheet(isPresented: $showCategoriesSheet) {
                categoriesSheetView
            }
            .sheet(isPresented: $showTagsSheet) {
                tagsSheetView
            }
        }
    }

    // MARK: - Filter Content Rows

    private var accountsContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            FilterSectionHeader(
                icon: "creditcard",
                title: "Cuentas",
                status: selectedAccountsText
            )
            .padding(.horizontal, 16)
            .padding(.top, 12)

            // Chips
            FlowLayout(spacing: 8) {
                ForEach(activeAccounts) { account in
                    accountChip(account)
                }
            }
            .padding(.leading, 52)
            .padding(.trailing, 16)
            .padding(.bottom, 12)
        }
    }

    private func accountChip(_ account: Account) -> some View {
        let isSelected = viewModel.selectedAccounts.contains(account.persistentModelID)

        return Button {
            withAnimation {
                if isSelected {
                    viewModel.selectedAccounts.remove(account.persistentModelID)
                } else {
                    viewModel.selectedAccounts.insert(account.persistentModelID)
                }
            }
        } label: {
            Text(account.name)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .foregroundStyle(isSelected ? .white : .primary)
                .background(
                    isSelected ? Color.electricIndigo : Color.netoSecondaryText.opacity(0.1)
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var selectedAccountsText: String {
        if viewModel.selectedAccounts.isEmpty {
            return "Todas"
        } else {
            return "\(viewModel.selectedAccounts.count)"
        }
    }

    private var categoriesContent: some View {
        Button {
            showCategoriesSheet = true
        } label: {
            HStack(spacing: 0) {
                FilterSectionHeader(
                    icon: "tag",
                    title: "Categorías",
                    status: selectedCategoriesText
                )

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    private var selectedCategoriesText: String {
        // Get selected subcategories preserving order
        let selectedSubs = allSubcategories.filter {
            viewModel.selectedSubcategories.contains($0.persistentModelID)
        }

        if selectedSubs.isEmpty {
            return "Todas"
        }

        if let firstSub = selectedSubs.first {
            let remainingCount = selectedSubs.count - 1
            if remainingCount > 0 {
                return "\(firstSub.name) +\(remainingCount)"
            } else {
                return firstSub.name
            }
        }

        return "Todas"
    }

    private var tagsContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            FilterSectionHeader(
                icon: "number",
                title: "Etiquetas",
                status: selectedTagsText
            )
            .padding(.horizontal, 16)
            .padding(.top, 12)

            // Chips
            // Show chips if there are active tags, or fallback spacing
            if !activeTags.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(activeTags) { tag in
                        tagChip(tag)
                    }
                }
                .padding(.leading, 52)
                .padding(.trailing, 16)
                .padding(.bottom, 12)
            } else {
                Color.clear.frame(height: 12)  // minimal spacer if empty
            }
        }
    }

    private func tagChip(_ tag: Tag) -> some View {
        let isSelected = viewModel.selectedTags.contains(tag.persistentModelID)

        return Button {
            if isSelected {
                viewModel.selectedTags.remove(tag.persistentModelID)
            } else {
                viewModel.selectedTags.insert(tag.persistentModelID)
            }
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color(hex: tag.colorHex))
                    .frame(width: 8, height: 8)

                Text(tag.name)
                    .font(.subheadline)
                    .foregroundStyle(isSelected ? .white : .primary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? Color.brandPrimary : Color(.tertiarySystemFill))
            )
        }
        .buttonStyle(.plain)
    }

    private var selectedTagsText: String {
        if viewModel.selectedTags.isEmpty { return "Todas" }
        if viewModel.selectedTags.count == activeTags.count { return "Todas" }
        return "\(viewModel.selectedTags.count)/\(activeTags.count)"
    }

    private var naturesContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            FilterSectionHeader(
                icon: "leaf.fill",
                title: "Naturaleza",
                status: selectedNaturesText
            )
            .padding(.horizontal, 16)
            .padding(.top, 12)

            // Chips
            FlowLayout(spacing: 8) {
                ForEach(SubcategoryNature.allCases, id: \.self) { nature in
                    natureChip(nature)
                }
            }
            .padding(.leading, 52)
            .padding(.trailing, 16)
            .padding(.bottom, 12)
        }
    }

    private func natureChip(_ nature: SubcategoryNature) -> some View {
        let isSelected = viewModel.selectedNatures.contains(nature)

        return Button {
            if isSelected {
                viewModel.selectedNatures.remove(nature)
            } else {
                viewModel.selectedNatures.insert(nature)
            }
        } label: {
            HStack(spacing: 6) {
                Text(nature.displayName)
                    .font(.subheadline)
                    .foregroundStyle(isSelected ? .white : .primary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? Color.brandPrimary : Color(.tertiarySystemFill))
            )
        }
        .buttonStyle(.plain)
    }

    private var selectedNaturesText: String {
        if viewModel.selectedNatures.isEmpty { return "Todas" }
        return "\(viewModel.selectedNatures.count)"
    }

    private var currencyContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            FilterSectionHeader(
                icon: "arrow.triangle.2.circlepath",
                title: "Moneda",
                status: selectedCurrenciesText
            )
            .padding(.horizontal, 16)
            .padding(.top, 12)

            // Chips
            FlowLayout(spacing: 8) {
                ForEach(CurrencyCode.allCases) { currency in
                    currencyChip(currency)
                }
            }
            .padding(.leading, 52)
            .padding(.trailing, 16)
            .padding(.bottom, 12)
        }
    }

    private func currencyChip(_ currency: CurrencyCode) -> some View {
        let isSelected = viewModel.selectedCurrencies.contains(currency)

        return Button {
            if isSelected {
                viewModel.selectedCurrencies.remove(currency)
            } else {
                viewModel.selectedCurrencies.insert(currency)
            }
        } label: {
            Text(currency.rawValue)
                .font(.subheadline)
                .foregroundStyle(isSelected ? .white : .primary)
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.brandPrimary : Color(.tertiarySystemFill))
                )
        }
        .buttonStyle(.plain)
    }

    private var selectedCurrenciesText: String {
        if viewModel.selectedCurrencies.isEmpty { return "Todas" }
        if viewModel.selectedCurrencies.count == CurrencyCode.allCases.count { return "Todas" }
        return "\(viewModel.selectedCurrencies.count)/\(CurrencyCode.allCases.count)"
    }

    private var amountContent: some View {
        AmountFilterView(
            condition: $viewModel.amountCondition,
            currencyCode: viewModel.selectedCurrencies.count == 1
                ? viewModel.selectedCurrencies.first : nil
        )
    }

    private var noteContent: some View {
        HStack(spacing: 12) {
            Image(systemName: "note.text")
                .font(.body)
                .foregroundStyle(.primary)
                .frame(width: 24)

            TextField("Nota contiene...", text: $viewModel.searchText)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Sheets

    private var accountsSheetView: some View {
        NavigationStack {
            List {
                ForEach(activeAccounts) { account in
                    Button {
                        if viewModel.selectedAccounts.contains(account.persistentModelID) {
                            viewModel.selectedAccounts.remove(account.persistentModelID)
                        } else {
                            viewModel.selectedAccounts.insert(account.persistentModelID)
                        }
                    } label: {
                        HStack {
                            Text(account.name)
                                .foregroundStyle(.primary)
                            Spacer()
                            if viewModel.selectedAccounts.contains(account.persistentModelID) {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.brandPrimary)
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                }
            }
            .navigationTitle("Seleccionar cuentas")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showAccountsSheet = false
                    } label: {
                        Image(systemName: "chevron.left")
                        Text("Atrás")
                    }
                }
            }
        }
    }

    private func sortedSubcategories(for category: Category) -> [Subcategory] {
        return category.subcategories.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var categoriesSheetView: some View {
        NavigationStack {
            List {
                ForEach(allCategories) { category in
                    Section {
                        ForEach(sortedSubcategories(for: category)) { sub in
                            Button {
                                if viewModel.selectedSubcategories.contains(sub.persistentModelID) {
                                    viewModel.selectedSubcategories.remove(sub.persistentModelID)
                                } else {
                                    viewModel.selectedSubcategories.insert(sub.persistentModelID)
                                }
                            } label: {
                                HStack {
                                    Circle()
                                        .fill(Color(hex: sub.colorHex ?? category.colorHex))
                                        .frame(width: 8, height: 8)
                                    Text(sub.name)
                                    Spacer()
                                    if viewModel.selectedSubcategories.contains(
                                        sub.persistentModelID)
                                    {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(Color.brandPrimary)
                                    }
                                }
                            }
                            .foregroundStyle(.primary)
                        }
                    } header: {
                        Text(category.name)
                    }
                }
            }
            .navigationTitle("Seleccionar categorías")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showCategoriesSheet = false
                    } label: {
                        Image(systemName: "chevron.left")
                        Text("Atrás")
                    }
                }
            }
        }
    }

    private var tagsSheetView: some View {
        NavigationStack {
            List {
                ForEach(activeTags) { tag in
                    Button {
                        if viewModel.selectedTags.contains(tag.persistentModelID) {
                            viewModel.selectedTags.remove(tag.persistentModelID)
                        } else {
                            viewModel.selectedTags.insert(tag.persistentModelID)
                        }
                    } label: {
                        HStack {
                            Circle()
                                .fill(Color(hex: tag.colorHex))
                                .frame(width: 8, height: 8)
                            Text(tag.name)
                            Spacer()
                            if viewModel.selectedTags.contains(tag.persistentModelID) {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.brandPrimary)
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                }
            }
            .navigationTitle("Seleccionar etiquetas")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showTagsSheet = false
                    } label: {
                        Image(systemName: "chevron.left")
                        Text("Atrás")
                    }
                }
            }
        }
    }
}
