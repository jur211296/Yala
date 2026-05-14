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
    // Cache de contadores hero (evita reduce O(N) por render). Actualizado en
    // refreshData() / recalculatePeriodFilters() cuando data o filtros cambian.
    @State private var budgetCounters: BudgetCounters = .zero

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
                VStack(spacing: DS.Spacing.md) {
                    // Limit reached banner
                    if isAtLimit {
                        LimitReachedBanner(
                            feature: .budgets,
                            currentCount: activeBudgetsCount
                        ) {
                            showUpgradeSheet = true
                        }
                    }

                    heroSection

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
                .padding(.top, DS.Spacing.md)
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
            updateBudgetCounters()

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

    // MARK: - Hero Section (polish panel-aligned, Bloque B)

    private var heroSection: some View {
        VStack(alignment: .center, spacing: DS.Spacing.sm) {
            // Period type selector — mismo diseño que TrendsPeriodMenu de Stats
            Menu {
                Button(NSLocalizedString("budgets.period.weekly", comment: ""))  { setPeriodType(0) }
                Button(NSLocalizedString("budgets.period.monthly", comment: "")) { setPeriodType(1) }
                Button(NSLocalizedString("budgets.period.yearly", comment: ""))  { setPeriodType(2) }
                Button(NSLocalizedString("budgets.period.unique", comment: ""))  { setPeriodType(3) }
            } label: {
                PeriodSelectorLabel(title: currentPeriodTypeLabel)
            }

            // Counters row (BRAND-VOICE §5.3: dot + texto)
            HStack(spacing: DS.Spacing.lg) {
                counterChip(color: Color.electricIndigo,    label: L10n.Planning.Budgets.statusOnTrack(budgetCounters.onTrack))
                counterChip(color: Color.essentialNeed,     label: L10n.Planning.Budgets.statusAtLimit(budgetCounters.atLimit))
                counterChip(color: Color.hotPink,           label: L10n.Planning.Budgets.statusOverLimit(budgetCounters.overLimit))
            }

            if selectedSegment != 3 {
                Text(L10n.Planning.Budgets.currentPeriod(viewModel.periodLabel))
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DS.Spacing.lg)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(heroAccessibilityLabel)
    }

    private func counterChip(color: Color, label: String) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(DS.Typography.captionSmall)
                .foregroundStyle(.secondary)
                .minimumScaleFactor(0.85)
                .lineLimit(1)
        }
    }

    private var heroAccessibilityLabel: String {
        let parts = [
            currentPeriodTypeLabel,
            L10n.Planning.Budgets.statusOnTrack(budgetCounters.onTrack),
            L10n.Planning.Budgets.statusAtLimit(budgetCounters.atLimit),
            L10n.Planning.Budgets.statusOverLimit(budgetCounters.overLimit),
        ]
        return parts.joined(separator: ". ")
    }

    private var currentPeriodTypeLabel: String {
        switch selectedSegment {
        case 0: return NSLocalizedString("budgets.period.weekly", comment: "")
        case 1: return NSLocalizedString("budgets.period.monthly", comment: "")
        case 2: return NSLocalizedString("budgets.period.yearly", comment: "")
        case 3: return NSLocalizedString("budgets.period.unique", comment: "")
        default: return ""
        }
    }

    private func setPeriodType(_ index: Int) {
        selectedSegment = index
        switch index {
        case 0: viewModel.selectedPeriodType = .weekly
        case 1: viewModel.selectedPeriodType = .monthly
        case 2: viewModel.selectedPeriodType = .yearly
        case 3: viewModel.selectedPeriodType = .unique
        default: break
        }
        recalculatePeriodFilters()
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

    /// Reload from DB + recompute. Use when DB mutations could have occurred
    /// (editor dismiss, PeriodSelector, dataVersion bump).
    private func refreshData() {
        viewModel.reloadAndRecalculate(
            hideInactive: appPreferences.budgetsHideInactive,
            defaultCurrencyCode: appPreferences.defaultCurrencyCode.rawValue
        )
        updateBudgetCounters()
    }

    /// Recompute only (no re-fetch). Use when a filter or period changed
    /// but the DB is unchanged.
    private func recalculatePeriodFilters() {
        viewModel.recalculateData(
            hideInactive: appPreferences.budgetsHideInactive,
            defaultCurrencyCode: appPreferences.defaultCurrencyCode.rawValue
        )
        updateBudgetCounters()
    }

    /// Recomputa los contadores hero a partir de `groupedBudgets` actual.
    /// Llamado solo cuando data o filtros cambian — el hero lee `@State`
    /// directo en cada render (O(1)).
    private func updateBudgetCounters() {
        let items = viewModel.groupedBudgets.flatMap(\.budgets).map {
            (spent: $0.spent, limit: $0.budget.limitAmount)
        }
        budgetCounters = BudgetStatusCounter.counters(for: items)
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
