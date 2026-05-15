//
//  AIPrivacySettingsView.swift
//  Yala
//
//  Sub-view from Profile > Security > AI Privacy. Manages the 3 AI consents
//  (data processing, chat, insights). Each switch can be revoked individually
//  with a confirm dialog; turning back ON triggers the corresponding consent alert.
//

import SwiftUI

struct AIPrivacySettingsView: View {

    @Environment(\.openURL) private var openURL
    @Environment(AppPreferences.self) private var appPreferences

    @State private var dataToggle: Bool = false
    @State private var chatToggle: Bool = false
    @State private var insightsToggle: Bool = false

    @State private var showDataConsentAlert = false
    @State private var showChatConsentAlert = false
    @State private var showInsightsConsentAlert = false
    @State private var pendingAIInput: PendingAIInput = .voice

    @State private var showRevokeDataDialog = false
    @State private var showRevokeChatDialog = false
    @State private var showRevokeInsightsDialog = false

    var body: some View {
        ZStack {
            PanelBackgroundView()

            ScrollView {
                VStack(spacing: DS.Spacing.lg) {
                    SectionBox(title: L10n.AIPrivacy.title) {
                        VStack(spacing: DS.Spacing.none) {
                            toggleRow(title: L10n.AIPrivacy.processingRow, isOn: $dataToggle)
                            SubsectionDivider()
                            toggleRow(title: L10n.AIPrivacy.chatRow, isOn: $chatToggle)
                            SubsectionDivider()
                            toggleRow(title: L10n.AIPrivacy.insightsRow, isOn: $insightsToggle)
                        }
                    }

                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        Text(L10n.AIPrivacy.footerHint)
                            .font(DS.Typography.caption)
                            .foregroundStyle(.secondary)

                        Button {
                            openURL(AppConstants.privacyURL)
                        } label: {
                            Text(L10n.AIPrivacy.policyLink)
                                .font(DS.Typography.caption.weight(.medium))
                                .foregroundStyle(.tint)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.lg)
            }
        }
        .navigationTitle(L10n.AIPrivacy.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            dataToggle = appPreferences.aiDataConsentAccepted
            chatToggle = appPreferences.aiChatConsentAccepted
            insightsToggle = appPreferences.aiInsightsConsentAccepted
        }
        .onChange(of: appPreferences.aiDataConsentAccepted) { _, newValue in dataToggle = newValue }
        .onChange(of: appPreferences.aiChatConsentAccepted) { _, newValue in chatToggle = newValue }
        .onChange(of: appPreferences.aiInsightsConsentAccepted) { _, newValue in insightsToggle = newValue }
        .onChange(of: dataToggle) { _, newValue in
            if newValue && !appPreferences.aiDataConsentAccepted {
                pendingAIInput = .voice
                showDataConsentAlert = true
            } else if !newValue && appPreferences.aiDataConsentAccepted {
                showRevokeDataDialog = true
            }
        }
        .onChange(of: chatToggle) { _, newValue in
            if newValue && !appPreferences.aiChatConsentAccepted {
                showChatConsentAlert = true
            } else if !newValue && appPreferences.aiChatConsentAccepted {
                showRevokeChatDialog = true
            }
        }
        .onChange(of: insightsToggle) { _, newValue in
            if newValue && !appPreferences.aiInsightsConsentAccepted {
                showInsightsConsentAlert = true
            } else if !newValue && appPreferences.aiInsightsConsentAccepted {
                showRevokeInsightsDialog = true
            }
        }
        .aiConsentAlert(isPresented: $showDataConsentAlert, pendingInput: $pendingAIInput) { _ in }
        .chatConsentAlert(isPresented: $showChatConsentAlert)
        .insightsConsentAlert(isPresented: $showInsightsConsentAlert)
        .confirmationDialog(
            L10n.AIPrivacy.revokeConfirmTitle,
            isPresented: $showRevokeDataDialog,
            titleVisibility: .visible
        ) {
            Button(L10n.AIPrivacy.revokeConfirmAction, role: .destructive) {
                appPreferences.aiDataConsentAccepted = false
            }
            Button(L10n.Action.cancel, role: .cancel) {
                dataToggle = true
            }
        } message: {
            Text(L10n.AIPrivacy.revokeConfirmMessage)
        }
        .confirmationDialog(
            L10n.AIPrivacy.revokeConfirmTitle,
            isPresented: $showRevokeChatDialog,
            titleVisibility: .visible
        ) {
            Button(L10n.AIPrivacy.revokeConfirmAction, role: .destructive) {
                appPreferences.aiChatConsentAccepted = false
            }
            Button(L10n.Action.cancel, role: .cancel) {
                chatToggle = true
            }
        } message: {
            Text(L10n.AIPrivacy.revokeConfirmMessage)
        }
        .confirmationDialog(
            L10n.AIPrivacy.revokeConfirmTitle,
            isPresented: $showRevokeInsightsDialog,
            titleVisibility: .visible
        ) {
            Button(L10n.AIPrivacy.revokeConfirmAction, role: .destructive) {
                appPreferences.aiInsightsConsentAccepted = false
            }
            Button(L10n.Action.cancel, role: .cancel) {
                insightsToggle = true
            }
        } message: {
            Text(L10n.AIPrivacy.revokeConfirmMessage)
        }
    }

    private func toggleRow(title: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Text(title)
                .font(DS.Typography.body)
                .foregroundStyle(.primary)

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.FormRow.paddingV)
    }
}
