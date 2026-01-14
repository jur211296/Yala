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
            globalFilters.dateInterval = selectedPeriod.dateInterval(customRange: customDateRange)
        }
    }

    /// Custom date range for .custom period (persisted via UserDefaults)
    var customDateRange: DateInterval? {
        didSet {
            // Persist custom range
            if let range = customDateRange {
                UserDefaults.standard.set(
                    range.start.timeIntervalSince1970, forKey: "customPeriodStart")
                UserDefaults.standard.set(
                    range.end.timeIntervalSince1970, forKey: "customPeriodEnd")
            } else {
                UserDefaults.standard.removeObject(forKey: "customPeriodStart")
                UserDefaults.standard.removeObject(forKey: "customPeriodEnd")
            }
            // Update filter if currently on custom period
            if selectedPeriod == .custom {
                globalFilters.dateInterval = selectedPeriod.dateInterval(
                    customRange: customDateRange)
            }
        }
    }

    // MARK: - Trend Metric State

    /// The currently selected trend metric (Balance/Income/Expense), synchronized across Panel and Statistics
    /// Defaults to .balance
    var selectedTrendMetric: TrendMetric = .balance

    /// Tracks whether the current Expense selection was automatic (due to filters) or manual (user click)
    /// Used to determine if we should auto-reset to Balance when filters are cleared
    var isExpenseAutomatic: Bool = false

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
        selectedPeriod.dateInterval(customRange: customDateRange)
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
        customDateRange = nil
        clearFilters()
        globalFilters.dateInterval = selectedPeriod.dateInterval()
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

        // Load persisted custom date range
        let startTimestamp = UserDefaults.standard.double(forKey: "customPeriodStart")
        let endTimestamp = UserDefaults.standard.double(forKey: "customPeriodEnd")
        if startTimestamp > 0 && endTimestamp > 0 {
            let start = Date(timeIntervalSince1970: startTimestamp)
            let end = Date(timeIntervalSince1970: endTimestamp)
            if start < end {
                self.customDateRange = DateInterval(start: start, end: end)
            }
        }

        // Set initial dateInterval on globalFilters
        self.globalFilters.dateInterval = selectedPeriod.dateInterval(customRange: customDateRange)
    }
}
