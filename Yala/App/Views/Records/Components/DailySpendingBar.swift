//
//  DailySpendingBar.swift
//  Yala
//
//  Barra de intensidad de gasto para una celda del calendario de Registros.
//

import SwiftUI

/// Barra horizontal cuya longitud es proporcional a `value / maxValue`, en el color de gasto.
struct DailySpendingBar: View {
    let value: Double
    let maxValue: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var fraction: Double {
        guard maxValue > 0, value > 0 else { return 0 }
        return min(1, value / maxValue)
    }

    var body: some View {
        GeometryReader { proxy in
            let trackWidth = proxy.size.width
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.thSecondaryText.opacity(0.10))

                // Color de gasto sólido: la intensidad ya la dice la longitud. Sin degradado (regla de marca).
                Capsule()
                    .fill(Color.expenseGraph)
                    .frame(width: trackWidth * fraction)
            }
        }
        .frame(height: 5)
        .animation(reduceMotion ? nil : .smooth(duration: 0.35), value: fraction)
    }
}
