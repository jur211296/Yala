//
//  TrendDataProcessor.swift
//  Yala
//
//  Unified service for trend chart data processing.
//  Single source of truth for TrendCardView and DetailContainerView.
//

import Foundation

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
        /// Points for chart visualization (smoothed when applicable)
        let points: [PanelViewModel.BarPoint]
        /// Original unsmoothed points for hover display and data queries
        let rawPoints: [PanelViewModel.BarPoint]
        let yDomain: ClosedRange<Double>
        let totalIncome: Double
        let totalExpense: Double
        /// The actual final balance before any smoothing is applied.
        /// Use this for KPI display instead of the last smoothed point.
        let finalBalance: Double
        /// Dot suelto "hoy" con saldo vivo. No-nil solo cuando metric==.balance
        /// y el período cubre hoy. La curva conserva sus puntos históricos
        /// intactos; este anchor se renderiza separado en `TrendChartView`.
        let liveAnchor: PanelViewModel.BarPoint?
        /// Desglose por moneda nativa del saldo vivo (`liveAnchor`). Habilita
        /// UX educativa multi-currency. Nil cuando `liveAnchor` es nil.
        let liveAnchorNativeBalances: [String: Decimal]?
    }

    // MARK: - Main Processing Entry Point

    /// Process transactions into chart-ready data points.
    /// Both PanelViewModel and TrendsDetailViewModel should use this method.
    ///
    /// - Parameter liveBalanceOverride: Si se pasa y `metric == .balance`,
    ///   construye un `liveAnchor` separado (dot suelto en `Date.now`) con
    ///   el valor. La curva mantiene sus puntos históricos intactos — el
    ///   dot lo renderiza `TrendChartView` aparte. `finalBalance` deriva de
    ///   este valor cuando aplica para que el KPI siga reflejando el saldo
    ///   al TC actual. El breakdown por moneda nativa se propaga vía
    ///   `liveAnchorNativeBalances` para UX educativa multi-currency.
    static func processTrendData(
        transactions: [TransactionItem],
        accounts: [Account],
        metric: TrendType,
        period: DetailPeriod,
        grouping: TrendGrouping,
        interval: DateInterval,
        currencyCode: String,
        liveBalanceOverride: LiveBalanceCalculator.LiveAnchorInfo? = nil
    ) -> TrendProcessingResult {
        let calendar = Calendar.current

        // 1. Filter transactions to interval first, then calculate totals and date range
        // This ensures min/max dates don't include transactions outside the interval
        let intervalTransactions = transactions.filter { interval.contains($0.date) }

        var totalIncome: Double = 0
        var totalExpense: Double = 0
        var minDate: Date?
        var maxDate: Date?

        for transaction in intervalTransactions {
            let amount = transaction.amountInPreferredCurrency

            // Exclude balance adjustments from income/expense totals
            // (they should only affect balance, not income/expense stats)
            let isBalanceAdjustment = transaction.balanceAdjustmentType != nil

            if !isBalanceAdjustment {
                if amount > 0 {
                    totalIncome += amount
                } else {
                    totalExpense += abs(amount)
                }
            }

            let date = transaction.date
            if let currentMin = minDate { if date < currentMin { minDate = date } } else { minDate = date }
            if let currentMax = maxDate { if date > currentMax { maxDate = date } } else { maxDate = date }
        }

        // 2. Determine actual data range from transactions (avoid empty leading periods)
        guard let firstTransactionDate = minDate,
            let lastTransactionDate = maxDate
        else {
            // No transactions - return empty result
            return TrendProcessingResult(
                points: [],
                rawPoints: [],
                yDomain: 0...100,
                totalIncome: 0,
                totalExpense: 0,
                finalBalance: 0,
                liveAnchor: nil,
                liveAnchorNativeBalances: nil
            )
        }

        // Use actual data range, capped to the interval end
        let effectiveStart = max(firstTransactionDate, interval.start)
        // Add 1 second to include transactions at exactly lastTransactionDate
        // (DateInterval.contains uses date < end, so we need end > lastTransactionDate)
        let effectiveEnd = min(lastTransactionDate.addingTimeInterval(1), interval.end)

        // Create effective interval for filtering (must match bucket range)
        let bucketStartDate = grouping.dateKey(for: effectiveStart, calendar: calendar)

        // Safety check: DateInterval crashes if start > end
        guard bucketStartDate <= effectiveEnd else {
            return TrendProcessingResult(
                points: [],
                rawPoints: [],
                yDomain: 0...100,
                totalIncome: totalIncome,
                totalExpense: totalExpense,
                finalBalance: 0,
                liveAnchor: nil,
                liveAnchorNativeBalances: nil
            )
        }

        let effectiveInterval = DateInterval(start: bucketStartDate, end: effectiveEnd)

        // 3. Build date buckets only for actual data range
        // Use < instead of <= because interval.end is exclusive
        var buckets: [Date: Double] = [:]
        var current = bucketStartDate
        let endDate = effectiveEnd

        while current < endDate {
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
                interval: effectiveInterval,  // Use the matched interval
                grouping: grouping,
                calendar: calendar
            )

        case .income:
            fillCumulativeBuckets(
                &buckets,
                transactions: transactions.filter {
                    $0.amountInPreferredCurrency > 0 && $0.balanceAdjustmentType == nil
                },
                grouping: grouping,
                calendar: calendar,
                valueTransform: { $0.amountInPreferredCurrency }
            )

        case .expense:
            fillCumulativeBuckets(
                &buckets,
                transactions: transactions.filter {
                    $0.amountInPreferredCurrency < 0 && $0.balanceAdjustmentType == nil
                },
                grouping: grouping,
                calendar: calendar,
                valueTransform: { abs($0.amountInPreferredCurrency) }
            )
        }

        // 4. Convert to BarPoints
        // For cumulative charts (all metrics now), keep all points after first non-zero value
        var rawPoints = buckets.map { date, value in
            PanelViewModel.BarPoint(date: date, value: value)
        }.sorted { $0.date < $1.date }

        // Remove leading zeros (before first transaction)
        if let firstNonZeroIndex = rawPoints.firstIndex(where: { $0.value != 0 }) {
            rawPoints = Array(rawPoints[firstNonZeroIndex...])
        }

        // 5. Apply smoothing only for balance on long periods (visual only)
        let shouldSmooth =
            smoothingPeriods.contains(period)
            && metric == .balance
            && rawPoints.count > smoothingThreshold

        // Smoothed points are for chart visualization only
        let chartPoints: [PanelViewModel.BarPoint]
        if shouldSmooth {
            chartPoints = TrendProcessingHelper.movingAverage(
                for: rawPoints,
                window: smoothingWindowSize
            )
        } else {
            chartPoints = rawPoints
        }

        // 5.5. Construye el liveAnchor (dot suelto "hoy") cuando aplica.
        //      `startOfDay` estabiliza el `BarPoint` para que `PanelTrendData`
        //      Equatable mantenga su cache (sin esto, cada render cambia la
        //      fecha por microsegundos e invalida toda la struct observable).
        let liveAnchor: PanelViewModel.BarPoint?
        let liveAnchorNativeBalances: [String: Decimal]?
        if let info = liveBalanceOverride, metric == .balance, !rawPoints.isEmpty {
            let anchorDate = calendar.startOfDay(for: Date.now)
            liveAnchor = PanelViewModel.BarPoint(date: anchorDate, value: info.value)
            liveAnchorNativeBalances = info.nativeBalances
        } else {
            liveAnchor = nil
            liveAnchorNativeBalances = nil
        }

        let finalBalance = liveAnchor?.value ?? rawPoints.last?.value ?? 0

        // 6. yDomain: extiende para incluir el liveAnchor si cae fuera del
        //    rango histórico (sino quedaría clipped al renderizarse).
        var yDomain = TrendProcessingHelper.calculateYDomain(
            for: rawPoints,
            isExpense: metric == .expense
        )
        if let anchorValue = liveAnchor?.value {
            yDomain = expand(yDomain, toInclude: anchorValue)
        }

        return TrendProcessingResult(
            points: chartPoints,
            rawPoints: rawPoints,
            yDomain: yDomain,
            totalIncome: totalIncome,
            totalExpense: totalExpense,
            finalBalance: finalBalance,
            liveAnchor: liveAnchor,
            liveAnchorNativeBalances: liveAnchorNativeBalances
        )
    }

    // MARK: - Private Helpers

    private static func expand(
        _ range: ClosedRange<Double>, toInclude value: Double
    ) -> ClosedRange<Double> {
        min(range.lowerBound, value)...max(range.upperBound, value)
    }

    /// Fill balance buckets with running balance calculation
    private static func fillBalanceBuckets(
        _ buckets: inout [Date: Double],
        transactions: [TransactionItem],
        accounts: [Account],
        interval: DateInterval,
        grouping: TrendGrouping,
        calendar: Calendar
    ) {
        // Start with 0 - initial balance is now a transaction
        var runningBalance = 0.0

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

    /// Fill buckets with cumulative (running total) values for income/expense
    private static func fillCumulativeBuckets(
        _ buckets: inout [Date: Double],
        transactions: [TransactionItem],
        grouping: TrendGrouping,
        calendar: Calendar,
        valueTransform: (TransactionItem) -> Double
    ) {
        // Group transactions by bucket date
        let transactionsByBucket = Dictionary(
            grouping: transactions
        ) { transaction in
            grouping.dateKey(for: transaction.date, calendar: calendar)
        }

        // Fill buckets with cumulative sum
        var runningTotal: Double = 0
        let sortedDates = buckets.keys.sorted()

        for date in sortedDates {
            if let txns = transactionsByBucket[date] {
                for txn in txns {
                    runningTotal += valueTransform(txn)
                }
            }
            buckets[date] = runningTotal
        }
    }
}
