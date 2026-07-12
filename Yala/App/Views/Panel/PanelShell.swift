//
//  PanelShell.swift
//  Yala
//
//  Lightweight wrapper that owns sheet state, FAB state, and onChange modifiers.
//  Hosts .sheet() and all SessionState onChange observers so that
//  UISheetPresentationController.layoutBelowIfNeeded and observation
//  cancel/re-register during tab switches hit PanelShell (trivial body)
//  instead of PanelView (heavy body with NavigationStack + widgets).
//

import SwiftUI

struct PanelShell: View {
    @State private var viewModel = PanelViewModel()
    @State private var sheets = PanelSheetState()
    @Environment(SessionState.self) private var sessionState

    var body: some View {
        PanelView(viewModel: viewModel, sheets: $sheets)
            .modifier(PanelSheetsModifier(
                sheets: $sheets,
                viewModel: viewModel
            ))
            .modifier(PanelDataObservers(
                viewModel: viewModel,
                sessionState: sessionState
            ))
            .modifier(PanelSessionObservers(
                viewModel: viewModel,
                sessionState: sessionState
            ))
            .sheet(isPresented: $sheets.showSubscriptionFromBanner) {
                NavigationStack {
                    SubscriptionView(source: sheets.subscriptionBannerSource)
                }
            }
            // Consumer gate: drain only when Panel is the active tab, so
            // intents don't present behind a hidden view.
            .routerConsumer(.panel) {
                drainPanelIfActive()
            }
            .onChange(of: sessionState.selectedMainTab) { _, _ in
                drainPanelIfActive()
            }
            // Gate .panel intents while ChatSheet is open: prevents draining
            // sheet-presenting intents before ChatSheet's dismiss animation completes.
            .onChange(of: sheets.showChatSheet) { _, isOpen in
                if isOpen {
                    AppRouter.shared.markUnready(.panel)
                } else {
                    AppRouter.shared.markReady(.panel)
                    drainPanelIfActive()
                }
            }
            // Re-drains de Clase D: liberar un blocker superior (cover del shell,
            // sheet de MainTab) o cerrar un sheet propio no bumpea revision — cada
            // dimensión del gate re-drena explícitamente (molde del ChatSheet).
            .onChange(of: sessionState.shellModalBlocker) { _, newBlocker in
                if newBlocker == nil { drainPanelIfActive() }
            }
            .onChange(of: sessionState.isMainTabModalVisible) { _, visible in
                if !visible { drainPanelIfActive() }
            }
            .onChange(of: sheets.hasActivePresentation) { _, active in
                if !active { drainPanelIfActive() }
            }
            .onChange(of: sessionState.showNewTransactionFromChat) { _, showing in
                if !showing { drainPanelIfActive() }
            }
    }

    private func drainPanelIfActive() {
        // Clase D: con cualquier nodo superior tapando (o un sheet propio ya
        // arriba), el intent ESPERA en cola en vez de consumirse tapado —
        // `sheets.showInbox = true` bajo un paywall jamás presentaba (bug
        // TestFlight: tap de notificación que nunca abría la Bandeja).
        guard RouterConsumerGateLogic.panelCanDrain(
            selectedTab: sessionState.selectedMainTab,
            chatSheetOpen: sheets.showChatSheet,
            shellBlocker: sessionState.shellModalBlocker,
            mainTabModalVisible: sessionState.isMainTabModalVisible,
            panelModalVisible: sheets.hasActivePresentation
                || sessionState.showNewTransactionFromChat
        ) else {
            #if DEBUG
            if let pending = AppRouter.shared.peekNext(for: .panel) {
                print("PanelShell drain hold: \(pending.id) por \(sessionState.shellModalBlocker ?? "modal visible")")
            }
            #endif
            return
        }
        guard let intent = AppRouter.shared.drainNext(for: .panel) else { return }
        handlePanelIntent(intent)
    }

    /// Drain handler for `.panel` intents. Mutates `sheets` which drive the
    /// `.sheet(isPresented:)` bindings in PanelSheetsModifier.
    private func handlePanelIntent(_ intent: RouterIntent) {
        switch intent {
        case .presentInboxSheet:
            sheets.showInbox = true
        case .presentSharedImage:
            sheets.showImageSelection = true
        case .presentNewTransaction:
            sheets.showNewTransaction = true
        case .presentNewTransactionFromChatDraft(let prefill):
            sessionState.pendingChatDraftPrefill = prefill
            sessionState.showNewTransactionFromChat = true
        case .presentVoiceEntry:
            sheets.showVoiceRecording = true
        case .presentImageEntry:
            sheets.showImageSelection = true
        case .presentUpgradeSheet(let feature):
            switch feature {
            case .voice:
                sheets.showUpgradeForVoice = true
            case .image:
                sheets.showUpgradeForImage = true
            case .accounts:
                sheets.showUpgradeForAccounts = true
            case .chat:
                sheets.showUpgradeForChat = true
            }
        case .requestAIConsent(let input):
            sheets.pendingAIInput = input
            sheets.showAIConsentAlert = true
        default:
            break  // Non-panel intents ignored (router shouldn't route them here).
        }
    }
}
