//
//  GroupMembersView.swift
//  Yala
//
//  Sheet dedicada de Miembros — lista, roles, aprobar/rechazar, invitar por enlace
//  y saldos iniciales (owner). Se abre desde el botón "Miembros" del toolbar del detalle.
//  Separada de GroupSettingsView para que cada botón del toolbar tenga un significado
//  nítido: personas (este) vs configuración del grupo (engranaje).
//

import SwiftUI
import SwiftData

struct GroupMembersView: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences

    // MARK: - Input

    let group: SplitGroup
    @Bindable var viewModel: GroupDetailViewModel

    // MARK: - State

    // Invite by link. Local error channel (no viewModel.showActionError): su alert vive en
    // GroupDetailView y quedaría oculto detrás de esta sheet.
    @State private var isCreatingShare = false
    @State private var shareURL: URL?
    @State private var showShareSheet = false
    @State private var showShareError = false
    @State private var shareErrorMessage: String = ""

    // Remove member
    @State private var showRemoveMemberConfirm = false
    @State private var memberToRemove: SplitMember?

    // Approve / reject (A3)
    @State private var pendingActionMember: SplitMember?
    @State private var showApproveConfirm: Bool = false
    @State private var showRejectConfirm: Bool = false
    @State private var pendingErrorMessage: String?
    @State private var showPendingError: Bool = false

    // changeRole / removeMember error channel
    @State private var showActionError = false
    @State private var actionErrorMessage: String = ""

    // Saldos iniciales (owner-only)
    @State private var showOpeningBalanceEditor = false
    @State private var openingBalanceToEdit: SplitExpense?
    @State private var openingBalancePrefillDebtor: String?
    @State private var showOpeningBalanceApprovalPrompt = false
    @State private var approvedMemberName: String = ""

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.xxl) {
                    membersSection

                    // Saldos iniciales (deuda de apertura) — owner-only.
                    if group.isOwner {
                        openingBalanceSection
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.xl)
            }
            .scrollContentBackground(.hidden)
            .yalaScreenBackground(.subtle)
            .navigationTitle(L10n.Groups.Settings.members)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = shareURL {
                    ActivityView(activityItems: [url])
                }
            }
            .sheet(isPresented: $showOpeningBalanceEditor, onDismiss: { viewModel.loadData() }) {
                GroupOpeningBalanceFormView(
                    group: group,
                    members: viewModel.activeMembers,
                    memberNameLookup: viewModel.memberNameLookup,
                    expenseToEdit: openingBalanceToEdit,
                    existingDebtorMemberID: openingBalanceToEdit.flatMap { debtorID(for: $0) },
                    prefillDebtorMemberID: openingBalanceToEdit == nil ? openingBalancePrefillDebtor : nil,
                    onSave: { viewModel.loadData() }
                )
                .presentationDetents(DS.Adaptive.sheetDetents([.large]))
                .presentationDragIndicator(.visible)
            }
            .confirmationDialog(
                L10n.Groups.OpeningBalance.approvalPromptTitle(approvedMemberName),
                isPresented: $showOpeningBalanceApprovalPrompt,
                titleVisibility: .visible
            ) {
                Button(L10n.Groups.OpeningBalance.approvalPromptAdd) {
                    openingBalanceToEdit = nil
                    showOpeningBalanceEditor = true
                }
                Button(L10n.Groups.OpeningBalance.approvalPromptSkip, role: .cancel) {
                    openingBalancePrefillDebtor = nil
                }
            } message: {
                Text(L10n.Groups.OpeningBalance.approvalPromptBody)
            }
            .confirmationDialog(
                L10n.Groups.Member.remove,
                isPresented: $showRemoveMemberConfirm,
                titleVisibility: .visible
            ) {
                Button(L10n.Groups.Member.remove, role: .destructive) {
                    removeMember()
                }
            } message: {
                if memberToRemoveHasDebt {
                    Text(L10n.Groups.Member.removeWithDebtWarning)
                } else {
                    Text(L10n.Groups.Member.removeConfirm)
                }
            }
            .confirmationDialog(
                pendingActionMember.map { L10n.Groups.Member.approveConfirm($0.displayName) } ?? "",
                isPresented: $showApproveConfirm,
                titleVisibility: .visible
            ) {
                Button(L10n.Groups.Member.approve) { performApprove() }
                Button(L10n.Common.cancel, role: .cancel) { pendingActionMember = nil }
            }
            .confirmationDialog(
                pendingActionMember.map { L10n.Groups.Member.rejectConfirm($0.displayName) } ?? "",
                isPresented: $showRejectConfirm,
                titleVisibility: .visible
            ) {
                Button(L10n.Groups.Member.reject, role: .destructive) { performReject() }
                Button(L10n.Common.cancel, role: .cancel) { pendingActionMember = nil }
            }
            .alert(L10n.Common.error, isPresented: $showPendingError) {
                Button(L10n.Common.ok) {}
            } message: {
                Text(pendingErrorMessage ?? "")
            }
            .alert(L10n.Common.error, isPresented: $showShareError) {
                Button(L10n.Common.ok) {}
            } message: {
                Text(shareErrorMessage)
            }
            .alert(L10n.Common.error, isPresented: $showActionError) {
                Button(L10n.Common.ok) {}
            } message: {
                Text(actionErrorMessage)
            }
        }
    }

    // MARK: - Members Section

    /// C-10: en un grupo CONGELADO las acciones de admin (quitar, aprobar/rechazar, cambiar rol, invitar)
    /// se ocultan. El detalle pasó a ser alcanzable en congelado — antes el tap de la card no lo abría —
    /// y estas escrituras irían a una zona CloudKit muerta: se perderían en silencio. La UX primaria es
    /// ocultarlas (mismo criterio que `canCurrentUserParticipate` con el resto de escrituras); la RED es
    /// el guard service-level en `GroupService`.
    private var canActAsAdmin: Bool { viewModel.isCurrentUserAdmin && !group.isMigratedFrozen }

    private var membersSection: some View {
        SectionBox(title: L10n.Groups.Settings.members) {
            VStack(spacing: DS.Spacing.none) {
                ForEach(viewModel.visibleMembers, id: \.id) { member in
                    GroupMemberRow(
                        member: member,
                        groupColorHex: group.colorHex,
                        isCurrentUserAdmin: canActAsAdmin,
                        onChangeRole: { changeRole(member) },
                        onRemove: {
                            memberToRemove = member
                            showRemoveMemberConfirm = true
                        },
                        onApprove: canActAsAdmin && member.isPendingApproval ? {
                            pendingActionMember = member
                            showApproveConfirm = true
                        } : nil,
                        onReject: canActAsAdmin && member.isPendingApproval ? {
                            pendingActionMember = member
                            showRejectConfirm = true
                        } : nil
                    )

                    if member.id != viewModel.members.last?.id {
                        Divider()
                            .padding(.leading, DS.FormRow.paddingH)
                    }
                }

                // Invite by link
                if group.isOwner && canActAsAdmin {
                    Divider()
                    Button {
                        DS.Haptic.light()
                        Task { await createShareLink() }
                    } label: {
                        HStack(spacing: DS.Spacing.md) {
                            Image(systemName: "link.badge.plus")
                                .font(DS.Typography.title2)
                                .foregroundStyle(.thAccent)

                            Text(isCreatingShare ? L10n.Groups.Settings.generatingInvite : L10n.Groups.Settings.invite)
                                .font(DS.Typography.body)
                                .foregroundStyle(.thAccent)

                            Spacer()

                            if isCreatingShare {
                                ProgressView()
                            }
                        }
                        .padding(.horizontal, DS.FormRow.paddingH)
                        .padding(.vertical, DS.FormRow.paddingV)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(isCreatingShare)

                    Text(L10n.Groups.Settings.inviteLinkHint)
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, DS.FormRow.paddingH)
                        .padding(.bottom, DS.Spacing.sm)
                }
            }
        }
    }

    // MARK: - A3: Pending Approval Actions

    private func performApprove() {
        guard let member = pendingActionMember else { return }
        let memberID = member.id.uuidString
        let memberName = member.resolvedDisplayName
        // `approveMember` es `async` (C5: grupo backend rutea a un RPC). Con flag OFF no suspende — el camino
        // CloudKit corre igual, solo envuelto en un Task (MainActor heredado).
        Task {
            do {
                try await GroupService.shared.approveMember(member, in: group)
                viewModel.loadData()
                pendingActionMember = nil
                // Atajo (owner-only): ofrecer crear un saldo inicial para el miembro recién aprobado.
                if group.isOwner {
                    openingBalancePrefillDebtor = memberID
                    approvedMemberName = memberName
                    showOpeningBalanceApprovalPrompt = true
                }
            } catch {
                pendingErrorMessage = error.localizedDescription
                showPendingError = true
                pendingActionMember = nil
                #if DEBUG
                print("GroupMembersView: approveMember failed: \(error)")
                #endif
            }
        }
    }

    private func performReject() {
        runPendingMemberAction(label: "rejectMember", GroupService.shared.rejectMember)
    }

    private func runPendingMemberAction(
        label: String,
        _ action: (SplitMember, SplitGroup) throws -> Void
    ) {
        guard let member = pendingActionMember else { return }
        do {
            try action(member, group)
            viewModel.loadData()
        } catch {
            pendingErrorMessage = error.localizedDescription
            showPendingError = true
            #if DEBUG
            print("GroupMembersView: \(label) failed: \(error)")
            #endif
        }
        pendingActionMember = nil
    }

    // MARK: - Opening Balance Section

    private var openingExpenses: [SplitExpense] {
        viewModel.expenses.filter(\.isOpeningBalance).sorted { $0.createdAt < $1.createdAt }
    }

    private func debtorID(for expense: SplitExpense) -> String? {
        viewModel.sharesForExpense(expense).first?.memberID
    }

    private struct RollupRow: Identifiable {
        let memberID: String
        let currencyCode: String
        let net: Double
        var id: String { "\(memberID)-\(currencyCode)" }
    }

    private var rollupRows: [RollupRow] {
        let edges = openingExpenses.compactMap { e -> OpeningBalanceRollup.Edge? in
            guard let d = debtorID(for: e) else { return nil }
            return OpeningBalanceRollup.Edge(
                debtorMemberID: d, creditorMemberID: e.paidByMemberID,
                amount: e.amount, currencyCode: e.currencyCode
            )
        }
        return OpeningBalanceRollup.netByMember(edges: edges)
            .flatMap { memberID, byCurrency in
                byCurrency.map { RollupRow(memberID: memberID, currencyCode: $0.key, net: $0.value) }
            }
            .sorted { lhs, rhs in
                let ln = viewModel.memberNameLookup[lhs.memberID] ?? lhs.memberID
                let rn = viewModel.memberNameLookup[rhs.memberID] ?? rhs.memberID
                if ln != rn { return ln < rn }
                return lhs.currencyCode < rhs.currencyCode
            }
    }

    private var openingBalanceSection: some View {
        SectionBox(title: L10n.Groups.OpeningBalance.sectionTitle) {
            VStack(spacing: DS.Spacing.md) {
                let rows = rollupRows
                if !rows.isEmpty {
                    VStack(spacing: DS.Spacing.xs) {
                        ForEach(rows) { row in
                            rollupRow(memberID: row.memberID, net: row.net, currencyCode: row.currencyCode)
                        }
                    }
                }

                if openingExpenses.isEmpty {
                    Text(L10n.Groups.OpeningBalance.emptyState)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    VStack(spacing: DS.Spacing.none) {
                        ForEach(openingExpenses, id: \.id) { expense in
                            edgeRow(expense)
                            if expense.id != openingExpenses.last?.id {
                                Divider()
                            }
                        }
                    }
                }

                Button {
                    openingBalanceToEdit = nil
                    openingBalancePrefillDebtor = nil
                    showOpeningBalanceEditor = true
                } label: {
                    Label(L10n.Groups.OpeningBalance.addButton, systemImage: "plus.circle.fill")
                        .font(DS.Typography.label)
                        .foregroundStyle(theme.accent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("opening_balance_add")
            }
            .padding(DS.Spacing.lg)
        }
    }

    private func rollupRow(memberID: String, net: Double, currencyCode: String) -> some View {
        let name = viewModel.memberNameLookup[memberID] ?? "?"
        let word = net > 0 ? L10n.Groups.OpeningBalance.rollupOwed : L10n.Groups.OpeningBalance.rollupOwes
        let amountStr = appPreferences.currency(abs(net), currencyCode: currencyCode)
        return HStack {
            Text(name)
                .font(DS.Typography.label)
                .foregroundStyle(.primary)
            Spacer()
            Text("\(word) \(amountStr)")
                .font(DS.Typography.caption)
                .foregroundStyle(net > 0 ? DS.Semantic.successForeground : Color.hotPink)
        }
    }

    private func edgeRow(_ expense: SplitExpense) -> some View {
        let debtorName = debtorID(for: expense).flatMap { viewModel.memberNameLookup[$0] } ?? "?"
        let creditorName = viewModel.memberNameLookup[expense.paidByMemberID] ?? "?"
        let amountStr = appPreferences.currency(expense.amount, currencyCode: expense.currencyCode)
        return Button {
            openingBalanceToEdit = expense
            showOpeningBalanceEditor = true
        } label: {
            HStack(spacing: DS.Spacing.md) {
                Text(L10n.Groups.OpeningBalance.feedRow(debtorName, creditorName))
                    .font(DS.Typography.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer()
                Text(amountStr)
                    .font(DS.Typography.label)
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(DS.Typography.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, DS.FormRow.paddingV)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("opening_balance_edge_\(expense.id)")
    }

    // MARK: - Balance helpers

    /// Duplicado intencional de GroupSettingsView.hasNonZeroBalance: el dialog de remover lo
    /// necesita aquí, pero GroupSettingsView lo conserva para leave/archive. Son 3 líneas
    /// sobre `viewModel.balances` — más limpio que moverlo al VM solo por esto.
    private func hasNonZeroBalance(for memberID: String) -> Bool {
        viewModel.balances
            .filter { $0.memberID == memberID }
            .contains { abs($0.netBalance) > 0.01 }
    }

    private var memberToRemoveHasDebt: Bool {
        guard let member = memberToRemove else { return false }
        return hasNonZeroBalance(for: member.id.uuidString)
    }

    // MARK: - Actions

    private func createShareLink() async {
        guard group.isOwner else { return }
        guard !isCreatingShare else { return }

        // Return cached URL if available
        if shareURL != nil {
            showShareSheet = true
            return
        }

        isCreatingShare = true
        do {
            // Fase 3: el `else` era el CKShare y ya no existe canal que lo sirva. El guard se conserva
            // ENTERO —flag + zona backend— y su rama negativa informa: un grupo legacy no se puede invitar
            // por ninguna vía, y dejar el botón mudo sería el apagón silencioso que la re-medición marca
            // como peor modo de fallo (§S5.2).
            if CloudSyncFlags.groupsBackendEnabled && group.isBackendGroup {
                // C4: grupo backend → invite por TOKEN RPC (link ya branded). Cache in-VM (`shareURL != nil`,
                // arriba) conservado. Nota A1: el flag cubre "no emitir hasta que el parser esté desplegado".
                let name = SessionDefaults.current.string(forKey: "userName") ?? ""
                let inviterName = name.isEmpty ? L10n.Profile.defaultName : name
                shareURL = try await GroupBackendInviteService(
                    membership: GroupBackendMembershipService(
                        client: GroupsMembershipClient(attestProvider: AttestSessionProvider.live))
                ).createInviteLink(for: group, inviterName: inviterName, members: viewModel.activeMembers)
            } else {
                isCreatingShare = false
                shareErrorMessage = L10n.Groups.Errors.inviteFailed
                showShareError = true
                return
            }
            isCreatingShare = false
            if shareURL != nil {
                showShareSheet = true
            }
        } catch {
            isCreatingShare = false
            shareErrorMessage = L10n.Groups.Errors.inviteFailed
            showShareError = true
        }
    }


    private func changeRole(_ member: SplitMember) {
        let newRole = member.role == "admin" ? "member" : "admin"
        do {
            try GroupService.shared.changeRole(member, to: newRole, in: group)
            viewModel.loadData()
        } catch {
            actionErrorMessage = error.localizedDescription
            showActionError = true
        }
    }

    private func removeMember() {
        guard let member = memberToRemove else { return }
        memberToRemove = nil
        // `removeMember` es `async` (C5: grupo backend rutea a un RPC). Con flag OFF no suspende.
        Task {
            do {
                try await GroupService.shared.removeMember(member, from: group)
                viewModel.loadData()
                DS.Haptic.warning()
            } catch {
                actionErrorMessage = error.localizedDescription
                showActionError = true
            }
        }
    }
}
