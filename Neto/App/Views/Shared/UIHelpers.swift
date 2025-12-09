//
//  UIHelpers.swift
//  Neto
//
//  Created by Neto Refactoring.
//

import SwiftUI

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

// Paleta de colores estándar para categorías y cuentas a partir de su hex
func colorForHex(_ hex: String) -> Color {
    switch hex {
    case "#FF9F0A":  // Alimentación
        return Color.orange

    case "#5E5CE6":  // Compras
        return Color.purple

    case "#0A84FF":  // Transporte
        return Color.blue

    case "#1C3556":  // Finanzas
        return Color(red: 0.11, green: 0.21, blue: 0.34)

    case "#FFD60A":  // Hogar
        return Color.yellow

    case "#FF375F":  // Entretenimiento
        return Color.red

    case "#30D158":  // Personal
        return Color.green

    case "#64D2FF":  // Vehículo (celeste)
        return Color(red: 0.39, green: 0.82, blue: 1.00)

    case "#32D74B":  // Ingresos (verde brillante)
        return Color(red: 0.19, green: 0.84, blue: 0.29)

    default:
        // Parse any valid hex color using the Color(hex:) initializer
        return Color(hex: hex)
    }
}

// Ícono estándar sugerido según el tipo de cuenta
func iconName(for accountType: AccountType) -> String {
    switch accountType {
    case .general:
        return "creditcard"
    case .cash:
        return "banknote.fill"
    case .checking:
        return "building.columns.fill"
    case .savings:
        return "banknote"
    }
}

// Ícono efectivo para mostrar según los datos actuales de la cuenta
func displayIconName(for account: Account) -> String {
    // Si ya hay un icono personalizado distinto del default antiguo, úsalo
    if !account.iconName.isEmpty && account.iconName != "building.columns.fill" {
        return account.iconName
    }

    // Si no, derivamos el icono a partir del tipo de cuenta
    if let type = AccountType(rawValue: account.type) {
        return iconName(for: type)
    }

    // Fallback seguro
    return "building.columns.fill"
}

// MARK: - Paleta Neto (Liquid Glass claro)

extension Color {
    static let financeGreen = Color(red: 0.13, green: 0.75, blue: 0.45)
    static let financeBlue = Color(red: 0.17, green: 0.47, blue: 0.96)
    static let financeOrange = Color(red: 1.00, green: 0.58, blue: 0.30)

    static let financeBackgroundTop = Color(red: 0.99, green: 0.99, blue: 1.00)
    static let financeBackgroundBottom = electricIndigo.opacity(0.1)
}

extension Color {

    // MARK: - Primary Brand Colors

    /// Electric Indigo: El equilibrio entre la seriedad bancaria y la tecnología moderna.
    /// Uso: Primario, CTAs y Branding.
    static let electricIndigo = Color(hex: "6366F1")

    /// Neon Cyan: Representa el 'dinero digital' y el optimismo.
    /// Uso: Gráficos de ingresos y ahorros.
    /// Note: Inferred hex based on name (original request had duplicate).
    static let neonCyan = Color(hex: "00F3FF")

    /// Hot Pink: Corta el ruido visual. Urgencia y placer culposo.
    /// Uso: Gastos y notificaciones.
    /// Note: Inferred hex based on name (original request had duplicate).
    static let hotPink = Color(hex: "FF0080")

    /// Deep Slate: El lienzo infinito.
    /// Uso: Primario para el Dark Mode.
    /// Note: Inferred hex based on name (original request had duplicate).
    static let deepSlate = Color(hex: "0F172A")

    // MARK: - Semantic Aliases

    static let brandPrimary = electricIndigo
    static let incomeGraph = neonCyan
    static let expenseGraph = hotPink
    static let darkBackground = deepSlate
}
