//
//  SubcategorySelectorSheet.swift
//  Yala
//
//  Created by Yala - New Transaction Form.
//

import SwiftData
import SwiftUI

// MARK: - Subcategory Selector Sheet

/// Sheet para seleccionar una subcategoría agrupada por categoría
struct SubcategorySelectorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var viewModel = SubcategorySelectorViewModel()

    @Binding var selectedSubcategory: Subcategory?
    let transactionType: TransactionType

    private let columns = [
        GridItem(.flexible(), spacing: DS.Spacing.md),
        GridItem(.flexible(), spacing: DS.Spacing.md),
        GridItem(.flexible(), spacing: DS.Spacing.md),
        GridItem(.flexible(), spacing: DS.Spacing.md),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()

                ScrollView {
                    VStack(spacing: DS.Spacing.xl) {
                        if viewModel.isEmpty {
                            // Empty state
                            VStack(spacing: DS.Spacing.lg) {
                                Image(systemName: "tag.slash")
                                    .font(DS.Typography.amountLarge)
                                    .foregroundStyle(.secondary)
                                Text(L10n.Empty.noSubcategories)
                                    .font(DS.Typography.headline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                        } else {
                            // Recientes section (if any)
                            if !viewModel.recentSubcategories.isEmpty {
                                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                                    HStack(spacing: DS.Spacing.sm) {
                                        Image(systemName: "clock.arrow.circlepath")
                                            .font(DS.Typography.caption)
                                            .foregroundStyle(.secondary)
                                        Text(L10n.Common.recent)
                                            .font(DS.Typography.headline)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.leading, DS.Spacing.xs)

                                    LazyVGrid(columns: columns, spacing: DS.Spacing.md) {
                                        ForEach(viewModel.recentSubcategories, id: \.persistentModelID) {
                                            subcategory in
                                            SubcategoryGridItem(
                                                subcategory: subcategory,
                                                categoryColor: subcategory.safeCategory.colorHex,
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
                                    .padding(.vertical, DS.Spacing.xs)
                            }

                            // All categories
                            ForEach(viewModel.groupedSubcategories, id: \.category.persistentModelID) {
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
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.xl)
                }
            }
            .navigationTitle(L10n.Transaction.subcategory)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: "Cerrar") {
                        dismiss()
                    }
                }
            }
        }

        .onAppear {
            viewModel.setContext(modelContext, transactionType: transactionType)
        }
    }

    private func isSelected(_ subcategory: Subcategory) -> Bool {
        guard let selected = selectedSubcategory else { return false }
        return selected.persistentModelID == subcategory.persistentModelID
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
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            // Category header
            HStack(spacing: DS.Spacing.sm) {
                Circle()
                    .fill(Color(hex: category.colorHex))
                    .frame(width: 10, height: 10)
                Text(category.name)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.secondary)
            }
            .padding(.leading, DS.Spacing.xs)

            // Subcategories grid
            LazyVGrid(columns: columns, spacing: DS.Spacing.md) {
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
            VStack(spacing: DS.Spacing.xs) {
                ZStack {
                    Circle()
                        .fill(Color(hex: effectiveColor).opacity(isSelected ? 1 : 0.15))
                        .frame(width: 48, height: 48)

                    Image(systemName: subcategory.iconName ?? "tag.fill")
                        .font(DS.Typography.bodyBold)
                        .foregroundStyle(isSelected ? .white : Color(hex: effectiveColor))

                    if isSelected {
                        Circle()
                            .stroke(Color(hex: effectiveColor), lineWidth: 2)
                            .frame(width: 54, height: 54)
                    }
                }

                Text(subcategory.name)
                    .font(DS.Typography.captionSmall)
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
