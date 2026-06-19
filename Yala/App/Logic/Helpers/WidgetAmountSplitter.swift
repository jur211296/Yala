//
//  WidgetAmountSplitter.swift
//  Yala
//
//  Pure-logic helper used by WidgetKit widgets to render amounts with
//  visual hierarchy: symbol + decimals subordinated to the integer.
//
//  Output canonical format: `<≈ optional><sign><symbol> <number>` —
//  alineado con CurrencyFormattingHelper del app principal.
//

import Foundation

enum WidgetAmountSplitter {
    /// Cache de NumberFormatter por `fractionDigits` × `locale.identifier`.
    /// Reusa el patrón de `CurrencyFormattingHelper`: evitar bootstrap ICU
    /// en cada render. App extensions no persisten estado entre launches.
    private static let formatterCache = NSCache<NSString, NumberFormatter>()

    private static func formatter(fractionDigits: Int, locale: Locale) -> NumberFormatter {
        let key = "\(locale.identifier)-\(fractionDigits)" as NSString
        if let cached = formatterCache.object(forKey: key) {
            return cached
        }
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = fractionDigits
        formatter.maximumFractionDigits = fractionDigits
        formatterCache.setObject(formatter, forKey: key)
        return formatter
    }

    /// Splits a numeric amount into visual runs for hierarchical rendering.
    ///
    /// - Parameters:
    ///   - value: numeric amount; sign derives from `value.signum()`.
    ///   - symbol: pre-resolved currency identifier (e.g. `"S/"`, `"$"`, `"USD"`).
    ///   - fractionDigits: digits after decimal separator (0 for heroes/rows, 2 for tx/payments).
    ///   - forceSign: when `true` and `value > 0`, prefixes `"+"` to the integer run.
    ///   - isEstimate: when `true`, prefixes `"≈ "` to the symbol run.
    ///   - locale: locale para formateo (default `.current`). Determina decimal Y grouping
    ///     separators de forma coherente — evita bugs en locales donde el grouping no es
    ///     "." o "," (ej. francés usa " ").
    /// - Returns: tuple con runs visuales + canonical accessibility string.
    ///   El run `decimal` incluye su propio separator (ej. `".56"` o `",56"`).
    static func split(
        value: Double,
        symbol: String,
        fractionDigits: Int,
        forceSign: Bool = false,
        isEstimate: Bool = false,
        locale: Locale = .current
    ) -> (symbol: String, sign: String, integer: String, decimal: String?, accessibilityFormatted: String) {
        let fmt = formatter(fractionDigits: fractionDigits, locale: locale)
        let formatted = fmt.string(from: NSNumber(value: abs(value))) ?? "0"

        let sign: String
        if value < 0 {
            sign = "-"
        } else if forceSign && value > 0 {
            sign = "+"
        } else {
            sign = ""
        }

        let displaySymbol = isEstimate ? "≈ \(symbol)" : symbol

        let decimalSep = fmt.decimalSeparator ?? "."
        let parts = formatted.components(separatedBy: decimalSep)
        let integer = parts.first ?? "0"
        let decimal: String? = (parts.count > 1) ? "\(decimalSep)\(parts[1])" : nil

        let approxPrefix = isEstimate ? "≈ " : ""
        let accessibility = "\(approxPrefix)\(sign)\(symbol) \(formatted)"

        return (displaySymbol, sign, integer, decimal, accessibility)
    }
}
