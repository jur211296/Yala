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

    @Environment(\.yalaTheme) private var theme

    var body: some View {
        VStack(spacing: DS.Spacing.none) {
            // Header
            headerCell

            // Income section header spacer
            Color.clear.frame(height: sectionHeaderHeight)

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
            }

            // Expense section header spacer
            Color.clear.frame(height: sectionHeaderHeight)

            if !expenseCollapsed {
                ForEach(month.expenseLines, id: \.lineID) { lineResult in
                    CashFlowCellView(
                        lineResult: lineResult,
                        month: month,
                        currencyCode: currencyCode,
                        width: columnWidth,
                        height: rowHeight
                    )
                    // Subcategory breakdown when expanded
                    if let subs = lineResult.subcategoryBreakdown {
                        ForEach(subs, id: \.subcategoryName) { sub in
                            subcategoryCell(sub)
                        }
                    }
                }

                // Other expenses
                if let other = month.otherExpenses {
                    otherExpensesCell(other)
                }
            }
        }
        .frame(width: columnWidth)
        .opacity(month.isPast ? 0.7 : 1.0)
    }

    // MARK: - Header

    private var headerCell: some View {
        VStack(spacing: 1) {
            Text(monthAbbreviation)
                .font(DS.Typography.labelSmall)
                .foregroundStyle(month.isCurrent ? theme.accent : .secondary)
                .fontWeight(month.isCurrent ? .bold : .regular)
            if showYear {
                Text(yearString)
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(height: rowHeight)
    }

    // MARK: - Subcategory Cell

    private func subcategoryCell(_ sub: SubcategoryLineResult) -> some View {
        let displayAmount = sub.realAmount ?? sub.plannedAmount
        return Text(YalaFormatter.currencyCompact(value: displayAmount, currencyCode: currencyCode))
            .font(DS.Typography.captionSmall)
            .foregroundStyle(.tertiary)
            .frame(width: columnWidth, height: rowHeight * 0.8)
    }

    // MARK: - Other Expenses Cell

    private func otherExpensesCell(_ other: CashFlowOtherResult) -> some View {
        let displayAmount = other.realAmount ?? other.plannedAmount
        return Text(YalaFormatter.currencyCompact(value: displayAmount, currencyCode: currencyCode))
            .font(DS.Typography.amountSmall)
            .foregroundStyle(.tertiary)
            .frame(width: columnWidth, height: rowHeight)
    }

    // MARK: - Helpers

    private let sectionHeaderHeight: CGFloat = 28

    private var monthAbbreviation: String {
        month.date.formatted(.dateTime.month(.abbreviated))
    }

    private var showYear: Bool {
        Calendar.current.component(.month, from: month.date) == 1
    }

    private var yearString: String {
        month.date.formatted(.dateTime.year(.twoDigits))
    }
}
