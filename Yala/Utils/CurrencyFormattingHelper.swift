//
//  CurrencyFormattingHelper.swift
//  Yala
//
//  Pure formatting primitives shared between `AppPreferences+Formatting`
//  (reactive, MainActor) and `YalaFormatterStatic` (snapshot, non-MainActor).
//
//  NumberFormatter is expensive to instantiate (locale resolution + ICU bootstrap
//  on first use). With this helper, the app keeps 3 cached formatters total —
//  one per supported `decimalPlaces` value (0/1/2) — instead of allocating a new
//  one on every body re-render.
//

import Foundation

enum CurrencyFormattingHelper {

    /// Cached `NumberFormatter` instances keyed by `decimalPlaces`.
    /// `NumberFormatter` is thread-safe for read access since iOS 7 (WWDC 2018
    /// "What's New in Foundation" confirmed). Mutation is guarded by only being
    /// done at initialization, never after.
    private static let formatters: [Int: NumberFormatter] = {
        var dict: [Int: NumberFormatter] = [:]
        for decimals in 0...2 {
            let f = NumberFormatter()
            f.numberStyle = .decimal
            f.minimumFractionDigits = decimals
            f.maximumFractionDigits = decimals
            dict[decimals] = f
        }
        return dict
    }()

    private static func formatter(for decimals: Int) -> NumberFormatter {
        formatters[decimals] ?? formatters[2]!
    }

    private static func fallback(for decimals: Int) -> String {
        decimals == 0 ? "0" : (decimals == 1 ? "0.0" : "0.00")
    }

    /// Formats a currency value: `PEN 20,000.00` or `S/ -20,000.00`.
    /// `decimals` and `identifier` must be already resolved by the caller.
    static func currency(
        _ value: Double,
        decimals: Int,
        identifier: String,
        forceSign: Bool,
        isEstimate: Bool
    ) -> String {
        let absoluteValue = abs(value)
        let formattedNumber = formatter(for: decimals)
            .string(from: NSNumber(value: absoluteValue)) ?? fallback(for: decimals)

        var signedNumber = formattedNumber
        if value < 0 {
            signedNumber = "-\(formattedNumber)"
        } else if forceSign && value > 0 {
            signedNumber = "+\(formattedNumber)"
        }

        let estimatePrefix = isEstimate ? "≈ " : ""
        return "\(estimatePrefix)\(identifier) \(signedNumber)"
    }

    /// Formats a number with `decimals`: `20,000.00` or `-20,000.00`.
    static func number(_ value: Double, decimals: Int) -> String {
        formatter(for: decimals)
            .string(from: NSNumber(value: value)) ?? fallback(for: decimals)
    }
}
