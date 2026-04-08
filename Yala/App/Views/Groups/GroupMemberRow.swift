//
//  GroupMemberRow.swift
//  Yala
//
//  Fila de miembro de grupo — avatar, nombre, rol, acciones de admin.
//

import SwiftUI

struct GroupMemberRow: View {

    let member: SplitMember
    let groupColorHex: String
    let isCurrentUserAdmin: Bool
    let onChangeRole: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            // Avatar
            avatar

            // Name + role
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                HStack(spacing: DS.Spacing.xs) {
                    Text(member.displayName)
                        .font(DS.Typography.body)
                        .foregroundStyle(.primary)

                    if member.isCurrentUser {
                        Text(L10n.Groups.Member.you)
                            .font(DS.Typography.captionSmall)
                            .foregroundStyle(.secondary)
                    }
                }

                if member.role == "admin" {
                    adminBadge
                }
            }

            Spacer()

            // Admin actions
            if isCurrentUserAdmin && !member.isCurrentUser {
                Menu {
                    Button {
                        onChangeRole()
                    } label: {
                        Label(L10n.Groups.Member.changeRole, systemImage: "arrow.left.arrow.right")
                    }

                    Button(role: .destructive) {
                        onRemove()
                    } label: {
                        Label(L10n.Groups.Member.remove, systemImage: "person.badge.minus")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(DS.Typography.body)
                        .foregroundStyle(.secondary)
                        .frame(width: DS.Button.actionSize, height: DS.Button.actionSize)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(L10n.Groups.Member.actions)
            }
        }
        .padding(.horizontal, DS.FormRow.paddingH)
        .padding(.vertical, DS.FormRow.paddingV)
    }

    // MARK: - Components

    private var avatar: some View {
        ZStack {
            Circle()
                .fill(Color(hex: groupColorHex).opacity(0.2))
                .frame(width: 36, height: 36)

            Text(initialLetter)
                .font(DS.Typography.label)
                .foregroundStyle(Color(hex: groupColorHex))
        }
    }

    private var adminBadge: some View {
        Text(L10n.Groups.Member.admin)
            .font(DS.Typography.captionSmall)
            .foregroundStyle(.thAccent)
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xxs)
            .background(
                Capsule().fill(.thAccent.opacity(0.12))
            )
    }

    private var initialLetter: String {
        String(member.displayName.prefix(1)).uppercased()
    }
}
