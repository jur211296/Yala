//
//  CategoriesSettingsListView.swift
//  Neto
//
//  Created by Neto Refactoring.
//

import SwiftData
import SwiftUI

// MARK: - Categorías en Ajustes (FIN-45)

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
                VStack(spacing: 24) {
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
                .padding(.horizontal, 16)
                .padding(.vertical, 32)
            }
        }
        .navigationTitle("Categorías")
        .navigationBarTitleDisplayMode(.inline)
        .swipeBack()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                NetoToolbarButton(systemName: "chevron.left") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                NetoToolbarButton(systemName: "plus") {
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
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "tag")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            Text("No tienes categorías")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Crea categorías para clasificar tus ingresos y gastos.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.top, 64)
    }

    // MARK: - Active Categories Section

    private var activeCategoriesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Activas")
                .font(.headline)
                .foregroundStyle(Color.primary.opacity(0.6))
                .padding(.leading, 6)

            List {
                ForEach(Array(activeCategories.enumerated()), id: \.element.id) { index, category in
                    NavigationLink {
                        CategoryDetailView(category: category)
                    } label: {
                        categoryRow(category)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.netoCard)
                    .listRowSeparator(
                        index < activeCategories.count - 1 ? .visible : .hidden, edges: .bottom)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollDisabled(true)
            .frame(height: CGFloat(activeCategories.count) * 52)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.netoCard)
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.black.opacity(0.05), lineWidth: 0.8)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 6)
        }
    }

    // MARK: - Hidden Categories Section

    private var hiddenCategoriesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ocultas")
                .font(.headline)
                .foregroundStyle(Color.primary.opacity(0.6))
                .padding(.leading, 6)

            List {
                ForEach(Array(hiddenCategories.enumerated()), id: \.element.id) { index, category in
                    NavigationLink {
                        CategoryDetailView(category: category)
                    } label: {
                        categoryRow(category)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.netoCard)
                    .listRowSeparator(
                        index < hiddenCategories.count - 1 ? .visible : .hidden, edges: .bottom)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollDisabled(true)
            .frame(height: CGFloat(hiddenCategories.count) * 52)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.netoCard)
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.black.opacity(0.05), lineWidth: 0.8)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 6)
        }
    }

    // MARK: - Category Row

    @ViewBuilder
    private func categoryRow(_ category: Category) -> some View {
        HStack(spacing: 12) {
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
