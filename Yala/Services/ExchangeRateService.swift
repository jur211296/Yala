//
//  ExchangeRateService.swift
//  Yala
//
//  Business logic for managing exchange rates.
//  Handles persistence, caching, and API coordination.
//

import Foundation
import Observation
import SwiftData

// MARK: - Exchange Rate Service Protocol

/// Protocol for exchange rate management, enabling dependency injection and testing.
protocol ExchangeRateServiceProtocol {
    func preloadHistoricalIfNeeded(context: ModelContext) async
    func updateTodayIfNeeded(context: ModelContext) async
    func forceUpdateToday(context: ModelContext) async
    func ensureRates(for dateRange: DateInterval, context: ModelContext) async
    func forceRefreshRates(for dateRange: DateInterval, context: ModelContext) async
    func ensureRatesForExistingTransactions(context: ModelContext) async
    func getRate(for date: Date, context: ModelContext) -> ExchangeRate?
    func getMostRecentRate(onOrBefore date: Date, context: ModelContext) -> ExchangeRate?
    func getLatestRate(context: ModelContext) -> ExchangeRate?
    func getOldestRate(context: ModelContext) -> ExchangeRate?
    func getStoredDateRange(context: ModelContext) -> DateInterval?
}

// MARK: - Exchange Rate Service

/// Service responsible for managing exchange rate data.
/// Handles fetching from API and persisting to SwiftData.
/// Supports @Environment injection in SwiftUI views.
@Observable
@MainActor
final class ExchangeRateService: ExchangeRateServiceProtocol {

    // MARK: - Singleton (for backward compatibility)

    /// Shared instance for backward compatibility. Prefer @Environment injection in Views.
    static let shared = ExchangeRateService(provider: ExchangeRateAPIService())

    // MARK: - Properties

    private let provider: ExchangeRateProviderProtocol
    private let baseCurrency = "USD"
    // All supported currencies - derived from CurrencyCode enum (single source of truth)
    private var supportedSymbols: [String] { CurrencyCode.allRawValues }

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
                Calendar.current.dateComponents([.day], from: lastLoad, to: Date.now).day ?? 0
            if daysSinceLoad < 30 {
                return
            }
        }

        // Check if we already have enough data
        let existingCount = countExistingRates(context: context)
        if existingCount > 300 {  // ~1 year of data
            UserDefaults.standard.set(Date.now, forKey: lastHistoricalLoadKey)
            return
        }

        // Get only required currencies (preferred + secondary + account currencies)
        let requiredCurrencies = Array(getRequiredCurrencies(context: context))

        // Load last 12 months in chunks to avoid API limits
        let calendar = Calendar.current
        let today = Date.now

        // Fetch in monthly chunks (exchangerate.host allows max 365 days per request)
        for monthOffset in 0..<12 {
            guard let chunkEnd = calendar.date(byAdding: .month, value: -monthOffset, to: today),
                let chunkStart = calendar.date(byAdding: .month, value: -1, to: chunkEnd)
            else {
                continue
            }

            do {
                try await fetchAndPersistRates(
                    from: chunkStart, to: chunkEnd, symbols: requiredCurrencies, context: context)
                // Small delay between requests to avoid rate limiting
                try? await Task.sleep(for: .seconds(0.5))
            } catch {
                #if DEBUG
                print(
                    "ExchangeRateService: Error loading historical chunk: \(error.localizedDescription)"
                )
                #endif
                // Continue with other chunks even if one fails
            }
        }

        UserDefaults.standard.set(Date.now, forKey: lastHistoricalLoadKey)
    }

    /// Updates today's exchange rate if not already fetched.
    /// Should be called on app launch and when opening Panel.
    func updateTodayIfNeeded(context: ModelContext) async {
        let todayKey = dateFormatter.string(from: Date.now)

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
            UserDefaults.standard.set(Date.now, forKey: lastTodayUpdateKey)
        } catch {
            #if DEBUG
            print("ExchangeRateService: Error updating today's rate: \(error.localizedDescription)")
            #endif
            // Don't throw - app should continue working with cached rates
        }
    }

    /// Forces update of today's exchange rate even if it already exists.
    /// Used after onboarding to ensure we have ALL 7 currencies, not just the ones
    /// that might have been fetched earlier with a partial set.
    func forceUpdateToday(context: ModelContext) async {
        let todayKey = dateFormatter.string(from: Date.now)

        do {
            let result = try await provider.fetchLatest(
                base: baseCurrency, symbols: supportedSymbols)
            try persistRate(
                dateKey: todayKey, rates: result.rates, timestamp: result.timestamp,
                context: context)
            UserDefaults.standard.set(Date.now, forKey: lastTodayUpdateKey)
            #if DEBUG
            print("ExchangeRateService: Force updated today's rate with all \(supportedSymbols.count) currencies")
            #endif
        } catch {
            #if DEBUG
            print("ExchangeRateService: Error force updating today's rate: \(error.localizedDescription)")
            #endif
        }
    }

    /// Forces a refresh of exchange rates for a date range.
    /// Only refetches dates that are missing OR don't have all currencies.
    /// Optimized to skip dates that already have complete data.
    func forceRefreshRates(for dateRange: DateInterval, context: ModelContext) async {
        let calendar = Calendar.current

        // Find dates that need refresh (missing or incomplete)
        var datesToRefresh: [Date] = []
        var currentDate = dateRange.start
        while currentDate <= dateRange.end {
            let dateKey = dateFormatter.string(from: currentDate)
            // Only add dates that don't have ALL currencies
            if !rateHasAllCurrencies(for: dateKey, context: context) {
                datesToRefresh.append(currentDate)
            }
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate.addingTimeInterval(86400)
        }

        guard !datesToRefresh.isEmpty else {
            #if DEBUG
            print("ExchangeRateService: All rates already have all currencies, skipping refresh")
            #endif
            return
        }

        #if DEBUG
        let totalDays = Int(dateRange.duration / 86400)
        print("ExchangeRateService: Refreshing \(datesToRefresh.count) of \(totalDays) days (skipped \(totalDays - datesToRefresh.count) complete)")
        #endif

        // Group into contiguous ranges for efficient fetching
        let ranges = groupIntoRanges(dates: datesToRefresh)

        for range in ranges {
            do {
                try await fetchAndPersistRates(from: range.start, to: range.end, context: context)
                // Small delay between requests
                try? await Task.sleep(for: .seconds(0.3))
            } catch {
                #if DEBUG
                print("ExchangeRateService: Error refreshing range \(range): \(error.localizedDescription)")
                #endif
            }
        }

        #if DEBUG
        print("ExchangeRateService: Force refresh complete")
        #endif
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
                try? await Task.sleep(for: .seconds(0.3))
            } catch {
                #if DEBUG
                print(
                    "ExchangeRateService: Error fetching range \(range): \(error.localizedDescription)"
                )
                #endif
            }
        }
    }

    /// Ensures exchange rates exist for all dates that have transactions.
    /// Should be called after onboarding or when secondary currencies change,
    /// to guarantee historical data for existing transactions.
    func ensureRatesForExistingTransactions(context: ModelContext) async {
        // Fetch all transactions to get date range
        let descriptor = FetchDescriptor<TransactionItem>(
            sortBy: [SortDescriptor(\TransactionItem.date, order: .forward)]
        )

        do {
            let transactions = try context.fetch(descriptor)
            guard !transactions.isEmpty,
                  let firstDate = transactions.first?.date,
                  let lastDate = transactions.last?.date else {
                #if DEBUG
                print("ExchangeRateService: No transactions found, skipping historical rates")
                #endif
                return
            }

            let dateInterval = DateInterval(start: firstDate, end: lastDate)
            #if DEBUG
            print("ExchangeRateService: Ensuring rates for transaction range: \(firstDate) to \(lastDate)")
            #endif

            await ensureRates(for: dateInterval, context: context)
        } catch {
            #if DEBUG
            print("ExchangeRateService: Error fetching transactions for rate sync: \(error)")
            #endif
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
            #if DEBUG
            print("ExchangeRateService: Error fetching fallback rate: \(error)")
            #endif
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
            #if DEBUG
            print("ExchangeRateService: Error fetching latest rate: \(error)")
            #endif
            return nil
        }
    }

    /// Gets the oldest exchange rate available (for determining data range).
    func getOldestRate(context: ModelContext) -> ExchangeRate? {
        let descriptor = FetchDescriptor<ExchangeRate>(
            sortBy: [SortDescriptor(\ExchangeRate.dateKey, order: .forward)]
        )

        do {
            var fetchDescriptor = descriptor
            fetchDescriptor.fetchLimit = 1
            let results = try context.fetch(fetchDescriptor)
            return results.first
        } catch {
            #if DEBUG
            print("ExchangeRateService: Error fetching oldest rate: \(error)")
            #endif
            return nil
        }
    }

    /// Gets the actual date range of stored exchange rates.
    /// Returns nil if no rates are stored.
    func getStoredDateRange(context: ModelContext) -> DateInterval? {
        guard let oldest = getOldestRate(context: context),
              let latest = getLatestRate(context: context) else {
            return nil
        }

        // Parse dateKey to Date
        let oldestDate = dateFormatter.date(from: oldest.dateKey) ?? Date.now
        let latestDate = dateFormatter.date(from: latest.dateKey) ?? Date.now

        return DateInterval(start: oldestDate, end: latestDate)
    }

    // MARK: - Private Helpers

    private func fetchAndPersistRates(
        from startDate: Date, to endDate: Date, symbols: [String]? = nil, context: ModelContext
    ) async throws {
        // Use provided symbols or default to all supported currencies
        let symbolsToFetch = symbols ?? supportedSymbols

        let rates = try await provider.fetchTimeseries(
            base: baseCurrency,
            symbols: symbolsToFetch,
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
            #if DEBUG
            print("ExchangeRateService: Error fetching rate: \(error)")
            #endif
            return nil
        }
    }

    private func rateExists(for dateKey: String, context: ModelContext) -> Bool {
        return fetchExchangeRate(for: dateKey, context: context) != nil
    }

    /// Checks if a stored rate has ALL supported currencies.
    /// Returns false if any currency from CurrencyCode.allRawValues is missing.
    private func rateHasAllCurrencies(for dateKey: String, context: ModelContext) -> Bool {
        guard let rate = fetchExchangeRate(for: dateKey, context: context) else {
            return false
        }
        let storedCurrencies = Set(rate.decodedRates().keys)
        let requiredCurrencies = Set(CurrencyCode.allRawValues)
        return requiredCurrencies.isSubset(of: storedCurrencies)
    }

    private func countExistingRates(context: ModelContext) -> Int {
        let descriptor = FetchDescriptor<ExchangeRate>()
        do {
            return try context.fetchCount(descriptor)
        } catch {
            #if DEBUG
            print("ExchangeRateService: Error counting rates: \(error)")
            #endif
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

    /// Returns the set of currency codes that need historical exchange rate data.
    /// Includes: preferred currency, secondary currencies, and currencies of existing accounts.
    private func getRequiredCurrencies(context: ModelContext) -> Set<String> {
        var required: Set<String> = []

        // 1. Preferred currency (always needed)
        let preferredCode = UserDefaults.standard.string(forKey: "defaultCurrencyCode") ?? "PEN"
        required.insert(preferredCode)

        // 2. Secondary currencies (for ExchangeRateWidget)
        if let secondaryRaw = UserDefaults.standard.string(forKey: "secondaryCurrencies"),
           !secondaryRaw.isEmpty
        {
            let secondary = secondaryRaw.split(separator: ",").map { String($0) }
            required.formUnion(secondary)
        }

        // 3. Currencies of existing accounts (for transaction conversions)
        let accountsDesc = FetchDescriptor<Account>()
        do {
            let accounts = try context.fetch(accountsDesc)
            let accountCurrencies = Set(accounts.map { $0.currencyCode })
            required.formUnion(accountCurrencies)
        } catch {
            #if DEBUG
                print("ExchangeRateService: Error fetching accounts for required currencies: \(error)")
            #endif
        }

        return required
    }
}
