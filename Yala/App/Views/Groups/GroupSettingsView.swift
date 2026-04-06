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

    @State private var showEditGroup = false
    @State private var showAddMemberAlert = false
    @State private var newMemberName = ""
    @State private var showLeaveConfirm = false
    @State private var showDeleteConfirm = false
    @State private var showRemoveMemberConfirm = false
    @State private var memberToRemove: SplitMember?
    @State private var simplifyDebts: Bool = false
    @State private var autoCreateTransaction: Bool = true

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.xxl) {
                    // Info section
                    infoSection

                    // Members section
                    membersSection

                    // Options section
                    optionsSection

                    // Danger zone
                    dangerZoneSection
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.xl)
            }
            .background(.thBackground)
            .navigationTitle(L10n.Groups.Settings.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showEditGroup, onDismiss: {
                viewModel.loadData()
            }) {
                GroupFormView(group: group)
            }
            .alert(L10n.Groups.Settings.addMember, isPresented: $showAddMemberAlert) {
                TextField(L10n.Groups.Settings.addMemberPrompt, text: $newMemberName)
                Button(L10n.Action.cancel, role: .cancel) {
                    newMemberName = ""
                }
                Button(L10n.Action.add) {
                    addMember()
                }
            }
            .confirmationDialog(
                L10n.Groups.Settings.leaveGroup,
                isPresented: $showLeaveConfirm,
                titleVisibility: .visible
            ) {
                Button(L10n.Groups.Settings.leaveGroup, role: .destructive) {
                    leaveGroup()
                }
            } message: {
                Text(L10n.Groups.Settings.leaveGroupConfirm)
            }
            .confirmationDialog(
                L10n.Groups.Settings.deleteGroup,
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button(L10n.Groups.Settings.deleteGroup, role: .destructive) {
                    deleteGroup()
                }
            } message: {
                Text(L10n.Groups.Settings.deleteGroupConfirm)
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
                Text(L10n.Groups.Member.removeConfirm)
            }
        }
    }

    // MARK: - Info Section

    private var infoSection: some View {
        SectionBox(title: L10n.Groups.Settings.info) {
            Button {
                showEditGroup = true
            } label: {
                HStack(spacing: DS.Spacing.md) {
                    // Group icon
                    ZStack {
                        Circle()
                            .fill(Color(hex: group.colorHex))
                            .frame(width: 48, height: 48)

                        Image(systemName: group.iconName)
                            .font(DS.Typography.title2)
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                        Text(group.name)
                            .font(DS.Typography.headline)
                            .foregroundStyle(.primary)

                        Text(group.currencyCode)
                            .font(DS.Typography.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, DS.FormRow.paddingH)
                .padding(.vertical, DS.FormRow.paddingV)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
        }
    }

    // MARK: - Members Section

    private var membersSection: some View {
        SectionBox(title: L10n.Groups.Settings.members) {
            VStack(spacing: DS.Spacing.none) {
                ForEach(viewModel.members, id: \.id) { member in
                    GroupMemberRow(
                        member: member,
                        groupColorHex: group.colorHex,
                        isCurrentUserAdmin: viewModel.isCurrentUserAdmin,
                        onChangeRole: { changeRole(member) },
                        onRemove: {
                            memberToRemove = member
                            showRemoveMemberConfirm = true
                        }
                    )

                    if member.id != viewModel.members.last?.id {
                        Divider()
                            .padding(.leading, DS.FormRow.paddingH)
                    }
                }

                // Add member button
                if viewModel.isCurrentUserAdmin {
                    Divider()
                    Button {
                        showAddMemberAlert = true
                    } label: {
                        HStack(spacing: DS.Spacing.md) {
                            Image(systemName: "plus.circle.fill")
                                .font(DS.Typography.title2)
                                .foregroundStyle(.thAccent)

                            Text(L10n.Groups.Settings.addMember)
                                .font(DS.Typography.body)
                                .foregroundStyle(.thAccent)
                        }
                        .padding(.horizontal, DS.FormRow.paddingH)
                        .padding(.vertical, DS.FormRow.paddingV)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                }
            }
        }
    }

    // MARK: - Options Section

    private var optionsSection: some View {
        SectionBox(title: L10n.Groups.Settings.options) {
            VStack(spacing: DS.Spacing.none) {
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
                    updateGroupOption { $0.simplifyDebts = newValue }
                }

                Divider()
                    .padding(.leading, DS.FormRow.paddingH)

                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Toggle(L10n.Groups.Form.autoCreate, isOn: $autoCreateTransaction)
                        .font(DS.Typography.body)

                    Text(L10n.Groups.Form.autoCreateHint)
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, DS.FormRow.paddingH)
                .padding(.vertical, DS.FormRow.paddingV)
                .onChange(of: autoCreateTransaction) { _, newValue in
                    updateGroupOption { $0.autoCreateTransaction = newValue }
                }
            }
        }
        .onAppear {
            simplifyDebts = group.simplifyDebts
            autoCreateTransaction = group.autoCreateTransaction
        }
    }

    // MARK: - Danger Zone

    private var dangerZoneSection: some View {
        SectionBox(title: L10n.Groups.Settings.dangerZone) {
            VStack(spacing: DS.Spacing.none) {
                // Archive / Unarchive
                Button {
                    toggleArchive()
                } label: {
                    HStack {
                        Text(group.isArchived ? L10n.Groups.Settings.unarchive : L10n.Groups.Settings.archive)
                            .font(DS.Typography.body)
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: group.isArchived ? "archivebox" : "archivebox.fill")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, DS.FormRow.paddingH)
                    .padding(.vertical, DS.FormRow.paddingV)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())

                Divider()
                    .padding(.leading, DS.FormRow.paddingH)

                // Leave or Delete
                if group.isOwner {
                    Button {
                        showDeleteConfirm = true
                    } label: {
                        HStack {
                            Text(L10n.Groups.Settings.deleteGroup)
                                .font(DS.Typography.body)
                                .foregroundStyle(DS.Semantic.errorForeground)
                            Spacer()
                            Image(systemName: "trash")
                                .foregroundStyle(DS.Semantic.errorForeground)
                        }
                        .padding(.horizontal, DS.FormRow.paddingH)
                        .padding(.vertical, DS.FormRow.paddingV)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                } else {
                    Button {
                        showLeaveConfirm = true
                    } label: {
                        HStack {
                            Text(L10n.Groups.Settings.leaveGroup)
                                .font(DS.Typography.body)
                                .foregroundStyle(DS.Semantic.errorForeground)
                            Spacer()
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .foregroundStyle(DS.Semantic.errorForeground)
                        }
                        .padding(.horizontal, DS.FormRow.paddingH)
                        .padding(.vertical, DS.FormRow.paddingV)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                }
            }
        }
    }

    // MARK: - Actions

    private func addMember() {
        let name = newMemberName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        do {
            try GroupService.shared.addMember(to: group, displayName: name)
            viewModel.loadData()
            DS.Haptic.success()
        } catch {
            #if DEBUG
            print("GroupSettingsView: Error adding member: \(error)")
            #endif
        }
        newMemberName = ""
    }

    private func changeRole(_ member: SplitMember) {
        let newRole = member.role == "admin" ? "member" : "admin"
        do {
            try GroupService.shared.changeRole(member, to: newRole, in: group)
            viewModel.loadData()
        } catch {
            #if DEBUG
            print("GroupSettingsView: Error changing role: \(error)")
            #endif
        }
    }

    private func removeMember() {
        guard let member = memberToRemove else { return }
        do {
            try GroupService.shared.removeMember(member, from: group)
            viewModel.loadData()
            DS.Haptic.warning()
        } catch {
            #if DEBUG
            print("GroupSettingsView: Error removing member: \(error)")
            #endif
        }
        memberToRemove = nil
    }

    private func toggleArchive() {
        do {
            try GroupService.shared.setArchived(group, isArchived: !group.isArchived)
            viewModel.loadData()
        } catch {
            #if DEBUG
            print("GroupSettingsView: Error toggling archive: \(error)")
            #endif
        }
    }

    private func leaveGroup() {
        do {
            try GroupService.shared.leaveGroup(group)
            dismiss()
        } catch {
            #if DEBUG
            print("GroupSettingsView: Error leaving group: \(error)")
            #endif
        }
    }

    private func deleteGroup() {
        do {
            try GroupService.shared.deleteGroup(group)
            dismiss()
        } catch {
            #if DEBUG
            print("GroupSettingsView: Error deleting group: \(error)")
            #endif
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
                defaultAccountID: group.defaultAccountID,
                autoCreateTransaction: group.autoCreateTransaction
            )
            viewModel.loadData()
        } catch {
            #if DEBUG
            print("GroupSettingsView: Error updating group: \(error)")
            #endif
        }
    }
}
