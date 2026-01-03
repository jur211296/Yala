//
//  TrendDataProcessor.swift
//  Neto
//
//  Unified service for trend chart data processing.
//  Single source of truth for TrendCardView and DetailContainerView.
//

import Foundation
import SwiftData

/// Unified trend data processor ensuring identical chart behavior
/// across TrendCardView (Panel) and DetailContainerView (Statistics).
struct TrendDataProcessor {

    // MARK: - Constants (Single Source of Truth)

    /// Window size for moving average calculation
    static let smoothingWindowSize = 14

    /// Minimum data points before applying smoothing
    static let smoothingThreshold = 30

    /// Periods that require smoothing
    static let smoothingPeriods: [DetailPeriod] = [.thisYear, .lastYear, .allTime]

    // MARK: - Result Type

    struct TrendProcessingResult {
        let points: [PanelViewModel.BarPoint]
        let yDomain: ClosedRange<Double>
        let totalIncome: Double
        let totalExpense: Double
    }

    // MARK: - Main Processing Entry Point

    /// Process transactions into chart-ready data points.
    /// Both PanelViewModel and TrendsDetailViewModel should use this method.
    static func processTrendData(
        transactions: [TransactionItem],
        accounts: [Account],
        metric: TrendType,
        period: DetailPeriod,
        grouping: TrendGrouping,
        interval: DateInterval,
        currencyCode: String,
        context: ModelContext
    ) -> TrendProcessingResult {
        let calendar = Calendar.current

        // 1. Single pass to calculate totals AND date range (performance optimization)
        var totalIncome: Double = 0
        var totalExpense: Double = 0
        var minDate: Date?
        var maxDate: Date?

        for transaction in transactions {
            let amount = transaction.amountInPreferredCurrency
            if amount > 0 {
                totalIncome += amount
            } else {
                totalExpense += abs(amount)
            }

            let date = transaction.date
            if minDate == nil || date < minDate! {
                minDate = date
            }
            if maxDate == nil || date > maxDate! {
                maxDate = date
            }
        }

        // 2. Determine actual data range from transactions (avoid empty leading periods)
        guard let firstTransactionDate = minDate,
            let lastTransactionDate = maxDate
        else {
            // No transactions - return empty result
            return TrendProcessingResult(
                points: [],
                yDomain: 0...100,
                totalIncome: 0,
                totalExpense: 0
            )
        }

        // Use actual data range, capped to the interval end
        let effectiveStart = max(firstTransactionDate, interval.start)
        let effectiveEnd = min(lastTransactionDate, interval.end)

        // 3. Build date buckets only for actual data range
        var buckets: [Date: Double] = [:]
        var current = grouping.dateKey(for: effectiveStart, calendar: calendar)
        let endDate = effectiveEnd

        while current <= endDate {
            buckets[current] = 0
            if let next = calendar.date(byAdding: grouping.calendarComponent, value: 1, to: current)
            {
                current = next
            } else {
                break
            }
        }

        // 3. Fill buckets based on metric
        switch metric {
        case .balance:
            fillBalanceBuckets(
                &buckets,
                transactions: transactions,
                accounts: accounts,
                interval: interval,
                grouping: grouping,
                calendar: calendar
            )

        case .income:
            for transaction in transactions where transaction.amountInPreferredCurrency > 0 {
                let bucketDate = grouping.dateKey(for: transaction.date, calendar: calendar)
                buckets[bucketDate, default: 0] += transaction.amountInPreferredCurrency
            }

        case .expense:
            for transaction in transactions where transaction.amountInPreferredCurrency < 0 {
                let bucketDate = grouping.dateKey(for: transaction.date, calendar: calendar)
                buckets[bucketDate, default: 0] += abs(transaction.amountInPreferredCurrency)
            }
        }

        // 4. Filter and convert to BarPoints
        let filteredBuckets: [Date: Double]
        if metric == .balance {
            filteredBuckets = buckets
        } else {
            // For income/expense, only keep dates with actual data
            filteredBuckets = buckets.filter { $0.value != 0 }
        }

        var rawPoints = filteredBuckets.map { date, value in
            PanelViewModel.BarPoint(date: date, value: value)
        }.sorted { $0.date < $1.date }

        // 5. Apply smoothing for balance on long periods
        let shouldSmooth =
            smoothingPeriods.contains(period)
            && metric == .balance
            && rawPoints.count > smoothingThreshold

        if shouldSmooth {
            rawPoints = TrendProcessingHelper.movingAverage(
                for: rawPoints,
                window: smoothingWindowSize
            )
        }

        // 6. Calculate Y domain
        let yDomain = TrendProcessingHelper.calculateYDomain(
            for: rawPoints,
            isExpense: metric == .expense
        )

        return TrendProcessingResult(
            points: rawPoints,
            yDomain: yDomain,
            totalIncome: totalIncome,
            totalExpense: totalExpense
        )
    }

    // MARK: - Private Helpers

    /// Fill balance buckets with running balance calculation
    private static func fillBalanceBuckets(
        _ buckets: inout [Date: Double],
        transactions: [TransactionItem],
        accounts: [Account],
        interval: DateInterval,
        grouping: TrendGrouping,
        calendar: Calendar
    ) {
        // Start with initial account balances
        var runningBalance = accounts.reduce(0.0) { $0 + $1.initialBalance }

        // Add transactions before interval
        for transaction in transactions where transaction.date < interval.start {
            runningBalance += transaction.amountInPreferredCurrency
        }

        // Group transactions by bucket date
        let transactionsByBucket = Dictionary(
            grouping: transactions.filter { interval.contains($0.date) }
        ) { transaction in
            grouping.dateKey(for: transaction.date, calendar: calendar)
        }

        // Fill buckets with cumulative balance
        let sortedDates = buckets.keys.sorted()
        for date in sortedDates {
            if let txns = transactionsByBucket[date] {
                for txn in txns {
                    runningBalance += txn.amountInPreferredCurrency
                }
            }
            buckets[date] = runningBalance
        }
    }
}
