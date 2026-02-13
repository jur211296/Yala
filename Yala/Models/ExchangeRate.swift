//
//  ExchangeRate.swift
//  Yala
//
//  Created by Yala Refactoring.
//

import Foundation
import SwiftData

// MARK: - ExchangeRate

@Model
final class ExchangeRate {
    // CloudKit: defaults required
    var dateKey: String = ""
    var base: String = "USD"
    var rates: Data = Data()
    /// Unix timestamp from the API response (when the rate was recorded)
    var timestamp: Date?

    init(
        dateKey: String,
        base: String,
        rates: Data,
        timestamp: Date? = nil
    ) {
        self.dateKey = dateKey
        self.base = base
        self.rates = rates
        self.timestamp = timestamp
    }

    convenience init(
        dateKey: String,
        base: String,
        ratesDictionary: [String: Double],
        timestamp: Date? = nil
    ) throws {
        let data = try JSONEncoder().encode(ratesDictionary)
        self.init(dateKey: dateKey, base: base, rates: data, timestamp: timestamp)
    }

    func decodedRates() -> [String: Double] {
        do {
            return try JSONDecoder().decode([String: Double].self, from: rates)
        } catch {
            #if DEBUG
            print("ExchangeRate: Error decoding rates for \(dateKey): \(error)")
            #endif
            return [:]
        }
    }
}
