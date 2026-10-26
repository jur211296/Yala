//
//  Filterable.swift
//  Yala
//
//  Protocol for ViewModels with filter capabilities.
//

import Foundation
import SwiftData

/// Protocol for ViewModels that support filtering transactions
/// Used by RecordsViewModel and StatisticsViewModel
protocol Filterable: AnyObject {

    // MARK: - Filter Properties

    /// Selected accounts for filtering
    var selectedAccounts: Set<PersistentIdentifier> { get set }

    /// Selected categories for filtering
    var selectedCategories: Set<PersistentIdentifier> { get set }

    /// Selected subcategories for filtering
    var selectedSubcategories: Set<PersistentIdentifier> { get set }

    /// Selected natures for filtering
    var selectedNeeds: Set<SubcategoryNeed> { get set }

    /// Selected tags for filtering
    var selectedTags: Set<PersistentIdentifier> { get set }

    /// Selected currencies for filtering
    var selectedCurrencies: Set<CurrencyCode> { get set }

    /// Amount filter condition
    var amountCondition: AmountFilterCondition { get set }

    /// Search text for note filtering
    var searchText: String { get set }

    // MARK: - Computed Properties

    /// Whether any filter is active
    var hasActiveFilters: Bool { get }

    /// Number of active filter types (for badge)
    var activeFilterCount: Int { get }

    // Lo oculto de cada dimensión («Sin X»). Convive con los `selected*` de arriba, que son los incluidos («Solo X»).
    // Sustituye al antiguo `isExcludeMode` global (opción B, 2026-10-25).
    var excludedAccounts: Set<PersistentIdentifier> { get set }
    var excludedCategories: Set<PersistentIdentifier> { get set }
    var excludedSubcategories: Set<PersistentIdentifier> { get set }
    var excludedNeeds: Set<SubcategoryNeed> { get set }
    var excludedTags: Set<PersistentIdentifier> { get set }
    var excludedCurrencies: Set<CurrencyCode> { get set }

    /// Selected transaction natures (income/expense chips)
    var selectedTransactionNatures: Set<TransactionNature> { get set }

    /// Shared/personal expense filter
    var sharedExpenseFilter: SharedExpenseFilter { get set }

    // MARK: - Actions

    /// Clear all filters
    func clearFilters()
}

// MARK: - Default Implementation

extension Filterable {

    /// Build FilterCriteria from current Filterable state.
    ///
    /// IMPORTANT: this default does NOT populate `selectedTagUUIDs` (no access to
    /// `[Tag]` catalog from the protocol). Consumers that pass the result to
    /// `FilterService.matchesCriteria` / `filterForTrends` MUST either:
    ///   - call `criteria.populateTagUUIDs(fromCatalog: allTags)` before use, or
    ///   - use `filterCriteria(withTagCatalog:)` overload that does it for them.
    /// Otherwise tag-filter matching is silently skipped (CSV-mirror SSOT).
    var filterCriteria: FilterCriteria {
        var c = FilterCriteria()
        c.selectedAccounts = selectedAccounts
        c.selectedCategories = selectedCategories
        c.selectedSubcategories = selectedSubcategories
        c.selectedTags = selectedTags
        c.selectedNeeds = selectedNeeds
        c.selectedTransactionNatures = selectedTransactionNatures
        c.selectedCurrencies = selectedCurrencies
        c.excludedAccounts = excludedAccounts
        c.excludedCategories = excludedCategories
        c.excludedSubcategories = excludedSubcategories
        c.excludedNeeds = excludedNeeds
        c.excludedTags = excludedTags
        c.excludedCurrencies = excludedCurrencies
        c.amountCondition = amountCondition
        c.searchText = searchText
        c.sharedExpenseFilter = sharedExpenseFilter
        return c
    }

    /// Build FilterCriteria with `selectedTagUUIDs` populated from the given
    /// catalog. Required when the result will be passed to `FilterService`.
    func filterCriteria(withTagCatalog allTags: [Tag]) -> FilterCriteria {
        var c = filterCriteria
        c.populateTagUUIDs(fromCatalog: allTags)
        return c
    }

    /// Default implementation for hasActiveFilters
    var hasActiveFiltersDefault: Bool {
        filterCriteria.hasActiveFilters
    }

    /// Default implementation for activeFilterCount
    var activeFilterCountDefault: Int {
        filterCriteria.activeFilterCount
    }

    /// Default implementation for clearFilters
    func clearFiltersDefault() {
        selectedAccounts.removeAll()
        selectedCategories.removeAll()
        selectedSubcategories.removeAll()
        selectedNeeds.removeAll()
        selectedTransactionNatures.removeAll()
        selectedTags.removeAll()
        selectedCurrencies.removeAll()
        amountCondition = .any
        searchText = ""
        excludedAccounts.removeAll()
        excludedCategories.removeAll()
        excludedSubcategories.removeAll()
        excludedNeeds.removeAll()
        excludedTags.removeAll()
        excludedCurrencies.removeAll()
        sharedExpenseFilter = .all
    }
}
