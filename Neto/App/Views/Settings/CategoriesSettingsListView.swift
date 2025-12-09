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
            colorHex: "#1C3556",
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
                    if !activeCategories.isEmpty {
                        SectionBox(title: "Activas") {
                            VStack(spacing: 0) {
                                ForEach(Array(activeCategories.enumerated()), id: \.element.id) {
                                    index, category in
                                    NavigationLink {
                                        CategoryDetailView(category: category)
                                    } label: {
                                        categoryRow(category)
                                    }
                                    .buttonStyle(.plain)

                                    if index < activeCategories.count - 1 {
                                        SubsectionDivider()
                                    }
                                }
                            }
                        }
                    }

                    if !hiddenCategories.isEmpty {
                        SectionBox(title: "Ocultas") {
                            VStack(spacing: 0) {
                                ForEach(Array(hiddenCategories.enumerated()), id: \.element.id) {
                                    index, category in
                                    NavigationLink {
                                        CategoryDetailView(category: category)
                                    } label: {
                                        categoryRow(category)
                                    }
                                    .buttonStyle(.plain)

                                    if index < hiddenCategories.count - 1 {
                                        SubsectionDivider()
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 32)
            }
        }
        .navigationTitle("Categorías")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    createAndOpenNewCategory()
                } label: {
                    Image(systemName: "plus")
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

    @ViewBuilder
    private func categoryRow(_ category: Category) -> some View {
        HStack(spacing: 12) {
            // Círculo con color e icono estándar de etiqueta
            Circle()
                .fill(colorForHex(category.colorHex))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: "tag")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(category.name)
                    .font(.body)
                    .foregroundStyle(.primary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)  // un poco más alta la fila
    }
}
