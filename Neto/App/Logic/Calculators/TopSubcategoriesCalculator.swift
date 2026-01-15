//
//  TopSubcategoriesCalculator.swift
//  Neto
//
//  Created by Neto Refactoring.
//

import Foundation
import SwiftData

struct TopSubcategoriesCalculator {
    /// Calculates top spending subcategories
    /// - Parameters:
    ///   - transactions: List of transactions (should already be filtered by account/validity if needed, but we check expenses)
    ///   - interval: Date interval for filtering
    ///   - currencyCode: Target currency code
    ///   - categoryFilter: Optional parent Category ID to filter by
    ///   - context: ModelContext for fetching exchange rates
    /// - Returns: Sorted list of SubcategorySpendingSummary
    static func calculateTopSubcategories(
        transactions: [TransactionItem],
        interval: DateInterval,
        currencyCode: String,
        categoryFilter: PersistentIdentifier? = nil,
        context: ModelContext
    ) -> [SubcategorySpendingSummary] {

        // 1. Filter Transactions
        // - Within interval
        // - Is Expense
        // - Has Category
        // - If categoryFilter is present, must match parent category

        let validTransactions = transactions.filter { transaction in
            // Basic validity
            guard let category = transaction.category, !category.isIncome else { return false }

            // Interval check
            if !interval.contains(transaction.date) { return false }

            // Category Filter Check
            if let filterID = categoryFilter {
                if category.persistentModelID != filterID {
                    return false
                }
            }

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

            let absAmount = abs(transaction.amount)
            let decimalAmount = Decimal(absAmount)

            // Convert using the transaction's date for accurate historical rate
            // Convert using the transaction's date for accurate historical rate
            // Convert using the transaction's date for accurate historical rate
            let doubleVal: Double
            if transaction.preferredCurrencyCode == currencyCode {
                // Use signed amount (expenses are negative)
                doubleVal = transaction.amountInPreferredCurrency
            } else {
                let convertedAmount = CurrencyConverter.shared.convert(
                    decimalAmount,
                    from: transaction.currencyCode,
                    to: currencyCode,
                    on: transaction.date,
                    context: context
                )
                // Restore sign from original amount for correct refund handling
                let magnitude = NSDecimalNumber(decimal: convertedAmount).doubleValue
                doubleVal = (transaction.amount < 0) ? -magnitude : magnitude
            }

            // Global aggregates
            totalExpenseAll += doubleVal
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
