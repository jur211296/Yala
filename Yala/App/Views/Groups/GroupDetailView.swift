//
//  GroupDetailView.swift
//  Yala
//
//  Vista detalle de un grupo — fullScreenCover "app within app".
//  Navigation chips: Gastos / Balances / Estadísticas.
//

import SwiftUI
import SwiftData
import UIKit

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
    @Environment(\.scenePhase) private var scenePhase

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
        ZStack {
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

                // banner pending/rejected. Refresh ya cubierto por onChange(dataVersion) abajo.
                if viewModel.currentUserMember?.isPendingApproval == true {
                    PendingApprovalBanner(state: .pending, onLeave: nil)
                } else if viewModel.currentUserMember?.isRejected == true {
                    PendingApprovalBanner(state: .rejected, onLeave: {
                        viewModel.activeSheet = .settings
                    })
                }

                tabContent
                    .yalaSkeleton(!viewModel.isReady)
            }

            // FAB — new expense (only on records tab)
            if selectedTab == .records && viewModel.canCurrentUserParticipate {
                newExpenseFAB
            }
        }
        .yalaScreenBackground(.panel)
        .safeAreaInset(edge: .top) {
            navigationChipsBar
                .padding(.vertical, DS.Spacing.sm)
        }
        .navigationTitle(group.name)
        .navigationBarTitleDisplayMode(.large)
        // Push nativo (como el resto de detalles de la app): swipe-back desde el borde
        // izquierdo + chevron custom. Tab bar oculto para conservar el look inmersivo
        // que tenía como fullScreenCover (Grupos se navega desde "Más").
        .swipeBack()
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                YalaToolbarButton(systemName: "chevron.left", label: L10n.Action.back) {
                    dismiss()
                }
            }

            ToolbarSpacer(.fixed, placement: .topBarTrailing)

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.activeSheet = .members
                } label: {
                    ZStack(alignment: .topTrailing) {
                        HStack(spacing: DS.Spacing.xxs) {
                            Image(systemName: "person.2.fill")
                            Text("\(viewModel.activeMembers.count)")
                                .font(DS.Typography.subheadline)
                        }
                        .fontWeight(.medium)
                        .foregroundStyle(Color.primary)

                        // Badge de solicitudes pendientes — movido del engranaje: las solicitudes
                        // son de personas y se aprueban/rechazan en la sheet de Miembros.
                        if viewModel.isCurrentUserAdmin && !viewModel.pendingApprovalMembers.isEmpty {
                            Circle()
                                .fill(DS.Semantic.errorForeground)
                                .frame(width: 8, height: 8)
                                .offset(x: DS.Spacing.xxs, y: -DS.Spacing.xxs)
                        }
                    }
                }
                .accessibilityLabel(membersButtonA11yLabel)
                .accessibilityIdentifier("group_members_button")
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.activeSheet = .settings
                } label: {
                    Image(systemName: "gearshape")
                        .fontWeight(.medium)
                        .foregroundStyle(Color.primary)
                }
                .accessibilityLabel(L10n.Groups.Settings.title)
                .buttonBorderShape(.circle)
            }
        }
        .sheet(item: $viewModel.activeSheet, onDismiss: {
            // Reemplazo de sheet: si el detalle pidió editar, sube el editor
            // (conserva el gasto); si no, cierre normal (recarga datos).
            if let expense = viewModel.consumePendingEditFromDetail() {
                viewModel.activeSheet = expense.isOpeningBalance ? .editOpeningBalance(expense) : .editExpense(expense)
            } else {
                viewModel.loadData()
            }
        }) { sheet in
            sheetContent(for: sheet)
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = viewModel.shareURL {
                ActivityView(activityItems: [url])
                }
        }
        .alert(L10n.Common.error, isPresented: $viewModel.showActionError) {
            Button(L10n.Common.ok) {}
        } message: {
            Text(viewModel.actionErrorMessage ?? L10n.Groups.Errors.actionFailed)
        }
        .appliesPendingRemoteChanges(sessionState)
        .onAppear {
            wasArchivedOnAppear = group.isArchived
            viewModel.setContext(modelContext)
            // Traer cambios remotos al abrir el grupo: los gastos de otros aún no sincronizados
            // aparecen sin depender del pull (el empty state de records no tiene pull-to-refresh).
            Task { await viewModel.refreshFromCloud(force: false) }
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
            viewModel.cancelRecalculation()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background, .inactive:
                viewModel.setBackground(true)
            case .active:
                guard UIApplication.shared.applicationState == .active else { return }
                viewModel.setBackground(false)
                viewModel.reloadAndRecalculate()
            @unknown default:
                break
            }
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

    // MARK: - Sheet Content

    @ViewBuilder
    private func sheetContent(for sheet: GroupSheet) -> some View {
        switch sheet {
        case .settings:
            GroupSettingsView(group: group, viewModel: viewModel)

        case .members:
            GroupMembersView(group: group, viewModel: viewModel)

        case .addExpense:
            // Detents `.large` + drag indicator: estabilizan el sheet y evitan
            // que el contenido "respire" con cambios de keyboard / state.
            GroupExpenseFormView(
                group: group,
                members: viewModel.activeMembers,
                memberNameLookup: viewModel.memberNameLookup,
                groupChip: .readOnly,
                onSave: {}
            )
            .presentationDetents(DS.Adaptive.sheetDetents([.large]))
            .presentationDragIndicator(.visible)

        case .expenseDetail(let expense):
            // Fase 1: detalle read-only en medium. El botón Editar sube el editor
            // en large (vía pendingEdit consumido en el onDismiss del sheet).
            GroupExpenseDetailSheet(
                expense: expense,
                share: viewModel.mySharesByExpense[expense.id],
                bridgeTransaction: viewModel.txBridgeMap[expense.id.uuidString],
                memberNameLookup: viewModel.memberNameLookup,
                currentMemberID: viewModel.currentMemberID,
                onEdit: { viewModel.requestEditFromDetail(expense) }
            )

        case .editExpense(let expense):
            GroupExpenseFormView(
                group: group,
                members: membersForExpenseForm(expense),
                memberNameLookup: viewModel.memberNameLookup,
                groupChip: .readOnly,
                expenseToEdit: expense,
                existingShares: viewModel.sharesForExpense(expense),
                onSave: {},
                onDelete: viewModel.canCurrentUserParticipate ? { viewModel.deleteExpense($0) } : nil
            )
            .presentationDetents(DS.Adaptive.sheetDetents([.large]))
            .presentationDragIndicator(.visible)

        case .openingBalanceDetail(let expense):
            GroupOpeningBalanceDetailSheet(
                expense: expense,
                debtorMemberID: viewModel.sharesForExpense(expense).first?.memberID,
                memberNameLookup: viewModel.memberNameLookup,
                isOwner: group.isOwner,
                onEdit: { viewModel.requestEditFromDetail(expense) },
                onDelete: { viewModel.removeOpeningBalance(expense) }
            )

        case .editOpeningBalance(let expense):
            GroupOpeningBalanceFormView(
                group: group,
                members: viewModel.activeMembers,
                memberNameLookup: viewModel.memberNameLookup,
                expenseToEdit: expense,
                existingDebtorMemberID: viewModel.sharesForExpense(expense).first?.memberID,
                onSave: {}
            )
            .presentationDetents(DS.Adaptive.sheetDetents([.large]))
            .presentationDragIndicator(.visible)

        case .settlement(let debt):
            SettlementFormView(
                group: group,
                debt: debt,
                memberNameLookup: viewModel.memberNameLookup,
                currentUserMemberID: viewModel.currentMemberID,
                onSave: {}
            )
            .presentationDetents(DS.Adaptive.sheetDetents([.large]))
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Members Button

    private var membersButtonA11yLabel: String {
        let base = L10n.Groups.Detail.memberCount(viewModel.activeMembers.count)
        if viewModel.isCurrentUserAdmin && !viewModel.pendingApprovalMembers.isEmpty {
            return "\(base), \(L10n.Groups.Member.pendingRequestsCount(viewModel.pendingApprovalMembers.count))"
        }
        return base
    }

    // MARK: - Navigation Chips Bar

    private var navigationChipsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.sm) {
                ForEach(GroupDetailTab.allCases) { tab in
                    navigationChipButton(for: tab)
                }
            }
            .scrollTargetLayout()
        }
        .contentMargins(.horizontal, DS.Spacing.lg)
        .scrollTargetBehavior(.viewAligned)
        .scrollClipDisabled()
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
            if tab == .balances {
                TelemetryService.track(.groupBalancesViewed)
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
                txBridgeMap: viewModel.txBridgeMap,
                mySharesByExpense: viewModel.mySharesByExpense,
                currentMemberID: viewModel.currentMemberID,
                onTapExpense: viewModel.canCurrentUserParticipate ? { expense in
                    viewModel.activeSheet = expense.isOpeningBalance ? .openingBalanceDetail(expense) : .expenseDetail(expense)
                } : nil,
                onEditExpense: viewModel.canCurrentUserParticipate ? { viewModel.activeSheet = .editExpense($0) } : nil,
                onDeleteExpense: viewModel.canCurrentUserParticipate ? { viewModel.deleteExpense($0) } : nil,
                onInvite: group.isOwner && viewModel.isCurrentUserAdmin ? {
                    guard !viewModel.isCreatingShare else { return }
                    Task {
                        await viewModel.createShareLink()
                        if viewModel.shareURL != nil {
                            showShareSheet = true
                        }
                    }
                } : nil,
                headerBalance: viewModel.headerBalance,
                debtsWereConverted: viewModel.debtsWereConverted,
                onTapBalance: {
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) { selectedTab = .balances }
                    TelemetryService.track(.groupBalancesViewed)
                },
                onRefresh: { await viewModel.refreshFromCloud(force: true) }
            )

        case .balances:
            GroupBalancesView(
                balances: viewModel.balances,
                debts: viewModel.debts,
                settlements: viewModel.settlements,
                memberNameLookup: viewModel.memberNameLookup,
                balancesWereConverted: viewModel.balancesWereConverted,
                debtsWereConverted: viewModel.debtsWereConverted,
                onSettleDebt: viewModel.canCurrentUserParticipate ? { viewModel.activeSheet = .settlement($0) } : nil,
                onConfirmSettlement: viewModel.canCurrentUserParticipate ? { viewModel.confirmSettlement($0) } : nil,
                onRejectSettlement: viewModel.canCurrentUserParticipate ? { viewModel.rejectSettlement($0) } : nil
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
            RouterEntryGate.shared.submit(.presentFullModeActivation)
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
                CircularPlusFAB(
                    tint: theme.accent,
                    accessibilityLabel: L10n.Groups.Expense.newExpense,
                    accessibilityIdentifier: "group_detail_fab_new_expense"
                ) {
                    viewModel.activeSheet = .addExpense
                }
                .dsFloatingShadow()
            }
            .padding(.trailing, DS.Spacing.xl)
            .padding(.bottom, DS.Spacing.xxl)
        }
    }

    private func membersForExpenseForm(_ expense: SplitExpense) -> [SplitMember] {
        let referencedMemberIDs = Set([expense.paidByMemberID] + viewModel.sharesForExpense(expense).map(\.memberID))
        return viewModel.members.filter { member in
            member.isActive || referencedMemberIDs.contains(member.id.uuidString)
        }
    }
}

// MARK: - A3: Pending Approval Banner

private struct PendingApprovalBanner: View {
    enum BannerState { case pending, rejected }
    let state: BannerState
    var onLeave: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            Image(systemName: state == .pending ? "clock.arrow.circlepath" : "xmark.circle.fill")
                .font(DS.Typography.title2)
                .foregroundStyle(state == .pending ? DS.Semantic.warningForeground : DS.Semantic.errorForeground)

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(state == .pending ? L10n.Groups.Invite.waitingApprovalBanner : L10n.Groups.Invite.rejectedTitle)
                    .font(DS.Typography.subheadlineEmphasized)
                if state == .rejected {
                    Text(L10n.Groups.Invite.rejectedBody)
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if state == .rejected, let onLeave {
                Button(L10n.Groups.Settings.leaveGroup, action: onLeave)
                    .font(DS.Typography.label)
                    .foregroundStyle(DS.Semantic.errorForeground)
            }
        }
        .padding(DS.Spacing.md)
        .background(
            (state == .pending ? DS.Semantic.warningBackground : DS.Semantic.errorBackground),
            in: RoundedRectangle(cornerRadius: DS.Radius.md)
        )
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.top, DS.Spacing.sm)
    }
}
