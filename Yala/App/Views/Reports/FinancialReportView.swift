//
//  FinancialReportView.swift
//  Yala
//
//  Main view for the Financial Report with tab-based navigation.
//

import SwiftData
import SwiftUI
import UIKit

struct FinancialReportView: View {

    // MARK: - State

    @State private var viewModel = FinancialReportViewModel()
    @State private var cashFlowViewModel = CashFlowPlanViewModel()
    @State private var selectedTab: ReportTab = .comparativa
    @State private var showCustomDatePicker = false
    @State private var isPresentingSettings = false
    @State private var showResetConfirmation = false
    @State private var showHorizonConfig = false
    @State private var recalculateTask: Task<Void, Never>?
    /// Whether the app is in background — suppresses recalculation to prevent 0x8BADF00D watchdog kill.
    @State private var isInBackground = false

    // MARK: - Environment

    @Environment(SessionState.self) private var sessionState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.yalaTheme) private var theme
    @Environment(\.scenePhase) private var scenePhase

    // MARK: - Queries

    @Query(sort: \TransactionItem.date, order: .reverse) private var transactions: [TransactionItem]
    @Query private var accounts: [Account]
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @Query private var allSubcategories: [Subcategory]
    @Query private var tags: [Tag]
    @Query private var scheduledPayments: [ScheduledPayment]

    // MARK: - Preferences

    @Environment(AppPreferences.self) private var appPreferences

    /// Alias for `appPreferences.defaultCurrencyCode.rawValue` — minimizes diff across 7 callsites.
    private var preferredCurrencyCode: String { appPreferences.defaultCurrencyCode.rawValue }
    private var showVariations: Bool { appPreferences.showVariations }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()
                VStack(spacing: DS.Spacing.none) {
                    reportGuide
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.top, DS.Spacing.xs)
                    tabContent
                }
            }
            .safeAreaInset(edge: .top) {
                navigationChipsBar
                    .padding(.vertical, DS.Spacing.sm)
            }
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
        }
        .sheet(isPresented: $isPresentingSettings) {
            ProfileView()
        }
        .sheet(isPresented: $cashFlowViewModel.showChartsSheet) {
            if cashFlowViewModel.projection != nil {
                CashFlowChartsSheet(
                    viewModel: cashFlowViewModel,
                    currencyCode: preferredCurrencyCode
                )
            }
        }
        .sheet(isPresented: $showHorizonConfig) {
            CashFlowHorizonSheet(viewModel: cashFlowViewModel)
        }
        .appliesPendingRemoteChanges(sessionState)
        .cashFlowResetDialog(
            isPresented: $showResetConfirmation,
            onReset: { cashFlowViewModel.resetPlan() }
        )
        .onAppear {
            recalculate()
            cashFlowViewModel.setContext(modelContext)
        }
        .onDisappear { recalculateTask?.cancel() }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background, .inactive:
                isInBackground = true
                recalculateTask?.cancel()
                recalculateTask = nil
            case .active:
                guard UIApplication.shared.applicationState == .active else { return }
                isInBackground = false
                scheduleRecalculate()
            @unknown default:
                break
            }
        }
        .onChange(of: sessionState.selectedPeriod) { _, _ in scheduleRecalculate() }
        .onChange(of: sessionState.customDateRange) { _, _ in scheduleRecalculate() }
        .onChange(of: sessionState.comparisonMode) { _, _ in scheduleRecalculate() }
        .onChange(of: sessionState.selectedAccountIDs) { _, _ in scheduleRecalculate() }
        .onChange(of: sessionState.selectedCategoryIDs) { _, _ in scheduleRecalculate() }
        .onChange(of: sessionState.selectedSubcategoryIDs) { _, _ in scheduleRecalculate() }
        .onChange(of: sessionState.selectedTags) { _, _ in scheduleRecalculate() }
        .onChange(of: sessionState.selectedNeeds) { _, _ in scheduleRecalculate() }
        .onChange(of: sessionState.selectedTransactionNatures) { _, _ in scheduleRecalculate() }
        .onChange(of: sessionState.selectedCurrencies) { _, _ in scheduleRecalculate() }
        .onChange(of: sessionState.dataVersion) { _, _ in scheduleRecalculate() }
        .onChange(of: viewModel.groupingState.activeDimensions) { _, _ in scheduleRecalculate() }
        .onChange(of: transactions.count) { _, _ in scheduleRecalculate() }
        .onChange(of: appPreferences.defaultCurrencyCode) { _, _ in scheduleRecalculate() }
        .onChange(of: sessionState.formattingVersion) { _, _ in scheduleRecalculate() }
    }

    // MARK: - Navigation Chips

    private var navigationChipsBar: some View {
        VStack(spacing: DS.Spacing.sm) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.sm) {
                    ForEach(ReportTab.allCases) { tab in
                        navigationChipButton(for: tab)
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)

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

    // MARK: - Report Guide

    @ViewBuilder
    private var reportGuide: some View {
        switch selectedTab {
        case .comparativa:
            ContextualGuideBanner.comparative()
        case .flujoDeCaja:
            ContextualGuideBanner.cashflow()
        }
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .comparativa:
            comparativaContent
        case .flujoDeCaja:
            cashFlowContent
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
            .padding(.top, DS.Spacing.sm)
            .yalaSafeBottomPadding()
        }
        .scrollViewGlassEdges()
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
        .solidCard()
    }

    // MARK: - Cash Flow

    @ViewBuilder
    private var cashFlowContent: some View {
        if transactions.isEmpty {
            ScrollView {
                emptyState
                    .padding(.top, DS.Spacing.xxl)
            }
        } else if cashFlowViewModel.hasPlan {
            CashFlowTableView(
                viewModel: cashFlowViewModel,
                transactions: transactions,
                categories: categories,
                scheduledPayments: scheduledPayments,
                currencyCode: preferredCurrencyCode
            )
        } else {
            CashFlowSetupView(
                viewModel: cashFlowViewModel,
                transactions: transactions,
                scheduledPayments: scheduledPayments,
                categories: categories,
                currencyCode: preferredCurrencyCode
            )
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var reportToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Group {
                if selectedTab == .flujoDeCaja && cashFlowViewModel.hasPlan {
                    HStack(spacing: DS.Spacing.md) {
                        Button {
                            cashFlowViewModel.showChartsSheet = true
                        } label: {
                            Image(systemName: "chart.bar.xaxis")
                                .font(DS.Typography.bodyBold)
                                .foregroundStyle(.thToolbarIcon)
                        }

                        Menu {
                            Button {
                                showHorizonConfig = true
                            } label: {
                                Label(L10n.CashFlowPlan.configureHorizon, systemImage: "calendar.badge.clock")
                            }
                            Divider()
                            Button(role: .destructive) {
                                showResetConfirmation = true
                            } label: {
                                Label(L10n.CashFlowPlan.resetPlan, systemImage: "arrow.counterclockwise")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(DS.Typography.bodyBold)
                                .foregroundStyle(.thToolbarIcon)
                        }
                    }
                } else if selectedTab == .comparativa {
                    Button {
                        viewModel.showFiltersSheet = true
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease")
                            .font(DS.Typography.bodyBold)
                            .foregroundStyle(.thToolbarIcon)
                    }
                    .accessibilityLabel(L10n.Filters.title)
                    .filterBadge(isActive: viewModel.activeFilterCount > 0)
                }
            }
        }

        ToolbarSpacer(.fixed, placement: .topBarTrailing)

        SyncIndicatorToolbarItem()

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
            onFilterChange: { scheduleRecalculate() }
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

    private func scheduleRecalculate() {
        guard !isInBackground else { return }
        guard UIApplication.shared.applicationState == .active else { return }
        recalculateTask?.cancel()
        recalculateTask = Task {
            do {
                try await Task.sleep(for: .milliseconds(150))
            } catch { return }
            recalculate()
        }
    }

    private func recalculate() {
        viewModel.calculateReport(
            transactions: transactions,
            accounts: accounts,
            preferredCurrency: preferredCurrencyCode
        )
    }
}

// MARK: - Cash Flow Reset Dialog Modifier

private struct CashFlowResetDialogModifier: ViewModifier {
    @Binding var isPresented: Bool
    let onReset: () -> Void

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                L10n.CashFlowPlan.resetPlan,
                isPresented: $isPresented,
                titleVisibility: .visible
            ) {
                Button(L10n.CashFlowPlan.resetPlan, role: .destructive) {
                    onReset()
                }
            } message: {
                Text(L10n.CashFlowPlan.resetConfirmation)
            }
    }
}

extension View {
    func cashFlowResetDialog(isPresented: Binding<Bool>, onReset: @escaping () -> Void) -> some View {
        modifier(CashFlowResetDialogModifier(isPresented: isPresented, onReset: onReset))
    }
}
