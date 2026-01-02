//
//  Filterable.swift
//  Neto
//
//  Protocol for ViewModels with filter capabilities.
//

import Foundation
import SwiftData

/// Protocol for ViewModels that support filtering transactions
/// Used by RecordsViewModel and TrendsDetailViewModel
protocol Filterable: AnyObject {

    // MARK: - Filter Properties

    /// Selected accounts for filtering
    var selectedAccounts: Set<PersistentIdentifier> { get set }

    /// Selected categories for filtering
    var selectedCategories: Set<PersistentIdentifier> { get set }

    /// Selected subcategories for filtering
    var selectedSubcategories: Set<PersistentIdentifier> { get set }

    /// Selected natures for filtering
    var selectedNatures: Set<SubcategoryNature> { get set }

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

    // MARK: - Actions

    /// Clear all filters
    func clearFilters()
}

// MARK: - Default Implementation

extension Filterable {

    /// Default implementation for hasActiveFilters
    var hasActiveFiltersDefault: Bool {
        !selectedAccounts.isEmpty || !selectedCategories.isEmpty || !selectedSubcategories.isEmpty
            || !selectedNatures.isEmpty || !selectedTags.isEmpty || !selectedCurrencies.isEmpty
            || amountCondition.isActive || !searchText.isEmpty
    }

    /// Default implementation for clearFilters
    func clearFiltersDefault() {
        selectedAccounts.removeAll()
        selectedCategories.removeAll()
        selectedSubcategories.removeAll()
        selectedNatures.removeAll()
        selectedTags.removeAll()
        selectedCurrencies.removeAll()
        amountCondition = .any
        searchText = ""
    }
}
