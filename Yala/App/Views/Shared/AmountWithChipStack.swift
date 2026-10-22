//
//  AmountWithChipStack.swift
//  Yala
//
//  Una cifra con su chip de variación detrás (las entradas y salidas del hero de Estadísticas).
//

import SwiftUI

/// En fila a los tamaños de texto normales y, con texto de accesibilidad, el chip debajo de la cifra.
///
/// **A tamaño normal pinta EXACTAMENTE el `HStack` plano de siempre** (`HStack(spacing: xs) { icono; cifra;
/// chip }`): los hijos de `amount` y el chip quedan hermanos en la misma pila. Con texto de accesibilidad (AX1–AX5)
/// la cifra y el chip no caben juntos en un iPhone: medido el 2026-10-12 a AX3 en el iPhone 17 Pro, con las dos
/// filas ya separadas (`AdaptiveRowStack`), «S/ 274,708.50» seguía saliendo «S/274,…50». Decisión A de Jürgen
/// (`stats-hero-detail-row-truncates-at-accessibility-text`): con letra grande la fila se parte en líneas.
struct AmountWithChipStack<Amount: View, Chip: View>: View {
    private let amount: Amount
    private let chip: Chip

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(@ViewBuilder amount: () -> Amount, @ViewBuilder chip: () -> Chip) {
        self.amount = amount()
        self.chip = chip()
    }

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                HStack(spacing: DS.Spacing.xs) { amount }
                chip
            }
        } else {
            HStack(spacing: DS.Spacing.xs) {
                amount
                chip
            }
        }
    }
}
