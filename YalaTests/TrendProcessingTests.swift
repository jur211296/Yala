//
//  TrendProcessingTests.swift
//  NetoTests
//
//  Unit tests for TrendProcessingHelper.
//

import Foundation
import Testing

@testable import Yala

struct TrendProcessingTests {

    @Test("Moving Average handles empty data")
    func movingAverageEmpty() {
        let result = TrendProcessingHelper.movingAverage(for: [], window: 5)
        #expect(result.isEmpty)
    }

    @Test("Moving Average preserves last window points unsmoothed")
    func movingAveragePreservesRecentData() {
        // Given: 3 points with window=2
        // Implementation preserves last `window` points without smoothing
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
        // noSmoothStart = 3 - 2 = 1
        // i=0: smoothed (only point) -> 10
        // i=1: preserved (in no-smooth zone) -> 20
        // i=2: preserved (in no-smooth zone) -> 30
        let result = TrendProcessingHelper.movingAverage(for: points, window: 2)

        // Then
        #expect(result.count == 3)
        #expect(result[0].value == 10)
        #expect(result[1].value == 20)  // Preserved, not averaged
        #expect(result[2].value == 30)  // Preserved, not averaged
    }

    @Test("Moving Average smooths historical data")
    func movingAverageSmoothsHistoricalData() {
        // Given: 5 points with window=2
        // First 3 points get smoothed, last 2 preserved
        let dates = (0..<5).map { Date().addingTimeInterval(86400 * Double($0)) }
        let points = [
            BarPoint(date: dates[0], value: 10),
            BarPoint(date: dates[1], value: 20),
            BarPoint(date: dates[2], value: 30),
            BarPoint(date: dates[3], value: 40),
            BarPoint(date: dates[4], value: 50),
        ]

        // When (Window 2)
        // noSmoothStart = 5 - 2 = 3
        // i=0: smoothed [10] -> 10
        // i=1: smoothed [10,20] -> 15
        // i=2: smoothed [20,30] -> 25
        // i=3: preserved -> 40
        // i=4: preserved -> 50
        let result = TrendProcessingHelper.movingAverage(for: points, window: 2)

        // Then
        #expect(result.count == 5)
        #expect(result[0].value == 10)
        #expect(result[1].value == 15)  // Smoothed
        #expect(result[2].value == 25)  // Smoothed
        #expect(result[3].value == 40)  // Preserved
        #expect(result[4].value == 50)  // Preserved
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
