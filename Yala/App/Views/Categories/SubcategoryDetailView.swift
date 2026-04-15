//
//  SubcategoryDetailView.swift
//  Yala
//
//  Created by Yala Refactoring.
//

import SwiftData
import SwiftUI

/// Formulario de creación/edición de subcategoría
struct SubcategoryDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(EntityDeletionService.self) private var deletionService

    let parentCategory: Category
    let subcategoryToEdit: Subcategory?

    private var isEditing: Bool { subcategoryToEdit != nil }

    @State private var name: String
    @State private var selectedNeed: SubcategoryNeed
    @State private var isVisible: Bool
    @State private var selectedColorHex: String
    @State private var selectedIconName: String

    @State private var isPresentingNeedSelector: Bool = false
    @State private var showDiscardDialog: Bool = false
    @State private var showIconColorPicker: Bool = false
    @State private var showDeleteConfirmation: Bool = false
    @State private var showTransferSheet: Bool = false
    @State private var transactionCount: Int = 0

    // Focus state
    @FocusState private var isNameFieldFocused: Bool

    private let initialName: String
    private let initialNeed: SubcategoryNeed
    private let initialIsVisible: Bool
    private let initialColorHex: String
    private let initialIconName: String

    init(parentCategory: Category, subcategoryToEdit: Subcategory? = nil) {
        self.parentCategory = parentCategory
        self.subcategoryToEdit = subcategoryToEdit

        if let sub = subcategoryToEdit {
            self.initialName = sub.name
            self.initialNeed = sub.need
            self.initialIsVisible = sub.isVisible
            self.initialColorHex = sub.colorHex ?? parentCategory.colorHex
            self.initialIconName = sub.iconName ?? parentCategory.iconName ?? "tag"
            _name = State(initialValue: sub.name)
            _selectedNeed = State(initialValue: sub.need)
            _isVisible = State(initialValue: sub.isVisible)
            _selectedColorHex = State(initialValue: sub.colorHex ?? parentCategory.colorHex)
            _selectedIconName = State(
                initialValue: sub.iconName ?? parentCategory.iconName ?? "tag")
        } else {
            self.initialName = ""
            self.initialNeed = .unclassified
            self.initialIsVisible = true
            self.initialColorHex = parentCategory.colorHex
            self.initialIconName = parentCategory.iconName ?? "tag"
            _name = State(initialValue: "")
            _selectedNeed = State(initialValue: .unclassified)
            _isVisible = State(initialValue: true)
            _selectedColorHex = State(initialValue: parentCategory.colorHex)
            _selectedIconName = State(initialValue: parentCategory.iconName ?? "tag")
        }
    }

    private var hasUnsavedChanges: Bool {
        let trimmedCurrentName = trimmedName
        let trimmedInitialName = initialName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedCurrentName != trimmedInitialName
            || selectedNeed != initialNeed
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
                VStack(spacing: DS.Spacing.xxl) {
                    header
                    detailsSection
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.xxl)
                .dismissKeyboardOnTap()
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle(isEditing ? L10n.Subcategory.editTitle : L10n.Subcategory.newTitle)
        .swipeBack()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                YalaToolbarButton(systemName: "chevron.left", label: L10n.Action.back) {
                    handleBack()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                YalaSaveButton(
                    action: { saveSubcategory() },
                    isDisabled: !canSave
                )
            }
        }
        .sheet(isPresented: $isPresentingNeedSelector) {
            NavigationStack {
                SubcategoryNeedSelectorView(selectedNeed: $selectedNeed)
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
            Button(L10n.Action.cancel, role: .cancel) {}
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
        .onChange(of: isPresentingNeedSelector) { _, isPresenting in
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
                Task {
                    try? await Task.sleep(for: .milliseconds(500))
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
                                .font(DS.Typography.title)
                                .foregroundStyle(.white)
                        )
                        .shadow(
                            color: Color(hex: selectedColorHex).opacity(0.3), radius: 6, x: 0, y: 3)

                    // Pencil edit indicator
                    Circle()
                        .fill(.thCard)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Image(systemName: "pencil")
                                .font(DS.Typography.labelSmall)
                                .foregroundStyle(Color(hex: selectedColorHex))
                        )
                        .overlay(
                            Circle()
                                .stroke(.thBackground, lineWidth: 2)
                        )
                        .offset(x: 4, y: 4)
                }
            }
            .buttonStyle(.plain)

            Text(parentCategory.name)
                .font(DS.Typography.subheadline)
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
                VStack(spacing: DS.Spacing.none) {
                    HStack(spacing: DS.Spacing.md) {
                        Image(systemName: "textformat")
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                        TextField(L10n.Subcategory.namePlaceholder, text: $name)
                            .textContentType(.name)
                            .focused($isNameFieldFocused)
                    }
                    .padding()

                    // Nature selector only for expense categories (not income)
                    if !parentCategory.isIncome {
                        SubsectionDivider()

                        Button {
                            isPresentingNeedSelector = true
                        } label: {
                            HStack(spacing: DS.Spacing.md) {
                                Image(systemName: "circle.lefthalf.filled")
                                    .foregroundStyle(.secondary)
                                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                                    Text(L10n.Category.need)
                                        .foregroundStyle(.primary)
                                    Text(selectedNeed.displayName)
                                        .font(DS.Typography.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(DS.Typography.caption)
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
                                .foregroundStyle(DS.Semantic.errorForeground)
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
        deletionService.setContext(modelContext)
        return deletionService.transactionCount(forSubcategory: subcategory)
    }

    private func deleteSubcategory() {
        guard let subcategory = subcategoryToEdit else { return }
        deletionService.setContext(modelContext)
        do {
            try deletionService.deleteSubcategory(subcategory)
            dismiss()
        } catch {
            #if DEBUG
            print("SubcategoryDetailView: Error deleting subcategory: \(error)")
            #endif
        }
    }

    private func saveSubcategory() {
        let finalName = trimmedName
        guard !finalName.isEmpty else { return }

        // Income subcategories always use unclassified nature
        let finalNeed: SubcategoryNeed = parentCategory.isIncome ? .unclassified : selectedNeed

        if let sub = subcategoryToEdit {
            // Edición
            sub.name = finalName
            sub.isVisible = isVisible
            sub.need = finalNeed
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
                natureRawValue: finalNeed.rawValue,
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
            #if DEBUG
            print("Subcategory: Error al guardar subcategoría: \(error)")
            #endif
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
            #if DEBUG
            print("Subcategory: Error reordering subcategories: \(error)")
            #endif
        }
    }
}
