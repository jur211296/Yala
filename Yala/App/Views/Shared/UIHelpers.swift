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

// MARK: - Filter Badge

struct FilterBadgeModifier: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        content.overlay(alignment: .topTrailing) {
            if isActive {
                Circle()
                    .fill(Color.hotPink)
                    .frame(width: DS.Chip.dotSize, height: DS.Chip.dotSize)
                    .offset(x: 2, y: -2)
                    .accessibilityHidden(true)
            }
        }
    }
}

extension View {
    func filterBadge(isActive: Bool) -> some View {
        modifier(FilterBadgeModifier(isActive: isActive))
    }
}

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

    /// Short description of what this account type is (for onboarding type picker)
    var typeDescription: String {
        switch self {
        case .checking: return L10n.Onboarding.accountTypeCheckingHint
        case .savings: return L10n.Onboarding.accountTypeSavingsHint
        case .creditCard: return L10n.Onboarding.accountTypeCreditHint
        case .cash: return L10n.Onboarding.accountTypeCashHint
        case .general: return ""
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
    case minimalist = 6
    case translucent = 7
    case liquidGlass = 8

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .system: return L10n.Settings.system
        case .light: return L10n.Settings.light
        case .dark: return L10n.Settings.dark
        case .indigo: return L10n.Settings.themeIndigo
        case .rosa: return L10n.Settings.themeRosa
        case .teal: return L10n.Settings.themeTeal
        case .minimalist: return L10n.Settings.themeMinimalist
        case .translucent: return L10n.Settings.themeTranslucent
        case .liquidGlass: return L10n.Settings.themeLiquidGlass
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark, .indigo, .rosa, .teal, .minimalist, .translucent, .liquidGlass: return .dark
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
        case .minimalist: return .minimalist
        case .translucent: return .translucent
        case .liquidGlass: return .liquidGlass
        }
    }

    /// Orden para la grilla de selección de tema.
    /// liquidGlass primero como tema estrella; el rawValue no cambia.
    static let displayOrder: [AppTheme] = [
        .liquidGlass, .system, .light, .dark, .indigo, .rosa, .teal, .minimalist, .translucent
    ]

    /// Whether this theme requires PRO subscription
    var isPro: Bool {
        switch self {
        case .system, .light, .dark, .liquidGlass: return false
        case .indigo, .rosa, .teal, .minimalist, .translucent: return true
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
    static let priorityNeed = Color(hex: "00C2CB")

    /// Turquesa oscurecido para el MONTO de un ingreso sobre tarjeta blanca.
    /// `priorityNeed` (#00C2CB) sólo alcanza 2,19 de contraste sobre blanco y
    /// no llega al mínimo AA de 4,5; éste da 5,1 conservando el matiz. Medido
    /// el 2026-09-02. Para superficies rellenas (chips, barras, anillos) sigue
    /// usándose `priorityNeed`: el requisito de contraste es del TEXTO.
    static let incomeAmount = Color(hex: "0F7A80")

    // MARK: - Need Colors (Distinct from brand colors)

    /// Essential Need: Warm amber for basic necessities
    static let essentialNeed = Color(hex: "F59E0B")

    /// Priority Need (Violet): Attention-grabbing but not urgent
    static let priorityNeedNew = Color(hex: "8B5CF6")

    /// Optional Need: Soft rose for discretionary spending
    static let optionalNeed = Color(hex: "FB7185")

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
    static let brandTertiary = priorityNeed  // Teal - third main color
    static let incomeGraph = priorityNeed  // Changed from neonCyan to teal
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

/// Pure formatting helpers (no UserDefaults reads). For prefs-aware formatting use:
/// - `appPreferences.X(...)` in `@MainActor` (Views/VMs) — reactive via Observation.
/// - `YalaFormatterStatic.X(...)` outside `@MainActor` (AppIntents, background) — non-reactive.
struct YalaFormatter {
    private static let compactTableFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    static func compactCurrency(value: Double) -> String {
        value.formatted(.number.notation(.compactName).precision(.fractionLength(0...1)))
    }

    /// Compact table cell: no currency prefix, "9,999" / "10.5k" / "101k"
    static func amountCompactTable(value: Double) -> String {
        let absValue = abs(value)
        let sign = value < 0 ? "-" : ""
        if absValue >= 100_000 {
            return String(format: "%@%.0fk", sign, absValue / 1000)
        }
        if absValue >= 10_000 {
            let k = absValue / 1000
            let formatted = k.truncatingRemainder(dividingBy: 1) == 0
                ? String(format: "%@%.0fk", sign, k)
                : String(format: "%@%.1fk", sign, k)
            return formatted
        }
        let formattedNumber = compactTableFormatter.string(from: NSNumber(value: absValue)) ?? "0"
        return "\(sign)\(formattedNumber)"
    }

    /// Compact axis label: 1500 → "2K", -40000 → "-40K", 500 → "500"
    static func axisK(_ value: Double) -> String {
        let absValue = abs(value)
        let sign = value < 0 ? "-" : ""
        if absValue >= 1000 {
            return String(format: "%@%.0fK", sign, absValue / 1000.0)
        } else {
            return String(format: "%@%.0f", sign, absValue)
        }
    }
}
