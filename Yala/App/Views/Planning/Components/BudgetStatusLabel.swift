//
//  BudgetStatusLabel.swift
//  Yala
//
//  La palabra del estado de un presupuesto, debajo de su barra (decisión 23 de la revisión 2.3, Jürgen 2026-11-09):
//  un estado, una palabra, un color. «En el límite» (80–99 %) y «Llegaste al límite» (100 % justo) en naranja, como la
//  barra; «Te pasaste» (> 100 %) en rosa. Por debajo del 80 %, nada. El estado sale de `BudgetStatusCounter`: no hay
//  otro umbral. Hasta 2.3 la palabra solo existía para «en el límite» (decisión del 2026-11-05).
//

import SwiftUI

struct BudgetStatusLabel: View {
    let status: BudgetCounterStatus
    var font: Font = DS.Typography.captionSmall

    /// La palabra de cada estado; `nil` cuando no lleva ninguna (al día).
    static func word(for status: BudgetCounterStatus) -> String? {
        switch status {
        case .onTrack: nil
        case .atLimit: L10n.UXL9.atLimit
        case .reachedLimit: L10n.UXL9.reachedLimit
        case .overLimit: L10n.UXL9.overLimitWord
        }
    }

    /// El color de la palabra es el de la barra: naranja de aviso, o rosa al pasarse.
    static func color(for status: BudgetCounterStatus) -> Color {
        status == .overLimit ? Color.overBudgetText : DS.Semantic.warningForeground
    }

    var body: some View {
        if let word = Self.word(for: status) {
            Text(word)
                .font(font)
                .fontWeight(.semibold)
                .foregroundStyle(Self.color(for: status))
                .accessibilityIdentifier("budget_status_label")
        }
    }
}
