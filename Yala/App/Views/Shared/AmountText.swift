//
//  AmountText.swift
//  Yala
//
//  SSOT compositivo para renderizar montos con jerarquía visual:
//  el entero domina (font del callsite, color primary); el símbolo
//  de divisa (`S/`, `$`, `PEN`) y los decimales viven con un font
//  más chico (default `.caption`) y color un tono menos. Resultado:
//  la cifra entera se lee primero, los detalles complementan sin competir.
//
//  El callsite controla los fonts — AmountText respeta el contexto
//  visual (rows, headers, heroes) sin imponer tamaños propios. Para
//  heroes destacados existen tokens `DS.Typography.heroAmount` +
//  `heroAmountSecondary` reusables.
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
    var font: Font = DS.Typography.body
    var secondaryFont: Font = DS.Typography.caption
    var tint: Tint = .primary
    var forceSign: Bool = false
    var isEstimate: Bool = false
    var forceFullPrecision: Bool = false

    @Environment(AppPreferences.self) private var prefs

    /// Color hierarchy del monto. El símbolo y los decimales viven
    /// "un tono menos" que el integer principal.
    ///
    /// - `.primary` (default): integer `.primary`, símbolo/decimales `.secondary`.
    /// - `.secondary`: integer `.secondary`, símbolo/decimales `.tertiary`. Para
    ///   amounts en rows neutros que no compiten con el contenido principal.
    /// - `.color(Color)`: integer en color custom (income/expense/success/etc),
    ///   símbolo/decimales en mismo color con opacity 0.6 para mantener jerarquía.
    enum Tint: Sendable {
        case primary
        case secondary
        case color(Color)
    }

    var body: some View {
        let formatted = prefs.currency(
            value,
            currencyCode: currencyCode,
            forceSign: forceSign,
            forceFullPrecision: forceFullPrecision,
            isEstimate: isEstimate
        )
        let identifier = prefs.currencyIdentifier(for: currencyCode)
        let decimalSep = Locale.current.decimalSeparator ?? "."
        let runs = Self.splitFormatted(
            formatted,
            identifier: identifier,
            decimalSeparator: decimalSep
        )

        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xxs) {
            if !runs.symbol.isEmpty {
                Text(runs.symbol)
                    .font(secondaryFont)
                    .foregroundStyle(secondaryForegroundStyle)
            }

            Text(runs.sign + runs.integer)
                .font(font)
                .foregroundStyle(integerForegroundStyle)

            if let decimal = runs.decimal {
                Text("\(decimalSep)\(decimal)")
                    .font(secondaryFont)
                    .foregroundStyle(secondaryForegroundStyle)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(formatted)
    }

    // MARK: - Tint mapping

    private var integerForegroundStyle: AnyShapeStyle {
        switch tint {
        case .primary:        return AnyShapeStyle(HierarchicalShapeStyle.primary)
        case .secondary:      return AnyShapeStyle(HierarchicalShapeStyle.secondary)
        case .color(let c):   return AnyShapeStyle(c)
        }
    }

    private var secondaryForegroundStyle: AnyShapeStyle {
        switch tint {
        case .primary:        return AnyShapeStyle(HierarchicalShapeStyle.secondary)
        case .secondary:      return AnyShapeStyle(HierarchicalShapeStyle.tertiary)
        case .color(let c):   return AnyShapeStyle(c.opacity(0.6))
        }
    }

    // MARK: - Attributed string helper (for composed strings like "Tienes X en N cuentas")

    /// Devuelve un `AttributedString` con la misma jerarquía visual del componente:
    /// symbol/decimal con `secondaryFont` y `.secondary` foreground, integer con
    /// `integerFont` y foreground primary (o color si `tintColor != nil`).
    ///
    /// Usado para componer subtitles donde el monto va embebido en otra cadena
    /// (ej. `L10n.Panel.panoramaCollapsedSummary`). El callsite es responsable
    /// de concatenar runs primary alrededor del retorno.
    @MainActor
    static func attributedAmount(
        value: Double,
        currencyCode: String,
        prefs: AppPreferences,
        integerFont: Font = .subheadline,
        secondaryFont: Font = .caption,
        tintColor: Color? = nil,
        forceFullPrecision: Bool = false
    ) -> AttributedString {
        let formatted = prefs.currency(
            value,
            currencyCode: currencyCode,
            forceFullPrecision: forceFullPrecision
        )
        let identifier = prefs.currencyIdentifier(for: currencyCode)
        let decimalSep = Locale.current.decimalSeparator ?? "."
        let runs = splitFormatted(formatted, identifier: identifier, decimalSeparator: decimalSep)

        var result = AttributedString()

        if !runs.symbol.isEmpty {
            var symbolRun = AttributedString(runs.symbol + " ")
            symbolRun.font = secondaryFont
            if let tintColor {
                symbolRun.foregroundColor = tintColor.opacity(0.6)
            }
            result.append(symbolRun)
        }

        var integerRun = AttributedString(runs.sign + runs.integer)
        integerRun.font = integerFont
        if let tintColor {
            integerRun.foregroundColor = tintColor
        }
        result.append(integerRun)

        if let decimal = runs.decimal {
            var decimalRun = AttributedString("\(decimalSep)\(decimal)")
            decimalRun.font = secondaryFont
            if let tintColor {
                decimalRun.foregroundColor = tintColor.opacity(0.6)
            }
            result.append(decimalRun)
        }

        return result
    }

    // MARK: - Pure-logic helpers (testable)

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
    AmountText(
        value: 2266.37,
        currencyCode: "USD",
        font: DS.Typography.heroAmount,
        secondaryFont: DS.Typography.heroAmountSecondary
    )
    .padding()
    .previewAppPreferences()
}

#Preview("Hero — negative + estimate") {
    AmountText(
        value: -1234.56,
        currencyCode: "PEN",
        font: DS.Typography.heroAmount,
        secondaryFont: DS.Typography.heroAmountSecondary,
        isEstimate: true
    )
    .padding()
    .previewAppPreferences()
}

#Preview("Sizes") {
    VStack(alignment: .leading, spacing: 16) {
        AmountText(
            value: 1234.56, currencyCode: "USD",
            font: DS.Typography.heroAmount,
            secondaryFont: DS.Typography.heroAmountSecondary
        )
        AmountText(value: 1234.56, currencyCode: "USD", font: DS.Typography.largeTitle)
        AmountText(value: 1234.56, currencyCode: "USD", font: DS.Typography.title2)
        AmountText(value: 1234.56, currencyCode: "USD", font: DS.Typography.headline)
        AmountText(value: 1234.56, currencyCode: "USD")
        AmountText(value: 1234.56, currencyCode: "USD", font: DS.Typography.subheadline, secondaryFont: DS.Typography.captionSmall)
        AmountText(value: 1234.56, currencyCode: "USD", font: DS.Typography.caption, secondaryFont: DS.Typography.captionSmall)
    }
    .padding()
    .previewAppPreferences()
}
