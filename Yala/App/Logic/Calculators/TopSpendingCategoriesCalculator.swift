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
        adjustment: GroupBridgeStatsAdjustment = .none,
        converter: CurrencyConverting = CurrencyConverter.shared
    ) -> [CategorySpendingSummary] {

        // Determine which natures to include
        let naturesToInclude = transactionNatures ?? [.expense]

        // 1. Filter Transactions
        // - Within interval
        // - Matches requested transaction natures (ingreso o gasto con la regla de toda la app: la categoría manda y,
        //   sin categoría, el signo). Un movimiento sin categoría entra en el trozo «Sin categoría» (decisión A de
        //   Jürgen, 2026-10-23): hasta entonces quedaba fuera y la tarta sumaba menos que el gasto del período.
        // - Excludes balance adjustments and transfers
        // - Excludes bridge-derived loan legs (préstamo a grupos): no son gasto/ingreso propio.
        let filteredTransactions = transactions.filter { transaction in
            guard !adjustment.isSuppressed(transaction) else { return false }
            // Exclude balance adjustments and transfers
            guard transaction.balanceAdjustmentType == nil else { return false }
            let nature: TransactionNature = TransactionClassificationLogic.isIncome(transaction) ? .income : .expense
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
        // «Sin categoría», con signo y POR LADO: con los filtros Ingresos y Gastos a la vez, un ingreso y un gasto sin
        // categoría no se restan entre sí (lo cazó la review del 2026-10-24). Su lado lo dice el signo, así que el de
        // ingresos nunca baja de 0 ni el de gastos sube de 0.
        var uncategorizedIncome = 0.0
        var uncategorizedExpense = 0.0

        for transaction in filteredTransactions {
            let category = transaction.category

            // Use absolute value for expense. `adjustment` proyecta un gasto de grupo Caso A a
            // "mi parte" (neto) en vez del total que pagué.
            let absAmount = abs(adjustment.amount(transaction))
            let decimalAmount = Decimal(absAmount)

            // Convert using the transaction's date for accurate historical rate
            let doubleAmount: Double
            if CashFlowCalculator.readsStoredAmount(transaction, currencyCode: currencyCode, adjustment: adjustment) {
                doubleAmount = adjustment.amountInPreferredCurrency(transaction)
            } else {
                let convertedAmount = converter.convert(
                    decimalAmount,
                    from: transaction.currencyCode,
                    to: currencyCode,
                    on: transaction.date
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
                // Restore sign from the ADJUSTED amount (no `transaction.amount`) — así el signo
                // acompaña a la magnitud neteada aunque difieran (paridad con la rama preferida).
                doubleAmount = (adjustment.amount(transaction) < 0) ? -magnitude : magnitude
            }

            guard let category else {
                if TransactionClassificationLogic.isIncome(transaction) {
                    uncategorizedIncome += doubleAmount
                } else {
                    uncategorizedExpense += doubleAmount
                }
                continue
            }
            let categoryID = category.persistentModelID
            categoryTotals[categoryID, default: 0] += doubleAmount
            categoryMap[categoryID] = category
        }

        // Cada trozo: su clave (`nil` = «Sin categoría»), su importe con signo (para el total) y su magnitud (lo que se
        // pinta). En una categoría la magnitud es la del neto; en «Sin categoría», la suma de las de cada lado.
        var entries: [(id: PersistentIdentifier?, signed: Double, magnitude: Double)] = categoryTotals.map {
            (id: $0.key, signed: $0.value, magnitude: abs($0.value))
        }
        if uncategorizedIncome != 0 || uncategorizedExpense != 0 {
            entries.append((
                id: nil,
                signed: uncategorizedIncome + uncategorizedExpense,
                magnitude: abs(uncategorizedIncome) + abs(uncategorizedExpense)
            ))
        }

        // 3. Calculate Total Expense (Using ABS of the net negative sum)
        let netTotalSigned = entries.reduce(0) { $0 + $1.signed }
        let totalExpense = abs(netTotalSigned)

        // 4. Sort (All categories)
        // Sort by magnitude; a igual importe, «Sin categoría» detrás de cualquier categoría.
        let sortedCategories = entries.sorted {
            if $0.magnitude != $1.magnitude { return $0.magnitude > $1.magnitude }
            return $0.id != nil && $1.id == nil
        }

        // Return all categories (Consumers like TopSpendingCardView can prefix(5) themselves)
        let topCategories = sortedCategories

        // 5. Create Summaries
        return topCategories.compactMap { entry -> CategorySpendingSummary? in
            let category: Category?
            if let id = entry.id {
                guard let found = categoryMap[id] else { return nil }
                category = found
            } else {
                category = nil
            }

            let absAmount = entry.magnitude
            let percentage = totalExpense > 0 ? (absAmount / totalExpense) * 100 : 0

            return CategorySpendingSummary(
                category: category,
                amount: absAmount,
                percentage: percentage
            )
        }
    }
}
