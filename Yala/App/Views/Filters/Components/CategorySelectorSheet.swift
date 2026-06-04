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
    @Environment(\.yalaTheme) private var theme

    // MARK: - Data

    let categories: [Category]
    let subcategories: [Subcategory]

    // MARK: - Selection Binding

    @Binding var selectedSubcategories: Set<PersistentIdentifier>

    // MARK: - Local State

    @State private var expandedCategories: Set<PersistentIdentifier> = []

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()

                ScrollView {
                    VStack(spacing: DS.Spacing.xxl) {
                        SectionBox(title: L10n.Filters.selectCategories) {
                            VStack(spacing: DS.Spacing.none) {
                                selectAllRow

                                SubsectionDivider()

                                ForEach(Array(categories.enumerated()), id: \.element.id) {
                                    index, category in
                                    VStack(spacing: DS.Spacing.none) {
                                        categoryRow(category)

                                        if expandedCategories.contains(category.persistentModelID) {
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
                    YalaToolbarButton(systemName: "chevron.left", label: L10n.Action.back) {
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
                    .font(DS.Typography.headline)
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: isEverythingSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(
                        isEverythingSelected
                            ? theme.accent : theme.secondaryText.opacity(0.4)
                    )
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.FormRow.paddingV)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Category Row

    private func categoryRow(_ category: Category) -> some View {
        Button {
            toggleExpanded(category)
        } label: {
            HStack(spacing: DS.Spacing.md) {
                Circle()
                    .fill(colorForHex(category.colorHex))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: category.iconName ?? "tag")
                            .font(DS.Typography.subheadline)
                            .foregroundStyle(.white)
                            .accessibilityHidden(true)
                    )

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(category.name)
                        .font(DS.Typography.body)
                        .foregroundStyle(.primary)

                    Text(selectionSummary(for: category))
                        .font(DS.Typography.caption)
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
                                ? theme.secondaryText.opacity(0.4)
                                : theme.accent
                        )
                        .accessibilityHidden(true)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isNoneSelected(for: category) ? L10n.Filters.selectAll : L10n.Filters.deselectAll)

                // Expand/collapse
                Button {
                    toggleExpanded(category)
                } label: {
                    Image(systemName: "chevron.down")
                        .rotationEffect(.degrees(expandedCategories.contains(category.persistentModelID) ? 0 : -90))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(expandedCategories.contains(category.persistentModelID) ? L10n.Accessibility.collapse : L10n.Accessibility.expand)
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.FormRow.paddingV)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
                            .font(DS.Typography.subheadline)
                            .foregroundStyle(.white)
                            .accessibilityHidden(true)
                    )

                Text(subcategory.name)
                    .foregroundStyle(.primary)
                    .font(DS.Typography.body)

                Spacer()

                let isSelected = selectedSubcategories.contains(subcategory.persistentModelID)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(
                        isSelected ? theme.accent : theme.secondaryText.opacity(0.4)
                    )
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Chip.paddingH)
            .padding(.leading, DS.Spacing.xxxxl)
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
        let id = category.persistentModelID
        if expandedCategories.contains(id) {
            expandedCategories.remove(id)
        } else {
            expandedCategories.insert(id)
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
        let selected = subs.count(where: { selectedSubcategories.contains($0.persistentModelID) })

        if total == 0 { return L10n.Filters.noSubcategories }
        if selected == 0 { return L10n.Filters.noneSelected }
        if selected == total { return L10n.Filters.allSubcategories }
        return "\(selected) / \(total)"
    }
}
