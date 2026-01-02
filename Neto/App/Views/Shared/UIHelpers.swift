//
//  UIHelpers.swift
//  Neto
//
//  Created by Neto Refactoring.
//  Updated by Audit & Refactoring Agent.
//

import SwiftData
import SwiftUI

#if canImport(UIKit)
    import UIKit
#endif

// MARK: - Design System Constants

/// Constantes de diseño para asegurar consistencia en Espaciado y Radios.
struct DesignSystem {
    enum Spacing {
        /// 4.0
        static let two: CGFloat = 2
        /// 4.0
        static let four: CGFloat = 4
        /// 8.0
        static let standard: CGFloat = 8
        /// 12.0
        static let medium: CGFloat = 12
        /// 16.0
        static let large: CGFloat = 16
        /// 20.0
        static let xLarge: CGFloat = 20
        /// 24.0
        static let xxLarge: CGFloat = 24
        /// 32.0
        static let triple: CGFloat = 32
    }

    enum Radius {
        /// 8.0
        static let small: CGFloat = 8
        /// 12.0
        static let standard: CGFloat = 12
        /// 16.0
        static let large: CGFloat = 16
        /// 24.0
        static let xLarge: CGFloat = 24
    }

    enum Opacity {
        static let glass: Double = 0.6
        static let subtle: Double = 0.1
    }
}

// MARK: - Enums de apoyo

enum AccountType: String, CaseIterable, Identifiable {
    case general = "General"
    case cash = "Efectivo"
    case checking = "Cuenta corriente"
    case savings = "Cuenta de ahorros"

    var id: String { rawValue }
}

enum AdjustmentMode: String, CaseIterable, Identifiable {
    case byEntry = "Ajustar por registro"
    case changeInitialBalance = "Cambiar saldo inicial"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .byEntry:
            return
                "Escribe el saldo correcto y crearemos un registro de corrección. Úsalo si se te olvidó registrar algunos gastos."
        case .changeInitialBalance:
            return
                "Escribe el saldo correcto y cambiaremos el saldo inicial en tu cuenta. Usa esto si no has registrado durante mucho tiempo."
        }
    }
}

enum AppTheme: Int, CaseIterable, Identifiable {
    case system = 0
    case light = 1
    case dark = 2

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .system: return "Sistema"
        case .light: return "Claro"
        case .dark: return "Oscuro"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// MARK: - Helper Functions

/// Paleta de colores estándar para categorías y cuentas a partir de su hex
/// - Parameter hex: Cadena hexadecimal del color.
/// - Returns: Color de SwiftUI.
func colorForHex(_ hex: String) -> Color {
    switch hex {
    case "#FF9F0A": return Color.orange
    case "#5E5CE6": return Color.purple
    case "#0A84FF": return Color.blue
    case "#1C3556": return Color(red: 0.11, green: 0.21, blue: 0.34)
    case "#FFD60A": return Color.yellow
    case "#FF375F": return Color.red
    case "#30D158": return Color.green
    case "#64D2FF": return Color(red: 0.39, green: 0.82, blue: 1.00)
    case "#32D74B": return Color(red: 0.19, green: 0.84, blue: 0.29)
    default: return Color(hex: hex)
    }
}

/// Ícono estándar sugerido según el tipo de cuenta
func iconName(for accountType: AccountType) -> String {
    switch accountType {
    case .general: return "creditcard"
    case .cash: return "banknote.fill"
    case .checking: return "building.columns.fill"
    case .savings: return "banknote"
    }
}

/// Ícono efectivo para mostrar según los datos actuales de la cuenta
func displayIconName(for account: Account) -> String {
    if !account.iconName.isEmpty && account.iconName != "building.columns.fill" {
        return account.iconName
    }
    if let type = AccountType(rawValue: account.type) {
        return iconName(for: type)
    }
    return "building.columns.fill"
}

// MARK: - Color Extension & Palette

extension Color {

    // MARK: - Primary Brand Colors

    /// Electric Indigo: El equilibrio entre la seriedad bancaria y la tecnología moderna.
    static let electricIndigo = Color(hex: "6366F1")

    /// Neon Cyan: Representa el 'dinero digital' y el optimismo.
    static let neonCyan = Color(hex: "00F3FF")

    /// Hot Pink: Corta el ruido visual. Urgencia y placer culposo.
    static let hotPink = Color(hex: "FF0080")

    /// Deep Slate: El lienzo infinito (Principal Dark Mode).
    static let deepSlate = Color(hex: "0F172A")

    /// Priority Nature: Softer Cyan for „Priority" expenses.
    static let priorityNature = Color(hex: "00C2CB")

    /// Tag Chip Color: Darker teal in light mode for visibility, bright cyan in dark mode.
    static var tagChipColor: Color {
        #if canImport(UIKit)
            return Color(
                UIColor { traitCollection in
                    return traitCollection.userInterfaceStyle == .dark
                        ? UIColor(Color.neonCyan)
                        : UIColor(Color(hex: "0891B2"))  // Darker teal for light mode
                })
        #else
            return Color.neonCyan
        #endif
    }

    /// Transfer Color: Dark gray that works in both light and dark mode.
    static var transferColor: Color {
        #if canImport(UIKit)
            return Color(
                UIColor { traitCollection in
                    return traitCollection.userInterfaceStyle == .dark
                        ? UIColor(Color(hex: "64748B"))  // Slate gray for dark mode
                        : UIColor.label  // Black for light mode
                })
        #else
            return Color.primary
        #endif
    }

    // MARK: - Semantic Colors (Adaptive)

    /// Color de fondo principal de la aplicación.
    /// Light: Blanco muy suave / Dark: Deep Slate.
    static var netoBackground: Color {
        #if canImport(UIKit)
            return Color(
                UIColor { traitCollection in
                    return traitCollection.userInterfaceStyle == .dark
                        ? UIColor(Color.deepSlate)
                        : UIColor(red: 0.98, green: 0.98, blue: 0.99, alpha: 1.0)
                })
        #else
            return Color.gray.opacity(0.1)  // Fallback
        #endif
    }

    /// Color secundario de fondo (para tarjetas o modales).
    /// Light: Blanco / Dark: Slate muy oscuro + ligero tinte.
    static var netoCard: Color {
        #if canImport(UIKit)
            return Color(
                UIColor { traitCollection in
                    return traitCollection.userInterfaceStyle == .dark
                        ? UIColor(red: 0.11, green: 0.16, blue: 0.28, alpha: 1.0) : UIColor.white
                })
        #else
            return Color.white  // Fallback
        #endif
    }

    /// Color de texto principal.
    static var netoPrimaryText: Color {
        Color.primary
    }

    /// Color de texto secundario (subtitulos).
    static var netoSecondaryText: Color {
        Color.secondary
    }

    /// Alias para compatibilidad con código existente
    static let financeGreen = Color(red: 0.13, green: 0.75, blue: 0.45)
    static let financeBlue = Color(red: 0.17, green: 0.47, blue: 0.96)
    static let financeOrange = Color(red: 1.00, green: 0.58, blue: 0.30)

    // Estos se deprecarian a favor de netoBackground, pero los mantenemos por compatibilidad inmediata
    static let financeBackgroundTop = Color(red: 0.99, green: 0.99, blue: 1.00)
    static let financeBackgroundBottom = electricIndigo.opacity(0.1)

    // MARK: - Semantic Aliases
    static let brandPrimary = electricIndigo
    static let incomeGraph = neonCyan
    static let expenseGraph = hotPink
    static let darkBackground = deepSlate

    /// Returns either white or black depending on which contrasts better with the given color.
    static func contrastingText(for color: Color) -> Color {
        #if canImport(UIKit)
            let uiColor = UIColor(color)
            var red: CGFloat = 0
            var green: CGFloat = 0
            var blue: CGFloat = 0
            var alpha: CGFloat = 0

            uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

            // Luminance formula
            let luminance = 0.299 * red + 0.587 * green + 0.114 * blue
            return luminance > 0.6 ? .black : .white  // 0.6 threshold favors white text slightly more for mid-tones
        #else
            return .white  // Fallback
        #endif
    }

}
// MARK: - Formatters

struct NetoFormatter {
    static func currency(
        value: Double, currencyCode: String, forceSign: Bool = false, decimals: Int = 2
    ) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = decimals
        formatter.maximumFractionDigits = decimals

        let absoluteValue = abs(value)
        let formattedNumber = formatter.string(from: NSNumber(value: absoluteValue)) ?? "0.00"

        var sign = ""
        if value < 0 {
            sign = "- "
        } else if forceSign {
            sign = "+ "
        }

        // Format: "PEN - 1000.00"
        return "\(currencyCode) \(sign)\(formattedNumber)"
    }

    static func compactCurrency(value: Double) -> String {
        value.formatted(.number.notation(.compactName).precision(.fractionLength(0...1)))
    }
}
