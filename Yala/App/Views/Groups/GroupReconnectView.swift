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
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false

    let invite: InviteMetadata
    var onJoin: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        NavigationStack {
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
                    if invite.mode == .archived || invite.mode == .deletedForAll || shouldDismissOnlyCTA {
                        // .archived / .deletedForAll: el CTA solo dismissa.
                        // shouldDismissOnlyCTA: pre-onboarding tampoco navega (no hay
                        // MainTabView donde "ver grupos").
                        onDismiss()
                    } else {
                        onJoin()
                    }
                }
                .padding(.bottom, DS.Spacing.xxl)
            }
            .padding(.horizontal, DS.Spacing.xxl)
            .yalaScreenBackground(.transparent)
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

    /// Pre-onboarding: los modes que normalmente navegan (`alreadyMember`, `pendingDuplicate`)
    /// no tienen destino válido — MainTabView no está montado. El CTA solo cierra el sheet.
    private var shouldDismissOnlyCTA: Bool {
        guard !hasCompletedOnboarding else { return false }
        switch invite.mode {
        case .alreadyMember, .pendingDuplicate: return true
        default: return false
        }
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
        // Pre-onboarded en alreadyMember/pendingDuplicate: CTA solo cierra el sheet
        // (no hay MainTabView donde navegar). Copy refleja el destino real.
        if shouldDismissOnlyCTA { return L10n.Groups.Reconnect.backToStart }
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
