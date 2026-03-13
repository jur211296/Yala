//
//  ExchangeRateServiceTests.swift
//  YalaTests
//
//  Unit tests for ExchangeRateService utility logic (date grouping, protocol conformance).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

struct ExchangeRateServiceTests {

    // MARK: - Protocol Conformance

    @MainActor @Test func conformsToProtocol() {
        let service = ExchangeRateService.shared
        #expect(service is ExchangeRateServiceProtocol)
    }

    // MARK: - Date Key Format

    @Test func dateKeyFormat_isYYYYMMDD() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")

        let calendar = Calendar.current
        let date = calendar.date(from: DateComponents(year: 2025, month: 3, day: 15))!
        let key = formatter.string(from: date)
        #expect(key == "2025-03-15")
    }

    @Test func dateKeyFormat_singleDigitMonthDay_pads() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")

        let calendar = Calendar.current
        let date = calendar.date(from: DateComponents(year: 2025, month: 1, day: 5))!
        let key = formatter.string(from: date)
        #expect(key == "2025-01-05")
    }

    // MARK: - Date Grouping Logic (mirrors private groupIntoRanges)

    @Test func groupIntoRanges_contiguousDates_singleRange() {
        let calendar = Calendar.current
        let dates = [
            calendar.date(from: DateComponents(year: 2025, month: 1, day: 1))!,
            calendar.date(from: DateComponents(year: 2025, month: 1, day: 2))!,
            calendar.date(from: DateComponents(year: 2025, month: 1, day: 3))!,
        ]

        let ranges = groupDatesIntoRanges(dates)
        #expect(ranges.count == 1)
    }

    @Test func groupIntoRanges_withGap_twoRanges() {
        let calendar = Calendar.current
        let dates = [
            calendar.date(from: DateComponents(year: 2025, month: 1, day: 1))!,
            calendar.date(from: DateComponents(year: 2025, month: 1, day: 2))!,
            // gap
            calendar.date(from: DateComponents(year: 2025, month: 1, day: 5))!,
            calendar.date(from: DateComponents(year: 2025, month: 1, day: 6))!,
        ]

        let ranges = groupDatesIntoRanges(dates)
        #expect(ranges.count == 2)
    }

    @Test func groupIntoRanges_singleDate_singleRange() {
        let calendar = Calendar.current
        let dates = [
            calendar.date(from: DateComponents(year: 2025, month: 6, day: 15))!
        ]

        let ranges = groupDatesIntoRanges(dates)
        #expect(ranges.count == 1)
    }

    @Test func groupIntoRanges_empty_noRanges() {
        let ranges = groupDatesIntoRanges([])
        #expect(ranges.isEmpty)
    }

    @Test func groupIntoRanges_allSeparate_manyRanges() {
        let calendar = Calendar.current
        let dates = [
            calendar.date(from: DateComponents(year: 2025, month: 1, day: 1))!,
            calendar.date(from: DateComponents(year: 2025, month: 1, day: 5))!,
            calendar.date(from: DateComponents(year: 2025, month: 1, day: 10))!,
        ]

        let ranges = groupDatesIntoRanges(dates)
        #expect(ranges.count == 3)
    }

    // MARK: - Helper (mirrors ExchangeRateService.groupIntoRanges)

    /// Reimplementation of the private groupIntoRanges for testing the algorithm
    private func groupDatesIntoRanges(_ dates: [Date]) -> [DateInterval] {
        guard !dates.isEmpty else { return [] }

        let sortedDates = dates.sorted()
        var ranges: [DateInterval] = []
        var rangeStart = sortedDates[0]
        var rangeEnd = sortedDates[0]

        for date in sortedDates.dropFirst() {
            let daysDiff = Calendar.current.dateComponents([.day], from: rangeEnd, to: date).day ?? 0

            if daysDiff <= 1 {
                rangeEnd = date
            } else {
                ranges.append(DateInterval(start: rangeStart, end: rangeEnd))
                rangeStart = date
                rangeEnd = date
            }
        }

        ranges.append(DateInterval(start: rangeStart, end: rangeEnd))
        return ranges
    }
}
