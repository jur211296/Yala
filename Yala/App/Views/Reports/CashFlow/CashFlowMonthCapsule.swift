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
    let currencyCode: String
    let showAccumulatedBalance: Bool

    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences

    var body: some View {
        VStack(spacing: DS.Spacing.xs) {
            // Month label (ABR 26)
            Text(month.date.formatted(.dateTime.month(.abbreviated).year(.twoDigits)))
                .font(DS.Typography.captionSmall)
                .fontWeight(isSelected ? .bold : .regular)
                .foregroundStyle(foregroundColor)
                .textCase(.uppercase)

            if showAccumulatedBalance {
                Text(accumulatedText)
                    .font(DS.Typography.labelSmall)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            miniBar

            let flow = netFlowInfo
            Text(flow.text)
                .font(DS.Typography.captionSmall)
                .foregroundStyle(flow.color)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(width: 78)
        .padding(.vertical, DS.Spacing.md)
        .padding(.horizontal, DS.Spacing.xxs)
        .glassEffect(isSelected ? .regular : .clear, in: .rect(cornerRadius: DS.Radius.lg))
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

    // MARK: - Computed Text

    private var accumulatedText: String {
        guard let balance = month.accumulatedBalance else { return "—" }
        if isSelected {
            let amount = YalaFormatter.amountCompactTable(value: balance)
            return "\(L10n.CashFlowPlan.accumulatedShort): \(amount)"
        }
        return appPreferences.amountCashFlowCell(balance, currencyCode: currencyCode)
    }

    private var netFlowInfo: (text: String, color: Color) {
        let isPositive = month.netFlow >= 0
        let sign = isPositive ? "+" : ""
        let text = sign + appPreferences.amountCashFlowCell(month.netFlow, currencyCode: currencyCode)
        let color: Color = isPositive ? .electricIndigo : .hotPink
        return (text, color)
    }

    // MARK: - Colors

    private var foregroundColor: Color {
        if isSelected { return theme.accent }
        if month.isCurrent { return .primary }
        return .secondary
    }
}
