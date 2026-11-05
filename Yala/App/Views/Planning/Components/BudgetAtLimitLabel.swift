//
//  BudgetAtLimitLabel.swift
//  Yala
//
//  «En el límite» junto a la barra naranja del presupuesto (decisión de Jürgen, 2026-11-05). El color ya avisaba desde
//  el 80 %; la palabra nombra lo que avisa. El umbral es el de `BudgetStatusCounter`: no hay otro.
//

import SwiftUI

struct BudgetAtLimitLabel: View {
    var font: Font = DS.Typography.captionSmall

    /// Solo «en el límite» (80–99 %). Pasado el límite ya lo dicen el rosa, el triángulo y el ánimo de debajo.
    static func isShown(spent: Double, limit: Double) -> Bool {
        BudgetStatusCounter.classify(spent: spent, limit: limit) == .atLimit
    }

    var body: some View {
        Text(L10n.UXL9.atLimit)
            .font(font)
            .fontWeight(.semibold)
            .foregroundStyle(DS.Semantic.warningForeground)
            .accessibilityIdentifier("budget_at_limit_label")
    }
}
