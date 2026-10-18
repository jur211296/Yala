//
//  BudgetRowView.swift
//  Yala
//
//  Individual budget card component
//

import SwiftData
import SwiftUI

struct BudgetRowView: View {
    let summary: BudgetSummary
    let currencyCode: String

    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        NavigationLink(value: BudgetNavigationID(id: summary.budget.persistentModelID)) {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                // Top row: Icon + Name + Amount. A tamaños de accesibilidad el importe baja bajo el
                // nombre (`AdaptiveRowStack`): en fila se partía carácter a carácter («S/ 435. / 00»).
                AdaptiveRowStack(spacing: DS.Spacing.md, stackedSpacing: DS.Spacing.sm) {
                    // Icon badge
                    budgetIcon

                    // Budget name
                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                        HStack(spacing: DS.Spacing.xs) {
                            Text(summary.budget.name)
                                .font(DS.Typography.headline)
                                .foregroundStyle(.primary)
                                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)

                            if summary.budget.isFavorite {
                                Image(systemName: "star.fill")
                                    .font(DS.Typography.captionSmall)
                                    .foregroundStyle(DS.Semantic.favoriteIcon)
                                    .accessibilityHidden(true)
                            }
                        }

                        // Status info (% spent + days remaining)
                        statusInfo
                    }
                } trailing: {
                    // Lo que queda, o lo que te pasaste (UX 2.2 · L9-1): es lo que se viene a mirar. Lo gastado va en la
                    // línea gris de la izquierda; la fila no crece.
                    HStack(alignment: .lastTextBaseline, spacing: DS.Spacing.xxs) {
                        if BudgetRemainingLogic.isOver(limit: summary.budget.limitAmount, spent: summary.spent) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(DS.Typography.captionSmall)
                                .foregroundStyle(Color.overBudgetText)
                                .accessibilityHidden(true)
                        }
                        BudgetRemainingFigure(
                            limit: summary.budget.limitAmount,
                            spent: summary.spent,
                            currencyCode: currencyCode,
                            alignment: .trailingUnlessStacked(dynamicTypeSize)
                        )
                    }
                }

                // Progress bar
                BudgetProgressBar(
                    percentage: summary.percentage,
                    color: summary.color,
                    isExceeded: summary.status == .exceeded
                )

                // Sin filtros cuenta TODO lo gastado (UX 2.2 · L9-2): «Viajes» salió al 1522% sin que nada lo dijera.
                if summary.budget.countsAllExpenses {
                    BudgetCountsAllExpensesNote()
                }

                // Exceeded encouragement (brand voice: constructive, never scolding)
                if summary.status == .exceeded {
                    Text(NSLocalizedString("budgets.exceeded.encouragement", comment: ""))
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(DS.Spacing.lg)
            .contentShape(Rectangle())
            .solidCard(radius: DS.Radius.md)
        }
        .buttonStyle(.plain)
        .pointerHighlight(cornerRadius: DS.Radius.md)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L10n.Accessibility.budgetRow(summary.budget.name, Int(summary.percentage), formattedSpent, formattedLimit))
        .accessibilityIdentifier("budget_row_\(summary.budget.name)")
    }

    // MARK: - Components

    private var budgetIcon: some View {
        ZStack {
            Circle()
                .fill(Color(hex: summary.color))
                .frame(width: 40, height: 40)

            Image(systemName: summary.icon)
                .font(DS.Typography.label)
                .foregroundStyle(.white)
        }
    }

    /// «S/ 1,408.00 de S/ 1,800.00 · 18 días» (UX 2.2 · L9-1): sin porcentaje y en una línea. Un período cerrado dice
    /// «Cerrado».
    private var statusInfo: some View {
        BudgetSpentLine(
            spent: summary.spent,
            limit: summary.budget.limitAmount,
            currencyCode: currencyCode,
            suffix: L10n.UXL9.shortDays(summary.daysRemaining)
        )
    }

    // MARK: - Formatters

    private var formattedSpent: String {
        appPreferences.currency(summary.spent, currencyCode: currencyCode)
    }

    private var formattedLimit: String {
        appPreferences.currency(summary.budget.limitAmount, currencyCode: currencyCode)
    }
}
