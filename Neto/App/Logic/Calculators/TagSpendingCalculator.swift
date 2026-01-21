//
//  TagSpendingCalculator.swift
//  Neto
//
//  Calculates spending by tag, following the same pattern as TopSpendingCategoriesCalculator.
//

import Foundation
import SwiftData

struct TagSpendingCalculator {
    /// Calculates the top spending tags for a given set of transactions and time interval.
    /// - Parameters:
    ///   - transactions: List of transactions (already filtered by account/category if needed)
    ///   - interval: Date interval for filtering
    ///   - currencyCode: Target currency code (for display, uses amountInPreferredCurrency)
    ///   - transactionNatures: Filter by transaction nature (nil = expense only for backwards compatibility)
    /// - Returns: Sorted list of TagSpendingSummary (descending by amount)
    static func calculateTopSpending(
        transactions: [TransactionItem],
        interval: DateInterval,
        currencyCode: String,
        transactionNatures: Set<TransactionNature>? = nil
    ) -> [TagSpendingSummary] {
        // Determine which natures to include (default: expense only)
        let naturesToInclude = transactionNatures ?? [.expense]

        // 1. Filter Transactions
        // - Within interval
        // - Has a category (to determine nature)
        // - Matches requested transaction natures
        // - Has at least one tag
        // - Excludes balance adjustments and transfers
        let filteredTransactions = transactions.filter { transaction in
            guard let category = transaction.category else { return false }
            // Exclude balance adjustments and transfers
            guard transaction.balanceAdjustmentType == nil else { return false }
            let nature: TransactionNature = category.isIncome ? .income : .expense
            guard naturesToInclude.contains(nature) else { return false }
            guard !transaction.tags.isEmpty else { return false }
            return interval.contains(transaction.date)
        }

        // 2. Group by Tag and Sum Amounts
        // Note: A transaction can have multiple tags, so it contributes to each tag's total
        var tagTotals: [PersistentIdentifier: Double] = [:]
        var tagMap: [PersistentIdentifier: Tag] = [:]

        for transaction in filteredTransactions {
            let absAmount = abs(transaction.amountInPreferredCurrency)
            for tag in transaction.tags {
                let tagID = tag.persistentModelID
                tagTotals[tagID, default: 0] += absAmount
                tagMap[tagID] = tag
            }
        }

        // 3. Calculate Total (for percentage calculation)
        let totalAmount = tagTotals.values.reduce(0, +)

        // 4. Sort by amount descending
        let sortedTags = tagTotals.sorted { $0.value > $1.value }

        // 5. Create Summaries
        return sortedTags.compactMap { (id, amount) -> TagSpendingSummary? in
            guard let tag = tagMap[id] else { return nil }
            let percentage = totalAmount > 0 ? (amount / totalAmount) * 100 : 0
            return TagSpendingSummary(tag: tag, amount: amount, percentage: percentage)
        }
    }
}
