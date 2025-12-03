//
//  CategoryDetailView.swift
//  Finaria
//
//  Created by Finaria Refactoring.
//

import SwiftData
import SwiftUI

/// Detalle de categoría: permite editar nombre, visibilidad y gestionar subcategorías
struct CategoryDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let category: Category
    let isNewCategory: Bool

    @State private var name: String
    @State private var isVisible: Bool
    @State private var showVisibilityInfo: Bool = false
    @State private var showDiscardDialog: Bool = false
    @State private var showMissingSubcategoriesAlert: Bool = false

    private let initialName: String
    private let initialIsVisible: Bool

    @Query(sort: \Subcategory.sortOrder, order: .forward) private var allSubcategories:
        [Subcategory]

    init(category: Category, isNewCategory: Bool = false) {
        self.category = category
        self.isNewCategory = isNewCategory
        self.initialName = category.name
        self.initialIsVisible = category.isVisible
        _name = State(initialValue: category.name)
        _isVisible = State(initialValue: category.isVisible)
    }

    /// Subcategorías filtradas solo para esta categoría, ordenadas por sortOrder y nombre.
    private var subcategories: [Subcategory] {
        allSubcategories
            .filter { $0.category == category }
            .sorted { lhs, rhs in
                if lhs.sortOrder != rhs.sortOrder {
                    return lhs.sortOrder < rhs.sortOrder
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    private var hasUnsavedChanges: Bool {
        let trimmedCurrentName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedInitialName = initialName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedCurrentName != trimmedInitialName || isVisible != initialIsVisible
    }

    private func handleBack() {
        if isNewCategory {
            if hasUnsavedChanges {
                showDiscardDialog = true
            } else {
                // Categoría nueva sin cambios: descartamos directamente
                modelContext.delete(category)
                do {
                    try modelContext.save()
                } catch {
                    print("FIN-45: Error al descartar categoría nueva sin cambios: \(error)")
                }
                dismiss()
            }
        } else {
            if hasUnsavedChanges {
                showDiscardDialog = true
            } else {
                dismiss()
            }
        }
    }

    var body: some View {
        ZStack {
            PanelBackgroundView()

            ScrollView {
                VStack(spacing: 24) {
                    header
                    detailsSection
                    subcategoriesSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 24)
            }
        }
        .navigationTitle("Editar categoría")
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    handleBack()
                } label: {
                    Image(systemName: "chevron.left")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Guardar") {
                    saveCategory()
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .alert("Categoría oculta", isPresented: $showVisibilityInfo) {
            Button("Entendido", role: .cancel) {}
        } message: {
            Text(
                "La categoría y sus subcategorías dejarán de aparecer en los selectores, pero no se perderán datos históricos."
            )
        }
        .alert("Añade al menos una subcategoría", isPresented: $showMissingSubcategoriesAlert) {
            Button("Entendido", role: .cancel) {}
        } message: {
            Text("Para crear una nueva categoría, debes añadir al menos una subcategoría.")
        }
        .alert("Hay cambios sin guardar", isPresented: $showDiscardDialog) {
            Button("Salir sin guardar", role: .destructive) {
                if isNewCategory {
                    modelContext.delete(category)
                    do {
                        try modelContext.save()
                    } catch {
                        print("FIN-45: Error al descartar categoría nueva: \(error)")
                    }
                }
                dismiss()
            }
            Button("Cancelar", role: .cancel) {
                // El usuario decide seguir editando; no hacemos nada.
            }
        } message: {
            Text("Si sales ahora, se perderán los cambios realizados en esta categoría.")
        }
    }

    // Encabezado con círculo de color e icono
    private var header: some View {
        VStack(spacing: 12) {
            Circle()
                .fill(colorForHex(category.colorHex))
                .frame(width: 70, height: 70)
                .overlay(
                    Image(systemName: "tag")
                        .font(.title2)
                        .foregroundStyle(.white)
                )

            Text(category.name)
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // Sección de nombre y visibilidad
    private var detailsSection: some View {
        SectionBox(title: "Detalles") {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: "textformat")
                        .foregroundStyle(.secondary)
                    TextField("Nombre de la categoría", text: $name)
                        .textContentType(.name)
                }
                .padding()

                SubsectionDivider()

                Toggle(isOn: $isVisible) {
                    Text("Mostrar")
                }
                .padding()
                .onChange(of: isVisible) { _, newValue in
                    if newValue == false {
                        showVisibilityInfo = true
                    }
                }
            }
        }
    }

    // Sección de subcategorías
    private var subcategoriesSection: some View {
        let visibles = subcategories.filter { $0.isVisible }
        let ocultas = subcategories.filter { !$0.isVisible }

        return VStack(spacing: 16) {
            SectionBox(title: "Subcategorías activas") {
                VStack(spacing: 0) {
                    if visibles.isEmpty && ocultas.isEmpty {
                        Text("Esta categoría aún no tiene subcategorías.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding()
                    } else {
                        ForEach(Array(visibles.enumerated()), id: \.element.id) {
                            index, subcategory in
                            NavigationLink {
                                SubcategoryDetailView(
                                    parentCategory: category, subcategoryToEdit: subcategory)
                            } label: {
                                subcategoryRow(subcategory)
                            }
                            .buttonStyle(.plain)

                            if index < visibles.count - 1 {
                                SubsectionDivider()
                            }
                        }
                    }

                    SubsectionDivider()

                    NavigationLink {
                        SubcategoryDetailView(parentCategory: category)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.tint)
                            Text("Añadir subcategoría")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.footnote)
                                .foregroundStyle(.tertiary)
                        }
                        .padding()
                    }
                }
            }

            if !ocultas.isEmpty {
                SectionBox(title: "Subcategorías ocultas") {
                    VStack(spacing: 0) {
                        ForEach(Array(ocultas.enumerated()), id: \.element.id) {
                            index, subcategory in
                            NavigationLink {
                                SubcategoryDetailView(
                                    parentCategory: category, subcategoryToEdit: subcategory)
                            } label: {
                                subcategoryRow(subcategory)
                            }
                            .buttonStyle(.plain)

                            if index < ocultas.count - 1 {
                                SubsectionDivider()
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func subcategoryRow(_ subcategory: Subcategory) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(colorForHex(subcategory.colorHex ?? category.colorHex))
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "tag")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(subcategory.name)
                    .font(.body)
                    .foregroundStyle(.primary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func saveCategory() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        if isNewCategory && subcategories.isEmpty {
            showMissingSubcategoriesAlert = true
            return
        }

        category.name = trimmedName
        category.isVisible = isVisible

        do {
            try modelContext.save()
        } catch {
            print("FIN-45: Error al guardar categoría: \(error)")
        }

        dismiss()
    }
}
