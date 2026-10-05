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
    @Environment(SceneNavigation.self) private var navigation

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
            .onChange(of: navigation.selectedMainTab) { _, _ in
                drainPanelIfActive()
            }
            // Gate .panel intents while ChatSheet is open: prevents draining
            // sheet-presenting intents before ChatSheet's dismiss animation completes.
            .onChange(of: sheets.showChatSheet) { _, isOpen in
                if isOpen {
                    AppRouter.shared.markUnready(.panel, in: navigation.id)
                } else {
                    AppRouter.shared.markReady(.panel, in: navigation.id)
                    drainPanelIfActive()
                }
            }
            // Re-drains de Clase D: liberar un blocker superior (cover del shell,
            // sheet de MainTab) o cerrar un sheet propio no bumpea revision — cada
            // dimensión del gate re-drena explícitamente (molde del ChatSheet).
            .onChange(of: navigation.shellModalBlocker) { _, newBlocker in
                if newBlocker == nil { drainPanelIfActive() }
            }
            .onChange(of: navigation.isMainTabModalVisible) { _, visible in
                if !visible { drainPanelIfActive() }
            }
            .onChange(of: sheets.hasActivePresentation) { _, active in
                if !active { drainPanelIfActive() }
            }
            .onChange(of: navigation.showNewTransactionFromChat) { _, showing in
                if !showing { drainPanelIfActive() }
            }
    }

    private func drainPanelIfActive() {
        // Clase D: con cualquier nodo superior tapando (o un sheet propio ya
        // arriba), el intent ESPERA en cola en vez de consumirse tapado —
        // `sheets.showInbox = true` bajo un paywall jamás presentaba (bug
        // TestFlight: tap de notificación que nunca abría la Bandeja).
        guard RouterConsumerGateLogic.panelCanDrain(
            selectedTab: navigation.selectedMainTab,
            chatSheetOpen: sheets.showChatSheet,
            shellBlocker: navigation.shellModalBlocker,
            mainTabModalVisible: navigation.isMainTabModalVisible,
            panelModalVisible: sheets.hasActivePresentation
                || navigation.showNewTransactionFromChat
        ) else {
            // Canario D4: solo con el tab correcto y por flags PUBLICADOS
            // (shellModalBlocker / isMainTabModalVisible) — tab equivocado,
            // chat abierto o sheet propio del panel son estado local real
            // del usuario, no un flag pegado.
            if navigation.selectedMainTab == .panel,
               let pending = AppRouter.shared.peekNext(for: .panel, in: navigation.id) {
                if let blocker = navigation.shellModalBlocker {
                    RouterHoldCanary.shared.noteHold(intentID: pending.id, blocker: blocker, consumer: "panel")
                } else if navigation.isMainTabModalVisible {
                    RouterHoldCanary.shared.noteHold(intentID: pending.id, blocker: "mainTabModal", consumer: "panel")
                }
                #if DEBUG
                print("PanelShell drain hold: \(pending.id) por \(navigation.shellModalBlocker ?? "modal visible")")
                #endif
            }
            return
        }
        guard let intent = AppRouter.shared.drainNext(for: .panel, in: navigation.id) else { return }
        RouterHoldCanary.shared.noteDrained(intentID: intent.id)
        handlePanelIntent(intent)
    }

    /// Drain handler for `.panel` intents. Mutates `sheets` which drive the
    /// `.sheet(isPresented:)` bindings in PanelSheetsModifier.
    private func handlePanelIntent(_ intent: RouterIntent) {
        // Lo que este intent encadene va a ESTA ventana, la que lo drenó.
        SceneRegistry.shared.noteFocused(navigation.id)
        switch intent {
        case .presentInboxSheet:
            sheets.showInbox = true
        case .presentSharedImage(let url):
            // La imagen viaja en el intent: la deja en ESTA ventana, que es la que la va a abrir.
            navigation.pendingSharedImageURL = url
            sheets.showImageSelection = true
        case .presentNewTransaction:
            sheets.showNewTransaction = true
        case .presentNewTransactionFromChatDraft(let prefill):
            navigation.pendingChatDraftPrefill = prefill
            navigation.showNewTransactionFromChat = true
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
