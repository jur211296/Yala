//
//  InitialBalanceServiceTests.swift
//  YalaTests
//
//  Unit tests for InitialBalanceService pure static logic (balance calculation, date computation).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

struct InitialBalanceServiceTests {

    // MARK: - Helpers

    private func makeAccount(name: String = "Test", currencyCode: String = "PEN") -> Account {
        Account(
            name: name,
            currencyCode: currencyCode,
            colorHex: "#000000",
            iconName: "creditcard",
            type: "bank"
        )
    }

    private func makeTransaction(
        amount: Double,
        date: Date = Date(),
        account: Account? = nil,
        balanceAdjustmentType: String? = nil
    ) -> TransactionItem {
        let tx = TransactionItem(
            date: date,
            amount: amount,
            currencyCode: "PEN",
            note: nil
        )
        tx.account = account
        tx.balanceAdjustmentType = balanceAdjustmentType
        return tx
    }

    // MARK: - Type Constants

    @Test func typeConstants() {
        #expect(InitialBalanceService.typeInitialBalance == "initial_balance")
        #expect(InitialBalanceService.typeAdjustment == "adjustment")
    }

    // MARK: - currentBalance

    @MainActor @Test func currentBalance_emptyTransactions() {
        let account = makeAccount()
        let result = InitialBalanceService.currentBalance(for: account, allTransactions: [])
        #expect(result == 0.0)
    }

    @MainActor @Test func currentBalance_sumsAmounts() {
        let account = makeAccount()
        let tx1 = makeTransaction(amount: 100, account: account)
        let tx2 = makeTransaction(amount: -30, account: account)
        let tx3 = makeTransaction(amount: 50, account: account)

        let result = InitialBalanceService.currentBalance(
            for: account, allTransactions: [tx1, tx2, tx3]
        )
        #expect(result == 120.0)
    }

    @MainActor @Test func currentBalance_filtersOtherAccounts() {
        let myAccount = makeAccount(name: "Mine")
        let otherAccount = makeAccount(name: "Other")
        let tx1 = makeTransaction(amount: 100, account: myAccount)
        let tx2 = makeTransaction(amount: 500, account: otherAccount)

        let result = InitialBalanceService.currentBalance(
            for: myAccount, allTransactions: [tx1, tx2]
        )
        #expect(result == 100.0)
    }

    @MainActor @Test func currentBalance_includesAdjustments() {
        let account = makeAccount()
        let tx1 = makeTransaction(amount: 1000, account: account, balanceAdjustmentType: "initial_balance")
        let tx2 = makeTransaction(amount: -50, account: account)

        let result = InitialBalanceService.currentBalance(
            for: account, allTransactions: [tx1, tx2]
        )
        #expect(result == 950.0)
    }

    // MARK: - calculateInitialBalanceDate

    @MainActor @Test func calculateInitialBalanceDate_noTransactions_returnsFirstOfCurrentMonth() {
        let account = makeAccount()
        let result = InitialBalanceService.calculateInitialBalanceDate(
            for: account, allTransactions: []
        )

        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: result)
        #expect(components.day == 1)
    }

    @MainActor @Test func calculateInitialBalanceDate_usesEarliestTransaction() {
        let account = makeAccount()
        let calendar = Calendar.current

        let earlyDate = calendar.date(from: DateComponents(year: 2025, month: 3, day: 15))!
        let lateDate = calendar.date(from: DateComponents(year: 2025, month: 6, day: 20))!

        let tx1 = makeTransaction(amount: -50, date: lateDate, account: account)
        let tx2 = makeTransaction(amount: -30, date: earlyDate, account: account)

        let result = InitialBalanceService.calculateInitialBalanceDate(
            for: account, allTransactions: [tx1, tx2]
        )

        let resultComponents = calendar.dateComponents([.year, .month, .day], from: result)
        #expect(resultComponents.year == 2025)
        #expect(resultComponents.month == 3)
        #expect(resultComponents.day == 1)
    }

    @MainActor @Test func calculateInitialBalanceDate_ignoresAdjustmentTransactions() {
        let account = makeAccount()
        let calendar = Calendar.current

        let adjustmentDate = calendar.date(from: DateComponents(year: 2024, month: 1, day: 1))!
        let realDate = calendar.date(from: DateComponents(year: 2025, month: 5, day: 10))!

        let adjustmentTx = makeTransaction(
            amount: 1000, date: adjustmentDate, account: account,
            balanceAdjustmentType: "initial_balance"
        )
        let realTx = makeTransaction(amount: -50, date: realDate, account: account)

        let result = InitialBalanceService.calculateInitialBalanceDate(
            for: account, allTransactions: [adjustmentTx, realTx]
        )

        let resultComponents = calendar.dateComponents([.year, .month, .day], from: result)
        #expect(resultComponents.year == 2025)
        #expect(resultComponents.month == 5)
        #expect(resultComponents.day == 1)
    }

    @MainActor @Test func calculateInitialBalanceDate_ignoresOtherAccountTransactions() {
        let myAccount = makeAccount(name: "Mine")
        let otherAccount = makeAccount(name: "Other")
        let calendar = Calendar.current

        let earlyDate = calendar.date(from: DateComponents(year: 2024, month: 2, day: 5))!
        let lateDate = calendar.date(from: DateComponents(year: 2025, month: 8, day: 15))!

        let otherTx = makeTransaction(amount: -100, date: earlyDate, account: otherAccount)
        let myTx = makeTransaction(amount: -50, date: lateDate, account: myAccount)

        let result = InitialBalanceService.calculateInitialBalanceDate(
            for: myAccount, allTransactions: [otherTx, myTx]
        )

        let resultComponents = calendar.dateComponents([.year, .month, .day], from: result)
        #expect(resultComponents.year == 2025)
        #expect(resultComponents.month == 8)
        #expect(resultComponents.day == 1)
    }
}
