//
//  ExchangeRateDisplayFormatter.swift
//  Yala
//
//  Cómo se ESCRIBE un tipo de cambio en pantalla. Solo presentación: el valor y la dirección con
//  que se guarda `exchangeRate` no cambian.
//  Tickets `exchange-rate-detail-shows-zero-for-low-denomination-currencies` y
//  `widget-de-tc-no-localiza-separadores`.
//

import Foundation

/// El único formateador de tipos de cambio de la app.
///
/// **Existe porque cuatro decimales fijos (`String(format: "%.4f")`) fallaban de dos maneras.**
/// (1) Una tasa de denominación baja se borraba: la tasa se guarda como «divisa preferida por unidad
/// de divisa nativa», y 1 VND = 0,0000408 USD salía «0,0000». (2) `String(format:)` no localiza, así
/// que el widget del Panel escribía «3.8000» a quien lee «3,8».
///
/// La regla:
/// - **tasa ≥ 1** → entre 2 y 4 decimales, como la hoja de ganancia cambiaria: «3,80», «3,7512»,
///   «24.500,00». La parte entera nunca se redondea.
/// - **tasa < 1** → los decimales que hagan falta para ver **4 cifras significativas**:
///   «0,2667» (PEN→USD, igual que antes), «0,006667» (JPY→USD), «0,00004082» (VND→USD).
/// - Separadores del idioma: los mismos que los importes (`NumberFormatter` con el locale del
///   sistema, como `CurrencyFormattingHelper`), para que la tasa no contradiga al importe de al lado.
enum ExchangeRateDisplayFormatter {

    /// Cifras significativas que se ven en una tasa menor que 1.
    static let significantDigits = 4

    /// Techo de decimales. Con 4 significativas cubre tasas hasta ~1e-9, muy por debajo del par más
    /// extremo de la tabla (VND→KWD ≈ 1,2e-5).
    static let maximumFractionDigits = 12

    /// Decimales mínimos y máximos para escribir `rate`.
    static func fractionDigits(for rate: Double) -> (minimum: Int, maximum: Int) {
        let magnitude = abs(rate)
        guard magnitude.isFinite, magnitude > 0, magnitude < 1 else { return (2, 4) }
        // 0,0000408 → log10 = -4,39 → la primera cifra significativa cae en el 5.º decimal.
        let firstSignificantDecimal = -Int(floor(log10(magnitude)))
        let maximum = min(firstSignificantDecimal + significantDigits - 1, maximumFractionDigits)
        return (2, max(maximum, 2))
    }

    /// La tasa escrita para leerla: «0,00004082», «3,80».
    static func string(_ rate: Double, locale: Locale = .current) -> String {
        guard rate.isFinite else { return "—" }
        let digits = fractionDigits(for: rate)
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = digits.minimum
        formatter.maximumFractionDigits = digits.maximum
        return formatter.string(from: NSNumber(value: rate)) ?? "—"
    }

    /// Variante para quien guarda la tasa en `Decimal` (la hoja de ganancia cambiaria).
    static func string(_ rate: Decimal, locale: Locale = .current) -> String {
        string(NSDecimalNumber(decimal: rate).doubleValue, locale: locale)
    }
}
