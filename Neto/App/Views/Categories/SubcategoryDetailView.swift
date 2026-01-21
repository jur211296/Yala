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
    @State private var showTransferSheet: Bool = false
    @State private var transactionCount: Int = 0

    // Focus state
    @FocusState private var isNameFieldFocused: Bool

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
                .dismissKeyboardOnTap()

            ScrollView {
                VStack(spacing: DS.Spacing.xxl) {
                    header
                    detailsSection
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.xxl)
            }
            .scrollDismissesKeyboard(.interactively)
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
        .sheet(isPresented: $showTransferSheet) {
            if let subcategory = subcategoryToEdit {
                SubcategoryTransferSheet(
                    subcategoryToDelete: subcategory,
                    onComplete: {
                        deleteSubcategory()
                    }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
        .onChange(of: isPresentingNatureSelector) { _, isPresenting in
            if isPresenting { dismissKeyboard() }
        }
        .onChange(of: showTransferSheet) { _, isPresenting in
            if isPresenting { dismissKeyboard() }
        }
        .onChange(of: showIconColorPicker) { _, isPresenting in
            if isPresenting { dismissKeyboard() }
        }
        .onAppear {
            // Auto-focus name field for new subcategories
            if !isEditing {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isNameFieldFocused = true
                }
            }
        }
    }

    // Encabezado con círculo de color e icono (tappable para editar)
    private var header: some View {
        VStack(spacing: DS.Spacing.md) {
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
        VStack(spacing: DS.Spacing.lg) {
            SectionBox(title: L10n.Subcategory.details) {
                VStack(spacing: 0) {
                    HStack(spacing: DS.Spacing.md) {
                        Image(systemName: "textformat")
                            .foregroundStyle(.secondary)
                        TextField(L10n.Subcategory.namePlaceholder, text: $name)
                            .textContentType(.name)
                            .focused($isNameFieldFocused)
                    }
                    .padding()

                    // Nature selector only for expense categories (not income)
                    if !parentCategory.isIncome {
                        SubsectionDivider()

                        Button {
                            isPresentingNatureSelector = true
                        } label: {
                            HStack(spacing: DS.Spacing.md) {
                                Image(systemName: "circle.lefthalf.filled")
                                    .foregroundStyle(.secondary)
                                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
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
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

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
                            showTransferSheet = true
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
        let subcategoryID = subcategory.persistentModelID
        do {
            let descriptor = FetchDescriptor<TransactionItem>()
            let allTransactions = try modelContext.fetch(descriptor)
            return allTransactions.filter { $0.subcategory?.persistentModelID == subcategoryID }.count
        } catch {
            print("Subcategory: Error counting transactions for subcategory: \(error)")
            return 0
        }
    }

    private func deleteSubcategory() {
        guard let subcategory = subcategoryToEdit else { return }
        modelContext.delete(subcategory)
        do {
            try modelContext.save()
            modelContext.processPendingChanges()
        } catch {
            print("Subcategory: Error deleting subcategory: \(error)")
        }
        dismiss()
    }

    private func saveSubcategory() {
        let finalName = trimmedName
        guard !finalName.isEmpty else { return }

        // Income subcategories always use unclassified nature
        let finalNature: SubcategoryNature = parentCategory.isIncome ? .unclassified : selectedNature

        if let sub = subcategoryToEdit {
            // Edición
            sub.name = finalName
            sub.isVisible = isVisible
            sub.nature = finalNature
            sub.colorHex = parentCategory.colorHex  // Enforce parent color
            sub.iconName = selectedIconName
        } else {
            // Creación - sortOrder will be recalculated after save
            let newSubcategory = Subcategory(
                name: finalName,
                colorHex: parentCategory.colorHex,  // Enforce parent color
                isDefaultSeed: false,
                isVisible: isVisible,
                sortOrder: 0,  // Temporary, will be recalculated
                natureRawValue: finalNature.rawValue,
                iconName: selectedIconName,
                category: parentCategory
            )

            modelContext.insert(newSubcategory)
        }

        // Reorder all subcategories in this category alphabetically
        reorderSubcategoriesAlphabetically()

        do {
            try modelContext.save()
        } catch {
            print("Subcategory: Error al guardar subcategoría: \(error)")
        }

        dismiss()
    }

    /// Reorders all subcategories in the parent category alphabetically by name
    private func reorderSubcategoriesAlphabetically() {
        do {
            let descriptor = FetchDescriptor<Subcategory>()
            let allSubcategories = try modelContext.fetch(descriptor)
            let categorySubcategories = allSubcategories
                .filter { $0.category == parentCategory }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

            for (index, subcategory) in categorySubcategories.enumerated() {
                subcategory.sortOrder = index
            }
        } catch {
            print("Subcategory: Error reordering subcategories: \(error)")
        }
    }
}
