//
//  CategoriesSettingsListView.swift
//  Yala
//
//  Created by Yala Refactoring.
//

import SwiftData
import SwiftUI

// MARK: - Categorías en Ajustes

/// Lista principal de categorías dentro de Ajustes → Registros
struct CategoriesSettingsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Category.name, order: .forward) private var categories: [Category]

    // Solo categorías padre (en Neto v1 todas las Category son padre)
    private var orderedCategories: [Category] {
        categories.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var activeCategories: [Category] {
        orderedCategories.filter { $0.isVisible }
    }

    private var hiddenCategories: [Category] {
        orderedCategories.filter { !$0.isVisible }
    }

    @State private var isNavigatingToNewCategory: Bool = false
    @State private var newCategory: Category?
    @State private var isEditing: Bool = false
    @State private var showCannotDeleteAlert: Bool = false
    @State private var categoryToDeleteName: String = ""
    @State private var transactionCountForAlert: Int = 0

    private func createAndOpenNewCategory() {
        let nextSortOrder = (categories.map { $0.sortOrder }.max() ?? 0) + 1

        let category = Category(
            name: "",
            colorHex: "#6366F1",
            isIncome: false,
            isDefaultSeed: false,
            isVisible: true,
            sortOrder: nextSortOrder,
            subcategories: []
        )
        modelContext.insert(category)

        newCategory = category
        isNavigatingToNewCategory = true
    }

    var body: some View {
        ZStack {
            PanelBackgroundView()

            ScrollView {
                VStack(spacing: DS.Spacing.xxl) {
                    if categories.isEmpty {
                        emptyState
                    } else {
                        if !activeCategories.isEmpty {
                            activeCategoriesSection
                        }

                        if !hiddenCategories.isEmpty {
                            hiddenCategoriesSection
                        }
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.xxxl)
            }
        }
        .navigationTitle(L10n.Settings.categories)
        .navigationBarTitleDisplayMode(.inline)
        .swipeBack()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                YalaToolbarButton(systemName: "chevron.left") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                YalaToolbarButton(systemName: "plus") {
                    createAndOpenNewCategory()
                }
            }
        }
        .navigationDestination(isPresented: $isNavigatingToNewCategory) {
            if let newCategory {
                CategoryDetailView(category: newCategory, isNewCategory: true)
            } else {
                EmptyView()
            }
        }
        .alert(
            L10n.Category.cannotDeleteTitle,
            isPresented: $showCannotDeleteAlert
        ) {
            Button(L10n.Common.understood, role: .cancel) {}
        } message: {
            Text(L10n.Category.cannotDeleteMessage(transactionCountForAlert))
        }
    }

    // MARK: - Edit Mode Functions

    private func handleCategoryDelete(_ category: Category) {
        let count = countTransactionsInCategory(category)
        if count > 0 {
            categoryToDeleteName = category.name
            transactionCountForAlert = count
            showCannotDeleteAlert = true
            return
        }
        // Delete subcategories first to avoid SwiftUI @Query conflicts
        for subcategory in category.subcategories {
            modelContext.delete(subcategory)
        }
        modelContext.delete(category)
        do {
            try modelContext.save()
            modelContext.processPendingChanges()
        } catch {
            print("Categories: Error deleting category: \(error)")
        }
    }

    private func countTransactionsInCategory(_ category: Category) -> Int {
        do {
            let descriptor = FetchDescriptor<TransactionItem>()
            let allTransactions = try modelContext.fetch(descriptor)
            return allTransactions.filter { transaction in
                guard let subcategory = transaction.subcategory else { return false }
                return subcategory.category.persistentModelID == category.persistentModelID
            }.count
        } catch {
            print("Categories: Error counting transactions: \(error)")
            return 0
        }
    }

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.lg) {
            Image(systemName: "folder.fill")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            Text(L10n.Empty.noCategories)
                .font(.headline)
                .foregroundStyle(.secondary)

            Text(L10n.Empty.categoriesDescription)
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.top, 64)
    }

    // MARK: - Active Categories Section

    private var activeCategoriesSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                Text(L10n.Common.active)
                    .font(.headline)
                    .foregroundStyle(Color.primary.opacity(0.6))
                Spacer()
                Button {
                    isEditing.toggle()
                } label: {
                    Text(isEditing ? L10n.Action.done : L10n.Action.edit)
                        .font(.subheadline)
                        .foregroundStyle(Color.electricIndigo)
                }
            }
            .padding(.horizontal, 6)

            VStack(spacing: 0) {
                ForEach(Array(activeCategories.enumerated()), id: \.element.id) { index, category in
                    HStack(spacing: 0) {
                        if isEditing {
                            Button {
                                handleCategoryDelete(category)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.red)
                            }
                            .padding(.leading, 16)
                            .padding(.trailing, 8)
                        }

                        NavigationLink {
                            CategoryDetailView(category: category)
                        } label: {
                            HStack {
                                categoryRow(category)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, isEditing ? 8 : 16)
                        .padding(.vertical, 8)
                    }

                    if index < activeCategories.count - 1 {
                        Divider()
                            .padding(.leading, isEditing ? 56 : 16)
                    }
                }
            }
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .fill(Color.yalaCard)
            )
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .stroke(Color.black.opacity(0.05), lineWidth: 0.8)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 6)
        }
    }

    // MARK: - Hidden Categories Section

    private var hiddenCategoriesSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(L10n.Common.hidden)
                .font(.headline)
                .foregroundStyle(Color.primary.opacity(0.6))
                .padding(.leading, 6)

            VStack(spacing: 0) {
                ForEach(Array(hiddenCategories.enumerated()), id: \.element.id) { index, category in
                    HStack(spacing: 0) {
                        if isEditing {
                            Button {
                                handleCategoryDelete(category)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.red)
                            }
                            .padding(.leading, 16)
                            .padding(.trailing, 8)
                        }

                        NavigationLink {
                            CategoryDetailView(category: category)
                        } label: {
                            HStack {
                                categoryRow(category)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, isEditing ? 8 : 16)
                        .padding(.vertical, 8)
                    }

                    if index < hiddenCategories.count - 1 {
                        Divider()
                            .padding(.leading, isEditing ? 56 : 16)
                    }
                }
            }
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .fill(Color.yalaCard)
            )
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .stroke(Color.black.opacity(0.05), lineWidth: 0.8)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 6)
        }
    }

    // MARK: - Category Row

    @ViewBuilder
    private func categoryRow(_ category: Category) -> some View {
        HStack(spacing: DS.Spacing.md) {
            // Círculo con color e icono estándar de etiqueta
            Circle()
                .fill(colorForHex(category.colorHex))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: category.iconName ?? "tag")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                )

            Text(category.name)
                .font(.body)
                .foregroundStyle(.primary)

            Spacer()
        }
        .contentShape(Rectangle())
    }
}
