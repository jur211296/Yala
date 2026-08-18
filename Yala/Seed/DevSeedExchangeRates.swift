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

    /// Ticket: Bugs/qa_cloud-fx-rates-blob-dos-caras.md
    ///
    /// Encodes the post-pull canonical face of `ExchangeRate.rates`: a JSON object whose
    /// values are scale-8 DECIMAL STRINGS (e.g. `"3.61230000"`), not native Doubles.
    /// Invoked from the existing Yala Dev uitest launch path (`-uitest -uitest-seed <profile>`)
    /// via `DevSeedService` for any profile that seeds personal data. A seed that only writes
    /// Doubles is a false green for Mini: `decodedRates()` would still succeed if the tolerant
    /// decoder were reverted.
    static func encodeScale8StringFaceBlob(_ rates: [String: Double]) throws -> Data {
        var strings: [String: String] = [:]
        strings.reserveCapacity(rates.count)
        for (code, value) in rates {
            strings[code] = String(format: "%.8f", value)
        }
        return try JSONSerialization.data(withJSONObject: strings, options: [.sortedKeys])
    }

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
                let blob = try encodeScale8StringFaceBlob(rates)
                let entry = ExchangeRate(
                    dateKey: dateKey,
                    base: "USD",
                    rates: blob,
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
