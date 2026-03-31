//
//  CategoriesSettingsListView.swift
//  Yala
//
//  Created by Yala Refactoring.
//

import SwiftData
import SwiftUI

// MARK: - Categorías en Ajustes

/// Lista principal de categorías dentro de Ajustes → Registros
struct CategoriesSettingsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionState.self) private var sessionState
    @Environment(EntityDeletionService.self) private var deletionService
    @State private var viewModel = CategoriesSettingsListViewModel()

    var body: some View {
        ZStack {
            PanelBackgroundView()

            ScrollView {
                VStack(spacing: DS.Spacing.xxl) {
                    if viewModel.isEmpty {
                        emptyState
                    } else {
                        if !viewModel.activeCategories.isEmpty {
                            ContextualGuideBanner.categoriesSettings()
                            activeCategoriesSection
                        }

                        if !viewModel.hiddenCategories.isEmpty {
                            hiddenCategoriesSection
                        }
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.xxxl)
            }
        }
        .navigationTitle(L10n.Settings.categories)
        .navigationBarTitleDisplayMode(.inline)
        .swipeBack()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                YalaToolbarButton(systemName: "chevron.left", label: L10n.Action.back) {
                    dismiss()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                YalaToolbarButton(systemName: "plus", label: L10n.Action.add) {
                    viewModel.createAndOpenNewCategory()
                }
            }
        }
        .navigationDestination(isPresented: $viewModel.isNavigatingToNewCategory) {
            if let newCategory = viewModel.newCategory {
                CategoryDetailView(category: newCategory, isNewCategory: true)
            } else {
                EmptyView()
            }
        }
        .alert(
            L10n.Category.cannotDeleteTitle,
            isPresented: $viewModel.showCannotDeleteAlert
        ) {
            Button(L10n.Common.understood, role: .cancel) {}
        } message: {
            Text(L10n.Category.cannotDeleteMessage(viewModel.transactionCountForAlert))
        }
        .onAppear {
            viewModel.setContext(modelContext, deletionService: deletionService)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.lg) {
            Image(systemName: "folder.fill")
                .font(DS.Typography.amountLarge)
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)

            Text(L10n.Empty.noCategories)
                .font(DS.Typography.headline)
                .foregroundStyle(.secondary)

            Text(L10n.Empty.categoriesDescription)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.xxxl)
        }
        .padding(.top, DS.Spacing.sheetTop)
    }

    // MARK: - Active Categories Section

    private var activeCategoriesSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                Text(L10n.Common.active)
                    .font(DS.Typography.headline)
                    .foregroundStyle(Color.primary.opacity(0.6))
                Spacer()
                Button {
                    viewModel.isEditing.toggle()
                } label: {
                    Text(viewModel.isEditing ? L10n.Action.done : L10n.Action.edit)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.primary)
                }
            }
            .padding(.horizontal, DS.Chip.paddingV)

            VStack(spacing: DS.Spacing.none) {
                ForEach(Array(viewModel.activeCategories.enumerated()), id: \.element.id) { index, category in
                    HStack(spacing: DS.Spacing.none) {
                        if viewModel.isEditing {
                            Button {
                                viewModel.handleCategoryDelete(category)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(DS.Typography.title)
                                    .foregroundStyle(DS.Semantic.errorForeground)
                            }
                            .accessibilityLabel(L10n.Accessibility.deleteCategory)
                            .padding(.leading, DS.Spacing.lg)
                            .padding(.trailing, DS.Spacing.sm)
                        }

                        NavigationLink {
                            CategoryDetailView(category: category)
                        } label: {
                            HStack {
                                categoryRow(category)
                                Image(systemName: "chevron.right")
                                    .font(DS.Typography.subheadline).fontWeight(.medium)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, viewModel.isEditing ? DS.Spacing.sm : DS.Spacing.lg)
                        .padding(.vertical, DS.Spacing.sm)
                    }

                    if index < viewModel.activeCategories.count - 1 {
                        Divider()
                            .padding(.leading, viewModel.isEditing ? DS.Spacing.formIndent + DS.Spacing.xs : DS.Spacing.lg)
                    }
                }
            }
            .padding(.vertical, DS.Chip.paddingV)
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

    // MARK: - Hidden Categories Section

    private var hiddenCategoriesSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(L10n.Common.hidden)
                .font(DS.Typography.headline)
                .foregroundStyle(Color.primary.opacity(0.6))
                .padding(.leading, DS.Chip.paddingV)

            VStack(spacing: DS.Spacing.none) {
                ForEach(Array(viewModel.hiddenCategories.enumerated()), id: \.element.id) { index, category in
                    HStack(spacing: DS.Spacing.none) {
                        if viewModel.isEditing {
                            Button {
                                viewModel.handleCategoryDelete(category)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(DS.Typography.title)
                                    .foregroundStyle(DS.Semantic.errorForeground)
                            }
                            .accessibilityLabel(L10n.Accessibility.deleteCategory)
                            .padding(.leading, DS.Spacing.lg)
                            .padding(.trailing, DS.Spacing.sm)
                        }

                        NavigationLink {
                            CategoryDetailView(category: category)
                        } label: {
                            HStack {
                                categoryRow(category)
                                Image(systemName: "chevron.right")
                                    .font(DS.Typography.subheadline).fontWeight(.medium)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, viewModel.isEditing ? DS.Spacing.sm : DS.Spacing.lg)
                        .padding(.vertical, DS.Spacing.sm)
                    }

                    if index < viewModel.hiddenCategories.count - 1 {
                        Divider()
                            .padding(.leading, viewModel.isEditing ? DS.Spacing.formIndent + DS.Spacing.xs : DS.Spacing.lg)
                    }
                }
            }
            .padding(.vertical, DS.Chip.paddingV)
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

    // MARK: - Category Row

    @ViewBuilder
    private func categoryRow(_ category: Category) -> some View {
        let isDimmed = sessionState.isExpensesOnlyMode && category.isIncome

        HStack(spacing: DS.Spacing.md) {
            // Círculo con color e icono estándar de etiqueta
            Circle()
                .fill(colorForHex(category.colorHex))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: category.iconName ?? "tag")
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.white)
                )

            Text(category.name)
                .font(DS.Typography.body)
                .foregroundStyle(.primary)

            if isDimmed {
                Text(L10n.Settings.categoryHidden)
                    .font(DS.Typography.labelTiny)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, DS.Spacing.xxs)
                    .background(.thSecondaryText.opacity(0.1))
                    .clipShape(Capsule())
            }

            Spacer()
        }
        .contentShape(Rectangle())
        .opacity(isDimmed ? 0.5 : 1.0)
    }
}
