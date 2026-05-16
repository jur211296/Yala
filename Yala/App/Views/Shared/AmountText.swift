//
//  AmountText.swift
//  Yala
//
//  SSOT compositivo para renderizar montos con jerarquía visual:
//  el entero domina (primary, peso semibold, tamaño grande); el símbolo
//  de divisa (`S/`, `$`, `PEN`) y los decimales viven en secondary
//  (peso regular, tamaño menor). Resultado: la cifra entera se lee
//  primero, los detalles complementan sin competir.
//
//  Reusa `appPreferences.currency(_:currencyCode:...)` para construir el
//  string y mantener byte-parity con el resto de la app (formatter cacheado,
//  preferencias reactivas). Solo añade composición visual y A11y.
//
//  Preview: requiere `.previewAppPreferences()` (PreviewHelpers.swift).
//

import SwiftUI

struct AmountText: View {
    let value: Double
    let currencyCode: String
    var size: Size = .body
    var forceSign: Bool = false
    var isEstimate: Bool = false

    @Environment(AppPreferences.self) private var prefs

    enum Size: Sendable, Hashable {
        case hero
        case kpi
        case headline
        case body
        case caption
    }

    var body: some View {
        let formatted = prefs.currency(
            value,
            currencyCode: currencyCode,
            forceSign: forceSign,
            isEstimate: isEstimate
        )
        let identifier = prefs.currencyIdentifier(for: currencyCode)
        let decimalSep = Locale.current.decimalSeparator ?? "."
        let runs = Self.splitFormatted(
            formatted,
            identifier: identifier,
            decimalSeparator: decimalSep
        )

        HStack(alignment: .firstTextBaseline, spacing: 2) {
            if !runs.symbol.isEmpty {
                Text(runs.symbol)
                    .font(symbolFont)
                    .foregroundStyle(.secondary)
            }

            Text(runs.sign + runs.integer)
                .font(integerFont)
                .foregroundStyle(.primary)

            if let decimal = runs.decimal {
                Text("\(decimalSep)\(decimal)")
                    .font(decimalFont)
                    .foregroundStyle(.secondary)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(formatted)
    }

    // MARK: - Font mapping

    private var integerFont: Font {
        switch size {
        case .hero:     return .system(size: 44, weight: .semibold)
        case .kpi:      return .system(size: 28, weight: .semibold)
        case .headline: return DS.Typography.headline
        case .body:     return DS.Typography.body
        case .caption:  return DS.Typography.caption
        }
    }

    private var symbolFont: Font {
        let style = Self.symbolFontStyle(for: size, displayFormat: prefs.currencyDisplayFormat)
        return .system(size: style.size, weight: style.weight)
    }

    private var decimalFont: Font {
        switch size {
        case .hero:     return .system(size: 20, weight: .regular)
        case .kpi:      return .system(size: 14, weight: .regular)
        case .headline: return DS.Typography.caption
        case .body:     return DS.Typography.caption
        case .caption:  return DS.Typography.captionSmall
        }
    }

    // MARK: - Pure-logic helpers (testable)

    /// Style del symbol según size + displayFormat. Codes (PEN/USD) usan
    /// peso medium y tamaño levemente mayor en `.hero` para balancear visualmente
    /// el glyph de 3 letras vs un símbolo compacto (`$`, `S/`).
    static func symbolFontStyle(
        for size: Size,
        displayFormat: CurrencyDisplayFormat
    ) -> (size: CGFloat, weight: Font.Weight) {
        switch size {
        case .hero:
            return displayFormat == .code ? (24, .medium) : (20, .regular)
        case .kpi:
            return displayFormat == .code ? (16, .medium) : (14, .regular)
        case .headline:
            return (13, .regular)
        case .body:
            return (12, .regular)
        case .caption:
            return (11, .regular)
        }
    }

    /// Parsea el output de `appPreferences.currency(...)` en 4 runs visuales.
    ///
    /// Formato esperado: `[≈ ]<identifier> [sign]<number>` donde number puede
    /// tener `<decimalSeparator>` para los decimales. Ej:
    /// - "S/ 2,266.37"     → ("S/", "", "2,266", "37")
    /// - "S/ -1,234.56"    → ("S/", "-", "1,234", "56")
    /// - "≈ PEN 1,234.56"  → ("≈ PEN", "", "1,234", "56")
    /// - "S/ 2.266,37"     → ("S/", "", "2.266", "37") con decimalSep=","
    /// - "¥ 1234"          → ("¥", "", "1234", nil)
    ///
    /// Fallback graceful: si el input no matchea el formato esperado,
    /// retorna `(identifier, "", formatted, nil)` para que el render no crashee.
    static func splitFormatted(
        _ formatted: String,
        identifier: String,
        decimalSeparator: String
    ) -> (symbol: String, sign: String, integer: String, decimal: String?) {
        let trimmed = formatted.trimmingCharacters(in: .whitespaces)
        let parts = trimmed.split(separator: " ", omittingEmptySubsequences: true).map(String.init)

        let symbol: String
        var numberStr: String

        if parts.count >= 3 && parts[0] == "≈" {
            symbol = "≈ \(parts[1])"
            numberStr = parts[2..<parts.count].joined(separator: " ")
        } else if parts.count == 2 {
            symbol = parts[0]
            numberStr = parts[1]
        } else {
            return (identifier, "", formatted, nil)
        }

        var sign = ""
        if numberStr.hasPrefix("-") {
            sign = "-"
            numberStr.removeFirst()
        } else if numberStr.hasPrefix("+") {
            sign = "+"
            numberStr.removeFirst()
        }

        let numParts = numberStr.components(separatedBy: decimalSeparator)
        let integer = numParts.first ?? "0"
        let decimal: String? = numParts.count > 1 ? numParts[1] : nil

        return (symbol, sign, integer, decimal)
    }
}

#Preview("Hero — positive") {
    AmountText(value: 2266.37, currencyCode: "USD", size: .hero)
        .padding()
        .previewAppPreferences()
}

#Preview("Hero — negative + estimate") {
    AmountText(value: -1234.56, currencyCode: "PEN", size: .hero, isEstimate: true)
        .padding()
        .previewAppPreferences()
}

#Preview("Sizes") {
    VStack(alignment: .leading, spacing: 16) {
        AmountText(value: 1234.56, currencyCode: "USD", size: .hero)
        AmountText(value: 1234.56, currencyCode: "USD", size: .kpi)
        AmountText(value: 1234.56, currencyCode: "USD", size: .headline)
        AmountText(value: 1234.56, currencyCode: "USD", size: .body)
        AmountText(value: 1234.56, currencyCode: "USD", size: .caption)
    }
    .padding()
    .previewAppPreferences()
}
