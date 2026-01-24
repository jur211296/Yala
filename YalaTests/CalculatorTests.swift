//
//  CalculatorTests.swift
//  NetoTests
//
//  Unit tests for standard calculators to ensure refactoring didn't break logic.
//

import Foundation
import Testing

@testable import Yala

struct CalculatorTests {

    @Test("CashFlow grouping ensures correct monthly buckets")
    func cashFlowMonthlyGrouping() {
        // Given
        let grouping = TrendGrouping.month
        let calendar = Calendar.current
        let date = Date()

        // When
        let bucketStart = grouping.dateKey(for: date, calendar: calendar)
        let component = grouping.calendarComponent

        // Then
        let expectedStart = calendar.date(
            from: calendar.dateComponents([.year, .month], from: date))

        #expect(bucketStart == expectedStart)
        #expect(component == .month)
    }

    @Test("Balance trend grouping handles daily buckets")
    func balanceTrendDailyGrouping() {
        // Given
        let grouping = TrendGrouping.day
        let calendar = Calendar.current
        let date = Date()

        // When
        let bucketStart = grouping.dateKey(for: date, calendar: calendar)

        // Then
        let expectedStart = calendar.startOfDay(for: date)
        #expect(bucketStart == expectedStart)
    }

    @Test("TrendGrouping extension handles week correctly")
    func weeklyGrouping() {
        // Given
        let grouping = TrendGrouping.week
        let calendar = Calendar.current
        let date = Date()

        // When
        let bucketStart = grouping.dateKey(for: date, calendar: calendar)

        // Then
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        let expectedStart = calendar.date(from: components)

        #expect(bucketStart == expectedStart)
    }
}
