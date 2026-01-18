//
//  BudgetsListView.swift
//  Neto
//
//  Main view for budget management with period filtering and status grouping
//

import SwiftData
import SwiftUI

struct BudgetsListView: View {
    @Environment(\.modelContext) private var modelContext

    // Data Queries
    @Query(sort: \Budget.createdAt, order: .reverse)
    private var allBudgets: [Budget]

    @Query(sort: \TransactionItem.date, order: .reverse)
    private var allTransactions: [TransactionItem]

    @Query(sort: \Account.name)
    private var accounts: [Account]

    @AppStorage("defaultCurrencyCode") private var defaultCurrencyCode: String = CurrencyCode.pen
        .rawValue

    // ViewModel
    @State private var viewModel = BudgetsViewModel()
    @State private var selectedSegment: Int = 1  // 0=Weekly, 1=Monthly, 2=Yearly, 3=Unique
    @State private var showPeriodSelector = false
    @AppStorage("budgets.hideInactive") private var hideInactive: Bool = false

    var body: some View {
        ZStack {
            PanelBackgroundView()

            ScrollView {
                VStack(spacing: 0) {
                    controlsBar

                    listContent
                }
            }

            // FAB button for new budget
            newBudgetFAB
        }
        .sheet(isPresented: $viewModel.showBudgetEditor) {
            if let budget = viewModel.editingBudget {
                BudgetEditorView(budget: budget)
                    .onDisappear {
                        viewModel.editingBudget = nil
                        refreshData()
                    }
            } else {
                BudgetEditorView(budget: nil)
                    .onDisappear {
                        refreshData()
                    }
            }
        }
        .sheet(isPresented: $showPeriodSelector) {
            BudgetPeriodSelectorSheet(
                viewModel: viewModel,
                transactions: allTransactions,
                onPeriodChange: { refreshData() }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            refreshData()
        }
    }

    // MARK: - Controls Bar

    private var controlsBar: some View {
        VStack(spacing: 0) {
            // Period type segmented control
            periodTypeSegmentedControl
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.md)
                .padding(.bottom, DS.Spacing.sm)

            // Period selector button and hide inactive toggle (hidden for "Unique" mode)
            if selectedSegment != 3 {
                HStack(spacing: DS.Spacing.md) {
                    periodSelectorButton

                    Spacer()

                    hideInactiveButton
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.md)
            } else {
                // For unique mode, only show the hide inactive button
                HStack {
                    Spacer()
                    hideInactiveButton
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.md)
            }
        }
    }

    // MARK: - List Content

    @ViewBuilder
    private var listContent: some View {
        if viewModel.groupedBudgets.isEmpty {
            emptyState
        } else {
            budgetsList
        }
    }

    // MARK: - Period Type Segmented Control

    private var periodTypeSegmentedControl: some View {
        Picker("Period Type", selection: $selectedSegment) {
            Text(NSLocalizedString("budgets.period.weekly", comment: "")).tag(0)
            Text(NSLocalizedString("budgets.period.monthly", comment: "")).tag(1)
            Text(NSLocalizedString("budgets.period.yearly", comment: "")).tag(2)
            Text(NSLocalizedString("budgets.period.unique", comment: "")).tag(3)
        }
        .pickerStyle(.segmented)
        .onChange(of: selectedSegment) { _, newValue in
            switch newValue {
            case 0:
                viewModel.selectedPeriodType = .weekly
            case 1:
                viewModel.selectedPeriodType = .monthly
            case 2:
                viewModel.selectedPeriodType = .yearly
            case 3:
                viewModel.selectedPeriodType = .unique
            default:
                break
            }
            refreshData()
        }
    }

    // MARK: - Period Selector Button

    private var periodSelectorButton: some View {
        Button {
            showPeriodSelector = true
        } label: {
            HStack(spacing: DS.Spacing.xs) {
                Text(currentPeriodText)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
        }
        .buttonStyle(.plain)
    }

    private var currentPeriodText: String {
        let calendar = Calendar.current
        let dateFormatter = DateFormatter()

        switch viewModel.selectedPeriodType {
        case .weekly:
            let currentWeek = calendar.startOfWeek(for: Date())
            let selectedWeek = viewModel.selectedWeek

            // Check if it's current, previous, or next week
            if calendar.isDate(selectedWeek, equalTo: currentWeek, toGranularity: .weekOfYear) {
                return L10n.Period.thisWeek
            } else if let previousWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: currentWeek),
                      calendar.isDate(selectedWeek, equalTo: previousWeek, toGranularity: .weekOfYear) {
                return L10n.Period.lastWeek
            } else if let nextWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: currentWeek),
                      calendar.isDate(selectedWeek, equalTo: nextWeek, toGranularity: .weekOfYear) {
                return L10n.Period.nextWeek
            } else {
                dateFormatter.dateFormat = "d MMM"
                let start = dateFormatter.string(from: selectedWeek)
                let end = calendar.date(byAdding: .day, value: 6, to: selectedWeek) ?? selectedWeek
                let endString = dateFormatter.string(from: end)
                return "\(start) - \(endString)"
            }

        case .monthly:
            let currentMonth = calendar.startOfMonth(for: Date())
            let selectedMonth = viewModel.selectedMonth

            // Check if it's current, previous, or next month
            if calendar.isDate(selectedMonth, equalTo: currentMonth, toGranularity: .month) {
                return L10n.Period.thisMonth
            } else if let previousMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth),
                      calendar.isDate(selectedMonth, equalTo: previousMonth, toGranularity: .month) {
                return L10n.Period.lastMonth
            } else if let nextMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth),
                      calendar.isDate(selectedMonth, equalTo: nextMonth, toGranularity: .month) {
                return L10n.Period.nextMonth
            } else {
                dateFormatter.dateFormat = "MMMM yyyy"
                return dateFormatter.string(from: selectedMonth).capitalized
            }

        case .yearly:
            let currentYear = calendar.component(.year, from: Date())
            let selectedYear = viewModel.selectedYear

            // Check if it's current, previous, or next year
            if selectedYear == currentYear {
                return L10n.Period.thisYear
            } else if selectedYear == currentYear - 1 {
                return L10n.Period.lastYear
            } else if selectedYear == currentYear + 1 {
                return L10n.Period.nextYear
            } else {
                return "\(selectedYear)"
            }

        case .unique:
            return ""
        }
    }

    // MARK: - Hide Inactive Button

    private var hideInactiveButton: some View {
        Button {
            hideInactive.toggle()
            refreshData()
        } label: {
            Image(systemName: hideInactive ? "eye" : "eye.slash")
                .font(.body.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .opacity(hasInactiveBudgets ? 1 : 0)
        .disabled(!hasInactiveBudgets)
    }

    private var hasInactiveBudgets: Bool {
        // Check if there are any inactive budgets in the current period type
        let budgets = allBudgets.filter { budget in
            if selectedSegment == 3 {
                // Unique mode: show all unique budgets
                return budget.periodType == BudgetPeriodType.unique.rawValue
            } else {
                // Other modes: filter by selected period type
                return budget.periodType == viewModel.selectedPeriodType.rawValue
            }
        }

        // Check if any budget is inactive (isActive == false)
        return budgets.contains { !$0.isActive }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.xxl) {
            ZStack {
                Circle()
                    .fill(Color.electricIndigo.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: "chart.pie.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.electricIndigo, Color.hotPink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: DS.Spacing.sm) {
                Text(NSLocalizedString("budgets.empty.title", comment: ""))
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(NSLocalizedString("budgets.empty.message", comment: ""))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, DS.Spacing.xxxl * 2)
    }

    // MARK: - Budgets List

    private var budgetsList: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xl) {
            ForEach(viewModel.groupedBudgets, id: \.status) { section in
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    // Section header
                    Text(section.status.localizedName)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, DS.Spacing.lg)

                    // Budget cards
                    ForEach(section.budgets) { summary in
                        BudgetRowView(
                            summary: summary,
                            currencyCode: defaultCurrencyCode
                        ) {
                            viewModel.editingBudget = summary.budget
                            viewModel.showBudgetEditor = true
                        }
                        .padding(.horizontal, DS.Spacing.lg)
                    }
                }
            }
        }
        .padding(.top, DS.Spacing.sm)
        .padding(.bottom, 100)  // Space for FAB
    }

    // MARK: - New Budget FAB

    private var newBudgetFAB: some View {
        VStack {
            Spacer()

            HStack {
                Spacer()

                Button {
                    viewModel.editingBudget = nil
                    viewModel.showBudgetEditor = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.electricIndigo)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive())
                .shadow(color: Color.black.opacity(0.20), radius: 20, x: 0, y: 10)
            }
            .padding(.trailing, 20)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Data Management

    private func refreshData() {
        // Filter budgets based on selected period type
        var filteredBudgets = allBudgets.filter {
            $0.periodType == viewModel.selectedPeriodType.rawValue
        }

        // Apply hideInactive filter if enabled
        if hideInactive {
            filteredBudgets = filteredBudgets.filter { $0.isActive }
        }

        // Calculate budget data
        viewModel.calculateBudgetData(
            budgets: filteredBudgets,
            transactions: allTransactions,
            accounts: accounts,
            defaultCurrencyCode: defaultCurrencyCode
        )
    }

}

// MARK: - Calendar Extension

private extension Calendar {
    func startOfWeek(for date: Date) -> Date {
        let components = dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return self.date(from: components) ?? date
    }

    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? date
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        BudgetsListView()
    }
}
