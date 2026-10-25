//
//  BudgetProgressBar.swift
//  Yala
//
//  Reusable progress bar component for budget spending visualization
//

import SwiftUI

struct BudgetProgressBar: View {
    let percentage: Double  // 0-100+
    let color: String
    let isExceeded: Bool
    var simplified: Bool = false

    @State private var barWidth: CGFloat = 0

    private var barColor: Color {
        if isExceeded { return Color.hotPink }
        if simplified { return Color.electricIndigo }
        if percentage >= 75 { return DS.Semantic.warningForeground }
        return Color(hex: color)
    }

    var body: some View {
        // Background capsule; el progreso va en su `overlay`. En un `ZStack`, un presupuesto pasado (al 100 %) fijaba el
        // ancho medido y la barra no encogía al estrechar la ventana (iPhone Duo al plegar o girar, iPad).
        Capsule()
            .fill(DS.Semantic.neutralBackground)
            .frame(height: 6)
            .overlay(alignment: .leading) {
                // Foreground capsule (progress)
                Capsule()
                    .fill(barColor)
                    .frame(width: max(0, barWidth * (min(percentage, 100.0) / 100.0)), height: 6)
            }
            .onGeometryChange(for: CGFloat.self, of: { $0.size.width }) { barWidth = $0 }
        .accessibilityValue(isExceeded ? L10n.Accessibility.exceeded : "\(Int(percentage))%")
    }
}
