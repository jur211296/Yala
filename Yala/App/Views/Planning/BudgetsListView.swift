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
    @Environment(\.yalaTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
        .navigationDestination(for: BudgetNavigationID.self) { navID in
            BudgetDetailDestination(budgetID: navID.id, viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showBudgetEditor) {
            BudgetEditorView(budget: nil)
                .onDisappear {
                    refreshData()
                }
        }
        .sheet(isPresented: $showPeriodSelector) {
            BudgetPeriodSelectorSheet(
                viewModel: viewModel,
                transactions: viewModel.allTransactions,
                onPeriodChange: { refreshData() }
            )
            .presentationDetents(DS.Adaptive.sheetDetents([.medium]))
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showUpgradeSheet) {
            UpgradePromptSheet(feature: .budgets, context: .limitReached)
        }
        .appliesPendingRemoteChanges(sessionState)
        .onAppear {
            viewModel.setContext(modelContext)
            viewModel.refreshBudgetData(
                hideInactive: hideInactive,
                defaultCurrencyCode: defaultCurrencyCode
            )

            // Auto-open editor from setup checklist (step 3)
            if sessionState.shouldAutoOpenBudgetEditor {
                sessionState.shouldAutoOpenBudgetEditor = false
                viewModel.editingBudget = nil
                viewModel.showBudgetEditor = true
            }
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

            if selectedSegment != 3 {
                // Period navigation header with chevrons
                periodNavigationHeader
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

    // MARK: - Period Navigation Header

    private var periodNavigationHeader: some View {
        HStack {
            Button {
                dsWithAnimation(reduceMotion) {
                    viewModel.previousPeriod()
                    refreshData()
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(DS.Typography.headline)
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                showPeriodSelector = true
            } label: {
                HStack(spacing: DS.Spacing.xs) {
                    Text(viewModel.periodLabel)
                        .font(DS.Typography.headline)
                        .foregroundStyle(.primary)

                    Image(systemName: "chevron.down")
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            hideInactiveButton

            Button {
                dsWithAnimation(reduceMotion) {
                    viewModel.nextPeriod()
                    refreshData()
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(DS.Typography.headline)
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, DS.Spacing.sm)
        .padding(.horizontal, DS.Spacing.lg)
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
        .accessibilityHint(!hasInactiveBudgets ? L10n.Budget.noInactive : "")
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
                        )
                        .padding(.horizontal, DS.Spacing.lg)
                    }
                }
            }
        }
        .padding(.top, DS.Spacing.sm)
        .padding(.bottom, DS.Spacing.safeBottom)  // Space for FAB
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
                        .frame(width: DS.Button.fabSize, height: DS.Button.fabSize)
                        .background(theme.accent)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.Accessibility.newBudget)
                .glassEffect(.regular.interactive())
                .shadow(color: Color.black.opacity(0.20), radius: 20, x: 0, y: 10)
            }
            .padding(.trailing, DS.Spacing.xl)
            .padding(.bottom, DS.Spacing.xxl)
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

// MARK: - Budget Detail Destination

/// Helper view that resolves PersistentIdentifier to Budget for navigation
private struct BudgetDetailDestination: View {
    let budgetID: PersistentIdentifier
    @Bindable var viewModel: BudgetsViewModel

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        if let budget = modelContext.model(for: budgetID) as? Budget {
            BudgetDetailView(budget: budget, viewModel: viewModel)
        } else {
            ContentUnavailableView(
                L10n.BudgetDetail.notFound,
                systemImage: "exclamationmark.triangle"
            )
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        BudgetsListView()
    }
}
