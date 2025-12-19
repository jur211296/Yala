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
            let convertedAmount = CurrencyConverter.shared.convert(
                decimalAmount,
                from: transaction.currencyCode,
                to: currencyCode,
                on: transaction.date,
                context: context
            )
            let doubleVal = NSDecimalNumber(decimal: convertedAmount).doubleValue

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
                        name: "Sin subcategoría",
                        color: category.colorHex,
                        sub: nil,
                        cat: category
                    )
                }
            }
        }

        // 3. Build Summaries
        var summaries: [SubcategorySpendingSummary] = []

        for (key, amount) in groupingTotals {
            guard let meta = groupingMetadata[key] else { continue }

            let catTotal = totalExpensePerCategory[key.categoryID] ?? amount  // Should exist

            let pctTotal = totalExpenseAll > 0 ? (amount / totalExpenseAll) * 100 : 0
            let pctCat = catTotal > 0 ? (amount / catTotal) * 100 : 0

            let summary = SubcategorySpendingSummary(
                subcategoryName: meta.name,
                colorHex: meta.color,
                amount: amount,
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
