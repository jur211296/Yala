//
//  YalaFormatterStatic.swift
//  Yala
//
//  Static currency/number formatting for callers OUTSIDE of `@MainActor` —
//  notably AppIntents (which run in a non-MainActor context where the
//  `@MainActor`-isolated `AppPreferences` cannot be accessed).
//
//  Reads `decimalPlaces` and `currencyDisplayFormat` directly from
//  `UserDefaults.standard` — output is byte-identical to the (now-removed)
//  static methods on `YalaFormatter` and to `AppPreferences.X(...)` for the
//  same prefs.
//
//  RULE: in `@MainActor` (Views, ViewModels) use `appPreferences.X(...)` for
//  reactive invalidation. Out of MainActor use `YalaFormatterStatic.X(...)`.
//  The compiler arbitrates because `AppPreferences` is `@MainActor`-isolated.
//

import Foundation

enum YalaFormatterStatic {

    private static var decimalPlaces: Int {
        if UserDefaults.standard.object(forKey: "decimalPlaces") == nil {
            if UserDefaults.standard.object(forKey: "useRoundedAmounts") != nil {
                let oldValue = UserDefaults.standard.bool(forKey: "useRoundedAmounts")
                return oldValue ? 0 : 2
            }
            return 0
        }
        return UserDefaults.standard.integer(forKey: "decimalPlaces")
    }

    private static var currencyDisplayFormat: String {
        UserDefaults.standard.string(forKey: "currencyDisplayFormat") ?? "code"
    }

    static func currencyIdentifier(for code: String) -> String {
        if currencyDisplayFormat == "symbol" {
            return CurrencyUtils.symbol(for: code)
        }
        return code
    }

    static func currency(
        value: Double,
        currencyCode: String,
        forceSign: Bool = false,
        forceFullPrecision: Bool = false,
        isEstimate: Bool = false
    ) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal

        let decimals = forceFullPrecision ? 2 : decimalPlaces
        formatter.minimumFractionDigits = decimals
        formatter.maximumFractionDigits = decimals

        let absoluteValue = abs(value)
        let fallback = decimals == 0 ? "0" : (decimals == 1 ? "0.0" : "0.00")
        let formattedNumber = formatter.string(from: NSNumber(value: absoluteValue)) ?? fallback

        var signedNumber = formattedNumber
        if value < 0 {
            signedNumber = "-\(formattedNumber)"
        } else if forceSign && value > 0 {
            signedNumber = "+\(formattedNumber)"
        }

        let identifier = currencyIdentifier(for: currencyCode)
        let estimatePrefix = isEstimate ? "≈ " : ""
        return "\(estimatePrefix)\(identifier) \(signedNumber)"
    }

    static func number(value: Double, forceFullPrecision: Bool = false) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal

        let decimals = forceFullPrecision ? 2 : decimalPlaces
        formatter.minimumFractionDigits = decimals
        formatter.maximumFractionDigits = decimals

        let fallback = decimals == 0 ? "0" : (decimals == 1 ? "0.0" : "0.00")
        return formatter.string(from: NSNumber(value: value)) ?? fallback
    }

    static func currencyCompact(value: Double, currencyCode: String) -> String {
        if abs(value) >= 10_000 {
            return String(format: "%.1fk", value / 1000)
        }
        return currency(value: value, currencyCode: currencyCode)
    }

    static func amountCashFlowCell(value: Double, currencyCode: String) -> String {
        let sym = currencyIdentifier(for: currencyCode)
        let sign = value < 0 ? "-" : ""
        let compact = YalaFormatter.amountCompactTable(value: abs(value))
        return "\(sign)\(sym) \(compact)"
    }
}
