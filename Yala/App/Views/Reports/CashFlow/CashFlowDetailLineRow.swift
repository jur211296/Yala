//
//  CashFlowDetailLineRow.swift
//  Yala
//
//  A single line row in the month detail view.
//  Shows icon, name, planned/real amount, and progress bar for current month.
//  Tap → line config sheet. Context menu → delete line.
//

import SwiftUI

struct CashFlowDetailLineRow: View {
    let lineResult: CashFlowLineResult
    let line: CashFlowLine?
    let month: CashFlowMonth
    let currencyCode: String
    let onTapLine: () -> Void
    let onDeleteLine: (() -> Void)?

    @Environment(\.yalaTheme) private var theme

    var body: some View {
        Button {
            onTapLine()
        } label: {
            HStack(spacing: DS.Spacing.md) {
                // Category icon
                categoryIcon

                // Name + method hint
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(lineResult.name)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if !month.isCurrent && !month.isPast {
                        Text(lineResult.estimationMethod.displayName)
                            .font(DS.Typography.captionSmall)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer(minLength: 0)

                // Amount column
                amountColumn
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            if let onDeleteLine {
                Button(role: .destructive) {
                    onDeleteLine()
                } label: {
                    Label(L10n.CashFlowPlan.deleteLineConfirmation, systemImage: "trash")
                }
            }
        }
    }

    // MARK: - Category Icon

    private var categoryIcon: some View {
        let iconName = line?.subcategory?.iconName ?? line?.category?.iconName
        let colorHex = line?.subcategory?.colorHex ?? line?.category?.colorHex

        return Group {
            if let iconName, let colorHex {
                ZStack {
                    Circle()
                        .fill(Color(hex: colorHex))
                        .frame(width: DS.Icon.badgeMedium, height: DS.Icon.badgeMedium)
                    Image(systemName: iconName)
                        .font(DS.Typography.iconMedium)
                        .foregroundStyle(.white)
                }
            } else {
                ZStack {
                    Circle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: DS.Icon.badgeMedium, height: DS.Icon.badgeMedium)
                    Image(systemName: "questionmark")
                        .font(DS.Typography.iconMedium)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Amount Column

    private var amountColumn: some View {
        VStack(alignment: .trailing, spacing: DS.Spacing.xxs) {
            // Display amount
            Text(YalaFormatter.currency(value: displayAmount, currencyCode: currencyCode))
                .font(DS.Typography.amountSmall)
                .fontWeight(.semibold)
                .foregroundStyle(amountColor)
                .monospacedDigit()

            // Progress bar for current month
            if month.isCurrent, let progress = lineResult.progress {
                HStack(spacing: DS.Spacing.xs) {
                    progressBar(progress: progress)
                        .frame(width: 60)
                    Text("\(Int(min(progress, 9.99) * 100))%")
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }
            }

            // Plan label for past months with real data
            if month.isPast, let real = lineResult.realAmount {
                let diff = real - lineResult.plannedAmount
                let isGood = lineResult.isIncome ? diff >= 0 : diff <= 0
                HStack(spacing: DS.Spacing.xxs) {
                    Image(systemName: isGood ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(isGood ? Color.electricIndigo : Color.hotPink)
                    Text(L10n.CashFlowPlan.plan + ": " + YalaFormatter.amountCompactTable(value: lineResult.plannedAmount))
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    // MARK: - Display Amount

    private var displayAmount: Double {
        if let real = lineResult.realAmount, (month.isPast || month.isCurrent) {
            return real
        }
        return lineResult.plannedAmount
    }

    private var amountColor: Color {
        if lineResult.isOverride { return .primary }
        if month.isPast, let diff = lineResult.difference {
            if abs(diff) > lineResult.plannedAmount * 0.1 {
                if lineResult.isIncome {
                    return diff >= 0 ? Color.electricIndigo : Color.hotPink
                }
                return diff > 0 ? Color.hotPink : Color.electricIndigo
            }
        }
        return .primary
    }

    // MARK: - Progress Bar

    private func progressBar(progress: Double) -> some View {
        let clamped = min(1.0, max(0, progress))
        return ZStack(alignment: .leading) {
            Capsule()
                .fill(DS.Semantic.neutralBackground)
                .frame(height: 4)
            Capsule()
                .fill(progress > 1.0 ? Color.hotPink : theme.accent)
                .frame(maxWidth: .infinity, maxHeight: 4)
                .scaleEffect(x: max(0.05, clamped), anchor: .leading)
        }
        .frame(height: 4)
    }
}
