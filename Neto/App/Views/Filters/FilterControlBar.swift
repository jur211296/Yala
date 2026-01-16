//
//  FilterControlBar.swift
//  Neto
//
//  Shared control bar component for period selection and filter chips.
//  Used by TrendsTabView and RecordsEmbeddedView for consistent UI.
//

import SwiftData
import SwiftUI

// MARK: - Filter Control Bar

/// A reusable control bar displaying a period selector and filter chips.
/// Used to ensure consistent UI between Trends and Records tabs.
struct FilterControlBar<PeriodView: View>: View {

    // MARK: - Properties

    /// The period selector view (TrendsPeriodMenu or RecordsPeriodMenu)
    let periodSelector: PeriodView

    /// Whether any filters are active
    let hasActiveFilters: Bool

    /// Number of active filter types
    let activeFilterCount: Int

    // MARK: - Filter Data (for chip generation)

    /// Selected accounts
    let selectedAccounts: Set<PersistentIdentifier>
    let allAccounts: [Account]

    /// Selected categories and subcategories
    let selectedCategories: Set<PersistentIdentifier>
    let selectedSubcategories: Set<PersistentIdentifier>
    let allCategories: [Category]

    /// Selected tags
    let selectedTags: Set<PersistentIdentifier>
    let allTags: [Tag]

    /// Selected natures
    let selectedNatures: Set<SubcategoryNature>

    /// Transaction type filter (optional, only for Records)
    let transactionTypeFilter: TransactionTypeFilter?

    // MARK: - Callbacks

    let onClearAccounts: () -> Void
    let onClearCategories: () -> Void
    let onClearTags: () -> Void
    let onClearNatures: () -> Void
    let onClearTransactionType: (() -> Void)?
    let onClearAll: () -> Void

    // MARK: - Body

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            // Period dropdown on the left
            periodSelector

            // Filter chips scrollable area
            if hasActiveFilters {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DS.Spacing.sm) {
                        // Account chips - "First +x" format
                        if let chipText = accountsChipText {
                            FilterChipView(text: chipText, onClear: onClearAccounts)
                        }

                        // Category chips - "First +x" format
                        if let chipText = categoriesChipText {
                            FilterChipView(text: chipText, onClear: onClearCategories)
                        }

                        // Tag chips - "First +x" format
                        if let chipText = tagsChipText {
                            FilterChipView(text: chipText, onClear: onClearTags)
                        }

                        // Nature chips - "First +x" format
                        if let chipText = naturesChipText {
                            FilterChipView(text: chipText, onClear: onClearNatures)
                        }

                        // Transaction type chip (only for Records)
                        if let filter = transactionTypeFilter,
                            filter != .all,
                            let onClear = onClearTransactionType
                        {
                            FilterChipView(text: filter.displayName, onClear: onClear)
                        }

                        // Clear All button if multiple filters
                        if activeFilterCount > 1 {
                            Button {
                                withAnimation {
                                    onClearAll()
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
    }

    // MARK: - Chip Text Helpers

    /// Returns chip text for accounts in "First +x" format
    private var accountsChipText: String? {
        guard !selectedAccounts.isEmpty else { return nil }
        let selectedNames =
            allAccounts
            .filter { selectedAccounts.contains($0.persistentModelID) }
            .map { $0.name }
        guard !selectedNames.isEmpty else { return nil }
        if selectedNames.count == 1 {
            return selectedNames.first
        }
        return "\(selectedNames.first ?? "") +\(selectedNames.count - 1)"
    }

    /// Returns chip text for categories/subcategories in "First +x" format
    private var categoriesChipText: String? {
        var names: [String] = []
        for cat in allCategories where selectedCategories.contains(cat.persistentModelID) {
            names.append(cat.name)
        }
        guard !names.isEmpty || !selectedSubcategories.isEmpty else { return nil }

        let totalCount = selectedCategories.count + selectedSubcategories.count
        if totalCount == 1 {
            return names.first ?? "Categoría"
        }
        return "\(names.first ?? "Categorías") +\(totalCount - 1)"
    }

    /// Returns chip text for tags in "First +x" format
    private var tagsChipText: String? {
        guard !selectedTags.isEmpty else { return nil }
        let selectedNames =
            allTags
            .filter { selectedTags.contains($0.persistentModelID) }
            .map { $0.name }
        guard !selectedNames.isEmpty else { return nil }
        if selectedNames.count == 1 {
            return selectedNames.first
        }
        return "\(selectedNames.first ?? "") +\(selectedNames.count - 1)"
    }

    /// Returns chip text for natures in "First +x" format
    private var naturesChipText: String? {
        guard !selectedNatures.isEmpty else { return nil }
        let names = selectedNatures.map { $0.displayName }
        if names.count == 1 {
            return names.first
        }
        return "\(names.first ?? "") +\(names.count - 1)"
    }
}

// MARK: - Convenience Initializers

extension FilterControlBar {

    /// Initialize for Trends tab (no transaction type filter)
    init(
        periodSelector: PeriodView,
        hasActiveFilters: Bool,
        activeFilterCount: Int,
        selectedAccounts: Set<PersistentIdentifier>,
        allAccounts: [Account],
        selectedCategories: Set<PersistentIdentifier>,
        selectedSubcategories: Set<PersistentIdentifier>,
        allCategories: [Category],
        selectedTags: Set<PersistentIdentifier>,
        allTags: [Tag],
        selectedNatures: Set<SubcategoryNature>,
        onClearAccounts: @escaping () -> Void,
        onClearCategories: @escaping () -> Void,
        onClearTags: @escaping () -> Void,
        onClearNatures: @escaping () -> Void,
        onClearAll: @escaping () -> Void
    ) {
        self.periodSelector = periodSelector
        self.hasActiveFilters = hasActiveFilters
        self.activeFilterCount = activeFilterCount
        self.selectedAccounts = selectedAccounts
        self.allAccounts = allAccounts
        self.selectedCategories = selectedCategories
        self.selectedSubcategories = selectedSubcategories
        self.allCategories = allCategories
        self.selectedTags = selectedTags
        self.allTags = allTags
        self.selectedNatures = selectedNatures
        self.transactionTypeFilter = nil
        self.onClearAccounts = onClearAccounts
        self.onClearCategories = onClearCategories
        self.onClearTags = onClearTags
        self.onClearNatures = onClearNatures
        self.onClearTransactionType = nil
        self.onClearAll = onClearAll
    }
}
