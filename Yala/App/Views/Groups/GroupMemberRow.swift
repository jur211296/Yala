//
//  GroupMemberRow.swift
//  Yala
//
//  Fila de miembro de grupo — avatar, nombre, rol, saldo contigo y acciones de admin.
//
//  Desde el lote 19 decidido (auditoría UX 2.2) vive en la lista agrupada de Miembros: el rol se llama
//  «Administrador» en todas partes (L19-3), el menú ofrece «Hacer administrador» o «Quitar como administrador»
//  cuando el servidor puede cambiarlo, y a la derecha va lo que esa persona y tú se deben (lienzo «Una sola Yala»:
//  en el color del texto, te deba o le debas).
//

import SwiftUI

struct GroupMemberRow: View {

    /// Lo que esta persona y quien mira se deben, ya formateado. `nil` si nada.
    struct Relation: Equatable {
        enum Direction: Equatable { case owesYou, youOwe }
        let direction: Direction
        let amountText: String
    }

    let member: SplitMember
    let groupColorHex: String
    let isCurrentUserAdmin: Bool
    /// ¿Esta fila soy YO? Lo decide quien monta la lista, con la identidad RESUELTA — no se lee
    /// `member.isCurrentUser` aquí a propósito.
    ///
    /// El flag es local y `applyMember` no lo enciende: un admin cuyo member bajó por el pull (2º
    /// device, reinstalación, aprobación en vivo) resuelve identidad por `sub` y ve
    /// `isCurrentUserAdmin == true`, pero su fila sigue con el flag apagado. Con la condición
    /// leyendo el flag, su PROPIA fila mostraba «quitar» y «cambiar rol» — y el botón funciona:
    /// llama al RPC. Se podía echar de su propio grupo.
    let isSelf: Bool
    /// Qué cambio de rol se ofrece (`GroupService.roleChangeOffer`), o `nil` si ninguno.
    var roleChangeOffer: GroupService.RoleChangeOffer? = nil
    var relation: Relation? = nil
    var onChangeRole: () -> Void = {}
    let onRemove: () -> Void
    var onApprove: (() -> Void)? = nil
    var onReject: (() -> Void)? = nil
    /// Card t3fq: «Saldo inicial» en el menú de la persona. `nil` = no se ofrece (solo quien creó el grupo).
    var onOpeningBalance: (() -> Void)? = nil

    @ScaledMetric(relativeTo: .body) private var avatarSize: CGFloat = 36 // A11Y-DT: @ScaledMetric

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            // Avatar
            avatar

            // Name + role
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                HStack(spacing: DS.Spacing.xs) {
                    Text(member.resolvedDisplayName)
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

            Spacer(minLength: DS.Spacing.sm)

            if let relation {
                relationView(relation)
            }

            // Admin actions
            if isCurrentUserAdmin && !isSelf && !member.isGroupOwner {
                if member.memberStatus == .pendingApproval, let onApprove, let onReject {
                    // Iconos circulares (vs botones text): caben junto al badge
                    // "Pendiente de aprobación" sin truncar nombre/label.
                    HStack(spacing: DS.Spacing.xs) {
                        Button(action: onApprove) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(DS.Typography.title2)
                                .foregroundStyle(.thAccentText)
                                .frame(width: DS.Button.actionSize, height: DS.Button.actionSize)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(L10n.Groups.Member.approve)
                        .accessibilityIdentifier("group_member_approve_\(member.displayName)")

                        Button(action: onReject) {
                            Image(systemName: "xmark.circle.fill")
                                .font(DS.Typography.title2)
                                .foregroundStyle(DS.Semantic.errorForeground)
                                .frame(width: DS.Button.actionSize, height: DS.Button.actionSize)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(L10n.Groups.Member.reject)
                        .accessibilityIdentifier("group_member_reject_\(member.displayName)")
                    }
                } else if member.isActive {
                    Menu {
                        if let roleChangeOffer {
                            Button {
                                onChangeRole()
                            } label: {
                                switch roleChangeOffer {
                                case .makeAdmin:
                                    Label(L10n.UXL19.makeAdmin, systemImage: "person.badge.shield.checkmark")
                                case .removeAdmin:
                                    Label(L10n.UXL19.removeAdmin, systemImage: "person.badge.minus")
                                }
                            }
                        }

                        if let onOpeningBalance {
                            Button {
                                onOpeningBalance()
                            } label: {
                                Label(L10n.Groups.OpeningBalance.editorTitle, systemImage: "arrow.left.arrow.right")
                            }
                            .accessibilityIdentifier("group_member_opening_balance_\(member.displayName)")
                        }

                        Button(role: .destructive) {
                            onRemove()
                        } label: {
                            Label(L10n.UXL19.removeMember, systemImage: "person.crop.circle.badge.xmark")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(DS.Typography.body)
                            .foregroundStyle(.secondary)
                            .frame(width: DS.Button.actionSize, height: DS.Button.actionSize)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.Groups.Member.actions)
                    // El id lleva el nombre dentro para poder afirmar de QUIÉN es el control. Es lo
                    // que permite el test de la auto-expulsión: que exista el de otro miembro y NO
                    // exista el propio. Sin nombre solo se podría contar, y contar no dice de quién.
                    .accessibilityIdentifier("group_member_actions_\(member.displayName)")
                }
            }
        }
        .padding(.vertical, DS.Spacing.xxs)
        // Pending mantiene opacity 1.0 para que los botones inline aprobar/rechazar
        // del admin sean visibles. Solo estados terminales se dimean.
        .opacity(member.isVisible ? 1 : 0.72)
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
        .accessibilityHidden(true)
    }

    private var adminBadge: some View {
        Text(L10n.UXL19.roleAdmin)
            .font(DS.Typography.captionSmall)
            .foregroundStyle(.thAccentText)
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xxs)
            .background(
                Capsule().fill(.thAccent.opacity(0.12))
            )
    }

    /// «Te debe / S/ 80.00» o «Le debes / S/ 40.00», la cifra en el color del texto en los dos casos: en Grupos los
    /// montos no llevan color (Jürgen, 2026-10-30).
    private func relationView(_ relation: Relation) -> some View {
        VStack(alignment: .trailing, spacing: DS.Spacing.none) {
            Text(relation.direction == .owesYou ? L10n.UXL19.owesYouShort : L10n.UXL19.youOweShort)
                .font(DS.Typography.captionSmall)
                .foregroundStyle(Color(uiColor: .secondaryLabel))
            Text(relation.amountText)
                .font(DS.Typography.amountSmall)
                .foregroundStyle(Color.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("group_member_balance_\(member.displayName)")
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
        String(member.resolvedDisplayName.prefix(1)).uppercased()
    }
}
