//
//  FilterChipHelper.swift
//  Yala
//
//  Helper functions for aggregated filter chips.
//  Used across PanelView, TrendsTabView, CategoriesTabView, and RecordsTabView.
//

import SwiftData
import SwiftUI

// MARK: - Account Chips

/// Generates a single aggregated account chip from selected accounts.
/// Returns empty array if no accounts are selected.
func buildAccountChips(
    selectedAccounts: Set<PersistentIdentifier>,
    allAccounts: [Account]
) -> [AccountChip] {
    guard !selectedAccounts.isEmpty else { return [] }
    let selectedList = allAccounts.filter { selectedAccounts.contains($0.persistentModelID) }
    guard let firstName = selectedList.first?.name else { return [] }
    return [AccountChip(name: firstName, count: selectedList.count)]
}

// MARK: - Tag Chips

/// Generates individual tag chips from selected tags.
func buildTagChips(
    selectedTags: Set<PersistentIdentifier>,
    allTags: [Tag]
) -> [TagChip] {
    allTags.filter { selectedTags.contains($0.persistentModelID) }
        .map {
            TagChip(
                id: $0.persistentModelID,
                tagID: $0.persistentModelID,
                name: $0.name,
                iconName: $0.iconName,
                colorHex: $0.colorHex
            )
        }
}

// MARK: - Need Chips

/// Generates need chip data from selected needs.
func buildNeedChips(
    selectedNeeds: Set<SubcategoryNeed>
) -> [NeedChipData] {
    selectedNeeds.sorted(by: { $0.rawValue < $1.rawValue })
        .map { NeedChipData(need: $0) }
}

/// Data for an aggregated filter chip
struct AggregatedChipData {
    let name: String
    let iconName: String?
    let colorHex: String
    let count: Int
}

// MARK: - Aggregated Category Chip

/// Generates aggregated category chip data from selected subcategories.
/// Returns nil if no subcategories are selected OR if ALL are selected (= no filter = "Todas").
func aggregatedCategoryChip(
    selectedSubcategories: Set<PersistentIdentifier>,
    allSubcategories: [Subcategory]
) -> AggregatedChipData? {
    // Empty = no filter
    guard !selectedSubcategories.isEmpty else { return nil }

    // All selected = no filter (equivalent to "Todas")
    let allIDs = Set(allSubcategories.map { $0.persistentModelID })
    if selectedSubcategories == allIDs { return nil }

    // Get unique parent categories from selected subcategories
    let selectedSubs = allSubcategories.filter {
        selectedSubcategories.contains($0.persistentModelID)
    }

    let parentCategories = Set(selectedSubs.compactMap { $0.category })

    guard let first = parentCategories.first else { return nil }

    return AggregatedChipData(
        name: first.name,
        iconName: first.iconName,
        colorHex: first.colorHex,
        count: parentCategories.count
    )
}

// MARK: - Aggregated Subcategory Chip

/// Generates aggregated subcategory chip data from selected subcategories.
/// Returns nil if no subcategories are selected OR if ALL are selected (= no filter = "Todas").
func aggregatedSubcategoryChip(
    selectedSubcategories: Set<PersistentIdentifier>,
    allSubcategories: [Subcategory]
) -> AggregatedChipData? {
    // Empty = no filter
    guard !selectedSubcategories.isEmpty else { return nil }

    // All selected = no filter (equivalent to "Todas")
    let allIDs = Set(allSubcategories.map { $0.persistentModelID })
    if selectedSubcategories == allIDs { return nil }

    let selected = allSubcategories.filter {
        selectedSubcategories.contains($0.persistentModelID)
    }

    guard let first = selected.first else { return nil }

    // Use subcategory color if available, otherwise fall back to parent category color
    let color =
        (first.colorHex?.isEmpty == false ? first.colorHex : nil)
        ?? first.safeCategory.colorHex

    return AggregatedChipData(
        name: first.name,
        iconName: first.iconName,
        colorHex: color,
        count: selected.count
    )
}
