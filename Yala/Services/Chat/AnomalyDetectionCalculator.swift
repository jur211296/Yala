//
//  AnomalyDetectionCalculator.swift
//  Yala
//
//  Detects expense transactions that deviate significantly from the user's
//  recent baseline (default: 90 days, 2x category average).
//
//  Extracted from ChatToolExecutor.analyzeUnusualSpending so the same logic can
//  be invoked on demand from the chat context builder when the user's question
//  matches AnomalyKeywords.
//

import Foundation

/// Anomaly entry returned in `FullFinancialContext.anomalias` (only populated
/// when the user's question signals interest in unusual spending).
struct AnomalyEntry: Codable, Equatable {
    let date: String          // ISO yyyy-MM-dd
    let amount: Double
    let merchant: String?     // canonicalized, nil if unknown
    let category: String
    let avgForCategory: Double
    let deviationPercent: Double

    enum CodingKeys: String, CodingKey {
        case date, amount, merchant, category
        case avgForCategory = "avg_for_category"
        case deviationPercent = "deviation_percent"
    }
}

@MainActor
enum AnomalyDetectionCalculator {

    /// Find transactions that spent significantly more than the category baseline.
    ///
    /// - Parameters:
    ///   - allTransactions: full eligible TX set (used to compute baseline averages
    ///     over the 90 days preceding `interval.start`).
    ///   - periodTransactions: TX inside `interval` to evaluate (already filtered
    ///     to expenses).
    ///   - interval: the period being evaluated.
    ///   - currencyCode: preferred currency for amounts.
    ///   - converter: currency converter to normalize TX into preferred currency.
    ///   - thresholdMultiplier: amount must exceed `avg * thresholdMultiplier`
    ///     to be flagged. Default 2.0.
    ///   - limit: max anomalies to return (sorted by deviation desc). Default 10.
    static func detect(
        allTransactions: [TransactionItem],
        periodTransactions: [TransactionItem],
        interval: DateInterval,
        currencyCode: String,
        converter: CurrencyConverting,
        thresholdMultiplier: Double = 2.0,
        limit: Int = 10
    ) -> [AnomalyEntry] {
        let calendar = Calendar.current
        let baselineStart = calendar.date(byAdding: .day, value: -90, to: interval.start) ?? interval.start
        let baselineInterval = DateInterval(start: baselineStart, end: interval.start)
        let baselineTx = allTransactions.filter {
            baselineInterval.contains($0.date) && $0.category?.isIncome == false
        }

        var catTotals: [String: (total: Double, count: Int)] = [:]
        for tx in baselineTx {
            let catName = tx.category?.name ?? "Other"
            let amount = convertAmount(tx, currencyCode: currencyCode, converter: converter)
            guard amount.isFinite else { continue }
            let existing = catTotals[catName] ?? (total: 0, count: 0)
            catTotals[catName] = (total: existing.total + amount, count: existing.count + 1)
        }
        var catAvg: [String: Double] = [:]
        for (name, data) in catTotals where data.count > 0 {
            catAvg[name] = data.total / Double(data.count)
        }

        struct Hit {
            let tx: TransactionItem
            let amount: Double
            let avg: Double
            let deviation: Double
        }

        var anomalies: [Hit] = []
        for tx in periodTransactions {
            let catName = tx.category?.name ?? "Other"
            let amount = convertAmount(tx, currencyCode: currencyCode, converter: converter)
            guard amount.isFinite, let avg = catAvg[catName], avg > 0 else { continue }
            let deviation = (amount - avg) / avg * 100
            if amount > avg * thresholdMultiplier {
                anomalies.append(Hit(tx: tx, amount: amount, avg: avg, deviation: deviation))
            }
        }

        anomalies.sort { $0.deviation > $1.deviation }

        return anomalies.prefix(limit).map { hit in
            AnomalyEntry(
                date: Self.dateFormatter.string(from: hit.tx.date),
                amount: hit.amount,
                merchant: safeMerchant(hit.tx),
                category: hit.tx.category?.name ?? "Other",
                avgForCategory: hit.avg,
                deviationPercent: hit.deviation
            )
        }
    }

    // MARK: - Helpers

    private static let dateFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f
    }()

    private static func convertAmount(
        _ tx: TransactionItem,
        currencyCode: String,
        converter: CurrencyConverting
    ) -> Double {
        tx.chatAmount(in: currencyCode, converter: converter)
    }

    private static func safeMerchant(_ tx: TransactionItem) -> String? {
        guard let note = tx.note, !note.isEmpty else { return nil }
        let canonical = MerchantCanonicalizer.canonicalize(note)
        return canonical.isEmpty ? nil : canonical
    }
}
