//
//  ExchangeRateProvider.swift
//  Yala
//
//  Protocol abstraction for exchange rate providers.
//  Allows swapping providers without changing business logic.
//

import Foundation

// MARK: - Provider Protocol

/// Result struct for live rate fetching that includes timestamp
struct LiveRateResult {
    let rates: [String: Double]
    let timestamp: Date?
}

/// Protocol defining the interface for exchange rate data providers.
/// Abstraction allows easy provider switching (e.g., from exchangerate.host to another).
protocol ExchangeRateProviderProtocol {
    /// Fetches the latest exchange rates for given symbols.
    /// - Parameters:
    ///   - base: Base currency code (e.g., "USD")
    ///   - symbols: Array of target currency codes (e.g., ["PEN", "EUR"])
    /// - Returns: LiveRateResult containing rates dictionary and optional timestamp
    func fetchLatest(base: String, symbols: [String]) async throws -> LiveRateResult

    /// Fetches historical exchange rates for a date range.
    /// - Parameters:
    ///   - base: Base currency code
    ///   - symbols: Array of target currency codes
    ///   - startDate: Start of the date range
    ///   - endDate: End of the date range
    /// - Returns: Dictionary mapping date strings (yyyy-MM-dd) to rate dictionaries
    func fetchTimeseries(
        base: String,
        symbols: [String],
        startDate: Date,
        endDate: Date
    ) async throws -> [String: [String: Double]]
}

// MARK: - Provider Errors

/// Errors that can occur when fetching exchange rates.
enum ExchangeRateProviderError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case apiError(String)
    case rateLimitExceeded
    case missingAPIKey

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL inválida para el servicio de tipo de cambio."
        case .networkError(let error):
            return "Error de red: \(error.localizedDescription)"
        case .invalidResponse:
            return "Respuesta inválida del servidor."
        case .apiError(let message):
            return "Error de API: \(message)"
        case .rateLimitExceeded:
            return "Se excedió el límite de solicitudes. Intenta más tarde."
        case .missingAPIKey:
            return "Falta la clave API para el servicio de tipo de cambio."
        }
    }
}
