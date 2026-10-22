//
//  DistributionPreviousPeriodCalculator.swift
//  Yala
//
//  Recorte WTD/MTD/YTD del período anterior para la pestaña Distribución
//  (CategoriesTabView). Misma semántica que el Panel / Tendencias:
//  `DateAlignmentHelper.alignedPreviousItems`.
//

import Foundation
import SwiftData

enum DistributionPreviousPeriodCalculator {

    /// Fechas del actual que la calculadora cuenta — corte nature-aware
    /// (nil → gasto), para no correr el WTD con un ingreso tardío.
    static func currentDates(
        from transactions: [TransactionItem],
        in interval: DateInterval,
        natures: Set<TransactionNature>?
    ) -> [Date] {
        let include = natures ?? [.expense]
        return transactions.filter { tx in
            guard tx.balanceAdjustmentType == nil, let category = tx.category,
                  interval.contains(tx.date) else { return false }
            let nature: TransactionNature = category.isIncome ? .income : .expense
            return include.contains(nature)
        }
        .map(\.date)
    }

    /// Previo recortado al span de días del actual. No-op en cerrados/rodantes
    /// y en `.thisWeek`+`.year` (el helper ya es simétrico ahí).
    static func alignedPrevious(
        _ previous: [TransactionItem],
        currentDates: [Date],
        currentInterval: DateInterval,
        previousInterval: DateInterval,
        period: DetailPeriod,
        comparisonMode: ComparisonMode
    ) -> [TransactionItem] {
        DateAlignmentHelper.alignedPreviousItems(
            previous,
            currentDates: currentDates,
            currentInterval: currentInterval,
            previousInterval: previousInterval,
            period: period,
            comparisonMode: comparisonMode
        ) { $0.date }
    }

    /// Total de gasto por categoría del previo ya recortado (superficie Distribución).
    static func previousCategoryTotal(
        previousTransactions: [TransactionItem],
        currentDates: [Date],
        currentInterval: DateInterval,
        previousInterval: DateInterval,
        period: DetailPeriod,
        comparisonMode: ComparisonMode,
        currencyCode: String,
        natures: Set<TransactionNature>? = nil,
        adjustment: GroupBridgeStatsAdjustment = .none
    ) -> Double {
        let aligned = alignedPrevious(
            previousTransactions,
            currentDates: currentDates,
            currentInterval: currentInterval,
            previousInterval: previousInterval,
            period: period,
            comparisonMode: comparisonMode
        )
        return TopSpendingCategoriesCalculator.calculateTopSpending(
            transactions: aligned,
            interval: previousInterval,
            currencyCode: currencyCode,
            transactionNatures: natures,
            adjustment: adjustment
        ).reduce(0) { $0 + $1.amount }
    }
}
