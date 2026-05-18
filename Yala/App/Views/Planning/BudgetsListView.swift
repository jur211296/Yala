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

    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.scenePhase) private var scenePhase

    // ViewModel
    @State private var viewModel = BudgetsViewModel()
    @State private var selectedSegment: Int = 1  // 0=Weekly, 1=Monthly, 2=Yearly, 3=Unique
    @State private var showPeriodSelector = false
    @State private var showUpgradeSheet = false

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
                VStack(spacing: DS.Spacing.xs) {
                    // Limit reached banner
                    if isAtLimit {
                        LimitReachedBanner(
                            feature: .budgets,
                            currentCount: activeBudgetsCount
                        ) {
                            showUpgradeSheet = true
                        }
                    }

                    // Segmented Picker período (Weekly/Monthly/Yearly/Unique).
                    // SIN padding horizontal externo — las cards de BudgetRowView usan
                    // `.padding(.lg)` INTERNO y `.solidCard` sin padding externo, así
                    // llegan al borde del ScrollView. El picker debe igualar ese ancho.
                    periodTypeSegmentedControl

                    // PeriodNavigationHeader shared (oculto en .unique mode)
                    if selectedSegment != 3 {
                        PeriodNavigationHeader(
                            currentLabel: viewModel.periodLabel,
                            onPrevious: {
                                viewModel.previousPeriod()
                                recalculatePeriodFilters()
                            },
                            onNext: {
                                viewModel.nextPeriod()
                                recalculatePeriodFilters()
                            },
                            onTapLabel: { showPeriodSelector = true }
                        )
                        .padding(.horizontal, DS.Spacing.lg)
                    }

                    listContent
                }
                .frame(maxWidth: .infinity)
                .padding(.top, DS.Spacing.sm)
            }
            .scrollViewGlassEdges()

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
                hideInactive: appPreferences.budgetsHideInactive,
                defaultCurrencyCode: appPreferences.defaultCurrencyCode.rawValue
            )

            // Auto-open editor from setup checklist — routed via AppRouter now;
            // drain handler below sets showBudgetEditor on .autoOpenBudgetEditor.
        }
        .onDisappear {
            viewModel.cancelRecalculation()
        }
        .onChange(of: scenePhase) { _, phase in
            viewModel.setBackground(phase != .active)
        }
        .onChange(of: sessionState.dataVersion) { _, _ in
            refreshData()
        }
        // Peek first so we only drain intents this view handles —
        // ScheduledPaymentsView shares the .planning consumer.
        .routerConsumer(.planning) {
            if case .autoOpenBudgetEditor = AppRouter.shared.peekNext(for: .planning) {
                _ = AppRouter.shared.drainNext(for: .planning)
                viewModel.editingBudget = nil
                viewModel.showBudgetEditor = true
            }
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
        .frame(maxWidth: .infinity)
        .onChange(of: selectedSegment) { _, newValue in
            switch newValue {
            case 0: viewModel.selectedPeriodType = .weekly
            case 1: viewModel.selectedPeriodType = .monthly
            case 2: viewModel.selectedPeriodType = .yearly
            case 3: viewModel.selectedPeriodType = .unique
            default: break
            }
            recalculatePeriodFilters()
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

    // MARK: - Empty State

    private var emptyState: some View {
        YalaEmptyState.noBudgets()
            .padding(.top, DS.Spacing.xxxl * 2)
    }

    // MARK: - Budgets List

    private var budgetsList: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            ForEach(viewModel.groupedBudgets, id: \.status) { section in
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    // Section header
                    Text(section.status.localizedName)
                        .font(DS.Typography.subheadlineEmphasized)
                        .foregroundStyle(.primary)

                    // Budget cards
                    ForEach(section.budgets) { summary in
                        BudgetRowView(
                            summary: summary,
                            currencyCode: summary.budget.currencyCode
                        )
                    }
                }
            }
        }
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
                        .glassEffect(
                            .regular.interactive().tint(theme.accent.opacity(0.6)),
                            in: Circle()
                        )
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .dsFloatingShadow()
                .accessibilityLabel(L10n.Accessibility.newBudget)
            }
            .padding(.trailing, DS.Spacing.xl)
            .padding(.bottom, DS.Spacing.xxl)
        }
    }

    // MARK: - Data Management

    /// Reload from DB + recompute. Use when DB mutations could have occurred
    /// (editor dismiss, PeriodSelector, dataVersion bump).
    private func refreshData() {
        viewModel.reloadAndRecalculate(
            hideInactive: appPreferences.budgetsHideInactive,
            defaultCurrencyCode: appPreferences.defaultCurrencyCode.rawValue
        )
    }

    /// Recompute only (no re-fetch). Use when a filter or period changed
    /// but the DB is unchanged.
    private func recalculatePeriodFilters() {
        viewModel.recalculateData(
            hideInactive: appPreferences.budgetsHideInactive,
            defaultCurrencyCode: appPreferences.defaultCurrencyCode.rawValue
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
