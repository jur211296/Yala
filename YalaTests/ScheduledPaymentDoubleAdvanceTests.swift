//
//  ScheduledPaymentDoubleAdvanceTests.swift
//  YalaTests
//
//  Regression coverage for the "advance payment then approve" double-advance bug.
//
//  Bug: the early-pay flow (createAdvancedDraft) used to set lastPaidDate +
//  advanceToNextDueDate immediately, and handleDraftApproved advanced AGAIN on
//  approval — two advances for a single early-paid occurrence, skipping a whole
//  period. The fix makes createAdvancedDraft NOT advance; the advance happens
//  exactly ONCE at approval (handleDraftApproved -> advanceToNextDueDate).
//
//  createAdvancedDraft / handleDraftApproved require a ModelContext (fetch +
//  insert), so they are out of scope for pure-logic tests (project rule R8).
//  These tests pin the observable contract on the pure mutation seam
//  `advanceToNextDueDate(payment:)`: a single advance lands on the correct next
//  occurrence, and the absence of a pre-advance means no occurrence is skipped.
//  A double advance is exercised explicitly to document the harm the fix prevents.
//

import Foundation
import Testing

@testable import Yala

@MainActor
struct ScheduledPaymentDoubleAdvanceTests {

    // MARK: - Helpers

    private let calendar = Calendar.current

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func makeMonthlyPayment(
        nextDueDate: Date,
        dayOfMonth: Int? = nil,
        interval: Int = 1
    ) -> ScheduledPayment {
        ScheduledPayment(
            name: "Netflix",
            amount: 30,
            currencyCode: "USD",
            transactionType: "expense",
            isRecurring: true,
            recurrenceType: "monthly",
            recurrenceInterval: interval,
            nextDueDate: nextDueDate,
            dayOfMonth: dayOfMonth,
            paymentCategory: "subscription",
            isActive: true
        )
    }

    // MARK: - Correct (post-fix) behavior: advance fires exactly once

    /// The advance happens exactly once at approval. A monthly payment due Mar 15
    /// must land on Apr 15 — NOT skip to May.
    @Test func singleAdvance_monthly_landsOnNextOccurrence_notSkipped() {
        let payment = makeMonthlyPayment(nextDueDate: date(2026, 3, 15), dayOfMonth: 15)

        // The whole early-pay -> approve flow results in ONE advance.
        ScheduledPaymentDraftService.advanceToNextDueDate(payment: payment)

        let aprilOccurrence = date(2026, 4, 15)
        let mayOccurrence = date(2026, 5, 15)
        #expect(calendar.isDate(payment.nextDueDate, inSameDayAs: aprilOccurrence))
        #expect(!calendar.isDate(payment.nextDueDate, inSameDayAs: mayOccurrence))
    }

    // MARK: - Bug reproduction: two advances skip a whole occurrence

    /// Documents the harm the fix prevents: if the advance fired twice (immediate
    /// in createAdvancedDraft + again in handleDraftApproved), a Mar 15 monthly
    /// payment would jump to May 15, skipping the entire April occurrence.
    @Test func doubleAdvance_monthly_skipsAnEntireOccurrence() {
        let payment = makeMonthlyPayment(nextDueDate: date(2026, 3, 15), dayOfMonth: 15)

        // Simulate the pre-fix double-advance.
        ScheduledPaymentDraftService.advanceToNextDueDate(payment: payment)
        ScheduledPaymentDraftService.advanceToNextDueDate(payment: payment)

        let aprilOccurrence = date(2026, 4, 15)
        let mayOccurrence = date(2026, 5, 15)
        // Proof of the bug: the intermediate April occurrence is lost.
        #expect(!calendar.isDate(payment.nextDueDate, inSameDayAs: aprilOccurrence))
        #expect(calendar.isDate(payment.nextDueDate, inSameDayAs: mayOccurrence))
    }

    // MARK: - Edge case: createAdvancedDraft must NOT pre-set lastPaidDate

    /// The fix removed the immediate `lastPaidDate = .now` from createAdvancedDraft.
    /// Until approval, an early-paid payment keeps its prior paid state. Here a
    /// freshly built payment has never been paid; advancing the date alone must
    /// not invent a lastPaidDate.
    @Test func advance_doesNotFabricateLastPaidDate() {
        let payment = makeMonthlyPayment(nextDueDate: date(2026, 3, 15), dayOfMonth: 15)
        #expect(payment.lastPaidDate == nil)

        ScheduledPaymentDraftService.advanceToNextDueDate(payment: payment)

        // advanceToNextDueDate only moves the due date; it must never touch lastPaidDate.
        #expect(payment.lastPaidDate == nil)
    }

    // MARK: - Edge case: month-end clamping survives a single advance

    /// A Jan 31 monthly payment advanced once must clamp to Feb 28 (2026 non-leap),
    /// and a double advance would skip that February occurrence entirely (-> Mar 31).
    @Test func singleVsDoubleAdvance_monthEndClamping() {
        let single = makeMonthlyPayment(nextDueDate: date(2026, 1, 31), dayOfMonth: 31)
        ScheduledPaymentDraftService.advanceToNextDueDate(payment: single)
        #expect(calendar.isDate(single.nextDueDate, inSameDayAs: date(2026, 2, 28)))

        let double = makeMonthlyPayment(nextDueDate: date(2026, 1, 31), dayOfMonth: 31)
        ScheduledPaymentDraftService.advanceToNextDueDate(payment: double)
        ScheduledPaymentDraftService.advanceToNextDueDate(payment: double)
        // Skipped February — the bug.
        #expect(!calendar.isDate(double.nextDueDate, inSameDayAs: date(2026, 2, 28)))
        #expect(calendar.isDate(double.nextDueDate, inSameDayAs: date(2026, 3, 31)))
    }
}
