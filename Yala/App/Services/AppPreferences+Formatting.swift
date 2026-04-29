//
//  AppPreferences+Formatting.swift
//  Yala
//
//  Reactive formatting helpers backed by @Observable AppPreferences.
//
//  Why this exists: SwiftUI views that call `appPreferences.currency(...)` from
//  their body register a dependency on `appPreferences.decimalPlaces` and
//  `appPreferences.currencyDisplayFormat` automatically (Observation tracking).
//  When the user changes either pref in Personalización, every view using these
//  helpers invalidates immediately — no navigation or restart required.
//
//  The actual formatting work is delegated to `CurrencyFormattingHelper` which
//  caches `NumberFormatter` instances. This file only resolves prefs and forwards.
//
//  Output is byte-identical to `YalaFormatterStatic` for the same prefs
//  (regression-guarded by parity tests in `AppPreferencesTests`).
//

import Foundation

extension AppPreferences {

    /// Returns the currency identifier (code or symbol) based on the user's
    /// `currencyDisplayFormat` preference.
    func currencyIdentifier(for currencyCode: String) -> String {
        currencyDisplayFormat == .symbol ? CurrencyUtils.symbol(for: currencyCode) : currencyCode
    }

    /// Formats a currency value: `PEN 20,000.00` or `S/ -20,000.00`.
    func currency(
        _ value: Double,
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

    /// Formats a number with `decimalPlaces`: `20,000.00` or `-20,000.00`.
    func number(_ value: Double, forceFullPrecision: Bool = false) -> String {
        CurrencyFormattingHelper.number(value, decimals: forceFullPrecision ? 2 : decimalPlaces)
    }

    /// Compact currency for table cells: uses abbreviation (1.2k) for large values.
    func currencyCompact(_ value: Double, currencyCode: String) -> String {
        if abs(value) >= 10_000 {
            return String(format: "%.1fk", value / 1000)
        }
        return currency(value, currencyCode: currencyCode)
    }

    /// Cash flow table cell: currency prefix + compact abbreviation. `S/ 9,999` / `PEN 10.5k`.
    func amountCashFlowCell(_ value: Double, currencyCode: String) -> String {
        let sym = currencyIdentifier(for: currencyCode)
        let sign = value < 0 ? "-" : ""
        let compact = YalaFormatter.amountCompactTable(value: abs(value))
        return "\(sign)\(sym) \(compact)"
    }
}
