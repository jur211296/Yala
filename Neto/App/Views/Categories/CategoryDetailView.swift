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
    @State private var showDeleteConfirmation: Bool = false
    @State private var showCannotDeleteAlert: Bool = false
    @State private var transactionCount: Int = 0

    // Subcategory editing/deletion states
    @State private var isEditingSubcategories: Bool = false
    @State private var subcategoryToDelete: Subcategory?
    @State private var showSubcategoryDeleteConfirmation: Bool = false
    @State private var subcategoryForTransfer: Subcategory?

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
                .dismissKeyboardOnTap()

            ScrollView {
                VStack(spacing: DS.Spacing.xxl) {
                    header
                    detailsSection
                    subcategoriesSection
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.xxl)
            }
            .scrollDismissesKeyboard(.interactively)
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
            Button(L10n.Alert.keepEditing, role: .cancel) {
                // El usuario decide seguir editando; no hacemos nada.
            }
        } message: {
            Text(L10n.Alert.discardChanges)
        }
        .confirmationDialog(
            L10n.Category.deleteConfirmTitle,
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(L10n.Category.delete, role: .destructive) {
                deleteCategory()
            }
            Button(L10n.Action.cancel, role: .cancel) {}
        } message: {
            Text(L10n.Category.deleteConfirmMessage)
        }
        .alert(
            L10n.Category.cannotDeleteTitle,
            isPresented: $showCannotDeleteAlert
        ) {
            Button(L10n.Common.understood, role: .cancel) {}
        } message: {
            Text(L10n.Category.cannotDeleteMessage(transactionCount))
        }
        .confirmationDialog(
            L10n.Subcategory.deleteConfirmTitle,
            isPresented: $showSubcategoryDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(L10n.Subcategory.delete, role: .destructive) {
                if let subcategory = subcategoryToDelete {
                    deleteSubcategory(subcategory)
                }
            }
            Button(L10n.Action.cancel, role: .cancel) {
                subcategoryToDelete = nil
            }
        } message: {
            Text(L10n.Subcategory.deleteConfirmMessage)
        }
        .sheet(item: $subcategoryForTransfer) { subcategory in
            SubcategoryTransferSheet(
                subcategoryToDelete: subcategory,
                onComplete: {
                    deleteSubcategory(subcategory)
                    subcategoryForTransfer = nil
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .onChange(of: showIconColorPicker) { _, isPresenting in
            if isPresenting { dismissKeyboard() }
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

            Text(name.isEmpty ? L10n.Category.newCategory : name)
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
        VStack(spacing: DS.Spacing.lg) {
            SectionBox(title: L10n.Category.details) {
                VStack(spacing: 0) {
                    HStack(spacing: DS.Spacing.md) {
                        Image(systemName: "textformat")
                            .foregroundStyle(.secondary)
                        TextField(L10n.Category.namePlaceholder, text: $name)
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

            // Delete button (only for existing categories, not new ones)
            if !isNewCategory {
                SectionBox(title: "") {
                    Button {
                        transactionCount = countTransactionsInCategory()
                        if transactionCount > 0 {
                            showCannotDeleteAlert = true
                        } else {
                            showDeleteConfirmation = true
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Text(L10n.Category.delete)
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

    // Sección de subcategorías
    private var subcategoriesSection: some View {
        let visibles = subcategories.filter { $0.isVisible }
        let ocultas = subcategories.filter { !$0.isVisible }

        return VStack(spacing: DS.Spacing.lg) {
            // Active subcategories section
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                // Header with Edit/Done button
                HStack {
                    Text(L10n.Category.activeSubcategories)
                        .font(.headline)
                        .foregroundStyle(Color.primary.opacity(0.6))
                    Spacer()
                    if !visibles.isEmpty || !ocultas.isEmpty {
                        Button {
                            isEditingSubcategories.toggle()
                        } label: {
                            Text(isEditingSubcategories ? L10n.Action.done : L10n.Action.edit)
                                .font(.subheadline)
                                .foregroundStyle(Color.electricIndigo)
                        }
                    }
                }
                .padding(.horizontal, DS.Spacing.xs)

                VStack(spacing: 0) {
                    if visibles.isEmpty && ocultas.isEmpty {
                        Text(L10n.Category.noSubcategoriesYet)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else if !visibles.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(Array(visibles.enumerated()), id: \.element.id) {
                                index, subcategory in
                                HStack(spacing: 0) {
                                    if isEditingSubcategories {
                                        Button {
                                            handleSubcategoryDelete(subcategory)
                                        } label: {
                                            Image(systemName: "minus.circle.fill")
                                                .font(.title2)
                                                .foregroundStyle(.red)
                                        }
                                        .padding(.leading, DS.Spacing.lg)
                                        .padding(.trailing, DS.Spacing.sm)
                                    }

                                    NavigationLink {
                                        SubcategoryDetailView(
                                            parentCategory: category, subcategoryToEdit: subcategory)
                                    } label: {
                                        HStack {
                                            subcategoryRow(subcategory)
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundStyle(.tertiary)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.horizontal, isEditingSubcategories ? 8 : 16)
                                    .padding(.vertical, DS.Spacing.sm)
                                }

                                if index < visibles.count - 1 {
                                    Divider()
                                        .padding(.leading, isEditingSubcategories ? 56 : 16)
                                }
                            }
                        }
                        .padding(.vertical, DS.Spacing.xs)
                    }

                    Divider()
                        .padding(.horizontal, DS.Spacing.lg)

                    NavigationLink {
                        SubcategoryDetailView(parentCategory: category)
                    } label: {
                        HStack(spacing: DS.Spacing.md) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(Color.brandPrimary)
                            Text(L10n.Category.addSubcategory)
                                .foregroundStyle(.primary)
                            Spacer()
                        }
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.vertical, DS.FormRow.paddingV)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                        .fill(Color.netoCard)
                )
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                        .stroke(Color.black.opacity(0.05), lineWidth: 0.8)
                )
                .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 6)
            }

            // Hidden subcategories section
            if !ocultas.isEmpty {
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    Text(L10n.Category.hiddenSubcategories)
                        .font(.headline)
                        .foregroundStyle(Color.primary.opacity(0.6))
                        .padding(.leading, DS.Spacing.xs)

                    VStack(spacing: 0) {
                        ForEach(Array(ocultas.enumerated()), id: \.element.id) {
                            index, subcategory in
                            HStack(spacing: 0) {
                                if isEditingSubcategories {
                                    Button {
                                        handleSubcategoryDelete(subcategory)
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .font(.title2)
                                            .foregroundStyle(.red)
                                    }
                                    .padding(.leading, DS.Spacing.lg)
                                    .padding(.trailing, DS.Spacing.sm)
                                }

                                NavigationLink {
                                    SubcategoryDetailView(
                                        parentCategory: category, subcategoryToEdit: subcategory)
                                } label: {
                                    HStack {
                                        subcategoryRow(subcategory)
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal, isEditingSubcategories ? 8 : 16)
                                .padding(.vertical, DS.Spacing.sm)
                            }

                            if index < ocultas.count - 1 {
                                Divider()
                                    .padding(.leading, isEditingSubcategories ? 56 : 16)
                            }
                        }
                    }
                    .padding(.vertical, DS.Spacing.xs)
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                            .fill(Color.netoCard)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                            .stroke(Color.black.opacity(0.05), lineWidth: 0.8)
                    )
                    .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 6)
                }
            }
        }
    }

    @ViewBuilder
    private func subcategoryRow(_ subcategory: Subcategory) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Circle()
                .fill(Color(hex: colorHex))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: subcategory.iconName ?? category.iconName ?? "tag")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                )

            Text(subcategory.name)
                .font(.body)
                .foregroundStyle(.primary)

            Spacer()
        }
        .contentShape(Rectangle())
    }

    /// Counts transactions linked to any subcategory of this category
    private func countTransactionsInCategory() -> Int {
        do {
            let descriptor = FetchDescriptor<TransactionItem>()
            let allTransactions = try modelContext.fetch(descriptor)
            return allTransactions.filter { transaction in
                guard let subcategory = transaction.subcategory else { return false }
                return subcategory.category == category
            }.count
        } catch {
            print("FIN-45: Error counting transactions for category: \(error)")
            return 0
        }
    }

    private func deleteCategory() {
        // Delete subcategories first to avoid SwiftUI @Query conflicts
        for subcategory in subcategories {
            modelContext.delete(subcategory)
        }
        modelContext.delete(category)
        do {
            try modelContext.save()
            modelContext.processPendingChanges()
        } catch {
            print("FIN-45: Error deleting category: \(error)")
        }
        dismiss()
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

    // MARK: - Subcategory Deletion

    private func handleSubcategoryDelete(_ subcategory: Subcategory) {
        let count = countTransactionsForSubcategory(subcategory)
        if count > 0 {
            subcategoryForTransfer = subcategory
        } else {
            subcategoryToDelete = subcategory
            showSubcategoryDeleteConfirmation = true
        }
    }

    private func deleteSubcategory(_ subcategory: Subcategory) {
        modelContext.delete(subcategory)
        do {
            try modelContext.save()
            modelContext.processPendingChanges()
        } catch {
            print("FIN-45: Error deleting subcategory: \(error)")
        }
        subcategoryToDelete = nil
        subcategoryForTransfer = nil
    }

    private func countTransactionsForSubcategory(_ subcategory: Subcategory) -> Int {
        let subcategoryID = subcategory.persistentModelID
        do {
            let descriptor = FetchDescriptor<TransactionItem>()
            let allTransactions = try modelContext.fetch(descriptor)
            return allTransactions.filter { $0.subcategory?.persistentModelID == subcategoryID }.count
        } catch {
            print("FIN-45: Error counting transactions: \(error)")
            return 0
        }
    }
}
