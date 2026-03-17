//
//  CashFlowSetupView.swift
//  Yala
//
//  Setup view for creating a cash flow plan from suggested lines.
//

import SwiftUI
import SwiftData

struct CashFlowSetupView: View {

    // MARK: - Properties

    @Bindable var viewModel: CashFlowPlanViewModel
    let transactions: [TransactionItem]
    let scheduledPayments: [ScheduledPayment]
    let categories: [Category]
    let currencyCode: String

    @State private var startingBalance: String = ""

    @Environment(\.yalaTheme) private var theme

    // MARK: - Computed

    private var selectedIncome: Double {
        viewModel.suggestedLines
            .filter { $0.isSelected && $0.isIncome }
            .reduce(0) { $0 + $1.suggestedAmount }
    }

    private var selectedExpense: Double {
        viewModel.suggestedLines
            .filter { $0.isSelected && !$0.isIncome }
            .reduce(0) { $0 + $1.suggestedAmount }
    }

    private var netFlow: Double { selectedIncome - selectedExpense }

    private var incomeLines: [SuggestedLine] {
        viewModel.suggestedLines.filter(\.isIncome)
    }

    private var expenseLines: [SuggestedLine] {
        viewModel.suggestedLines.filter { !$0.isIncome }
    }

    private var recommendedExpenses: [SuggestedLine] {
        expenseLines.filter(\.isRecommended)
    }

    private var otherExpenses: [SuggestedLine] {
        expenseLines.filter { !$0.isRecommended }
    }

    // MARK: - Body

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: DS.Spacing.xl) {
                headerSection
                if viewModel.suggestedLines.isEmpty {
                    emptyState
                } else {
                    if !incomeLines.isEmpty {
                        lineSection(
                            title: L10n.CashFlowPlan.incomeSection,
                            lines: incomeLines,
                            isIncome: true
                        )
                    }
                    if !recommendedExpenses.isEmpty {
                        lineSection(
                            title: L10n.CashFlowPlan.expenseSection,
                            lines: recommendedExpenses,
                            isIncome: false
                        )
                    }
                    if !otherExpenses.isEmpty {
                        lineSection(
                            title: L10n.CashFlowPlan.otherExpensesLabel,
                            lines: otherExpenses,
                            isIncome: false
                        )
                    }
                    summarySection
                    startingBalanceSection
                    createButton
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.top, DS.Spacing.sm)
            .yalaSafeBottomPadding()
        }
        .onAppear {
            viewModel.generateSuggestions(
                transactions: transactions,
                scheduledPayments: scheduledPayments,
                categories: categories
            )
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: DS.Spacing.sm) {
            Text(L10n.CashFlowPlan.title)
                .font(DS.Typography.title2)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(L10n.CashFlowPlan.description)
                .font(DS.Typography.body)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        YalaEmptyState(
            icon: "arrow.left.arrow.right",
            title: L10n.CashFlowPlan.emptyState,
            message: L10n.CashFlowPlan.emptyStateMessage
        )
        .padding(.top, DS.Spacing.xxl)
    }

    // MARK: - Line Section

    private func lineSection(title: String, lines: [SuggestedLine], isIncome: Bool) -> some View {
        VStack(spacing: DS.Spacing.none) {
            Text(title.uppercased())
                .font(DS.Typography.label)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, DS.Spacing.sm)

            VStack(spacing: DS.Spacing.none) {
                ForEach(lines) { line in
                    suggestedLineRow(line)
                    if line.id != lines.last?.id {
                        Divider()
                            .padding(.leading, DS.Spacing.xxl)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
            .yalaCard(padding: 0)
        }
    }

    // MARK: - Line Row

    private func suggestedLineRow(_ line: SuggestedLine) -> some View {
        let index = viewModel.suggestedLines.firstIndex(where: { $0.id == line.id })

        return Button {
            if let index {
                viewModel.suggestedLines[index].isSelected.toggle()
            }
        } label: {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: line.isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(line.isSelected ? theme.accent : .secondary)
                    .font(DS.Typography.headline)

                if let cat = line.category, let iconName = cat.iconName {
                    Image(systemName: iconName)
                        .foregroundStyle(Color(hex: cat.colorHex) ?? .secondary)
                        .font(DS.Typography.body)
                        .frame(width: 24)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: DS.Spacing.sm) {
                        Text(line.name)
                            .font(DS.Typography.body)
                            .foregroundStyle(.primary)
                        if line.isRecommended {
                            Text(L10n.CashFlowPlan.recommendedBadge)
                                .font(DS.Typography.caption)
                                .foregroundStyle(theme.accent)
                                .padding(.horizontal, DS.Spacing.sm)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule().fill(theme.accent.opacity(0.15))
                                )
                        }
                    }
                    Text("\(line.monthsWithActivity) \(L10n.CashFlowPlan.monthsActive)")
                        .font(DS.Typography.caption)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                Text(YalaFormatter.currency(value: line.suggestedAmount, currencyCode: currencyCode))
                    .font(DS.Typography.body)
                    .foregroundStyle(line.isIncome ? DS.Semantic.successForeground : .primary)
                    .monospacedDigit()
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Summary

    private var summarySection: some View {
        VStack(spacing: DS.Spacing.sm) {
            summaryRow(label: L10n.CashFlow.income, amount: selectedIncome, color: DS.Semantic.successForeground)
            summaryRow(label: L10n.CashFlow.expense, amount: -selectedExpense, color: DS.Semantic.errorForeground)
            Divider()
            summaryRow(
                label: L10n.CashFlowPlan.available,
                amount: netFlow,
                color: netFlow >= 0 ? DS.Semantic.successForeground : DS.Semantic.errorForeground,
                isBold: true
            )
        }
        .padding(DS.Spacing.lg)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
        .yalaCard(padding: 0)
    }

    private func summaryRow(label: String, amount: Double, color: Color, isBold: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(isBold ? DS.Typography.headline : DS.Typography.body)
            Spacer()
            Text(YalaFormatter.currency(value: amount, currencyCode: currencyCode))
                .font(isBold ? DS.Typography.headline : DS.Typography.body)
                .foregroundStyle(color)
                .monospacedDigit()
        }
    }

    // MARK: - Starting Balance

    private var startingBalanceSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(L10n.CashFlowPlan.startingBalance)
                .font(DS.Typography.label)
                .foregroundStyle(.secondary)
            TextField("0", text: $startingBalance)
                .keyboardType(.decimalPad)
                .font(DS.Typography.headline)
                .monospacedDigit()
                .padding(DS.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                        .fill(.thCard)
                )
            Text(L10n.CashFlowPlan.startingBalanceHelper)
                .font(DS.Typography.caption)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Create Button

    private var createButton: some View {
        YalaPrimaryButton(
            L10n.CashFlowPlan.createButton,
            icon: "plus.circle.fill",
            isDisabled: viewModel.suggestedLines.filter(\.isSelected).isEmpty
        ) {
            let balance = Double(startingBalance.replacing(",", with: ".")) ?? 0
            viewModel.createPlan(startingBalance: balance)
        }
    }
}
