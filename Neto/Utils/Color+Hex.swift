import SwiftUI

extension Color {
    /// Inicializa un Color a partir de un string hexadecimal (ej. "#1C3556" o "1C3556").
    /// Soporta formatos de 6 dígitos.
    public init(hex: String) {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("#") {
            cleaned.removeFirst()
        }

        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)

        let r: Double
        let g: Double
        let b: Double
        switch cleaned.count {
        case 6:
            r = Double((int & 0xFF0000) >> 16) / 255.0
            g = Double((int & 0x00FF00) >> 8) / 255.0
            b = Double(int & 0x0000FF) / 255.0
        default:
            r = 0.0
            g = 0.0
            b = 0.0
        }

        self.init(red: r, green: g, blue: b)
    }
}
