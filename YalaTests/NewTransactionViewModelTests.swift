//
//  NewTransactionViewModelTests.swift
//  YalaTests
//
//  Unit tests for NewTransactionViewModel - Tier 1: Pure logic (no SwiftData)
//

import Foundation
import Testing

@testable import Yala

struct NewTransactionViewModelTests {

    // MARK: - Numeric Keypad: Basic Input
    // Note: Tests call clearAmount() first because ViewModel initializes with "0.00"
    // and the append logic checks for "0" specifically

    @MainActor
    @Test("Append digit replaces initial zero")
    func appendDigitReplacesZero() async {
        let vm = NewTransactionViewModel()
        vm.clearAmount()  // Sets to "0"
        vm.appendDigit("5")
        #expect(vm.amountString == "5")
    }

    @MainActor
    @Test("Append multiple digits builds number")
    func appendMultipleDigits() async {
        let vm = NewTransactionViewModel()
        vm.clearAmount()
        vm.appendDigit("1")
        vm.appendDigit("2")
        vm.appendDigit("3")
        #expect(vm.amountString == "123")
    }

    @MainActor
    @Test("Append zero to existing number")
    func appendZeroToNumber() async {
        let vm = NewTransactionViewModel()
        vm.clearAmount()
        vm.appendDigit("5")
        vm.appendDigit("0")
        #expect(vm.amountString == "50")
    }

    // MARK: - Numeric Keypad: Decimal Handling

    @MainActor
    @Test("Append decimal point once")
    func appendDecimalOnce() async {
        let vm = NewTransactionViewModel()
        vm.clearAmount()
        vm.appendDigit("1")
        vm.appendDigit(".")
        vm.appendDigit("5")
        #expect(vm.amountString == "1.5")
    }

    @MainActor
    @Test("Prevent multiple decimal points")
    func preventMultipleDecimals() async {
        let vm = NewTransactionViewModel()
        vm.clearAmount()
        vm.appendDigit("1")
        vm.appendDigit(".")
        vm.appendDigit(".")
        vm.appendDigit("5")
        #expect(vm.amountString == "1.5")
    }

    @MainActor
    @Test("Limit decimals to two places")
    func limitDecimalsToTwo() async {
        let vm = NewTransactionViewModel()
        vm.clearAmount()
        vm.appendDigit("1")
        vm.appendDigit(".")
        vm.appendDigit("2")
        vm.appendDigit("3")
        vm.appendDigit("4")  // Should be ignored
        #expect(vm.amountString == "1.23")
    }

    @MainActor
    @Test("Decimal at start adds to zero")
    func decimalAtStart() async {
        let vm = NewTransactionViewModel()
        vm.clearAmount()
        vm.appendDigit(".")
        vm.appendDigit("5")
        #expect(vm.amountString == "0.5")
    }

    // MARK: - Numeric Keypad: Delete

    @MainActor
    @Test("Delete last digit")
    func deleteLastDigit() async {
        let vm = NewTransactionViewModel()
        vm.clearAmount()
        vm.appendDigit("1")
        vm.appendDigit("2")
        vm.deleteLastDigit()
        #expect(vm.amountString == "1")
    }

    @MainActor
    @Test("Delete resets single digit to zero")
    func deleteResetsToZero() async {
        let vm = NewTransactionViewModel()
        vm.clearAmount()
        vm.appendDigit("5")
        vm.deleteLastDigit()
        #expect(vm.amountString == "0")
    }

    @MainActor
    @Test("Delete on zero stays zero")
    func deleteOnZeroStaysZero() async {
        let vm = NewTransactionViewModel()
        vm.clearAmount()
        vm.deleteLastDigit()
        #expect(vm.amountString == "0")
    }

    @MainActor
    @Test("Delete decimal point")
    func deleteDecimalPoint() async {
        let vm = NewTransactionViewModel()
        vm.clearAmount()
        vm.appendDigit("1")
        vm.appendDigit(".")
        vm.deleteLastDigit()
        #expect(vm.amountString == "1")
    }

    // MARK: - Numeric Keypad: Clear

    @MainActor
    @Test("Clear amount resets to zero")
    func clearAmountResetsToZero() async {
        let vm = NewTransactionViewModel()
        vm.appendDigit("1")
        vm.appendDigit("2")
        vm.appendDigit("3")
        vm.clearAmount()
        #expect(vm.amountString == "0")
    }

    // MARK: - Amount Parsing

    @MainActor
    @Test("Amount parses integer correctly")
    func amountParsesInteger() async {
        let vm = NewTransactionViewModel()
        vm.clearAmount()
        vm.appendDigit("1")
        vm.appendDigit("0")
        vm.appendDigit("0")
        #expect(vm.amount == 100.0)
    }

    @MainActor
    @Test("Amount parses decimal correctly")
    func amountParsesDecimal() async {
        let vm = NewTransactionViewModel()
        vm.clearAmount()
        vm.appendDigit("1")
        vm.appendDigit("2")
        vm.appendDigit(".")
        vm.appendDigit("5")
        #expect(vm.amount == 12.5)
    }

    @MainActor
    @Test("Amount parses two decimal places")
    func amountParsesTwoDecimals() async {
        let vm = NewTransactionViewModel()
        vm.clearAmount()
        vm.appendDigit("9")
        vm.appendDigit(".")
        vm.appendDigit("9")
        vm.appendDigit("9")
        #expect(vm.amount == 9.99)
    }

    @MainActor
    @Test("Initial amount is zero")
    func initialAmountIsZero() async {
        let vm = NewTransactionViewModel()
        // Initial is "0.00" which parses to 0.0
        #expect(vm.amount == 0.0)
    }

    // MARK: - Validation: Amount

    @MainActor
    @Test("Amount valid when greater than zero")
    func amountValidWhenGreaterThanZero() async {
        let vm = NewTransactionViewModel()
        vm.clearAmount()
        vm.appendDigit("1")
        #expect(vm.isAmountValid == true)
    }

    @MainActor
    @Test("Amount invalid when zero")
    func amountInvalidWhenZero() async {
        let vm = NewTransactionViewModel()
        #expect(vm.isAmountValid == false)
    }

    @MainActor
    @Test("Amount valid with decimal")
    func amountValidWithDecimal() async {
        let vm = NewTransactionViewModel()
        vm.clearAmount()
        vm.appendDigit("0")
        vm.appendDigit(".")
        vm.appendDigit("0")
        vm.appendDigit("1")
        #expect(vm.isAmountValid == true)
        #expect(vm.amount == 0.01)
    }

    // MARK: - Validation: Account

    @MainActor
    @Test("Account invalid when nil for expense")
    func accountInvalidWhenNilForExpense() async {
        let vm = NewTransactionViewModel()
        vm.transactionType = .expense
        #expect(vm.isAccountValid == false)
    }

    @MainActor
    @Test("Account invalid when nil for income")
    func accountInvalidWhenNilForIncome() async {
        let vm = NewTransactionViewModel()
        vm.transactionType = .income
        #expect(vm.isAccountValid == false)
    }

    @MainActor
    @Test("Transfer invalid when source nil")
    func transferInvalidWhenSourceNil() async {
        let vm = NewTransactionViewModel()
        vm.transactionType = .transfer
        vm.sourceAccount = nil
        #expect(vm.isAccountValid == false)
    }

    @MainActor
    @Test("Transfer invalid when destination nil")
    func transferInvalidWhenDestinationNil() async {
        let vm = NewTransactionViewModel()
        vm.transactionType = .transfer
        vm.destinationAccount = nil
        #expect(vm.isAccountValid == false)
    }

    // MARK: - Validation: Subcategory

    @MainActor
    @Test("Subcategory invalid when nil for expense")
    func subcategoryInvalidWhenNilForExpense() async {
        let vm = NewTransactionViewModel()
        vm.transactionType = .expense
        #expect(vm.isSubcategoryValid == false)
    }

    @MainActor
    @Test("Subcategory optional for transfer")
    func subcategoryOptionalForTransfer() async {
        let vm = NewTransactionViewModel()
        vm.transactionType = .transfer
        vm.selectedSubcategory = nil
        #expect(vm.isSubcategoryValid == true)
    }

    // MARK: - Transaction Type

    @MainActor
    @Test("Default type is expense")
    func defaultTypeIsExpense() async {
        let vm = NewTransactionViewModel()
        #expect(vm.transactionType == .expense)
    }

    @MainActor
    @Test("isTransfer true when transfer type")
    func isTransferTrueWhenTransfer() async {
        let vm = NewTransactionViewModel()
        vm.transactionType = .transfer
        #expect(vm.isTransfer == true)
    }

    @MainActor
    @Test("isTransfer false when expense")
    func isTransferFalseWhenExpense() async {
        let vm = NewTransactionViewModel()
        vm.transactionType = .expense
        #expect(vm.isTransfer == false)
    }

    // MARK: - Exchange Rate

    @MainActor
    @Test("needsExchangeRate false when not transfer")
    func needsExchangeRateFalseWhenNotTransfer() async {
        let vm = NewTransactionViewModel()
        vm.transactionType = .expense
        #expect(vm.needsExchangeRate == false)
    }

    @MainActor
    @Test("needsExchangeRate false when no accounts")
    func needsExchangeRateFalseWhenNoAccounts() async {
        let vm = NewTransactionViewModel()
        vm.transactionType = .transfer
        vm.sourceAccount = nil
        vm.destinationAccount = nil
        #expect(vm.needsExchangeRate == false)
    }

    @MainActor
    @Test("Update exchange rate from destination")
    func updateExchangeRateFromDestination() async {
        let vm = NewTransactionViewModel()
        vm.clearAmount()
        vm.appendDigit("1")
        vm.appendDigit("0")
        vm.appendDigit("0")  // amount = 100
        vm.destinationAmount = 350.0
        vm.updateExchangeRateFromDestination()
        #expect(vm.exchangeRate == 3.5)
        #expect(vm.isExchangeRateManual == true)
    }

    @MainActor
    @Test("Exchange rate unchanged when amount zero")
    func exchangeRateUnchangedWhenAmountZero() async {
        let vm = NewTransactionViewModel()
        let initialRate = vm.exchangeRate
        vm.destinationAmount = 100.0
        vm.updateExchangeRateFromDestination()
        #expect(vm.exchangeRate == initialRate)
    }

    // MARK: - Reset

    @MainActor
    @Test("Reset clears all form state")
    func resetClearsAllState() async {
        let vm = NewTransactionViewModel()

        // Set various state
        vm.appendDigit("1")
        vm.appendDigit("2")
        vm.appendDigit("3")
        vm.transactionType = .income
        vm.note = "Test note"
        vm.exchangeRate = 3.5
        vm.destinationAmount = 100.0
        vm.isExchangeRateManual = true
        vm.showValidationErrors = true

        // Reset
        vm.reset()

        // Verify all cleared
        #expect(vm.amountString == "0")
        #expect(vm.transactionType == .expense)
        #expect(vm.note == "")
        #expect(vm.exchangeRate == 1.0)
        #expect(vm.destinationAmount == 0.0)
        #expect(vm.isExchangeRateManual == false)
        #expect(vm.showValidationErrors == false)
        #expect(vm.selectedAccount == nil)
        #expect(vm.sourceAccount == nil)
        #expect(vm.destinationAccount == nil)
        #expect(vm.selectedSubcategory == nil)
        #expect(vm.selectedTags.isEmpty)
    }

    // MARK: - Edge Cases

    @MainActor
    @Test("Large number input")
    func largeNumberInput() async {
        let vm = NewTransactionViewModel()
        vm.clearAmount()
        for _ in 1...9 {
            vm.appendDigit("9")
        }
        #expect(vm.amount == 999999999.0)
    }

    @MainActor
    @Test("Formatted amount has two decimals")
    func formattedAmountHasTwoDecimals() async {
        let vm = NewTransactionViewModel()
        vm.appendDigit("5")
        // formattedAmount should include decimals
        #expect(vm.formattedAmount.contains(".") || vm.formattedAmount.contains(","))
    }

    // MARK: - Split Calculator

    @MainActor
    @Test("applySplitResult sets all split fields correctly")
    func applySplitResultSetsFields() async {
        let vm = NewTransactionViewModel()
        vm.applySplitResult(amount: 100, splitType: .percentage, totalAmount: 125, myValue: 80, divisor: 100)
        #expect(vm.splitTotalAmount == 125)
        #expect(vm.splitType == .percentage)
        #expect(vm.splitMyValue == 80)
        #expect(vm.splitDivisor == 100)
        #expect(vm.isSplitStale == false)
    }

    @MainActor
    @Test("applySplitResult updates amountString")
    func applySplitResultUpdatesAmount() async {
        let vm = NewTransactionViewModel()
        vm.applySplitResult(amount: 100, splitType: .percentage, totalAmount: 125, myValue: 80, divisor: 100)
        #expect(vm.amountString == "100.00")
    }

    @MainActor
    @Test("clearSplitData clears all split fields")
    func clearSplitDataClearsAll() async {
        let vm = NewTransactionViewModel()
        vm.applySplitResult(amount: 100, splitType: .percentage, totalAmount: 125, myValue: 80, divisor: 100)
        vm.clearSplitData()
        #expect(vm.splitTotalAmount == nil)
        #expect(vm.splitType == nil)
        #expect(vm.splitMyValue == nil)
        #expect(vm.splitDivisor == nil)
        #expect(vm.isSplitStale == false)
    }

    @MainActor
    @Test("hasSplitData returns true when split is set")
    func hasSplitDataTrue() async {
        let vm = NewTransactionViewModel()
        vm.applySplitResult(amount: 100, splitType: .equal, totalAmount: 300, myValue: 3, divisor: 3)
        #expect(vm.hasSplitData == true)
    }

    @MainActor
    @Test("hasSplitData returns false when no split")
    func hasSplitDataFalse() async {
        let vm = NewTransactionViewModel()
        #expect(vm.hasSplitData == false)
    }

    @MainActor
    @Test("splitDescription for percentage type")
    func splitDescriptionPercentage() async {
        let vm = NewTransactionViewModel()
        vm.applySplitResult(amount: 100, splitType: .percentage, totalAmount: 125, myValue: 80, divisor: 100)
        #expect(vm.splitDescription?.contains("80%") == true)
    }

    @MainActor
    @Test("splitDescription for equal type")
    func splitDescriptionEqual() async {
        let vm = NewTransactionViewModel()
        vm.applySplitResult(amount: 40, splitType: .equal, totalAmount: 120, myValue: 3, divisor: 3)
        #expect(vm.splitDescription?.contains("3") == true)
    }

    @MainActor
    @Test("splitDescription for shares type")
    func splitDescriptionShares() async {
        let vm = NewTransactionViewModel()
        vm.applySplitResult(amount: 200, splitType: .shares, totalAmount: 500, myValue: 2, divisor: 5)
        #expect(vm.splitDescription?.contains("2 de 5") == true)
    }

    @MainActor
    @Test("reset clears split data")
    func resetClearsSplitData() async {
        let vm = NewTransactionViewModel()
        vm.applySplitResult(amount: 100, splitType: .percentage, totalAmount: 125, myValue: 80, divisor: 100)
        vm.reset()
        #expect(vm.hasSplitData == false)
        #expect(vm.isSplitStale == false)
    }

    @MainActor
    @Test("isSplitStale can be set manually")
    func splitStaleManualSet() async {
        let vm = NewTransactionViewModel()
        vm.applySplitResult(amount: 100, splitType: .percentage, totalAmount: 125, myValue: 80, divisor: 100)
        vm.isSplitStale = true
        #expect(vm.isSplitStale == true)
    }
}
