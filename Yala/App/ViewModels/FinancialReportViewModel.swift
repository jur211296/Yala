//
//  FinancialReportViewModel.swift
//  Yala
//
//  ViewModel for the Financial Report pivot table view.
//

import Foundation
import SwiftData

@MainActor
@Observable
final class FinancialReportViewModel: Filterable {

    // MARK: - Grouping State

    var groupingState = ReportGroupingState()

    // MARK: - Sheet State

    var showFiltersSheet = false

    // MARK: - Filter State (SSOT: Read/Write from SessionState.shared)

    var selectedAccounts: Set<PersistentIdentifier> {
        get { SessionState.shared.selectedAccountIDs }
        set { SessionState.shared.selectedAccountIDs = newValue }
    }

    var selectedCategories: Set<PersistentIdentifier> {
        get { SessionState.shared.selectedCategoryIDs }
        set { SessionState.shared.selectedCategoryIDs = newValue }
    }

    var selectedSubcategories: Set<PersistentIdentifier> {
        get { SessionState.shared.selectedSubcategoryIDs }
        set { SessionState.shared.selectedSubcategoryIDs = newValue }
    }

    var selectedTags: Set<PersistentIdentifier> {
        get { SessionState.shared.selectedTags }
        set { SessionState.shared.selectedTags = newValue }
    }

    var selectedNeeds: Set<SubcategoryNeed> {
        get { SessionState.shared.selectedNeeds }
        set { SessionState.shared.selectedNeeds = newValue }
    }

    var selectedTransactionNatures: Set<TransactionNature> {
        get { SessionState.shared.selectedTransactionNatures }
        set { SessionState.shared.selectedTransactionNatures = newValue }
    }

    var selectedCurrencies: Set<CurrencyCode> {
        get { SessionState.shared.selectedCurrencies }
        set { SessionState.shared.selectedCurrencies = newValue }
    }

    var amountCondition: AmountFilterCondition {
        get { SessionState.shared.amountCondition }
        set { SessionState.shared.amountCondition = newValue }
    }

    var searchText: String {
        get { SessionState.shared.searchText }
        set { SessionState.shared.searchText = newValue }
    }

    var isExcludeMode: Bool {
        get { SessionState.shared.isExcludeMode }
        set { SessionState.shared.isExcludeMode = newValue }
    }

    var detailPeriod: DetailPeriod {
        get { SessionState.shared.selectedPeriod }
        set { SessionState.shared.selectedPeriod = newValue }
    }

    var customDateRange: DateInterval? {
        get { SessionState.shared.customDateRange }
        set { SessionState.shared.customDateRange = newValue }
    }

    // MARK: - Computed Filter Properties

    var hasActiveFilters: Bool { filterCriteria.hasActiveFilters }
    var activeFilterCount: Int { filterCriteria.activeFilterCount }

    func clearFilters() {
        clearFiltersDefault()
    }

    // MARK: - Computed Data

    /// Root pivot nodes for the current period
    private(set) var rootNodes: [PivotNode] = []

    /// Flattened rows for rendering
    private(set) var flattenedRows: [PivotFlatRow] = []

    /// Net flow data
    private(set) var netFlowCurrent: Double = 0
    private(set) var netFlowPrevious: Double?
    private(set) var netFlowVariation: Double?

    /// Whether there is data to display
    var hasData: Bool { !rootNodes.isEmpty }

    // MARK: - Period Interval

    var panelDateInterval: DateInterval {
        detailPeriod.dateInterval(customRange: customDateRange)
    }

    // MARK: - Data Calculation

    func calculateReport(
        transactions: [TransactionItem],
        accounts: [Account],
        preferredCurrency: String
    ) {
        let interval = panelDateInterval
        let comparisonMode = SessionState.shared.comparisonMode
        let previousInterval = PreviousPeriodHelper.previousInterval(
            for: detailPeriod,
            mode: comparisonMode,
            customRange: customDateRange
        )

        // Build filter criteria (shared base, only dateInterval differs)
        func makeCriteria(dateInterval: DateInterval) -> FilterCriteria {
            FilterCriteria(
                selectedAccounts: selectedAccounts,
                selectedCategories: selectedCategories,
                selectedSubcategories: selectedSubcategories,
                selectedTags: selectedTags,
                selectedNeeds: selectedNeeds,
                selectedCurrencies: selectedCurrencies,
                isExcludeMode: isExcludeMode,
                transactionTypeFilter: .all,
                amountCondition: amountCondition,
                searchText: searchText,
                dateInterval: dateInterval
            )
        }

        let currentFiltered = FilterService.filterForTrends(
            transactions: transactions,
            accounts: accounts,
            criteria: makeCriteria(dateInterval: interval)
        )

        let previousFiltered = FilterService.filterForTrends(
            transactions: transactions,
            accounts: accounts,
            criteria: makeCriteria(dateInterval: previousInterval)
        )

        // Exclude balance adjustments and transfers from the report
        let currentTxns = currentFiltered.filter { $0.balanceAdjustmentType == nil }
        let previousTxns = previousFiltered.filter { $0.balanceAdjustmentType == nil }

        // Build pivot tree
        let hierarchy = groupingState.activeDimensions
        rootNodes = PivotTableCalculator.buildTree(
            currentTransactions: currentTxns,
            previousTransactions: previousTxns,
            hierarchy: hierarchy,
            preferredCurrency: preferredCurrency
        )

        // Flatten for rendering
        flattenedRows = PivotTableCalculator.flatten(nodes: rootNodes)

        // Calculate net flow from root nodes
        let flow = PivotTableCalculator.calculateNetFlow(currentNodes: rootNodes)
        netFlowCurrent = flow.current
        netFlowPrevious = previousTxns.isEmpty ? nil : previousTxns.reduce(0) { $0 + $1.amountInPreferredCurrency }
        netFlowVariation = netFlowPrevious.flatMap {
            PreviousPeriodHelper.calculateVariation(currentAmount: flow.current, previousAmount: $0)
        }
    }
}
