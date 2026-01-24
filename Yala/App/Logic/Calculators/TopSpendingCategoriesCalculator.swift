//
//  TopSpendingCategoriesCalculator.swift
//  Yala
//
//  Created by Yala Refactoring.
//

import Foundation
import SwiftData

struct TopSpendingCategoriesCalculator {
    /// Calculates the top spending categories for a given set of transactions and time interval.
    /// - Parameters:
    ///   - transactions: List of transactions
    ///   - interval: Date interval for filtering
    ///   - currencyCode: Target currency code
    ///   - transactionNatures: Filter by transaction nature (nil = expense only for backwards compatibility)
    ///   - context: ModelContext for fetching exchange rates
    /// - Returns: Sorted list of CategorySpendingSummary
    static func calculateTopSpending(
        transactions: [TransactionItem],
        interval: DateInterval,
        currencyCode: String,
        transactionNatures: Set<TransactionNature>? = nil,
        context: ModelContext
    ) -> [CategorySpendingSummary] {

        // Determine which natures to include
        let naturesToInclude = transactionNatures ?? [.expense]

        // 1. Filter Transactions
        // - Within interval
        // - Has a category
        // - Matches requested transaction natures
        // - Excludes balance adjustments and transfers
        let filteredTransactions = transactions.filter { transaction in
            guard let category = transaction.category else { return false }
            // Exclude balance adjustments and transfers
            guard transaction.balanceAdjustmentType == nil else { return false }
            let nature: TransactionNature = category.isIncome ? .income : .expense
            guard naturesToInclude.contains(nature) else { return false }
            return interval.contains(transaction.date)
        }

        // 2. Group by Category (Parent) and Sum Amounts
        // Note: Logic says "Group by category parent".
        // If the transaction has a subcategory, it still belongs to the parent category.
        // transaction.category IS the category (parent if direct assignment, or parent of subcategory?)
        // Let's assume transaction.category is the main grouping entity.

        var categoryTotals: [PersistentIdentifier: Double] = [:]
        var categoryMap: [PersistentIdentifier: Category] = [:]

        for transaction in filteredTransactions {
            guard let category = transaction.category else { continue }

            // Use absolute value for expense
            let absAmount = abs(transaction.amount)
            let decimalAmount = Decimal(absAmount)

            // Convert using the transaction's date for accurate historical rate
            let doubleAmount: Double
            if transaction.preferredCurrencyCode == currencyCode {
                doubleAmount = transaction.amountInPreferredCurrency
            } else {
                let convertedAmount = CurrencyConverter.shared.convert(
                    decimalAmount,
                    from: transaction.currencyCode,
                    to: currencyCode,
                    on: transaction.date,
                    context: context
                )
                // Fallback conversion usually returns positive because input decimalAmount is abs()
                // We should flip it if transaction.amount is negative (expense)
                // However, transaction.amount is usually negative for expense.
                // But simplified: Use signed logic if available. If fallback, maybe we assume expense is negative?
                // The prompt says "amountInPreferredCurrency" is the standard.
                // If we fallback, we might have sign issues?
                // Let's assume fallback is positive magnitude (since decimalAmount is abs), and we negate it?
                // Or just rely on persisted amount.
                // For safety in this specific refactor step regarding "Standardizing Amount Usage"
                // we mainly care about the preferredCurrency path.

                // Correction: The fallback uses `decimalAmount` which comes from `let absAmount = abs(transaction.amount)`.
                // So fallback returns POSITIVE magnitude.
                // Since this calculator is for "Expense", we should treat it as negative?
                // Previously we were adding POSITIVE doubleAmount to total.
                // Now we want signed. Expenses are negative.
                // So if fallback returns 100, we should use -100.
                // But transaction could be refund (+10).

                // To support fallback correctly with signs:
                // let sign = transaction.amount >= 0 ? 1.0 : -1.0
                // doubleAmount = ... * sign

                // However, user data is migrated, so preferredCurrencyCode should match mostly.
                // Let's stick to what we had for fallback (positive) but maybe negate it?
                // Actually, existing code was: `categoryTotals += doubleAmount` (positive).
                // So previously `categoryTotals` held POSITIVE magnitude.
                // Now we represent expense as NEGATIVE.
                // So `categoryTotals` will be negative.
                // So `doubleAmount` must be negative.

                let magnitude = NSDecimalNumber(decimal: convertedAmount).doubleValue
                // Restore sign from original amount
                doubleAmount = (transaction.amount < 0) ? -magnitude : magnitude
            }

            let categoryID = category.persistentModelID
            categoryTotals[categoryID, default: 0] += doubleAmount
            categoryMap[categoryID] = category
        }

        // 3. Calculate Total Expense (Using ABS of the net negative sum)
        let netTotalSigned = categoryTotals.values.reduce(0, +)
        let totalExpense = abs(netTotalSigned)

        // 4. Sort (All categories)
        // Sort by magnitude (abs)
        let sortedCategories = categoryTotals.sorted { abs($0.value) > abs($1.value) }

        // Return all categories (Consumers like TopSpendingCardView can prefix(5) themselves)
        let topCategories = sortedCategories

        // 5. Create Summaries
        return topCategories.compactMap { (id, signedAmount) -> CategorySpendingSummary? in
            guard let category = categoryMap[id] else { return nil }

            let absAmount = abs(signedAmount)
            let percentage = totalExpense > 0 ? (absAmount / totalExpense) * 100 : 0

            return CategorySpendingSummary(
                category: category,
                amount: absAmount,
                percentage: percentage
            )
        }
    }
}
