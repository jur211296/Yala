//
//  YalaFormatterStatic.swift
//  Yala
//
//  Static currency/number formatting for callers OUTSIDE of `@MainActor` —
//  notably AppIntents (which run in a non-MainActor context where the
//  `@MainActor`-isolated `AppPreferences` cannot be accessed).
//
//  Reads `decimalPlaces` and `currencyDisplayFormat` directly from
//  `UserDefaults.standard` — output is byte-identical to `appPreferences.X(...)`
//  for the same prefs.
//
//  RULE: in `@MainActor` (Views, ViewModels) use `appPreferences.X(...)` for
//  reactive invalidation. Out of MainActor use `YalaFormatterStatic.X(...)`.
//  The compiler arbitrates because `AppPreferences` is `@MainActor`-isolated.
//

import Foundation

enum YalaFormatterStatic {

    private static var decimalPlaces: Int {
        if UserDefaults.standard.object(forKey: "decimalPlaces") == nil {
            // Migration: older builds stored a Bool flag instead of an Int.
            if UserDefaults.standard.object(forKey: "useRoundedAmounts") != nil {
                let oldValue = UserDefaults.standard.bool(forKey: "useRoundedAmounts")
                return oldValue ? 0 : 2
            }
            return 2
        }
        return UserDefaults.standard.integer(forKey: "decimalPlaces")
    }

    private static var currencyDisplayFormat: String {
        UserDefaults.standard.string(forKey: "currencyDisplayFormat") ?? "symbol"
    }

    static func currencyIdentifier(for code: String) -> String {
        currencyDisplayFormat == "symbol" ? CurrencyUtils.symbol(for: code) : code
    }

    static func currency(
        value: Double,
        currencyCode: String,
        forceSign: Bool = false,
        forceFullPrecision: Bool = false,
        isEstimate: Bool = false
    ) -> String {
        CurrencyFormattingHelper.currency(
            value,
            decimals: forceFullPrecision ? 2 : decimalPlaces,
            identifier: currencyIdentifier(for: currencyCode),
            forceSign: forceSign,
            isEstimate: isEstimate
        )
    }

    static func number(value: Double, forceFullPrecision: Bool = false) -> String {
        CurrencyFormattingHelper.number(value, decimals: forceFullPrecision ? 2 : decimalPlaces)
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
