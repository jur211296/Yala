//
//  CurrencyUtils.swift
//  Yala
//
//  Utilidades para normalizar códigos de moneda y convertir montos.
//  IMPORTANTE: Para agregar una nueva divisa, solo edita el enum CurrencyCode.
//

import Foundation

// MARK: - Currency Code Enum (Single Source of Truth)

/// Enum centralizado de divisas soportadas.
/// **Para agregar una nueva divisa:**
/// 1. Añade el case al enum (ej: `case ars = "ARS"`)
/// 2. Implementa las propiedades computadas (flag, symbol, aliases, etc.)
/// 3. Añade la key de localización en L10n.Currency
/// 4. Opcionalmente, añade mapeo de región en `regionMappings`
enum CurrencyCode: String, CaseIterable, Identifiable, Hashable, Equatable {
    case pen = "PEN"
    case usd = "USD"
    case eur = "EUR"
    case mxn = "MXN"
    case cop = "COP"
    case brl = "BRL"
    case gbp = "GBP"

    var id: String { rawValue }

    // MARK: - Display Properties

    /// Emoji de bandera para mostrar en UI
    var flag: String {
        switch self {
        case .pen: return "🇵🇪"
        case .usd: return "🇺🇸"
        case .eur: return "🇪🇺"
        case .mxn: return "🇲🇽"
        case .cop: return "🇨🇴"
        case .brl: return "🇧🇷"
        case .gbp: return "🇬🇧"
        }
    }

    /// Símbolo corto de la moneda (para mostrar en cantidades)
    var symbol: String {
        switch self {
        case .pen: return "S/"
        case .usd: return "$"
        case .eur: return "€"
        case .mxn: return "$"
        case .cop: return "$"
        case .brl: return "R$"
        case .gbp: return "£"
        }
    }

    /// Nombre localizado de la moneda
    var localizedName: String {
        switch self {
        case .pen: return L10n.Currency.pen
        case .usd: return L10n.Currency.usd
        case .eur: return L10n.Currency.eur
        case .mxn: return L10n.Currency.mxn
        case .cop: return L10n.Currency.cop
        case .brl: return L10n.Currency.brl
        case .gbp: return L10n.Currency.gbp
        }
    }

    // MARK: - Normalization Aliases

    /// Aliases que se normalizan a este código de moneda.
    /// Usado por `normalizeCurrencyCode()` para reconocer variantes.
    var aliases: [String] {
        switch self {
        case .pen:
            return ["PEN", "SOL", "SOLES", "S/", "S/.", "S/. "]
        case .usd:
            return ["USD", "US$", "US DOLLAR", "$", "$USD", "USD$", "DOLLAR", "DOLAR"]
        case .eur:
            return ["EUR", "€", "EURO", "EUROS"]
        case .mxn:
            return ["MXN", "MX$", "PESO MEXICANO", "PESOS MEXICANOS"]
        case .cop:
            return ["COP", "CO$", "PESO COLOMBIANO", "PESOS COLOMBIANOS"]
        case .brl:
            return ["BRL", "R$", "REAL", "REAIS", "REALES"]
        case .gbp:
            return ["GBP", "£", "POUND", "POUNDS", "LIBRA", "LIBRAS"]
        }
    }

    // MARK: - Exchange Rate Properties

    /// Tasa de cambio de fallback relativa a USD.
    /// IMPORTANTE: Solo se usa cuando no hay datos de API disponibles.
    /// Valores aproximados de enero 2025.
    var fallbackRateToUSD: Double {
        switch self {
        case .usd: return 1.0
        case .pen: return 3.72      // 1 USD = 3.72 PEN
        case .eur: return 0.92      // 1 USD = 0.92 EUR
        case .mxn: return 17.2      // 1 USD = 17.2 MXN
        case .cop: return 4380.0    // 1 USD = 4380 COP
        case .brl: return 6.05      // 1 USD = 6.05 BRL
        case .gbp: return 0.79      // 1 USD = 0.79 GBP
        }
    }

    /// Tasa de cambio de fallback a PEN (para retrocompatibilidad).
    var fallbackRateToPEN: Decimal {
        // Calcula: 1 [esta moneda] = X PEN
        // Fórmula: (PEN/USD) / (esta/USD)
        let penRate = CurrencyCode.pen.fallbackRateToUSD
        let thisRate = self.fallbackRateToUSD
        return Decimal(penRate / thisRate)
    }

    // MARK: - Region Mapping

    /// Códigos de región ISO que usan esta moneda.
    /// Usado para auto-detectar la moneda preferida del usuario.
    var regionCodes: [String] {
        switch self {
        case .pen: return ["PE"]
        case .usd: return ["US"]
        case .eur: return ["ES", "DE", "FR", "IT", "PT", "NL", "BE", "AT", "IE", "FI", "GR",
                          "SK", "SI", "EE", "LV", "LT", "CY", "MT", "LU"]
        case .mxn: return ["MX"]
        case .cop: return ["CO"]
        case .brl: return ["BR"]
        case .gbp: return ["GB"]
        }
    }

    // MARK: - Static Helpers

    /// Todos los códigos de moneda como strings (para API calls).
    static var allRawValues: [String] {
        allCases.map { $0.rawValue }
    }

    /// Diccionario de tasas de fallback relativas a USD.
    static var fallbackRates: [String: Double] {
        Dictionary(uniqueKeysWithValues: allCases.map { ($0.rawValue, $0.fallbackRateToUSD) })
    }

    /// Busca una moneda por código de región.
    static func fromRegion(_ regionCode: String) -> CurrencyCode? {
        allCases.first { $0.regionCodes.contains(regionCode) }
    }

    /// Busca una moneda por cualquiera de sus aliases.
    static func fromAlias(_ alias: String) -> CurrencyCode? {
        let upper = alias.uppercased()
        return allCases.first { $0.aliases.contains(upper) }
    }
}

// MARK: - Currency Code Normalization

/// Normaliza un código de moneda "sucio" a un código estándar de 3 letras.
/// Deriva automáticamente de CurrencyCode.aliases.
/// Ejemplos:
/// - "S/", "s/.", "SOL", "soles" → "PEN"
/// - "$", "US$", "usd" → "USD"
/// - "€", "eur" → "EUR"
func normalizeCurrencyCode(_ raw: String) -> String {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty {
        return CurrencyDefaults.fallbackCode
    }

    // Intenta encontrar por alias
    if let currency = CurrencyCode.fromAlias(trimmed) {
        return currency.rawValue
    }

    // Intento de normalización genérica: tomar solo letras y quedarnos con 3
    let upper = trimmed.uppercased()
    let letters = upper.filter { $0.isLetter }
    if letters.count == 3 {
        // Verifica si es un código válido
        if CurrencyCode(rawValue: String(letters)) != nil {
            return String(letters)
        }
    } else if letters.count > 3 {
        let start = letters.startIndex
        let end = letters.index(start, offsetBy: 3)
        let code = String(letters[start..<end])
        if CurrencyCode(rawValue: code) != nil {
            return code
        }
    }

    // Fallback a USD para códigos no reconocidos
    return CurrencyDefaults.fallbackCode
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

    // Usa las tasas de fallback del enum
    if let currency = CurrencyCode(rawValue: code) {
        return currency.fallbackRateToPEN
    }
    return 1.0
}

// MARK: - Currency Defaults

/// Centralized default currency settings.
/// Use these constants instead of hardcoding currency codes throughout the codebase.
enum CurrencyDefaults {
    /// The fallback currency code when region detection fails (USD - US Dollar)
    static let fallbackCode = "USD"

    /// The default currency code when none is specified
    /// Uses region detection, falls back to USD
    static var defaultCode: String {
        detectCurrencyFromRegion().rawValue
    }

    /// UserDefaults key for storing the user's preferred currency
    static let preferredCurrencyKey = "defaultCurrencyCode"

    /// Returns the user's current preferred currency code, or the detected default if not set
    static var currentPreferred: String {
        UserDefaults.standard.string(forKey: preferredCurrencyKey) ?? defaultCode
    }

    /// Detects the recommended currency based on the user's device region.
    /// Derives automatically from CurrencyCode.regionCodes.
    static func detectCurrencyFromRegion() -> CurrencyCode {
        let regionCode = Locale.current.region?.identifier ?? ""

        // Busca en el mapeo centralizado del enum
        if let currency = CurrencyCode.fromRegion(regionCode) {
            return currency
        }

        // Default to USD for unsupported regions
        return .usd
    }
}

// MARK: - Currency Info (Backward Compatibility)

/// Returns display info for a currency.
/// Now derives from CurrencyCode properties.
func currencyInfo(for currency: CurrencyCode) -> (name: String, code: String, flag: String) {
    return (currency.localizedName, currency.rawValue, currency.flag)
}
