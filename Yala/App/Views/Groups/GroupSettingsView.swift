//
//  GroupSettingsView.swift
//  Yala
//
//  Sheet de ajustes del grupo — info, miembros, opciones, acciones destructivas.
//

import SwiftUI
import SwiftData

struct GroupSettingsView: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.yalaTheme) private var theme

    // MARK: - Input

    let group: SplitGroup
    @Bindable var viewModel: GroupDetailViewModel

    // MARK: - State

    @State private var editName: String = ""
    @State private var editIconName: String = ""
    @State private var editColorHex: String = ""
    @State private var showIconPicker: Bool = false
    @State private var isCreatingShare = false
    @State private var shareURL: URL?
    @State private var hasExistingShare = false
    @State private var showShareSheet = false
    @State private var showRemoveMemberConfirm = false
    @State private var memberToRemove: SplitMember?
    @State private var simplifyDebts: Bool = false
    @State private var showDebtsInSingleCurrency: Bool = false
    @State private var selectedCurrency: CurrencyCode = .pen
    @State private var showCurrencyPicker: Bool = false
    @State private var defaultSplitType: SplitType = .equal

    // Leave group
    @State private var showLeaveGroupConfirm = false
    @State private var isLeavingGroup = false
    @State private var showLeaveError = false
    @State private var leaveErrorMessage: String = ""
    @State private var showShareError = false
    @State private var shareErrorMessage: String = ""
    @State private var showActionError = false
    @State private var actionErrorMessage: String = ""

    @State private var pendingActionMember: SplitMember?
    @State private var showApproveConfirm: Bool = false
    @State private var showRejectConfirm: Bool = false
    @State private var pendingErrorMessage: String?
    @State private var showPendingError: Bool = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.xxl) {
                    // Info section
                    infoSection

                    // Members section
                    membersSection

                    // Group options section
                    optionsSection

                    // Leave group (non-owner)
                    if !group.isOwner {
                        leaveGroupSection
                    }

                    // Danger zone (archive)
                    if viewModel.isCurrentUserAdmin {
                        dangerZoneSection
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.xl)
                .dismissKeyboardOnTap()
            }
            .scrollDismissesKeyboard(.interactively)
            .background(.thBackground)
            .onDisappear { saveIdentity() }
            .task {
                hasExistingShare = await SplitZoneManager(syncManager: .shared).hasShare(for: group)
            }
            .navigationTitle(L10n.Groups.Settings.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showCurrencyPicker) {
                NavigationStack {
                    CurrencySelectorView(selectedCurrency: $selectedCurrency)
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = shareURL {
                    ActivityView(activityItems: [url])
                        }
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
                L10n.Groups.Settings.leaveGroup,
                isPresented: $showLeaveGroupConfirm,
                titleVisibility: .visible
            ) {
                Button(L10n.Groups.Settings.leaveGroup, role: .destructive) {
                    Task { await leaveGroup() }
                }
            } message: {
                if hasOutstandingBalance {
                    Text(L10n.Groups.Settings.leaveGroupWithDebtWarning)
                } else {
                    Text(L10n.Groups.Settings.leaveGroupConfirm)
                }
            }
            .alert(L10n.Common.error, isPresented: $showLeaveError) {
                Button(L10n.Common.ok) {}
            } message: {
                Text(leaveErrorMessage)
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
        }
    }

    // MARK: - Info Section

    private var infoSection: some View {
        SectionBox(title: L10n.Groups.Settings.info) {
            HStack(spacing: DS.Spacing.md) {
                if viewModel.isCurrentUserAdmin {
                    // Group icon — tappable to change (admin only)
                    Button {
                        showIconPicker = true
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color(hex: editColorHex))
                                .frame(width: 48, height: 48) // A11Y-DT: fixed icon size matching CategoryDetailView pattern

                            Image(systemName: editIconName)
                                .font(DS.Typography.title2)
                                .foregroundStyle(.white)

                            // A11Y-DT: decorative edit badge on group icon
                            Image(systemName: "pencil.circle.fill")
                                .font(DS.Typography.label)
                                .foregroundStyle(Color(hex: editColorHex))
                                .background(Circle().fill(.white).frame(width: 16, height: 16))
                                .offset(x: 16, y: 16)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.Groups.Form.icon)

                    // Group name — editable inline (admin only)
                    TextField(L10n.Groups.Form.namePlaceholder, text: $editName)
                        .font(DS.Typography.headline)
                        .onSubmit { saveIdentity() }
                } else {
                    // Group icon — static (non-admin)
                    ZStack {
                        Circle()
                            .fill(Color(hex: editColorHex))
                            .frame(width: 48, height: 48) // A11Y-DT: fixed icon size matching CategoryDetailView pattern

                        Image(systemName: editIconName)
                            .font(DS.Typography.title2)
                            .foregroundStyle(.white)
                    }

                    // Group name — read-only (non-admin)
                    Text(editName)
                        .font(DS.Typography.headline)
                }
            }
            .padding(.horizontal, DS.FormRow.paddingH)
            .padding(.vertical, DS.FormRow.paddingV)
        }
        .onAppear {
            editName = group.name
            editIconName = group.iconName
            editColorHex = group.colorHex
        }
        .sheet(isPresented: $showIconPicker, onDismiss: {
            saveIdentity()
        }) {
            IconColorPickerSheet(
                selectedIconName: $editIconName,
                selectedColorHex: $editColorHex
            )
        }
    }

    // MARK: - Members Section

    private var membersSection: some View {
        SectionBox(title: L10n.Groups.Settings.members) {
            VStack(spacing: DS.Spacing.none) {
                ForEach(viewModel.visibleMembers, id: \.id) { member in
                    GroupMemberRow(
                        member: member,
                        groupColorHex: group.colorHex,
                        isCurrentUserAdmin: viewModel.isCurrentUserAdmin,
                        onChangeRole: { changeRole(member) },
                        onRemove: {
                            memberToRemove = member
                            showRemoveMemberConfirm = true
                        },
                        onApprove: viewModel.isCurrentUserAdmin && member.isPendingApproval ? {
                            pendingActionMember = member
                            showApproveConfirm = true
                        } : nil,
                        onReject: viewModel.isCurrentUserAdmin && member.isPendingApproval ? {
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
                if group.isOwner && viewModel.isCurrentUserAdmin {
                    Divider()
                    Button {
                        Task { await createShareLink() }
                    } label: {
                        HStack(spacing: DS.Spacing.md) {
                            Image(systemName: "link.badge.plus")
                                .font(DS.Typography.title2)
                                .foregroundStyle(.thAccent)

                            Text(L10n.Groups.Settings.invite)
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
        runPendingMemberAction(label: "approveMember", GroupService.shared.approveMember)
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
            print("GroupSettingsView: \(label) failed: \(error)")
            #endif
        }
        pendingActionMember = nil
    }

    // MARK: - Options Section

    private var optionsSection: some View {
        SectionBox(title: L10n.Groups.Settings.options) {
            VStack(spacing: DS.Spacing.none) {
                // Simplify Debts
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Toggle(L10n.Groups.Form.simplifyDebts, isOn: $simplifyDebts)
                        .font(DS.Typography.body)

                    Text(L10n.Groups.Form.simplifyDebtsHint)
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, DS.FormRow.paddingH)
                .padding(.vertical, DS.FormRow.paddingV)
                .onChange(of: simplifyDebts) { _, newValue in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        updateGroupOption { $0.simplifyDebts = newValue }
                    }
                }

                // Admin-only options
                if viewModel.isCurrentUserAdmin {
                    Divider()
                        .padding(.leading, DS.FormRow.paddingH)

                    // Show debts in single currency
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Toggle(L10n.Groups.Form.showDebtsInSingleCurrency, isOn: $showDebtsInSingleCurrency)
                            .font(DS.Typography.body)

                        Text(L10n.Groups.Form.showDebtsInSingleCurrencyHint)
                            .font(DS.Typography.captionSmall)
                            .foregroundStyle(.secondary)

                        if showDebtsInSingleCurrency {
                            Button {
                                showCurrencyPicker = true
                            } label: {
                                HStack(spacing: DS.Spacing.md) {
                                    let info = currencyInfo(for: selectedCurrency)
                                    Text(info.flag)
                                        .font(DS.Typography.body)

                                    Text(info.code)
                                        .font(DS.Typography.body)
                                        .foregroundStyle(.primary)

                                    Spacer()

                                    Text(info.name.capitalized)
                                        .font(DS.Typography.captionSmall)
                                        .foregroundStyle(.secondary)

                                    Image(systemName: "chevron.right")
                                        .font(DS.Typography.captionSmall)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, DS.Spacing.sm)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, DS.FormRow.paddingH)
                    .padding(.vertical, DS.FormRow.paddingV)
                    .onChange(of: showDebtsInSingleCurrency) { _, newValue in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            updateGroupOption { $0.showDebtsInSingleCurrency = newValue }
                        }
                    }
                    .onChange(of: selectedCurrency) { _, newValue in
                        updateGroupOption { $0.currencyCode = newValue.rawValue }
                    }

                    Divider()
                        .padding(.leading, DS.FormRow.paddingH)

                    // Default split type
                    HStack {
                        Text(L10n.Groups.Form.defaultSplitType)
                            .font(DS.Typography.body)

                        Spacer()

                        Picker("", selection: $defaultSplitType) {
                            ForEach(SplitType.allCases) { type in
                                Text(type.displayName).tag(type)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    .padding(.horizontal, DS.FormRow.paddingH)
                    .padding(.vertical, DS.FormRow.paddingV)
                    .onChange(of: defaultSplitType) { _, newValue in
                        updateGroupOption { $0.defaultSplitType = newValue.rawValue }
                    }

                }
            }
        }
        .onAppear {
            simplifyDebts = group.simplifyDebts
            showDebtsInSingleCurrency = group.showDebtsInSingleCurrency
            selectedCurrency = CurrencyCode(rawValue: group.currencyCode) ?? .pen
            defaultSplitType = SplitType(rawValue: group.defaultSplitType) ?? .equal
        }
    }

    // MARK: - Danger Zone (Archive)

    private var dangerZoneSection: some View {
        VStack(spacing: DS.Spacing.none) {
            Button {
                toggleArchive()
            } label: {
                HStack {
                    Image(systemName: group.isArchived ? "archivebox.fill" : "archivebox")
                        .foregroundStyle(DS.Semantic.errorForeground)
                    Text(group.isArchived ? L10n.Groups.Settings.unarchive : L10n.Groups.Settings.archive)
                        .font(DS.Typography.body)
                        .foregroundStyle(DS.Semantic.errorForeground)
                    Spacer()
                }
                .padding(.horizontal, DS.FormRow.paddingH)
                .padding(.vertical, DS.FormRow.paddingV)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .background(RoundedRectangle(cornerRadius: DS.Radius.card).fill(.thCard))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.card).stroke(.thCardBorder, lineWidth: 1))
    }

    // MARK: - Leave Group

    private var leaveGroupSection: some View {
        VStack(spacing: DS.Spacing.xs) {
            Button {
                showLeaveGroupConfirm = true
            } label: {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .foregroundStyle(DS.Semantic.errorForeground)
                    Text(L10n.Groups.Settings.leaveGroup)
                        .font(DS.Typography.body)
                        .foregroundStyle(DS.Semantic.errorForeground)
                    Spacer()
                    if isLeavingGroup {
                        ProgressView()
                    }
                }
                .padding(.horizontal, DS.FormRow.paddingH)
                .padding(.vertical, DS.FormRow.paddingV)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isLeavingGroup)
        }
        .background(RoundedRectangle(cornerRadius: DS.Radius.card).fill(.thCard))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.card).stroke(.thCardBorder, lineWidth: 1))
    }

    private func hasNonZeroBalance(for memberID: String) -> Bool {
        viewModel.balances
            .filter { $0.memberID == memberID }
            .contains { abs($0.netBalance) > 0.01 }
    }

    private var memberToRemoveHasDebt: Bool {
        guard let member = memberToRemove else { return false }
        return hasNonZeroBalance(for: member.id.uuidString)
    }

    private var hasOutstandingBalance: Bool {
        let current: SplitMember? = {
            if let recordName = GroupUserIdentityService.shared.cachedRecordName, !recordName.isEmpty {
                return viewModel.members.first(where: { $0.cloudKitUserRecordID == recordName })
            }
            return viewModel.currentUserMember
        }()
        guard let current else { return false }
        return hasNonZeroBalance(for: current.id.uuidString)
    }

    private func leaveGroup() async {
        guard !isLeavingGroup else { return }
        isLeavingGroup = true
        defer { isLeavingGroup = false }

        do {
            try await GroupService.shared.leaveGroup(group)
            DS.Haptic.success()
            dismiss()
        } catch {
            DS.Haptic.warning()
            leaveErrorMessage = error.localizedDescription
            showLeaveError = true
        }
    }

    // MARK: - Actions

    private func saveIdentity() {
        let trimmedName = editName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        let nameChanged = trimmedName != group.name
        let iconChanged = editIconName != group.iconName
        let colorChanged = editColorHex != group.colorHex
        guard nameChanged || iconChanged || colorChanged else { return }

        do {
            try GroupService.shared.updateGroup(
                group,
                name: trimmedName,
                iconName: editIconName,
                colorHex: editColorHex,
                currencyCode: group.currencyCode,
                simplifyDebts: group.simplifyDebts,
                showDebtsInSingleCurrency: group.showDebtsInSingleCurrency,
                defaultSplitType: group.defaultSplitType,
                membersCanInvite: group.membersCanInvite
            )
            viewModel.loadData()
        } catch {
            actionErrorMessage = error.localizedDescription
            showActionError = true
        }
    }

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
            let (_, ckURL) = try await SplitZoneManager(syncManager: .shared).createShare(for: group)
            if let ckURL {
                shareURL = buildBrandedInviteURL(from: ckURL)
            }
            isCreatingShare = false
            if shareURL != nil {
                hasExistingShare = true
                showShareSheet = true
            }
        } catch {
            isCreatingShare = false
            shareErrorMessage = error.localizedDescription
            showShareError = true
        }
    }

    private func buildBrandedInviteURL(from ckURL: URL) -> URL {
        let name = UserDefaults.standard.string(forKey: "userName") ?? ""
        let inviterName = name.isEmpty ? "Usuario" : name
        return InviteLinkService.buildInviteURL(
            shareURL: ckURL,
            group: group,
            members: viewModel.activeMembers,
            inviterName: inviterName
        ) ?? ckURL
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
        do {
            try GroupService.shared.removeMember(member, from: group)
            viewModel.loadData()
            DS.Haptic.warning()
        } catch {
            actionErrorMessage = error.localizedDescription
            showActionError = true
        }
        memberToRemove = nil
    }

    private func toggleArchive() {
        do {
            let willArchive = !group.isArchived
            try GroupService.shared.setArchived(group, isArchived: willArchive)
            if willArchive { TelemetryService.track(.groupArchived) }
            DS.Haptic.success()
            viewModel.loadData()
            if group.isArchived {
                dismiss()
            }
        } catch {
            actionErrorMessage = error.localizedDescription
            showActionError = true
        }
    }

    private func updateGroupOption(_ update: (SplitGroup) -> Void) {
        update(group)
        do {
            try GroupService.shared.updateGroup(
                group,
                name: group.name,
                iconName: group.iconName,
                colorHex: group.colorHex,
                currencyCode: group.currencyCode,
                simplifyDebts: group.simplifyDebts,
                showDebtsInSingleCurrency: group.showDebtsInSingleCurrency,
                defaultSplitType: group.defaultSplitType,
                membersCanInvite: group.membersCanInvite
            )
            viewModel.loadData()
        } catch {
            actionErrorMessage = error.localizedDescription
            showActionError = true
        }
    }

}
