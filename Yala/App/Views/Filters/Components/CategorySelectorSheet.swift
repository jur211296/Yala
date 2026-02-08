//
//  CategorySelectorSheet.swift
//  Yala
//
//  Shared hierarchical category/subcategory selector used by filter views.
//

import SwiftData
import SwiftUI

/// Hierarchical category selector sheet with subcategory selection.
/// Used by both RecordsFiltersView and ExportFiltersStepView.
struct CategorySelectorSheet: View {
    @Environment(\.dismiss) private var dismiss

    // MARK: - Data

    let categories: [Category]
    let subcategories: [Subcategory]

    // MARK: - Selection Binding

    @Binding var selectedSubcategories: Set<PersistentIdentifier>

    // MARK: - Local State

    @State private var expandedCategories: Set<Category> = []

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()

                ScrollView {
                    VStack(spacing: DS.Spacing.xxl) {
                        SectionBox(title: L10n.Filters.selectCategories) {
                            VStack(spacing: 0) {
                                selectAllRow

                                SubsectionDivider()

                                ForEach(Array(categories.enumerated()), id: \.element.id) {
                                    index, category in
                                    VStack(spacing: 0) {
                                        categoryRow(category)

                                        if expandedCategories.contains(category) {
                                            ForEach(visibleSubcategories(for: category)) {
                                                subcategory in
                                                SubsectionDivider()
                                                subcategoryRow(subcategory, category: category)
                                            }
                                        }
                                    }

                                    if index < categories.count - 1 {
                                        SubsectionDivider()
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.xxl)
                }
            }
            .navigationTitle(L10n.Filters.selectCategories)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "chevron.left", label: "Atrás") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Select All Row

    private var selectAllRow: some View {
        Button {
            // Guard: prevent action if subcategories not yet loaded
            guard !subcategories.isEmpty else { return }

            // Toggle logic:
            // - If everything is selected → clear (no filter = "Todas")
            // - Otherwise → select all
            if isEverythingSelected {
                selectedSubcategories.removeAll()
            } else {
                selectedSubcategories = Set(subcategories.map { $0.persistentModelID })
            }
        } label: {
            HStack {
                // Show "Deselect" only when everything is explicitly selected
                Text(isEverythingSelected ? L10n.Filters.deselectAll : L10n.Filters.selectAll)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: isEverythingSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(
                        isEverythingSelected
                            ? Color.brandPrimary : Color.yalaSecondaryText.opacity(0.4)
                    )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Category Row

    private func categoryRow(_ category: Category) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Circle()
                .fill(colorForHex(category.colorHex))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: category.iconName ?? "tag")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(category.name)
                    .font(.body)
                    .foregroundStyle(.primary)

                Text(selectionSummary(for: category))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Toggle all subcategories
            Button {
                toggleCategory(category)
            } label: {
                Image(systemName: selectionIcon(for: category))
                    .foregroundStyle(
                        isNoneSelected(for: category)
                            ? Color.yalaSecondaryText.opacity(0.4)
                            : Color.brandPrimary
                    )
            }
            .buttonStyle(.plain)

            // Expand/collapse
            Button {
                toggleExpanded(category)
            } label: {
                Image(systemName: "chevron.down")
                    .rotationEffect(.degrees(expandedCategories.contains(category) ? 0 : -90))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .onTapGesture {
            toggleExpanded(category)
        }
    }

    // MARK: - Subcategory Row

    private func subcategoryRow(_ subcategory: Subcategory, category: Category) -> some View {
        Button {
            if selectedSubcategories.contains(subcategory.persistentModelID) {
                selectedSubcategories.remove(subcategory.persistentModelID)
            } else {
                selectedSubcategories.insert(subcategory.persistentModelID)
            }
        } label: {
            HStack(spacing: DS.Spacing.md) {
                Circle()
                    .fill(colorForHex(subcategory.colorHex ?? category.colorHex))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: subcategory.iconName ?? "tag")
                            .font(.subheadline)
                            .foregroundStyle(.white)
                    )

                Text(subcategory.name)
                    .foregroundStyle(.primary)
                    .font(.body)

                Spacer()

                let isSelected = selectedSubcategories.contains(subcategory.persistentModelID)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(
                        isSelected ? Color.brandPrimary : Color.yalaSecondaryText.opacity(0.4)
                    )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .padding(.leading, 48)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private var visibleSubcategories: [Subcategory] {
        subcategories.filter { $0.isVisible }
    }

    private func visibleSubcategories(for category: Category) -> [Subcategory] {
        subcategories.filter { $0.category == category && $0.isVisible }
    }

    private var isEverythingSelected: Bool {
        // Check against ALL subcategories, not just visible ones
        let allIDs = Set(subcategories.map { $0.persistentModelID })
        return !allIDs.isEmpty && selectedSubcategories == allIDs
    }

    private func toggleExpanded(_ category: Category) {
        if expandedCategories.contains(category) {
            expandedCategories.remove(category)
        } else {
            expandedCategories.insert(category)
        }
    }

    private func toggleCategory(_ category: Category) {
        let subs = visibleSubcategories(for: category)
        let allSelected = subs.allSatisfy { selectedSubcategories.contains($0.persistentModelID) }

        if allSelected {
            subs.forEach { selectedSubcategories.remove($0.persistentModelID) }
        } else {
            subs.forEach { selectedSubcategories.insert($0.persistentModelID) }
        }
    }

    private func isNoneSelected(for category: Category) -> Bool {
        let subs = visibleSubcategories(for: category)
        return !subs.contains { selectedSubcategories.contains($0.persistentModelID) }
    }

    private func selectionIcon(for category: Category) -> String {
        let subs = visibleSubcategories(for: category)
        if subs.isEmpty { return "circle" }

        let selectedCount = subs.filter { selectedSubcategories.contains($0.persistentModelID) }
            .count
        if selectedCount == 0 { return "circle" }
        if selectedCount == subs.count { return "checkmark.circle.fill" }
        return "minus.circle.fill"
    }

    private func selectionSummary(for category: Category) -> String {
        let subs = visibleSubcategories(for: category)
        let total = subs.count
        let selected = subs.filter { selectedSubcategories.contains($0.persistentModelID) }.count

        if total == 0 { return L10n.Filters.noSubcategories }
        if selected == 0 { return L10n.Filters.noneSelected }
        if selected == total { return L10n.Filters.allSubcategories }
        return "\(selected) / \(total)"
    }
}
