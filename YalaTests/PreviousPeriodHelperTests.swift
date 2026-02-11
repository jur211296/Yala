//
//  PreviousPeriodHelperTests.swift
//  YalaTests
//
//  Unit tests for PreviousPeriodHelper (pure functions, no SwiftData).
//

import Foundation
import Testing

@testable import Yala

struct PreviousPeriodHelperTests {

    // MARK: - isSelectorVisible

    @Test func isSelectorVisible_thisWeek_true() {
        #expect(PreviousPeriodHelper.isSelectorVisible(for: .thisWeek) == true)
    }

    @Test func isSelectorVisible_thisMonth_true() {
        #expect(PreviousPeriodHelper.isSelectorVisible(for: .thisMonth) == true)
    }

    @Test func isSelectorVisible_thisYear_false() {
        #expect(PreviousPeriodHelper.isSelectorVisible(for: .thisYear) == false)
    }

    @Test func isSelectorVisible_lastYear_false() {
        #expect(PreviousPeriodHelper.isSelectorVisible(for: .lastYear) == false)
    }

    @Test func isSelectorVisible_allTime_false() {
        #expect(PreviousPeriodHelper.isSelectorVisible(for: .allTime) == false)
    }

    // MARK: - defaultMode

    @Test func defaultMode_thisWeek_month() {
        #expect(PreviousPeriodHelper.defaultMode(for: .thisWeek) == .month)
    }

    @Test func defaultMode_thisMonth_month() {
        #expect(PreviousPeriodHelper.defaultMode(for: .thisMonth) == .month)
    }

    @Test func defaultMode_thisYear_year() {
        #expect(PreviousPeriodHelper.defaultMode(for: .thisYear) == .year)
    }

    @Test func defaultMode_lastYear_year() {
        #expect(PreviousPeriodHelper.defaultMode(for: .lastYear) == .year)
    }

    @Test func defaultMode_allTime_year() {
        #expect(PreviousPeriodHelper.defaultMode(for: .allTime) == .year)
    }

    // MARK: - previousInterval

    @Test func previousInterval_thisWeek_month_matchesCurrentDuration() {
        let interval = PreviousPeriodHelper.previousInterval(for: .thisWeek, mode: .month)
        let currentInterval = DetailPeriod.thisWeek.dateInterval()
        // Previous interval should end just before current starts
        #expect(interval.end < currentInterval.start)
        // Duration should match current interval (thisWeek = start of week to today)
        let currentDays = currentInterval.duration / 86400
        let previousDays = interval.duration / 86400
        #expect(abs(previousDays - currentDays) < 1)
    }

    @Test func previousInterval_thisMonth_month_previousMonth() {
        let interval = PreviousPeriodHelper.previousInterval(for: .thisMonth, mode: .month)
        let currentInterval = DetailPeriod.thisMonth.dateInterval()
        // Previous month start should be before current month start
        #expect(interval.start < currentInterval.start)
        // Should be roughly a month (28-31 days)
        let durationDays = interval.duration / 86400
        #expect(durationDays >= 28 && durationDays <= 31)
    }

    @Test func previousInterval_lastMonth_month_twoMonthsAgo() {
        let interval = PreviousPeriodHelper.previousInterval(for: .lastMonth, mode: .month)
        let currentInterval = DetailPeriod.lastMonth.dateInterval()
        // Should be before current interval
        #expect(interval.start < currentInterval.start)
    }

    @Test func previousInterval_thisWeek_year_sameWeekLastYear() {
        let interval = PreviousPeriodHelper.previousInterval(for: .thisWeek, mode: .year)
        let cal = Calendar.current
        // Year component should be previous year
        let yearComponent = cal.component(.year, from: interval.start)
        let currentYear = cal.component(.year, from: Date())
        #expect(yearComponent == currentYear - 1)
    }

    @Test func previousInterval_thisMonth_year_sameMonthLastYear() {
        let interval = PreviousPeriodHelper.previousInterval(for: .thisMonth, mode: .year)
        let cal = Calendar.current
        let yearComponent = cal.component(.year, from: interval.start)
        let currentYear = cal.component(.year, from: Date())
        #expect(yearComponent == currentYear - 1)
        // Same month
        let monthComponent = cal.component(.month, from: interval.start)
        let currentMonth = cal.component(.month, from: Date())
        #expect(monthComponent == currentMonth)
    }

    @Test func previousInterval_allTime_returnsSameInterval() {
        let interval = PreviousPeriodHelper.previousInterval(for: .allTime, mode: .month)
        // allTime in month mode returns the same interval (no "previous" concept)
        // Duration should be very long (years worth of seconds)
        #expect(interval.duration > 86400 * 365)
    }

    // MARK: - calculateVariation

    @Test func calculateVariation_increase() {
        let result = PreviousPeriodHelper.calculateVariation(currentAmount: 1200, previousAmount: 1000)
        #expect(result == 20.0)
    }

    @Test func calculateVariation_decrease() {
        let result = PreviousPeriodHelper.calculateVariation(currentAmount: 800, previousAmount: 1000)
        #expect(result == -20.0)
    }

    @Test func calculateVariation_previousZero_nil() {
        let result = PreviousPeriodHelper.calculateVariation(currentAmount: 100, previousAmount: 0)
        #expect(result == nil)
    }

    @Test func calculateVariation_bothZero_nil() {
        let result = PreviousPeriodHelper.calculateVariation(currentAmount: 0, previousAmount: 0)
        #expect(result == nil)
    }

    // MARK: - formatVariation

    @Test func formatVariation_nil_NA() {
        #expect(PreviousPeriodHelper.formatVariation(nil) == "N/A")
    }

    @Test func formatVariation_positive() {
        let result = PreviousPeriodHelper.formatVariation(12.5)
        #expect(result == "+12.5%")
    }

    @Test func formatVariation_negative() {
        let result = PreviousPeriodHelper.formatVariation(-3.2)
        #expect(result == "-3.2%")
    }

    @Test func formatVariation_zero() {
        let result = PreviousPeriodHelper.formatVariation(0.0)
        #expect(result == "+0%")
    }
}
