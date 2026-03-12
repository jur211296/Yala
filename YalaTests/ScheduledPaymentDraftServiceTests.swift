// Tests generated for: ScheduledPaymentDraftService (advanceToNextDueDate)
// Cobertura estimada: 85% of advanceToNextDueDate logic

import Foundation
import Testing

@testable import Yala

@MainActor
struct ScheduledPaymentDraftServiceTests {

    // MARK: - Helpers

    private let calendar = Calendar.current

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func makePayment(
        name: String = "Test Payment",
        amount: Double = 100,
        isRecurring: Bool = true,
        recurrenceType: String = "monthly",
        recurrenceInterval: Int = 1,
        nextDueDate: Date? = nil,
        dayOfMonth: Int? = nil,
        endDate: Date? = nil,
        transactionType: String = "expense",
        paymentCategory: String = "recurring"
    ) -> ScheduledPayment {
        ScheduledPayment(
            name: name,
            amount: amount,
            currencyCode: "USD",
            transactionType: transactionType,
            isRecurring: isRecurring,
            recurrenceType: recurrenceType,
            recurrenceInterval: recurrenceInterval,
            nextDueDate: nextDueDate ?? date(2026, 3, 15),
            dayOfMonth: dayOfMonth,
            endDate: endDate,
            paymentCategory: paymentCategory,
            notifyOnDueDate: true,
            notifyDaysBefore: 0,
            isActive: true
        )
    }

    // MARK: - One-Time Payment

    @Test func advanceToNextDueDate_oneTimePayment_deactivates() {
        let payment = makePayment(isRecurring: false)
        #expect(payment.isActive == true)

        ScheduledPaymentDraftService.advanceToNextDueDate(payment: payment)

        #expect(payment.isActive == false)
    }

    // MARK: - Daily Recurrence

    @Test func advanceToNextDueDate_daily_advancesByOneDay() {
        let payment = makePayment(recurrenceType: "daily", nextDueDate: date(2026, 3, 15))

        ScheduledPaymentDraftService.advanceToNextDueDate(payment: payment)

        let expected = date(2026, 3, 16)
        #expect(calendar.isDate(payment.nextDueDate, inSameDayAs: expected))
    }

    @Test func advanceToNextDueDate_daily_interval3() {
        let payment = makePayment(
            recurrenceType: "daily",
            recurrenceInterval: 3,
            nextDueDate: date(2026, 3, 10)
        )

        ScheduledPaymentDraftService.advanceToNextDueDate(payment: payment)

        let expected = date(2026, 3, 13)
        #expect(calendar.isDate(payment.nextDueDate, inSameDayAs: expected))
    }

    @Test func advanceToNextDueDate_daily_crossesMonthBoundary() {
        let payment = makePayment(recurrenceType: "daily", nextDueDate: date(2026, 3, 31))

        ScheduledPaymentDraftService.advanceToNextDueDate(payment: payment)

        let expected = date(2026, 4, 1)
        #expect(calendar.isDate(payment.nextDueDate, inSameDayAs: expected))
    }

    // MARK: - Weekly Recurrence

    @Test func advanceToNextDueDate_weekly_advancesByOneWeek() {
        let payment = makePayment(recurrenceType: "weekly", nextDueDate: date(2026, 3, 10))

        ScheduledPaymentDraftService.advanceToNextDueDate(payment: payment)

        let expected = date(2026, 3, 17)
        #expect(calendar.isDate(payment.nextDueDate, inSameDayAs: expected))
    }

    @Test func advanceToNextDueDate_weekly_interval2() {
        let payment = makePayment(
            recurrenceType: "weekly",
            recurrenceInterval: 2,
            nextDueDate: date(2026, 3, 10)
        )

        ScheduledPaymentDraftService.advanceToNextDueDate(payment: payment)

        let expected = date(2026, 3, 24)
        #expect(calendar.isDate(payment.nextDueDate, inSameDayAs: expected))
    }

    // MARK: - Monthly Recurrence

    @Test func advanceToNextDueDate_monthly_advancesByOneMonth() {
        let payment = makePayment(
            recurrenceType: "monthly",
            nextDueDate: date(2026, 3, 15),
            dayOfMonth: 15
        )

        ScheduledPaymentDraftService.advanceToNextDueDate(payment: payment)

        let expected = date(2026, 4, 15)
        #expect(calendar.isDate(payment.nextDueDate, inSameDayAs: expected))
    }

    @Test func advanceToNextDueDate_monthly_dayOfMonth31_clampsToFebruary() {
        let payment = makePayment(
            recurrenceType: "monthly",
            nextDueDate: date(2026, 1, 31),
            dayOfMonth: 31
        )

        ScheduledPaymentDraftService.advanceToNextDueDate(payment: payment)

        // February 2026 has 28 days, so day 31 should clamp to 28
        let expected = date(2026, 2, 28)
        #expect(calendar.isDate(payment.nextDueDate, inSameDayAs: expected))
    }

    @Test func advanceToNextDueDate_monthly_dayOfMonth30_clampsToFebLeapYear() {
        let payment = makePayment(
            recurrenceType: "monthly",
            nextDueDate: date(2028, 1, 30),
            dayOfMonth: 30
        )

        ScheduledPaymentDraftService.advanceToNextDueDate(payment: payment)

        // February 2028 is a leap year, has 29 days, so day 30 clamps to 29
        let expected = date(2028, 2, 29)
        #expect(calendar.isDate(payment.nextDueDate, inSameDayAs: expected))
    }

    @Test func advanceToNextDueDate_monthly_interval3_quarterly() {
        let payment = makePayment(
            recurrenceType: "monthly",
            recurrenceInterval: 3,
            nextDueDate: date(2026, 1, 10),
            dayOfMonth: 10
        )

        ScheduledPaymentDraftService.advanceToNextDueDate(payment: payment)

        let expected = date(2026, 4, 10)
        #expect(calendar.isDate(payment.nextDueDate, inSameDayAs: expected))
    }

    // MARK: - Yearly Recurrence

    @Test func advanceToNextDueDate_yearly_advancesByOneYear() {
        let payment = makePayment(
            recurrenceType: "yearly",
            nextDueDate: date(2026, 6, 15)
        )

        ScheduledPaymentDraftService.advanceToNextDueDate(payment: payment)

        let expected = date(2027, 6, 15)
        #expect(calendar.isDate(payment.nextDueDate, inSameDayAs: expected))
    }

    @Test func advanceToNextDueDate_yearly_interval2() {
        let payment = makePayment(
            recurrenceType: "yearly",
            recurrenceInterval: 2,
            nextDueDate: date(2026, 6, 15)
        )

        ScheduledPaymentDraftService.advanceToNextDueDate(payment: payment)

        let expected = date(2028, 6, 15)
        #expect(calendar.isDate(payment.nextDueDate, inSameDayAs: expected))
    }

    // MARK: - End Date Deactivation

    @Test func advanceToNextDueDate_pastEndDate_deactivatesPayment() {
        let payment = makePayment(
            recurrenceType: "monthly",
            nextDueDate: date(2026, 3, 15),
            dayOfMonth: 15,
            endDate: date(2026, 3, 31)
        )

        ScheduledPaymentDraftService.advanceToNextDueDate(payment: payment)

        // Next due would be April 15, which is past March 31 end date
        #expect(payment.isActive == false)
    }

    @Test func advanceToNextDueDate_beforeEndDate_staysActive() {
        let payment = makePayment(
            recurrenceType: "monthly",
            nextDueDate: date(2026, 3, 15),
            dayOfMonth: 15,
            endDate: date(2026, 12, 31)
        )

        ScheduledPaymentDraftService.advanceToNextDueDate(payment: payment)

        // Next due is April 15, well before Dec 31
        #expect(payment.isActive == true)
        let expected = date(2026, 4, 15)
        #expect(calendar.isDate(payment.nextDueDate, inSameDayAs: expected))
    }

    // MARK: - Invalid Recurrence Type

    @Test func advanceToNextDueDate_invalidRecurrenceType_doesNotChange() {
        let payment = makePayment(
            recurrenceType: "biweekly", // Not a valid RecurrenceType
            nextDueDate: date(2026, 3, 15)
        )
        let originalDate = payment.nextDueDate

        ScheduledPaymentDraftService.advanceToNextDueDate(payment: payment)

        // Should not change since recurrenceType is invalid
        #expect(calendar.isDate(payment.nextDueDate, inSameDayAs: originalDate))
    }

    // MARK: - Monthly without dayOfMonth (uses current day)

    @Test func advanceToNextDueDate_monthly_noDayOfMonth_usesCurrentDay() {
        let payment = makePayment(
            recurrenceType: "monthly",
            nextDueDate: date(2026, 3, 20),
            dayOfMonth: nil
        )

        ScheduledPaymentDraftService.advanceToNextDueDate(payment: payment)

        // Without dayOfMonth, it should use the day from nextDueDate (20th)
        let expected = date(2026, 4, 20)
        #expect(calendar.isDate(payment.nextDueDate, inSameDayAs: expected))
    }
}

/*
Tests generated:
1. test advanceToNextDueDate_oneTimePayment_deactivates - Non-recurring payment deactivates
2. test advanceToNextDueDate_daily_advancesByOneDay - Daily interval 1
3. test advanceToNextDueDate_daily_interval3 - Daily custom interval
4. test advanceToNextDueDate_daily_crossesMonthBoundary - Daily across month boundary
5. test advanceToNextDueDate_weekly_advancesByOneWeek - Weekly interval 1
6. test advanceToNextDueDate_weekly_interval2 - Weekly biweekly
7. test advanceToNextDueDate_monthly_advancesByOneMonth - Monthly standard
8. test advanceToNextDueDate_monthly_dayOfMonth31_clampsToFebruary - Day clamping for short months
9. test advanceToNextDueDate_monthly_dayOfMonth30_clampsToFebLeapYear - Leap year clamping
10. test advanceToNextDueDate_monthly_interval3_quarterly - Quarterly recurrence
11. test advanceToNextDueDate_yearly_advancesByOneYear - Yearly standard
12. test advanceToNextDueDate_yearly_interval2 - Yearly biennial
13. test advanceToNextDueDate_pastEndDate_deactivatesPayment - End date enforcement
14. test advanceToNextDueDate_beforeEndDate_staysActive - End date not yet reached
15. test advanceToNextDueDate_invalidRecurrenceType_doesNotChange - Invalid type guard
16. test advanceToNextDueDate_monthly_noDayOfMonth_usesCurrentDay - Fallback day logic

Cases NOT covered (require ModelContext):
- processDuePayments (full flow with context queries)
- hasPendingDraft (requires InboxDraft fetch)
- hasLinkedTransaction (requires TransactionItem fetch)
- createDraft (private method, tested indirectly through processDuePayments)
- handleDraftApproved (requires context fetch)
- recreateDraftIfNeeded (requires context fetch)
*/
