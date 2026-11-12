//
//  GroupJoinRequestViews.swift
//  Yala
//
//  Auditoría UX 2.2 · L19-1 (decisión de Jürgen del 18-oct: opción D, variante 3, `L19-1-C.png`). Una solicitud para
//  unirse ya no es un punto rojo y dos iconos sin texto: dentro del grupo, un aviso «Carla quiere unirse · Revisar» que
//  abre Miembros; en Miembros, una tarjeta por persona con cuándo pidió entrar, qué pasa al aceptarla o rechazarla, y
//  «Aceptar» / «Rechazar» con su nombre.
//
//  El rosa de marca es lo que pide atención (criterio d de Jürgen); relleno sólido en el botón, sin degradados.
//

import SwiftUI

/// El aviso dentro del grupo, para quien puede aceptar.
struct GroupJoinRequestsBanner: View {

    let pendingNames: [String]
    let title: String
    let onReview: () -> Void

    @ScaledMetric(relativeTo: .body) private var avatarSize: CGFloat = 40 // A11Y-DT: @ScaledMetric

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            avatar
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(title)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(pendingNames.count == 1
                     ? L10n.UXD14.requestsBannerBodyOne : L10n.UXD14.requestsBannerBodyMany)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: DS.Spacing.sm)
            Button(action: onReview) {
                Text(L10n.UXD14.requestsReview)
                    .font(DS.Typography.label)
                    .foregroundStyle(.white)
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(Capsule().fill(Color.hotPink))
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("group_join_requests_review")
        }
        .padding(DS.Spacing.lg)
        .background(Color.hotPink.opacity(0.14), in: RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("group_join_requests_banner")
    }

    @ViewBuilder
    private var avatar: some View {
        ZStack {
            Circle()
                .fill(Color.hotPink.opacity(0.22))
                .frame(width: avatarSize, height: avatarSize)
            if pendingNames.count == 1, let initial = pendingNames.first?.first {
                Text(String(initial).uppercased())
                    .font(DS.Typography.headline)
                    .foregroundStyle(Color.hotPink)
            } else {
                Image(systemName: "person.2.fill")
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(Color.hotPink)
            }
        }
        .accessibilityHidden(true)
    }
}

/// La tarjeta de UNA solicitud en Miembros.
struct GroupJoinRequestCard: View {

    let name: String
    /// El nombre con el que se arman los identificadores (`displayName`, como en `GroupMemberRow`).
    let idName: String
    let requestedAt: Date
    let onAccept: () -> Void
    let onReject: () -> Void

    @ScaledMetric(relativeTo: .body) private var avatarSize: CGFloat = 40 // A11Y-DT: @ScaledMetric

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(Color.hotPink.opacity(0.22))
                        .frame(width: avatarSize, height: avatarSize)
                    Text(String(name.first ?? "?").uppercased())
                        .font(DS.Typography.headline)
                        .foregroundStyle(Color.hotPink)
                }
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(name)
                        .font(DS.Typography.headline)
                        .foregroundStyle(.primary)
                    Text(L10n.UXD14.requestOpened(requestedAt))
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }

            Text(L10n.UXD14.requestsConsequence)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: DS.Spacing.sm) { acceptButton; rejectButton; Spacer(minLength: 0) }
                VStack(alignment: .leading, spacing: DS.Spacing.sm) { acceptButton; rejectButton }
            }
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.hotPink.opacity(0.14), in: RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("group_join_request_\(idName)")
    }

    // Los identificadores son los de la fila de antes (`GroupMemberRow`): las pruebas de administración los buscan por
    // nombre, y se reconoce de quién es el control sin contar.
    private var acceptButton: some View {
        Button(action: onAccept) {
            Label(L10n.UXD14.requestsAccept, systemImage: "checkmark")
                .font(DS.Typography.label)
                .foregroundStyle(.white)
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.sm)
                .background(Capsule().fill(Color.hotPink))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(L10n.UXD14.requestsAccept), \(name)")
        .accessibilityIdentifier("group_member_approve_\(idName)")
    }

    private var rejectButton: some View {
        Button(action: onReject) {
            Text(L10n.Groups.Member.reject)
                .font(DS.Typography.label)
                .foregroundStyle(.secondary)
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.sm)
                .background(Capsule().fill(Color.secondary.opacity(0.16)))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(L10n.Groups.Member.reject), \(name)")
        .accessibilityIdentifier("group_member_reject_\(idName)")
    }
}
