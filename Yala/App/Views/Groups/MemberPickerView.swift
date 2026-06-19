//
//  MemberPickerView.swift
//  Yala
//
//  Selector de miembros — single select ("Pagado por") y multi-select ("Dividir entre").
//

import SwiftUI

enum MemberPickerMode {
    case singleSelect
    case multiSelect
}

struct MemberPickerView: View {

    @Environment(\.dismiss) private var dismiss

    let members: [SplitMember]
    let memberNameLookup: [String: String]
    let groupColorHex: String
    let mode: MemberPickerMode

    @ScaledMetric(relativeTo: .body) private var avatarSize: CGFloat = 36 // A11Y-DT: @ScaledMetric

    // Single select
    @Binding var selectedMemberID: String

    // Multi select
    @Binding var selectedMemberIDs: Set<String>
    let onSelectAll: () -> Void
    let onDeselectAll: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.none) {
                    ForEach(members, id: \.id) { member in
                        let id = member.id.uuidString

                        if mode == .singleSelect {
                            singleRow(member: member, id: id)
                        } else {
                            multiRow(member: member, id: id)
                        }

                        if member.id != members.last?.id {
                            Divider()
                                .padding(.leading, DS.FormRow.paddingH)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                        .fill(.thCard)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                        .stroke(.thCardBorder, lineWidth: 1)
                )
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.sm)
            }
            .yalaScreenBackground(.subtle)
            .navigationTitle(mode == .singleSelect ? L10n.Groups.Expense.paidByTitle : L10n.Groups.Expense.divideBetween)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                }

                if mode == .multiSelect {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button(L10n.Groups.Expense.selectAll) { onSelectAll() }
                            Button(L10n.Groups.Expense.deselectAll) { onDeselectAll() }
                        } label: {
                            Text(L10n.Groups.Expense.membersSelected(selectedMemberIDs.count, members.count))
                                .font(DS.Typography.caption)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Single Select Row

    private func singleRow(member: SplitMember, id: String) -> some View {
        Button {
            selectedMemberID = id
            dismiss()
        } label: {
            HStack(spacing: DS.Spacing.md) {
                memberAvatar(member)
                memberName(member)
                Spacer()
                if selectedMemberID == id {
                    Image(systemName: "checkmark")
                        .font(DS.Typography.body)
                        .foregroundStyle(.thAccent)
                }
            }
            .padding(.horizontal, DS.FormRow.paddingH)
            .padding(.vertical, DS.FormRow.paddingV)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Multi Select Row

    private func multiRow(member: SplitMember, id: String) -> some View {
        let isSelected = selectedMemberIDs.contains(id)

        return Button {
            if isSelected {
                selectedMemberIDs.remove(id)
            } else {
                selectedMemberIDs.insert(id)
            }
        } label: {
            HStack(spacing: DS.Spacing.md) {
                memberAvatar(member)
                memberName(member)
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(DS.Typography.headline)
                    .foregroundStyle(isSelected ? Color.electricIndigo : Color.secondary)
            }
            .padding(.horizontal, DS.FormRow.paddingH)
            .padding(.vertical, DS.FormRow.paddingV)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Components

    private func memberAvatar(_ member: SplitMember) -> some View {
        ZStack {
            Circle()
                .fill(Color(hex: groupColorHex).opacity(0.2))
                .frame(width: avatarSize, height: avatarSize)

            Text(String(member.displayName.prefix(1)).uppercased())
                .font(DS.Typography.label)
                .foregroundStyle(Color(hex: groupColorHex))
        }
    }

    private func memberName(_ member: SplitMember) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            Text(member.displayName)
                .font(DS.Typography.body)
                .foregroundStyle(member.isActive ? .primary : .secondary)

            if member.isCurrentUser {
                Text(L10n.Groups.Member.you)
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(.secondary)
            }

            if !member.isActive {
                Text(member.memberStatus == .left ? L10n.Groups.Member.left : L10n.Groups.Member.removed)
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
