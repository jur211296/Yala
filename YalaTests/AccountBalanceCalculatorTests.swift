//
//  AccountBalanceCalculatorTests.swift
//  YalaTests
//
//  Unit tests for AccountBalanceCalculator.
//  Models created without ModelContext to avoid CloudKit race crashes.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

struct AccountBalanceCalculatorTests {

    /// Create a TransactionItem without ModelContext
    private func makePlainTransaction(amount: Double, account: Account? = nil) -> TransactionItem {
        TransactionItem(date: Date(), amount: amount, currencyCode: "PEN", account: account)
    }

    @Test func currentBalance_singleIncome() {
        let txn = makePlainTransaction(amount: 500)
        let result = AccountBalanceCalculator.currentBalance(transactions: [txn])
        #expect(result == 500)
    }

    @Test func currentBalance_singleExpense() {
        let txn = makePlainTransaction(amount: -200)
        let result = AccountBalanceCalculator.currentBalance(transactions: [txn])
        #expect(result == -200)
    }

    @Test func currentBalance_mixed() {
        let t1 = makePlainTransaction(amount: 1000)
        let t2 = makePlainTransaction(amount: -300)
        let result = AccountBalanceCalculator.currentBalance(transactions: [t1, t2])
        #expect(result == 700)
    }

    @Test func currentBalance_empty() {
        let result = AccountBalanceCalculator.currentBalance(transactions: [])
        #expect(result == 0)
    }

    @Test func batchCalculateBalances_multipleAccounts() {
        let acc1 = Account(name: "Cuenta 1", currencyCode: "PEN", colorHex: "#000", iconName: "creditcard", type: "bank")
        let acc2 = Account(name: "Cuenta 2", currencyCode: "PEN", colorHex: "#000", iconName: "creditcard", type: "bank")
        let t1 = makePlainTransaction(amount: 500, account: acc1)
        let t2 = makePlainTransaction(amount: -100, account: acc2)
        let result = AccountBalanceCalculator.batchCalculateBalances(accounts: [acc1, acc2], transactions: [t1, t2])
        #expect(result[acc1.persistentModelID] == 500)
        #expect(result[acc2.persistentModelID] == -100)
    }

    @Test func batchCalculateBalances_ignoresUnrelatedAccounts() {
        let acc1 = Account(name: "Incluida", currencyCode: "PEN", colorHex: "#000", iconName: "creditcard", type: "bank")
        let acc2 = Account(name: "No Incluida", currencyCode: "PEN", colorHex: "#000", iconName: "creditcard", type: "bank")
        let txn = makePlainTransaction(amount: 300, account: acc2)
        // Only ask for acc1's balance
        let result = AccountBalanceCalculator.batchCalculateBalances(accounts: [acc1], transactions: [txn])
        #expect(result[acc1.persistentModelID] == 0)
    }

    @Test func currentBalance_forAccount_filtersByPersistentID_notModelEquality() {
        // Two different accounts with identical field values should NEVER share balances.
        // This guards against any Equatable/Hashable semantics that could compare by fields.
        let acc1 = Account(name: "Duplicada", currencyCode: "PEN", colorHex: "#000", iconName: "creditcard", type: "bank")
        let acc2 = Account(name: "Duplicada", currencyCode: "PEN", colorHex: "#000", iconName: "creditcard", type: "bank")

        let txn = makePlainTransaction(amount: 70, account: acc1)
        let all = [txn]

        #expect(AccountBalanceCalculator.currentBalance(for: acc1, allTransactions: all) == 70)
        #expect(AccountBalanceCalculator.currentBalance(for: acc2, allTransactions: all) == 0)
    }
}
