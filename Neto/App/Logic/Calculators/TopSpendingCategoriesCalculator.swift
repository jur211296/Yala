//
//  TopSpendingCategoriesCalculator.swift
//  Neto
//
//  Created by Neto Refactoring.
//

import Foundation
import SwiftData

struct TopSpendingCategoriesCalculator {
    /// Calculates the top 5 spending categories for a given set of transactions and time interval.
    static func calculateTopSpending(
        transactions: [TransactionItem],
        interval: DateInterval,
        currencyCode: String,
        context: ModelContext
    ) -> [CategorySpendingSummary] {

        // 1. Filter Transactions
        // - Within interval
        // - Has a category
        // - Category is an expense (isIncome == false)
        let expenseTransactions = transactions.filter { transaction in
            guard let category = transaction.category, !category.isIncome else { return false }
            return interval.contains(transaction.date)
        }

        // 2. Group by Category (Parent) and Sum Amounts
        // Note: Logic says "Group by category parent".
        // If the transaction has a subcategory, it still belongs to the parent category.
        // transaction.category IS the category (parent if direct assignment, or parent of subcategory?)
        // Let's assume transaction.category is the main grouping entity.

        var categoryTotals: [PersistentIdentifier: Double] = [:]
        var categoryMap: [PersistentIdentifier: Category] = [:]

        for transaction in expenseTransactions {
            guard let category = transaction.category else { continue }

            // Use absolute value for expense
            let absAmount = abs(transaction.amount)
            let decimalAmount = Decimal(absAmount)

            // Convert using the transaction's date for accurate historical rate
            let convertedAmount = CurrencyConverter.shared.convert(
                decimalAmount,
                from: transaction.currencyCode,
                to: currencyCode,
                on: transaction.date,
                context: context
            )
            let doubleAmount = NSDecimalNumber(decimal: convertedAmount).doubleValue

            let categoryID = category.persistentModelID
            categoryTotals[categoryID, default: 0] += doubleAmount
            categoryMap[categoryID] = category
        }

        // 3. Calculate Total Expense (of the filtered set) for Percentage
        let totalExpense = categoryTotals.values.reduce(0, +)

        // 4. Sort and Pick Top 5
        // 4. Sort (All categories)
        let sortedCategories = categoryTotals.sorted { $0.value > $1.value }

        // Return all categories (Consumers like TopSpendingCardView can prefix(5) themselves)
        let topCategories = sortedCategories

        // 5. Create Summaries
        return topCategories.compactMap { (id, amount) -> CategorySpendingSummary? in
            guard let category = categoryMap[id] else { return nil }

            let percentage = totalExpense > 0 ? (amount / totalExpense) * 100 : 0

            return CategorySpendingSummary(
                category: category,
                amount: amount,
                percentage: percentage
            )
        }
    }
}
