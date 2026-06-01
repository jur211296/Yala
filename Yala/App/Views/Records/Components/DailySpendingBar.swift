//
//  DailySpendingBar.swift
//  Yala
//
//  Barra de intensidad de gasto para una celda del calendario de Registros.
//

import SwiftUI

/// Barra horizontal cuya longitud es proporcional a `value / maxValue`, pintada con
/// `DS.Gradients.spendingHeat` **anclado al ancho del track completo**: la punta del
/// día de mayor gasto llega a rosa puro y los días menores se quedan en índigo/morado.
///
/// El gradiente se dibuja a ancho de track y se recorta (`mask`) a `fillWidth` — así el
/// color en cada posición refleja el valor absoluto del día, no se reescala al fill.
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

                Capsule()
                    .fill(LinearGradient(
                        colors: DS.Gradients.spendingHeat,
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .frame(width: trackWidth)                       // gradiente a ancho completo
                    .mask(alignment: .leading) {
                        Capsule().frame(width: trackWidth * fraction)  // recortado al fill
                    }
            }
        }
        .frame(height: 5)
        .animation(reduceMotion ? nil : .smooth(duration: 0.35), value: fraction)
    }
}
