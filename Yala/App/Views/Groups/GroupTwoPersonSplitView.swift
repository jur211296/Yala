//
//  GroupTwoPersonSplitView.swift
//  Yala
//
//  Pre-pantalla de split rápido para grupos de DOS personas (estilo Splitwise): las 4
//  combinaciones más comunes de (pagador × reparto) en lenguaje natural, con su saldo
//  resultante. "Más opciones" baja al editor detallado (GroupSplitSelectorView). Escribe
//  estado válido del ViewModel vía `applyTwoPersonChoice` — sin modelo de datos propio.
//

import SwiftUI

struct GroupTwoPersonSplitView: View {

    @Bindable var viewModel: GroupExpenseViewModel
    /// Baja esta sheet y sube el editor detallado (dismiss-then-present en el form).
    let onMoreOptions: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences

    /// Nombre de la otra persona (la deuda y las acciones "es todo de X" se refieren a ella).
    private var otherName: String { viewModel.otherActiveMemberName }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    optionsCard
                    moreOptionsButton
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.lg)
            }
            .yalaScreenBackground(.subtle)
            .navigationTitle(L10n.Groups.Expense.TwoPerson.sheetTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents(DS.Adaptive.sheetDetents([.large]))
        .presentationDragIndicator(.visible)
    }

    // MARK: - Options

    private var optionsCard: some View {
        VStack(spacing: DS.Spacing.none) {
            ForEach(TwoPersonSplitOptions.Choice.allCases) { choice in
                optionRow(choice)
                if choice != TwoPersonSplitOptions.Choice.allCases.last {
                    Divider().padding(.leading, DS.Spacing.lg)
                }
            }
        }
        .solidCard(radius: DS.Radius.xl)
    }

    private func optionRow(_ choice: TwoPersonSplitOptions.Choice) -> some View {
        let isActive = viewModel.activeTwoPersonChoice == choice
        let subtitle = debtSubtitle(for: choice)
        return Button {
            viewModel.applyTwoPersonChoice(choice)
            TelemetryService.track(.groupTwoPersonSplitChosen, parameters: ["choice": choice.rawValue])
            dismiss()
        } label: {
            HStack(spacing: DS.Spacing.md) {
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(choice.actionTitle(otherName: otherName))
                        .font(DS.Typography.body)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                    if let subtitle {
                        Text(subtitle)
                            .font(DS.Typography.subheadline)
                            .foregroundStyle(debtColor(for: choice))
                    }
                }
                Spacer()
                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .font(DS.Typography.headline)
                        .foregroundStyle(theme.accent)
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel(for: choice, subtitle: subtitle))
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    private var moreOptionsButton: some View {
        Button {
            TelemetryService.track(.groupTwoPersonSplitChosen, parameters: ["choice": "moreOptions"])
            onMoreOptions()
        } label: {
            HStack(spacing: DS.Spacing.xs) {
                Text(L10n.Groups.Expense.TwoPerson.moreOptions)
                Image(systemName: "slider.horizontal.3")
            }
            .font(DS.Typography.subheadlineEmphasized)
            .foregroundStyle(theme.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Text helpers

    /// Saldo resultante. `nil` con monto vacío → la fila muestra solo la acción (consistente
    /// con el footer del editor detallado, que oculta la línea de monto cuando amount == 0).
    private func debtSubtitle(for choice: TwoPersonSplitOptions.Choice) -> String? {
        guard viewModel.amount > 0 else { return nil }
        let amount = TwoPersonSplitOptions.debt(for: choice, total: viewModel.amount).amount
        let amountStr = appPreferences.currency(amount, currencyCode: viewModel.currencyCode)
        return choice.debtText(otherName: otherName, amountStr: amountStr)
    }

    /// Verde (te deben) / hot pink (debes) — misma convención que `GroupHeaderBalanceBar`.
    private func debtColor(for choice: TwoPersonSplitOptions.Choice) -> Color {
        choice.debtDirection == .theyOweMe ? DS.Semantic.successForeground : .hotPink
    }

    private func accessibilityLabel(for choice: TwoPersonSplitOptions.Choice, subtitle: String?) -> String {
        let title = choice.actionTitle(otherName: otherName)
        guard let subtitle else { return title }
        return "\(title). \(subtitle)"
    }
}
