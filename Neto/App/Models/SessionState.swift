//
//  SessionState.swift
//  Neto
//
//  Created by Neto Refactoring.
//

import SwiftData
import SwiftUI

/// Global session state to manage synchronization between views
@Observable
class SessionState {

    // MARK: - Period State

    /// The currently selected period, synchronized across Panel and Statistics
    var selectedPeriod: DetailPeriod {
        didSet {
            // Update globalFilters.dateInterval when period changes
            globalFilters.dateInterval = selectedPeriod.dateInterval
        }
    }

    // MARK: - Global Filter State (shared between Panel and Statistics)

    /// Selected account IDs (empty = all accounts)
    var selectedAccountIDs: Set<PersistentIdentifier> = []

    /// Selected category IDs (empty = all categories)
    var selectedCategoryIDs: Set<PersistentIdentifier> = []

    /// Selected subcategory names (empty = all subcategories)
    var selectedSubcategoryNames: Set<String> = []

    /// Selected natures (empty = all natures)
    var selectedNatures: Set<SubcategoryNature> = []

    // MARK: - Filter Criteria State

    /// Global filter criteria shared across views (Trends, Records)
    /// Views can bind to this for automatic synchronization.
    var globalFilters: FilterCriteria = .empty

    // MARK: - Computed Properties

    /// Convenience: current date interval based on selectedPeriod
    var currentDateInterval: DateInterval {
        selectedPeriod.dateInterval
    }

    /// Check if any global filter is active
    var hasActiveFilters: Bool {
        !selectedAccountIDs.isEmpty || !selectedCategoryIDs.isEmpty
            || !selectedSubcategoryNames.isEmpty || !selectedNatures.isEmpty
    }

    // MARK: - Actions

    /// Clear all global filters (except period)
    func clearFilters() {
        selectedAccountIDs.removeAll()
        selectedCategoryIDs.removeAll()
        selectedSubcategoryNames.removeAll()
        selectedNatures.removeAll()
        globalFilters.clearAll()
    }

    /// Toggle account filter (single-select behavior for Panel compatibility)
    func toggleAccountFilter(_ id: PersistentIdentifier) {
        if selectedAccountIDs.contains(id) {
            selectedAccountIDs.remove(id)
        } else {
            selectedAccountIDs.removeAll()  // Single-select: clear others
            selectedAccountIDs.insert(id)
        }
    }

    /// Toggle category filter
    func toggleCategoryFilter(_ id: PersistentIdentifier) {
        if selectedCategoryIDs.contains(id) {
            selectedCategoryIDs.remove(id)
            // Clear subcategories when category is deselected
            selectedSubcategoryNames.removeAll()
        } else {
            selectedCategoryIDs.removeAll()  // Single-select for Panel
            selectedCategoryIDs.insert(id)
        }
    }

    /// Toggle subcategory filter
    func toggleSubcategoryFilter(_ name: String) {
        if selectedSubcategoryNames.contains(name) {
            selectedSubcategoryNames.remove(name)
        } else {
            selectedSubcategoryNames.removeAll()  // Single-select for Panel
            selectedSubcategoryNames.insert(name)
        }
    }

    /// Toggle nature filter
    func toggleNatureFilter(_ nature: SubcategoryNature) {
        if selectedNatures.contains(nature) {
            selectedNatures.remove(nature)
        } else {
            selectedNatures.removeAll()  // Single-select for Panel
            selectedNatures.insert(nature)
        }
    }

    /// Reset to default state
    func resetToDefaults() {
        selectedPeriod = .allTime
        clearFilters()
        globalFilters.dateInterval = selectedPeriod.dateInterval
    }

    // MARK: - Initialization

    init() {
        // Load default period from AppStorage or fallback to .allTime
        if let rawValue = UserDefaults.standard.string(forKey: "defaultPeriod"),
            let period = DetailPeriod(rawValue: rawValue)
        {
            self.selectedPeriod = period
        } else {
            self.selectedPeriod = .allTime
        }

        // Set initial dateInterval on globalFilters
        self.globalFilters.dateInterval = selectedPeriod.dateInterval
    }
}
