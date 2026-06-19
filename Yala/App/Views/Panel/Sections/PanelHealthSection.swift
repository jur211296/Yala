//
//  PanelHealthSection.swift
//  Yala
//
//  Hidden until the first `performCalculation()` produces a `FinancialScore`;
//  keeps an empty card from flashing on initial Panel mount.
//

import SwiftUI

struct PanelHealthSection: View {
    let viewModel: PanelViewModel
    let sessionState: SessionState

    var body: some View {
        if let score = viewModel.healthWidget.score {
            FinancialScoreView(
                score: score,
                sessionState: sessionState,
                subtitle: viewModel.selectedPeriod.displayName
            )
        }
    }
}
