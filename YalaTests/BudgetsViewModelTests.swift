//
//  BudgetsViewModelTests.swift
//  YalaTests
//
//  Unit tests for BudgetsViewModel - Pure logic tests (no SwiftData context)
//

import Foundation
import Testing

@testable import Yala

struct BudgetsViewModelTests {

    // MARK: - Budget Status Logic Tests
    // These test the pure logic of status determination without SwiftData

    @MainActor
    @Test("Status is active when spending is under limit")
    func statusActiveWhenUnderLimit() async {
        let vm = BudgetsViewModel()

        // Test logic: isActive=true, spending < limit → .active
        let status = vm.calculateBudgetStatus(isActive: true, spending: 500, limit: 1000)
        #expect(status == .active)
    }

    @MainActor
    @Test("Status is exceeded when spending equals limit")
    func statusExceededAtLimit() async {
        let vm = BudgetsViewModel()

        // Test logic: isActive=true, spending == limit → .exceeded
        let status = vm.calculateBudgetStatus(isActive: true, spending: 1000, limit: 1000)
        #expect(status == .exceeded)
    }

    @MainActor
    @Test("Status is exceeded when spending is over limit")
    func statusExceededWhenOverLimit() async {
        let vm = BudgetsViewModel()

        // Test logic: isActive=true, spending > limit → .exceeded
        let status = vm.calculateBudgetStatus(isActive: true, spending: 1200, limit: 1000)
        #expect(status == .exceeded)
    }

    @MainActor
    @Test("Status is inactive when budget is disabled")
    func statusInactiveWhenDisabled() async {
        let vm = BudgetsViewModel()

        // Test logic: isActive=false → .inactive (regardless of spending)
        let status = vm.calculateBudgetStatus(isActive: false, spending: 500, limit: 1000)
        #expect(status == .inactive)
    }

    @MainActor
    @Test("Inactive status even when spending exceeds limit")
    func inactiveStatusEvenWhenExceeded() async {
        let vm = BudgetsViewModel()

        // Test logic: isActive=false with exceeded spending → still .inactive
        let status = vm.calculateBudgetStatus(isActive: false, spending: 2000, limit: 1000)
        #expect(status == .inactive)
    }

    @MainActor
    @Test("Status active when spending is zero")
    func statusActiveWhenZeroSpending() async {
        let vm = BudgetsViewModel()

        // Test logic: no spending yet → .active
        let status = vm.calculateBudgetStatus(isActive: true, spending: 0, limit: 1000)
        #expect(status == .active)
    }

    @MainActor
    @Test("Status exceeded when limit is zero and any spending")
    func statusExceededWhenZeroLimit() async {
        let vm = BudgetsViewModel()

        // Edge case: limit of 0 means any spending exceeds
        let status = vm.calculateBudgetStatus(isActive: true, spending: 1, limit: 0)
        #expect(status == .exceeded)
    }

    // MARK: - Display Properties Logic Tests

    @MainActor
    @Test("Default properties when no subcategories")
    func defaultPropertiesNoSubcategories() async {
        let vm = BudgetsViewModel()

        // Test logic: empty subcategories → default icon/color
        let (icon, color) = vm.calculateDisplayProperties(subcategoryCount: 0, firstSubcategoryIcon: nil, firstCategoryColor: nil, uniqueCategoryCount: 0)

        #expect(icon == "chart.pie.fill")
        #expect(color == "#6366F1")
    }

    @MainActor
    @Test("Single subcategory uses its properties")
    func singleSubcategoryUsesItsProperties() async {
        let vm = BudgetsViewModel()

        // Test logic: exactly 1 subcategory → use its icon and category color
        let (icon, color) = vm.calculateDisplayProperties(
            subcategoryCount: 1,
            firstSubcategoryIcon: "cart.fill",
            firstCategoryColor: "#EF4444",
            uniqueCategoryCount: 1
        )

        #expect(icon == "cart.fill")
        #expect(color == "#EF4444")
    }

    @MainActor
    @Test("Multiple subcategories same category uses category properties")
    func multipleSubcategoriesSameCategoryUsesCategory() async {
        let vm = BudgetsViewModel()

        // Test logic: multiple subs from same category → use category icon/color
        let (icon, color) = vm.calculateDisplayProperties(
            subcategoryCount: 3,
            firstSubcategoryIcon: "cart.fill",
            firstCategoryColor: "#EF4444",
            uniqueCategoryCount: 1,
            firstCategoryIcon: "fork.knife"
        )

        #expect(icon == "fork.knife")
        #expect(color == "#EF4444")
    }

    @MainActor
    @Test("Multiple subcategories multiple categories uses default")
    func multipleSubcategoriesMultipleCategoriesUsesDefault() async {
        let vm = BudgetsViewModel()

        // Test logic: subs from different categories → use default
        let (icon, color) = vm.calculateDisplayProperties(
            subcategoryCount: 3,
            firstSubcategoryIcon: "cart.fill",
            firstCategoryColor: "#EF4444",
            uniqueCategoryCount: 2
        )

        #expect(icon == "chart.pie.fill")
        #expect(color == "#6366F1")
    }

    // MARK: - userConfiguredCalendar firstWeekday Regression
    // Regression for the bug where weekly budgets started on Sunday (system default)
    // instead of the user's "Monday" preference. Helper now reads firstWeekday from
    // the injected UserDefaults and BudgetsViewModel routes all weekly math through it.

    @Test("userConfiguredCalendar respects Monday preference")
    func userConfiguredCalendar_respectsMondayPreference() {
        let defaults = UserDefaults(suiteName: "test.\(UUID().uuidString)")!
        defaults.set(2, forKey: "firstWeekday")
        let cal = userConfiguredCalendar(defaults: defaults)
        #expect(cal.firstWeekday == 2)
    }

    @Test("userConfiguredCalendar respects Sunday preference")
    func userConfiguredCalendar_respectsSundayPreference() {
        let defaults = UserDefaults(suiteName: "test.\(UUID().uuidString)")!
        defaults.set(1, forKey: "firstWeekday")
        let cal = userConfiguredCalendar(defaults: defaults)
        #expect(cal.firstWeekday == 1)
    }

    @Test("userConfiguredCalendar defaults to Monday when preference unset")
    func userConfiguredCalendar_defaultsToMondayWhenUnset() {
        let defaults = UserDefaults(suiteName: "test.\(UUID().uuidString)")!
        let cal = userConfiguredCalendar(defaults: defaults)
        #expect(cal.firstWeekday == 2, "Default should be Monday (2), not system default Sunday (1)")
    }
}
