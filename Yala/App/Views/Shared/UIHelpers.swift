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
    /// Es el acento de los temas índigo, y los botones rellenos llevan texto blanco encima: #6063F1 da 4,61:1 (AA).
    /// Hasta el 2026-10-17 era #6366F1 (4,47:1); se oscureció solo la luminosidad, mismo tono (ΔE 2,2). Lo fija
    /// `BrandAccentContrastTests`, junto con las copias del hex (widgets, `AccentColor`, `LaunchBackground`, Sankey).
    static let electricIndigo = Color(hex: "6063F1")

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

    /// El tono de un IMPORTE de movimiento, el mismo que el Panel en toda la app (UX 2.2 · L4-14, decisión de Jürgen
    /// 2026-10-14): el ingreso en `incomeAmount`, el gasto en el color del texto. Se colorea la excepción; el signo
    /// del importe ya dice que es gasto. Antes la Bandeja, Registros y otras pantallas pintaban el gasto en rosa y el
    /// ingreso en índigo, y el mismo borrador salía en blanco al revisarlo y en rosa en la Bandeja.
    static func amountTint(isIncome: Bool) -> Color {
        isIncome ? Color.incomeAmount : Color.primary
    }

    // MARK: - Rellenos sólidos del onboarding (UX 2.2 · L1UI, variante 2 elegida por Jürgen el 2026-10-13)

    /// Índigo profundo: la tarjeta ELEGIDA del onboarding y las fichas de resultado de la calculadora del saldo.
    /// Texto blanco encima con contraste AA holgado (#3D36B3, 8,8:1); `electricIndigo` lo pasa justo (4,61:1).
    static let selectedIndigoFill = Color(hex: "3D36B3")

    /// Relleno del botón destacado de una alerta del sistema (el «Activar» del aviso de voz y foto) en el modo OSCURO.
    /// La alerta lo toma del `AccentColor` del catálogo, que en oscuro tiene que valer esto y en claro `electricIndigo`
    /// (lo fija `AlertActionIndigoParityTests`). Con blanco encima da 5,09:1, AA (`electricIndigo`, #6063F1, da 4,61:1).
    static let alertActionIndigo = Color(hex: "585BEC")

    /// Tinte con el que se presenta esa alerta. Medido en píxeles el 2026-10-17 (iOS 27.0): el texto del botón destacado
    /// sale del tinte de SwiftUI de quien presenta la alerta, y si el tinte coincide con el relleno sale NEGRO, en claro
    /// y en oscuro, sea cual sea el relleno (también sobre #3D36B3). No responde a `.tint` ni a `foregroundStyle` en el
    /// propio botón, y el mismo tinte colorea «Política de privacidad» y «Cancelar».
    /// - Oscuro: blanco. El texto del botón sale blanco (5,09:1) y los otros dos también, sobre cristal oscuro.
    /// - Claro: el mismo `electricIndigo` del relleno, así que el sistema pone negro (4,55:1, AA). Blanco obligaría a
    ///   pintar en blanco los otros dos botones sobre el cristal claro, donde no se leen. Es un límite de la alerta del
    ///   sistema; solo lo usa el tema Claro (y Sistema de día): el resto de temas son oscuros.
    static let alertActionTint = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? .white : UIColor(Color.electricIndigo)
    })

    /// Rosa profundo: la tarjeta «¿No sabes tu saldo?». `hotPink` (#FF0080) con texto blanco da 3,8:1;
    /// este tono da 5,2:1 sin dejar de ser el rosa de marca.
    static let emphasisPinkFill = Color(hex: "D6006B")

    /// TEXTO de «te pasaste» de un presupuesto (UX 2.2 · L9-1): `hotPink` sobre tarjeta blanca da 3,77 y no llega al AA
    /// de 4,5, así que en claro va el rosa profundo (#D6006B, 5,2) y en oscuro el de siempre, que ahí sí contrasta.
    static let overBudgetText = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(Color.hotPink) : UIColor(Color.emphasisPinkFill)
    })

    /// Dorado de Yala Pro, sólido (UX 2.2 · L16-12, variante 1 elegida por Jürgen el 2026-10-15): el aro del avatar y
    /// las insignias Pro. Antes era el degradado amarillo-naranja de `DS.Gradients.proBadge`, y nada de degradados.
    static let proGold = Color(hex: "F5B400")

    /// Texto sobre `proGold`: casi negro. El blanco sobre ese dorado da 1,9:1 y no se lee; éste pasa de 11:1.
    static let proGoldInk = Color(hex: "1C1500")

    /// TEXTO en el rosa de marca que tiene que leerse en los dos modos (UX 2.2 · L11-11, «Los lunes son tu día más caro»):
    /// el mismo par que `overBudgetText`, con nombre propio porque no habla de presupuestos.
    static let emphasisPinkText = overBudgetText

    /// Barra de un período que NO pasó el límite en el historial de un presupuesto (UX 2.2 · L9-7): neutra y sólida, para
    /// que el rosa marque solo los que se pasaron.
    static let budgetBarNeutral = Color(uiColor: .systemGray3) // A11Y-DM: gris de sistema, adapta claro/oscuro

    /// Rosa claro para texto sobre los rellenos índigo (lo que resta en la cuenta de la calculadora).
    static let pinkOnIndigo = Color(hex: "FF99CC")

    /// Rojo del círculo de «resta» de la calculadora. Es un glifo sobre relleno, no texto.
    static let subtractSign = Color(hex: "E5484D")

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

    /// Etiqueta del eje Y con los decimales que pide el rango del eje.
    ///
    /// `axisK(_:)` redondea a miles enteros, y en un eje estrecho todas las marcas salen iguales:
    /// el saldo de una cuenta nueva de S/ 1.800 pintaba «2K 2K 2K», y un eje de 0 a 1.800 pintaba
    /// 1.500 como «2K» (auditoría UX 2.2, lote 3, B3). Aquí los decimales salen del paso entre
    /// marcas, y los ceros de sobra se quitan: «1.75K 1.8K 1.85K», «1K 1.5K 2K», «94K 96K 98K».
    ///
    /// El paso se estima como un quinto del rango: el eje pide unas tres marcas y Swift Charts
    /// puede poner hasta cinco. Un paso real mayor solo deja decimales que se recortan.
    static func axisK(_ value: Double, domain: ClosedRange<Double>) -> String {
        let absValue = abs(value)
        let sign = value < 0 ? "-" : ""
        let step = (domain.upperBound - domain.lowerBound) / 5
        if absValue >= 1000 {
            return sign + trimmedDecimal(absValue / 1000, decimals: axisDecimals(forStep: step / 1000)) + "K"
        }
        return sign + trimmedDecimal(absValue, decimals: axisDecimals(forStep: step))
    }

    /// 0 decimales si el paso es de al menos una unidad, 1 si es de una décima, 2 si es menor.
    private static func axisDecimals(forStep step: Double) -> Int {
        guard step.isFinite, step > 0 else { return 0 }
        if step >= 1 { return 0 }
        if step >= 0.1 { return 1 }
        return 2
    }

    private static func trimmedDecimal(_ value: Double, decimals: Int) -> String {
        var text = String(format: "%.\(decimals)f", value)
        guard decimals > 0 else { return text }
        while text.hasSuffix("0") { text.removeLast() }
        if text.hasSuffix(".") { text.removeLast() }
        return text
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
