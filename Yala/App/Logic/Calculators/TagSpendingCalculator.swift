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
    ///   - allTags: Required catalog of Tag objects (from `@Query<Tag>` or service).
    ///     CSV-mirror SSOT: resuelve UUIDs del CSV mirror → Tag objects sin tocar la M2M lazy.
    /// - Returns: Sorted list of TagSpendingSummary (descending by amount)
    static func calculateTopSpending(
        transactions: [TransactionItem],
        interval: DateInterval,
        currencyCode: String,
        transactionNatures: Set<TransactionNature>? = nil,
        allTags: [Tag],
        adjustment: GroupBridgeStatsAdjustment = .none
    ) -> [TagSpendingSummary] {
        // Determine which natures to include (default: expense only)
        let naturesToInclude = transactionNatures ?? [.expense]

        let tagsByID = Tag.byIDLookup(allTags)

        // 1. Filter Transactions (within interval, has category, matching natures, has tags).
        //    Patas de préstamo derivadas del bridge se excluyen (no son gasto ni ingreso propio).
        let filteredTransactions = transactions.filter { transaction in
            guard !adjustment.isSuppressed(transaction) else { return false }
            guard let category = transaction.category else { return false }
            guard transaction.balanceAdjustmentType == nil else { return false }
            let nature: TransactionNature = category.isIncome ? .income : .expense
            guard naturesToInclude.contains(nature) else { return false }
            let txTagUUIDs = transaction.resolvedTagIDs(scheduleBackfill: true) ?? []
            guard !txTagUUIDs.isEmpty else { return false }
            return interval.contains(transaction.date)
        }

        // 2. Group by Tag UUID and Sum Amounts. `adjustment` proyecta un gasto de grupo Caso A
        //    a "mi parte" (neto), en vez del total que pagué.
        var tagTotals: [UUID: Double] = [:]
        var tagMap: [UUID: Tag] = [:]

        for transaction in filteredTransactions {
            let absAmount = abs(adjustment.amountInPreferredCurrency(transaction))
            let txTagUUIDs = transaction.resolvedTagIDs(scheduleBackfill: true) ?? []
            for tagID in txTagUUIDs {
                tagTotals[tagID, default: 0] += absAmount
                if let tag = tagsByID[tagID] {
                    tagMap[tagID] = tag
                }
                // UUIDs huérfanos (Tag borrado) se skipean silenciosamente en (5).
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
