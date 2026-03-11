//
//  BudgetAlertServiceTests.swift
//  YalaTests
//
//  Unit tests for BudgetAlertService.getCurrentPeriodInterval logic.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

struct BudgetAlertServiceTests {

    // MARK: - Period Interval Tests

    @MainActor @Test func weeklyPeriod_7dayDuration() {
        let service = BudgetAlertService.shared
        let budget = makeBudget(periodType: "weekly")
        let interval = service.getCurrentPeriodInterval(for: budget)

        let days = Calendar.current.dateComponents([.day], from: interval.start, to: interval.end).day!
        #expect(days == 7)
    }

    @MainActor @Test func monthlyPeriod_containsToday() {
        let service = BudgetAlertService.shared
        let budget = makeBudget(periodType: "monthly")
        let interval = service.getCurrentPeriodInterval(for: budget)

        #expect(interval.contains(Date()))
    }

    @MainActor @Test func monthlyPeriod_startIsFirstOfMonth() {
        let service = BudgetAlertService.shared
        let budget = makeBudget(periodType: "monthly")
        let interval = service.getCurrentPeriodInterval(for: budget)

        let day = Calendar.current.component(.day, from: interval.start)
        #expect(day == 1)
    }

    @MainActor @Test func yearlyPeriod_startsJan1() {
        let service = BudgetAlertService.shared
        let budget = makeBudget(periodType: "yearly")
        let interval = service.getCurrentPeriodInterval(for: budget)

        let components = Calendar.current.dateComponents([.month, .day], from: interval.start)
        #expect(components.month == 1)
        #expect(components.day == 1)
    }

    @MainActor @Test func uniquePeriod_usesExactDates() {
        let start = Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: 1))!
        let end = Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 30))!
        let service = BudgetAlertService.shared
        let budget = makeBudget(periodType: "unique", startDate: start, endDate: end)
        let interval = service.getCurrentPeriodInterval(for: budget)

        #expect(interval.start == start)
        #expect(interval.end == end)
    }

    @MainActor @Test func uniquePeriod_noDates_fallbackMonthly() {
        let service = BudgetAlertService.shared
        let budget = makeBudget(periodType: "unique")
        let interval = service.getCurrentPeriodInterval(for: budget)

        // Falls back to monthly — should contain today and start on day 1
        #expect(interval.contains(Date()))
        let day = Calendar.current.component(.day, from: interval.start)
        #expect(day == 1)
    }
}
