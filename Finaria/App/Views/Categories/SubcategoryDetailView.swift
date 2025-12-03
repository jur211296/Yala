//
//  SubcategoryDetailView.swift
//  Finaria
//
//  Created by Finaria Refactoring.
//

import SwiftData
import SwiftUI

/// Formulario de creación/edición de subcategoría
struct SubcategoryDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let parentCategory: Category
    let subcategoryToEdit: Subcategory?

    private var isEditing: Bool { subcategoryToEdit != nil }

    @State private var name: String
    @State private var selectedNature: SubcategoryNature
    @State private var isVisible: Bool
    @State private var selectedColorHex: String

    @State private var isPresentingNatureSelector: Bool = false

    @State private var showDiscardDialog: Bool = false

    private let initialName: String
    private let initialNature: SubcategoryNature
    private let initialIsVisible: Bool
    private let initialColorHex: String

    init(parentCategory: Category, subcategoryToEdit: Subcategory? = nil) {
        self.parentCategory = parentCategory
        self.subcategoryToEdit = subcategoryToEdit

        if let sub = subcategoryToEdit {
            self.initialName = sub.name
            self.initialNature = sub.nature
            self.initialIsVisible = sub.isVisible
            self.initialColorHex = sub.colorHex ?? parentCategory.colorHex
            _name = State(initialValue: sub.name)
            _selectedNature = State(initialValue: sub.nature)
            _isVisible = State(initialValue: sub.isVisible)
            _selectedColorHex = State(initialValue: sub.colorHex ?? parentCategory.colorHex)
        } else {
            self.initialName = ""
            self.initialNature = .unclassified
            self.initialIsVisible = true
            self.initialColorHex = parentCategory.colorHex
            _name = State(initialValue: "")
            _selectedNature = State(initialValue: .unclassified)
            _isVisible = State(initialValue: true)
            _selectedColorHex = State(initialValue: parentCategory.colorHex)
        }
    }

    private var hasUnsavedChanges: Bool {
        let trimmedCurrentName = trimmedName
        let trimmedInitialName = initialName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedCurrentName != trimmedInitialName || selectedNature != initialNature
            || isVisible != initialIsVisible || selectedColorHex != initialColorHex
    }

    private func handleBack() {
        if hasUnsavedChanges {
            showDiscardDialog = true
        } else {
            dismiss()
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedName.isEmpty
    }

    var body: some View {
        ZStack {
            PanelBackgroundView()

            ScrollView {
                VStack(spacing: 24) {
                    header
                    detailsSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 24)
            }
        }
        .navigationTitle(isEditing ? "Editar subcategoría" : "Nueva subcategoría")
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
                    saveSubcategory()
                }
                .disabled(!canSave)
            }
        }
        .sheet(isPresented: $isPresentingNatureSelector) {
            NavigationStack {
                SubcategoryNatureSelectorView(selectedNature: $selectedNature)
            }
        }
        .confirmationDialog(
            "Hay cambios sin guardar",
            isPresented: $showDiscardDialog,
            titleVisibility: .visible
        ) {
            Button("Salir sin guardar", role: .destructive) {
                dismiss()
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Si sales ahora, se perderán los cambios realizados en esta subcategoría.")
        }
    }

    // Encabezado con círculo de color e icono
    private var header: some View {
        VStack(spacing: 12) {
            Circle()
                .fill(colorForHex(selectedColorHex))
                .frame(width: 70, height: 70)
                .overlay(
                    Image(systemName: "tag")
                        .font(.title2)
                        .foregroundStyle(.white)
                )

            Text(parentCategory.name)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // Sección de nombre, naturaleza y visibilidad
    private var detailsSection: some View {
        SectionBox(title: "Detalles de la subcategoría") {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: "textformat")
                        .foregroundStyle(.secondary)
                    TextField("Nombre de la subcategoría", text: $name)
                        .textContentType(.name)
                }
                .padding()

                SubsectionDivider()

                Button {
                    isPresentingNatureSelector = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "circle.lefthalf.filled")
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Naturaleza")
                                .foregroundStyle(.primary)
                            Text(selectedNature.displayName)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                    }
                    .padding()
                }
                .buttonStyle(.plain)

                SubsectionDivider()

                Toggle(isOn: $isVisible) {
                    Text("Mostrar")
                }
                .padding()
            }
        }
    }

    private func saveSubcategory() {
        let finalName = trimmedName
        guard !finalName.isEmpty else { return }

        if let sub = subcategoryToEdit {
            // Edición
            sub.name = finalName
            sub.isVisible = isVisible
            sub.nature = selectedNature
            sub.colorHex = selectedColorHex
        } else {
            // Creación
            let sortOrder: Int
            do {
                let descriptor = FetchDescriptor<Subcategory>()
                let allSubcategories = try modelContext.fetch(descriptor)
                let existing = allSubcategories.filter { $0.category == parentCategory }
                let maxOrder = existing.map { $0.sortOrder }.max() ?? -1
                sortOrder = maxOrder + 1
            } catch {
                print("FIN-45: Error calculando sortOrder de subcategorías: \(error)")
                sortOrder = 0
            }

            let newSubcategory = Subcategory(
                name: finalName,
                colorHex: selectedColorHex,
                isDefaultSeed: false,
                isVisible: isVisible,
                sortOrder: sortOrder,
                natureRawValue: selectedNature.rawValue,
                category: parentCategory
            )

            modelContext.insert(newSubcategory)
        }

        do {
            try modelContext.save()
        } catch {
            print("FIN-45: Error al guardar subcategoría: \(error)")
        }

        dismiss()
    }
}
