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
    @State private var showDiscardDialog: Bool = false
    @State private var showMissingSubcategoriesAlert: Bool = false
    @State private var showIconColorPicker: Bool = false
    @State private var showDeleteConfirmation: Bool = false
    @State private var showCannotDeleteAlert: Bool = false
    @State private var transactionCount: Int = 0
    /// «Mover sus registros…» desde el aviso de «No se puede eliminar» (L7-10).
    @State private var showMoveRecordsSheet: Bool = false
    /// No se pudo contar lo que hay dentro: no se borra nada a ciegas.
    @State private var showCountFailed: Bool = false

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
        ScrollView {
            VStack(spacing: DS.Spacing.xxl) {
                header
                detailsSection
                subcategoriesSection
                // «Eliminar» al fondo, como en cuentas y etiquetas: en medio se tocaba sin querer (L7-11).
                deleteSection
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.xxl)
            .dismissKeyboardOnTap()
        }
        .scrollDismissesKeyboard(.interactively)
        .yalaScreenBackground(.subtle)
        // Una categoría recién creada no se «edita» todavía (auditoría UX 2.2, lote 7, B4).
        .navigationTitle(viewModel.isNewCategory ? L10n.Category.new : L10n.Category.editTitle)
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
        .alert(L10n.Category.addOneSubcategory, isPresented: $showMissingSubcategoriesAlert) {
            Button(L10n.Common.understood, role: .cancel) {}
        } message: {
            Text(L10n.Category.requiresSubcategory)
        }
        // Alertas y no `confirmationDialog`: en iOS 26 el diálogo sale como popover y no pinta el botón
        // de cancelar, así que «Seguir editando» y «Cancelar» no se veían; y el de descartar decía
        // «Descartar» tres veces (auditoría UX 2.2, lote 7, B3). Textos del molde de la Bandeja.
        .alert(L10n.Inbox.discardChangesTitle, isPresented: $showDiscardDialog) {
            Button(L10n.Inbox.discardChanges, role: .destructive) {
                if viewModel.isNewCategory {
                    viewModel.discardNewCategory()
                }
                dismiss()
            }
            Button(L10n.Inbox.keepEditing, role: .cancel) {}
        } message: {
            Text(L10n.Inbox.discardChangesMessage)
        }
        .alert(L10n.Category.deleteConfirmTitle, isPresented: $showDeleteConfirmation) {
            Button(L10n.Category.delete, role: .destructive) {
                if viewModel.deleteCategory() {
                    dismiss()
                }
            }
            Button(L10n.Action.cancel, role: .cancel) {}
        } message: {
            Text(L10n.Category.deleteConfirmMessage)
        }
        .modifier(CategoryCannotDeleteAlert(
            isPresented: $showCannotDeleteAlert,
            recordCount: transactionCount,
            onHide: hideCategory,
            onMove: { showMoveRecordsSheet = true }
        ))
        .alert(L10n.Common.error, isPresented: $showCountFailed) {
            Button(L10n.Common.understood, role: .cancel) {}
        } message: {
            Text(L10n.UXL7.Categories.countFailed)
        }
        .sheet(isPresented: $showMoveRecordsSheet) {
            CategoryMoveRecordsSheet(category: viewModel.category) {
                dismiss()
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .alert(L10n.Subcategory.deleteConfirmTitle, isPresented: $showSubcategoryDeleteConfirmation) {
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
                        .frame(width: DS.Icon.badgeSmall, height: DS.Icon.badgeSmall)
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
            .accessibilityLabel(L10n.Action.edit)

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
                            .accessibilityHidden(true)
                        TextField(L10n.Category.namePlaceholder, text: $viewModel.name)
                            .textContentType(.name)
                            .focused($isNameFieldFocused)
                            .accessibilityIdentifier("category_name_field")
                    }
                    .padding()

                    SubsectionDivider()

                    // «Usar al registrar» con su pie, y sin alerta al apagarlo: la alerta salía antes de guardar,
                    // como si ya estuviera hecho, y decía lo mismo que este pie (L7-11).
                    Toggle(isOn: $viewModel.isVisible) {
                        Text(L10n.UXL7.Categories.useWhenRecording)
                    }
                    .padding()
                    .accessibilityIdentifier("category_use_when_recording_toggle")

                    Text(L10n.UXL7.Categories.useWhenRecordingFooter)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.bottom)
                }
            }
        }
    }

    // Delete button (only for user-created categories, not system categories)
    @ViewBuilder
    private var deleteSection: some View {
        if !viewModel.isNewCategory && !viewModel.isSystemCategory {
            SectionBox(title: "") {
                Button {
                    requestDelete()
                } label: {
                    HStack {
                        Spacer()
                        Text(L10n.Category.delete)
                            .foregroundStyle(DS.Semantic.errorForeground)
                        Spacer()
                    }
                    .padding()
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("category_delete_button")
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
                                    if isEditingSubcategories && !subcategory.isAnySystem {
                                        Button {
                                            handleSubcategoryDelete(subcategory)
                                        } label: {
                                            Image(systemName: "minus.circle.fill")
                                                .font(DS.Typography.title)
                                                .foregroundStyle(DS.Semantic.errorForeground)
                                        }
                                        .accessibilityLabel(L10n.Accessibility.deleteSubcategory)
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
                                                .accessibilityHidden(true)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.horizontal, isEditingSubcategories && !subcategory.isAnySystem ? DS.Spacing.sm : DS.Spacing.lg)
                                    .padding(.vertical, DS.Spacing.sm)
                                }

                                if index < visibles.count - 1 {
                                    Divider()
                                        .padding(.leading, isEditingSubcategories && !subcategory.isAnySystem ? DS.Spacing.xxxxl + DS.Spacing.sm : DS.Spacing.lg)
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
                    .accessibilityIdentifier("category_add_subcategory")
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
                .dsSubtleShadow()
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
                                if isEditingSubcategories && !subcategory.isAnySystem {
                                    Button {
                                        handleSubcategoryDelete(subcategory)
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .font(DS.Typography.title)
                                            .foregroundStyle(DS.Semantic.errorForeground)
                                    }
                                    .accessibilityLabel(L10n.Accessibility.deleteSubcategory)
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
                                            .accessibilityHidden(true)
                                    }
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal, isEditingSubcategories && !subcategory.isAnySystem ? DS.Spacing.sm : DS.Spacing.lg)
                                .padding(.vertical, DS.Spacing.sm)
                            }

                            if index < ocultas.count - 1 {
                                Divider()
                                    .padding(.leading, isEditingSubcategories && !subcategory.isAnySystem ? DS.Spacing.xxxxl + DS.Spacing.sm : DS.Spacing.lg)
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
                    .dsSubtleShadow()
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

    /// Con registros no se borra: se ofrece ocultarla o mover sus registros (L7-10). El recuento cuenta también
    /// los registros que solo llevan una de sus subcategorías, y si no se puede leer, no se borra nada.
    private func requestDelete() {
        guard let count = viewModel.recordCountForDeletion() else {
            showCountFailed = true
            return
        }
        transactionCount = count
        if count > 0 {
            showCannotDeleteAlert = true
        } else {
            showDeleteConfirmation = true
        }
    }

    /// «Ocultarla»: deja de aparecer al registrar y su historial se queda (L7-10).
    private func hideCategory() {
        viewModel.isVisible = false
        if viewModel.saveCategory() {
            dismiss()
        }
    }

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
