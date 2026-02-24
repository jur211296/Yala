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
    let onTap: () -> Void

    @Environment(\.yalaTheme) private var theme

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                // Top row: Icon + Name + Amount
                HStack(spacing: DS.Spacing.md) {
                    // Icon badge
                    budgetIcon

                    // Budget name
                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                        Text(summary.budget.name)
                            .font(DS.Typography.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        // Status info (% spent + days remaining)
                        statusInfo
                    }

                    Spacer()

                    // Amount (right-aligned)
                    VStack(alignment: .trailing, spacing: DS.Spacing.xxs) {
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
                color: Color.black.opacity(theme.shadowOpacity),
                radius: 6,
                x: 0,
                y: 3
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L10n.Accessibility.budgetRow(summary.budget.name, Int(summary.percentage), formattedSpent, formattedLimit))
    }

    // MARK: - Components

    private var cardBackground: some View {
        theme.card
    }

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

        return HStack(spacing: DS.Spacing.xs) {
            Text(spentText)
                .font(DS.Typography.labelTiny)
                .foregroundStyle(summary.status == .exceeded ? Color.hotPink : .secondary)

            Text("•")
                .font(DS.Typography.captionSmall)
                .foregroundStyle(.secondary.opacity(0.5))

            Text(daysText)
                .font(DS.Typography.captionSmall)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Formatters

    private var formattedSpent: String {
        YalaFormatter.currency(value: summary.spent, currencyCode: currencyCode)
    }

    private var formattedLimit: String {
        YalaFormatter.currency(value: summary.budget.limitAmount, currencyCode: currencyCode)
    }
}
