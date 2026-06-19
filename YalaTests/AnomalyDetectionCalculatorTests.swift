//
//  AnomalyDetectionCalculatorTests.swift
//  YalaTests
//
//  Cubre la lógica de detección de gastos anómalos extraída de
//  ChatToolExecutor.analyzeUnusualSpending.
//

import Testing
import Foundation
@testable import Yala

@Suite(.serialized)
struct AnomalyDetectionCalculatorTests {

    // MARK: - Helpers

    private func makeCategory(name: String, isIncome: Bool = false) -> YalaCategory {
        YalaCategory(name: name, colorHex: "#000", isIncome: isIncome)
    }

    private func makeTx(
        amount: Double,
        date: Date,
        category: YalaCategory?,
        note: String? = nil
    ) -> TransactionItem {
        let tx = TransactionItem(
            date: date,
            amount: amount,
            currencyCode: "USD",
            note: note,
            category: category,
            amountInPreferredCurrency: amount
        )
        tx.preferredCurrencyCode = "USD"
        return tx
    }

    /// Returns an interval covering "this month" so anomalies can be evaluated against
    /// the prior 90 days as baseline.
    private func currentMonthInterval() -> DateInterval {
        let cal = Calendar.current
        let start = cal.dateInterval(of: .month, for: Date.now)?.start ?? Date.now
        return DateInterval(start: start, end: Date.now)
    }

    private func daysAgo(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: Date.now) ?? Date.now
    }

    // MARK: - Tests

    @MainActor @Test func detect_singleLargeTx_flagsAnomaly() {
        let food = makeCategory(name: "Food")
        let interval = currentMonthInterval()

        // Baseline: 10 normal tx of ~$20 each over the past 60 days
        var baseline: [TransactionItem] = []
        for i in 1...10 {
            baseline.append(makeTx(amount: -20, date: daysAgo(20 + i * 3), category: food))
        }

        // Period: 1 huge tx of $200 (10x baseline)
        let anomaly = makeTx(amount: -200, date: interval.start.addingTimeInterval(3600), category: food, note: "Big dinner")

        let allTx = baseline + [anomaly]
        let periodTx = [anomaly]

        let result = AnomalyDetectionCalculator.detect(
            allTransactions: allTx,
            periodTransactions: periodTx,
            interval: interval,
            currencyCode: "USD",
            converter: MockCurrencyConverter(fixedRate: 1.0)
        )

        #expect(result.count == 1)
        #expect(result.first?.amount == 200.0)
        #expect(result.first?.category == "Food")
        #expect((result.first?.deviationPercent ?? 0) > 100)
    }

    @MainActor @Test func detect_normalTx_doesNotFlag() {
        let food = makeCategory(name: "Food")
        let interval = currentMonthInterval()

        var baseline: [TransactionItem] = []
        for i in 1...10 {
            baseline.append(makeTx(amount: -20, date: daysAgo(20 + i * 3), category: food))
        }
        let normal = makeTx(amount: -25, date: interval.start.addingTimeInterval(3600), category: food)

        let result = AnomalyDetectionCalculator.detect(
            allTransactions: baseline + [normal],
            periodTransactions: [normal],
            interval: interval,
            currencyCode: "USD",
            converter: MockCurrencyConverter(fixedRate: 1.0)
        )

        #expect(result.isEmpty)
    }

    @MainActor @Test func detect_emptyBaseline_returnsEmpty() {
        let food = makeCategory(name: "Food")
        let interval = currentMonthInterval()
        let lone = makeTx(amount: -500, date: interval.start.addingTimeInterval(3600), category: food)

        let result = AnomalyDetectionCalculator.detect(
            allTransactions: [lone],
            periodTransactions: [lone],
            interval: interval,
            currencyCode: "USD",
            converter: MockCurrencyConverter(fixedRate: 1.0)
        )

        // No baseline → no average to compare against → no anomalies
        #expect(result.isEmpty)
    }

    @MainActor @Test func detect_sortedByDeviationDesc() {
        let food = makeCategory(name: "Food")
        let transport = makeCategory(name: "Transport")
        let interval = currentMonthInterval()

        var baseline: [TransactionItem] = []
        for i in 1...10 {
            baseline.append(makeTx(amount: -20, date: daysAgo(20 + i * 3), category: food))
            baseline.append(makeTx(amount: -10, date: daysAgo(20 + i * 3), category: transport))
        }
        // Food anomaly: 5x baseline ($100 vs $20)
        let foodAnomaly = makeTx(amount: -100, date: interval.start.addingTimeInterval(3600), category: food)
        // Transport anomaly: 10x baseline ($100 vs $10)
        let transportAnomaly = makeTx(amount: -100, date: interval.start.addingTimeInterval(7200), category: transport)

        let result = AnomalyDetectionCalculator.detect(
            allTransactions: baseline + [foodAnomaly, transportAnomaly],
            periodTransactions: [foodAnomaly, transportAnomaly],
            interval: interval,
            currencyCode: "USD",
            converter: MockCurrencyConverter(fixedRate: 1.0)
        )

        #expect(result.count == 2)
        #expect(result.first?.category == "Transport") // higher deviation first
        #expect(result.last?.category == "Food")
    }

    @MainActor @Test func detect_respectsLimit() {
        let food = makeCategory(name: "Food")
        let interval = currentMonthInterval()

        var baseline: [TransactionItem] = []
        for i in 1...10 {
            baseline.append(makeTx(amount: -20, date: daysAgo(20 + i * 3), category: food))
        }
        var anomalies: [TransactionItem] = []
        for i in 1...5 {
            anomalies.append(makeTx(amount: Double(-50 - i * 10), date: interval.start.addingTimeInterval(Double(i) * 3600), category: food))
        }

        let result = AnomalyDetectionCalculator.detect(
            allTransactions: baseline + anomalies,
            periodTransactions: anomalies,
            interval: interval,
            currencyCode: "USD",
            converter: MockCurrencyConverter(fixedRate: 1.0),
            limit: 3
        )

        #expect(result.count == 3)
    }

    @MainActor @Test func detect_canonicalizesMerchant() {
        let food = makeCategory(name: "Food")
        let interval = currentMonthInterval()

        var baseline: [TransactionItem] = []
        for i in 1...10 {
            baseline.append(makeTx(amount: -20, date: daysAgo(20 + i * 3), category: food))
        }
        let anomaly = makeTx(
            amount: -200,
            date: interval.start.addingTimeInterval(3600),
            category: food,
            note: "Lunch with Juan at Starbucks"
        )

        let result = AnomalyDetectionCalculator.detect(
            allTransactions: baseline + [anomaly],
            periodTransactions: [anomaly],
            interval: interval,
            currencyCode: "USD",
            converter: MockCurrencyConverter(fixedRate: 1.0)
        )

        // merchant should be canonicalized — should not equal raw note verbatim
        let merchant = result.first?.merchant
        #expect(merchant != nil)
        #expect(merchant != "Lunch with Juan at Starbucks")
    }
}
