//
//  CashFlowMonthDetailView.swift
//  Yala
//
//  Full-width detail view for the selected month in cash flow.
//  Shows income/expense sections with lines, other expenses, and summary.
//

import SwiftUI

struct CashFlowMonthDetailView: View {
    let month: CashFlowMonth
    @Bindable var viewModel: CashFlowPlanViewModel
    let currencyCode: String
    let transactions: [TransactionItem]
    var onCellDetailDismiss: (() -> Void)?

    @State private var incomeCollapsed = false
    @State private var expenseCollapsed = false
    @State private var selectedCellLineID: UUID?

    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            // Transition bar
            transitionBar

            // Income section
            incomeSection
                .panelCard()

            // Expense section
            expenseSection
                .panelCard()

            // Summary card
            summaryCard
                .panelCard()
                .coachMarkAnchor("cfTableAvailable")
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.bottom, DS.Spacing.lg)
        .sheet(isPresented: Binding(
            get: { selectedCellLineID != nil },
            set: { if !$0 { selectedCellLineID = nil } }
        ), onDismiss: onCellDetailDismiss) {
            if let lineID = selectedCellLineID,
               let lineResult = allLines.first(where: { $0.lineID == lineID }) {
                CashFlowCellDetailSheet(
                    lineResult: lineResult,
                    line: viewModel.line(for: lineID),
                    month: month,
                    currencyCode: currencyCode,
                    transactions: transactions,
                    viewModel: viewModel
                )
            }
        }
    }

    // MARK: - Transition Bar

    private var transitionBar: some View {
        HStack(spacing: DS.Spacing.sm) {
            Text(month.date.formatted(.dateTime.month(.wide).year()))
                .font(DS.Typography.headline)
                .foregroundStyle(.primary)

            if month.isCurrent {
                Text(L10n.CashFlowPlan.thisMonth)
                    .font(DS.Typography.captionSmall)
                    .fontWeight(.semibold)
                    .foregroundStyle(theme.accent)
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, DS.Spacing.xxs)
                    .background(
                        Capsule()
                            .fill(theme.accent.opacity(0.12))
                    )
            } else if month.isPast {
                Text(L10n.CashFlowPlan.pastMonth)
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(.tertiary)
            } else {
                Text(L10n.CashFlowPlan.futureMonth)
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            // Execution % for current month
            if month.isCurrent {
                let totalPlanned = month.expenseLines.reduce(0.0) { $0 + $1.plannedAmount }
                let totalReal = month.expenseLines.reduce(0.0) { $0 + ($1.realAmount ?? 0) }
                if totalPlanned > 0 {
                    let percent = Int((totalReal / totalPlanned) * 100)
                    Text(L10n.CashFlowPlan.executionPercent(percent))
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, DS.Spacing.xs)
    }

    // MARK: - Income Section

    private var incomeSection: some View {
        VStack(spacing: DS.Spacing.none) {
            sectionHeader(
                title: L10n.CashFlowPlan.incomeSection,
                total: month.totalIncome,
                isIncome: true,
                isCollapsed: $incomeCollapsed
            )

            if !incomeCollapsed {
                Divider().padding(.horizontal, DS.Spacing.lg)
                lineRows(for: month.incomeLines)
                addLineButton(isIncome: true)

                uncategorizedRow(
                    result: month.otherIncome,
                    label: L10n.CashFlowPlan.otherIncomeLabel,
                    action: { viewModel.showOthersIncomeBreakdown = true }
                )
            }
        }
    }

    // MARK: - Expense Section

    private var expenseSection: some View {
        VStack(spacing: DS.Spacing.none) {
            sectionHeader(
                title: L10n.CashFlowPlan.expenseSection,
                total: month.totalExpense,
                isIncome: false,
                isCollapsed: $expenseCollapsed
            )
            .coachMarkAnchor("cfTableCell")

            if !expenseCollapsed {
                Divider().padding(.horizontal, DS.Spacing.lg)
                lineRows(for: month.expenseLines)

                addLineButton(isIncome: false)
                    .coachMarkAnchor("cfTableAdd")

                uncategorizedRow(
                    result: month.otherExpenses,
                    label: L10n.CashFlowPlan.otherExpensesLabel,
                    action: { viewModel.showOthersBreakdown = true }
                )
            }
        }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        VStack(spacing: DS.Spacing.sm) {
            // Available (net flow)
            HStack {
                HStack(spacing: DS.Spacing.xs) {
                    Text(L10n.CashFlowPlan.available)
                        .font(DS.Typography.label)
                        .foregroundStyle(.secondary)
                    InfoHintButton(
                        title: L10n.CashFlowPlan.availableHintTitle,
                        message: L10n.CashFlowPlan.availableHintMessage
                    )
                }
                Spacer()
                Text(appPreferences.currency(month.netFlow, currencyCode: currencyCode))
                    .font(DS.Typography.amount)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                    .monospacedDigit()
            }

            if viewModel.plan?.showAccumulatedBalance ?? true {
                Divider()

                // Accumulated
                HStack {
                    HStack(spacing: DS.Spacing.xs) {
                        Text(L10n.CashFlowPlan.accumulated)
                            .font(DS.Typography.label)
                            .foregroundStyle(.secondary)
                        InfoHintButton(
                            title: L10n.CashFlowPlan.accumulatedHintTitle,
                            message: L10n.CashFlowPlan.accumulatedHintMessage
                        )
                        Spacer()
                        Button {
                            viewModel.showEditStartingBalance = true
                        } label: {
                            Image(systemName: "pencil.circle")
                                .font(DS.Typography.label)
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                    if let balance = month.accumulatedBalance {
                        Text(appPreferences.currency(balance, currencyCode: currencyCode))
                            .font(DS.Typography.amount)
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)
                            .monospacedDigit()
                    } else {
                        Text("—")
                            .font(DS.Typography.amount)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding(DS.Spacing.lg)
    }

    // MARK: - Line Rows

    @ViewBuilder
    private func lineRows(for lines: [CashFlowLineResult]) -> some View {
        ForEach(lines, id: \.lineID) { lineResult in
            let line = viewModel.line(for: lineResult.lineID)
            CashFlowDetailLineRow(
                lineResult: lineResult,
                line: line,
                month: month,
                currencyCode: currencyCode,
                onTapLine: {
                    selectedCellLineID = lineResult.lineID
                },
                onDeleteLine: line.map { l in
                    { viewModel.removeLine(l) }
                }
            )
        }
    }

    // MARK: - Uncategorized Row

    @ViewBuilder
    private func uncategorizedRow(result: CashFlowOtherResult?, label: String, action: @escaping () -> Void) -> some View {
        if let result, result.plannedAmount > 0 {
            Divider()
                .padding(.horizontal, DS.Spacing.lg)
                .dashPattern()

            Button(action: action) {
                HStack(spacing: DS.Spacing.md) {
                    Image(systemName: "ellipsis.circle")
                        .font(DS.Typography.caption)
                        .foregroundStyle(.tertiary)
                    Text(label)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    let displayAmount = result.realAmount ?? result.plannedAmount
                    Text(appPreferences.currency(displayAmount, currencyCode: currencyCode))
                        .font(DS.Typography.amountSmall)
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.md)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Section Header

    private func sectionHeader(title: String, total: Double, isIncome: Bool, isCollapsed: Binding<Bool>) -> some View {
        Button {
            withAnimation(.easeInOut(duration: DS.Animation.fast)) {
                isCollapsed.wrappedValue.toggle()
            }
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: isIncome ? "arrow.up.right" : "arrow.down.right")
                    .font(DS.Typography.caption)
                    .foregroundStyle(isIncome ? Color.electricIndigo : Color.hotPink)

                Text(title)
                    .font(DS.Typography.label)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                Image(systemName: "chevron.down")
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(isCollapsed.wrappedValue ? -90 : 0))

                Spacer()

                Text(appPreferences.currency(total, currencyCode: currencyCode))
                    .font(DS.Typography.amountSmall)
                    .fontWeight(.bold)
                    .foregroundStyle(isIncome ? Color.electricIndigo : Color.hotPink)
                    .monospacedDigit()
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Add Line Button

    private var allLines: [CashFlowLineResult] {
        month.incomeLines + month.expenseLines
    }

    private func addLineButton(isIncome: Bool) -> some View {
        Button {
            viewModel.addLineIsIncome = isIncome
            viewModel.showAddLine = true
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "plus.circle")
                    .font(DS.Typography.caption)
                Text(L10n.CashFlowPlan.addLine)
                    .font(DS.Typography.caption)
            }
            .foregroundStyle(theme.accent)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
