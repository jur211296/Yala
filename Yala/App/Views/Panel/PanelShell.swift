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
            .modifier(PanelSheetTriggers(
                sessionState: sessionState,
                sheets: $sheets
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
    }
}
