//
//  DevSeedExchangeRates.swift
//  Yala
//
//  Creates ~730 daily exchange rate entries for dev seed data.
//

#if DEBUG
import Foundation
import SwiftData

struct DevSeedExchangeRates {

    @MainActor
    static func create(
        startDate: Date,
        endDate: Date,
        rng: inout SeededRandom,
        in context: ModelContext
    ) {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        var penRate = DevSeedTransactions.basePenRate
        var eurRate = 0.92
        var currentDate = startDate

        while currentDate <= endDate {
            let dateKey = formatter.string(from: currentDate)

            // Random walk drift
            penRate += rng.nextDouble(in: -0.02...0.02)
            penRate = max(3.50, min(3.90, penRate))

            eurRate += rng.nextDouble(in: -0.005...0.005)
            eurRate = max(0.87, min(0.97, eurRate))

            let rates: [String: Double] = [
                "PEN": (penRate * 100).rounded() / 100,
                "EUR": (eurRate * 1000).rounded() / 1000,
                "USD": 1.0,
            ]

            do {
                let entry = try ExchangeRate(
                    dateKey: dateKey,
                    base: "USD",
                    ratesDictionary: rates,
                    timestamp: currentDate
                )
                context.insert(entry)
            } catch {
                print("DevSeedExchangeRates: Error creating rate for \(dateKey): \(error)")
            }

            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = nextDate
        }
    }
}
#endif
