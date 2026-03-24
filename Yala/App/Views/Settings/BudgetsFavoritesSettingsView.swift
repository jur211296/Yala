//
//  BudgetsFavoritesSettingsView.swift
//  Yala
//
//  Manage budgets: create, edit, delete + favorite management for widget display.
//  Favorite budgets appear in the Budgets widget (top 3 in medium, top 5 in large).
//

import SwiftData
import SwiftUI

struct BudgetsFavoritesSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(SessionState.self) private var sessionState
    @Environment(\.yalaTheme) private var theme

    @State private var viewModel = BudgetsFavoritesSettingsViewModel()

    var body: some View {
        ZStack {
            PanelBackgroundView()

            ScrollView {
                VStack(spacing: DS.Spacing.xxl) {
                    if viewModel.isEmpty {
                        emptyState
                    } else {
                        // Info header (visible when budgets exist)
                        infoHeader

                        // Widget preview
                        if viewModel.hasFavorites && !viewModel.isEditMode {
                            widgetPreview
                        }

                        if viewModel.isEditMode {
                            // Edit mode: show only favorites for reordering
                            reorderSection
                        } else {
                            // Normal mode: show all budgets grouped by period
                            ForEach(viewModel.budgetsByPeriod, id: \.periodType) { group in
                                periodSection(periodType: group.periodType, budgets: group.budgets)
                            }
                        }
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.xxl)
            }
        }
        .navigationTitle(L10n.Settings.budgets)
        .navigationBarTitleDisplayMode(.inline)
        .swipeBack()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                YalaToolbarButton(systemName: "chevron.left", label: L10n.Action.back) {
                    dismiss()
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: DS.Spacing.xs) {
                    if viewModel.isEditMode {
                        YalaToolbarButton(systemName: "checkmark", label: L10n.Action.done) {
                            dsWithAnimation(reduceMotion, .spring(response: 0.3, dampingFraction: 0.8)) {
                                viewModel.isEditMode.toggle()
                            }
                        }
                    } else {
                        if viewModel.hasFavorites {
                            YalaToolbarButton(systemName: "arrow.up.arrow.down", label: L10n.Action.reorder) {
                                dsWithAnimation(reduceMotion, .spring(response: 0.3, dampingFraction: 0.8)) {
                                    viewModel.isEditMode.toggle()
                                }
                            }
                        }

                        YalaToolbarButton(systemName: "plus", label: L10n.Action.add) {
                            viewModel.requestCreate()
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $viewModel.showEditor, onDismiss: { viewModel.closeEditor() }) {
            BudgetEditorView(budget: viewModel.budgetToEdit)
        }
        .sheet(isPresented: $viewModel.showUpgradeSheet) {
            UpgradePromptSheet(feature: .budgets, context: .limitReached)
        }
        .alert(
            L10n.Common.error,
            isPresented: $viewModel.showSaveError,
            actions: {
                Button(L10n.Common.understood, role: .cancel) {}
            },
            message: {
                Text(L10n.Common.saveError)
            }
        )
        .alert(
            L10n.Common.error,
            isPresented: $viewModel.showDeleteError,
            actions: {
                Button(L10n.Common.understood, role: .cancel) {}
            },
            message: {
                Text(L10n.Common.deleteError)
            }
        )
        .alert(
            NSLocalizedString("budgets.delete.confirm.title", comment: ""),
            isPresented: $viewModel.showDeleteConfirmation
        ) {
            Button(L10n.Action.delete, role: .destructive) { viewModel.deleteBudget() }
            Button(L10n.Common.cancel, role: .cancel) {}
        } message: {
            Text(NSLocalizedString("budgets.delete.confirm.message", comment: ""))
        }
        .onAppear {
            viewModel.setContext(modelContext, sessionState: sessionState)
        }
    }

    // MARK: - Widget Preview

    private var widgetPreview: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(NSLocalizedString("budgets.favorites.previewTitle", comment: ""))
                .font(DS.Typography.headline)
                .foregroundStyle(Color.primary.opacity(0.6))
                .padding(.leading, DS.Chip.paddingV)

            VStack(spacing: DS.Spacing.md) {
                ForEach(Array(viewModel.favoriteBudgets.prefix(3).enumerated()), id: \.element.persistentModelID) { _, budget in
                    previewBudgetRow(budget)
                }
            }
            .padding(DS.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .fill(.thCard)
            )
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .stroke(theme.accent.opacity(0.2), lineWidth: 1)
            )
            .dsSubtleShadow()
        }
    }

    private func previewBudgetRow(_ budget: Budget) -> some View {
        let (icon, colorHex) = budget.displayProperties

        return HStack(spacing: DS.Spacing.md) {
            // Icon badge (matches BudgetWidgetRow)
            ZStack {
                Circle()
                    .fill(Color(hex: colorHex))
                    .frame(width: DS.Icon.badgeLarge, height: DS.Icon.badgeLarge)

                Image(systemName: icon)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                // Name and limit row
                HStack {
                    Text(budget.name)
                        .font(DS.Typography.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer()

                    Text(formatAmount(budget.limitAmount, currency: budget.currencyCode))
                        .font(DS.Typography.headline)
                        .foregroundStyle(.primary)
                }

                // Placeholder progress bar (empty)
                BudgetProgressBar(
                    percentage: 0,
                    color: colorHex,
                    isExceeded: false,
                    simplified: true
                )
            }
        }
    }

    // MARK: - Info Header

    private var infoHeader: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "info.circle.fill")
                .font(DS.Typography.body)
                .foregroundStyle(.thAccent)

            Text(L10n.Settings.budgetsFavoritesInfo)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .fill(theme.accent.opacity(0.1))
        )
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack {
            Spacer()
            YalaEmptyState.noBudgets { viewModel.requestCreate() }
            Spacer()
        }
    }

    // MARK: - Period Section

    private func periodSection(periodType: BudgetPeriodType, budgets: [Budget]) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(periodType.localizedName)
                .font(DS.Typography.headline)
                .foregroundStyle(Color.primary.opacity(0.6))
                .padding(.leading, DS.Chip.paddingV)

            VStack(spacing: DS.Spacing.none) {
                ForEach(Array(budgets.enumerated()), id: \.element.persistentModelID) { index, budget in
                    budgetRow(budget)

                    if index < budgets.count - 1 {
                        Divider()
                            .padding(.leading, DS.Spacing.formIndent)
                    }
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
            .dsSubtleShadow()
        }
    }

    // MARK: - Budget Row

    private func budgetRow(_ budget: Budget) -> some View {
        let (icon, colorHex) = budget.displayProperties

        return HStack(spacing: DS.Spacing.none) {
            // Tappable area: opens editor
            Button {
                viewModel.openEditor(for: budget)
            } label: {
                HStack(spacing: DS.Spacing.md) {
                    // Icon badge (40x40)
                    ZStack {
                        Circle()
                            .fill(Color(hex: colorHex).opacity(0.15))
                            .frame(width: 40, height: 40)

                        Image(systemName: icon)
                            .font(DS.Typography.body)
                            .foregroundStyle(Color(hex: colorHex))
                    }

                    // Info
                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                        Text(budget.name)
                            .font(DS.Typography.bodyBold)
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        Text(formatAmount(budget.limitAmount, currency: budget.currencyCode))
                            .font(DS.Typography.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Favorite star — separate Button, not inside the row Button
            Button {
                dsWithAnimation(reduceMotion, .spring(response: 0.3, dampingFraction: 0.8)) {
                    viewModel.toggleFavorite(budget)
                }
            } label: {
                Image(systemName: budget.isFavorite ? "star.fill" : "star")
                    .font(DS.Typography.body)
                    .foregroundStyle(budget.isFavorite ? DS.Semantic.favoriteIcon : Color.secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Chevron — tapping opens editor too
            Button {
                viewModel.openEditor(for: budget)
            } label: {
                Image(systemName: "chevron.right")
                    .font(DS.Typography.indicator)
                    .foregroundStyle(.tertiary)
                    .frame(width: 24, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
        .contextMenu {
            Button {
                viewModel.openEditor(for: budget)
            } label: {
                Label(L10n.Action.edit, systemImage: "pencil")
            }

            Button(role: .destructive) {
                viewModel.confirmDelete(budget)
            } label: {
                Label(L10n.Action.delete, systemImage: "trash")
            }
        }
    }

    // MARK: - Reorder Section (Edit Mode)

    private var reorderSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(L10n.Settings.budgetsFavoritesReorder)
                .font(DS.Typography.headline)
                .foregroundStyle(Color.primary.opacity(0.6))
                .padding(.leading, DS.Chip.paddingV)

            List {
                ForEach(Array(viewModel.favoriteBudgets.enumerated()), id: \.element.persistentModelID) { index, budget in
                    reorderRow(budget, position: index + 1)
                        .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                        .listRowBackground(theme.card)
                        .listRowSeparator(
                            index == 0 || index == viewModel.favoriteBudgets.count - 1 ? .hidden : .visible,
                            edges: index == 0 ? .top : .bottom
                        )
                }
                .onMove(perform: viewModel.moveBudget)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollDisabled(true)
            .frame(height: CGFloat(viewModel.favoriteBudgets.count) * 52)
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
            .environment(\.editMode, .constant(.active))
        }
    }

    private func reorderRow(_ budget: Budget, position: Int) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Text("#\(position)")
                .font(DS.Typography.captionMonoBold)
                .foregroundStyle(.thAccent)
                .frame(width: 28)

            Text(budget.name)
                .font(DS.Typography.body)
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer()

            Text(BudgetPeriodType(rawValue: budget.periodType)?.localizedName ?? "")
                .font(DS.Typography.caption)
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }

    // MARK: - Helpers

    private static let amountFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.maximumFractionDigits = 0
        return f
    }()

    private func formatAmount(_ amount: Double, currency: String) -> String {
        Self.amountFormatter.currencyCode = currency
        return Self.amountFormatter.string(from: NSNumber(value: amount)) ?? "\(currency) \(Int(amount))"
    }
}

#Preview {
    NavigationStack {
        BudgetsFavoritesSettingsView()
    }
}
