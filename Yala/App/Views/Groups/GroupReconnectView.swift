//
//  GroupReconnectView.swift
//  Yala
//
//  Confirmation screen for existing users accepting a group invitation.
//  Shows group icon/color/name/members. X to dismiss, Join to accept.
//

import SwiftUI

struct GroupReconnectView: View {
    @Environment(SessionState.self) private var sessionState
    @Environment(\.yalaTheme) private var theme

    var onJoin: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                theme.background
                    .ignoresSafeArea()

                VStack(spacing: DS.Spacing.xxl) {
                    Spacer()

                    // Group icon with color
                    groupIcon

                    // Group info
                    VStack(spacing: DS.Spacing.sm) {
                        if let groupName = sessionState.pendingInviteGroupName {
                            Text(L10n.Groups.Reconnect.subtitleWithGroup(groupName))
                                .font(DS.Typography.title2)
                                .multilineTextAlignment(.center)
                        } else {
                            Text(L10n.Groups.Reconnect.title)
                                .font(DS.Typography.title2)
                                .multilineTextAlignment(.center)
                        }

                        Text(L10n.Groups.Reconnect.subtitle)
                            .font(DS.Typography.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)

                        // Member names from invite URL
                        if let members = sessionState.pendingInviteGroupMembers, !members.isEmpty {
                            Text(members.joined(separator: ", "))
                                .font(DS.Typography.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.top, DS.Spacing.xs)
                        }
                    }

                    Spacer()

                    YalaPrimaryButton(L10n.Groups.Invite.joinButton) {
                        onJoin()
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

    // MARK: - Group Icon

    private var groupIcon: some View {
        ZStack {
            Circle()
                .fill(groupColor)
                .frame(width: 64, height: 64) // A11Y-DT: decorative hero icon, fixed size

            Image(systemName: sessionState.pendingInviteGroupIcon ?? "person.2.fill")
                .font(.system(size: 28)) // A11Y-DT: decorative icon inside circle
                .foregroundStyle(.white)
        }
        .glassEffect(.regular, in: Circle())
    }

    private var groupColor: Color {
        if let hex = sessionState.pendingInviteGroupColor {
            return Color(hex: hex)
        }
        return theme.accent
    }
}
