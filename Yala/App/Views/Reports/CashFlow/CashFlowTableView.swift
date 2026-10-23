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
    let accounts: [Account]
    let currencyCode: String

    // Tour
    @Environment(AppPreferences.self) private var appPreferences
    @State private var showTour = false
    @State private var tourIndex = 0
    @State private var scrollProxy: ScrollViewProxy?

    @Environment(\.yalaTheme) private var theme

    // MARK: - Body

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                if let projection = viewModel.projection {
                    VStack(spacing: DS.Spacing.none) {
                        // Month strip
                        CashFlowMonthStrip(
                            months: projection.months,
                            selectedMonthKey: $viewModel.selectedMonthKey,
                            currencyCode: currencyCode
                        )

                        // Month detail for selected month
                        if let month = projection.months.first(where: { $0.monthKey == viewModel.selectedMonthKey }) {
                            CashFlowMonthDetailView(
                                month: month,
                                viewModel: viewModel,
                                currencyCode: currencyCode,
                                transactions: transactions,
                                onCellDetailDismiss: { recalculate() }
                            )
                            // Deslizar cambia de mes sin quitarle el arrastre vertical al scroll. Un `DragGesture`
                            // aquí —con `.gesture` y también con `.simultaneousGesture`— dejaba la lista del mes sin
                            // desplazarse: solo se movía arrastrando desde la tira de meses (lote 18, medido).
                            .gesture(HorizontalSwipeGesture { towardsNext in
                                navigateMonth(in: projection.months, forward: towardsNext)
                            })
                            .accessibilityAdjustableAction { direction in
                                navigateMonth(in: projection.months, forward: direction == .increment)
                            }
                        }
                    }
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .scrollDisabled(showTour)
            .onAppear { scrollProxy = proxy }
        }
        .coachMarkOverlay(
            steps: CashFlowTableTourSteps.steps,
            isPresented: $showTour,
            currentIndex: $tourIndex,
            scrollProxy: scrollProxy
        ) {
            appPreferences.hasSeenCashFlowTableTour = true
        }
        .onAppear {
            recalculate()
        }
        .onChange(of: viewModel.planRevision) { _, _ in recalculate() }
        .task {
            do {
                try await Task.sleep(for: .seconds(0.5))
            } catch {
                return
            }
            // UX 2.2 · L18-6: la guía de 3 pasos solo sale justo después de crear el plan, una vez. Abrir un plan que ya
            // existía (o que llegó de otro teléfono) no la enseña.
            if viewModel.projection != nil && viewModel.planJustCreated && !appPreferences.hasSeenCashFlowTableTour {
                showTour = true
            }
            viewModel.planJustCreated = false
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
        .sheet(isPresented: $viewModel.showOthersIncomeBreakdown, onDismiss: { recalculate() }) {
            CashFlowOthersSheet(
                viewModel: viewModel,
                currencyCode: currencyCode,
                isIncome: true
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
            // UX 2.2 · L18-10: la misma hoja que «Cambiar el monto» de crear el plan, con la divisa y «Usar este monto».
            CashFlowStartingBalanceSheet(
                title: L10n.CashFlowPlan.editStartingBalance,
                initialAmount: viewModel.plan?.startingBalance ?? 0,
                initialDate: viewModel.plan?.startingBalanceDate,
                todayBalance: startingBalanceToday,
                currencyCode: currencyCode,
                showsDate: true
            ) { amount, date in
                viewModel.updateStartingBalance(amount, date: date)
            }
        }
    }

    /// Lo de hoy en las cuentas, para «Usar este monto». `nil` sin cuentas que sumen.
    private var startingBalanceToday: CashFlowSetupLogic.TodayBalance? {
        let balance = CashFlowSetupLogic.todayBalance(
            accounts: accounts, transactions: transactions, currencyCode: currencyCode,
            includeGroups: appPreferences.includeGroupsInPanelTotal
        )
        return balance.accountCount > 0 ? balance : nil
    }

    // MARK: - Navigation

    private func navigateMonth(in months: [CashFlowMonth], forward: Bool) {
        guard let idx = months.firstIndex(where: { $0.monthKey == viewModel.selectedMonthKey }) else { return }
        let next = forward ? idx + 1 : idx - 1
        guard months.indices.contains(next) else { return }
        withAnimation(.easeInOut(duration: DS.Animation.fast)) {
            viewModel.selectedMonthKey = months[next].monthKey
        }
    }

    // MARK: - Recalculate

    private func recalculate() {
        let expenseCategories = categories.filter { !$0.isIncome }
        let incomeCategories = categories.filter { $0.isIncome }
        viewModel.recalculate(
            transactions: transactions,
            allExpenseCategories: expenseCategories,
            allIncomeCategories: incomeCategories,
            scheduledPayments: scheduledPayments,
            currencyCode: currencyCode,
            converter: CurrencyConverter.shared
        )
    }
}
