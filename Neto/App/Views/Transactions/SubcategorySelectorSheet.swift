//
//  SubcategorySelectorSheet.swift
//  Neto
//
//  Created by Neto - New Transaction Form.
//

import SwiftData
import SwiftUI

// MARK: - Subcategory Selector Sheet

/// Sheet para seleccionar una subcategoría agrupada por categoría
struct SubcategorySelectorSheet: View {
    @Environment(\.dismiss) private var dismiss

    // Query subcategories directly to avoid lazy loading issues
    @Query(sort: \Subcategory.sortOrder, order: .forward) private var allSubcategories:
        [Subcategory]

    // Query recent transactions to get recently used subcategories
    @Query(sort: \TransactionItem.date, order: .reverse) private var recentTransactions:
        [TransactionItem]

    @Binding var selectedSubcategory: Subcategory?
    let transactionType: TransactionType

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()

                ScrollView {
                    VStack(spacing: 20) {
                        if groupedSubcategories.isEmpty {
                            // Empty state
                            VStack(spacing: 16) {
                                Image(systemName: "tag.slash")
                                    .font(.system(size: 48))
                                    .foregroundStyle(.secondary)
                                Text("No hay subcategorías disponibles")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                        } else {
                            // Recientes section (if any)
                            if !recentSubcategories.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "clock.arrow.circlepath")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text("Recientes")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.leading, 4)

                                    LazyVGrid(columns: columns, spacing: 12) {
                                        ForEach(recentSubcategories, id: \.persistentModelID) {
                                            subcategory in
                                            SubcategoryGridItem(
                                                subcategory: subcategory,
                                                categoryColor: subcategory.category.colorHex,
                                                isSelected: isSelected(subcategory),
                                                action: {
                                                    selectedSubcategory = subcategory
                                                    dismiss()
                                                }
                                            )
                                        }
                                    }
                                }

                                Divider()
                                    .padding(.vertical, 4)
                            }

                            // All categories
                            ForEach(groupedSubcategories, id: \.category.persistentModelID) {
                                group in
                                SubcategoryGridSection(
                                    category: group.category,
                                    subcategories: group.subcategories,
                                    columns: columns,
                                    selectedSubcategory: $selectedSubcategory,
                                    onSelect: { subcategory in
                                        selectedSubcategory = subcategory
                                        dismiss()
                                    }
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("Subcategoría")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NetoToolbarButton(systemName: "xmark") {
                        dismiss()
                    }
                }
            }
        }
        .tint(Color.electricIndigo)
    }

    /// Last 4 unique subcategories used in recent transactions
    private var recentSubcategories: [Subcategory] {
        var seen = Set<PersistentIdentifier>()
        var result: [Subcategory] = []

        for transaction in recentTransactions {
            guard let subcategory = transaction.subcategory else { continue }
            guard subcategory.isVisible else { continue }

            // Check if matches current transaction type
            let category = subcategory.category
            let matchesType: Bool
            switch transactionType {
            case .expense:
                matchesType = !category.isIncome
            case .income:
                matchesType = category.isIncome
            case .transfer:
                matchesType = false
            }

            guard matchesType else { continue }

            let id = subcategory.persistentModelID
            if !seen.contains(id) {
                seen.insert(id)
                result.append(subcategory)
                if result.count >= 4 { break }
            }
        }

        return result
    }

    private func isSelected(_ subcategory: Subcategory) -> Bool {
        guard let selected = selectedSubcategory else { return false }
        return selected.persistentModelID == subcategory.persistentModelID
    }

    /// Groups subcategories by their parent category, filtered by transaction type
    private var groupedSubcategories: [(category: Category, subcategories: [Subcategory])] {
        // Filter subcategories by transaction type and visibility
        let filtered = allSubcategories.filter { subcategory in
            guard subcategory.isVisible else { return false }

            let category = subcategory.category
            guard category.isVisible else { return false }

            switch transactionType {
            case .expense:
                return !category.isIncome
            case .income:
                return category.isIncome
            case .transfer:
                return false  // Transfers don't need subcategories
            }
        }

        // Group by category
        let grouped = Dictionary(grouping: filtered) { $0.category }

        // Sort by category sortOrder and convert to array of tuples
        return
            grouped
            .sorted { $0.key.sortOrder < $1.key.sortOrder }
            .map {
                (category: $0.key, subcategories: $0.value.sorted { $0.sortOrder < $1.sortOrder })
            }
    }
}

// MARK: - Subcategory Grid Section

struct SubcategoryGridSection: View {
    let category: Category
    let subcategories: [Subcategory]
    let columns: [GridItem]
    @Binding var selectedSubcategory: Subcategory?
    let onSelect: (Subcategory) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Category header
            HStack(spacing: 8) {
                Circle()
                    .fill(Color(hex: category.colorHex))
                    .frame(width: 10, height: 10)
                Text(category.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.leading, 4)

            // Subcategories grid
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(subcategories, id: \.persistentModelID) { subcategory in
                    SubcategoryGridItem(
                        subcategory: subcategory,
                        categoryColor: category.colorHex,
                        isSelected: isSelected(subcategory),
                        action: { onSelect(subcategory) }
                    )
                }
            }
        }
    }

    private func isSelected(_ subcategory: Subcategory) -> Bool {
        guard let selected = selectedSubcategory else { return false }
        return selected.persistentModelID == subcategory.persistentModelID
    }
}

// MARK: - Subcategory Grid Item

struct SubcategoryGridItem: View {
    let subcategory: Subcategory
    let categoryColor: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(Color(hex: effectiveColor).opacity(isSelected ? 1 : 0.15))
                        .frame(width: 48, height: 48)

                    Image(systemName: subcategory.iconName ?? "tag.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(isSelected ? .white : Color(hex: effectiveColor))

                    if isSelected {
                        Circle()
                            .stroke(Color(hex: effectiveColor), lineWidth: 2)
                            .frame(width: 54, height: 54)
                    }
                }

                Text(subcategory.name)
                    .font(.caption2)
                    .foregroundStyle(isSelected ? Color(hex: effectiveColor) : .primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(height: 28)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private var effectiveColor: String {
        subcategory.colorHex ?? categoryColor
    }
}

#Preview {
    SubcategorySelectorSheet(
        selectedSubcategory: .constant(nil),
        transactionType: .expense
    )
}
