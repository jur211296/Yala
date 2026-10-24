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
            // Exclude balance adjustments and transfers (they shouldn't appear in category stats)
            guard transaction.balanceAdjustmentType == nil else { return false }

            // Ingreso o gasto con la regla de toda la app. Sin categoría también entra: va a la fila «Sin categoría»
            // (decisión A de Jürgen, 2026-10-23) para que el ranking sume el total del período.
            let nature: TransactionNature = TransactionClassificationLogic.isIncome(transaction) ? .income : .expense
            guard naturesToInclude.contains(nature) else { return false }

            // Interval check
            if !interval.contains(transaction.date) { return false }

            return true
        }

        // 2. Compute Totals
        // Needs total expense of ALL valid transactions (for % of Total)
        // Needs total expense per Parent Category (for % of Category)

        var totalExpenseAll: Double = 0
        // Clave `nil` = «Sin categoría».
        var totalExpensePerCategory: [PersistentIdentifier?: Double] = [:]

        // Grouping Key: "SubcategoryID", "NoSubcategory-CategoryID" o, sin categoría, las dos `nil`.
        struct GroupingKey: Hashable {
            let subcategoryID: PersistentIdentifier?
            let categoryID: PersistentIdentifier?
        }

        var groupingTotals: [GroupingKey: Double] = [:]
        // La fila «Sin categoría» suma la magnitud de cada lado: con los filtros Ingresos y Gastos a la vez, un ingreso y
        // un gasto sin categoría no se restan entre sí (review del 2026-10-24; mismo criterio que la tarta).
        var uncategorizedIncome = 0.0
        var uncategorizedExpense = 0.0
        var groupingMetadata:
            [GroupingKey: (name: String, color: String?, sub: Subcategory?, cat: Category?)] = [:]

        for transaction in validTransactions {
            let category = transaction.category

            // Convert using the transaction's date for accurate historical rate
            // `adjustment` proyecta un gasto de grupo Caso A a "mi parte" (neto).
            let doubleVal: Double
            if CashFlowCalculator.readsStoredAmount(transaction, currencyCode: currencyCode, adjustment: adjustment) {
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
               category?.persistentModelID != filterID { continue }

            totalExpensePerCategory[category?.persistentModelID, default: 0] += doubleVal

            // Grouping. Sin categoría, una sola fila aunque el movimiento traiga una subcategoría colgando.
            let subID = category == nil ? nil : transaction.subcategory?.persistentModelID
            let key = GroupingKey(subcategoryID: subID, categoryID: category?.persistentModelID)

            groupingTotals[key, default: 0] += doubleVal
            if category == nil {
                if TransactionClassificationLogic.isIncome(transaction) {
                    uncategorizedIncome += doubleVal
                } else {
                    uncategorizedExpense += doubleVal
                }
            }

            // Metadata (store once)
            if groupingMetadata[key] == nil {
                if category == nil {
                    groupingMetadata[key] = (
                        name: L10n.Report.uncategorized,
                        color: AppConstants.uncategorizedColorHex,
                        sub: nil,
                        cat: nil
                    )
                } else if let category, let sub = transaction.subcategory {
                    groupingMetadata[key] = (
                        name: sub.name,
                        color: (sub.colorHex?.isEmpty == false ? sub.colorHex : nil)
                            ?? category.colorHex,  // Fallback to category color if nil or empty
                        sub: sub,
                        cat: category
                    )
                } else if let category {
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
            let absAmount = key.categoryID == nil
                ? abs(uncategorizedIncome) + abs(uncategorizedExpense)
                : abs(amount)
            let absCatTotal = key.categoryID == nil ? absAmount : abs(catTotal)

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
