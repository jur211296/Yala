//
//  TagSpendingCalculator.swift
//  Yala
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
    ///   - allTags: Caller-provided list of Tag objects (typically from `@Query<Tag>` or service).
    ///     Used to resolve `tag.id` UUID from the CSV mirror back to Tag objects for display.
    ///     Permite ignorar la M2M lazy y leer spending por tag desde el CSV mirror.
    /// - Returns: Sorted list of TagSpendingSummary (descending by amount)
    static func calculateTopSpending(
        transactions: [TransactionItem],
        interval: DateInterval,
        currencyCode: String,
        transactionNatures: Set<TransactionNature>? = nil,
        allTags: [Tag] = []
    ) -> [TagSpendingSummary] {
        // Determine which natures to include (default: expense only)
        let naturesToInclude = transactionNatures ?? [.expense]

        // Resolver UUID → Tag para construir el tagMap final.
        // Si `allTags` está vacío (fallback legacy), caemos al patrón M2M-direct.
        let tagsByID = Tag.byIDLookup(allTags)
        let useCSVPath = !allTags.isEmpty

        // 1. Filter Transactions (within interval, has category, matching natures, has tags).
        let filteredTransactions = transactions.filter { transaction in
            guard let category = transaction.category else { return false }
            guard transaction.balanceAdjustmentType == nil else { return false }
            let nature: TransactionNature = category.isIncome ? .income : .expense
            guard naturesToInclude.contains(nature) else { return false }
            let txTagUUIDs = transaction.resolvedTagIDs(scheduleBackfill: true) ?? []
            guard !txTagUUIDs.isEmpty else { return false }
            return interval.contains(transaction.date)
        }

        // 2. Group by Tag UUID and Sum Amounts.
        var tagTotals: [UUID: Double] = [:]
        var tagMap: [UUID: Tag] = [:]

        for transaction in filteredTransactions {
            let absAmount = abs(transaction.amountInPreferredCurrency)
            let txTagUUIDs = transaction.resolvedTagIDs(scheduleBackfill: true) ?? []
            for tagID in txTagUUIDs {
                tagTotals[tagID, default: 0] += absAmount
                if useCSVPath {
                    if let tag = tagsByID[tagID] {
                        tagMap[tagID] = tag
                    }
                    // UUIDs huérfanos (Tag borrado) se skipean silenciosamente en (5).
                } else {
                    // Fallback legacy: resolver via M2M relation.
                    if let tag = (transaction.tags ?? []).first(where: { $0.id == tagID }) {
                        tagMap[tagID] = tag
                    }
                }
            }
        }

        // 3. Calculate Total
        let totalAmount = tagTotals.values.reduce(0, +)

        // 4. Sort by amount descending
        let sortedTags = tagTotals.sorted { $0.value > $1.value }

        // 5. Create Summaries (huérfanos sin Tag resuelto se descartan).
        return sortedTags.compactMap { (id, amount) -> TagSpendingSummary? in
            guard let tag = tagMap[id] else { return nil }
            let percentage = totalAmount > 0 ? (amount / totalAmount) * 100 : 0
            return TagSpendingSummary(tag: tag, amount: amount, percentage: percentage)
        }
    }
}
