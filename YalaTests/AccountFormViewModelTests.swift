//
//  AccountFormViewModelTests.swift
//  YalaTests
//
//  Unit tests for AccountFormViewModel validation logic.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

struct AccountFormViewModelTests {

    // MARK: - isNameValid

    @MainActor @Test func isNameValid_empty_false() {
        let vm = AccountFormViewModel(accountToEdit: nil, existingNames: [])
        vm.name = ""
        #expect(vm.isNameValid == false)
    }

    @MainActor @Test func isNameValid_whitespace_false() {
        let vm = AccountFormViewModel(accountToEdit: nil, existingNames: [])
        vm.name = "   "
        #expect(vm.isNameValid == false)
    }

    @MainActor @Test func isNameValid_withText_true() {
        let vm = AccountFormViewModel(accountToEdit: nil, existingNames: [])
        vm.name = "Mi Cuenta"
        #expect(vm.isNameValid == true)
    }

    // MARK: - isNameUnique

    @MainActor @Test func isNameUnique_noExisting_true() {
        let vm = AccountFormViewModel(accountToEdit: nil, existingNames: [])
        vm.name = "Nueva"
        #expect(vm.isNameUnique == true)
    }

    @MainActor @Test func isNameUnique_duplicate_false() {
        let vm = AccountFormViewModel(accountToEdit: nil, existingNames: ["Banco"])
        vm.name = "Banco"
        #expect(vm.isNameUnique == false)
    }

    @MainActor @Test func isNameUnique_caseInsensitive_false() {
        let vm = AccountFormViewModel(accountToEdit: nil, existingNames: ["Banco"])
        vm.name = "banco"
        #expect(vm.isNameUnique == false)
    }

    @MainActor @Test func isNameUnique_editingSameName_true() {
        let account = Account(name: "Banco", currencyCode: "PEN", colorHex: "#6366F1", iconName: "creditcard.fill", type: "bank")
        let vm = AccountFormViewModel(accountToEdit: account, existingNames: ["Banco"])
        vm.name = "Banco"
        #expect(vm.isNameUnique == true)
    }

    // MARK: - isCurrencyValid

    @MainActor @Test func isCurrencyValid_validCurrency_true() {
        let vm = AccountFormViewModel(accountToEdit: nil, existingNames: [])
        vm.selectedCurrency = .pen
        #expect(vm.isCurrencyValid == true)
    }

    // MARK: - isBalanceValid

    @MainActor @Test func isBalanceValid_newAccount_emptyText_false() {
        let vm = AccountFormViewModel(accountToEdit: nil, existingNames: [])
        vm.balanceText = ""
        #expect(vm.isBalanceValid == false)
    }

    @MainActor @Test func isBalanceValid_newAccount_validText_true() {
        let vm = AccountFormViewModel(accountToEdit: nil, existingNames: [])
        vm.balanceText = "100.50"
        #expect(vm.isBalanceValid == true)
    }

    // MARK: - canSave

    @MainActor @Test func canSave_allValid_true() {
        let vm = AccountFormViewModel(accountToEdit: nil, existingNames: [])
        vm.name = "Cuenta Nueva"
        vm.selectedCurrency = .pen
        vm.balanceText = "0"
        #expect(vm.canSave == true)
    }

    @MainActor @Test func canSave_emptyName_false() {
        let vm = AccountFormViewModel(accountToEdit: nil, existingNames: [])
        vm.name = ""
        vm.balanceText = "100"
        #expect(vm.canSave == false)
    }

    // MARK: - parsedBalanceAmount

    @MainActor @Test func parsedBalanceAmount_positive() {
        let vm = AccountFormViewModel(accountToEdit: nil, existingNames: [])
        vm.isPositive = true
        vm.balanceText = "500"
        #expect(vm.parsedBalanceAmount == 500)
    }

    @MainActor @Test func parsedBalanceAmount_negative() {
        let vm = AccountFormViewModel(accountToEdit: nil, existingNames: [])
        vm.isPositive = false
        vm.balanceText = "500"
        #expect(vm.parsedBalanceAmount == -500)
    }

    // MARK: - needsAdjustment

    @MainActor @Test func needsAdjustment_newAccount_noBalance_false() {
        let vm = AccountFormViewModel(accountToEdit: nil, existingNames: [])
        vm.balanceText = ""
        #expect(vm.needsAdjustment == false)
    }

    // MARK: - Balance Adjustment Scenarios (BUG-13)

    // 2a: byEntry sin input → sin ajuste
    @MainActor @Test func needsAdjustment_editByEntry_noInput_false() {
        let account = Account(name: "Test", currencyCode: "PEN", colorHex: "#6366F1", iconName: "creditcard.fill", type: "bank")
        let vm = AccountFormViewModel(accountToEdit: account, existingNames: [])
        #expect(vm.selectedAdjustmentMode == .byEntry)
        #expect(vm.balanceText.isEmpty)
        #expect(vm.parsedBalanceAmount == nil)
        #expect(vm.needsAdjustment == false)
    }

    // 2b: byEntry con input → necesita ajuste
    @MainActor @Test func needsAdjustment_editByEntry_withInput_true() {
        let account = Account(name: "Test", currencyCode: "PEN", colorHex: "#6366F1", iconName: "creditcard.fill", type: "bank")
        let vm = AccountFormViewModel(accountToEdit: account, existingNames: [])
        vm.balanceText = "500"
        vm.isPositive = true
        // currentBalance is 0 (no transactions), target is 500 → adjustment needed
        #expect(vm.needsAdjustment == true)
        #expect(vm.adjustmentAmount == 500)
    }

    // 2c: changeInitialBalance sin modificar → sin ajuste
    @MainActor @Test func needsAdjustment_editChangeInitial_noModification_false() {
        let account = Account(name: "Test", currencyCode: "PEN", colorHex: "#6366F1", iconName: "creditcard.fill", type: "bank")
        let vm = AccountFormViewModel(accountToEdit: account, existingNames: [])
        vm.selectedAdjustmentMode = .changeInitialBalance
        vm.adjustmentModeChanged()
        // Pre-filled with existingInitialBalance (0.00) → no change → no adjustment
        #expect(vm.needsAdjustment == false)
    }

    // 2d: changeInitialBalance con modificación → necesita ajuste
    @MainActor @Test func needsAdjustment_editChangeInitial_withModification_true() {
        let account = Account(name: "Test", currencyCode: "PEN", colorHex: "#6366F1", iconName: "creditcard.fill", type: "bank")
        let vm = AccountFormViewModel(accountToEdit: account, existingNames: [])
        vm.selectedAdjustmentMode = .changeInitialBalance
        vm.adjustmentModeChanged()
        // Modify to a different value
        vm.balanceText = "1000"
        vm.isPositive = true
        // existingInitialBalance is 0, new is 1000 → adjustment needed
        #expect(vm.needsAdjustment == true)
    }

    // MARK: - Credit Card Fields

    @MainActor @Test func creditCard_defaultValues() {
        let vm = AccountFormViewModel(accountToEdit: nil, existingNames: [])
        #expect(vm.creditCardPaymentReminder == false)
        #expect(vm.creditCardPaymentDay == 1)
    }

    @MainActor @Test func creditCard_loadsFromAccount() {
        let account = Account(name: "Visa", currencyCode: "USD", colorHex: "#FF0080", iconName: "creditcard.fill", type: "Tarjeta de crédito")
        account.creditCardPaymentReminder = true
        account.creditCardPaymentDay = 15
        let vm = AccountFormViewModel(accountToEdit: account, existingNames: [])
        #expect(vm.creditCardPaymentReminder == true)
        #expect(vm.creditCardPaymentDay == 15)
        #expect(vm.selectedType == .creditCard)
    }

    // Cambio de modo: byEntry → changeInitialBalance pre-llena, changeInitialBalance → byEntry limpia
    @MainActor @Test func adjustmentModeChanged_switchModes_correctState() {
        let account = Account(name: "Test", currencyCode: "PEN", colorHex: "#6366F1", iconName: "creditcard.fill", type: "bank")
        let vm = AccountFormViewModel(accountToEdit: account, existingNames: [])
        #expect(vm.balanceText.isEmpty) // byEntry default: empty

        vm.selectedAdjustmentMode = .changeInitialBalance
        vm.adjustmentModeChanged()
        #expect(vm.balanceText == "0.00") // pre-filled

        vm.selectedAdjustmentMode = .byEntry
        vm.adjustmentModeChanged()
        #expect(vm.balanceText.isEmpty) // cleared
        #expect(vm.isPositive == true)
    }
}
