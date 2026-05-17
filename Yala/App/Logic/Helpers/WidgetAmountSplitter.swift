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
//  Lives in the main Yala target but is also member of YalaWidgetsExtension
//  via pbxproj membershipExceptions. Tests access it through `@testable import Yala`.
//
//  El splitter NO conoce currencies — recibe el symbol ya resuelto. La resolución
//  de currency code → symbol vive en el callsite (WidgetAmountText usa
//  CurrencySymbols del target widget).
//

import Foundation

enum WidgetAmountSplitter {
    /// Splits a numeric amount into visual runs for hierarchical rendering.
    ///
    /// - Parameters:
    ///   - value: numeric amount; sign derives from `value.signum()`.
    ///   - symbol: pre-resolved currency identifier (e.g. `"S/"`, `"$"`, `"USD"`).
    ///   - fractionDigits: digits after decimal separator (0 for heroes/rows, 2 for tx/payments).
    ///   - forceSign: when `true` and `value > 0`, prefixes `"+"` to the integer run.
    ///   - isEstimate: when `true`, prefixes `"≈ "` to the symbol run.
    ///   - decimalSeparator: locale separator (default `"."`).
    /// - Returns: tuple with the 4 visual runs + a canonical accessibility string.
    static func split(
        value: Double,
        symbol: String,
        fractionDigits: Int,
        forceSign: Bool = false,
        isEstimate: Bool = false,
        decimalSeparator: String = "."
    ) -> (symbol: String, sign: String, integer: String, decimal: String?, accessibilityFormatted: String) {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = fractionDigits
        formatter.maximumFractionDigits = fractionDigits
        formatter.decimalSeparator = decimalSeparator
        // Grouping coherente con el decimal: "," decimal → "." grouping, y viceversa.
        // Sin esto el formatter usa el locale default y produce strings inconsistentes
        // cuando el decimal forzado colisiona con el grouping default (ej. "1,234,56").
        formatter.groupingSeparator = (decimalSeparator == ",") ? "." : ","
        formatter.usesGroupingSeparator = true
        let formatted = formatter.string(from: NSNumber(value: abs(value))) ?? "0"

        let sign: String
        if value < 0 {
            sign = "-"
        } else if forceSign && value > 0 {
            sign = "+"
        } else {
            sign = ""
        }

        let displaySymbol = isEstimate ? "≈ \(symbol)" : symbol

        let parts = formatted.components(separatedBy: decimalSeparator)
        let integer = parts.first ?? "0"
        let decimal: String? = (parts.count > 1) ? parts[1] : nil

        let approxPrefix = isEstimate ? "≈ " : ""
        let accessibility = "\(approxPrefix)\(sign)\(symbol) \(formatted)"

        return (displaySymbol, sign, integer, decimal, accessibility)
    }
}
