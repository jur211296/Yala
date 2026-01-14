//
//  SubcategoryDetailView.swift
//  Neto
//
//  Created by Neto Refactoring.
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
    @State private var selectedIconName: String

    @State private var isPresentingNatureSelector: Bool = false
    @State private var showDiscardDialog: Bool = false
    @State private var showIconColorPicker: Bool = false
    @State private var showDeleteConfirmation: Bool = false
    @State private var showCannotDeleteAlert: Bool = false
    @State private var transactionCount: Int = 0

    private let initialName: String
    private let initialNature: SubcategoryNature
    private let initialIsVisible: Bool
    private let initialColorHex: String
    private let initialIconName: String

    init(parentCategory: Category, subcategoryToEdit: Subcategory? = nil) {
        self.parentCategory = parentCategory
        self.subcategoryToEdit = subcategoryToEdit

        if let sub = subcategoryToEdit {
            self.initialName = sub.name
            self.initialNature = sub.nature
            self.initialIsVisible = sub.isVisible
            self.initialColorHex = sub.colorHex ?? parentCategory.colorHex
            self.initialIconName = sub.iconName ?? parentCategory.iconName ?? "tag"
            _name = State(initialValue: sub.name)
            _selectedNature = State(initialValue: sub.nature)
            _isVisible = State(initialValue: sub.isVisible)
            _selectedColorHex = State(initialValue: sub.colorHex ?? parentCategory.colorHex)
            _selectedIconName = State(
                initialValue: sub.iconName ?? parentCategory.iconName ?? "tag")
        } else {
            self.initialName = ""
            self.initialNature = .unclassified
            self.initialIsVisible = true
            self.initialColorHex = parentCategory.colorHex
            self.initialIconName = parentCategory.iconName ?? "tag"
            _name = State(initialValue: "")
            _selectedNature = State(initialValue: .unclassified)
            _isVisible = State(initialValue: true)
            _selectedColorHex = State(initialValue: parentCategory.colorHex)
            _selectedIconName = State(initialValue: parentCategory.iconName ?? "tag")
        }
    }

    private var hasUnsavedChanges: Bool {
        let trimmedCurrentName = trimmedName
        let trimmedInitialName = initialName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedCurrentName != trimmedInitialName
            || selectedNature != initialNature
            || isVisible != initialIsVisible
            || selectedColorHex != initialColorHex
            || selectedIconName != initialIconName
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
        .navigationTitle(isEditing ? L10n.Subcategory.editTitle : L10n.Subcategory.newTitle)
        .swipeBack()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                NetoToolbarButton(systemName: "chevron.left") {
                    handleBack()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                NetoSaveButton(
                    action: { saveSubcategory() },
                    isDisabled: !canSave
                )
            }
        }
        .sheet(isPresented: $isPresentingNatureSelector) {
            NavigationStack {
                SubcategoryNatureSelectorView(selectedNature: $selectedNature)
            }
        }
        .confirmationDialog(
            L10n.Alert.unsavedChanges,
            isPresented: $showDiscardDialog,
            titleVisibility: .visible
        ) {
            Button(L10n.Alert.discardChanges, role: .destructive) {
                dismiss()
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text(L10n.Alert.discardChanges)
        }
        .confirmationDialog(
            L10n.Subcategory.deleteConfirmTitle,
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(L10n.Subcategory.delete, role: .destructive) {
                deleteSubcategory()
            }
            Button(L10n.Action.cancel, role: .cancel) {}
        } message: {
            Text(L10n.Subcategory.deleteConfirmMessage)
        }
        .alert(
            L10n.Subcategory.cannotDeleteTitle,
            isPresented: $showCannotDeleteAlert
        ) {
            Button(L10n.Common.understood, role: .cancel) {}
        } message: {
            Text(L10n.Subcategory.cannotDeleteMessage(transactionCount))
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
                        .fill(Color(hex: selectedColorHex))
                        .frame(width: 70, height: 70)
                        .overlay(
                            Image(systemName: selectedIconName)
                                .font(.title2)
                                .foregroundStyle(.white)
                        )
                        .shadow(
                            color: Color(hex: selectedColorHex).opacity(0.3), radius: 6, x: 0, y: 3)

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

            Text(parentCategory.name)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .sheet(isPresented: $showIconColorPicker) {
            IconColorPickerSheet(
                selectedIconName: $selectedIconName,
                selectedColorHex: $selectedColorHex,
                supportsColorPicking: false
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    // Sección de nombre, naturaleza y visibilidad
    private var detailsSection: some View {
        VStack(spacing: 16) {
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
                                Text(L10n.Category.nature)
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
                        Text(L10n.Category.show)
                    }
                    .tint(Color.electricIndigo)
                    .padding()
                }
            }

            // Delete button (only when editing an existing subcategory)
            if isEditing {
                SectionBox(title: "") {
                    Button {
                        transactionCount = countTransactions()
                        if transactionCount > 0 {
                            showCannotDeleteAlert = true
                        } else {
                            showDeleteConfirmation = true
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Text(L10n.Subcategory.delete)
                                .foregroundStyle(.red)
                            Spacer()
                        }
                        .padding()
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    /// Counts transactions linked to this subcategory
    private func countTransactions() -> Int {
        guard let subcategory = subcategoryToEdit else { return 0 }
        do {
            let descriptor = FetchDescriptor<TransactionItem>()
            let allTransactions = try modelContext.fetch(descriptor)
            return allTransactions.filter { $0.subcategory == subcategory }.count
        } catch {
            print("FIN-45: Error counting transactions for subcategory: \(error)")
            return 0
        }
    }

    private func deleteSubcategory() {
        guard let subcategory = subcategoryToEdit else { return }
        modelContext.delete(subcategory)
        do {
            try modelContext.save()
        } catch {
            print("FIN-45: Error deleting subcategory: \(error)")
        }
        dismiss()
    }

    private func saveSubcategory() {
        let finalName = trimmedName
        guard !finalName.isEmpty else { return }

        if let sub = subcategoryToEdit {
            // Edición
            sub.name = finalName
            sub.isVisible = isVisible
            sub.nature = selectedNature
            sub.colorHex = parentCategory.colorHex  // Enforce parent color
            sub.iconName = selectedIconName
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
                colorHex: parentCategory.colorHex,  // Enforce parent color
                isDefaultSeed: false,
                isVisible: isVisible,
                sortOrder: sortOrder,
                natureRawValue: selectedNature.rawValue,
                iconName: selectedIconName,
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
