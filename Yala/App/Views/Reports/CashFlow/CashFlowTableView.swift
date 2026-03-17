//
//  CashFlowTableView.swift
//  Yala
//
//  Main table view for cash flow plan with sticky name column and horizontal month scroll.
//

import SwiftUI
import SwiftData

struct CashFlowTableView: View {

    // MARK: - Properties

    @Bindable var viewModel: CashFlowPlanViewModel
    let transactions: [TransactionItem]
    let categories: [Category]
    let scheduledPayments: [ScheduledPayment]
    let currencyCode: String

    // MARK: - State

    @State private var incomeCollapsed = false
    @State private var expenseCollapsed = false

    @Environment(\.yalaTheme) private var theme

    // MARK: - Constants

    private let nameColumnWidth: CGFloat = 140
    private let monthColumnWidth: CGFloat = 90
    private let rowHeight: CGFloat = 40

    // MARK: - Body

    var body: some View {
        VStack(spacing: DS.Spacing.none) {
            if let projection = viewModel.projection {
                tableContent(projection)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let projection = viewModel.projection {
                CashFlowSummaryRow(
                    months: projection.months,
                    nameColumnWidth: nameColumnWidth,
                    monthColumnWidth: monthColumnWidth,
                    currencyCode: currencyCode
                )
            }
        }
        .onAppear {
            recalculate()
        }
    }

    // MARK: - Table Content

    private func tableContent(_ projection: CashFlowProjection) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            HStack(alignment: .top, spacing: DS.Spacing.none) {
                // Sticky name column
                nameColumn(projection)
                    .frame(width: nameColumnWidth)

                // Scrollable month columns
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DS.Spacing.none) {
                        ForEach(projection.months, id: \.monthKey) { month in
                            CashFlowMonthColumn(
                                month: month,
                                incomeCollapsed: incomeCollapsed,
                                expenseCollapsed: expenseCollapsed,
                                currencyCode: currencyCode,
                                columnWidth: monthColumnWidth,
                                rowHeight: rowHeight
                            )
                        }
                    }
                }
            }
            .yalaSafeBottomPadding()
        }
    }

    // MARK: - Name Column

    private func nameColumn(_ projection: CashFlowProjection) -> some View {
        VStack(spacing: DS.Spacing.none) {
            // Header spacer (aligns with month headers)
            Color.clear.frame(height: rowHeight)

            // Income section
            CashFlowHeaderRow(
                title: L10n.CashFlowPlan.incomeSection,
                isCollapsed: $incomeCollapsed
            )
            .frame(height: 28)

            if !incomeCollapsed {
                let incomeLines = projection.months.first?.incomeLines ?? []
                ForEach(incomeLines, id: \.lineID) { lineResult in
                    let line = viewModel.plan?.lines?.first { $0.id == lineResult.lineID }
                    CashFlowLineNameRow(
                        lineResult: lineResult,
                        line: line,
                        isOtherExpenses: false,
                        height: rowHeight
                    )
                    .onTapGesture {
                        if let line {
                            viewModel.selectedLine = line
                            viewModel.showLineConfig = true
                        }
                    }
                }
            }

            // Expense section
            CashFlowHeaderRow(
                title: L10n.CashFlowPlan.expenseSection,
                isCollapsed: $expenseCollapsed
            )
            .frame(height: 28)

            if !expenseCollapsed {
                let expenseLines = projection.months.first?.expenseLines ?? []
                ForEach(expenseLines, id: \.lineID) { lineResult in
                    let line = viewModel.plan?.lines?.first { $0.id == lineResult.lineID }
                    CashFlowLineNameRow(
                        lineResult: lineResult,
                        line: line,
                        isOtherExpenses: false,
                        height: rowHeight
                    )
                    .onTapGesture {
                        if let line {
                            viewModel.selectedLine = line
                            viewModel.showLineConfig = true
                        }
                    }
                }

                // Add line button
                Button {
                    viewModel.showAddLine = true
                } label: {
                    HStack(spacing: DS.Spacing.sm) {
                        Image(systemName: "plus.circle")
                            .font(DS.Typography.caption)
                        Text(L10n.CashFlowPlan.addLine)
                            .font(DS.Typography.caption)
                    }
                    .foregroundStyle(theme.accent)
                    .padding(.horizontal, DS.Spacing.md)
                    .frame(height: rowHeight)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                // Other expenses
                if let other = projection.months.first?.otherExpenses {
                    Divider()
                        .padding(.horizontal, DS.Spacing.md)
                        .dashPattern()

                    Button {
                        viewModel.showOthersBreakdown = true
                    } label: {
                        HStack(spacing: DS.Spacing.sm) {
                            Image(systemName: "ellipsis.circle")
                                .font(DS.Typography.caption)
                                .foregroundStyle(.tertiary)
                                .frame(width: 20)
                            Text(L10n.CashFlowPlan.otherExpensesLabel)
                                .font(DS.Typography.caption)
                                .foregroundStyle(.secondary)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, DS.Spacing.md)
                        .frame(height: rowHeight)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Recalculate

    private func recalculate() {
        let expenseCategories = categories.filter { !$0.isIncome }
        viewModel.recalculate(
            transactions: transactions,
            allExpenseCategories: expenseCategories,
            scheduledPayments: scheduledPayments,
            currencyCode: currencyCode
        )
    }
}

// MARK: - Dash Pattern Extension

private extension View {
    func dashPattern() -> some View {
        self.overlay(
            GeometryReader { geo in
                Path { path in
                    path.move(to: CGPoint(x: 0, y: geo.size.height / 2))
                    path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height / 2))
                }
                .stroke(style: StrokeStyle(lineWidth: 0.5, dash: [4, 3]))
                .foregroundStyle(.quaternary)
            }
        )
    }
}
