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

    var sharedExpenseFilter: SharedExpenseFilter = .all

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

    /// Filtro de tipo de transacción del pivot según el modo. En Solo Gastos fuerza
    /// `.expense` (paridad con `RecordsViewModel`): en arranque en frío
    /// `SessionState.selectedTransactionNatures` es `[]` (el `didSet` de
    /// `isExpensesOnlyMode` no corre en `init`), así que sin esto el pivot mostraría
    /// ingresos. Solo lógica → testeable.
    static func transactionTypeFilter(expensesOnly: Bool) -> TransactionTypeFilter {
        expensesOnly ? .expense : .all
    }

    func calculateReport(
        transactions: [TransactionItem],
        accounts: [Account],
        preferredCurrency: String,
        allTags: [Tag] = [],
        now: Date = .now,
        period: DetailPeriod? = nil,
        comparisonMode: ComparisonMode? = nil,
        expensesOnly: Bool? = nil
    ) {
        // Proyección "mi parte" (neto) desde el set AMPLIO (`transactions` completo, con AMBAS
        // hermanas del bridge, antes de cualquier filtro por cuenta/etiqueta).
        // Sin `context` aquí (evita tocar la firma de FinancialReportView, cuyo body está al
        // límite del type-checker): `build(from:)` cubre los casos comunes; residual conocido —
        // la rara pata de préstamo SUELTA (payer con parte 0) no se suprime en el informe.
        let adjustment = GroupBridgeStatsAdjustment.build(from: transactions)
        let resolvedPeriod = period ?? detailPeriod
        let resolvedMode = comparisonMode ?? SessionState.shared.comparisonMode
        let resolvedExpensesOnly = expensesOnly ?? SessionState.shared.isExpensesOnlyMode
        let interval = resolvedPeriod.dateInterval(customRange: customDateRange, now: now)
        let previousInterval = PreviousPeriodHelper.previousInterval(
            for: resolvedPeriod,
            mode: resolvedMode,
            customRange: customDateRange,
            now: now
        )

        // Build filter criteria (shared base, only dateInterval differs)
        func makeCriteria(dateInterval: DateInterval) -> FilterCriteria {
            var criteria = FilterCriteria(
                selectedAccounts: selectedAccounts,
                selectedCategories: selectedCategories,
                selectedSubcategories: selectedSubcategories,
                selectedTags: selectedTags,
                selectedNeeds: selectedNeeds,
                selectedTransactionNatures: selectedTransactionNatures,
                selectedCurrencies: selectedCurrencies,
                isExcludeMode: isExcludeMode,
                transactionTypeFilter: Self.transactionTypeFilter(expensesOnly: resolvedExpensesOnly),
                amountCondition: amountCondition,
                searchText: searchText,
                dateInterval: dateInterval
            )
            criteria.populateTagUUIDs(
                from: allTags.filter { selectedTags.contains($0.persistentModelID) }
            )
            return criteria
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
        // WTD/MTD/YTD: recorta el previo al span de días del actual (p20-15).
        // No-op en modo año, cerrados y rodantes (`aggregatePreviousNeedsAlignment`).
        let previousTxns = DateAlignmentHelper.alignedPreviousItems(
            previousFiltered.filter { $0.balanceAdjustmentType == nil },
            currentDates: currentTxns.map(\.date),
            currentInterval: interval,
            previousInterval: previousInterval,
            period: resolvedPeriod,
            comparisonMode: resolvedMode
        ) { $0.date }

        // Build pivot tree
        let hierarchy = groupingState.activeDimensions
        rootNodes = PivotTableCalculator.buildTree(
            currentTransactions: currentTxns,
            previousTransactions: previousTxns,
            hierarchy: hierarchy,
            preferredCurrency: preferredCurrency,
            allTags: allTags,
            adjustment: adjustment
        )

        // Flatten for rendering
        flattenedRows = PivotTableCalculator.flatten(nodes: rootNodes)

        // Calculate net flow from filtered transactions (always in preferred currency).
        // Income-aware: suprime las patas de préstamo derivadas y netea la pata real a `-myShare`.
        netFlowCurrent = currentTxns.reduce(0.0) { $0 + (adjustment.incomeAwarePreferred($1) ?? 0) }
        netFlowPrevious = previousTxns.isEmpty
            ? nil
            : previousTxns.reduce(0.0) { $0 + (adjustment.incomeAwarePreferred($1) ?? 0) }
        netFlowVariation = netFlowPrevious.flatMap {
            PreviousPeriodHelper.calculateVariation(currentAmount: netFlowCurrent, previousAmount: $0)
        }
    }
}
