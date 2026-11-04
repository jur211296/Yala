//
//  DailyAllowanceLine.swift
//  Yala
//
//  «Hoy puedes gastar S/ 42.30» (2.3, variante A): el cupo del día de un presupuesto, que baja con cada gasto de hoy
//  (`DailyAllowanceLogic`). Una sola vista para la fila del widget del Panel y el detalle del presupuesto. Sin cupo
//  que enseñar (período cerrado, presupuesto ya agotado) no pinta nada.
//

import SwiftUI

struct DailyAllowanceLine: View {
    let summary: BudgetSummary
    var font: Font = DS.Typography.captionSmall

    @Environment(AppPreferences.self) private var appPreferences

    /// Un presupuesto desactivado no tiene cupo: no cuenta para nada hasta que se reactive.
    private var state: DailyAllowanceLogic.State? {
        guard summary.status != .inactive else { return nil }
        return DailyAllowanceLogic.state(
            limit: summary.budget.limitAmount,
            spent: summary.spent,
            spentToday: summary.spentToday,
            daysRemaining: summary.daysRemaining
        )
    }

    var body: some View {
        if let state {
            let isOver = if case .overToday = state { true } else { false }
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: isOver ? "exclamationmark.circle.fill" : "sun.max.fill")
                    .foregroundStyle(isOver ? AnyShapeStyle(Color.overBudgetText) : AnyShapeStyle(ThemeColor.thAccentText))
                    .accessibilityHidden(true)
                Text(text(for: state))
                    .foregroundStyle(isOver ? Color.overBudgetText : Color.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .font(font)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("budget_daily_allowance")
        }
    }

    /// La cifra en negrita dentro de la frase: es lo que se lee de un vistazo.
    private func text(for state: DailyAllowanceLogic.State) -> AttributedString {
        let amount: Double
        let sentence: String
        switch state {
        case .available(let value):
            amount = value
            sentence = L10n.DailyAllowance.canSpendToday(appPreferences.currency(value, currencyCode: summary.budget.currencyCode))
        case .overToday(let value):
            amount = value
            sentence = L10n.DailyAllowance.overToday(appPreferences.currency(value, currencyCode: summary.budget.currencyCode))
        }
        var attributed = AttributedString(sentence)
        let amountText = appPreferences.currency(amount, currencyCode: summary.budget.currencyCode)
        if let range = attributed.range(of: amountText) {
            attributed[range].font = font.weight(.semibold)
            if case .available = state { attributed[range].foregroundColor = Color.primary }
        }
        return attributed
    }
}
