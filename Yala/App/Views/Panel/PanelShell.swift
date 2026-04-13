//
//  PanelShell.swift
//  Yala
//
//  Lightweight wrapper that owns sheet state and presentation.
//  UISheetPresentationController.layoutBelowIfNeeded forces re-evaluation
//  of the view that hosts .sheet() — by hosting them here instead of PanelView,
//  the forced re-evaluation hits PanelShell (zero @Observable reads, ~0ms)
//  instead of PanelView (50+ @Observable reads → infinite render loop).
//

import SwiftUI

struct PanelShell: View {
    @State private var viewModel = PanelViewModel()
    @State private var sheets = PanelSheetState()

    var body: some View {
        PanelView(viewModel: viewModel, sheets: $sheets)
            .modifier(PanelSheetsModifier(
                sheets: $sheets,
                viewModel: viewModel
            ))
            .sheet(isPresented: $sheets.showSubscriptionFromBanner) {
                NavigationStack {
                    SubscriptionView(source: sheets.subscriptionBannerSource)
                }
            }
    }
}
