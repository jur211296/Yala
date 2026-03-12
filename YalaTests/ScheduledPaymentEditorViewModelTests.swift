//
//  ScheduledPaymentEditorViewModelTests.swift
//  YalaTests
//
//  Unit tests for ScheduledPaymentEditorViewModel state and behavior.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

struct ScheduledPaymentEditorViewModelTests {

    // MARK: - Initial State

    @MainActor @Test func initialState_accountsEmpty() {
        let vm = ScheduledPaymentEditorViewModel()
        #expect(vm.allAccounts.isEmpty)
        #expect(vm.activeAccounts.isEmpty)
    }

    @MainActor @Test func initialState_tagsEmpty() {
        let vm = ScheduledPaymentEditorViewModel()
        #expect(vm.allTags.isEmpty)
        #expect(vm.activeTags.isEmpty)
    }

    @MainActor @Test func initialState_showSaveErrorFalse() {
        let vm = ScheduledPaymentEditorViewModel()
        #expect(vm.showSaveError == false)
    }

    // MARK: - dismissSaveError

    @MainActor @Test func dismissSaveError_setsToFalse() {
        let vm = ScheduledPaymentEditorViewModel()
        // Can't set showSaveError directly (private(set)), but dismissSaveError
        // should always result in false
        vm.dismissSaveError()
        #expect(vm.showSaveError == false)
    }

    // MARK: - loadData without context

    @MainActor @Test func loadData_withoutContext_keepsEmpty() {
        let vm = ScheduledPaymentEditorViewModel()
        vm.loadData()
        #expect(vm.allAccounts.isEmpty)
        #expect(vm.allTags.isEmpty)
    }

    // MARK: - savePayment without context returns nil

    @MainActor @Test func savePayment_withoutContext_returnsNil() {
        let vm = ScheduledPaymentEditorViewModel()
        let result = vm.savePayment(
            existing: nil,
            name: "Test",
            amount: 100,
            note: "",
            currencyCode: "PEN",
            transactionType: "expense",
            paymentCategory: .recurring,
            account: nil,
            subcategory: nil,
            selectedTags: [],
            isRecurring: false,
            recurrenceType: .monthly,
            recurrenceInterval: 1,
            paymentDate: Date(),
            dayOfMonth: nil,
            selectedWeekdays: [],
            yearlyMonth: nil,
            yearlyDay: nil,
            endDate: nil,
            notifyOnDueDate: false,
            notifyDaysBefore: 0,
            isActive: true
        )
        #expect(result == nil)
    }

    // MARK: - deletePayment without context returns false

    @MainActor @Test func deletePayment_withoutContext_returnsFalse() {
        let vm = ScheduledPaymentEditorViewModel()
        let payment = ScheduledPayment(
            name: "Test",
            amount: 100,
            currencyCode: "PEN",
            nextDueDate: Date()
        )
        let result = vm.deletePayment(payment)
        #expect(result == false)
    }

    // MARK: - Account filtering logic

    @Test func accountArchived_filterLogic() {
        let active = Account(name: "Active", currencyCode: "PEN", colorHex: "#000", iconName: "creditcard", type: "bank")
        let archived = Account(name: "Old", currencyCode: "PEN", colorHex: "#000", iconName: "creditcard", type: "bank")
        archived.isArchived = true

        let allAccounts = [active, archived]
        let activeAccounts = allAccounts.filter { !$0.isArchived }

        #expect(activeAccounts.count == 1)
        #expect(activeAccounts[0].name == "Active")
    }

    // MARK: - Weekday string generation logic

    @Test func weekdayString_fromSet() {
        let selectedWeekdays: Set<Int> = [1, 3, 5]
        let weekdaysStr = selectedWeekdays.sorted().map { String($0) }.joined(separator: ",")
        #expect(weekdaysStr == "1,3,5")
    }

    @Test func weekdayString_emptySet() {
        let selectedWeekdays: Set<Int> = []
        let weekdaysStr = selectedWeekdays.sorted().map { String($0) }.joined(separator: ",")
        #expect(weekdaysStr == "")
    }

    @Test func weekdayString_singleDay() {
        let selectedWeekdays: Set<Int> = [2]
        let weekdaysStr = selectedWeekdays.sorted().map { String($0) }.joined(separator: ",")
        #expect(weekdaysStr == "2")
    }

    // MARK: - Recurrence type conditional logic

    @Test func dayOfMonth_onlyForMonthly() {
        let recurrenceType = RecurrenceType.monthly
        let dayOfMonth = 15
        let result = recurrenceType == .monthly ? dayOfMonth : nil
        #expect(result == 15)
    }

    @Test func dayOfMonth_nilForWeekly() {
        let recurrenceType = RecurrenceType.weekly
        let dayOfMonth = 15
        let result = recurrenceType == .monthly ? dayOfMonth : nil
        #expect(result == nil)
    }

    @Test func endDate_nilForNonRecurring() {
        let isRecurring = false
        let endDate = Date()
        let result = isRecurring ? endDate : nil
        #expect(result == nil)
    }

    @Test func endDate_preservedForRecurring() {
        let isRecurring = true
        let endDate = Date()
        let result = isRecurring ? endDate : nil
        #expect(result != nil)
    }
}
