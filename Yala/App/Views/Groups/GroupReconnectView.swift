//
//  GroupReconnectView.swift
//  Yala
//
//  Reconnection screen for dormant users who accept a group invitation.
//  Single screen: "Welcome back" + "Join group" button.
//

import SwiftUI

struct GroupReconnectView: View {
    @Environment(SessionState.self) private var sessionState
    @Environment(\.yalaTheme) private var theme

    var onComplete: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                theme.background
                    .ignoresSafeArea()

                VStack(spacing: DS.Spacing.xxl) {
                    Spacer()

                    Image(systemName: "hand.wave.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(theme.accent)

                    VStack(spacing: DS.Spacing.sm) {
                        Text(L10n.Groups.Reconnect.title)
                            .font(DS.Typography.title2)
                            .multilineTextAlignment(.center)

                        if let groupName = sessionState.pendingInviteGroupName {
                            Text(L10n.Groups.Reconnect.subtitleWithGroup(groupName))
                                .font(DS.Typography.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        } else {
                            Text(L10n.Groups.Reconnect.subtitle)
                                .font(DS.Typography.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }

                    Spacer()

                    YalaPrimaryButton(L10n.Groups.Invite.joinButton) {
                        onComplete()
                    }
                    .padding(.bottom, DS.Spacing.xxl)
                }
                .padding(.horizontal, DS.Spacing.xxl)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Action.cancel) {
                        onComplete()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
