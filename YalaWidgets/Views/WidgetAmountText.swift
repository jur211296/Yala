//
//  WidgetAmountText.swift
//  YalaWidgets
//
//  SSOT compositivo para amounts en widgets WidgetKit.
//
//  Renderiza un monto con jerarquía visual: el integer domina (font primary);
//  el símbolo de divisa (`S/`, `$`, `PEN`), prefix `≈` y los decimales viven
//  en `secondaryFont` + foreground "un tone menos". Espeja la regla establecida
//  por `AmountText` en el app principal.
//
//  Standalone: no depende de `AppPreferences`. Resuelve el currency symbol con
//  `CurrencySymbols.symbol(for:)` y delega la lógica de split en
//  `WidgetAmountSplitter` (shared con target Yala vía membership exception).
//

import SwiftUI
import WidgetKit

struct WidgetAmountText: View {
    let value: Double
    let currencyCode: String
    var displayFormat: String = "symbol"
    var font: Font = WDS.Typography.value
    var secondaryFont: Font = WDS.Typography.valueSecondary
    var tint: Tint = .primary
    var forceSign: Bool = false
    var isEstimate: Bool = false
    var fractionDigits: Int = 0

    /// Color hierarchy del monto. Symbol y decimales viven "un tone menos" que el integer.
    ///
    /// - `.primary`: integer `.primary`, symbol/decimal `.secondary`.
    /// - `.secondary`: integer `.secondary`, symbol/decimal `.tertiary`.
    /// - `.color(Color)`: integer en color custom, symbol/decimal en mismo color con `opacity(0.6)`.
    enum Tint: Sendable {
        case primary
        case secondary
        case color(Color)
    }

    var body: some View {
        let symbolRaw = (displayFormat == "symbol")
            ? CurrencySymbols.symbol(for: currencyCode)
            : currencyCode
        let runs = WidgetAmountSplitter.split(
            value: value,
            symbol: symbolRaw,
            fractionDigits: fractionDigits,
            forceSign: forceSign,
            isEstimate: isEstimate
        )

        HStack(alignment: .firstTextBaseline, spacing: 2) {
            if !runs.symbol.isEmpty {
                Text(runs.symbol)
                    .font(secondaryFont)
                    .foregroundStyle(secondaryForegroundStyle)
            }

            Text(runs.sign + runs.integer)
                .font(font)
                .foregroundStyle(integerForegroundStyle)

            if let decimal = runs.decimal {
                Text(decimal)
                    .font(secondaryFont)
                    .foregroundStyle(secondaryForegroundStyle)
            }
        }
        .lineLimit(1)
        // 0.5 (vs 0.7 de AmountText): widgets tienen restricción de espacio dura;
        // un balance largo S/ 99,999,999 debe poder caber en Small widget.
        .minimumScaleFactor(0.5)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(runs.accessibilityFormatted)
    }

    // MARK: - Tint mapping

    private var integerForegroundStyle: AnyShapeStyle {
        switch tint {
        case .primary:      return AnyShapeStyle(HierarchicalShapeStyle.primary)
        case .secondary:    return AnyShapeStyle(HierarchicalShapeStyle.secondary)
        case .color(let c): return AnyShapeStyle(c)
        }
    }

    private var secondaryForegroundStyle: AnyShapeStyle {
        switch tint {
        case .primary:      return AnyShapeStyle(HierarchicalShapeStyle.secondary)
        case .secondary:    return AnyShapeStyle(HierarchicalShapeStyle.tertiary)
        case .color(let c): return AnyShapeStyle(c.opacity(0.6))
        }
    }
}

// MARK: - Previews

#Preview("Basic — canary pbxproj edit") {
    VStack(alignment: .leading, spacing: 12) {
        WidgetAmountText(value: 1234.56, currencyCode: "PEN", fractionDigits: 2)
        WidgetAmountText(value: -1234.56, currencyCode: "USD", isEstimate: true, fractionDigits: 2)
        WidgetAmountText(
            value: 99999,
            currencyCode: "PEN",
            font: WDS.Typography.kpiLarge,
            secondaryFont: WDS.Typography.kpiLargeSecondary
        )
        WidgetAmountText(
            value: 45.50,
            currencyCode: "PEN",
            tint: .color(WidgetColors.income),
            forceSign: true,
            fractionDigits: 2
        )
    }
    .padding()
}
