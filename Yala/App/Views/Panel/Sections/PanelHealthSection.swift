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
            // Lote 1 de la nota de salud (11-nov-2026): en el Panel, la tarjeta chata; el desglose, al tocarla.
            FinancialScoreCompactCard(
                score: score,
                sessionState: sessionState,
                hasBudgets: viewModel.budgets.contains { $0.isActive }
            )
        }
    }
}
