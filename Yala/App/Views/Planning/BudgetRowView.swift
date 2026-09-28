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
                    // Amount (right-aligned)
                    VStack(alignment: .trailingUnlessStacked(dynamicTypeSize), spacing: DS.Spacing.xxs) {
                        HStack(spacing: DS.Spacing.xxs) {
                            if summary.status == .exceeded {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(DS.Typography.captionSmall)
                                    .foregroundStyle(Color.hotPink)
                                    .accessibilityHidden(true)
                            }
                            Text(formattedSpent)
                                .font(DS.Typography.headline)
                                .foregroundStyle(summary.status == .exceeded ? Color.hotPink : .primary)
                        }

                        Text(String(format: NSLocalizedString("budgets.amount.of", comment: ""), formattedLimit))
                            .font(DS.Typography.captionSmall)
                            .foregroundStyle(.secondary)
                    }
                }

                // Progress bar
                BudgetProgressBar(
                    percentage: summary.percentage,
                    color: summary.color,
                    isExceeded: summary.status == .exceeded
                )

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

    private var statusInfo: some View {
        let percentText = String(format: "%.0f%%", summary.percentage)
        let spentKey = NSLocalizedString("budgets.spent.percent", comment: "")
        let spentText = String(format: spentKey, percentText)

        let daysText: String
        if summary.daysRemaining == -1 {
            daysText = NSLocalizedString("budgets.period.past", comment: "")
        } else {
            let daysKey = NSLocalizedString("budgets.days.remaining", comment: "")
            daysText = String(format: daysKey, "\(summary.daysRemaining)")
        }

        // A tamaños de accesibilidad las dos cifras van una bajo otra, sin el separador: en fila se
        // partían sílaba a sílaba.
        return AdaptiveRowStack(spacing: DS.Spacing.xs, stackedSpacing: DS.Spacing.xxs) {
            Text(spentText)
                .font(DS.Typography.labelTiny)
                .foregroundStyle(summary.status == .exceeded ? Color.hotPink : .secondary)

            if !dynamicTypeSize.isAccessibilitySize {
                Text("•")
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(.secondary.opacity(0.5))
            }

            Text(daysText)
                .font(DS.Typography.captionSmall)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Formatters

    private var formattedSpent: String {
        appPreferences.currency(summary.spent, currencyCode: currencyCode)
    }

    private var formattedLimit: String {
        appPreferences.currency(summary.budget.limitAmount, currencyCode: currencyCode)
    }
}
