//
//  TrendProcessingTests.swift
//  YalaTests
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

    @Test("YDomain for Expense includes negative points (refund-dominant curve)")
    func yDomainExpenseWithNegative() {
        // La curva .expense signed puede ir negativa (reembolsos > gastos); el
        // dominio debe incluir el punto negativo, no clamparlo al piso 0.
        let points = [
            BarPoint(date: Date(), value: 50),
            BarPoint(date: Date(), value: -150),
        ]

        let domain = TrendProcessingHelper.calculateYDomain(for: points, isExpense: true)

        #expect(domain.lowerBound <= -150)  // incluye el negativo (antes: clampado a 0)
        #expect(domain.upperBound > 50)     // 50 + buffer
    }

    @Test("YDomain for Expense with all-negative points does not invert")
    func yDomainExpenseAllNegative() {
        // Período de solo reembolsos netos (todos los puntos negativos): el
        // techo NO debe invertirse a positivo (bug de abs) y el piso cubre el min.
        let points = [
            BarPoint(date: Date(), value: -80),
            BarPoint(date: Date(), value: -200),
        ]

        let domain = TrendProcessingHelper.calculateYDomain(for: points, isExpense: true)

        #expect(domain.lowerBound <= -200)          // cubre el min real
        #expect(domain.lowerBound < domain.upperBound)  // rango válido, no invertido
        #expect(domain.upperBound < 1000)           // techo razonable (0+buffer), no ~+200 por abs
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
        #expect(domain.lowerBound < -50)  // -50 - padding
        #expect(domain.upperBound > 100)  // 100 + padding
    }

    @Test("YDomain for Balance with only high positive values does not clamp to 0")
    func yDomainBalancePositiveHighValues() {
        // Given: all positive values far from zero (e.g. account balance)
        let points = [
            BarPoint(date: Date(), value: 5000),
            BarPoint(date: Date(), value: 8000),
        ]

        // When
        let domain = TrendProcessingHelper.calculateYDomain(for: points, isExpense: false)

        // Then: domain should hug the real min/max, not start at 0
        #expect(domain.lowerBound > 0)
        #expect(domain.lowerBound < 5000)  // 5000 - padding
        #expect(domain.upperBound > 8000)  // 8000 + padding
    }
}
