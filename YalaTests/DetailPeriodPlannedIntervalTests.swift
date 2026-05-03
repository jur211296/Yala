//
//  DetailPeriodPlannedIntervalTests.swift
//  YalaTests
//
//  Unit tests for DetailPeriod.plannedInterval and shouldShowPlannedHint.
//  Deterministic via injected `now` and gregorian calendar.
//

import Foundation
import Testing

@testable import Yala

@MainActor
struct DetailPeriodPlannedIntervalTests {

    // MARK: - Fixtures

    /// Gregorian calendar with explicit firstWeekday=1 (Sunday) to keep weekly
    /// boundaries deterministic across host locale settings.
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 1
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var c = DateComponents()
        c.year = year; c.month = month; c.day = day
        c.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: c)!.addingTimeInterval(0)
    }

    /// Reference `now`: Friday 2026-05-15 12:00 UTC. Mid-month, mid-year, non-leap.
    private var now: Date {
        var c = DateComponents()
        c.year = 2026; c.month = 5; c.day = 15; c.hour = 12
        c.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: c)!
    }

    private var endOfCurrentMonth: Date {
        // 2026-06-01 00:00 UTC
        date(2026, 6, 1)
    }

    // MARK: - plannedInterval

    @Test func plannedInterval_thisWeek_endsAtMinOfWeekEndAndMonthEnd() {
        // 2026-05-15 is Friday. With firstWeekday=Sunday → week starts 2026-05-10,
        // ends 2026-05-17 (next Sunday). 17 < 1-Jun → endOfWeek wins.
        let interval = DetailPeriod.thisWeek.plannedInterval(
            customRange: nil,
            calendar: calendar,
            now: now
        )
        #expect(interval != nil)
        #expect(interval?.start == date(2026, 5, 10))
        #expect(interval?.end == date(2026, 5, 17))
    }

    @Test func plannedInterval_thisMonth_endsAtEndOfMonth() {
        let interval = DetailPeriod.thisMonth.plannedInterval(
            customRange: nil,
            calendar: calendar,
            now: now
        )
        #expect(interval != nil)
        #expect(interval?.start == date(2026, 5, 1))
        #expect(interval?.end == endOfCurrentMonth)
    }

    @Test func plannedInterval_thisYear_endsAtEndOfCurrentMonth() {
        let interval = DetailPeriod.thisYear.plannedInterval(
            customRange: nil,
            calendar: calendar,
            now: now
        )
        #expect(interval != nil)
        #expect(interval?.start == date(2026, 1, 1))
        // Truncated to end-of-current-month, not end-of-year.
        #expect(interval?.end == endOfCurrentMonth)
    }

    @Test func plannedInterval_lastMonth_returnsNil() {
        let interval = DetailPeriod.lastMonth.plannedInterval(
            customRange: nil,
            calendar: calendar,
            now: now
        )
        #expect(interval == nil)
    }

    @Test func plannedInterval_lastYear_returnsNil() {
        let interval = DetailPeriod.lastYear.plannedInterval(
            customRange: nil,
            calendar: calendar,
            now: now
        )
        #expect(interval == nil)
    }

    @Test func plannedInterval_last7Days_returnsNil() {
        let interval = DetailPeriod.last7Days.plannedInterval(
            customRange: nil,
            calendar: calendar,
            now: now
        )
        #expect(interval == nil)
    }

    @Test func plannedInterval_last30Days_returnsNil() {
        let interval = DetailPeriod.last30Days.plannedInterval(
            customRange: nil,
            calendar: calendar,
            now: now
        )
        #expect(interval == nil)
    }

    @Test func plannedInterval_allTime_returnsNil() {
        let interval = DetailPeriod.allTime.plannedInterval(
            customRange: nil,
            calendar: calendar,
            now: now
        )
        #expect(interval == nil)
    }

    @Test func plannedInterval_customWithFutureEnd_truncatesToMonthEnd() {
        // Custom range that extends beyond current month → truncated.
        let custom = DateInterval(start: date(2026, 4, 1), end: date(2026, 9, 30))
        let interval = DetailPeriod.custom.plannedInterval(
            customRange: custom,
            calendar: calendar,
            now: now
        )
        #expect(interval != nil)
        #expect(interval?.start == date(2026, 4, 1))
        #expect(interval?.end == endOfCurrentMonth)
    }

    @Test func plannedInterval_customAllPast_returnsNil() {
        // Custom range entirely in the past (end ≤ today) → nil.
        let custom = DateInterval(start: date(2024, 1, 1), end: date(2024, 12, 31))
        let interval = DetailPeriod.custom.plannedInterval(
            customRange: custom,
            calendar: calendar,
            now: now
        )
        #expect(interval == nil)
    }

    // MARK: - shouldShowPlannedHint

    @Test func shouldShowPlannedHint_thisYear_isTrue() {
        let show = DetailPeriod.thisYear.shouldShowPlannedHint(
            customRange: nil,
            calendar: calendar,
            now: now
        )
        #expect(show == true)
    }

    @Test func shouldShowPlannedHint_thisMonth_isFalse() {
        let show = DetailPeriod.thisMonth.shouldShowPlannedHint(
            customRange: nil,
            calendar: calendar,
            now: now
        )
        #expect(show == false)
    }

    @Test func shouldShowPlannedHint_customMultiMonth_isTrue() {
        // Custom that ends after current month end → hint applies.
        let custom = DateInterval(start: date(2026, 4, 1), end: date(2026, 8, 31))
        let show = DetailPeriod.custom.shouldShowPlannedHint(
            customRange: custom,
            calendar: calendar,
            now: now
        )
        #expect(show == true)
    }
}
