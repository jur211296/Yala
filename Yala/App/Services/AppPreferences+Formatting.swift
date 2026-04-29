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
//  Use these instead of `YalaFormatter.X(...)` for any amount rendered in a
//  view body, view-bound state, or view-scoped computed property.
//
//  Output is byte-identical to `YalaFormatter` for the same prefs (regression-
//  guarded by `AppPreferencesFormattingParityTests`).
//

import Foundation

extension AppPreferences {

    /// Returns the currency identifier (code or symbol) based on the user's
    /// `currencyDisplayFormat` preference.
    func currencyIdentifier(for currencyCode: String) -> String {
        if currencyDisplayFormat == .symbol {
            return CurrencyUtils.symbol(for: currencyCode)
        }
        return currencyCode
    }

    /// Formats a currency value: `PEN 20,000.00` or `S/ -20,000.00`.
    /// Honors `decimalPlaces` and `currencyDisplayFormat` reactively.
    func currency(
        _ value: Double,
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

    /// Formats a number with `decimalPlaces`: `20,000.00` or `-20,000.00`.
    func number(_ value: Double, forceFullPrecision: Bool = false) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal

        let decimals = forceFullPrecision ? 2 : decimalPlaces
        formatter.minimumFractionDigits = decimals
        formatter.maximumFractionDigits = decimals

        let fallback = decimals == 0 ? "0" : (decimals == 1 ? "0.0" : "0.00")
        return formatter.string(from: NSNumber(value: value)) ?? fallback
    }

    /// Compact currency for table cells: uses abbreviation (1.2k) for large values.
    func currencyCompact(_ value: Double, currencyCode: String) -> String {
        if abs(value) >= 10_000 {
            return String(format: "%.1fk", value / 1000)
        }
        return currency(value, currencyCode: currencyCode)
    }

    /// Cash flow table cell: currency prefix (respects user preference) + compact.
    /// `S/ 9,999` / `PEN 10.5k`. Uses `YalaFormatter.amountCompactTable` (pure helper).
    func amountCashFlowCell(_ value: Double, currencyCode: String) -> String {
        let sym = currencyIdentifier(for: currencyCode)
        let sign = value < 0 ? "-" : ""
        let compact = YalaFormatter.amountCompactTable(value: abs(value))
        return "\(sign)\(sym) \(compact)"
    }
}
