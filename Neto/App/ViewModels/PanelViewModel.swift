import Foundation
import SwiftData
import SwiftUI

@Observable
final class PanelViewModel {

    // MARK: - State

    var selectedAccountID: PersistentIdentifier?
    var leadingColumnIndex: Int? = 0

    // Period Filter State (Removed - forced to This Year Tight Range)
    // var panelPeriodType... removed
    // var customPeriodStart... removed

    // Draft state (Removed)

    // Trend State
    var chartTransactions: [ChartTransaction] = []
    var balanceStatus: BalanceStatus = .unknown
    var historicalThreshold: Double = 0
    var trendGrouping: TrendGrouping = .day
    var trendType: TrendType = .balance
    var focusedDate: Date? = nil  // Global Focus State

    // MARK: - Dependencies / Configuration

    // We keep these as simple properties or computed ones based on what the View passes
    // or we can load them if we want to move AppStorage here (requires a wrapper or passing values).
    // For simplicity in MVVM with SwiftUI, we can keep AppStorage in View and sync,
    // OR use a PersistenceController.
    // However, to strictly follow the plan: "Move state variables... Move logic".

    // Let's handle the logic that doesn't depend on View-specific property wrappers like @Query directly,
    // or accept the data in methods.

    // MARK: - Computed Logic

    /// Returns active accounts sorted by the user's custom order.
    func orderedActiveAccounts(from accounts: [Account], sortOrderNames: [String]) -> [Account] {
        let activeAccounts = accounts.filter { !$0.isArchived }
        let indexByName = Dictionary(
            uniqueKeysWithValues: sortOrderNames.enumerated().map { ($1, $0) })

        return activeAccounts.sorted { a, b in
            let ia = indexByName[a.name]
            let ib = indexByName[b.name]

            switch (ia, ib) {
            case (let x?, let y?):
                return x < y
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            default:
                return a.name < b.name
            }
        }
    }

    /// Calculates the total balance in the default currency.
    func totalBalanceInDefaultCurrency(
        accounts: [Account],
        transactions: [TransactionItem],
        defaultCurrencyCode: String
    ) -> Double {
        let preferredCurrency = CurrencyCode(rawValue: defaultCurrencyCode) ?? .pen

        let eligibleAccounts = accounts.filter { account in
            !account.isArchived && !account.excludeFromStatistics
        }

        // Optimized: Calculate all balances in one pass
        let balances = AccountBalanceCalculator.batchCalculateBalances(
            accounts: eligibleAccounts,
            transactions: transactions
        )

        let totalDecimal: Decimal = eligibleAccounts.reduce(0) { partial, account in
            let currentBalance = balances[account.persistentModelID] ?? 0

            let sourceCurrency =
                CurrencyCode(rawValue: normalizeCurrencyCode(account.currencyCode))
                ?? preferredCurrency

            let converted = convertToPreferredCurrency(
                amount: currentBalance,
                from: sourceCurrency,
                to: preferredCurrency
            )

            return partial + converted
        }

        return (totalDecimal as NSDecimalNumber).doubleValue
    }

    /// Calculates the displayed balance (either total or selected account).
    func displayedBalanceInDefaultCurrency(
        accounts: [Account],
        transactions: [TransactionItem],
        defaultCurrencyCode: String
    ) -> Double {
        let preferredCurrency = CurrencyCode(rawValue: defaultCurrencyCode) ?? .pen

        if let selectedID = selectedAccountID,
            let account = accounts.first(where: { $0.persistentModelID == selectedID }),
            !account.isArchived,
            !account.excludeFromStatistics
        {
            let currentBalanceDecimal = AccountBalanceCalculator.currentBalance(
                for: account,
                allTransactions: transactions
            )

            let sourceCurrency =
                CurrencyCode(rawValue: normalizeCurrencyCode(account.currencyCode))
                ?? preferredCurrency

            let converted = convertToPreferredCurrency(
                amount: currentBalanceDecimal,
                from: sourceCurrency,
                to: preferredCurrency
            )

            return (converted as NSDecimalNumber).doubleValue
        }

        return totalBalanceInDefaultCurrency(
            accounts: accounts,
            transactions: transactions,
            defaultCurrencyCode: defaultCurrencyCode
        )
    }

    /// Calculates the total expense for the currently displayed period (Year).
    func totalExpenseInDefaultCurrency(
        accounts: [Account],
        transactions: [TransactionItem],
        defaultCurrencyCode: String
    ) -> Double {

        // Use the calculated chartTransactions which are already filtered for Year & Eligible Accounts
        // But chartTransactions are 'ChartTransaction' type. We need the raw value.
        // Actually, 'chartTransactions' contains daily summaries.
        // We can just sum the 'expense' property of chartTransactions.

        return chartTransactions.reduce(0) { $0 + $1.expense }
    }

    /// Returns transactions filtered by the focused date, or all transactions if no focus.
    func transactions(filteredBy focusedDate: Date?, from allTransactions: [TransactionItem])
        -> [TransactionItem]
    {
        guard let focusedDate = focusedDate else {
            return allTransactions
        }
        let calendar = Calendar.current
        return allTransactions.filter {
            calendar.isDate($0.date, inSameDayAs: focusedDate)
        }
    }

    // MARK: - Helpers

    func ensureAccountsSortOrderConsistency(
        accounts: [Account],
        currentOrderRaw: String
    ) -> String {
        let activeAccounts = accounts.filter { !$0.isArchived }
        let activeNames = activeAccounts.map { $0.name }

        if activeNames.isEmpty {
            return ""
        }

        let currentOrder = currentOrderRaw.split(separator: "|").map(String.init)
        var newOrder = currentOrder.filter { activeNames.contains($0) }

        for name in activeNames where !newOrder.contains(name) {
            newOrder.append(name)
        }

        return newOrder.joined(separator: "|")
    }

    private func convertToPreferredCurrency(
        amount: Decimal,
        from source: CurrencyCode,
        to target: CurrencyCode
    ) -> Decimal {
        if source == target {
            return amount
        }

        // Tasas de ejemplo (mismas que en PanelView original)
        let usdToPen = Decimal(string: "3.54") ?? Decimal(3.54)
        let eurToPen = Decimal(string: "3.89") ?? Decimal(3.89)

        func penToUsd(_ pen: Decimal) -> Decimal {
            guard usdToPen != 0 else { return pen }
            return pen / usdToPen
        }

        func penToEur(_ pen: Decimal) -> Decimal {
            guard eurToPen != 0 else { return pen }
            return pen / eurToPen
        }

        let amountInPen: Decimal
        switch source {
        case .pen:
            amountInPen = amount
        case .usd:
            amountInPen = amount * usdToPen
        case .eur:
            amountInPen = amount * eurToPen
        }

        switch target {
        case .pen:
            return amountInPen
        case .usd:
            return penToUsd(amountInPen)
        case .eur:
            return penToEur(amountInPen)
        }
    }

    // MARK: - Trend Logic (Year Only - Tight Range)

    /// Intervalo de fecha calculado:
    /// - Desde: La primera transacción del año actual (o 1 de Enero si vacío)
    /// - Hasta: La última transacción del año actual (o Hoy / 31 Dic si vacío)
    var panelDateInterval: DateInterval {
        let calendar = Calendar.current
        let now = Date()
        let startOfYear = calendar.dateInterval(of: .year, for: now)?.start ?? now
        let endOfYear = calendar.dateInterval(of: .year, for: now)?.end ?? now

        // 1. Filter transactions to current year
        let yearTransactions = chartTransactions.filter {
            $0.date >= startOfYear && $0.date < endOfYear
        }

        // 2. Find min and max
        guard let minDate = yearTransactions.map(\.date).min(),
            let maxDate = yearTransactions.map(\.date).max()
        else {
            // Fallback: Start of Year to Now (or End of Year?)
            // If no data, just show Year To Date? or the whole empty year?
            // "que no haya vacio a los lados" implies purely data driven.
            // If no data, maybe just Today?
            return DateInterval(start: startOfYear, end: now)
        }

        // 3. Return tight range
        // Add a small buffer? User said "limite inferior y superior las fechas minima y maxima".
        // So EXACT match.
        return DateInterval(start: minDate, end: maxDate)
    }

    // MARK: - Trend & Balance Status Logic

    /// Calculates trend data and status based on the current period and selected account.
    /// Calculates trend data and status based on the current period and selected account.
    func calculateTrendData(
        accounts: [Account],
        transactions: [TransactionItem],
        defaultCurrencyCode: String
    ) {
        let preferredCurrency = CurrencyCode(rawValue: defaultCurrencyCode) ?? .pen

        // For the chart, we want ALL transactions relative to the computed tight interval?
        // Actually, we usually calculate trend data for the *visible* interval.
        // But `panelDateInterval` now depends on `chartTransactions`. Circular dependency?
        // Ah, `panelDateInterval` is computed property based on `chartTransactions`.
        // So here we must first prepare ALL transactions, then let the view or a second pass determine the interval?
        //
        // Strategy:
        // 1. Calculate balances for ALL TIME (or at least this year).
        // 2. Store them in `chartTransactions`.
        // 3. `panelDateInterval` then reads `chartTransactions` to find min/max.

        // Let's modify filterTransactionsForPanel logic inline since we deleted the helper.
        // We want all transactions for the *current year* to be processed.
        let calendar = Calendar.current
        let now = Date()
        let yearInterval =
            calendar.dateInterval(of: .year, for: now) ?? DateInterval(start: now, end: now)

        // 1. Determine Eligible Accounts
        // We must calculate trend based on active, non-excluded accounts that matched the selection (if any).
        let eligibleAccounts = accounts.filter { account in
            !account.isArchived && !account.excludeFromStatistics
                && (selectedAccountID == nil || account.persistentModelID == selectedAccountID)
        }
        let eligibleAccountIDs = Set(eligibleAccounts.map { $0.persistentModelID })

        // 2. Filter Transactions
        // Must be in the Year AND belong to an eligible account
        let filteredTransactions = transactions.filter { tx in
            // Filter by Account Eligibility
            guard let account = tx.account, eligibleAccountIDs.contains(account.persistentModelID)
            else {
                return false
            }
            // Filter by Year
            return yearInterval.contains(tx.date)
        }

        let interval = yearInterval

        // 4. Transform to ChartTransactions (Balance Trend Series)
        // We want a continuous line of the user's balance over time.
        // Logic:
        // 1. Calculate Initial Balance (before interval).
        // 2. Iterate each day in interval.
        // 3. Apply transactions for that day.
        // 4. Store [Date: Balance].

        var processedTransactions: [ChartTransaction] = []
        var runningBalance = initialBalanceForTrend(
            accounts: eligibleAccounts,
            transactions: transactions,
            before: interval.start,
            preferredCurrency: preferredCurrency
        )

        // Group filtered transactions by Day for easier lookup
        // Note: 'calendar' is already defined above as Calendar.current
        let transactionsByDay = Dictionary(grouping: filteredTransactions) { tx in
            calendar.startOfDay(for: tx.date)
        }

        // Iterate day by day through the full interval
        var currentDate = interval.start

        // Aux vars for status (still calculated based on period totals vs historical)
        // Note: Total Income/Expense logic is slightly independent of balance trend
        // but required for side-stats if needed.

        // Optimization: Pre-calculate end date to avoid infinite loops

        while currentDate < interval.end {
            let startOfDay = calendar.startOfDay(for: currentDate)
            let dailyTransactions = transactionsByDay[startOfDay] ?? []

            var dailyIncome: Double = 0
            var dailyExpense: Double = 0

            for tx in dailyTransactions {
                // Ensure currency normalization
                let normalizedCode = normalizeCurrencyCode(tx.currencyCode)

                let amount = convertToPreferredCurrency(
                    amount: Decimal(tx.amount),
                    from: CurrencyCode(rawValue: normalizedCode) ?? preferredCurrency,
                    to: preferredCurrency
                )
                let amountDouble = (amount as NSDecimalNumber).doubleValue

                // Determine direction based on category or value
                let isIncome = tx.category?.isIncome ?? (amountDouble >= 0)

                if isIncome {
                    dailyIncome += abs(amountDouble)
                    runningBalance += abs(amountDouble)
                } else {
                    dailyExpense += abs(amountDouble)
                    runningBalance -= abs(amountDouble)
                }
            }

            // Append point for this day with the End-of-Day balance
            processedTransactions.append(
                ChartTransaction(
                    id: UUID(),
                    date: startOfDay,
                    income: dailyIncome,
                    expense: dailyExpense,
                    balance: runningBalance
                )
            )

            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else {
                break
            }
            currentDate = nextDate
        }

        self.chartTransactions = processedTransactions

        // 5. Calculate Historical Threshold & Status
        // Use the final runningBalance
        calculateStatus(
            accounts: eligibleAccounts,
            transactions: transactions,
            currentBalance: runningBalance,
            preferredCurrency: preferredCurrency,
            currentInterval: interval
        )
    }

    private func initialBalanceForTrend(
        accounts: [Account],
        transactions: [TransactionItem],
        before date: Date,
        preferredCurrency: CurrencyCode
    ) -> Double {
        // Calculate balance of all eligible accounts up to 'date'
        // This is expensive if done naively.
        // Optimization: Use AccountBalanceCalculator logic but filtered by date.

        // For now, let's reuse the batch calculator but we need it to support a cutoff date.
        // Since AccountBalanceCalculator might not support cutoff, we do a manual sum here.
        // Or better: Current Balance - Transactions AFTER date.

        // Let's go with: Sum of initial balances + Sum of all transactions BEFORE date.

        var total: Decimal = 0

        for account in accounts {
            let sourceCurrency =
                CurrencyCode(rawValue: normalizeCurrencyCode(account.currencyCode))
                ?? preferredCurrency

            // Initial Balance
            let initial = convertToPreferredCurrency(
                amount: Decimal(account.initialBalance),
                from: sourceCurrency,
                to: preferredCurrency
            )
            total += initial
        }

        let pastTransactions = transactions.filter { $0.date < date }
        let eligibleAccountIDs = Set(accounts.map { $0.persistentModelID })

        for tx in pastTransactions {
            guard let account = tx.account, eligibleAccountIDs.contains(account.persistentModelID)
            else { continue }

            let sourceCurrency =
                CurrencyCode(rawValue: normalizeCurrencyCode(tx.currencyCode)) ?? preferredCurrency
            let amount = convertToPreferredCurrency(
                amount: Decimal(tx.amount),
                from: sourceCurrency,
                to: preferredCurrency
            )

            // Logic: Income adds, Expense subtracts.
            // If amount is signed in DB, just add. If absolute, check category.
            // Assuming signed storage for now based on standard practices,
            // BUT `TransactionItem` doesn't seem to enforce sign.
            // Let's check `Category.isIncome`.

            let isIncome = tx.category?.isIncome ?? (tx.amount >= 0)
            if isIncome {
                total += abs(amount)
            } else {
                total -= abs(amount)
            }
        }

        return (total as NSDecimalNumber).doubleValue
    }

    private func calculateStatus(
        accounts: [Account],
        transactions: [TransactionItem],
        currentBalance: Double,
        preferredCurrency: CurrencyCode,
        currentInterval: DateInterval
    ) {
        // Historical Threshold: Average balance of the PREVIOUS period of same duration.

        let previousEnd = currentInterval.start

        // We need the average daily balance of that period? Or the End Balance?
        // Requirement says: "umbral de gasto promedio en periodos inmediatamente pasados"
        // (average spending threshold in immediately past periods) OR "saldo actual ... respecto a un umbral histórico"

        // Let's interpret "Historical Threshold" as the Average End-of-Period Balance of the last 3 periods?
        // Or simply the Balance at the end of the previous period?

        // Let's try: Average Daily Balance of the previous period.
        // This represents the "normal" level of funds the user has.

        // Simplified approach for MVP: Compare Current Balance vs Balance exactly 1 period ago.
        let balanceOnePeriodAgo = initialBalanceForTrend(
            accounts: accounts,
            transactions: transactions,
            before: previousEnd,
            preferredCurrency: preferredCurrency
        )

        self.historicalThreshold = balanceOnePeriodAgo

        // Status Logic
        // Green (Good): > Threshold + 5%
        // Red (Critical): < Threshold - 5%
        // Normal: Within +/- 5%

        let diff = currentBalance - historicalThreshold
        let percentage = historicalThreshold == 0 ? 0 : (diff / abs(historicalThreshold))

        if percentage > 0.05 {
            balanceStatus = .good
        } else if percentage < -0.05 {
            balanceStatus = .critical
        } else {
            balanceStatus = .normal
        }
    }
}
