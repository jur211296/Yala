//
//  GroupDetailView.swift
//  Yala
//
//  Vista detalle de un grupo — fullScreenCover "app within app".
//  Navigation chips: Gastos / Balances / Estadísticas.
//

import SwiftUI
import SwiftData

// MARK: - Detail Tab Enum

enum GroupDetailTab: String, CaseIterable, Identifiable {
    case records
    case balances
    case stats

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .records: return L10n.Groups.Detail.records
        case .balances: return L10n.Groups.Detail.balances
        case .stats: return L10n.Groups.Detail.stats
        }
    }

    var icon: String {
        switch self {
        case .records: return "list.bullet"
        case .balances: return "arrow.left.arrow.right"
        case .stats: return "chart.pie"
        }
    }
}

// MARK: - Group Detail View

struct GroupDetailView: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(SessionState.self) private var sessionState
    @Environment(\.yalaTheme) private var theme

    // MARK: - Input

    let group: SplitGroup

    // MARK: - State

    @State private var viewModel: GroupDetailViewModel
    @State private var selectedTab: GroupDetailTab = .records
    @State private var showNudgeBanner = false
    @State private var showShareSheet = false
    @State private var wasArchivedOnAppear = false

    // MARK: - Init

    init(group: SplitGroup) {
        self.group = group
        self._viewModel = State(initialValue: GroupDetailViewModel(group: group))
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()

                VStack(spacing: 0) {
                    if let nudge = NudgeService.shared.currentNudge, showNudgeBanner {
                        GroupNudgeBanner(
                            nudge: nudge,
                            message: NudgeService.shared.currentNudgeMessage ?? "",
                            onAction: {
                                NudgeService.shared.recordInteracted(nudge)
                                withAnimation(.easeOut(duration: 0.25)) { showNudgeBanner = false }
                                handleNudgeAction(nudge)
                            },
                            onDismiss: {
                                NudgeService.shared.recordDismissed(nudge)
                                withAnimation(.easeOut(duration: 0.25)) { showNudgeBanner = false }
                            },
                            onAutoDismiss: {
                                NudgeService.shared.recordDismissed(nudge, autoDismissed: true)
                                withAnimation(.easeOut(duration: 0.25)) { showNudgeBanner = false }
                            }
                        )
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.top, DS.Spacing.sm)
                    }

                    tabContent
                }

                // FAB — new expense (only on records tab)
                if selectedTab == .records {
                    newExpenseFAB
                }
            }
            .safeAreaInset(edge: .top) {
                navigationChipsBar
                    .padding(.vertical, DS.Spacing.sm)
            }
            .navigationTitle(group.name)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "chevron.left", label: L10n.Action.back) {
                        dismiss()
                    }
                }

                ToolbarSpacer(.fixed, placement: .topBarTrailing)

                ToolbarItem(placement: .topBarTrailing) {
                    YalaToolbarButton(systemName: "gearshape", label: L10n.Groups.Settings.title) {
                        viewModel.activeSheet = .settings
                    }
                }
            }
            .sheet(item: $viewModel.activeSheet, onDismiss: {
                viewModel.loadData()
            }) { sheet in
                sheetContent(for: sheet)
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = viewModel.shareURL {
                    ActivityView(activityItems: [url])
                }
            }
            .refreshable { viewModel.loadData() }
            .appliesPendingRemoteChanges(sessionState)
            .onAppear {
                wasArchivedOnAppear = group.isArchived
                viewModel.setContext(modelContext)
                // Only evaluate if no nudge is already showing (avoid overriding GroupsContainer nudge)
                if NudgeService.shared.currentNudge == nil {
                    NudgeService.shared.evaluate()
                }
                if NudgeService.shared.currentNudge != nil {
                    withAnimation(.easeOut(duration: 0.3)) { showNudgeBanner = true }
                }
            }
            .onDisappear {
                showNudgeBanner = false
            }
            .onChange(of: sessionState.dataVersion) {
                viewModel.loadData()
                if group.modelContext == nil || group.isDeleted {
                    dismiss()
                    return
                }
                // Only dismiss if group BECAME archived during this session
                if group.isArchived && !wasArchivedOnAppear {
                    dismiss()
                }
            }
        }
    }

    // MARK: - Sheet Content

    @ViewBuilder
    private func sheetContent(for sheet: GroupSheet) -> some View {
        switch sheet {
        case .settings:
            GroupSettingsView(group: group, viewModel: viewModel)

        case .addExpense:
            GroupExpenseFormView(
                group: group,
                members: viewModel.members,
                memberNameLookup: viewModel.memberNameLookup,
                onSave: {}
            )

        case .editExpense(let expense):
            GroupExpenseFormView(
                group: group,
                members: viewModel.members,
                memberNameLookup: viewModel.memberNameLookup,
                expenseToEdit: expense,
                existingShares: viewModel.sharesForExpense(expense),
                onSave: {}
            )

        case .settlement(let debt):
            SettlementFormView(
                group: group,
                debt: debt,
                memberNameLookup: viewModel.memberNameLookup,
                onSave: {}
            )
        }
    }

    // MARK: - Navigation Chips Bar

    private var navigationChipsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.sm) {
                ForEach(GroupDetailTab.allCases) { tab in
                    navigationChipButton(for: tab)
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
        }
    }

    @ViewBuilder
    private func navigationChipButton(for tab: GroupDetailTab) -> some View {
        let isSelected = selectedTab == tab

        Button {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                selectedTab = tab
            }
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: tab.icon)
                    .font(DS.Typography.subheadline)
                Text(tab.displayName)
                    .font(DS.Typography.label)
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.sm)
            .foregroundStyle(isSelected ? .white : .primary)
            .background(
                Capsule()
                    .fill(isSelected ? theme.accent : Color.clear)
            )
            .glassEffect(isSelected ? .clear : .regular.interactive(), in: .capsule)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .records:
            GroupRecordsView(
                expenses: viewModel.expenses,
                shares: viewModel.shares,
                memberNameLookup: viewModel.memberNameLookup,
                currencyCode: group.currencyCode,
                onTapExpense: { viewModel.activeSheet = .editExpense($0) },
                onDeleteExpense: { viewModel.deleteExpense($0) },
                onInvite: {
                    guard !viewModel.isCreatingShare else { return }
                    Task {
                        await viewModel.createShareLink()
                        if viewModel.shareURL != nil {
                            showShareSheet = true
                        }
                    }
                }
            )

        case .balances:
            GroupBalancesView(
                balances: viewModel.balances,
                debts: viewModel.debts,
                settlements: viewModel.settlements,
                memberNameLookup: viewModel.memberNameLookup,
                onSettleDebt: { viewModel.activeSheet = .settlement($0) },
                onConfirmSettlement: { viewModel.confirmSettlement($0) },
                onRejectSettlement: { viewModel.rejectSettlement($0) }
            )

        case .stats:
            GroupStatsView(
                expenses: viewModel.expenses,
                shares: viewModel.shares,
                members: viewModel.members,
                settlements: viewModel.settlements,
                currentUserMemberID: viewModel.currentUserMember?.id.uuidString,
                currencyCode: group.currencyCode
            )
        }
    }

    // MARK: - Nudge CTA Routing

    private func handleNudgeAction(_ nudge: NudgeType) {
        switch nudge.actionType {
        case .activateFullMode:
            SessionState.shared.shouldOpenFullModeActivation = true
        case .openPanel:
            dismiss()
        case .openGroupDetail, .dismiss:
            break
        }
    }

    // MARK: - FAB

    private var newExpenseFAB: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button {
                    viewModel.activeSheet = .addExpense
                } label: {
                    Image(systemName: "plus")
                        .font(DS.Typography.title)
                        .foregroundStyle(.white)
                        .frame(width: DS.Button.fabSize, height: DS.Button.fabSize)
                        .background(theme.accent)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.Groups.Expense.newExpense)
                .glassEffect(.regular.interactive())
                .dsFloatingShadow()
            }
            .padding(.trailing, DS.Spacing.xl)
            .padding(.bottom, DS.Spacing.xxl)
        }
    }
}
