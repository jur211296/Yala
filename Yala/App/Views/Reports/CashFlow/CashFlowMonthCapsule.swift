//
//  CashFlowMonthCapsule.swift
//  Yala
//
//  Individual month capsule in the horizontal strip.
//  Shows month+year, accumulated balance, stacked income/expense bars, and net flow.
//

import SwiftUI

struct CashFlowMonthCapsule: View {
    let month: CashFlowMonth
    let isSelected: Bool

    @Environment(\.yalaTheme) private var theme

    var body: some View {
        VStack(spacing: DS.Spacing.xs) {
            // Month label (ABR 26)
            Text(month.date.formatted(.dateTime.month(.abbreviated).year(.twoDigits)))
                .font(DS.Typography.captionSmall)
                .fontWeight(isSelected ? .bold : .regular)
                .foregroundStyle(foregroundColor)
                .textCase(.uppercase)

            // Accumulated balance (main number)
            Text(YalaFormatter.amountCompactTable(value: month.accumulatedBalance))
                .font(DS.Typography.labelSmall)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .monospacedDigit()

            // Side-by-side bars (income | expense)
            miniBar

            // Net flow (+2,983)
            netFlowLabel
        }
        .frame(width: 78)
        .padding(.vertical, DS.Spacing.md)
        .padding(.horizontal, DS.Spacing.xxs)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .fill(isSelected ? theme.accent.opacity(0.1) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .strokeBorder(
                    isSelected ? theme.accent : Color.clear,
                    lineWidth: isSelected ? 2 : 0
                )
        )
        .opacity(month.isPast && !isSelected ? 0.6 : 1.0)
        .contentShape(Rectangle())
    }

    // MARK: - Mini Bar (side-by-side, proportional height)

    private var miniBar: some View {
        let maxVal = max(month.totalIncome, month.totalExpense, 1)
        let barMaxHeight: CGFloat = 18
        let incomeH = max(3, barMaxHeight * (month.totalIncome / maxVal))
        let expenseH = max(3, barMaxHeight * (month.totalExpense / maxVal))

        return HStack(alignment: .bottom, spacing: DS.Spacing.xxs) {
            RoundedRectangle(cornerRadius: DS.Spacing.xxs, style: .continuous)
                .fill(Color.electricIndigo)
                .frame(width: 8, height: incomeH)
            RoundedRectangle(cornerRadius: DS.Spacing.xxs, style: .continuous)
                .fill(Color.hotPink)
                .frame(width: 8, height: expenseH)
        }
        .frame(height: barMaxHeight)
    }

    // MARK: - Net Flow Label

    private var netFlowLabel: some View {
        let sign = month.netFlow >= 0 ? "+" : ""
        return Text(sign + YalaFormatter.amountCompactTable(value: month.netFlow))
            .font(DS.Typography.captionSmall)
            .foregroundStyle(.primary)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }

    // MARK: - Colors

    private var foregroundColor: Color {
        if isSelected { return theme.accent }
        if month.isCurrent { return .primary }
        return .secondary
    }
}
