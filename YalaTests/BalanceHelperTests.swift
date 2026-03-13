//
//  BalanceHelperTests.swift
//  YalaTests
//
//  Unit tests for BalanceHelper static methods.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

struct BalanceHelperTests {

    // MARK: - Helpers

    private let calendar = Calendar.current

    private func makeAccount(
        name: String = "Main",
        currencyCode: String = "USD",
        excludeFromStatistics: Bool = false
    ) -> Account {
        let account = Account(
            name: name,
            currencyCode: currencyCode,
            colorHex: "#6366F1",
            iconName: "creditcard",
            type: "bank",
            excludeFromStatistics: excludeFromStatistics
        )
        return account
    }

    private func makeCategory(name: String, isIncome: Bool = false) -> YalaCategory {
        YalaCategory(name: name, colorHex: "#FF0000", isIncome: isIncome)
    }

    private func makeTransaction(
        amount: Double,
        date: Date = Date(),
        currencyCode: String = "USD",
        account: Account? = nil,
        category: YalaCategory? = nil
    ) -> TransactionItem {
        let tx = TransactionItem(
            date: date,
            amount: amount,
            currencyCode: currencyCode,
            note: "",
            category: category,
            account: account,
            tags: [],
            amountInPreferredCurrency: amount
        )
        tx.preferredCurrencyCode = "USD"
        return tx
    }

    // MARK: - totalBalance Tests

    @Test func totalBalance_emptyTransactions_returnsZero() {
        let account = makeAccount()
        let result = BalanceHelper.totalBalance(
            accounts: [account],
            transactions: [],
            preferredCurrencyCode: "USD",
            converter: MockCurrencyConverter()
        )

        #expect(result == 0)
    }

    @Test func totalBalance_singleTransaction_correctBalance() {
        let account = makeAccount()
        let tx = makeTransaction(amount: -100, account: account)

        let result = BalanceHelper.totalBalance(
            accounts: [account],
            transactions: [tx],
            preferredCurrencyCode: "USD",
            converter: MockCurrencyConverter()
        )

        #expect(result == -100)
    }

    @Test func totalBalance_excludedAccount_notCounted() {
        let includedAccount = makeAccount(name: "Included")
        let excludedAccount = makeAccount(name: "Excluded", excludeFromStatistics: true)
        let tx1 = makeTransaction(amount: -100, account: includedAccount)
        let tx2 = makeTransaction(amount: -500, account: excludedAccount)

        let result = BalanceHelper.totalBalance(
            accounts: [includedAccount, excludedAccount],
            transactions: [tx1, tx2],
            preferredCurrencyCode: "USD",
            converter: MockCurrencyConverter()
        )

        #expect(result == -100)
    }

    // MARK: - displayedBalance Tests

    @Test func displayedBalance_withSelectedAccountID_onlyThatAccount() {
        let account1 = makeAccount(name: "Account1")
        let account2 = makeAccount(name: "Account2")
        let tx1 = makeTransaction(amount: -100, account: account1)
        let tx2 = makeTransaction(amount: -300, account: account2)

        let result = BalanceHelper.displayedBalance(
            accounts: [account1, account2],
            transactions: [tx1, tx2],
            selectedAccountID: account1.persistentModelID,
            preferredCurrencyCode: "USD",
            converter: MockCurrencyConverter()
        )

        #expect(result == -100)
    }

    @Test func displayedBalance_nilSelectedAccountID_returnsTotal() {
        let account = makeAccount()
        let tx = makeTransaction(amount: -100, account: account)

        let result = BalanceHelper.displayedBalance(
            accounts: [account],
            transactions: [tx],
            selectedAccountID: nil,
            preferredCurrencyCode: "USD",
            converter: MockCurrencyConverter()
        )

        #expect(result == -100)
    }

    @Test func totalBalance_multiCurrency_conversionApplied() {
        let account = makeAccount(currencyCode: "EUR")
        let tx = makeTransaction(amount: -50, currencyCode: "EUR", account: account)
        tx.preferredCurrencyCode = "EUR" // Different from target "USD"

        var converter = MockCurrencyConverter()
        converter.fixedRate = 2.0

        let result = BalanceHelper.totalBalance(
            accounts: [account],
            transactions: [tx],
            preferredCurrencyCode: "USD",
            converter: converter
        )

        #expect(result == -100) // 50 * 2.0 (negative)
    }

    // MARK: - initialBalanceForTrend Tests

    @Test func initialBalanceForTrend_onlyCountsBeforeDate() {
        let account = makeAccount()
        let cat = makeCategory(name: "Food")
        let incomeCat = makeCategory(name: "Salary", isIncome: true)
        let beforeDate = calendar.date(from: DateComponents(year: 2026, month: 3, day: 10))!
        let earlyDate = calendar.date(from: DateComponents(year: 2026, month: 3, day: 5))!
        let lateDate = calendar.date(from: DateComponents(year: 2026, month: 3, day: 15))!

        let txBefore = makeTransaction(amount: 500, date: earlyDate, account: account, category: incomeCat)
        let txAfter = makeTransaction(amount: -200, date: lateDate, account: account, category: cat)

        let result = BalanceHelper.initialBalanceForTrend(
            accounts: [account],
            transactions: [txBefore, txAfter],
            before: beforeDate,
            preferredCurrency: .usd,
            converter: MockCurrencyConverter()
        )

        // Only txBefore (income: +500) should be counted, txAfter is after the date
        #expect(result == 500)
    }

    @Test func initialBalanceForTrend_withCategoryFilter_onlyMatchingCategory() {
        let account = makeAccount()
        let catFood = makeCategory(name: "Food")
        let catTransport = makeCategory(name: "Transport")
        let date = calendar.date(from: DateComponents(year: 2026, month: 3, day: 1))!
        let beforeDate = calendar.date(from: DateComponents(year: 2026, month: 3, day: 10))!

        let txFood = makeTransaction(amount: -100, date: date, account: account, category: catFood)
        let txTransport = makeTransaction(amount: -200, date: date, account: account, category: catTransport)

        let result = BalanceHelper.initialBalanceForTrend(
            accounts: [account],
            transactions: [txFood, txTransport],
            before: beforeDate,
            preferredCurrency: .usd,
            categoryFilter: catFood.persistentModelID,
            converter: MockCurrencyConverter()
        )

        // Only Food (-100) should be counted, Transport excluded by filter
        #expect(result == -100)
    }
}

/*
Tests generated:
1. totalBalance_emptyTransactions_returnsZero - Empty transactions produce zero balance
2. totalBalance_singleTransaction_correctBalance - Single transaction reflected in balance
3. totalBalance_excludedAccount_notCounted - Excluded accounts are filtered out
4. displayedBalance_withSelectedAccountID_onlyThatAccount - Selected account filters transactions
5. displayedBalance_nilSelectedAccountID_returnsTotal - Nil selection falls back to total balance
6. totalBalance_multiCurrency_conversionApplied - Currency conversion with fixedRate 2.0
7. initialBalanceForTrend_onlyCountsBeforeDate - Only transactions before date are counted
8. initialBalanceForTrend_withCategoryFilter_onlyMatchingCategory - Category filter limits results

Cases NOT covered (require more context):
- Transactions with no account (filtered out by guard in the method)
- Mixed income/expense in initialBalanceForTrend (income adds, expense subtracts)
*/
