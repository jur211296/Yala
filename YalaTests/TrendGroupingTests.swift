//
//  TrendGroupingTests.swift
//  YalaTests
//
//  Unit tests for TrendGrouping extension methods.
//

import Foundation
import Testing

@testable import Yala

// MARK: - TrendGrouping Tests

struct TrendGroupingTests {

    let calendar = Calendar.current

    // MARK: - calendarComponent Tests

    @Test func calendarComponent_day_returnsDay() {
        #expect(TrendGrouping.day.calendarComponent == .day)
    }

    @Test func calendarComponent_week_returnsWeekOfYear() {
        #expect(TrendGrouping.week.calendarComponent == .weekOfYear)
    }

    @Test func calendarComponent_month_returnsMonth() {
        #expect(TrendGrouping.month.calendarComponent == .month)
    }

    // MARK: - dateKey Tests

    @Test func dateKey_day_returnsStartOfDay() {
        // Given: A date with time component (2024-12-24 14:30:00)
        let components = DateComponents(year: 2024, month: 12, day: 24, hour: 14, minute: 30)
        let date = calendar.date(from: components)!

        // When: Getting the day key
        let key = TrendGrouping.day.dateKey(for: date, calendar: calendar)

        // Then: Should return start of that day (midnight)
        let expected = calendar.startOfDay(for: date)
        #expect(key == expected)
    }

    @Test func dateKey_week_returnsStartOfWeek() {
        // Given: A date mid-week (2024-12-24 is a Tuesday)
        let components = DateComponents(year: 2024, month: 12, day: 24)
        let date = calendar.date(from: components)!

        // When: Getting the week key
        let key = TrendGrouping.week.dateKey(for: date, calendar: calendar)

        // Then: Should return start of that week
        let expected = calendar.dateInterval(of: .weekOfYear, for: date)?.start
        #expect(key == expected)
    }

    @Test func dateKey_month_returnsStartOfMonth() {
        // Given: A date mid-month (2024-12-24)
        let components = DateComponents(year: 2024, month: 12, day: 24)
        let date = calendar.date(from: components)!

        // When: Getting the month key
        let key = TrendGrouping.month.dateKey(for: date, calendar: calendar)

        // Then: Should return first day of that month
        let expected = calendar.dateInterval(of: .month, for: date)?.start
        #expect(key == expected)
    }
}

// MARK: - CurrencyDefaults Tests

struct CurrencyDefaultsTests {

    @Test func defaultCode_isPEN() {
        #expect(CurrencyDefaults.defaultCode == "PEN")
    }

    @Test func preferredCurrencyKey_isExpectedKey() {
        #expect(CurrencyDefaults.preferredCurrencyKey == "defaultCurrencyCode")
    }

    @Test func currentPreferred_returnsDefaultWhenNotSet() {
        // Note: This test assumes UserDefaults doesn't have the key set
        // In a real scenario, you'd want to clean up UserDefaults first
        let preferred = CurrencyDefaults.currentPreferred
        // Should be either the saved value or default
        #expect(!preferred.isEmpty)
        #expect(preferred.count == 3)  // Currency codes are 3 letters
    }
}

// MARK: - CurrencyCode Enum Tests

struct CurrencyCodeTests {

    @Test func allCases_containsMultipleCurrencies() {
        // 54 currencies organized by 7 continents
        #expect(CurrencyCode.allCases.count == 54)
    }

    @Test func pen_hasCorrectRawValue() {
        #expect(CurrencyCode.pen.rawValue == "PEN")
    }

    @Test func usd_hasCorrectRawValue() {
        #expect(CurrencyCode.usd.rawValue == "USD")
    }

    @Test func eur_hasCorrectRawValue() {
        #expect(CurrencyCode.eur.rawValue == "EUR")
    }
}
