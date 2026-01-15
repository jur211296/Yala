//
//  CurrencyUtils.swift
//  Neto
//
//  Utilidades para normalizar códigos de moneda y convertir montos.
//

import Foundation

// MARK: - Currency Code Normalization

/// Normaliza un código de moneda "sucio" a un código estándar de 3 letras.
/// Ejemplos:
/// - "S/", "s/.", "SOL", "soles" → "PEN"
/// - "$", "US$", "usd" → "USD"
/// - "€", "eur" → "EUR"
/// Si no se reconoce, devuelve la versión uppercased recortada a 3 letras cuando aplica.
func normalizeCurrencyCode(_ raw: String) -> String {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty {
        return "PEN"
    }

    let upper = trimmed.uppercased()

    switch upper {
    // Sol peruano
    case "PEN", "SOL", "SOLES", "S/", "S/.", "S/. ":
        return "PEN"

    // Dólar estadounidense
    case "USD", "US$", "US DOLLAR", "$", "$USD", "USD$":
        return "USD"

    // Euro
    case "EUR", "€", "EURO":
        return "EUR"

    default:
        // Intento de normalización genérica: tomar solo letras y quedarnos con 3
        let letters = upper.filter { $0.isLetter }
        if letters.count == 3 {
            return String(letters)
        } else if letters.count > 3 {
            let start = letters.startIndex
            let end = letters.index(start, offsetBy: 3)
            return String(letters[start..<end])
        } else {
            // Fallback a PEN para seguridad
            return "PEN"
        }
    }
}

// MARK: - Currency Conversion (Using CurrencyConverter)

/// Convierte un monto entre dos monedas.
/// Esta función mantiene retrocompatibilidad con el código existente.
/// Usa tasas de fallback estáticas cuando no hay contexto SwiftData disponible.
/// - Para conversiones con tasas actualizadas por fecha, usar CurrencyConverter.shared directamente.
func convert(_ amount: Decimal, from rawFrom: String, to rawTo: String) -> Decimal {
    return CurrencyConverter.shared.convertWithFallback(amount, from: rawFrom, to: rawTo)
}

/// Devuelve la tasa de conversión de una moneda a PEN.
/// @deprecated Usar CurrencyConverter.shared para tasas actualizadas.
/// Esta función mantiene retrocompatibilidad con tasas aproximadas.
func rateToPEN(_ rawCode: String) -> Decimal {
    let code = normalizeCurrencyCode(rawCode)

    // Fallback rates (approximate, for backward compatibility)
    switch code {
    case "PEN":
        return 1.0
    case "USD":
        return 3.72  // Updated approximate rate
    case "EUR":
        return 3.95  // Updated approximate rate
    default:
        return 1.0
    }
}

// MARK: - Currency Code Enum

enum CurrencyCode: String, CaseIterable, Identifiable, Hashable, Equatable {
    case pen = "PEN"
    case usd = "USD"
    case eur = "EUR"

    var id: String { rawValue }
}

// MARK: - Currency Defaults

/// Centralized default currency settings.
/// Use these constants instead of hardcoding "PEN" throughout the codebase.
enum CurrencyDefaults {
    /// The default currency code when none is specified (PEN - Peruvian Sol)
    static let defaultCode = "PEN"

    /// UserDefaults key for storing the user's preferred currency
    static let preferredCurrencyKey = "defaultCurrencyCode"

    /// Returns the user's current preferred currency code, or the default if not set
    static var currentPreferred: String {
        UserDefaults.standard.string(forKey: preferredCurrencyKey) ?? defaultCode
    }
}

// MARK: - Currency Info

func currencyInfo(for currency: CurrencyCode) -> (name: String, code: String, flag: String) {
    switch currency {
    case .pen:
        return (L10n.Currency.pen, "PEN", "🇵🇪")
    case .usd:
        return (L10n.Currency.usd, "USD", "🇺🇸")
    case .eur:
        return (L10n.Currency.eur, "EUR", "🇪🇺")
    }
}
