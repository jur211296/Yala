//
//  CategoryDetailView.swift
//  Neto
//
//  Created by Neto Refactoring.
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
    @State private var iconName: String
    @State private var colorHex: String
    @State private var showVisibilityInfo: Bool = false
    @State private var showDiscardDialog: Bool = false
    @State private var showMissingSubcategoriesAlert: Bool = false
    @State private var showIconColorPicker: Bool = false

    private let initialName: String
    private let initialIsVisible: Bool
    private let initialIconName: String
    private let initialColorHex: String

    @Query(sort: \Subcategory.sortOrder, order: .forward) private var allSubcategories:
        [Subcategory]

    init(category: Category, isNewCategory: Bool = false) {
        self.category = category
        self.isNewCategory = isNewCategory
        self.initialName = category.name
        self.initialIsVisible = category.isVisible
        self.initialIconName = category.iconName ?? "tag"
        self.initialColorHex = category.colorHex
        _name = State(initialValue: category.name)
        _isVisible = State(initialValue: category.isVisible)
        _iconName = State(initialValue: category.iconName ?? "tag")
        _colorHex = State(initialValue: category.colorHex)
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
        return trimmedCurrentName != trimmedInitialName
            || isVisible != initialIsVisible
            || iconName != initialIconName
            || colorHex != initialColorHex
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
        .navigationTitle(L10n.Category.editTitle)
        .swipeBack()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                NetoToolbarButton(systemName: "chevron.left") {
                    handleBack()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                NetoSaveButton(
                    action: { saveCategory() },
                    isDisabled: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || !hasUnsavedChanges
                )
            }
        }
        .alert(L10n.Category.hiddenTitle, isPresented: $showVisibilityInfo) {
            Button(L10n.Common.understood, role: .cancel) {}
        } message: {
            Text(
                L10n.Category.hiddenDescription
            )
        }
        .alert(L10n.Category.addOneSubcategory, isPresented: $showMissingSubcategoriesAlert) {
            Button(L10n.Common.understood, role: .cancel) {}
        } message: {
            Text(L10n.Category.requiresSubcategory)
        }
        .confirmationDialog(
            L10n.Alert.discardChanges,
            isPresented: $showDiscardDialog,
            titleVisibility: .visible
        ) {
            Button(L10n.Alert.discardChanges, role: .destructive) {
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
            Button("Seguir editando", role: .cancel) {
                // El usuario decide seguir editando; no hacemos nada.
            }
        } message: {
            Text(L10n.Alert.discardChanges)
        }
    }

    // Encabezado con círculo de color e icono (tappable para editar)
    private var header: some View {
        VStack(spacing: 12) {
            Button {
                showIconColorPicker = true
            } label: {
                ZStack(alignment: .bottomTrailing) {
                    Circle()
                        .fill(Color(hex: colorHex))
                        .frame(width: 70, height: 70)
                        .overlay(
                            Image(systemName: iconName)
                                .font(.title2)
                                .foregroundStyle(.white)
                        )
                        .shadow(color: Color(hex: colorHex).opacity(0.3), radius: 6, x: 0, y: 3)

                    // Pencil edit indicator
                    Circle()
                        .fill(Color.netoCard)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Image(systemName: "pencil")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.electricIndigo)
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.netoBackground, lineWidth: 2)
                        )
                        .offset(x: 4, y: 4)
                }
            }
            .buttonStyle(.plain)

            Text(name.isEmpty ? "Nueva categoría" : name)
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .sheet(isPresented: $showIconColorPicker) {
            IconColorPickerSheet(
                selectedIconName: $iconName,
                selectedColorHex: $colorHex
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
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
                    Text(L10n.Category.show)
                }
                .tint(Color.electricIndigo)
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
                        Text(L10n.Category.noSubcategoriesYet)
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
                                .foregroundStyle(Color.brandPrimary)
                            Text(L10n.Category.addSubcategory)
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
        let backgroundColor = Color(hex: colorHex)

        HStack(spacing: 12) {
            Circle()
                .fill(backgroundColor)
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: subcategory.iconName ?? category.iconName ?? "tag")
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
        .contentShape(Rectangle())
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
        category.iconName = iconName
        category.colorHex = colorHex

        // Enforce color inheritance for all subcategories
        for subcategory in category.subcategories {
            subcategory.colorHex = colorHex
        }

        do {
            try modelContext.save()
        } catch {
            print("FIN-45: Error al guardar categoría: \(error)")
        }

        dismiss()
    }
}
