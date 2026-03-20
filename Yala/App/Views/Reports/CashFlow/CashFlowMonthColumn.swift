//
//  CashFlowMonthColumn.swift
//  Yala
//
//  A single month column in the cash flow table.
//

import SwiftUI

struct CashFlowMonthColumn: View {
    let month: CashFlowMonth
    let incomeCollapsed: Bool
    let expenseCollapsed: Bool
    let currencyCode: String
    let columnWidth: CGFloat
    let rowHeight: CGFloat
    let hasOtherExpenses: Bool
    var compactMode: Bool = false

    @Environment(\.yalaTheme) private var theme

    var body: some View {
        VStack(spacing: DS.Spacing.none) {
            // Header
            headerCell

            // Income section header — total in header row
            sectionTotalCell(value: month.totalIncome, isIncome: true)

            if !incomeCollapsed {
                ForEach(month.incomeLines, id: \.lineID) { lineResult in
                    CashFlowCellView(
                        lineResult: lineResult,
                        month: month,
                        currencyCode: currencyCode,
                        width: columnWidth,
                        height: rowHeight
                    )
                }
                // Spacer for add-income button
                Color.clear.frame(height: rowHeight)
            }

            // Expense section header — total in header row
            sectionTotalCell(value: month.totalExpense, isIncome: false)

            if !expenseCollapsed {
                ForEach(month.expenseLines, id: \.lineID) { lineResult in
                    CashFlowCellView(
                        lineResult: lineResult,
                        month: month,
                        currencyCode: currencyCode,
                        width: columnWidth,
                        height: rowHeight
                    )
                    // Subcategory breakdown
                    if !compactMode, let subs = lineResult.subcategoryBreakdown {
                        ForEach(subs, id: \.subcategoryName) { sub in
                            subcategoryCell(sub)
                        }
                    }
                }
                // Spacer for add-expense button
                Color.clear.frame(height: rowHeight)

                // Other expenses
                if hasOtherExpenses {
                    Color.clear.frame(height: 1)
                    if let other = month.otherExpenses {
                        otherExpensesCell(other)
                    } else {
                        Color.clear.frame(height: rowHeight)
                    }
                }
            }

            // Summary
            Divider()
            summaryCell(value: month.netFlow, isPositive: month.netFlow >= 0)
            summaryCell(value: month.accumulatedBalance, isPositive: month.accumulatedBalance >= 0)
        }
        .frame(width: columnWidth)
        .opacity(month.isPast ? 0.7 : 1.0)
    }

    // MARK: - Header

    private var headerCell: some View {
        Text(month.date.formatted(.dateTime.month(.abbreviated).year(.twoDigits)))
            .font(DS.Typography.labelSmall)
            .foregroundStyle(month.isCurrent ? theme.accent : .secondary)
            .fontWeight(month.isCurrent ? .bold : .regular)
            .frame(height: rowHeight)
    }

    // MARK: - Section Total Cell

    private func sectionTotalCell(value: Double, isIncome: Bool) -> some View {
        Text(YalaFormatter.amountCashFlowCell(value: value, currencyCode: currencyCode))
            .font(DS.Typography.labelSmall)
            .fontWeight(.bold)
            .foregroundStyle(isIncome ? Color.electricIndigo : Color.hotPink)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(width: columnWidth, height: rowHeight)
    }

    // MARK: - Summary Cell

    private func summaryCell(value: Double, isPositive: Bool) -> some View {
        Text(YalaFormatter.amountCashFlowCell(value: value, currencyCode: currencyCode))
            .font(DS.Typography.labelSmall)
            .fontWeight(.semibold)
            .foregroundStyle(isPositive ? Color.electricIndigo : Color.hotPink)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(width: columnWidth, height: summaryRowHeight)
    }

    // MARK: - Subcategory Cell

    private func subcategoryCell(_ sub: SubcategoryLineResult) -> some View {
        let displayAmount = sub.realAmount ?? sub.plannedAmount
        return Text(YalaFormatter.amountCashFlowCell(value: displayAmount, currencyCode: currencyCode))
            .font(DS.Typography.captionSmall)
            .foregroundStyle(.tertiary)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(width: columnWidth, height: rowHeight)
    }

    // MARK: - Other Expenses Cell

    private func otherExpensesCell(_ other: CashFlowOtherResult) -> some View {
        let displayAmount = other.realAmount ?? other.plannedAmount
        return Text(YalaFormatter.amountCashFlowCell(value: displayAmount, currencyCode: currencyCode))
            .font(DS.Typography.caption)
            .foregroundStyle(.tertiary)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(width: columnWidth, height: rowHeight)
    }

    // MARK: - Constants

    private let summaryRowHeight: CGFloat = 36
}
