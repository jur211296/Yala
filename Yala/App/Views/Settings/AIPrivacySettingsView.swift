//
//  AIPrivacySettingsView.swift
//  Yala
//
//  Sub-view from Profile > Security > AI Privacy. Manages the 3 AI consents
//  (data processing, chat, insights). Each switch can be revoked individually
//  with a confirm dialog; turning back ON triggers the corresponding consent alert.
//  Con la cuenta en la nube y Yala IA ampliada encendida, una cuarta fila: la respuesta al texto N1
//  (`YalaIACloudExploreConsent`), que el chat pregunta una vez antes de la primera pregunta.
//

import SwiftUI

struct AIPrivacySettingsView: View {

    @Environment(\.openURL) private var openURL
    @Environment(AppPreferences.self) private var appPreferences

    @State private var dataToggle: Bool = false
    @State private var chatToggle: Bool = false
    @State private var insightsToggle: Bool = false
    @State private var cloudExploreToggle: Bool = false
    /// La fila de N1 solo existe con el camino ampliado disponible; se mide al aparecer.
    @State private var showsCloudExploreRow = false

    @State private var showDataConsentAlert = false
    @State private var showChatConsentAlert = false
    @State private var showInsightsConsentAlert = false
    @State private var showCloudExploreConsentAlert = false
    @State private var pendingAIInput: PendingAIInput = .voice

    @State private var showRevokeDataDialog = false
    @State private var showRevokeChatDialog = false
    @State private var showRevokeInsightsDialog = false
    @State private var showRevokeCloudExploreDialog = false
    @State private var showChatUpgrade = false

    /// Yala IA es de Pro: sin Pro su fila lleva la marca y encenderla abre la hoja de Pro, no el permiso (UX 2.2 ·
    /// L14-11, opción D). Antes se aceptaba el permiso y la función seguía bloqueada.
    private var isChatLocked: Bool { !FeatureGateService.shared.canAccess(.chatAssistant) }

    var body: some View {
        // UX 2.2 · L14-11: cada función con el nombre que tiene en la app y una línea que dice qué hace. La línea va en
        // el pie de su bloque, como pide `YalaSettingsList` para la ayuda que solo es de una fila. Antes eran tres
        // filas con nombres internos («Procesamiento (voz e imagen)», «Asistente Pro») en un solo bloque.
        YalaSettingsList {
            YalaSettingsSection(L10n.AIPrivacy.title) {
                YalaSettingsToggleRow(L10n.AIPrivacy.processingRow, isOn: $dataToggle)
                    .accessibilityIdentifier("ai_privacy_processing_row")
            } footer: {
                Text(L10n.UXL14D.processingLine)
            }
            YalaSettingsSection {
                YalaSettingsToggleRow(L10n.AIPrivacy.chatRow, isOn: $chatToggle) {
                    if isChatLocked {
                        ProBadge(size: .small)
                    }
                }
                .accessibilityIdentifier("ai_privacy_chat_row")
            } footer: {
                Text(L10n.UXL14D.chatLine)
            }
            YalaSettingsSection {
                YalaSettingsToggleRow(L10n.AIPrivacy.insightsRow, isOn: $insightsToggle)
                    .accessibilityIdentifier("ai_privacy_insights_row")
            } footer: {
                Text(L10n.UXL14D.insightsLine)
            }
            if showsCloudExploreRow {
                YalaSettingsSection {
                    YalaSettingsToggleRow(L10n.AIPrivacy.cloudExploreRow, isOn: $cloudExploreToggle)
                        .accessibilityIdentifier("ai_privacy_cloud_explore_row")
                } footer: {
                    Text(L10n.UXL14D.cloudExploreLine)
                }
            }
            Section {
                EmptyView()
            } footer: {
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    Text(L10n.AIPrivacy.footerHint)

                    Button {
                        openURL(AppConstants.privacyURL)
                    } label: {
                        Text(L10n.AIPrivacy.policyLink)
                            .font(DS.Typography.caption.weight(.medium))
                            .foregroundStyle(.tint)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .yalaScreenBackground(.subtle)
        .navigationTitle(L10n.AIPrivacy.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            dataToggle = appPreferences.aiDataConsentAccepted
            chatToggle = appPreferences.aiChatConsentAccepted
            insightsToggle = appPreferences.aiInsightsConsentAccepted
            cloudExploreToggle = appPreferences.aiCloudExploreConsent == .accepted
            showsCloudExploreRow = YalaIAChatRouting.cloudExploreAvailableNow()
        }
        .onChange(of: appPreferences.aiDataConsentAccepted) { _, newValue in dataToggle = newValue }
        .onChange(of: appPreferences.aiChatConsentAccepted) { _, newValue in chatToggle = newValue }
        .onChange(of: appPreferences.aiInsightsConsentAccepted) { _, newValue in insightsToggle = newValue }
        .modifier(CloudExploreConsentRowBehavior(
            toggle: $cloudExploreToggle,
            showConsentAlert: $showCloudExploreConsentAlert,
            showRevokeDialog: $showRevokeCloudExploreDialog
        ))
        .onChange(of: dataToggle) { _, newValue in
            if newValue && !appPreferences.aiDataConsentAccepted {
                pendingAIInput = .voice
                showDataConsentAlert = true
            } else if !newValue && appPreferences.aiDataConsentAccepted {
                showRevokeDataDialog = true
            }
        }
        .onChange(of: chatToggle) { _, newValue in
            if newValue && !appPreferences.aiChatConsentAccepted && isChatLocked {
                // Sin Pro el permiso no sirve de nada: la fila vuelve a apagado y sale la hoja de Pro.
                chatToggle = false
                showChatUpgrade = true
            } else if newValue && !appPreferences.aiChatConsentAccepted {
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
        // If a grant alert is dismissed without accepting (Cancel / Privacy Policy /
        // swipe), consent was never persisted — revert the toggle so the switch
        // reflects the real consent state instead of staying falsely ON.
        // Al cerrar el alert leemos el consentimiento desde UserDefaults SÍNCRONO: la propiedad
        // de `appPreferences` se refresca async vía el observer de didChangeNotification, así que
        // aquí estaría stale y revertiría el toggle aunque el usuario haya aceptado. La key es la
        // misma SSOT que persiste el alert.
        .onChange(of: showDataConsentAlert) { _, shown in
            if !shown && !UserDefaults.standard.bool(forKey: AppPreferences.Keys.aiDataConsentAccepted) { dataToggle = false }
        }
        .onChange(of: showChatConsentAlert) { _, shown in
            if !shown && !UserDefaults.standard.bool(forKey: AppPreferences.Keys.aiChatConsentAccepted) { chatToggle = false }
        }
        .onChange(of: showInsightsConsentAlert) { _, shown in
            if !shown && !UserDefaults.standard.bool(forKey: AppPreferences.Keys.aiInsightsConsentAccepted) { insightsToggle = false }
        }
        .aiConsentAlert(isPresented: $showDataConsentAlert, pendingInput: $pendingAIInput) { _ in }
        .chatConsentAlert(isPresented: $showChatConsentAlert)
        .insightsConsentAlert(isPresented: $showInsightsConsentAlert)
        .proUpgradeSheet(isPresented: $showChatUpgrade, feature: .chatAssistant, context: .proFeature)
        .confirmationDialog(
            L10n.UXL14D.revokeTitle(L10n.AIPrivacy.processingRow),
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
            L10n.UXL14D.revokeTitle(L10n.AIPrivacy.chatRow),
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
            L10n.UXL14D.revokeTitle(L10n.AIPrivacy.insightsRow),
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
}

/// La fila de N1 en Privacidad de la IA: encender enseña N1 y solo «Aceptar» la deja encendida; apagar pide la misma
/// confirmación que las otras tres y apunta el rechazo, así que el chat no vuelve a preguntar. Va en su propio
/// modificador para no alargar la cadena del `body` (el compilador del CI tipa peor; `swiftui-ds.md`).
private struct CloudExploreConsentRowBehavior: ViewModifier {
    @Environment(AppPreferences.self) private var appPreferences
    @Binding var toggle: Bool
    @Binding var showConsentAlert: Bool
    @Binding var showRevokeDialog: Bool

    private var accepted: Bool { appPreferences.aiCloudExploreConsent == .accepted }

    func body(content: Content) -> some View {
        content
            .onChange(of: appPreferences.aiCloudExploreConsent) { _, newValue in toggle = newValue == .accepted }
            .onChange(of: toggle) { _, newValue in toggleChanged(to: newValue) }
            .cloudExploreConsentAlert(
                isPresented: $showConsentAlert,
                onAccept: { appPreferences.aiCloudExploreConsent = .accepted },
                onDecline: { toggle = false },
                onPrivacyPolicy: { toggle = false }
            )
            .confirmationDialog(
                L10n.UXL14D.revokeTitle(L10n.AIPrivacy.cloudExploreRow),
                isPresented: $showRevokeDialog,
                titleVisibility: .visible
            ) {
                Button(L10n.AIPrivacy.revokeConfirmAction, role: .destructive) {
                    appPreferences.aiCloudExploreConsent = .declined
                }
                Button(L10n.Action.cancel, role: .cancel) { toggle = true }
            } message: {
                Text(L10n.AIPrivacy.revokeConfirmMessage)
            }
    }

    private func toggleChanged(to newValue: Bool) {
        if newValue && !accepted {
            showConsentAlert = true
        } else if !newValue && accepted {
            showRevokeDialog = true
        }
    }
}
