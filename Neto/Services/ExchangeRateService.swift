//
//  ExchangeRateService.swift
//  Neto
//
//  Business logic for managing exchange rates.
//  Handles persistence, caching, and API coordination.
//

import Foundation
import SwiftData

// MARK: - Exchange Rate Service

/// Service responsible for managing exchange rate data.
/// Handles fetching from API and persisting to SwiftData.
@MainActor
final class ExchangeRateService {

    // MARK: - Singleton

    static let shared = ExchangeRateService(provider: ExchangeRateAPIService())

    // MARK: - Properties

    private let provider: ExchangeRateProviderProtocol
    private let baseCurrency = "USD"
    private let supportedSymbols = ["USD", "PEN", "EUR"]

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()

    // UserDefaults keys
    private let lastHistoricalLoadKey = "exchangeRate_lastHistoricalLoad"
    private let lastTodayUpdateKey = "exchangeRate_lastTodayUpdate"

    // MARK: - Initialization

    init(provider: ExchangeRateProviderProtocol) {
        self.provider = provider
    }

    // MARK: - Public API

    /// Preloads historical exchange rates if needed (last 12 months).
    /// Should be called on first app launch or after data reset.
    func preloadHistoricalIfNeeded(context: ModelContext) async {
        // Check if we've already loaded historical data
        let lastLoad = UserDefaults.standard.object(forKey: lastHistoricalLoadKey) as? Date

        // Only reload if never loaded or more than 30 days ago
        if let lastLoad = lastLoad {
            let daysSinceLoad =
                Calendar.current.dateComponents([.day], from: lastLoad, to: Date()).day ?? 0
            if daysSinceLoad < 30 {
                return
            }
        }

        // Check if we already have enough data
        let existingCount = countExistingRates(context: context)
        if existingCount > 300 {  // ~1 year of data
            UserDefaults.standard.set(Date(), forKey: lastHistoricalLoadKey)
            return
        }

        // Load last 12 months in chunks to avoid API limits
        let calendar = Calendar.current
        let today = Date()

        // Fetch in monthly chunks (exchangerate.host allows max 365 days per request)
        for monthOffset in 0..<12 {
            guard let chunkEnd = calendar.date(byAdding: .month, value: -monthOffset, to: today),
                let chunkStart = calendar.date(byAdding: .month, value: -1, to: chunkEnd)
            else {
                continue
            }

            do {
                try await fetchAndPersistRates(from: chunkStart, to: chunkEnd, context: context)
                // Small delay between requests to avoid rate limiting
                try? await Task.sleep(nanoseconds: 500_000_000)  // 0.5 seconds
            } catch {
                print(
                    "ExchangeRateService: Error loading historical chunk: \(error.localizedDescription)"
                )
                // Continue with other chunks even if one fails
            }
        }

        UserDefaults.standard.set(Date(), forKey: lastHistoricalLoadKey)
    }

    /// Updates today's exchange rate if not already fetched.
    /// Should be called on app launch and when opening Panel.
    func updateTodayIfNeeded(context: ModelContext) async {
        let todayKey = dateFormatter.string(from: Date())

        // Check if we already have today's rate
        if rateExists(for: todayKey, context: context) {
            return
        }

        do {
            let result = try await provider.fetchLatest(
                base: baseCurrency, symbols: supportedSymbols)
            try persistRate(
                dateKey: todayKey, rates: result.rates, timestamp: result.timestamp,
                context: context)
            UserDefaults.standard.set(Date(), forKey: lastTodayUpdateKey)
        } catch {
            print("ExchangeRateService: Error updating today's rate: \(error.localizedDescription)")
            // Don't throw - app should continue working with cached rates
        }
    }

    /// Ensures exchange rates exist for a given date range.
    /// Used after CSV import to fetch historical rates for imported transactions.
    func ensureRates(for dateRange: DateInterval, context: ModelContext) async {
        // Find missing dates in the range
        let missingDates = findMissingDates(in: dateRange, context: context)

        guard !missingDates.isEmpty else { return }

        // Group missing dates into contiguous ranges for efficient fetching
        let ranges = groupIntoRanges(dates: missingDates)

        for range in ranges {
            do {
                try await fetchAndPersistRates(from: range.start, to: range.end, context: context)
                // Small delay between requests
                try? await Task.sleep(nanoseconds: 300_000_000)  // 0.3 seconds
            } catch {
                print(
                    "ExchangeRateService: Error fetching range \(range): \(error.localizedDescription)"
                )
            }
        }
    }

    /// Gets the exchange rate for a specific date.
    /// Returns nil if not found (caller should use fallback logic).
    func getRate(for date: Date, context: ModelContext) -> ExchangeRate? {
        let dateKey = dateFormatter.string(from: date)
        return fetchExchangeRate(for: dateKey, context: context)
    }

    /// Gets the most recent exchange rate on or before the given date.
    /// Used as fallback when exact date rate is not available.
    func getMostRecentRate(onOrBefore date: Date, context: ModelContext) -> ExchangeRate? {
        let dateKey = dateFormatter.string(from: date)

        let descriptor = FetchDescriptor<ExchangeRate>(
            predicate: #Predicate { $0.dateKey <= dateKey },
            sortBy: [SortDescriptor(\ExchangeRate.dateKey, order: .reverse)]
        )

        do {
            let results = try context.fetch(descriptor)
            return results.first
        } catch {
            print("ExchangeRateService: Error fetching fallback rate: \(error)")
            return nil
        }
    }

    /// Gets the most recent exchange rate available (for UI display).
    func getLatestRate(context: ModelContext) -> ExchangeRate? {
        let descriptor = FetchDescriptor<ExchangeRate>(
            sortBy: [SortDescriptor(\ExchangeRate.dateKey, order: .reverse)]
        )

        do {
            var fetchDescriptor = descriptor
            fetchDescriptor.fetchLimit = 1
            let results = try context.fetch(fetchDescriptor)
            return results.first
        } catch {
            print("ExchangeRateService: Error fetching latest rate: \(error)")
            return nil
        }
    }

    // MARK: - Private Helpers

    private func fetchAndPersistRates(from startDate: Date, to endDate: Date, context: ModelContext)
        async throws
    {
        let rates = try await provider.fetchTimeseries(
            base: baseCurrency,
            symbols: supportedSymbols,
            startDate: startDate,
            endDate: endDate
        )

        for (dateKey, dayRates) in rates {
            try persistRate(dateKey: dateKey, rates: dayRates, context: context)
        }
    }

    private func persistRate(
        dateKey: String, rates: [String: Double], timestamp: Date? = nil, context: ModelContext
    ) throws {
        // Check if rate already exists for this date
        if let existing = fetchExchangeRate(for: dateKey, context: context) {
            // Update existing rate
            let data = try JSONEncoder().encode(rates)
            existing.rates = data
            existing.timestamp = timestamp
        } else {
            // Create new rate
            let newRate = try ExchangeRate(
                dateKey: dateKey,
                base: baseCurrency,
                ratesDictionary: rates,
                timestamp: timestamp
            )
            context.insert(newRate)
        }

        try context.save()
    }

    private func fetchExchangeRate(for dateKey: String, context: ModelContext) -> ExchangeRate? {
        let descriptor = FetchDescriptor<ExchangeRate>(
            predicate: #Predicate { $0.dateKey == dateKey }
        )

        do {
            let results = try context.fetch(descriptor)
            return results.first
        } catch {
            return nil
        }
    }

    private func rateExists(for dateKey: String, context: ModelContext) -> Bool {
        return fetchExchangeRate(for: dateKey, context: context) != nil
    }

    private func countExistingRates(context: ModelContext) -> Int {
        let descriptor = FetchDescriptor<ExchangeRate>()
        do {
            return try context.fetchCount(descriptor)
        } catch {
            return 0
        }
    }

    private func findMissingDates(in range: DateInterval, context: ModelContext) -> [Date] {
        let calendar = Calendar.current
        var missingDates: [Date] = []
        var currentDate = range.start

        while currentDate <= range.end {
            let dateKey = dateFormatter.string(from: currentDate)
            if !rateExists(for: dateKey, context: context) {
                missingDates.append(currentDate)
            }
            currentDate =
                calendar.date(byAdding: .day, value: 1, to: currentDate)
                ?? currentDate.addingTimeInterval(86400)
        }

        return missingDates
    }

    private func groupIntoRanges(dates: [Date]) -> [DateInterval] {
        guard !dates.isEmpty else { return [] }

        let sortedDates = dates.sorted()
        var ranges: [DateInterval] = []
        var rangeStart = sortedDates[0]
        var rangeEnd = sortedDates[0]

        for date in sortedDates.dropFirst() {
            let daysDiff =
                Calendar.current.dateComponents([.day], from: rangeEnd, to: date).day ?? 0

            if daysDiff <= 1 {
                // Contiguous date, extend range
                rangeEnd = date
            } else {
                // Gap found, save current range and start new one
                ranges.append(DateInterval(start: rangeStart, end: rangeEnd))
                rangeStart = date
                rangeEnd = date
            }
        }

        // Don't forget the last range
        ranges.append(DateInterval(start: rangeStart, end: rangeEnd))

        return ranges
    }
}
