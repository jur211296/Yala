//
//  ExchangeRate.swift
//  Finaria
//
//  Created by Finaria Refactoring.
//

import Foundation
import SwiftData

// MARK: - ExchangeRate

@Model
final class ExchangeRate {
    var dateKey: String
    var base: String
    var rates: Data

    init(
        dateKey: String,
        base: String,
        rates: Data
    ) {
        self.dateKey = dateKey
        self.base = base
        self.rates = rates
    }

    convenience init(
        dateKey: String,
        base: String,
        ratesDictionary: [String: Double]
    ) throws {
        let data = try JSONEncoder().encode(ratesDictionary)
        self.init(dateKey: dateKey, base: base, rates: data)
    }

    func decodedRates() -> [String: Double] {
        (try? JSONDecoder().decode([String: Double].self, from: rates)) ?? [:]
    }
}
