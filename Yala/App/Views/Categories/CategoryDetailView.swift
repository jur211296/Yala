//
//  CategoryDetailView.swift
//  Yala
//
//  Created by Yala Refactoring.
//

import SwiftData
import SwiftUI

/// Detalle de categoría: permite editar nombre, visibilidad y gestionar subcategorías
struct CategoryDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(EntityDeletionService.self) private var deletionService

    @State private var viewModel: CategoryDetailViewModel

    // UI State
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

    // Focus state
    @FocusState private var isNameFieldFocused: Bool

    init(category: Category, isNewCategory: Bool = false) {
        _viewModel = State(initialValue: CategoryDetailViewModel(category: category, isNewCategory: isNewCategory))
    }

    private func handleBack() {
        if viewModel.isNewCategory {
            if viewModel.hasUnsavedChanges {
                showDiscardDialog = true
            } else {
                viewModel.discardNewCategory()
                dismiss()
            }
        } else {
            if viewModel.hasUnsavedChanges {
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
                YalaToolbarButton(systemName: "chevron.left", label: L10n.Action.back) {
                    handleBack()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                YalaSaveButton(
                    action: { saveCategory() },
                    isDisabled: !viewModel.canSave
                )
            }
        }
        .alert(L10n.Category.hiddenTitle, isPresented: $showVisibilityInfo) {
            Button(L10n.Common.understood, role: .cancel) {}
        } message: {
            Text(L10n.Category.hiddenDescription)
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
                if viewModel.isNewCategory {
                    viewModel.discardNewCategory()
                }
                dismiss()
            }
            Button(L10n.Alert.keepEditing, role: .cancel) {}
        } message: {
            Text(L10n.Alert.discardChanges)
        }
        .confirmationDialog(
            L10n.Category.deleteConfirmTitle,
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(L10n.Category.delete, role: .destructive) {
                if viewModel.deleteCategory() {
                    dismiss()
                }
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
                    _ = viewModel.deleteSubcategory(subcategory)
                    subcategoryToDelete = nil
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
                    _ = viewModel.deleteSubcategory(subcategory)
                    subcategoryForTransfer = nil
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .onChange(of: showIconColorPicker) { _, isPresenting in
            if isPresenting { dismissKeyboard() }
        }
        .onAppear {
            viewModel.setContext(modelContext, deletionService: deletionService)
            if viewModel.isNewCategory {
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
                        .fill(Color(hex: viewModel.colorHex))
                        .frame(width: 70, height: 70)
                        .overlay(
                            Image(systemName: viewModel.iconName)
                                .font(DS.Typography.title)
                                .foregroundStyle(.white)
                        )
                        .shadow(color: Color(hex: viewModel.colorHex).opacity(0.3), radius: 6, x: 0, y: 3)

                    // Pencil edit indicator
                    Circle()
                        .fill(.thCard)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Image(systemName: "pencil")
                                .font(DS.Typography.labelSmall)
                                .foregroundStyle(Color(hex: viewModel.colorHex))
                        )
                        .overlay(
                            Circle()
                                .stroke(.thBackground, lineWidth: 2)
                        )
                        .offset(x: 4, y: 4)
                }
            }
            .buttonStyle(.plain)

            Text(viewModel.displayName)
                .font(DS.Typography.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .sheet(isPresented: $showIconColorPicker) {
            IconColorPickerSheet(
                selectedIconName: $viewModel.iconName,
                selectedColorHex: $viewModel.colorHex
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    // Sección de nombre y visibilidad
    private var detailsSection: some View {
        VStack(spacing: DS.Spacing.lg) {
            SectionBox(title: L10n.Category.details) {
                VStack(spacing: DS.Spacing.none) {
                    HStack(spacing: DS.Spacing.md) {
                        Image(systemName: "textformat")
                            .foregroundStyle(.secondary)
                        TextField(L10n.Category.namePlaceholder, text: $viewModel.name)
                            .textContentType(.name)
                            .focused($isNameFieldFocused)
                    }
                    .padding()

                    SubsectionDivider()

                    Toggle(isOn: $viewModel.isVisible) {
                        Text(L10n.Category.show)
                    }

                    .padding()
                    .onChange(of: viewModel.isVisible) { _, newValue in
                        if newValue == false {
                            showVisibilityInfo = true
                        }
                    }
                }
            }

            // Delete button (only for user-created categories, not system categories)
            if !viewModel.isNewCategory && !viewModel.isSystemCategory {
                SectionBox(title: "") {
                    Button {
                        transactionCount = viewModel.countTransactionsInCategory()
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
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // Sección de subcategorías
    private var subcategoriesSection: some View {
        let visibles = viewModel.visibleSubcategories
        let ocultas = viewModel.hiddenSubcategories

        return VStack(spacing: DS.Spacing.lg) {
            // Active subcategories section
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                // Header with Edit/Done button
                HStack {
                    Text(L10n.Category.activeSubcategories)
                        .font(DS.Typography.headline)
                        .foregroundStyle(Color.primary.opacity(0.6))
                    Spacer()
                    if !visibles.isEmpty || !ocultas.isEmpty {
                        Button {
                            isEditingSubcategories.toggle()
                        } label: {
                            Text(isEditingSubcategories ? L10n.Action.done : L10n.Action.edit)
                                .font(DS.Typography.subheadline)
                                .foregroundStyle(.primary)
                        }
                    }
                }
                .padding(.horizontal, DS.Spacing.xs)

                VStack(spacing: DS.Spacing.none) {
                    if visibles.isEmpty && ocultas.isEmpty {
                        Text(L10n.Category.noSubcategoriesYet)
                            .font(DS.Typography.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else if !visibles.isEmpty {
                        VStack(spacing: DS.Spacing.none) {
                            ForEach(Array(visibles.enumerated()), id: \.element.id) { index, subcategory in
                                HStack(spacing: DS.Spacing.none) {
                                    if isEditingSubcategories && !subcategory.isSystemSubcategory {
                                        Button {
                                            handleSubcategoryDelete(subcategory)
                                        } label: {
                                            Image(systemName: "minus.circle.fill")
                                                .font(DS.Typography.title)
                                                .foregroundStyle(.red)
                                        }
                                        .accessibilityLabel("Eliminar subcategoría")
                                        .padding(.leading, DS.Spacing.lg)
                                        .padding(.trailing, DS.Spacing.sm)
                                    }

                                    NavigationLink {
                                        SubcategoryDetailView(
                                            parentCategory: viewModel.category, subcategoryToEdit: subcategory)
                                    } label: {
                                        HStack {
                                            subcategoryRow(subcategory)
                                            Image(systemName: "chevron.right")
                                                .font(DS.Typography.labelSmall)
                                                .foregroundStyle(.tertiary)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.horizontal, isEditingSubcategories && !subcategory.isSystemSubcategory ? 8 : 16)
                                    .padding(.vertical, DS.Spacing.sm)
                                }

                                if index < visibles.count - 1 {
                                    Divider()
                                        .padding(.leading, isEditingSubcategories && !subcategory.isSystemSubcategory ? 56 : 16)
                                }
                            }
                        }
                        .padding(.vertical, DS.Spacing.xs)
                    }

                    Divider()
                        .padding(.horizontal, DS.Spacing.lg)

                    NavigationLink {
                        SubcategoryDetailView(parentCategory: viewModel.category)
                    } label: {
                        HStack(spacing: DS.Spacing.md) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.thAccent)
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
                        .fill(.thCard)
                )
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                        .stroke(DS.Colors.borderDark, lineWidth: 0.8)
                )
                .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 6)
            }

            // Hidden subcategories section
            if !ocultas.isEmpty {
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    Text(L10n.Category.hiddenSubcategories)
                        .font(DS.Typography.headline)
                        .foregroundStyle(Color.primary.opacity(0.6))
                        .padding(.leading, DS.Spacing.xs)

                    VStack(spacing: DS.Spacing.none) {
                        ForEach(Array(ocultas.enumerated()), id: \.element.id) { index, subcategory in
                            HStack(spacing: DS.Spacing.none) {
                                if isEditingSubcategories && !subcategory.isSystemSubcategory {
                                    Button {
                                        handleSubcategoryDelete(subcategory)
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .font(DS.Typography.title)
                                            .foregroundStyle(.red)
                                    }
                                    .accessibilityLabel("Eliminar subcategoría")
                                    .padding(.leading, DS.Spacing.lg)
                                    .padding(.trailing, DS.Spacing.sm)
                                }

                                NavigationLink {
                                    SubcategoryDetailView(
                                        parentCategory: viewModel.category, subcategoryToEdit: subcategory)
                                } label: {
                                    HStack {
                                        subcategoryRow(subcategory)
                                        Image(systemName: "chevron.right")
                                            .font(DS.Typography.labelSmall)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal, isEditingSubcategories && !subcategory.isSystemSubcategory ? 8 : 16)
                                .padding(.vertical, DS.Spacing.sm)
                            }

                            if index < ocultas.count - 1 {
                                Divider()
                                    .padding(.leading, isEditingSubcategories && !subcategory.isSystemSubcategory ? 56 : 16)
                            }
                        }
                    }
                    .padding(.vertical, DS.Spacing.xs)
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                            .fill(.thCard)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                            .stroke(DS.Colors.borderDark, lineWidth: 0.8)
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
                .fill(Color(hex: viewModel.colorHex))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: subcategory.iconName ?? viewModel.category.iconName ?? "tag")
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.white)
                )

            Text(subcategory.name)
                .font(DS.Typography.body)
                .foregroundStyle(.primary)

            Spacer()
        }
        .contentShape(Rectangle())
    }

    // MARK: - Actions

    private func saveCategory() {
        if viewModel.isNewCategory && viewModel.subcategories.isEmpty {
            showMissingSubcategoriesAlert = true
            return
        }
        if viewModel.saveCategory() {
            dismiss()
        }
    }

    private func handleSubcategoryDelete(_ subcategory: Subcategory) {
        let count = viewModel.countTransactionsForSubcategory(subcategory)
        if count > 0 {
            subcategoryForTransfer = subcategory
        } else {
            subcategoryToDelete = subcategory
            showSubcategoryDeleteConfirmation = true
        }
    }
}
