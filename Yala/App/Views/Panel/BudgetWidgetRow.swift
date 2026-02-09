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
            }

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                // Name and Amount row
                HStack {
                    Text(summary.budget.name)
                        .font(DS.Typography.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer()

                    Text(formattedSpent)
                        .font(DS.Typography.headline)
                        .foregroundStyle(summary.status == .exceeded ? Color.hotPink : .primary)
                }

                // Status info
                HStack(spacing: DS.Spacing.xs) {
                    Text(percentText)
                        .font(DS.Typography.labelTiny)
                        .foregroundStyle(summary.status == .exceeded ? Color.hotPink : .secondary)

                    Text("•")
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.secondary.opacity(0.5))

                    Text(daysText)
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(formattedLimit)
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.secondary)
                }

                // Progress bar
                BudgetProgressBar(
                    percentage: summary.percentage,
                    color: summary.color,
                    isExceeded: summary.status == .exceeded
                )
            }
        }
    }

    // MARK: - Formatters

    private var formattedSpent: String {
        YalaFormatter.currency(value: summary.spent, currencyCode: currencyCode)
    }

    private var formattedLimit: String {
        String(format: NSLocalizedString("budgets.amount.of", comment: ""),
               YalaFormatter.currency(value: summary.budget.limitAmount, currencyCode: currencyCode))
    }

    private var percentText: String {
        let key = NSLocalizedString("budgets.spent.percent", comment: "")
        return String(format: key, String(format: "%.0f%%", summary.percentage))
    }

    private var daysText: String {
        if summary.daysRemaining == -1 {
            return NSLocalizedString("budgets.period.past", comment: "")
        } else {
            let key = NSLocalizedString("budgets.days.remaining", comment: "")
            return String(format: key, "\(summary.daysRemaining)")
        }
    }
}
