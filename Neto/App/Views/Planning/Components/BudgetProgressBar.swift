//
//  BudgetProgressBar.swift
//  Neto
//
//  Reusable progress bar component for budget spending visualization
//

import SwiftUI

struct BudgetProgressBar: View {
    let percentage: Double  // 0-100+
    let color: String
    let isExceeded: Bool

    var body: some View {
        GeometryReader { geo in
            let clampedPercentage = min(percentage, 100.0)
            let width = (clampedPercentage / 100.0) * geo.size.width

            ZStack(alignment: .leading) {
                // Background capsule
                Capsule()
                    .fill(Color.gray.opacity(0.1))
                    .frame(height: 6)

                // Foreground capsule (progress)
                Capsule()
                    .fill(isExceeded ? Color.hotPink : Color(hex: color))
                    .frame(width: max(0, width), height: 6)
            }
        }
        .frame(height: 6)
    }
}
