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
    /// - Returns: Sorted list of SubcategorySpendingSummary
    static func calculateTopSubcategories(
        transactions: [TransactionItem],
        interval: DateInterval,
        currencyCode: String,
        categoryFilter: PersistentIdentifier? = nil
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
            // Conversion logic (simplified here, assumes calling context or global convert exists as in other calculators)
            let decimalAmount = Decimal(absAmount)
            let convertedAmount = convert(
                decimalAmount, from: transaction.currencyCode, to: currencyCode)
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

    // MARK: - Private Helpers (Self-Contained)

    private static func normalizeCurrencyCode(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "PEN" }

        let upper = trimmed.uppercased()
        switch upper {
        case "PEN", "SOL", "SOLES", "S/", "S/.", "S/. ": return "PEN"
        case "USD", "US$", "US DOLLAR", "$", "$USD", "USD$": return "USD"
        case "EUR", "€", "EURO": return "EUR"
        default: return "PEN"
        }
    }

    private static func rateToPEN(_ rawCode: String) -> Decimal {
        let code = normalizeCurrencyCode(rawCode)
        switch code {
        case "PEN": return 1.0
        case "USD": return 3.54
        case "EUR": return 3.89
        default: return 1.0
        }
    }

    private static func convert(_ amount: Decimal, from rawFrom: String, to rawTo: String)
        -> Decimal
    {
        let fromCode = normalizeCurrencyCode(rawFrom)
        let toCode = normalizeCurrencyCode(rawTo)

        if fromCode == toCode { return amount }

        let fromRate = rateToPEN(fromCode)
        let toRate = rateToPEN(toCode)

        if fromRate == 0 || toRate == 0 { return amount }

        let amountInPEN = amount * fromRate

        if toCode == "PEN" { return amountInPEN }

        return amountInPEN / toRate
    }
}
