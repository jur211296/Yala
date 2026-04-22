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
    }

    private func drainPanelIfActive() {
        guard sessionState.selectedMainTab == .panel else { return }
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
        default:
            break  // Non-panel intents ignored (router shouldn't route them here).
        }
    }
}
