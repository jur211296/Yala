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
        ZStack(alignment: .leading) {
            // Background capsule
            Capsule()
                .fill(DS.Semantic.neutralBackground)
                .frame(height: 6)

            // Foreground capsule (progress)
            Capsule()
                .fill(barColor)
                .frame(width: max(0, barWidth * (min(percentage, 100.0) / 100.0)), height: 6)
        }
        .frame(height: 6)
        .onGeometryChange(for: CGFloat.self, of: { $0.size.width }) { barWidth = $0 }
        .accessibilityValue(isExceeded ? L10n.Accessibility.exceeded : "\(Int(percentage))%")
    }
}
