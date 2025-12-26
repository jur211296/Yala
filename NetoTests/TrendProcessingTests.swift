//
//  TrendProcessingTests.swift
//  NetoTests
//
//  Unit tests for TrendProcessingHelper.
//

import Foundation
import Testing

@testable import Neto

struct TrendProcessingTests {

    @Test("Moving Average handles empty data")
    func movingAverageEmpty() {
        let result = TrendProcessingHelper.movingAverage(for: [], window: 5)
        #expect(result.isEmpty)
    }

    @Test("Moving Average calculates correctly")
    func movingAverageCalculation() {
        // Given
        let dates = [
            Date(),
            Date().addingTimeInterval(86400),
            Date().addingTimeInterval(86400 * 2),
        ]
        let points = [
            BarPoint(date: dates[0], value: 10),
            BarPoint(date: dates[1], value: 20),
            BarPoint(date: dates[2], value: 30),
        ]

        // When (Window 2)
        // i=0: [10] -> 10
        // i=1: [10, 20] -> 15
        // i=2: [20, 30] -> 25
        let result = TrendProcessingHelper.movingAverage(for: points, window: 2)

        // Then
        #expect(result.count == 3)
        #expect(result[0].value == 10)
        #expect(result[1].value == 15)
        #expect(result[2].value == 25)
    }

    @Test("YDomain for Expense starts at 0")
    func yDomainExpense() {
        // Given
        let points = [
            BarPoint(date: Date(), value: 100),
            BarPoint(date: Date(), value: 50),
        ]

        // When
        let domain = TrendProcessingHelper.calculateYDomain(for: points, isExpense: true)

        // Then
        #expect(domain.lowerBound == 0)
        #expect(domain.upperBound > 100)  // 100 + buffer
    }

    @Test("YDomain for Balance handles negative values")
    func yDomainBalanceNegative() {
        // Given
        let points = [
            BarPoint(date: Date(), value: -50),
            BarPoint(date: Date(), value: 100),
        ]

        // When
        let domain = TrendProcessingHelper.calculateYDomain(for: points, isExpense: false)

        // Then
        #expect(domain.lowerBound < -50)  // -50 - buffer
        #expect(domain.upperBound > 100)  // 100 + buffer
    }
}
