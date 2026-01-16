//
//  BudgetWidgetRow.swift
//  Neto
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
                    .font(.subheadline)
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                // Name and Amount row
                HStack {
                    Text(summary.budget.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer()

                    Text(formattedSpent)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(summary.status == .exceeded ? Color.hotPink : .primary)
                }

                // Status info
                HStack(spacing: DS.Spacing.xs) {
                    Text(percentText)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(summary.status == .exceeded ? Color.hotPink : .secondary)

                    Text("•")
                        .font(.caption2)
                        .foregroundStyle(.secondary.opacity(0.5))

                    Text(daysText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(formattedLimit)
                        .font(.caption2)
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
        NetoFormatter.currency(value: summary.spent, currencyCode: currencyCode)
    }

    private var formattedLimit: String {
        String(format: NSLocalizedString("budgets.amount.of", comment: ""),
               NetoFormatter.currency(value: summary.budget.limitAmount, currencyCode: currencyCode))
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
