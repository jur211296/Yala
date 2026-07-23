//
//  TopSubcategoriesCalculator.swift
//  Yala
//
//  Created by Yala Refactoring.
//

import Foundation
import SwiftData

struct TopSubcategoriesCalculator {
    /// Calculates top subcategories by amount
    /// - Parameters:
    ///   - transactions: List of transactions
    ///   - interval: Date interval for filtering
    ///   - currencyCode: Target currency code
    ///   - categoryFilter: Optional parent Category ID to filter by
    ///   - transactionNatures: Filter by transaction nature (nil = expense only for backwards compatibility)
    ///   - context: ModelContext for fetching exchange rates
    /// - Returns: Sorted list of SubcategorySpendingSummary
    static func calculateTopSubcategories(
        transactions: [TransactionItem],
        interval: DateInterval,
        currencyCode: String,
        categoryFilter: PersistentIdentifier? = nil,
        transactionNatures: Set<TransactionNature>? = nil,
        adjustment: GroupBridgeStatsAdjustment = .none,
        converter: CurrencyConverting = CurrencyConverter.shared
    ) -> [SubcategorySpendingSummary] {

        // Determine which natures to include
        let naturesToInclude = transactionNatures ?? [.expense]

        // 1. Filter Transactions
        // - Within interval
        // - Matches requested transaction natures
        // - Has Category
        // - If categoryFilter is present, must match parent category

        // Filter by interval, nature, and balance adjustment — WITHOUT categoryFilter
        // so totalExpenseAll reflects the global total across all categories
        let validTransactions = transactions.filter { transaction in
            // Excluir patas de préstamo derivadas del bridge (préstamo a grupos).
            guard !adjustment.isSuppressed(transaction) else { return false }
            // Basic validity - must have category
            guard let category = transaction.category else { return false }

            // Exclude balance adjustments and transfers (they shouldn't appear in category stats)
            guard transaction.balanceAdjustmentType == nil else { return false }

            // Need check
            let nature: TransactionNature = category.isIncome ? .income : .expense
            guard naturesToInclude.contains(nature) else { return false }

            // Interval check
            if !interval.contains(transaction.date) { return false }

            return true
        }

        // 2. Compute Totals
        // Needs total expense of ALL valid transactions (for % of Total)
        // Needs total expense per Parent Category (for % of Category)

        var totalExpenseAll: Double = 0
        var totalExpensePerCategory: [PersistentIdentifier: Double] = [:]

        // Grouping Key: "SubcategoryID" or "NoSubcategory-CategoryID"
        struct GroupingKey: Hashable {
            let subcategoryID: PersistentIdentifier?
            let categoryID: PersistentIdentifier
        }

        var groupingTotals: [GroupingKey: Double] = [:]
        var groupingMetadata:
            [GroupingKey: (name: String, color: String?, sub: Subcategory?, cat: Category)] = [:]

        for transaction in validTransactions {
            guard let category = transaction.category else { continue }

            // Convert using the transaction's date for accurate historical rate
            // `adjustment` proyecta un gasto de grupo Caso A a "mi parte" (neto).
            let doubleVal: Double
            if transaction.preferredCurrencyCode == currencyCode {
                doubleVal = adjustment.amountInPreferredCurrency(transaction)
            } else {
                let decimalAmount = Decimal(abs(adjustment.amount(transaction)))
                let convertedAmount = converter.convert(
                    decimalAmount,
                    from: transaction.currencyCode,
                    to: currencyCode,
                    on: transaction.date
                )
                // Restore sign from the ADJUSTED amount for correct refund/neteo handling
                let magnitude = NSDecimalNumber(decimal: convertedAmount).doubleValue
                doubleVal = (adjustment.amount(transaction) < 0) ? -magnitude : magnitude
            }

            // Always accumulate global total (across all categories)
            totalExpenseAll += doubleVal

            // Apply categoryFilter only for grouping/per-category totals
            if let filterID = categoryFilter,
               category.persistentModelID != filterID { continue }

            totalExpensePerCategory[category.persistentModelID, default: 0] += doubleVal

            // Grouping
            let subID = transaction.subcategory?.persistentModelID
            let key = GroupingKey(subcategoryID: subID, categoryID: category.persistentModelID)

            groupingTotals[key, default: 0] += doubleVal

            // Metadata (store once)
            if groupingMetadata[key] == nil {
                if let sub = transaction.subcategory {
                    groupingMetadata[key] = (
                        name: sub.name,
                        color: (sub.colorHex?.isEmpty == false ? sub.colorHex : nil)
                            ?? category.colorHex,  // Fallback to category color if nil or empty
                        sub: sub,
                        cat: category
                    )
                } else {
                    // No Subcategory case
                    groupingMetadata[key] = (
                        name: L10n.Subcategory.noSubcategory,
                        color: category.colorHex,
                        sub: nil,
                        cat: category
                    )
                }
            }
        }

        // 3. Build Summaries
        var summaries: [SubcategorySpendingSummary] = []

        // Use absolute totals for percentage calculation (net negative expense -> positive magnitude)
        let absTotalAll = abs(totalExpenseAll)

        for (key, amount) in groupingTotals {
            guard let meta = groupingMetadata[key] else { continue }

            let catTotal = totalExpensePerCategory[key.categoryID] ?? amount
            let absCatTotal = abs(catTotal)
            let absAmount = abs(amount)

            let pctTotal = absTotalAll > 0 ? (absAmount / absTotalAll) * 100 : 0
            let pctCat = absCatTotal > 0 ? (absAmount / absCatTotal) * 100 : 0

            let summary = SubcategorySpendingSummary(
                subcategoryName: meta.name,
                colorHex: meta.color,
                amount: absAmount,
                percentageOfTotal: pctTotal,
                percentageOfCategory: pctCat,
                subcategory: meta.sub,
                category: meta.cat
            )
            summaries.append(summary)
        }

        // 4. Sort
        // Primary: Amount desc
        // Secondary: Name asc
        summaries.sort {
            if abs($0.amount - $1.amount) > 0.001 {
                return $0.amount > $1.amount
            }
            return $0.subcategoryName < $1.subcategoryName
        }

        return summaries

    }
}
