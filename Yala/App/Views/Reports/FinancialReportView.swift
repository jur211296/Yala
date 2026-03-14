//
//  FinancialReportView.swift
//  Yala
//
//  Main view for the Financial Report with tab-based navigation.
//

import SwiftData
import SwiftUI

struct FinancialReportView: View {

    // MARK: - State

    @State private var viewModel = FinancialReportViewModel()
    @State private var selectedTab: ReportTab = .comparativa
    @State private var showCustomDatePicker = false
    @State private var isPresentingSettings = false

    // MARK: - Environment

    @Environment(SessionState.self) private var sessionState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.yalaTheme) private var theme

    // MARK: - Queries

    @Query(sort: \TransactionItem.date, order: .reverse) private var transactions: [TransactionItem]
    @Query private var accounts: [Account]
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @Query private var allSubcategories: [Subcategory]
    @Query private var tags: [Tag]

    // MARK: - Settings

    @AppStorage("defaultCurrencyCode") private var preferredCurrencyCode: String = "PEN"
    @AppStorage("showVariations") private var showVariations: Bool = true

    // MARK: - Body

    var body: some View {
        NavigationStack {
            mainContent
                .navigationTitle(L10n.Report.title)
                .navigationBarTitleDisplayMode(.large)
            .toolbar {
                reportToolbar
            }
        }
        .sheet(isPresented: $showCustomDatePicker) {
            CustomPeriodPickerSheet(
                minDate: transactionDateRange.start,
                maxDate: transactionDateRange.end,
                currentRange: sessionState.customDateRange
            )
        }
        .sheet(isPresented: $viewModel.showFiltersSheet) {
            RecordsFiltersView(recordsViewModel: viewModel)
                .onDisappear { recalculate() }
        }
        .sheet(isPresented: $isPresentingSettings) {
            ProfileView()
        }
        .onAppear { recalculate() }
        .onChange(of: sessionState.selectedPeriod) { _, _ in recalculate() }
        .onChange(of: sessionState.customDateRange?.start) { _, _ in recalculate() }
        .onChange(of: sessionState.comparisonMode) { _, _ in recalculate() }
        .onChange(of: sessionState.selectedAccountIDs) { _, _ in recalculate() }
        .onChange(of: sessionState.selectedCategoryIDs) { _, _ in recalculate() }
        .onChange(of: sessionState.selectedSubcategoryIDs) { _, _ in recalculate() }
        .onChange(of: sessionState.selectedTags) { _, _ in recalculate() }
        .onChange(of: sessionState.selectedNeeds) { _, _ in recalculate() }
        .onChange(of: sessionState.selectedTransactionNatures) { _, _ in recalculate() }
        .onChange(of: sessionState.selectedCurrencies) { _, _ in recalculate() }
        .onChange(of: sessionState.dataVersion) { _, _ in recalculate() }
        .onChange(of: viewModel.groupingState.activeDimensions) { _, _ in recalculate() }
        .onChange(of: transactions.count) { _, _ in recalculate() }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ZStack {
            PanelBackgroundView()
            tabContent
        }
        .safeAreaInset(edge: .top) {
            navigationChipsBar
                .padding(.vertical, DS.Spacing.sm)
        }
    }

    // MARK: - Navigation Chips

    private var navigationChipsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.sm) {
                ForEach(ReportTab.allCases) { tab in
                    navigationChipButton(for: tab)
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
        }
    }

    @ViewBuilder
    private func navigationChipButton(for tab: ReportTab) -> some View {
        let isSelected = selectedTab == tab

        Button {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                selectedTab = tab
            }
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: tab.icon)
                    .font(DS.Typography.subheadline)
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
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .comparativa:
            comparativaContent
        case .flujoDeCaja:
            cashFlowPlaceholder
        }
    }

    // MARK: - Comparativa

    private var comparativaContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: DS.Spacing.xl) {
                filterBar
                GroupingChipsBar(state: $viewModel.groupingState)

                if viewModel.hasData {
                    pivotTable

                    NetFlowSummaryView(
                        currentAmount: viewModel.netFlowCurrent,
                        previousAmount: viewModel.netFlowPrevious,
                        variation: viewModel.netFlowVariation,
                        currencyCode: preferredCurrencyCode
                    )
                } else {
                    emptyState
                        .padding(.top, DS.Spacing.xxl)
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.top, DS.Spacing.sm)
            .yalaSafeBottomPadding()
        }
    }

    private var pivotTable: some View {
        LazyVStack(spacing: DS.Spacing.none) {
            ForEach(viewModel.flattenedRows) { row in
                PivotRowView(
                    node: row.node,
                    level: row.level,
                    preferredCurrency: preferredCurrencyCode
                )

                if row.id != viewModel.flattenedRows.last?.id {
                    Divider()
                        .padding(.leading, DS.Spacing.lg + CGFloat(max(0, row.level - 1)) * (DS.Spacing.lg / 2))
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
        .yalaCard(padding: 0)
    }

    // MARK: - Cash Flow (Placeholder)

    private var cashFlowPlaceholder: some View {
        ScrollView(.vertical, showsIndicators: false) {
            YalaEmptyState(
                icon: "arrow.left.arrow.right",
                title: L10n.Report.Tab.cashFlow,
                message: "" // TODO: Implement cash flow tab
            )
            .padding(.top, DS.Spacing.xxl)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var reportToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                viewModel.showFiltersSheet = true
            } label: {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(DS.Typography.body.weight(.medium))
                    .foregroundStyle(.thToolbarIcon)
            }
            .accessibilityLabel(L10n.Filters.title)
            .overlay(alignment: .topTrailing) {
                if viewModel.activeFilterCount > 0 {
                    Circle()
                        .fill(Color.hotPink)
                        .frame(width: 8, height: 8)
                        .offset(x: 2, y: -2)
                }
            }
        }

        ToolbarSpacer(.fixed, placement: .topBarTrailing)

        ProfileToolbarItem {
            isPresentingSettings = true
        }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        FilterControlBar(
            periodSelector: TrendsPeriodMenu(
                selectedPeriod: viewModel.detailPeriod,
                customDateRange: viewModel.customDateRange,
                onSelect: { period in
                    viewModel.detailPeriod = period
                },
                onCustomTapped: {
                    showCustomDatePicker = true
                }
            ),
            viewModel: viewModel,
            accounts: accounts,
            categories: categories,
            allSubcategories: allSubcategories,
            tags: tags,
            animationValue: viewModel.detailPeriod,
            onFilterChange: { recalculate() }
        ) {
            if showVariations && PreviousPeriodHelper.isSelectorVisible(for: viewModel.detailPeriod) {
                ComparisonModeSelector()
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        YalaEmptyState(
            icon: "tablecells",
            title: L10n.Report.noData,
            message: L10n.Report.noDataDescription
        )
    }

    // MARK: - Helpers

    private var transactionDateRange: (start: Date, end: Date) {
        let start = transactions.last?.date ?? Date.now
        let end = transactions.first?.date ?? Date.now
        return (start, end)
    }

    private func recalculate() {
        viewModel.calculateReport(
            transactions: transactions,
            accounts: accounts,
            preferredCurrency: preferredCurrencyCode
        )
    }
}
