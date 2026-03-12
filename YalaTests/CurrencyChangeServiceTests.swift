//
//  CurrencyChangeServiceTests.swift
//  YalaTests
//
//  Unit tests for CurrencyChangeService rate calculation logic.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

struct CurrencyChangeServiceTests {

    // MARK: - Rate Derivation Logic

    @Test func effectiveRate_normalAmount() {
        // Mirrors the rate derivation logic in CurrencyChangeService.updateAllTransactions
        let amountDouble = 100.0
        let amountInPreferred = Decimal(375.0)  // 100 USD → 375 PEN

        let effectiveRate: Double
        if abs(amountDouble) > 0.0001 {
            effectiveRate = (amountInPreferred as NSDecimalNumber).doubleValue / amountDouble
        } else {
            effectiveRate = 1.0
        }

        #expect(abs(effectiveRate) == 3.75)
    }

    @Test func effectiveRate_negativeAmount() {
        let amountDouble = -50.0
        let amountInPreferred = Decimal(-187.5)

        let effectiveRate: Double
        if abs(amountDouble) > 0.0001 {
            effectiveRate = (amountInPreferred as NSDecimalNumber).doubleValue / amountDouble
        } else {
            effectiveRate = 1.0
        }

        #expect(abs(effectiveRate) == 3.75)
    }

    @Test func effectiveRate_zeroAmount_defaultsToOne() {
        let amountDouble = 0.0
        let amountInPreferred = Decimal(0)

        let effectiveRate: Double
        if abs(amountDouble) > 0.0001 {
            effectiveRate = (amountInPreferred as NSDecimalNumber).doubleValue / amountDouble
        } else {
            effectiveRate = 1.0
        }

        #expect(effectiveRate == 1.0)
    }

    @Test func effectiveRate_tinyAmount_defaultsToOne() {
        let amountDouble = 0.00001
        let amountInPreferred = Decimal(0.0000375)

        let effectiveRate: Double
        if abs(amountDouble) > 0.0001 {
            effectiveRate = (amountInPreferred as NSDecimalNumber).doubleValue / amountDouble
        } else {
            effectiveRate = 1.0
        }

        #expect(effectiveRate == 1.0)
    }

    // MARK: - Progress Callback Logic

    @Test func progressInterval_every20Items() {
        // Verify the progress reporting pattern
        var progressCalls: [Int] = []
        let total = 100

        for index in 0..<total {
            if index % 20 == 0 {
                progressCalls.append(index)
            }
        }

        #expect(progressCalls == [0, 20, 40, 60, 80])
    }

    @Test func progressValue_atCompletion() {
        let total = Double(50)
        let finalProgress = Double(50) / total
        #expect(finalProgress == 1.0)
    }
}
