//
//  UIHelpers.swift
//  Yala
//
//  Created by Yala Refactoring.
//  Updated by Audit & Refactoring Agent.
//

import SwiftData
import SwiftUI

#if canImport(UIKit)
    import UIKit
#endif

// MARK: - Design System
// Note: Design tokens (Spacing, Radius, Opacity) are now unified in:
// App/Theme/DesignTokens.swift → Use DS.Spacing, DS.Radius, DS.Opacity
// Legacy DesignSystem aliases remain available for backwards compatibility.

// MARK: - Enums de apoyo

enum AccountType: String, CaseIterable, Identifiable {
    case general = "General"
    case cash = "Efectivo"
    case checking = "Cuenta corriente"
    case savings = "Cuenta de ahorros"
    case creditCard = "Tarjeta de crédito"

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .general: return L10n.Account.AccountType.general
        case .cash: return L10n.Account.AccountType.cash
        case .checking: return L10n.Account.AccountType.current
        case .savings: return L10n.Account.AccountType.savings
        case .creditCard: return L10n.Account.AccountType.creditCard
        }
    }

    /// Contextual balance hint for onboarding (varies by account type)
    var balanceHint: String {
        switch self {
        case .general: return L10n.Onboarding.accountBalanceHintGeneral
        case .cash: return L10n.Onboarding.accountBalanceHintCash
        case .checking: return L10n.Onboarding.accountBalanceHintChecking
        case .savings: return L10n.Onboarding.accountBalanceHintSavings
        case .creditCard: return L10n.Onboarding.accountBalanceHintCreditCard
        }
    }
}

enum AdjustmentMode: String, CaseIterable, Identifiable {
    // Keep rawValue for backward compatibility with stored data
    case byEntry = "Ajustar por registro"
    case changeInitialBalance = "Cambiar saldo inicial"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .byEntry:
            return L10n.Account.adjustByEntry
        case .changeInitialBalance:
            return L10n.Account.changeInitialBalanceName
        }
    }

    var description: String {
        switch self {
        case .byEntry:
            return L10n.Account.adjustByEntryDesc
        case .changeInitialBalance:
            return L10n.Account.changeInitialBalanceDesc
        }
    }
}

enum AppTheme: Int, CaseIterable, Identifiable {
    case system = 0
    case light = 1
    case dark = 2
    case indigo = 3
    case rosa = 4
    case teal = 5

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .system: return L10n.Settings.system
        case .light: return L10n.Settings.light
        case .dark: return L10n.Settings.dark
        case .indigo: return L10n.Settings.themeIndigo
        case .rosa: return L10n.Settings.themeRosa
        case .teal: return L10n.Settings.themeTeal
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark, .indigo, .rosa, .teal: return .dark
        }
    }

    var yalaTheme: YalaTheme {
        switch self {
        case .system: return .light  // ThemeManager resolves system dynamically
        case .light: return .light
        case .dark: return .dark
        case .indigo: return .indigo
        case .rosa: return .rosa
        case .teal: return .teal
        }
    }

    /// Whether this theme requires PRO subscription
    var isPro: Bool {
        switch self {
        case .system, .light, .dark: return false
        case .indigo, .rosa, .teal: return true
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
    case .creditCard: return "creditcard.fill"
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

    /// Deep Slate: Negro puro OLED (Principal Dark Mode).
    static let deepSlate = Color(hex: "000000")

    /// Priority Nature: Softer Cyan for „Priority" expenses.
    static let priorityNature = Color(hex: "00C2CB")

    // MARK: - Nature Colors (Distinct from brand colors)

    /// Essential Nature: Warm amber for basic necessities
    static let essentialNature = Color(hex: "F59E0B")

    /// Priority Nature (Violet): Attention-grabbing but not urgent
    static let priorityNatureNew = Color(hex: "8B5CF6")

    /// Optional Nature: Soft rose for discretionary spending
    static let optionalNature = Color(hex: "FB7185")

    // Legacy adaptive colors removed — use ThemeColor (.thBackground, .thCard, etc.)
    // or @Environment(\.yalaTheme) for raw Color access.

    /// Alias para compatibilidad con código existente
    static let financeGreen = Color(red: 0.13, green: 0.75, blue: 0.45)
    static let financeBlue = Color(red: 0.17, green: 0.47, blue: 0.96)
    static let financeOrange = Color(red: 1.00, green: 0.58, blue: 0.30)

    // Estos se deprecarian a favor de yalaBackground, pero los mantenemos por compatibilidad inmediata
    static let financeBackgroundTop = Color(red: 0.99, green: 0.99, blue: 1.00)
    static let financeBackgroundBottom = electricIndigo.opacity(0.1)

    // MARK: - Semantic Aliases
    static let brandPrimary = electricIndigo
    static let brandSecondary = hotPink
    static let brandTertiary = priorityNature  // Teal - third main color
    static let incomeGraph = priorityNature  // Changed from neonCyan to teal
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

struct YalaFormatter {
    /// Number of decimal places for aggregated amounts (totals, charts, KPIs)
    /// 0 = no decimals, 1 = one decimal, 2 = two decimals
    /// Defaults to 0 (no decimals) on first launch
    private static var decimalPlaces: Int {
        // Migration: convert old boolean to new int format
        if UserDefaults.standard.object(forKey: "decimalPlaces") == nil {
            // Check if old key exists for migration
            if UserDefaults.standard.object(forKey: "useRoundedAmounts") != nil {
                let oldValue = UserDefaults.standard.bool(forKey: "useRoundedAmounts")
                return oldValue ? 0 : 2
            }
            return 0  // Default to no decimals
        }
        return UserDefaults.standard.integer(forKey: "decimalPlaces")
    }

    /// Currency display format: "code" (PEN) or "symbol" (S/)
    /// Defaults to "code" on first launch
    private static var currencyDisplayFormat: String {
        UserDefaults.standard.string(forKey: "currencyDisplayFormat") ?? "code"
    }

    /// Map currency codes to their symbols
    private static let currencySymbols: [String: String] = [
        "PEN": "S/",
        "USD": "$",
        "EUR": "€",
        "MXN": "$",
        "COP": "$",
        "BRL": "R$",
        "GBP": "£",
    ]

    /// Returns the currency identifier (code or symbol) based on user preference
    private static func currencyIdentifier(for code: String) -> String {
        if currencyDisplayFormat == "symbol", let symbol = currencySymbols[code] {
            return symbol
        }
        return code
    }

    /// Formats a currency value with standard format: `PEN 20,000.00` or `S/ 20,000.00`
    /// - Parameters:
    ///   - value: The numeric value to format
    ///   - currencyCode: 3-letter currency code (e.g., "PEN", "USD")
    ///   - forceSign: If true, adds '+' for positive values (only for tooltips like CashFlow)
    ///   - forceFullPrecision: If true, always shows 2 decimals (use for individual records)
    /// - Returns: Formatted string like "PEN 20,000.00" or "S/ -20,000.00"
    static func currency(
        value: Double, currencyCode: String, forceSign: Bool = false, forceFullPrecision: Bool = false
    ) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal

        let decimals = forceFullPrecision ? 2 : decimalPlaces
        formatter.minimumFractionDigits = decimals
        formatter.maximumFractionDigits = decimals

        let absoluteValue = abs(value)
        let fallback = decimals == 0 ? "0" : (decimals == 1 ? "0.0" : "0.00")
        let formattedNumber = formatter.string(from: NSNumber(value: absoluteValue)) ?? fallback

        // Build sign prefix (attached to number, no extra space)
        var signedNumber = formattedNumber
        if value < 0 {
            signedNumber = "-\(formattedNumber)"
        } else if forceSign && value > 0 {
            signedNumber = "+\(formattedNumber)"
        }

        // Format: "PEN 20,000.00" or "S/ -20,000.00" based on user preference
        let identifier = currencyIdentifier(for: currencyCode)
        return "\(identifier) \(signedNumber)"
    }

    static func compactCurrency(value: Double) -> String {
        value.formatted(.number.notation(.compactName).precision(.fractionLength(0...1)))
    }

    /// Formats a number with standard format: `20,000.00` or `-20,000.00` (no currency)
    /// - Parameters:
    ///   - value: The numeric value to format
    ///   - forceFullPrecision: If true, always shows 2 decimals (use for individual records)
    /// - Returns: Formatted string like "20,000.00" or "-20,000.00"
    static func number(value: Double, forceFullPrecision: Bool = false) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal

        let decimals = forceFullPrecision ? 2 : decimalPlaces
        formatter.minimumFractionDigits = decimals
        formatter.maximumFractionDigits = decimals

        let fallback = decimals == 0 ? "0" : (decimals == 1 ? "0.0" : "0.00")
        return formatter.string(from: NSNumber(value: value)) ?? fallback
    }
}
