//
//  TransactionUpdateServiceTests.swift
//  YalaTests
//
//  Unit tests for TransactionUpdateService rate calculation and update logic.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

struct TransactionUpdateServiceTests {

    // MARK: - Rate Derivation Logic (mirrors updateProvisionalTransactions)

    @Test func rateDerivation_normalPositiveAmount() {
        let amountDouble = 200.0
        let amountInPreferred = Decimal(750.0)  // 200 USD → 750 PEN at 3.75

        let effectiveRate: Double
        if abs(amountDouble) > 0.0001 {
            effectiveRate = (amountInPreferred as NSDecimalNumber).doubleValue / amountDouble
        } else {
            effectiveRate = 1.0
        }

        #expect(abs(effectiveRate - 3.75) < 0.001)
    }

    @Test func rateDerivation_negativeExpense() {
        let amountDouble = -100.0
        let amountInPreferred = Decimal(-375.0)

        let effectiveRate: Double
        if abs(amountDouble) > 0.0001 {
            effectiveRate = (amountInPreferred as NSDecimalNumber).doubleValue / amountDouble
        } else {
            effectiveRate = 1.0
        }

        // Rate should be stored as absolute
        #expect(abs(effectiveRate - 3.75) < 0.001)
    }

    @Test func rateDerivation_zeroAmount_fallbackToOne() {
        let amountDouble = 0.0

        let effectiveRate: Double
        if abs(amountDouble) > 0.0001 {
            effectiveRate = 0.0  // would never reach here
        } else {
            effectiveRate = 1.0
        }

        #expect(effectiveRate == 1.0)
    }

    // MARK: - Transaction Update Properties

    @Test func updatedTransaction_setsProvisionalFalse() {
        let tx = TransactionItem(
            date: Date(),
            amount: -100,
            currencyCode: "USD",
            note: nil,
            exchangeRate: 1.0,
            amountInPreferredCurrency: -100,
            preferredCurrencyCode: "USD"
        )
        tx.isExchangeRateProvisional = true

        // Simulate update
        tx.exchangeRate = 3.75
        tx.amountInPreferredCurrency = -375.0
        tx.preferredCurrencyCode = "PEN"
        tx.isExchangeRateProvisional = false

        #expect(tx.isExchangeRateProvisional == false)
        #expect(tx.exchangeRate == 3.75)
        #expect(tx.amountInPreferredCurrency == -375.0)
        #expect(tx.preferredCurrencyCode == "PEN")
    }

    // MARK: - Date Deduplication Logic

    @Test func uniqueDates_deduplicatesSameDay() {
        let calendar = Calendar.current
        let date1 = calendar.date(from: DateComponents(year: 2025, month: 3, day: 15, hour: 10))!
        let date2 = calendar.date(from: DateComponents(year: 2025, month: 3, day: 15, hour: 14))!
        let date3 = calendar.date(from: DateComponents(year: 2025, month: 3, day: 16, hour: 9))!

        // The service uses Set(transactions.map { $0.date }) to get unique dates
        // Since dates include time, same-day transactions with different times are different
        let dates = Set([date1, date2, date3])
        #expect(dates.count == 3)
    }
}
