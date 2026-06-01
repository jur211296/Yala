//
//  DailySpendingCalculatorTests.swift
//  YalaTests
//
//  Unit tests for DailySpendingCalculator (daily expense aggregation for the
//  Records calendar). Pure logic, no ModelContext.
//

import Foundation
import Testing

@testable import Yala

struct DailySpendingCalculatorTests {
    private let calendar = Calendar.current

    private func startOfDay(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.startOfDay(for: calendar.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!)
    }

    private func makeAccount(excludeFromStatistics: Bool = false) -> Account {
        Account(
            name: "Main", currencyCode: "USD", colorHex: "#6366F1",
            iconName: "creditcard", type: "bank",
            excludeFromStatistics: excludeFromStatistics
        )
    }

    /// `preferred` es el monto en divisa preferida (negativo = gasto, positivo = ingreso).
    private func makeTx(
        preferred: Double,
        account: Account?,
        balanceAdjustmentType: String? = nil
    ) -> TransactionItem {
        let tx = TransactionItem(
            date: Date(),
            amount: preferred,
            currencyCode: "USD",
            note: "",
            account: account,
            tags: [],
            amountInPreferredCurrency: preferred,
            preferredCurrencyCode: "USD"
        )
        tx.balanceAdjustmentType = balanceAdjustmentType
        return tx
    }

    // MARK: - Tests

    @Test func empty_returnsZeroMax() {
        let result = DailySpendingCalculator.compute(groups: [])
        #expect(result.spendingByDay.isEmpty)
        #expect(result.maxSpending == 0)
    }

    @Test func sumsExpensesPerDay() {
        let acc = makeAccount()
        let day = startOfDay(2026, 1, 5)
        let groups = [(date: day, records: [
            makeTx(preferred: -100, account: acc),
            makeTx(preferred: -50, account: acc),
        ])]
        let result = DailySpendingCalculator.compute(groups: groups)
        #expect(result.spendingByDay[day] == 150)
        #expect(result.maxSpending == 150)
    }

    @Test func ignoresIncome() {
        let acc = makeAccount()
        let day = startOfDay(2026, 1, 5)
        let groups = [(date: day, records: [
            makeTx(preferred: 500, account: acc),
            makeTx(preferred: -80, account: acc),
        ])]
        let result = DailySpendingCalculator.compute(groups: groups)
        #expect(result.spendingByDay[day] == 80)
    }

    @Test func ignoresTransfersAndAdjustments() {
        let acc = makeAccount()
        let day = startOfDay(2026, 1, 5)
        let groups = [(date: day, records: [
            makeTx(preferred: -100, account: acc, balanceAdjustmentType: TransactionItem.adjustmentTypeTransfer),
            makeTx(preferred: -40, account: acc),
        ])]
        let result = DailySpendingCalculator.compute(groups: groups)
        #expect(result.spendingByDay[day] == 40)
    }

    @Test func ignoresExcludedAccounts() {
        let excluded = makeAccount(excludeFromStatistics: true)
        let day = startOfDay(2026, 1, 5)
        let groups = [(date: day, records: [makeTx(preferred: -100, account: excluded)])]
        let result = DailySpendingCalculator.compute(groups: groups)
        #expect(result.spendingByDay[day] == nil)
        #expect(result.maxSpending == 0)
    }

    @Test func ignoresRecordsWithoutAccount() {
        let day = startOfDay(2026, 1, 5)
        let groups = [(date: day, records: [makeTx(preferred: -100, account: nil)])]
        let result = DailySpendingCalculator.compute(groups: groups)
        #expect(result.spendingByDay.isEmpty)
    }

    @Test func maxAcrossDays() {
        let acc = makeAccount()
        let d1 = startOfDay(2026, 1, 5)
        let d2 = startOfDay(2026, 1, 6)
        let groups = [
            (date: d1, records: [makeTx(preferred: -100, account: acc)]),
            (date: d2, records: [makeTx(preferred: -250, account: acc)]),
        ]
        let result = DailySpendingCalculator.compute(groups: groups)
        #expect(result.spendingByDay[d1] == 100)
        #expect(result.spendingByDay[d2] == 250)
        #expect(result.maxSpending == 250)
    }

    @Test func incomeOnlyDay_notInResult() {
        let acc = makeAccount()
        let day = startOfDay(2026, 1, 5)
        let groups = [(date: day, records: [makeTx(preferred: 300, account: acc)])]
        let result = DailySpendingCalculator.compute(groups: groups)
        #expect(result.spendingByDay[day] == nil)
        #expect(result.maxSpending == 0)
    }
}
