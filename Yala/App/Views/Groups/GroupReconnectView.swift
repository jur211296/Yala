//
//  GroupReconnectView.swift
//  Yala
//
//  Confirmation/info screen mostrado tras tap a un invite link cuando el usuario
//  ya tenía estado relevante (member status local o grupo archivado). UI condicional
//  por `mode` del invite — copy + CTA cambian según escenario.
//

import SwiftUI

struct GroupReconnectView: View {
    @Environment(SessionState.self) private var sessionState
    @Environment(\.yalaTheme) private var theme

    let invite: InviteMetadata
    var onJoin: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()

                VStack(spacing: DS.Spacing.xxl) {
                    Spacer()

                    groupIcon

                    VStack(spacing: DS.Spacing.sm) {
                        Text(title)
                            .font(DS.Typography.title2)
                            .multilineTextAlignment(.center)

                        Text(subtitle)
                            .font(DS.Typography.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    Spacer()

                    YalaPrimaryButton(ctaLabel) {
                        if invite.mode == .archived || invite.mode == .deletedForAll {
                            // .archived / .deletedForAll (FU-02): el CTA solo dismissa.
                            onDismiss()
                        } else {
                            onJoin()
                        }
                    }
                    .padding(.bottom, DS.Spacing.xxl)
                }
                .padding(.horizontal, DS.Spacing.xxl)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        onDismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Mode-driven copy

    private var title: String {
        let groupName = invite.groupName ?? L10n.Groups.Reconnect.fallbackGroupName
        switch invite.mode {
        case .standardReconnect: return L10n.Groups.Reconnect.title
        case .archived: return L10n.Groups.Reconnect.archivedTitle(groupName)
        case .alreadyMember: return L10n.Groups.Reconnect.alreadyMemberTitle(groupName)
        case .pendingDuplicate: return L10n.Groups.Reconnect.pendingDuplicateTitle(groupName)
        case .rejectedRetry: return L10n.Groups.Reconnect.rejectedRetryTitle
        case .leftRetry: return L10n.Groups.Reconnect.leftRetryTitle(groupName)
        case .removedRetry: return L10n.Groups.Reconnect.removedRetryTitle(groupName)
        case .deletedForAll: return L10n.Groups.Reconnect.deletedForAllTitle(groupName)
        }
    }

    private var subtitle: String {
        switch invite.mode {
        case .standardReconnect: return L10n.Groups.Reconnect.subtitle
        case .archived: return L10n.Groups.Reconnect.archivedBody
        case .alreadyMember: return L10n.Groups.Reconnect.alreadyMemberBody
        case .pendingDuplicate: return L10n.Groups.Reconnect.pendingDuplicateBody
        case .rejectedRetry: return L10n.Groups.Reconnect.rejectedRetryBody
        case .leftRetry: return L10n.Groups.Reconnect.leftRetryBody
        case .removedRetry: return L10n.Groups.Reconnect.removedRetryBody
        case .deletedForAll: return L10n.Groups.Reconnect.deletedForAllBody
        }
    }

    private var ctaLabel: String {
        switch invite.mode {
        case .standardReconnect: return L10n.Groups.Invite.joinButton
        case .archived: return L10n.Groups.Reconnect.archivedCta
        case .alreadyMember: return L10n.Groups.Reconnect.alreadyMemberCta
        case .pendingDuplicate: return L10n.Groups.Reconnect.pendingDuplicateCta
        case .rejectedRetry, .leftRetry, .removedRetry: return L10n.Groups.Reconnect.retryCta
        case .deletedForAll: return L10n.Groups.Reconnect.deletedForAllCta
        }
    }

    // MARK: - Group Icon

    private var groupIcon: some View {
        ZStack {
            Circle()
                .fill(groupColor)
                .frame(width: 64, height: 64) // A11Y-DT: decorative hero icon, fixed size

            Image(systemName: invite.groupIcon ?? "person.2.fill")
                .font(.system(size: 28)) // A11Y-DT: decorative icon inside circle
                .foregroundStyle(.white)
        }
        .glassEffect(.regular, in: Circle())
    }

    private var groupColor: Color {
        if let hex = invite.groupColor, !hex.isEmpty { return Color(hex: hex) }
        return theme.accent
    }
}
