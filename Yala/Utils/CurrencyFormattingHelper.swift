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
    private nonisolated static let formatters: [Int: NumberFormatter] = {
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

    private nonisolated static func formatter(for decimals: Int) -> NumberFormatter {
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

        // Lo que se pinta como cero no lleva signo: ni «-0.00» ni «+0.00».
        let shownAsZero = isShownAsZero(value, using: formatter(for: decimals))
        var signedNumber = formattedNumber
        if value < 0 && !shownAsZero {
            signedNumber = "-\(formattedNumber)"
        } else if forceSign && value > 0 && !shownAsZero {
            signedNumber = "+\(formattedNumber)"
        }

        let estimatePrefix = isEstimate ? "≈ " : ""
        return "\(estimatePrefix)\(identifier) \(signedNumber)"
    }

    /// Formats a number with `decimals`: `20,000.00` or `-20,000.00`.
    static func number(_ value: Double, decimals: Int) -> String {
        let fmt = formatter(for: decimals)
        let shown = isShownAsZero(value, using: fmt) ? 0 : value
        return fmt.string(from: NSNumber(value: shown)) ?? fallback(for: decimals)
    }

    /// `true` cuando `formatter` pinta `value` como su cero: «-0.00» no es un importe.
    ///
    /// Una suma en coma flotante que debería dar cero da `-1e-14`, y el formateador redondea a «-0.00» conservando el
    /// signo (medido: la cuenta «Euros» del Excel real de Jürgen, 73 movimientos que suman cero, salía «€ -0.00» en
    /// Ajustes › Cuentas). Se compara con lo que el MISMO formateador escribe para el cero, así que vale con cualquier
    /// número de decimales y cualquier modo de redondeo sin repetir la aritmética. Un formateador que pinte un importe
    /// llama aquí antes de decidir el signo.
    /// Lo mismo con el formateador de `decimals` decimales de la app: para quien decide un signo, un color o un rótulo de
    /// deuda sobre un importe que se pinta con `currency(_:decimals:…)`. `nonisolated`: la lógica de las tarjetas del
    /// Panel lo es, y los formateadores cacheados solo se leen (ver `formatters`).
    nonisolated static func isShownAsZero(_ value: Double, decimals: Int = 2) -> Bool {
        isShownAsZero(value, using: formatter(for: decimals))
    }

    nonisolated static func isShownAsZero(_ value: Double, using formatter: NumberFormatter) -> Bool {
        guard value != 0 else { return true }
        guard value.isFinite else { return false }
        return formatter.string(from: NSNumber(value: abs(value))) == formatter.string(from: NSNumber(value: 0))
    }
}
