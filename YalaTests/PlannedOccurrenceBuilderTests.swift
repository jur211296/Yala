//
//  PlannedOccurrenceBuilderTests.swift
//  YalaTests
//
//  Unit tests for PlannedOccurrenceBuilder.build (pure logic).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
struct PlannedOccurrenceBuilderTests {

    // MARK: - Helpers

    private let calendar = Calendar(identifier: .gregorian)

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var c = DateComponents()
        c.year = year; c.month = month; c.day = day
        return calendar.date(from: c)!
    }

    private func interval(from a: Date, to b: Date) -> DateInterval {
        DateInterval(start: a, end: b.addingTimeInterval(86400)) // include end day
    }

    private func makeSP(
        name: String = "Rent",
        amount: Double = 500,
        currencyCode: String = "USD",
        nextDueDate: Date,
        isRecurring: Bool = true,
        recurrenceType: String = "monthly",
        paymentCategory: String = "recurring",
        transactionType: String = "expense",
        isActive: Bool = true
    ) -> ScheduledPayment {
        let sp = ScheduledPayment(
            name: name,
            amount: amount,
            currencyCode: currencyCode,
            transactionType: transactionType,
            isRecurring: isRecurring,
            recurrenceType: recurrenceType,
            recurrenceInterval: 1,
            nextDueDate: nextDueDate,
            paymentCategory: paymentCategory,
            isActive: isActive
        )
        // Pin createdAt before fixtures so applyPostFilters keeps occurrences.
        sp.createdAt = date(2026, 1, 1)
        return sp
    }

    private func makeTx(
        amount: Double,
        date: Date,
        scheduledPaymentID: String? = nil
    ) -> TransactionItem {
        let tx = TransactionItem(
            date: date,
            amount: amount,
            currencyCode: "USD",
            note: nil
        )
        tx.scheduledPaymentID = scheduledPaymentID
        return tx
    }

    /// Identity converter (no rate change). Used when SP currency == default.
    private struct IdentityConverter: CurrencyConverting {
        func convert(_ amount: Decimal, from: String, to: String, on date: Date) -> Decimal { amount }
        func convertWithLatestRate(_ amount: Decimal, from: String, to: String) -> Decimal { amount }
    }

    /// Fixed-rate converter (USD → PEN at 4.0).
    private struct FixedRateConverter: CurrencyConverting {
        let rate: Decimal
        func convert(_ amount: Decimal, from: String, to: String, on date: Date) -> Decimal { amount * rate }
        func convertWithLatestRate(_ amount: Decimal, from: String, to: String) -> Decimal { amount * rate }
    }

    // MARK: - Tests

    @Test func build_excludesPaidOccurrence_byScheduledPaymentID() {
        let sp = makeSP(amount: 100, nextDueDate: date(2026, 4, 10))
        let paidTx = makeTx(amount: -100, date: date(2026, 4, 10), scheduledPaymentID: sp.id.uuidString)
        let result = PlannedOccurrenceBuilder.build(
            scheduledPayments: [sp],
            filteredTransactions: [paidTx],
            interval: interval(from: date(2026, 4, 1), to: date(2026, 4, 30)),
            selectedAccounts: [],
            defaultCurrencyCode: "USD",
            converter: IdentityConverter(),
            calendar: calendar
        )
        // Paid → no pending occurrence emitted.
        #expect(result.isEmpty)
    }

    @Test func build_excludesSkippedOccurrence() {
        let sp = makeSP(amount: 100, nextDueDate: date(2026, 4, 10))
        sp.skipDate(date(2026, 4, 10))
        let result = PlannedOccurrenceBuilder.build(
            scheduledPayments: [sp],
            filteredTransactions: [],
            interval: interval(from: date(2026, 4, 1), to: date(2026, 4, 30)),
            selectedAccounts: [],
            defaultCurrencyCode: "USD",
            converter: IdentityConverter(),
            calendar: calendar
        )
        #expect(result.isEmpty)
    }

    @Test func build_excludesIncomeScheduledPayment() {
        let sp = makeSP(
            name: "Salary",
            amount: 1000,
            nextDueDate: date(2026, 4, 1),
            transactionType: "income"
        )
        let result = PlannedOccurrenceBuilder.build(
            scheduledPayments: [sp],
            filteredTransactions: [],
            interval: interval(from: date(2026, 4, 1), to: date(2026, 4, 30)),
            selectedAccounts: [],
            defaultCurrencyCode: "USD",
            converter: IdentityConverter(),
            calendar: calendar
        )
        #expect(result.isEmpty)
    }

    @Test func build_excludesInactiveScheduledPayment() {
        let sp = makeSP(amount: 100, nextDueDate: date(2026, 4, 10), isActive: false)
        let result = PlannedOccurrenceBuilder.build(
            scheduledPayments: [sp],
            filteredTransactions: [],
            interval: interval(from: date(2026, 4, 1), to: date(2026, 4, 30)),
            selectedAccounts: [],
            defaultCurrencyCode: "USD",
            converter: IdentityConverter(),
            calendar: calendar
        )
        #expect(result.isEmpty)
    }

    @Test func build_convertsMultiCurrency_atFixedRate() {
        let sp = makeSP(amount: 100, currencyCode: "USD", nextDueDate: date(2026, 4, 10))
        let result = PlannedOccurrenceBuilder.build(
            scheduledPayments: [sp],
            filteredTransactions: [],
            interval: interval(from: date(2026, 4, 1), to: date(2026, 4, 30)),
            selectedAccounts: [],
            defaultCurrencyCode: "PEN",
            converter: FixedRateConverter(rate: 4),
            calendar: calendar
        )
        #expect(result.count == 1)
        #expect(result.first?.amount == 400)
    }

    @Test func build_intervalSubsetOfMonth_excludesOccurrencesOutsideInterval() {
        // Monthly SP due on day 25. Interval covers only days 1-10 of April.
        // Occurrence on April 25 should NOT appear.
        let sp = makeSP(amount: 100, nextDueDate: date(2026, 4, 25))
        let result = PlannedOccurrenceBuilder.build(
            scheduledPayments: [sp],
            filteredTransactions: [],
            interval: interval(from: date(2026, 4, 1), to: date(2026, 4, 10)),
            selectedAccounts: [],
            defaultCurrencyCode: "USD",
            converter: IdentityConverter(),
            calendar: calendar
        )
        #expect(result.isEmpty)
    }

    @Test func build_intervalSpanningTwoMonths_includesOccurrencesFromBoth() {
        // Monthly SP due on the 15th. Interval = Apr 1 to May 31 → 2 occurrences (Apr 15, May 15).
        let sp = makeSP(
            amount: 100,
            nextDueDate: date(2026, 4, 15),
            recurrenceType: "monthly"
        )
        let result = PlannedOccurrenceBuilder.build(
            scheduledPayments: [sp],
            filteredTransactions: [],
            interval: interval(from: date(2026, 4, 1), to: date(2026, 5, 31)),
            selectedAccounts: [],
            defaultCurrencyCode: "USD",
            converter: IdentityConverter(),
            calendar: calendar
        )
        #expect(result.count == 2)
        #expect(result.allSatisfy { $0.amount == 100 })
    }

    @Test func build_kindMappedFromPaymentCategory() {
        let recurring = makeSP(
            name: "Rent",
            amount: 100,
            nextDueDate: date(2026, 4, 10),
            paymentCategory: "recurring"
        )
        let subscription = makeSP(
            name: "Netflix",
            amount: 30,
            nextDueDate: date(2026, 4, 11),
            paymentCategory: "subscription"
        )
        let result = PlannedOccurrenceBuilder.build(
            scheduledPayments: [recurring, subscription],
            filteredTransactions: [],
            interval: interval(from: date(2026, 4, 1), to: date(2026, 4, 30)),
            selectedAccounts: [],
            defaultCurrencyCode: "USD",
            converter: IdentityConverter(),
            calendar: calendar
        )
        #expect(result.count == 2)
        #expect(result.contains { $0.kind == .recurring && $0.amount == 100 })
        #expect(result.contains { $0.kind == .subscription && $0.amount == 30 })
    }
}
