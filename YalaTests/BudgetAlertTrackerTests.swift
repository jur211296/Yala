//
//  BudgetAlertTrackerTests.swift
//  YalaTests
//
//  Unit tests for BudgetAlertTracker period key generation and threshold tracking.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

struct BudgetAlertTrackerTests {

    // MARK: - Period Key Format

    @MainActor @Test func periodKey_weekly_format() {
        let tracker = BudgetAlertTracker.shared
        let budget = makeBudget(periodType: "weekly")
        let key = tracker.periodKey(for: budget)

        // Format: YYYY-Wnn
        #expect(key.contains("-W"))
        let parts = key.split(separator: "-")
        #expect(parts.count == 2)
        #expect(parts[0].count == 4)
        #expect(parts[1].hasPrefix("W"))
    }

    @MainActor @Test func periodKey_monthly_format() {
        let tracker = BudgetAlertTracker.shared
        let budget = makeBudget(periodType: "monthly")
        let key = tracker.periodKey(for: budget)

        // Format: yyyy-MM
        let parts = key.split(separator: "-")
        #expect(parts.count == 2)
        #expect(parts[0].count == 4)
        #expect(parts[1].count == 2)
    }

    @MainActor @Test func periodKey_yearly_format() {
        let tracker = BudgetAlertTracker.shared
        let budget = makeBudget(periodType: "yearly")
        let key = tracker.periodKey(for: budget)

        // Format: YYYY (4-digit year)
        #expect(key.count == 4)
        #expect(Int(key) != nil)
    }

    @MainActor @Test func periodKey_unique_format() {
        let start = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 15))!
        let end = Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 30))!
        let tracker = BudgetAlertTracker.shared
        let budget = makeBudget(periodType: "unique", startDate: start, endDate: end)
        let key = tracker.periodKey(for: budget)

        #expect(key == "unique_20260115_20260630")
    }

    @MainActor @Test func periodKey_invalidType_returnsUnknown() {
        let tracker = BudgetAlertTracker.shared
        let budget = makeBudget(periodType: "biweekly")
        let key = tracker.periodKey(for: budget)

        #expect(key == "unknown")
    }

    // MARK: - Threshold Tracking (isolated via unique UUID per test)

    @MainActor @Test func notifiedThresholds_empty_byDefault() {
        let tracker = BudgetAlertTracker.shared
        let budgetID = UUID()
        let result = tracker.notifiedThresholds(budgetID: budgetID, periodKey: "test_period")

        #expect(result.isEmpty)
    }

    @MainActor @Test func markNotified_thenRetrieve() {
        let tracker = BudgetAlertTracker.shared
        let budgetID = UUID()
        let periodKey = "test_\(UUID().uuidString)"

        tracker.markNotified(budgetID: budgetID, periodKey: periodKey, threshold: 50)
        let result = tracker.notifiedThresholds(budgetID: budgetID, periodKey: periodKey)

        #expect(result.contains(50))
    }

    @MainActor @Test func markNotified_duplicate_noDuplicate() {
        let tracker = BudgetAlertTracker.shared
        let budgetID = UUID()
        let periodKey = "test_\(UUID().uuidString)"

        tracker.markNotified(budgetID: budgetID, periodKey: periodKey, threshold: 50)
        tracker.markNotified(budgetID: budgetID, periodKey: periodKey, threshold: 50)
        let result = tracker.notifiedThresholds(budgetID: budgetID, periodKey: periodKey)

        #expect(result.count == 1)
    }

    // MARK: - getNewThresholds

    @MainActor @Test func getNewThresholds_returnsAllCrossed() {
        let tracker = BudgetAlertTracker.shared
        let budgetID = UUID()
        let periodKey = "test_\(UUID().uuidString)"

        let result = tracker.getNewThresholds(
            budgetID: budgetID,
            periodKey: periodKey,
            currentPercentage: 80,
            configuredThresholds: [50, 75, 90]
        )

        #expect(result.contains(50))
        #expect(result.contains(75))
        #expect(!result.contains(90))
    }

    @MainActor @Test func getNewThresholds_excludesNotified() {
        let tracker = BudgetAlertTracker.shared
        let budgetID = UUID()
        let periodKey = "test_\(UUID().uuidString)"

        tracker.markNotified(budgetID: budgetID, periodKey: periodKey, threshold: 50)

        let result = tracker.getNewThresholds(
            budgetID: budgetID,
            periodKey: periodKey,
            currentPercentage: 80,
            configuredThresholds: [50, 75, 90]
        )

        #expect(!result.contains(50))
        #expect(result.contains(75))
    }

    @MainActor @Test func getNewThresholds_belowAll_empty() {
        let tracker = BudgetAlertTracker.shared
        let budgetID = UUID()
        let periodKey = "test_\(UUID().uuidString)"

        let result = tracker.getNewThresholds(
            budgetID: budgetID,
            periodKey: periodKey,
            currentPercentage: 40,
            configuredThresholds: [50, 75]
        )

        #expect(result.isEmpty)
    }

    @MainActor @Test func getNewThresholds_sorted() {
        let tracker = BudgetAlertTracker.shared
        let budgetID = UUID()
        let periodKey = "test_\(UUID().uuidString)"

        let result = tracker.getNewThresholds(
            budgetID: budgetID,
            periodKey: periodKey,
            currentPercentage: 100,
            configuredThresholds: [90, 50, 75]
        )

        #expect(result == [50, 75, 90])
    }
}
