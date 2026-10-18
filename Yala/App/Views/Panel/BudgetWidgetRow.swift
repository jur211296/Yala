//
//  BudgetWidgetRow.swift
//  Yala
//
//  Compact budget row for BudgetsWidget display
//

import SwiftUI

struct BudgetWidgetRow: View {
    let summary: BudgetSummary
    let currencyCode: String

    @Environment(AppPreferences.self) private var appPreferences

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            // Icon badge
            ZStack {
                Circle()
                    .fill(Color(hex: summary.color))
                    .frame(width: DS.Icon.badgeLarge, height: DS.Icon.badgeLarge)

                Image(systemName: summary.icon)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.white)
                    .accessibilityHidden(true)
            }

            // Lo que queda arriba a la derecha y lo gastado de su límite con el porcentaje debajo (UX 2.2 · L9-10, alineado
            // con la fila de Planificación, L9-1). Antes la cifra era lo gastado, sin «gastado» ni «de S/ 1,800».
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                HStack(alignment: .firstTextBaseline) {
                    Text(summary.budget.name)
                        .font(DS.Typography.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer(minLength: DS.Spacing.sm)

                    // En la divisa del presupuesto, que es en la que está lo gastado (antes, la del Panel).
                    Text(appPreferences.currency(abs(remaining), currencyCode: summary.budget.currencyCode))
                        .font(DS.Typography.headline)
                        .foregroundStyle(isOver ? Color.overBudgetText : Color.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }

                HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
                    BudgetSpentLine(
                        spent: summary.spent,
                        limit: summary.budget.limitAmount,
                        currencyCode: summary.budget.currencyCode,
                        suffix: percentText
                    )

                    Spacer(minLength: DS.Spacing.xs)

                    Text(isOver ? L10n.UXL9.overLabel : L10n.UXL9.remainingLabel)
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(isOver ? Color.overBudgetText : Color.secondary)
                        .lineLimit(1)
                        .fixedSize()
                }

                // Progress bar
                BudgetProgressBar(
                    percentage: summary.percentage,
                    color: summary.color,
                    isExceeded: summary.status == .exceeded,
                    simplified: true
                )
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var remaining: Double {
        BudgetRemainingLogic.remaining(limit: summary.budget.limitAmount, spent: summary.spent)
    }

    private var isOver: Bool {
        BudgetRemainingLogic.isOver(limit: summary.budget.limitAmount, spent: summary.spent)
    }

    // MARK: - Formatters

    private var percentText: String {
        String(format: "%.0f%%", summary.percentage)
    }
}
