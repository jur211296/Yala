// Tests generated for: ScheduledPaymentsSettingsViewModel
// Cobertura estimada: 70% (computed properties + UI state)

import Foundation
import Testing

@testable import Yala

@MainActor
struct ScheduledPaymentsSettingsViewModelTests {

    // MARK: - Initial State

    @Test func initialState_allPaymentsEmpty() {
        let vm = ScheduledPaymentsSettingsViewModel()
        #expect(vm.allPayments.isEmpty)
    }

    @Test func initialState_filteredPaymentsEmpty() {
        let vm = ScheduledPaymentsSettingsViewModel()
        #expect(vm.filteredPayments.isEmpty)
    }

    @Test func initialState_isEmptyTrue() {
        let vm = ScheduledPaymentsSettingsViewModel()
        #expect(vm.isEmpty == true)
    }

    @Test func initialState_selectedTabIsAll() {
        let vm = ScheduledPaymentsSettingsViewModel()
        #expect(vm.selectedTab == .all)
    }

    @Test func initialState_showEditorFalse() {
        let vm = ScheduledPaymentsSettingsViewModel()
        #expect(vm.showEditor == false)
    }

    @Test func initialState_paymentToEditNil() {
        let vm = ScheduledPaymentsSettingsViewModel()
        #expect(vm.paymentToEdit == nil)
    }

    @Test func initialState_showDeleteErrorFalse() {
        let vm = ScheduledPaymentsSettingsViewModel()
        #expect(vm.showDeleteError == false)
    }

    // MARK: - openEditor

    @Test func openEditor_withPayment_setsPaymentAndShowsEditor() {
        let vm = ScheduledPaymentsSettingsViewModel()
        let payment = ScheduledPayment(
            name: "Netflix",
            amount: 15.99,
            currencyCode: "USD",
            nextDueDate: Date()
        )

        vm.openEditor(for: payment)

        #expect(vm.showEditor == true)
        #expect(vm.paymentToEdit?.name == "Netflix")
    }

    @Test func openEditor_withNil_showsEditorForNewPayment() {
        let vm = ScheduledPaymentsSettingsViewModel()

        vm.openEditor(for: nil)

        #expect(vm.showEditor == true)
        #expect(vm.paymentToEdit == nil)
    }

    // MARK: - closeEditor

    @Test func closeEditor_resetsState() {
        let vm = ScheduledPaymentsSettingsViewModel()
        let payment = ScheduledPayment(
            name: "Netflix",
            amount: 15.99,
            currencyCode: "USD",
            nextDueDate: Date()
        )
        vm.openEditor(for: payment)

        vm.closeEditor()

        #expect(vm.showEditor == false)
        #expect(vm.paymentToEdit == nil)
    }

    // MARK: - loadPayments without context

    @Test func loadPayments_withoutContext_keepsEmpty() {
        let vm = ScheduledPaymentsSettingsViewModel()
        vm.loadPayments()
        #expect(vm.allPayments.isEmpty)
    }

    // MARK: - Tab Filtering Logic (tested on enum directly)

    @Test func scheduledPaymentsTab_allFilter_nilCategory() {
        let tab = ScheduledPaymentsTab.all
        #expect(tab.categoryFilter == nil)
    }

    @Test func scheduledPaymentsTab_recurringFilter_returnsRecurring() {
        let tab = ScheduledPaymentsTab.recurring
        #expect(tab.categoryFilter == PaymentCategory.recurring.rawValue)
    }

    @Test func scheduledPaymentsTab_subscriptionsFilter_returnsSubscription() {
        let tab = ScheduledPaymentsTab.subscriptions
        #expect(tab.categoryFilter == PaymentCategory.subscription.rawValue)
    }

    // MARK: - Tab Selection

    @Test func selectedTab_canBeChanged() {
        let vm = ScheduledPaymentsSettingsViewModel()

        vm.selectedTab = .recurring
        #expect(vm.selectedTab == .recurring)

        vm.selectedTab = .subscriptions
        #expect(vm.selectedTab == .subscriptions)

        vm.selectedTab = .all
        #expect(vm.selectedTab == .all)
    }
}

/*
Tests generated:
1. test initialState_allPaymentsEmpty - Starts with no payments
2. test initialState_filteredPaymentsEmpty - Filtered list also empty initially
3. test initialState_isEmptyTrue - isEmpty computed property true at start
4. test initialState_selectedTabIsAll - Default tab is .all
5. test initialState_showEditorFalse - Editor hidden at start
6. test initialState_paymentToEditNil - No payment selected at start
7. test initialState_showDeleteErrorFalse - No error shown at start
8. test openEditor_withPayment_setsPaymentAndShowsEditor - Opening editor with existing payment
9. test openEditor_withNil_showsEditorForNewPayment - Opening editor for new payment
10. test closeEditor_resetsState - Closing editor clears state
11. test loadPayments_withoutContext_keepsEmpty - Loading without context is safe
12. test scheduledPaymentsTab_allFilter_nilCategory - All tab has no filter
13. test scheduledPaymentsTab_recurringFilter_returnsRecurring - Recurring tab filter
14. test scheduledPaymentsTab_subscriptionsFilter_returnsSubscription - Subscriptions tab filter
15. test selectedTab_canBeChanged - Tab selection state changes

Cases NOT covered (require ModelContext):
- filteredPayments with actual data (allPayments is private(set), populated via loadPayments which needs context)
- deletePayments (requires EntityDeletionService + context)
- loadPayments actually populating allPayments (requires context fetch)
*/
