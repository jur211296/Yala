//
//  SankeyLabelModeToggle.swift
//  Yala
//
//  Two-segment glass pill for switching Sankey labels between currency amount
//  and percentage. Reuses the P-1/A-1 pattern (Circle + matchedGeometryEffect).
//
//  El botón de montos pinta el símbolo de la divisa en la que se ve el Sankey («S/», «€», «$»). Era un «$» fijo
//  (SF Symbol `dollarsign`) aunque la moneda fuera soles (lote 07 de mejoras necesarias 2.3).
//

import SwiftUI

struct SankeyLabelModeToggle: View {

    @Binding var mode: SankeyLabelMode
    /// La divisa en la que el Sankey pinta sus montos.
    let currencyCode: String
    @Environment(\.yalaTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var pillNamespace

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            button(for: .amount, glyph: .text(Self.amountSymbol(for: currencyCode)),
                   accessibilityLabel: L10n.Statistics.Sankey.toggleAmount)
            button(for: .percentage, glyph: .symbol("percent"),
                   accessibilityLabel: L10n.Statistics.Sankey.togglePercentage)
        }
        // Implícita en el propio selector: en una pestaña un `withAnimation` no anima (card oxyr).
        .dsAnimation(DS.Animation.selection, value: mode, reduceMotion: reduceMotion)
    }

    /// El símbolo con el que se pintan los montos de esa divisa, el mismo de `CurrencyCode.symbol`.
    static func amountSymbol(for currencyCode: String) -> String {
        CurrencyUtils.symbol(for: currencyCode)
    }

    private enum Glyph {
        case text(String)
        case symbol(String)
    }

    @ViewBuilder
    private func glyphView(_ glyph: Glyph) -> some View {
        switch glyph {
        case .text(let text):
            Text(verbatim: text)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.horizontal, DS.Spacing.xxs)
        case .symbol(let name):
            Image(systemName: name)
        }
    }

    private func button(
        for target: SankeyLabelMode,
        glyph: Glyph,
        accessibilityLabel: String
    ) -> some View {
        let isSelected = mode == target

        return Button {
            mode = target
        } label: {
            glyphView(glyph)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isSelected ? theme.onAccent : theme.secondaryText)
                .frame(width: DS.Icon.badgeMedium, height: DS.Icon.badgeMedium)
                .background {
                    if isSelected {
                        Circle()
                            .fill(theme.accent)
                            .matchedGeometryEffect(id: "sankeyToggle", in: pillNamespace)
                    } else {
                        Circle()
                            .fill(.thSecondaryText.opacity(0.08))
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
