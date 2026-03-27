//
//  CashFlowTableView.swift
//  Yala
//
//  Main cash flow view: horizontal month strip + full-width month detail.
//  Strip shows capsules for each month; detail shows lines, progress, summary.
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

    // Tour
    @AppStorage("hasSeenCashFlowTableTour") private var hasSeenTour = false
    @State private var showTour = false
    @State private var tourIndex = 0
    @State private var scrollProxy: ScrollViewProxy?

    @Environment(\.yalaTheme) private var theme

    // MARK: - Body

    var body: some View {
        VStack(spacing: DS.Spacing.none) {
            if let projection = viewModel.projection {
                // Month strip
                CashFlowMonthStrip(
                    months: projection.months,
                    selectedMonthKey: $viewModel.selectedMonthKey
                )

                // Month detail with swipe
                TabView(selection: $viewModel.selectedMonthKey) {
                    ForEach(projection.months, id: \.monthKey) { month in
                        ScrollViewReader { proxy in
                            ScrollView(.vertical, showsIndicators: false) {
                                CashFlowMonthDetailView(
                                    month: month,
                                    viewModel: viewModel,
                                    currencyCode: currencyCode,
                                    transactions: transactions
                                )
                            }
                            .onAppear { scrollProxy = proxy }
                        }
                        .tag(month.monthKey)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .coachMarkOverlay(
            steps: CashFlowTableTourSteps.steps,
            isPresented: $showTour,
            currentIndex: $tourIndex,
            scrollProxy: scrollProxy
        ) {
            hasSeenTour = true
        }
        .onAppear {
            recalculate()
        }
        .task {
            do {
                try await Task.sleep(for: .seconds(0.5))
            } catch {
                return
            }
            if viewModel.projection != nil && !hasSeenTour {
                showTour = true
            }
        }
        .sheet(isPresented: $viewModel.showLineConfig, onDismiss: { recalculate() }) {
            if let line = viewModel.selectedLine {
                CashFlowLineConfigSheet(
                    viewModel: viewModel,
                    line: line,
                    currencyCode: currencyCode,
                    transactions: transactions
                )
            }
        }
        .sheet(isPresented: $viewModel.showOthersBreakdown, onDismiss: { recalculate() }) {
            CashFlowOthersSheet(
                viewModel: viewModel,
                currencyCode: currencyCode
            )
        }
        .sheet(isPresented: $viewModel.showAddLine, onDismiss: { recalculate() }) {
            CashFlowAddLineSheet(
                viewModel: viewModel,
                currencyCode: currencyCode,
                transactions: transactions
            )
        }
        .sheet(isPresented: $viewModel.showEditStartingBalance, onDismiss: { recalculate() }) {
            EditStartingBalanceSheet(viewModel: viewModel, currencyCode: currencyCode)
        }
    }

    // MARK: - Recalculate

    private func recalculate() {
        let expenseCategories = categories.filter { !$0.isIncome }
        viewModel.recalculate(
            transactions: transactions,
            allExpenseCategories: expenseCategories,
            scheduledPayments: scheduledPayments,
            currencyCode: currencyCode,
            converter: CurrencyConverter.shared
        )
    }
}

// MARK: - Edit Starting Balance Sheet

private struct EditStartingBalanceSheet: View {
    @Bindable var viewModel: CashFlowPlanViewModel
    let currencyCode: String
    @State private var balanceText: String = ""
    @State private var hasDate: Bool = false
    @State private var balanceDate: Date = Date.now
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: DS.Spacing.xl) {
                Text(L10n.CashFlowPlan.editStartingBalance)
                    .font(DS.Typography.headline)

                TextField("0", text: $balanceText)
                    .keyboardType(.decimalPad)
                    .font(DS.Typography.title)
                    .monospacedDigit()
                    .multilineTextAlignment(.center)
                    .padding(DS.Spacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                            .fill(.thCard)
                    )

                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    Toggle(L10n.CashFlowPlan.startingBalanceDateLabel, isOn: $hasDate)
                        .font(DS.Typography.label)

                    if hasDate {
                        DatePicker(
                            "",
                            selection: $balanceDate,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.compact)
                        .labelsHidden()
                    }

                    Text(L10n.CashFlowPlan.startingBalanceDateHelper)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(DS.Spacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                        .fill(.thCard)
                )

                YalaPrimaryButton(L10n.CashFlowPlan.editStartingBalanceSave, icon: "checkmark.circle.fill") {
                    let value = AmountInputHelper.parseDecimal(balanceText)
                    viewModel.updateStartingBalance(value, date: hasDate ? balanceDate : nil)
                    dismiss()
                }
            }
            .padding(DS.Spacing.xl)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear {
            balanceText = String(format: "%.0f", viewModel.plan?.startingBalance ?? 0)
            if let date = viewModel.plan?.startingBalanceDate {
                hasDate = true
                balanceDate = date
            }
        }
    }
}
