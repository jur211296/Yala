//
//  TransactionClassificationLogicTests.swift
//  YalaTests
//
//  Unit tests para la regla canónica de clasificación income/expense.
//  Instancia @Model directos sin ModelContext (evita flake R8).
//

import Foundation
import Testing

@testable import Yala

struct TransactionClassificationLogicTests {

    // MARK: - Helpers

    private func makeCategory(isIncome: Bool) -> YalaCategory {
        YalaCategory(name: isIncome ? "Salario" : "Comida", colorHex: "#000000", isIncome: isIncome)
    }

    private func makeTransaction(
        amountInPreferredCurrency: Double,
        category: YalaCategory?
    ) -> TransactionItem {
        let tx = TransactionItem(
            date: Date(timeIntervalSince1970: 1_700_000_000),
            amount: amountInPreferredCurrency,
            currencyCode: "USD",
            note: "",
            category: category,
            tags: [],
            amountInPreferredCurrency: amountInPreferredCurrency
        )
        tx.preferredCurrencyCode = "USD"
        return tx
    }

    // MARK: - La categoría manda sobre el signo (el bug)

    @Test func incomeCategory_withNegativeAmount_isIncome() {
        let tx = makeTransaction(amountInPreferredCurrency: -240, category: makeCategory(isIncome: true))
        #expect(TransactionClassificationLogic.isIncome(tx) == true)
    }

    @Test func expenseCategory_withPositiveAmount_isExpense() {
        let tx = makeTransaction(amountInPreferredCurrency: 240, category: makeCategory(isIncome: false))
        #expect(TransactionClassificationLogic.isIncome(tx) == false)
    }

    // MARK: - Casos coherentes (el 99% de los datos)

    @Test func incomeCategory_withPositiveAmount_isIncome() {
        let tx = makeTransaction(amountInPreferredCurrency: 500, category: makeCategory(isIncome: true))
        #expect(TransactionClassificationLogic.isIncome(tx) == true)
    }

    @Test func expenseCategory_withNegativeAmount_isExpense() {
        let tx = makeTransaction(amountInPreferredCurrency: -100, category: makeCategory(isIncome: false))
        #expect(TransactionClassificationLogic.isIncome(tx) == false)
    }

    // MARK: - Fallback al signo cuando category == nil

    @Test func noCategory_withPositiveAmount_fallsBackToIncome() {
        let tx = makeTransaction(amountInPreferredCurrency: 50, category: nil)
        #expect(TransactionClassificationLogic.isIncome(tx) == true)
    }

    @Test func noCategory_withNegativeAmount_fallsBackToExpense() {
        let tx = makeTransaction(amountInPreferredCurrency: -50, category: nil)
        #expect(TransactionClassificationLogic.isIncome(tx) == false)
    }

    @Test func noCategory_withZeroAmount_isIncome_boundary() {
        // Borde `>= 0`: 0 cuenta como income (paridad con TransactionDetailSheetLogic).
        let tx = makeTransaction(amountInPreferredCurrency: 0, category: nil)
        #expect(TransactionClassificationLogic.isIncome(tx) == true)
    }
}
