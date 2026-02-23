//
//  ScheduledPaymentDateCalculatorTests.swift
//  YalaTests
//
//  Tests for ScheduledPaymentDateCalculator — BUG-25 to BUG-29.
//

import Foundation
import Testing

@testable import Yala

struct ScheduledPaymentDateCalculatorTests {

    // MARK: - Helpers

    private let calendar = Calendar.current

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func monthDate(_ year: Int, _ month: Int) -> Date {
        date(year, month, 15)
    }

    private func makeParams(
        isRecurring: Bool = true,
        recurrenceType: String = "monthly",
        recurrenceInterval: Int = 1,
        nextDueDate: Date? = nil,
        createdAt: Date? = nil,
        endDate: Date? = nil,
        dayOfMonth: Int? = nil,
        selectedWeekdays: String? = nil,
        yearlyMonth: Int? = nil,
        yearlyDay: Int? = nil
    ) -> ScheduledPaymentDateCalculator.PaymentParams {
        ScheduledPaymentDateCalculator.PaymentParams(
            isRecurring: isRecurring,
            recurrenceType: recurrenceType,
            recurrenceInterval: recurrenceInterval,
            nextDueDate: nextDueDate ?? date(2026, 1, 15),
            createdAt: createdAt ?? date(2025, 1, 1),
            endDate: endDate,
            dayOfMonth: dayOfMonth,
            selectedWeekdays: selectedWeekdays,
            yearlyMonth: yearlyMonth,
            yearlyDay: yearlyDay
        )
    }

    // MARK: - BUG-25: endDate respected

    @Test func monthlyEndDateCutsOffFutureOccurrences() {
        let params = makeParams(
            recurrenceType: "monthly",
            endDate: date(2026, 3, 31),
            dayOfMonth: 10
        )
        let apr = ScheduledPaymentDateCalculator.paymentDatesInMonth(params: params, month: monthDate(2026, 4))
        #expect(apr.isEmpty)

        let mar = ScheduledPaymentDateCalculator.paymentDatesInMonth(params: params, month: monthDate(2026, 3))
        #expect(mar.count == 1)
    }

    @Test func weeklyEndDateCutsOff() {
        let params = makeParams(
            recurrenceType: "weekly",
            endDate: date(2026, 2, 10),
            selectedWeekdays: "2" // Monday
        )
        // Feb 2026: Mondays are 2, 9, 16, 23 — endDate=10 means only 2 and 9
        let feb = ScheduledPaymentDateCalculator.paymentDatesInMonth(params: params, month: monthDate(2026, 2))
        #expect(feb.count == 2)
    }

    @Test func dailyEndDateCutsOff() {
        let params = makeParams(
            recurrenceType: "daily",
            recurrenceInterval: 1,
            nextDueDate: date(2026, 3, 1),
            createdAt: date(2026, 3, 1),
            endDate: date(2026, 3, 5)
        )
        let mar = ScheduledPaymentDateCalculator.paymentDatesInMonth(params: params, month: monthDate(2026, 3))
        #expect(mar.count == 5) // 1,2,3,4,5
    }

    @Test func yearlyEndDateCutsOff() {
        let params = makeParams(
            recurrenceType: "yearly",
            nextDueDate: date(2025, 6, 15),
            endDate: date(2026, 5, 1),
            yearlyMonth: 6,
            yearlyDay: 15
        )
        let jun2026 = ScheduledPaymentDateCalculator.paymentDatesInMonth(params: params, month: monthDate(2026, 6))
        #expect(jun2026.isEmpty)

        let jun2025 = ScheduledPaymentDateCalculator.paymentDatesInMonth(params: params, month: monthDate(2025, 6))
        #expect(jun2025.count == 1)
    }

    // MARK: - BUG-26: weekly respects recurrenceInterval

    @Test func weeklyInterval2AlternatesWeeks() {
        let params = makeParams(
            recurrenceType: "weekly",
            recurrenceInterval: 2,
            nextDueDate: date(2026, 2, 2), // Monday Feb 2
            selectedWeekdays: "2" // Monday
        )
        // Feb 2026 Mondays: 2, 9, 16, 23 — with interval=2 anchored on Feb 2: 2 and 16
        let feb = ScheduledPaymentDateCalculator.paymentDatesInMonth(params: params, month: monthDate(2026, 2))
        #expect(feb.count == 2)
        #expect(feb.contains(date(2026, 2, 2)))
        #expect(feb.contains(date(2026, 2, 16)))
    }

    @Test func weeklyInterval1ShowsEveryWeek() {
        let params = makeParams(
            recurrenceType: "weekly",
            recurrenceInterval: 1,
            selectedWeekdays: "2" // Monday
        )
        // Feb 2026 has 4 Mondays
        let feb = ScheduledPaymentDateCalculator.paymentDatesInMonth(params: params, month: monthDate(2026, 2))
        #expect(feb.count == 4)
    }

    // MARK: - BUG-27: monthly respects recurrenceInterval

    @Test func monthlyInterval3IsQuarterly() {
        let params = makeParams(
            recurrenceType: "monthly",
            recurrenceInterval: 3,
            nextDueDate: date(2026, 1, 15),
            dayOfMonth: 15
        )
        // Jan anchor, interval=3 → Jan, Apr, Jul, Oct
        let jan = ScheduledPaymentDateCalculator.paymentDatesInMonth(params: params, month: monthDate(2026, 1))
        let feb = ScheduledPaymentDateCalculator.paymentDatesInMonth(params: params, month: monthDate(2026, 2))
        let apr = ScheduledPaymentDateCalculator.paymentDatesInMonth(params: params, month: monthDate(2026, 4))

        #expect(jan.count == 1)
        #expect(feb.isEmpty)
        #expect(apr.count == 1)
    }

    @Test func monthlyInterval1ShowsEveryMonth() {
        let params = makeParams(
            recurrenceType: "monthly",
            recurrenceInterval: 1,
            dayOfMonth: 10
        )
        let feb = ScheduledPaymentDateCalculator.paymentDatesInMonth(params: params, month: monthDate(2026, 2))
        let mar = ScheduledPaymentDateCalculator.paymentDatesInMonth(params: params, month: monthDate(2026, 3))
        #expect(feb.count == 1)
        #expect(mar.count == 1)
    }

    @Test func monthlyInterval3CrossYear() {
        let params = makeParams(
            recurrenceType: "monthly",
            recurrenceInterval: 3,
            nextDueDate: date(2025, 10, 15),
            dayOfMonth: 15
        )
        // Oct 2025 anchor, interval=3 → Oct 2025, Jan 2026, Apr 2026
        let jan2026 = ScheduledPaymentDateCalculator.paymentDatesInMonth(params: params, month: monthDate(2026, 1))
        let feb2026 = ScheduledPaymentDateCalculator.paymentDatesInMonth(params: params, month: monthDate(2026, 2))
        #expect(jan2026.count == 1)
        #expect(feb2026.isEmpty)
    }

    // MARK: - BUG-28: daily safety (no infinite loop)

    @Test func dailyNormalInterval() {
        let params = makeParams(
            recurrenceType: "daily",
            recurrenceInterval: 3,
            nextDueDate: date(2026, 3, 1),
            createdAt: date(2026, 3, 1)
        )
        // Mar 2026 has 31 days, every 3 days from 1st: 1,4,7,10,13,16,19,22,25,28,31 = 11
        let mar = ScheduledPaymentDateCalculator.paymentDatesInMonth(params: params, month: monthDate(2026, 3))
        #expect(mar.count == 11)
    }

    @Test func dailyIntervalZeroDoesNotHang() {
        let params = makeParams(
            recurrenceType: "daily",
            recurrenceInterval: 0, // edge case — should be treated as 1
        nextDueDate: date(2026, 3, 1),
            createdAt: date(2026, 3, 1)
        )
        let mar = ScheduledPaymentDateCalculator.paymentDatesInMonth(params: params, month: monthDate(2026, 3))
        // interval=0 → max(1,0)=1 → daily, 31 days
        #expect(mar.count == 31)
    }

    // MARK: - Regression: one-time payment

    @Test func oneTimeInMonth() {
        let params = makeParams(
            isRecurring: false,
            nextDueDate: date(2026, 3, 15),
            createdAt: date(2026, 1, 1)
        )
        let mar = ScheduledPaymentDateCalculator.paymentDatesInMonth(params: params, month: monthDate(2026, 3))
        #expect(mar.count == 1)
    }

    @Test func oneTimeOutOfMonth() {
        let params = makeParams(
            isRecurring: false,
            nextDueDate: date(2026, 3, 15),
            createdAt: date(2026, 1, 1)
        )
        let feb = ScheduledPaymentDateCalculator.paymentDatesInMonth(params: params, month: monthDate(2026, 2))
        #expect(feb.isEmpty)
    }

    // MARK: - Regression: createdAt filters backward propagation

    @Test func createdAtFiltersOldDates() {
        let params = makeParams(
            recurrenceType: "monthly",
            recurrenceInterval: 1,
            nextDueDate: date(2026, 1, 10),
            createdAt: date(2026, 3, 1),
            dayOfMonth: 10
        )
        // Created Mar 1 — Feb should be filtered out
        let feb = ScheduledPaymentDateCalculator.paymentDatesInMonth(params: params, month: monthDate(2026, 2))
        #expect(feb.isEmpty)

        // Mar 10 >= Mar 1, so it passes
        let mar = ScheduledPaymentDateCalculator.paymentDatesInMonth(params: params, month: monthDate(2026, 3))
        #expect(mar.count == 1)
    }

    // MARK: - parseWeekdays

    @Test func parseWeekdaysStandard() {
        let result = ScheduledPaymentDateCalculator.parseWeekdays("1,3,5")
        #expect(result == Set([1, 3, 5]))
    }

    @Test func parseWeekdaysNil() {
        let result = ScheduledPaymentDateCalculator.parseWeekdays(nil)
        #expect(result.isEmpty)
    }

    @Test func parseWeekdaysEmpty() {
        let result = ScheduledPaymentDateCalculator.parseWeekdays("")
        #expect(result.isEmpty)
    }
}
