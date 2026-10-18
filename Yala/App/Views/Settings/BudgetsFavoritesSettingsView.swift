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
    @Environment(AppPreferences.self) private var appPreferences

    @State private var viewModel = BudgetsFavoritesSettingsViewModel()
    /// Lo gastado de cada favorito en su período actual, para que la vista previa enseñe cifras reales (UX 2.2 · L9-11).
    @State private var spendingViewModel = BudgetsViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.xxl) {
                    if viewModel.isEmpty {
                        emptyState
                    } else {
                        // Info header (visible when budgets exist)
                        infoHeader

                        // Vista previa con su sitio reservado desde el principio (UX 2.2 · L9-11): al aparecer con la primera
                        // estrella empujaba la lista, y el segundo toque caía en otro presupuesto.
                        if !viewModel.isEditMode {
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
        .yalaScreenBackground(.subtle)
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
        // Nombra el presupuesto y dice que los gastos se quedan (UX 2.2 · L9-14).
        .alert(
            L10n.UXL9.deleteTitle(viewModel.budgetToDelete?.name ?? ""),
            isPresented: $viewModel.showDeleteConfirmation
        ) {
            Button(L10n.Action.delete, role: .destructive) { viewModel.deleteBudget() }
            Button(L10n.Common.cancel, role: .cancel) {}
        } message: {
            Text(NSLocalizedString("budgets.delete.confirm.message", comment: ""))
        }
        .onAppear {
            viewModel.setContext(modelContext, sessionState: sessionState)
            spendingViewModel.setContext(modelContext)
        }
    }

    // MARK: - Widget Preview

    /// La MISMA tarjeta de Presupuestos del Panel en tamaño mediano, con lo gastado real (UX 2.2 · L9-11). Su alto se
    /// reserva para tres filas aunque no haya ninguna marcada, así la lista de debajo no se mueve al tocar estrellas.
    private var widgetPreview: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(NSLocalizedString("budgets.favorites.previewTitle", comment: ""))
                .font(DS.Typography.headline)
                .foregroundStyle(Color.primary.opacity(0.6))
                .padding(.leading, DS.Chip.paddingV)

            ZStack(alignment: .top) {
                // Molde invisible de tres filas: fija el alto.
                previewSkeleton
                    .hidden()
                    .accessibilityHidden(true)

                if previewSummaries.isEmpty {
                    VStack(spacing: DS.Spacing.sm) {
                        Image(systemName: "star")
                            .font(DS.Typography.title)
                            .foregroundStyle(DS.Semantic.favoriteIcon)
                            .accessibilityHidden(true)
                        Text(L10n.UXL9.previewEmpty)
                            .font(DS.Typography.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(DS.Spacing.lg)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .panelCard()
                    .accessibilityIdentifier("budgets_favorites_preview_empty")
                } else {
                    BudgetsWidget(
                        budgets: previewSummaries,
                        currencyCode: appPreferences.defaultCurrencyCode.rawValue,
                        size: .medium
                    )
                    .allowsHitTesting(false)
                    .accessibilityIdentifier("budgets_favorites_preview")
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Los tres primeros favoritos, en su orden, con lo gastado de su período actual.
    private var previewSummaries: [BudgetSummary] {
        let currency = appPreferences.defaultCurrencyCode.rawValue
        return viewModel.favoriteBudgets.prefix(3).map {
            spendingViewModel.buildSummary(for: $0, defaultCurrencyCode: currency)
        }
    }

    /// Mismas piezas y tipografías que la tarjeta con tres filas (`BudgetsWidget` + `BudgetWidgetRow`).
    private var previewSkeleton: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text(L10n.WidgetType.budgets)
                .font(DS.Typography.subheadlineEmphasized)
            VStack(spacing: DS.Spacing.lg) {
                ForEach(0..<3, id: \.self) { _ in
                    HStack(spacing: DS.Spacing.md) {
                        Circle().frame(width: DS.Icon.badgeLarge, height: DS.Icon.badgeLarge)
                        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                            Text(verbatim: "Aa").font(DS.Typography.headline)
                            Text(verbatim: "Aa").font(DS.Typography.captionSmall)
                            BudgetProgressBar(percentage: 0, color: "#000000", isExceeded: false, simplified: true)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .panelCard()
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
            .solidCard()
        }
    }

    // MARK: - Budget Row

    private func budgetRow(_ budget: Budget) -> some View {
        // CSV mirror SSOT con fallback M2M para legacy budgets pre-deploy.
        let (icon, colorHex) = Budget.computeDisplayProperties(for: budget, in: modelContext)

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
                            .frame(width: DS.ListRow.iconSize, height: DS.ListRow.iconSize)

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
                    .frame(width: DS.Button.actionSize, height: DS.Button.actionSize)
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
                    .frame(width: DS.Button.actionSize, height: DS.Button.actionSize)
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
                        .listRowBackground(Color.clear)
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
            .solidCard()
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

    /// Con la preferencia de divisa del usuario (símbolo o código, decimales), como el resto de la app. Antes
    /// llevaba su propio formateador sin decimales y con la región del iPhone: «S/ 1,800» aquí y «S/ 1,800.00» en
    /// Planificación (auditoría UX 2.2, lote 9).
    private func formatAmount(_ amount: Double, currency: String) -> String {
        appPreferences.currency(amount, currencyCode: currency)
    }
}

#Preview {
    NavigationStack {
        BudgetsFavoritesSettingsView()
    }
}
