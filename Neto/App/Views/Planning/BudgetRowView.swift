//
//  BudgetRowView.swift
//  Neto
//
//  Individual budget card component
//

import SwiftData
import SwiftUI

struct BudgetRowView: View {
    let summary: BudgetSummary
    let currencyCode: String
    let onTap: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Top row: Icon + Name + Amount
                HStack(spacing: 12) {
                    // Icon badge
                    budgetIcon

                    // Budget name
                    VStack(alignment: .leading, spacing: 2) {
                        Text(summary.budget.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        // Status info (% spent + days remaining)
                        statusInfo
                    }

                    Spacer()

                    // Amount (right-aligned)
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(formattedSpent)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(summary.status == .exceeded ? Color.hotPink : .primary)

                        Text(String(format: NSLocalizedString("budgets.amount.of", comment: ""), formattedLimit))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                // Progress bar
                BudgetProgressBar(
                    percentage: summary.percentage,
                    color: summary.color,
                    isExceeded: summary.status == .exceeded
                )
            }
            .padding(DS.Spacing.lg)
            .contentShape(Rectangle())
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .stroke(Color.white.opacity(DS.Card.borderOpacity), lineWidth: 1)
            )
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.25 : DS.Opacity.faint),
                radius: 6,
                x: 0,
                y: 3
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Components

    private var cardBackground: some View {
        Color.netoCard
    }

    private var budgetIcon: some View {
        ZStack {
            Circle()
                .fill(Color(hex: summary.color))
                .frame(width: 40, height: 40)

            Image(systemName: summary.icon)
                .font(.callout.weight(.medium))
                .foregroundStyle(.white)
        }
    }

    private var statusInfo: some View {
        let percentText = String(format: "%.1f%%", summary.percentage)
        let spentKey = NSLocalizedString("budgets.spent.percent", comment: "")
        let spentText = String(format: spentKey, percentText)

        let daysText: String
        if summary.daysRemaining == -1 {
            daysText = NSLocalizedString("budgets.period.past", comment: "")
        } else {
            let daysKey = NSLocalizedString("budgets.days.remaining", comment: "")
            daysText = String(format: daysKey, "\(summary.daysRemaining)")
        }

        return HStack(spacing: 4) {
            Text(spentText)
                .font(.caption2.weight(.medium))
                .foregroundStyle(summary.status == .exceeded ? Color.hotPink : .secondary)

            Text("•")
                .font(.caption2)
                .foregroundStyle(.secondary.opacity(0.5))

            Text(daysText)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Formatters

    private var formattedSpent: String {
        NetoFormatter.currency(value: summary.spent, currencyCode: currencyCode)
    }

    private var formattedLimit: String {
        NetoFormatter.currency(value: summary.budget.limitAmount, currencyCode: currencyCode)
    }
}
