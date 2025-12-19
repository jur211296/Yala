//
//  ExchangeRateAPIService.swift
//  Neto
//
//  Implementation of ExchangeRateProviderProtocol for exchangerate.host API.
//

import Foundation

// MARK: - API Response Models

/// Response for /live endpoint
private struct LiveRateResponse: Decodable {
    let success: Bool
    let timestamp: Int?
    let source: String?
    let quotes: [String: Double]?
    let error: ExchangeRateAPIError?
}

/// Response for /timeframe endpoint
private struct TimeframeResponse: Decodable {
    let success: Bool
    let timeframe: Bool?
    let startDate: String?
    let endDate: String?
    let source: String?
    let quotes: [String: [String: Double]]?
    let error: ExchangeRateAPIError?

    enum CodingKeys: String, CodingKey {
        case success, timeframe, source, quotes, error
        case startDate = "start_date"
        case endDate = "end_date"
    }
}

private struct ExchangeRateAPIError: Decodable {
    let code: Int?
    let type: String?
    let info: String?
}

// MARK: - API Service Implementation

/// Concrete implementation of ExchangeRateProviderProtocol using exchangerate.host API.
final class ExchangeRateAPIService: ExchangeRateProviderProtocol {

    // MARK: - Properties

    private let baseURL = "https://api.exchangerate.host"
    private let session: URLSession
    private let dateFormatter: DateFormatter

    // MARK: - Initialization

    init(session: URLSession = .shared) {
        self.session = session
        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateFormat = "yyyy-MM-dd"
        self.dateFormatter.timeZone = TimeZone(identifier: "UTC")
    }

    // MARK: - API Key

    private var apiKey: String {
        // First try Info.plist (set via Build Settings from xcconfig)
        if let key = Bundle.main.object(forInfoDictionaryKey: "EXCHANGE_RATE_API_KEY") as? String,
            !key.isEmpty, key != "$(EXCHANGE_RATE_API_KEY)"
        {
            return key
        }

        // Fallback to hardcoded key for development
        return "c06401ad1af737edd8345b27b5304c36"
    }

    // MARK: - ExchangeRateProviderProtocol

    func fetchLatest(base: String, symbols: [String]) async throws -> LiveRateResult {
        let currenciesString = symbols.joined(separator: ",")

        // exchangerate.host uses 'source' instead of 'base' and 'currencies' instead of 'symbols'
        let urlString =
            "\(baseURL)/live?access_key=\(apiKey)&source=\(base)&currencies=\(currenciesString)"

        guard let url = URL(string: urlString) else {
            throw ExchangeRateProviderError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw ExchangeRateProviderError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ExchangeRateProviderError.invalidResponse
        }

        if httpResponse.statusCode == 429 {
            throw ExchangeRateProviderError.rateLimitExceeded
        }

        // Debug: Print raw response
        #if DEBUG
            if let jsonString = String(data: data, encoding: .utf8) {
                print("ExchangeRateAPI Response: \(jsonString)")
            }
        #endif

        let decoded: LiveRateResponse
        do {
            decoded = try JSONDecoder().decode(LiveRateResponse.self, from: data)
        } catch {
            print("ExchangeRateAPI Decode Error: \(error)")
            throw ExchangeRateProviderError.invalidResponse
        }

        if !decoded.success {
            let message = decoded.error?.info ?? "Unknown error (code: \(decoded.error?.code ?? 0))"
            throw ExchangeRateProviderError.apiError(message)
        }

        guard let quotes = decoded.quotes else {
            throw ExchangeRateProviderError.invalidResponse
        }

        // Convert response format: "USDPEN" -> "PEN"
        // quotes format: {"USDPEN": 3.37, "USDEUR": 0.85}
        var rates: [String: Double] = [base: 1.0]  // Base currency is always 1.0

        for (key, value) in quotes {
            // Extract target currency (remove source prefix)
            if key.hasPrefix(base), key.count > base.count {
                let targetCurrency = String(key.dropFirst(base.count))
                rates[targetCurrency] = value
            }
        }

        // Convert Unix timestamp to Date
        let timestamp: Date? = decoded.timestamp.map { Date(timeIntervalSince1970: Double($0)) }

        return LiveRateResult(rates: rates, timestamp: timestamp)
    }

    func fetchTimeseries(
        base: String,
        symbols: [String],
        startDate: Date,
        endDate: Date
    ) async throws -> [String: [String: Double]] {
        let currenciesString = symbols.joined(separator: ",")
        let startDateString = dateFormatter.string(from: startDate)
        let endDateString = dateFormatter.string(from: endDate)

        // exchangerate.host uses /timeframe for historical data
        let urlString =
            "\(baseURL)/timeframe?access_key=\(apiKey)&source=\(base)&currencies=\(currenciesString)&start_date=\(startDateString)&end_date=\(endDateString)"

        guard let url = URL(string: urlString) else {
            throw ExchangeRateProviderError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 60

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw ExchangeRateProviderError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ExchangeRateProviderError.invalidResponse
        }

        if httpResponse.statusCode == 429 {
            throw ExchangeRateProviderError.rateLimitExceeded
        }

        let decoded: TimeframeResponse
        do {
            decoded = try JSONDecoder().decode(TimeframeResponse.self, from: data)
        } catch {
            print("ExchangeRateAPI Timeseries Decode Error: \(error)")
            throw ExchangeRateProviderError.invalidResponse
        }

        if !decoded.success {
            let message = decoded.error?.info ?? "Unknown error"
            throw ExchangeRateProviderError.apiError(message)
        }

        guard let quotes = decoded.quotes else {
            throw ExchangeRateProviderError.invalidResponse
        }

        // Convert response format
        // Input: { "2024-12-19": { "USDPEN": 3.37, "USDEUR": 0.85 } }
        // Output: { "2024-12-19": { "PEN": 3.37, "EUR": 0.85, "USD": 1.0 } }
        var result: [String: [String: Double]] = [:]

        for (dateKey, dayQuotes) in quotes {
            var dayResult: [String: Double] = [base: 1.0]

            for (key, value) in dayQuotes {
                if key.hasPrefix(base), key.count > base.count {
                    let targetCurrency = String(key.dropFirst(base.count))
                    dayResult[targetCurrency] = value
                }
            }

            result[dateKey] = dayResult
        }

        return result
    }
}
