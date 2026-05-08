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
    var onApprove: (() -> Void)? = nil
    var onReject: (() -> Void)? = nil

    @ScaledMetric(relativeTo: .body) private var avatarSize: CGFloat = 36 // A11Y-DT: @ScaledMetric

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            // Avatar
            avatar

            // Name + role
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                HStack(spacing: DS.Spacing.xs) {
                    Text(member.displayName)
                        .font(DS.Typography.body)
                        .foregroundStyle(member.isActive ? .primary : .secondary)

                    if member.isCurrentUser {
                        Text(L10n.Groups.Member.you)
                            .font(DS.Typography.captionSmall)
                            .foregroundStyle(.secondary)
                    }
                }

                if member.role == "admin" {
                    adminBadge
                }

                statusBadge
            }

            Spacer()

            // Admin actions
            if isCurrentUserAdmin && !member.isCurrentUser && !member.isGroupOwner {
                if member.memberStatus == .pendingApproval, let onApprove, let onReject {
                    HStack(spacing: DS.Spacing.sm) {
                        Button(action: onApprove) {
                            Text(L10n.Groups.Member.approve)
                                .font(DS.Typography.labelSmall)
                                .foregroundStyle(.white)
                                .padding(.horizontal, DS.Spacing.md)
                                .padding(.vertical, DS.Spacing.sm)
                                .background(.thAccent, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                        }
                        .buttonStyle(.plain)

                        Button(action: onReject) {
                            Text(L10n.Groups.Member.reject)
                                .font(DS.Typography.labelSmall)
                                .foregroundStyle(DS.Semantic.errorForeground)
                                .padding(.horizontal, DS.Spacing.md)
                                .padding(.vertical, DS.Spacing.sm)
                                .background(DS.Semantic.errorBackground, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                        }
                        .buttonStyle(.plain)
                    }
                } else if member.isActive {
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
        }
        .padding(.horizontal, DS.FormRow.paddingH)
        .padding(.vertical, DS.FormRow.paddingV)
        // #20-bis: pending mantiene opacity 1.0 para que botones aprobar/rechazar
        // sean prominentes. Solo estados no-actionable (left/removed/rejected) se dimean.
        .opacity(member.isActive || member.isPendingApproval ? 1 : 0.72)
    }

    // MARK: - Components

    private var avatar: some View {
        ZStack {
            Circle()
                .fill(Color(hex: groupColorHex).opacity(0.2))
                .frame(width: avatarSize, height: avatarSize)

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

    @ViewBuilder
    private var statusBadge: some View {
        if member.memberStatus != .active {
            let (text, fg, bg): (String, Color, Color) = {
                switch member.memberStatus {
                case .pendingApproval:
                    return (L10n.Groups.Member.statusPending, DS.Semantic.warningForeground, DS.Semantic.warningBackground)
                case .rejected:
                    return (L10n.Groups.Member.statusRejected, DS.Semantic.errorForeground, DS.Semantic.errorBackground)
                case .left:
                    return (L10n.Groups.Member.left, .secondary, Color.secondary.opacity(0.12))
                case .removed:
                    return (L10n.Groups.Member.removed, .secondary, Color.secondary.opacity(0.12))
                case .active:
                    return ("", .clear, .clear)
                }
            }()
            Text(text)
                .font(DS.Typography.captionSmall)
                .foregroundStyle(fg)
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, DS.Spacing.xxs)
                .background(Capsule().fill(bg))
        }
    }

    private var initialLetter: String {
        String(member.displayName.prefix(1)).uppercased()
    }
}
