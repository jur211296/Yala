//
//  CompactNumberFormat.swift
//  Yala
//
//  Formato compacto de montos sin símbolo de divisa para celdas pequeñas
//  (calendario de Registros). Respeta el separador decimal del locale.
//

import Foundation

/// Abrevia montos para que quepan en una celda de calendario:
/// `340`, `1.2k`, `12k`, `1.2M`. Siempre magnitud (sin signo) y sin símbolo de divisa.
/// El separador decimal sigue el locale (`1,2k` en español, `1.2k` en inglés).
enum CompactAmountFormatter {

    /// Monto abreviado (magnitud absoluta, sin símbolo de divisa).
    ///
    /// Formato manual (sin `NumberFormatter`, que es caro de instanciar y se llamaría
    /// una vez por celda en cada render); solo se consulta el separador decimal del locale.
    static func string(_ value: Double, locale: Locale = .current) -> String {
        let magnitude = abs(value)

        // Bajo mil: entero, sin sufijo ni separador de miles.
        if magnitude < 1_000 {
            return String(Int(magnitude.rounded()))
        }

        let scaled: Double
        let suffix: String
        if magnitude < 1_000_000 {
            scaled = magnitude / 1_000
            suffix = "k"
        } else {
            scaled = magnitude / 1_000_000
            suffix = "M"
        }

        // 1 decimal, recortando el ".0" redundante (1.0k → 1k).
        let tenths = Int((scaled * 10).rounded())
        let intPart = tenths / 10
        let decimal = tenths % 10
        if decimal == 0 {
            return "\(intPart)\(suffix)"
        }
        let separator = locale.decimalSeparator ?? "."
        return "\(intPart)\(separator)\(decimal)\(suffix)"
    }
}
