//
//  ScheduledPaymentsViewModelTests.swift
//  YalaTests
//
//  Unit tests for ScheduledPaymentsViewModel pure logic.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

struct ScheduledPaymentsViewModelTests {

    // MARK: - Helpers

    private func makeSummary(
        isPaid: Bool = false,
        isSkipped: Bool = false,
        paidAmount: Double? = nil,
        paidCurrencyCode: String? = nil
    ) -> ScheduledPaymentSummary {
        let now = Date()
        let payment = ScheduledPayment(
            name: "Test",
            amount: 100,
            currencyCode: "USD",
            transactionType: "expense",
            nextDueDate: now
        )
        var summary = ScheduledPaymentSummary(
            payment: payment,
            dueDate: now,
            dueStatus: .upcoming,
            daysUntilDue: 5,
            icon: "creditcard",
            color: "#000000"
        )
        summary.isPaidForMonth = isPaid
        summary.isSkippedForMonth = isSkipped
        summary.paidAmount = paidAmount
        summary.paidCurrencyCode = paidCurrencyCode
        return summary
    }

    // MARK: - monthYearLabel

    @MainActor @Test func monthYearLabel_currentMonth() {
        let vm = ScheduledPaymentsViewModel()
        vm.selectedMonth = Date()
        #expect(vm.monthYearLabel == L10n.Period.thisMonth)
    }

    @MainActor @Test func monthYearLabel_lastMonth() {
        let vm = ScheduledPaymentsViewModel()
        vm.selectedMonth = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
        #expect(vm.monthYearLabel == L10n.Period.lastMonth)
    }

    @MainActor @Test func monthYearLabel_nextMonth() {
        let vm = ScheduledPaymentsViewModel()
        vm.selectedMonth = Calendar.current.date(byAdding: .month, value: 1, to: Date())!
        #expect(vm.monthYearLabel == L10n.Period.nextMonth)
    }

    @MainActor @Test func monthYearLabel_distantMonth() {
        let vm = ScheduledPaymentsViewModel()
        vm.selectedMonth = Calendar.current.date(byAdding: .month, value: 6, to: Date())!
        let label = vm.monthYearLabel
        #expect(!label.isEmpty)
        #expect(label != L10n.Period.thisMonth)
        #expect(label != L10n.Period.lastMonth)
        #expect(label != L10n.Period.nextMonth)
    }

    // MARK: - previousMonth / nextMonth

    @MainActor @Test func previousMonth_decrementsMonth() {
        let vm = ScheduledPaymentsViewModel()
        let original = vm.selectedMonth
        vm.previousMonth()

        let diff = Calendar.current.dateComponents([.month], from: vm.selectedMonth, to: original)
        #expect(diff.month == 1)
    }

    @MainActor @Test func nextMonth_incrementsMonth() {
        let vm = ScheduledPaymentsViewModel()
        let original = vm.selectedMonth
        vm.nextMonth()

        let diff = Calendar.current.dateComponents([.month], from: original, to: vm.selectedMonth)
        #expect(diff.month == 1)
    }

    // MARK: - filteredGroupedPayments

    @MainActor @Test func filteredGrouped_allFilter_returnsAll() {
        let vm = ScheduledPaymentsViewModel()
        let paid = makeSummary(isPaid: true)
        let pending = makeSummary(isPaid: false)
        vm.groupedPayments = [
            (status: .upcoming, payments: [paid, pending])
        ]
        vm.paymentStatusFilter = .all

        let result = vm.filteredGroupedPayments
        #expect(result.count == 1)
        #expect(result[0].payments.count == 2)
    }

    @MainActor @Test func filteredGrouped_paidFilter_onlyPaid() {
        let vm = ScheduledPaymentsViewModel()
        let paid = makeSummary(isPaid: true)
        let pending = makeSummary(isPaid: false)
        vm.groupedPayments = [
            (status: .upcoming, payments: [paid, pending])
        ]
        vm.paymentStatusFilter = .paid

        let result = vm.filteredGroupedPayments
        #expect(result.count == 1)
        #expect(result[0].payments.count == 1)
    }

    @MainActor @Test func filteredGrouped_pendingFilter() {
        let vm = ScheduledPaymentsViewModel()
        let paid = makeSummary(isPaid: true)
        let pending = makeSummary(isPaid: false, isSkipped: false)
        let skipped = makeSummary(isPaid: false, isSkipped: true)
        vm.groupedPayments = [
            (status: .upcoming, payments: [paid, pending, skipped])
        ]
        vm.paymentStatusFilter = .pending

        let result = vm.filteredGroupedPayments
        #expect(result.count == 1)
        #expect(result[0].payments.count == 1)
    }

    @MainActor @Test func filteredGrouped_emptySectionRemoved() {
        let vm = ScheduledPaymentsViewModel()
        let paid = makeSummary(isPaid: true)
        vm.groupedPayments = [
            (status: .past, payments: [paid]),
            (status: .upcoming, payments: [paid])
        ]
        vm.paymentStatusFilter = .pending

        let result = vm.filteredGroupedPayments
        #expect(result.isEmpty)
    }

    // MARK: - displayAmount / displayCurrencyCode

    @Test func displayAmount_whenPaid_returnsRealAmount() {
        let summary = makeSummary(isPaid: true, paidAmount: 80)
        #expect(summary.displayAmount == 80)
    }

    @Test func displayAmount_whenPending_returnsPaymentAmount() {
        let summary = makeSummary(isPaid: false)
        #expect(summary.displayAmount == 100) // payment.amount
    }

    @Test func displayCurrencyCode_whenPaid_returnsRealCurrency() {
        let summary = makeSummary(isPaid: true, paidAmount: 80, paidCurrencyCode: "EUR")
        #expect(summary.displayCurrencyCode == "EUR")
    }

    @Test func displayCurrencyCode_whenPending_returnsPaymentCurrency() {
        let summary = makeSummary(isPaid: false)
        #expect(summary.displayCurrencyCode == "USD") // payment.currencyCode
    }
}
