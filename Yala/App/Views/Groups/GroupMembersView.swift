//
//  GroupMembersView.swift
//  Yala
//
//  Sheet dedicada de Miembros — lista, roles, aprobar/rechazar, invitar por enlace
//  y saldos iniciales (owner). Se abre desde el botón "Miembros" del toolbar del detalle.
//  Separada de GroupSettingsView para que cada botón del toolbar tenga un significado
//  nítido: personas (este) vs configuración del grupo (engranaje).
//
//  Desde el lote 19 decidido de la auditoría UX 2.2 es la lista agrupada de Ajustes (lienzo «Una sola Yala»), cada
//  persona lleva a la derecha lo que se deben contigo, el rol se cambia con «Hacer/Quitar como administrador»
//  y una confirmación que dice qué podrá hacer (L19-3), y quitar a alguien que debe dice cuánto y a quién, con
//  «Saldar primero» (L19-4).
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
    /// `.sheet(item:)`: con `isPresented` y el enlace en otro `@State`, la hoja de compartir puede salir vacía (regla de
    /// `swiftui-ds.md`).
    @State private var shareItem: ShareItem?

    private struct ShareItem: Identifiable {
        let id = UUID()
        let url: URL
    }
    @State private var showShareError = false
    @State private var shareErrorMessage: String = ""

    // Remove member. Dos diálogos y no uno con un botón condicional: los botones de una presentación no admiten
    // contenido que dependa del estado (regla medida el 2026-09-06). Con deuda lleva «Saldar primero» (L19-4).
    @State private var showRemoveMemberConfirm = false
    @State private var showRemoveWithDebtConfirm = false
    @State private var memberToRemove: SplitMember?

    // Cambiar el rol (L19-3). Un diálogo por sentido, por lo mismo.
    @State private var roleChangeMember: SplitMember?
    /// El rol que se preguntó, fijado al abrir la confirmación: si el pull cambia el rol con el diálogo abierto, confirmar
    /// «Hacer administrador» no puede acabar degradando (review adversarial del 21-oct).
    @State private var roleChangeTarget: String?
    @State private var showMakeAdminConfirm = false
    @State private var showRemoveAdminConfirm = false

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
            YalaSettingsList {
                // L19-1 · las solicitudes van arriba, una tarjeta por persona, con su consecuencia y sus dos botones.
                if canActAsAdmin && !viewModel.pendingApprovalMembers.isEmpty {
                    Section {
                        joinRequestsSection
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                // L12-13: invitar es lo primero que se ve tras las solicitudes, y es la única tarjeta destacada de la hoja.
                if group.isOwner && canActAsAdmin {
                    Section {
                        inviteCard
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                membersSection

                // Saldos iniciales (deuda de apertura) — owner-only.
                if group.isOwner {
                    openingBalanceSection
                }
            }
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
            .sheet(item: $shareItem) { item in
                // L12-14 · el enlace viaja con un texto que dice qué es y qué hacer si aún no tiene Yala.
                ActivityView(activityItems: [GroupInviteShareMessage.text(
                    inviterName: UserDefaults.standard.string(forKey: AppPreferences.Keys.userName),
                    defaultName: L10n.Profile.defaultName,
                    groupName: group.name,
                    url: item.url)])
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
                .yalaSheetDetents([.large])
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
                .accessibilityIdentifier("opening_balance_prompt_add")
                Button(L10n.Groups.OpeningBalance.approvalPromptSkip) {
                    openingBalancePrefillDebtor = nil
                }
                .accessibilityIdentifier("opening_balance_prompt_skip")
            } message: {
                Text(L10n.Groups.OpeningBalance.approvalPromptBody)
            }
            .confirmationDialog(
                memberToRemove.map { L10n.UXL19.removeTitle($0.resolvedDisplayName) } ?? "",
                isPresented: $showRemoveMemberConfirm,
                titleVisibility: .visible
            ) {
                Button(L10n.UXL19.removeMember, role: .destructive) {
                    removeMember()
                }
                .accessibilityIdentifier("group_member_remove_confirm")
                Button(L10n.Common.cancel) { memberToRemove = nil }
                    .accessibilityIdentifier("group_member_remove_cancel")
            } message: {
                Text(memberToRemove.map { L10n.UXL19.removeBody($0.resolvedDisplayName) } ?? "")
            }
            .confirmationDialog(
                memberToRemove.map { L10n.UXL19.removeTitle($0.resolvedDisplayName) } ?? "",
                isPresented: $showRemoveWithDebtConfirm,
                titleVisibility: .visible
            ) {
                Button(L10n.UXL19.removeMember, role: .destructive) {
                    removeMember()
                }
                .accessibilityIdentifier("group_member_remove_confirm")
                Button(L10n.UXL19.settleFirst) { settleFirstWithMemberToRemove() }
                    .accessibilityIdentifier("group_member_remove_settle_first")
                Button(L10n.Common.cancel) { memberToRemove = nil }
                    .accessibilityIdentifier("group_member_remove_with_debt_cancel")
            } message: {
                Text(removeWithDebtMessage)
            }
            .modifier(RoleChangePresentations(
                memberName: roleChangeMember?.resolvedDisplayName ?? "",
                showMakeAdminConfirm: $showMakeAdminConfirm,
                showRemoveAdminConfirm: $showRemoveAdminConfirm,
                onConfirm: { performRoleChange() },
                onCancel: { roleChangeMember = nil; roleChangeTarget = nil }
            ))
            // L19-1 · el mismo verbo que la tarjeta («Aceptar»): «Aprobar» en la confirmación eran dos palabras para un gesto.
            .confirmationDialog(
                pendingActionMember.map { L10n.UXD14.requestsAcceptConfirm($0.displayName) } ?? "",
                isPresented: $showApproveConfirm,
                titleVisibility: .visible
            ) {
                Button(L10n.UXD14.requestsAccept) { performApprove() }
                    .accessibilityIdentifier("group_member_approve_confirm")
                Button(L10n.Common.cancel) { pendingActionMember = nil }
                    .accessibilityIdentifier("group_member_approve_cancel")
            }
            .confirmationDialog(
                pendingActionMember.map { L10n.Groups.Member.rejectConfirm($0.displayName) } ?? "",
                isPresented: $showRejectConfirm,
                titleVisibility: .visible
            ) {
                Button(L10n.Groups.Member.reject, role: .destructive) { performReject() }
                Button(L10n.Common.cancel) { pendingActionMember = nil }
                    .accessibilityIdentifier("group_member_reject_cancel")
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
            #if DEBUG
            .onAppear {
                // L19-2 · la pregunta que sigue a aceptar, sin el servidor que la aceptación necesita (XCUITest y capturas).
                if UITestHooks.openingBalancePrompt, !showOpeningBalanceApprovalPrompt {
                    approvedMemberName = "Carla"
                    showOpeningBalanceApprovalPrompt = true
                }
            }
            #endif
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
        YalaSettingsSection(L10n.Groups.Settings.members) {
            ForEach(listedMembers, id: \.id) { member in
                GroupMemberRow(
                    member: member,
                    groupColorHex: group.colorHex,
                    isCurrentUserAdmin: canActAsAdmin,
                    // El flag O la identidad resuelta: la unión de los dos criterios, nunca uno
                    // solo. Una zona MIGRADA puede tener DOS filas del mismo humano con el flag
                    // puesto —`refreshCurrentUserFlags` conserva el de la fila legacy
                    // (GroupService:1136) y enciende el de la born-backend por `sub`—, y el
                    // resolvedor devuelve UNA (la de `min(joinedAt)`). Comparar solo contra ella
                    // dejaría la otra fila propia con «quitar» y «cambiar rol» a la vista, que es
                    // justo la regresión que este parámetro venía a evitar.
                    isSelf: member.isCurrentUser
                        || member.id.uuidString == viewModel.currentMemberID,
                    roleChangeOffer: GroupService.shared.roleChangeOffer(for: member, in: group),
                    relation: relation(with: member),
                    onChangeRole: { askRoleChange(member) },
                    onRemove: { askRemove(member) },
                    onApprove: canActAsAdmin && member.isPendingApproval ? {
                        pendingActionMember = member
                        showApproveConfirm = true
                    } : nil,
                    onReject: canActAsAdmin && member.isPendingApproval ? {
                        pendingActionMember = member
                        showRejectConfirm = true
                    } : nil
                )
            }
        }
    }

    /// La lista de Miembros. Para quien puede aceptar, sin las solicitudes: esas ya tienen su tarjeta arriba (L19-1), y
    /// repetirlas abajo con dos iconos sería el mismo gesto en dos sitios.
    private var listedMembers: [SplitMember] {
        canActAsAdmin ? viewModel.visibleMembers.filter { !$0.isPendingApproval } : viewModel.visibleMembers
    }

    /// L19-1 · «Quieren unirse (N)»: una tarjeta por solicitud. Aceptar y rechazar pasan por las mismas confirmaciones de
    /// siempre.
    private var joinRequestsSection: some View {
        let pending = viewModel.pendingApprovalMembers.sorted { $0.joinedAt < $1.joinedAt }
        // La cabecera imita la de las secciones de la lista (letra, color y sangría de «Miembros»); el cuerpo no, porque
        // cada solicitud ya es su propia tarjeta y dentro de otra quedaría una tarjeta en una tarjeta.
        return VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(L10n.UXD14.requestsSection(pending.count))
                .font(DS.Typography.headline)
                .foregroundStyle(.thSecondaryText)
                .padding(.leading, DS.Spacing.lg)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: DS.Spacing.md) {
                ForEach(pending, id: \.id) { member in
                    GroupJoinRequestCard(
                        name: member.resolvedDisplayName,
                        idName: member.displayName,
                        requestedAt: member.joinedAt,
                        onAccept: {
                            pendingActionMember = member
                            showApproveConfirm = true
                        },
                        onReject: {
                            pendingActionMember = member
                            showRejectConfirm = true
                        }
                    )
                }
            }
        }
        .accessibilityIdentifier("group_join_requests_section")
    }

    /// Lo que esta persona y tú se deben, de las deudas que enseña el grupo (respeta «simplificar» y «moneda única»).
    private func relation(with member: SplitMember) -> GroupMemberRow.Relation? {
        guard let me = viewModel.currentMemberID, member.id.uuidString != me else { return nil }
        let them = member.id.uuidString
        let mine = viewModel.debts.filter {
            ($0.fromMemberID == them && $0.toMemberID == me) || ($0.fromMemberID == me && $0.toMemberID == them)
        }
        let owesYou = mine.filter { $0.fromMemberID == them }
        let youOwe = mine.filter { $0.fromMemberID == me }
        let money: (Double, String) -> String = { appPreferences.currency($0, currencyCode: $1) }
        if !owesYou.isEmpty {
            return .init(direction: .owesYou,
                         amountText: GroupDebtCopyLogic.amounts(owesYou.map { ($0.amount, $0.currencyCode) }, money: money))
        }
        if !youOwe.isEmpty {
            return .init(direction: .youOwe,
                         amountText: GroupDebtCopyLogic.amounts(youOwe.map { ($0.amount, $0.currencyCode) }, money: money))
        }
        return nil
    }

    /// L12-13 · la tarjeta de invitar: pregunta, qué pasa al tocar y un solo botón relleno.
    private var inviteCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(alignment: .top, spacing: DS.Spacing.md) {
                Image(systemName: "link.badge.plus")
                    .font(DS.Typography.title2)
                    .foregroundStyle(Color.electricIndigo)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(L10n.UXL12.inviteTitle)
                        .font(DS.Typography.headline)
                        .foregroundStyle(.primary)
                    Text(L10n.UXL12.inviteMessage)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            YalaPrimaryButton(
                isCreatingShare ? L10n.Groups.Settings.generatingInvite : L10n.UXL12.inviteShare,
                isLoading: isCreatingShare
            ) {
                DS.Haptic.light()
                Task { await createShareLink() }
            }
            .accessibilityIdentifier("group_members_invite_share")
        }
        .padding(DS.Spacing.lg)
        .background(Color.electricIndigo.opacity(0.16), in: RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
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
                pendingErrorMessage = GroupActionErrorLogic.message(for: error)
                showPendingError = true
                pendingActionMember = nil
                #if DEBUG
                print("GroupMembersView: approveMember failed: \(error)")
                #endif
            }
        }
    }

    /// `rejectMember` es `async` desde que el grupo de la nube rechaza en el servidor (card 840m): mismo molde que
    /// `performApprove`. Con el canal de CloudKit no suspende.
    private func performReject() {
        guard let member = pendingActionMember else { return }
        Task {
            do {
                try await GroupService.shared.rejectMember(member, in: group)
                viewModel.loadData()
            } catch {
                pendingErrorMessage = GroupActionErrorLogic.message(for: error)
                showPendingError = true
                #if DEBUG
                print("GroupMembersView: rejectMember failed: \(error)")
                #endif
            }
            pendingActionMember = nil
        }
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
        YalaSettingsSection(L10n.Groups.OpeningBalance.sectionTitle) {
            let rows = rollupRows
            if !rows.isEmpty {
                VStack(spacing: DS.Spacing.xs) {
                    ForEach(rows) { row in
                        rollupRow(memberID: row.memberID, net: row.net, currencyCode: row.currencyCode)
                    }
                }
                .padding(.vertical, DS.Spacing.xxs)
            }

            ForEach(openingExpenses, id: \.id) { expense in
                edgeRow(expense)
            }

            Button {
                openingBalanceToEdit = nil
                openingBalancePrefillDebtor = nil
                showOpeningBalanceEditor = true
            } label: {
                Label(L10n.Groups.OpeningBalance.addButton, systemImage: "plus.circle.fill")
                    .font(DS.Typography.label)
                    .foregroundStyle(theme.accentText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("opening_balance_add")
        } footer: {
            if openingExpenses.isEmpty {
                Text(L10n.Groups.OpeningBalance.emptyState)
            }
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
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("opening_balance_edge_\(expense.id)")
    }

    // MARK: - Quitar a alguien (L19-4)

    /// ¿La persona tiene deuda en el grupo? Las de persona a persona que enseña Saldos, no el saldo neto: el residuo de
    /// redondeo no es una deuda que avisar (`GroupRoundingResidueLogic`, L19-10).
    private func hasOutstandingBalance(_ member: SplitMember) -> Bool {
        GroupRoundingResidueLogic.hasOutstanding(debts: viewModel.debts, memberID: member.id.uuidString)
    }

    private func askRemove(_ member: SplitMember) {
        memberToRemove = member
        if hasOutstandingBalance(member) {
            showRemoveWithDebtConfirm = true
        } else {
            showRemoveMemberConfirm = true
        }
    }

    /// «Ana te debe S/ 80.00. Si la quitas, deja el grupo y esa deuda queda sin saldar.»
    private var removeWithDebtMessage: String {
        guard let member = memberToRemove else { return "" }
        let sentences = GroupDebtCopyLogic.relationSentences(
            about: member.id.uuidString,
            debts: viewModel.debts,
            currentMemberID: viewModel.currentMemberID,
            name: { viewModel.memberName(for: $0) },
            money: { appPreferences.currency($0, currencyCode: $1) }
        )
        guard !sentences.isEmpty else { return L10n.Groups.Member.removeWithDebtWarning }
        return (sentences + [L10n.UXL19.removeDebtTail(member.resolvedDisplayName)]).joined(separator: " ")
    }

    /// «Saldar primero»: con una deuda entre esa persona y tú, «Saldar» con ella; si lo que debe es a otros, Saldos.
    private func settleFirstWithMemberToRemove() {
        guard let member = memberToRemove else { return }
        memberToRemove = nil
        let them = member.id.uuidString
        let me = viewModel.currentMemberID
        let withMe = viewModel.debts.first {
            ($0.fromMemberID == them && $0.toMemberID == me) || ($0.fromMemberID == me && $0.toMemberID == them)
        }
        if let withMe {
            viewModel.requestAfterSheetDismiss(.settle(withMe))
        } else {
            viewModel.requestAfterSheetDismiss(.showBalances)
        }
    }

    // MARK: - Cambiar el rol (L19-3)

    private func askRoleChange(_ member: SplitMember) {
        guard let offer = GroupService.shared.roleChangeOffer(for: member, in: group) else { return }
        roleChangeMember = member
        roleChangeTarget = offer == .makeAdmin ? "admin" : "member"
        switch offer {
        case .makeAdmin: showMakeAdminConfirm = true
        case .removeAdmin: showRemoveAdminConfirm = true
        }
    }

    /// El cambio va al servidor primero en un grupo de la nube (`GroupService.changeRole`, RPC `set_member_role`).
    private func performRoleChange() {
        guard let member = roleChangeMember, let newRole = roleChangeTarget else {
            roleChangeMember = nil
            roleChangeTarget = nil
            return
        }
        roleChangeMember = nil
        roleChangeTarget = nil
        // Ya tiene ese rol (lo cambió otro administrador mientras se preguntaba): no hay nada que hacer.
        guard member.role != newRole else { return }
        Task {
            do {
                try await GroupService.shared.changeRole(member, to: newRole, in: group)
                viewModel.loadData()
                DS.Haptic.success()
            } catch {
                actionErrorMessage = GroupActionErrorLogic.message(for: error)
                showActionError = true
            }
        }
    }

    // MARK: - Actions

    private func createShareLink() async {
        guard group.isOwner else { return }
        guard !isCreatingShare else { return }

        // Return cached URL if available
        if let cached = shareURL {
            shareItem = ShareItem(url: cached)
            return
        }

        isCreatingShare = true
        // El guard del canal y la clasificación del fallo viven en `GroupInviteLinkMaker`, que comparte con la hoja
        // «está listo» de crear un grupo (L12-10).
        let outcome = await GroupInviteLinkMaker.make(for: group, members: viewModel.activeMembers)
        isCreatingShare = false
        switch outcome {
        case .link(let url):
            shareURL = url
            shareItem = ShareItem(url: url)
        case .failed(let message):
            shareErrorMessage = message
            showShareError = true
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
                actionErrorMessage = GroupActionErrorLogic.message(for: error)
                showActionError = true
            }
        }
    }
}

// MARK: - Confirmar el cambio de rol (L19-3)

/// «¿Hacer administrador a Ana?» con lo que podrá hacer, y su contrario. Dos diálogos con botones fijos, en su propio
/// modificador para no alargar la cadena del `body`.
private struct RoleChangePresentations: ViewModifier {
    let memberName: String
    @Binding var showMakeAdminConfirm: Bool
    @Binding var showRemoveAdminConfirm: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                L10n.UXL19.makeAdminTitle(memberName),
                isPresented: $showMakeAdminConfirm,
                titleVisibility: .visible
            ) {
                Button(L10n.UXL19.makeAdmin) { onConfirm() }
                    .accessibilityIdentifier("group_member_make_admin_confirm")
                Button(L10n.Common.cancel) { onCancel() }
                    .accessibilityIdentifier("group_member_make_admin_cancel")
            } message: {
                Text(L10n.UXL19.makeAdminBody(memberName))
            }
            .confirmationDialog(
                L10n.UXL19.removeAdminTitle(memberName),
                isPresented: $showRemoveAdminConfirm,
                titleVisibility: .visible
            ) {
                Button(L10n.UXL19.removeAdmin, role: .destructive) { onConfirm() }
                    .accessibilityIdentifier("group_member_remove_admin_confirm")
                Button(L10n.Common.cancel) { onCancel() }
                    .accessibilityIdentifier("group_member_remove_admin_cancel")
            } message: {
                Text(L10n.UXL19.removeAdminBody(memberName))
            }
    }
}
