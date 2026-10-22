//
//  MemberPickerView.swift
//  Yala
//
//  Selector de un miembro (single select) — p. ej. "Pagado por".
//

import SwiftUI

struct MemberPickerView: View {

    @Environment(\.dismiss) private var dismiss

    let members: [SplitMember]
    let groupColorHex: String

    @ScaledMetric(relativeTo: .body) private var avatarSize: CGFloat = 36 // A11Y-DT: @ScaledMetric

    @Binding var selectedMemberID: String

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.none) {
                    ForEach(members, id: \.id) { member in
                        let id = member.id.uuidString

                        singleRow(member: member, id: id)

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
            .navigationTitle(L10n.Groups.Expense.paidByTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Row

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

    // MARK: - Components

    private func memberAvatar(_ member: SplitMember) -> some View {
        ZStack {
            Circle()
                .fill(Color(hex: groupColorHex).opacity(0.2))
                .frame(width: avatarSize, height: avatarSize)

            Text(String(member.resolvedDisplayName.prefix(1)).uppercased())
                .font(DS.Typography.label)
                .foregroundStyle(Color(hex: groupColorHex))
        }
    }

    private func memberName(_ member: SplitMember) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            Text(member.resolvedDisplayName)
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
