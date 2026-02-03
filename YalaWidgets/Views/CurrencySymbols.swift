//
//  CurrencySymbols.swift
//  YalaWidgets
//
//  Currency symbol lookup for widgets.
//  Subset of main app's CurrencyUtils.swift for widget use.
//

import Foundation

/// Helper to get currency symbols without pulling in full CurrencyUtils
enum CurrencySymbols {
    /// Returns the symbol for a currency code
    static func symbol(for code: String) -> String {
        switch code.uppercased() {
        case "PEN": return "S/"
        case "USD": return "$"
        case "EUR": return "€"
        case "MXN": return "$"
        case "COP": return "$"
        case "BRL": return "R$"
        case "GBP": return "£"
        case "ARS": return "$"
        case "CLP": return "$"
        case "UYU": return "$"
        case "BOB": return "Bs"
        case "PYG": return "₲"
        case "VES": return "Bs"
        case "JPY": return "¥"
        case "CNY": return "¥"
        case "KRW": return "₩"
        case "INR": return "₹"
        case "CAD": return "$"
        case "AUD": return "$"
        case "CHF": return "Fr"
        default: return code
        }
    }
}
