//
//  BudgetsListView.swift
//  Yala
//
//  Main view for budget management with period filtering and status grouping
//

import SwiftData
import SwiftUI

struct BudgetsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SessionState.self) private var sessionState

    @AppStorage("defaultCurrencyCode") private var defaultCurrencyCode: String = CurrencyCode.pen
        .rawValue

    // ViewModel
    @State private var viewModel = BudgetsViewModel()
    @State private var selectedSegment: Int = 1  // 0=Weekly, 1=Monthly, 2=Yearly, 3=Unique
    @State private var showPeriodSelector = false
    @State private var showUpgradeSheet = false
    @AppStorage("budgets.hideInactive") private var hideInactive: Bool = false

    private var activeBudgetsCount: Int {
        viewModel.activeBudgetsCount
    }

    private var isAtLimit: Bool {
        FeatureGateService.shared.isAtLimit(.budgets, currentCount: activeBudgetsCount)
    }

    var body: some View {
        ZStack {
            PanelBackgroundView()

            ScrollView {
                VStack(spacing: DS.Spacing.none) {
                    // Limit reached banner
                    if isAtLimit {
                        LimitReachedBanner(
                            feature: .budgets,
                            currentCount: activeBudgetsCount
                        ) {
                            showUpgradeSheet = true
                        }
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.top, DS.Spacing.md)
                    }

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
                transactions: viewModel.allTransactions,
                onPeriodChange: { refreshData() }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showUpgradeSheet) {
            UpgradePromptSheet(feature: .budgets, context: .limitReached)
        }
        .onAppear {
            viewModel.setContext(modelContext)
            refreshData()
        }
        .onChange(of: sessionState.dataVersion) { _, _ in
            refreshData()
        }
    }

    // MARK: - Controls Bar

    private var controlsBar: some View {
        VStack(spacing: DS.Spacing.none) {
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
                    .font(DS.Typography.label)
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
                .font(DS.Typography.bodyBold)
                .foregroundStyle(.secondary)
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .opacity(hasInactiveBudgets ? 1 : 0)
        .accessibilityHint(!hasInactiveBudgets ? "No hay presupuestos inactivos" : "")
        .disabled(!hasInactiveBudgets)
    }

    private var hasInactiveBudgets: Bool {
        viewModel.hasInactiveBudgets(forPeriodTypeIndex: selectedSegment)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        YalaEmptyState.noBudgets()
            .padding(.top, DS.Spacing.xxxl * 2)
    }

    // MARK: - Budgets List

    private var budgetsList: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xl) {
            ForEach(viewModel.groupedBudgets, id: \.status) { section in
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    // Section header
                    Text(section.status.localizedName)
                        .font(DS.Typography.headline)
                        .foregroundStyle(.primary)
                        .padding(.horizontal, DS.Spacing.lg)

                    // Budget cards
                    ForEach(section.budgets) { summary in
                        BudgetRowView(
                            summary: summary,
                            currencyCode: summary.budget.currencyCode
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
                    if FeatureGateService.shared.canCreate(.budgets, currentCount: activeBudgetsCount) {
                        viewModel.editingBudget = nil
                        viewModel.showBudgetEditor = true
                    } else {
                        showUpgradeSheet = true
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(DS.Typography.title)
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
        viewModel.loadData()
        viewModel.refreshBudgetData(
            hideInactive: hideInactive,
            defaultCurrencyCode: defaultCurrencyCode
        )
    }

}

// MARK: - Calendar Extension


// MARK: - Preview

#Preview {
    NavigationStack {
        BudgetsListView()
    }
}
