//
//  FullFinancialContextBuilder.swift
//  Yala
//
//  Builds the FullFinancialContext from SwiftData. Reuses existing calculators
//  to avoid duplicating financial logic. Caches the result for 60s (per builder
//  instance) to avoid recomputing across rapid successive chat questions.
//
//  Edge cases handled (per plan):
//   - 0 transacciones → shape válido con arrays vacíos
//   - tx.category == nil → bucket `uncategorized` explícito
//   - account.excludeFromStatistics / isArchived → excluido + listado en metadata
//   - tx.balanceAdjustmentType != nil → filtrado
//   - tx.date > now → filtrado (drafts en futuro)
//   - multi-currency → amountInPreferredCurrency con guard isFinite
//   - budget.limitAmount == 0 → status="no_limit", usage_pct=null
//   - 5+ años de data → fetch acotado a últimos 13 meses
//

import Foundation
import SwiftData

@MainActor
final class FullFinancialContextBuilder {

    // MARK: - Cache (60s TTL)

    private struct CacheEntry {
        let context: FullFinancialContext
        let timestamp: Date
        let includedAnomalies: Bool
    }

    private var cache: CacheEntry?
    private static let ttlSeconds: TimeInterval = 60

    // MARK: - Build

    /// Build the context. If cache is fresh (<60s) and matches the anomaly request,
    /// returns cached. Otherwise rebuilds.
    func build(
        modelContext: ModelContext,
        currencyCode: String,
        currencyDisplay: String,
        converter: CurrencyConverting,
        language: String,
        country: String,
        includeAnomalies: Bool,
        now: Date = .now
    ) -> FullFinancialContext {
        let calendar = Calendar.current
        let fetchStart = calendar.date(byAdding: .month, value: -13, to: now) ?? now
        return buildFromArrays(
            transactions: fetchTransactions(modelContext, from: fetchStart, to: now),
            budgets: fetchBudgets(modelContext),
            accounts: fetchAccounts(modelContext),
            tags: fetchTags(modelContext),
            scheduledPayments: fetchScheduledPayments(modelContext),
            currencyCode: currencyCode,
            currencyDisplay: currencyDisplay,
            converter: converter,
            language: language,
            country: country,
            includeAnomalies: includeAnomalies,
            now: now
        )
    }

    /// Pure build entry point — operates on in-memory arrays so tests can avoid
    /// instantiating a ModelContext (whose CloudKit container has a known race
    /// condition in suite mode). Production callers use `build(modelContext:...)`
    /// which fetches and delegates here.
    func buildFromArrays(
        transactions: [TransactionItem],
        budgets: [Budget],
        accounts: [Account],
        tags: [Tag],
        scheduledPayments: [ScheduledPayment],
        currencyCode: String,
        currencyDisplay: String,
        converter: CurrencyConverting,
        language: String,
        country: String,
        includeAnomalies: Bool,
        now: Date = .now
    ) -> FullFinancialContext {
        if let entry = cache,
           now.timeIntervalSince(entry.timestamp) < Self.ttlSeconds,
           includeAnomalies == false || entry.includedAnomalies {
            return entry.context
        }

        let calendar = Calendar.current
        let allTx = transactions
        let allBudgets = budgets
        let allAccounts = accounts
        let allTags = tags
        let scheduledPayments = scheduledPayments
        let excludedAccountNames = allAccounts
            .filter { $0.excludeFromStatistics || $0.isArchived }
            .map(\.name)

        // Filter excluded/balance-adjustment/future TX once
        let eligibleTx = allTx.filter { tx in
            tx.balanceAdjustmentType == nil
                && tx.account?.excludeFromStatistics != true
                && tx.account?.isArchived != true
                && tx.date <= now
        }

        let intervals = buildIntervals(now: now, calendar: calendar)
        // `!= true` keeps tx with category=nil in the expense bucket → uncategorized
        // bucket sees them. Income tx (isIncome==true) are excluded.
        let currentMonthExpenseTx = eligibleTx.filter {
            intervals.currentMonth.contains($0.date) && $0.category?.isIncome != true
        }

        let metadata = buildMetadata(
            now: now,
            currency: currencyCode,
            currencyDisplay: currencyDisplay,
            language: language,
            country: country,
            excludedAccountNames: excludedAccountNames,
            calendar: calendar
        )

        let balances = buildBalances(
            accounts: allAccounts.filter { !$0.excludeFromStatistics && !$0.isArchived },
            allRawTx: allTx,
            preferredCurrency: currencyCode,
            converter: converter
        )

        let periods = buildPeriods(
            tx: eligibleTx,
            intervals: intervals,
            currencyCode: currencyCode,
            converter: converter,
            now: now,
            calendar: calendar
        )

        let categories = buildCategories(
            tx: eligibleTx,
            intervals: intervals,
            currencyCode: currencyCode,
            converter: converter
        )

        let uncategorized = buildUncategorized(
            tx: currentMonthExpenseTx,
            converter: converter,
            currencyCode: currencyCode
        )

        let merchantsTop20 = buildMerchantsTop20(
            tx: eligibleTx,
            intervals: intervals,
            currencyCode: currencyCode,
            converter: converter
        )

        let budgets = buildBudgets(
            allBudgets: allBudgets,
            allTx: eligibleTx,
            converter: converter,
            now: now,
            calendar: calendar
        )

        let recurring = buildRecurring(
            scheduledPayments: scheduledPayments,
            currencyCode: currencyCode,
            converter: converter,
            now: now,
            calendar: calendar,
            currentMonthInterval: intervals.currentMonth
        )

        let patterns = buildPatterns(
            tx: eligibleTx,
            currencyCode: currencyCode,
            converter: converter,
            now: now,
            calendar: calendar
        )

        let tagsTop10 = buildTagsTop10(
            tx: currentMonthExpenseTx,
            allTags: allTags,
            currencyCode: currencyCode,
            converter: converter,
            currentMonthInterval: intervals.currentMonth
        )

        let topTxBySubcategory = buildTopTxBySubcategory(
            tx: currentMonthExpenseTx,
            currencyCode: currencyCode,
            converter: converter
        )

        let anomalies: [AnomalyEntry]? = includeAnomalies
            ? AnomalyDetectionCalculator.detect(
                allTransactions: eligibleTx,
                periodTransactions: currentMonthExpenseTx,
                interval: intervals.currentMonth,
                currencyCode: currencyCode,
                converter: converter
            )
            : nil

        let context = FullFinancialContext(
            metadata: metadata,
            balances: balances,
            periods: periods,
            categories: categories,
            uncategorized: uncategorized,
            merchantsTop20: merchantsTop20,
            budgets: budgets,
            recurring: recurring,
            patterns: patterns,
            tagsTop10: tagsTop10,
            topTxBySubcategory: topTxBySubcategory,
            anomalies: anomalies
        )

        cache = CacheEntry(
            context: context,
            timestamp: now,
            includedAnomalies: includeAnomalies
        )
        return context
    }

    /// Manually invalidate cache. Not normally needed (TTL handles staleness) but
    /// useful for tests.
    func invalidateCache() {
        cache = nil
    }

    // MARK: - Intervals

    private struct Intervals {
        let today: DateInterval
        let currentWeek: DateInterval
        let lastWeek: DateInterval
        let last4Weeks: [DateInterval] // index 0 = oldest, 3 = current
        let currentMonth: DateInterval
        let lastMonth: DateInterval
        let twoMonthsAgo: DateInterval
        let threeMonthsAgo: DateInterval
        let currentYear: DateInterval
        let last30Days: DateInterval
    }

    private func buildIntervals(now: Date, calendar: Calendar) -> Intervals {
        let startOfToday = calendar.startOfDay(for: now)
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? startOfToday
        let prevWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: weekStart) ?? startOfToday
        let monthStart = calendar.dateInterval(of: .month, for: now)?.start ?? startOfToday
        let lastMonthStart = calendar.date(byAdding: .month, value: -1, to: monthStart) ?? startOfToday
        let twoMonthsAgoStart = calendar.date(byAdding: .month, value: -2, to: monthStart) ?? startOfToday
        let threeMonthsAgoStart = calendar.date(byAdding: .month, value: -3, to: monthStart) ?? startOfToday
        let yearStart = calendar.dateInterval(of: .year, for: now)?.start ?? startOfToday
        let last30Start = calendar.date(byAdding: .day, value: -30, to: now) ?? startOfToday

        var weeks: [DateInterval] = []
        for i in stride(from: 3, through: 0, by: -1) {
            if let start = calendar.date(byAdding: .weekOfYear, value: -i, to: weekStart),
               let end = calendar.date(byAdding: .weekOfYear, value: 1, to: start) {
                weeks.append(DateInterval(start: start, end: end))
            }
        }

        return Intervals(
            today: DateInterval(start: startOfToday, end: now),
            currentWeek: DateInterval(start: weekStart, end: now),
            lastWeek: DateInterval(start: prevWeekStart, end: weekStart),
            last4Weeks: weeks,
            currentMonth: DateInterval(start: monthStart, end: now),
            lastMonth: DateInterval(start: lastMonthStart, end: monthStart),
            twoMonthsAgo: DateInterval(start: twoMonthsAgoStart, end: lastMonthStart),
            threeMonthsAgo: DateInterval(start: threeMonthsAgoStart, end: twoMonthsAgoStart),
            currentYear: DateInterval(start: yearStart, end: now),
            last30Days: DateInterval(start: last30Start, end: now)
        )
    }

    // MARK: - Sub-builders

    private func buildMetadata(
        now: Date,
        currency: String,
        currencyDisplay: String,
        language: String,
        country: String,
        excludedAccountNames: [String],
        calendar: Calendar
    ) -> FullFinancialContext.Metadata {
        let weekdaySymbols = calendar.weekdaySymbols
        let weekdayIdx = calendar.component(.weekday, from: now)
        let weekday = (weekdayIdx >= 1 && weekdayIdx <= 7) ? weekdaySymbols[weekdayIdx - 1] : ""

        let monthLabelFormatter = DateFormatter()
        monthLabelFormatter.dateFormat = "MMMM yyyy"
        monthLabelFormatter.locale = Locale(identifier: language)

        return FullFinancialContext.Metadata(
            dateToday: Self.isoDateFormatter.string(from: now),
            weekday: weekday,
            monthLabel: monthLabelFormatter.string(from: now),
            currency: currency,
            currencyDisplay: currencyDisplay,
            language: language,
            country: country,
            excludedAccounts: excludedAccountNames
        )
    }

    private func buildBalances(
        accounts: [Account],
        allRawTx: [TransactionItem],
        preferredCurrency: String,
        converter: CurrencyConverting
    ) -> FullFinancialContext.BalancesSection {
        let entries = accounts.map { account in
            let balance = InitialBalanceService.currentBalance(for: account, allTransactions: allRawTx)
            return FullFinancialContext.AccountEntry(
                name: account.name,
                type: account.type,
                balance: safeDouble(balance),
                currency: account.currencyCode
            )
        }
        // Balance enviado al LLM: TC actual sobre saldo nativo (LiveBalanceCalculator)
        // en vez de suma de snapshots históricos — el LLM debe ver el saldo
        // disponible HOY, no la acumulación con TCs de distintos momentos.
        let total = LiveBalanceCalculator.liveBalance(
            accounts: accounts,
            transactions: allRawTx,
            preferredCurrencyCode: preferredCurrency,
            converter: converter
        )
        return FullFinancialContext.BalancesSection(
            accounts: entries,
            totalBalance: safeDouble(total)
        )
    }

    private func buildPeriods(
        tx: [TransactionItem],
        intervals: Intervals,
        currencyCode: String,
        converter: CurrencyConverting,
        now: Date,
        calendar: Calendar
    ) -> FullFinancialContext.PeriodsSection {
        func summarize(_ interval: DateInterval) -> FullFinancialContext.PeriodSummary {
            let periodTx = tx.filter { interval.contains($0.date) }
            let cashFlow = CashFlowCalculator.calculateCashFlow(
                transactions: periodTx,
                interval: interval,
                grouping: .day,
                currencyCode: currencyCode,
                converter: converter
            )
            let days = max(1, calendar.dateComponents([.day], from: interval.start, to: min(interval.end, now)).day ?? 1)
            let dailyAvg = cashFlow.totalExpense / Double(days)
            let savingsRate: Double? = cashFlow.totalIncome > 0
                ? ((cashFlow.totalIncome - cashFlow.totalExpense) / cashFlow.totalIncome) * 100
                : nil
            return FullFinancialContext.PeriodSummary(
                income: safeDouble(cashFlow.totalIncome),
                expense: safeDouble(cashFlow.totalExpense),
                balance: safeDouble(cashFlow.netFlow),
                txCount: periodTx.count,
                dailyAvg: safeDouble(dailyAvg),
                savingsRatePercent: savingsRate.map(safeDouble)
            )
        }

        let weekSummaries: [FullFinancialContext.WeekSummary] = intervals.last4Weeks.map { interval in
            let weekTx = tx.filter { interval.contains($0.date) }
            let cashFlow = CashFlowCalculator.calculateCashFlow(
                transactions: weekTx,
                interval: interval,
                grouping: .day,
                currencyCode: currencyCode,
                converter: converter
            )
            return FullFinancialContext.WeekSummary(
                weekStart: Self.isoDateFormatter.string(from: interval.start),
                income: safeDouble(cashFlow.totalIncome),
                expense: safeDouble(cashFlow.totalExpense)
            )
        }

        return FullFinancialContext.PeriodsSection(
            today: summarize(intervals.today),
            currentWeek: summarize(intervals.currentWeek),
            lastWeek: summarize(intervals.lastWeek),
            last4Weeks: weekSummaries,
            currentMonth: summarize(intervals.currentMonth),
            lastMonth: summarize(intervals.lastMonth),
            twoMonthsAgo: summarize(intervals.twoMonthsAgo),
            threeMonthsAgo: summarize(intervals.threeMonthsAgo),
            currentYear: summarize(intervals.currentYear)
        )
    }

    private func buildCategories(
        tx: [TransactionItem],
        intervals: Intervals,
        currencyCode: String,
        converter: CurrencyConverting
    ) -> [FullFinancialContext.CategoryEntry] {
        let currentTx = tx.filter { intervals.currentMonth.contains($0.date) && $0.category?.isIncome == false }
        let lastMonthTx = tx.filter { intervals.lastMonth.contains($0.date) && $0.category?.isIncome == false }
        let twoMonthsAgoTx = tx.filter { intervals.twoMonthsAgo.contains($0.date) && $0.category?.isIncome == false }

        // Group by category name for each period
        var current: [String: (total: Double, count: Int)] = [:]
        var last: [String: Double] = [:]
        var twoBack: [String: Double] = [:]
        // Track tx by (categoryName -> subcategoryName -> totals)
        var subAgg: [String: [String: (current: Double, last: Double, twoBack: Double, count: Int)]] = [:]

        for tx in currentTx {
            let cat = tx.category?.name ?? "Other"
            let amount = convertAmount(tx, currencyCode: currencyCode, converter: converter)
            let entry = current[cat] ?? (total: 0, count: 0)
            current[cat] = (total: entry.total + amount, count: entry.count + 1)
            if let sub = tx.subcategory?.name {
                var subDict = subAgg[cat] ?? [:]
                let subEntry = subDict[sub] ?? (current: 0, last: 0, twoBack: 0, count: 0)
                subDict[sub] = (current: subEntry.current + amount, last: subEntry.last, twoBack: subEntry.twoBack, count: subEntry.count + 1)
                subAgg[cat] = subDict
            }
        }
        for tx in lastMonthTx {
            let cat = tx.category?.name ?? "Other"
            let amount = convertAmount(tx, currencyCode: currencyCode, converter: converter)
            last[cat, default: 0] += amount
            if let sub = tx.subcategory?.name {
                var subDict = subAgg[cat] ?? [:]
                let subEntry = subDict[sub] ?? (current: 0, last: 0, twoBack: 0, count: 0)
                subDict[sub] = (current: subEntry.current, last: subEntry.last + amount, twoBack: subEntry.twoBack, count: subEntry.count)
                subAgg[cat] = subDict
            }
        }
        for tx in twoMonthsAgoTx {
            let cat = tx.category?.name ?? "Other"
            let amount = convertAmount(tx, currencyCode: currencyCode, converter: converter)
            twoBack[cat, default: 0] += amount
            if let sub = tx.subcategory?.name {
                var subDict = subAgg[cat] ?? [:]
                let subEntry = subDict[sub] ?? (current: 0, last: 0, twoBack: 0, count: 0)
                subDict[sub] = (current: subEntry.current, last: subEntry.last, twoBack: subEntry.twoBack + amount, count: subEntry.count)
                subAgg[cat] = subDict
            }
        }

        // Top 10 categories by current month total (or last month if no current)
        let allCatNames = Set(current.keys).union(last.keys).union(twoBack.keys)
        let ranked = allCatNames.sorted { (a, b) in
            (current[a]?.total ?? 0) > (current[b]?.total ?? 0)
        }
        let topCats = Array(ranked.prefix(10))

        return topCats.map { catName in
            let cur = current[catName] ?? (total: 0, count: 0)
            let lastVal = last[catName] ?? 0
            let twoVal = twoBack[catName] ?? 0
            let variation: Double? = lastVal > 0 ? ((cur.total - lastVal) / lastVal) * 100 : nil

            // Subcategorías con tx > 0 en cualquiera de los 3 meses
            var subEntries: [FullFinancialContext.SubcategoryEntry] = []
            if let subDict = subAgg[catName] {
                let activeSubs = subDict.filter { $0.value.current > 0 || $0.value.last > 0 || $0.value.twoBack > 0 }
                let sortedSubs = activeSubs.sorted { $0.value.current > $1.value.current }
                subEntries = sortedSubs.map { (name, val) in
                    let subVar: Double? = val.last > 0 ? ((val.current - val.last) / val.last) * 100 : nil
                    return FullFinancialContext.SubcategoryEntry(
                        name: name,
                        totalCurrentMonth: safeDouble(val.current),
                        totalLastMonth: safeDouble(val.last),
                        totalTwoMonthsAgo: safeDouble(val.twoBack),
                        variationPercentVsLastMonth: subVar.map(safeDouble),
                        txCountCurrentMonth: val.count
                    )
                }
            }

            return FullFinancialContext.CategoryEntry(
                name: catName,
                totalCurrentMonth: safeDouble(cur.total),
                totalLastMonth: safeDouble(lastVal),
                totalTwoMonthsAgo: safeDouble(twoVal),
                variationPercentVsLastMonth: variation.map(safeDouble),
                txCountCurrentMonth: cur.count,
                subcategories: subEntries
            )
        }
    }

    private func buildUncategorized(
        tx: [TransactionItem],
        converter: CurrencyConverting,
        currencyCode: String
    ) -> FullFinancialContext.UncategorizedBucket {
        let unc = tx.filter { $0.category == nil }
        let total = unc.reduce(0.0) { $0 + convertAmount($1, currencyCode: currencyCode, converter: converter) }
        return FullFinancialContext.UncategorizedBucket(
            totalCurrentMonth: safeDouble(total),
            txCountCurrentMonth: unc.count
        )
    }

    private func buildMerchantsTop20(
        tx: [TransactionItem],
        intervals: Intervals,
        currencyCode: String,
        converter: CurrencyConverting
    ) -> [FullFinancialContext.MerchantEntry] {
        let currentTx = tx.filter { intervals.currentMonth.contains($0.date) && $0.category?.isIncome == false }
        let lastTx = tx.filter { intervals.lastMonth.contains($0.date) && $0.category?.isIncome == false }

        var current: [String: (total: Double, count: Int)] = [:]
        var last: [String: Double] = [:]

        for tx in currentTx {
            guard let merchant = canonicalMerchant(tx) else { continue }
            let amount = convertAmount(tx, currencyCode: currencyCode, converter: converter)
            let entry = current[merchant] ?? (total: 0, count: 0)
            current[merchant] = (total: entry.total + amount, count: entry.count + 1)
        }
        for tx in lastTx {
            guard let merchant = canonicalMerchant(tx) else { continue }
            let amount = convertAmount(tx, currencyCode: currencyCode, converter: converter)
            last[merchant, default: 0] += amount
        }

        let sorted = current.sorted { $0.value.total > $1.value.total }.prefix(20)
        return sorted.map { (name, val) in
            let lastVal = last[name] ?? 0
            let variation: Double? = lastVal > 0 ? ((val.total - lastVal) / lastVal) * 100 : nil
            let avg = val.count > 0 ? val.total / Double(val.count) : 0
            return FullFinancialContext.MerchantEntry(
                name: name,
                totalCurrentMonth: safeDouble(val.total),
                totalLastMonth: safeDouble(lastVal),
                txCount: val.count,
                avgAmount: safeDouble(avg),
                variationPercentVsLastMonth: variation.map(safeDouble)
            )
        }
    }

    private func buildBudgets(
        allBudgets: [Budget],
        allTx: [TransactionItem],
        converter: CurrencyConverting,
        now: Date,
        calendar: Calendar
    ) -> [FullFinancialContext.BudgetEntry] {
        let active = allBudgets.filter { $0.isActive }
        // Pre-index expense tx by category ID — single O(n) pass, then O(1) lookup per budget.
        var byCategory: [PersistentIdentifier: [TransactionItem]] = [:]
        for tx in allTx where tx.category?.isIncome == false {
            guard let id = tx.category?.persistentModelID else { continue }
            byCategory[id, default: []].append(tx)
        }
        return active.map { budget in
            let interval = InsightsCalculator.currentBudgetInterval(for: budget)
            let categoryTx: [TransactionItem] = {
                guard let id = budget.category?.persistentModelID else { return [] }
                return byCategory[id] ?? []
            }()
            let budgetTx = categoryTx.filter { interval.contains($0.date) }
            let spent = budgetTx.reduce(0.0) { sum, tx in
                let converted = converter.convert(
                    Decimal(abs(tx.amount)),
                    from: tx.currencyCode,
                    to: budget.currencyCode,
                    on: tx.date
                )
                return sum + safeDouble(NSDecimalNumber(decimal: converted).doubleValue)
            }
            let limit = budget.limitAmount
            let usagePct: Double? = limit > 0 ? (spent / limit) * 100 : nil
            let daysLeft = max(0, calendar.dateComponents([.day], from: now, to: interval.end).day ?? 0)
            let status: FullFinancialContext.BudgetStatus
            if limit <= 0 {
                status = .noLimit
            } else if (usagePct ?? 0) >= 100 {
                status = .exceeded
            } else if (usagePct ?? 0) >= 75 {
                status = .atRisk
            } else {
                status = .onTrack
            }
            return FullFinancialContext.BudgetEntry(
                name: budget.name,
                category: budget.category?.name,
                limit: safeDouble(limit),
                spent: safeDouble(spent),
                usagePercent: usagePct.map(safeDouble),
                daysLeft: daysLeft,
                status: status,
                periodType: budget.periodType,
                currency: budget.currencyCode
            )
        }
    }

    private func buildRecurring(
        scheduledPayments: [ScheduledPayment],
        currencyCode: String,
        converter: CurrencyConverting,
        now: Date,
        calendar: Calendar,
        currentMonthInterval: DateInterval
    ) -> FullFinancialContext.RecurringSection {
        let active = scheduledPayments.filter { $0.isActive }

        // Paid this month: dates within currentMonthInterval AND <= now
        var paid: [FullFinancialContext.RecurringPaidEntry] = []
        // Pending next 30 days: dates > now AND <= now+30
        var pending: [FullFinancialContext.RecurringPendingEntry] = []
        let cutoffPending = calendar.date(byAdding: .day, value: 30, to: now) ?? now

        // Check current and next month for pending; current and prev for paid
        let monthsToCheck = [
            calendar.date(byAdding: .month, value: -1, to: now) ?? now,
            now,
            calendar.date(byAdding: .month, value: 1, to: now) ?? now
        ]

        var seenPaid: Set<String> = []
        var seenPending: Set<String> = []

        for monthDate in monthsToCheck {
            for payment in active {
                let dates = ScheduledPaymentDateCalculator.paymentDatesInMonth(
                    params: payment.dateCalculatorParams,
                    month: monthDate,
                    calendar: calendar
                )
                for date in dates where !payment.isDateSkipped(date) {
                    let amount: Double
                    if payment.currencyCode == currencyCode {
                        amount = abs(payment.amount)
                    } else {
                        let converted = converter.convert(
                            Decimal(abs(payment.amount)),
                            from: payment.currencyCode,
                            to: currencyCode,
                            on: date
                        )
                        amount = safeDouble(NSDecimalNumber(decimal: converted).doubleValue)
                    }
                    let key = "\(payment.id)-\(Self.isoDateFormatter.string(from: date))"

                    if currentMonthInterval.contains(date) && date <= now && payment.transactionType == "expense" {
                        if seenPaid.insert(key).inserted {
                            paid.append(FullFinancialContext.RecurringPaidEntry(
                                name: payment.name,
                                amount: amount,
                                date: Self.isoDateFormatter.string(from: date),
                                category: payment.subcategory?.category?.name,
                                subcategory: payment.subcategory?.name
                            ))
                        }
                    } else if date > now && date <= cutoffPending {
                        if seenPending.insert(key).inserted {
                            let type = payment.isRecurring ? payment.paymentCategory : "one_time"
                            pending.append(FullFinancialContext.RecurringPendingEntry(
                                name: payment.name,
                                amount: amount,
                                dueDate: Self.isoDateFormatter.string(from: date),
                                category: payment.subcategory?.category?.name,
                                subcategory: payment.subcategory?.name,
                                type: type
                            ))
                        }
                    }
                }
            }
        }
        paid.sort { $0.date < $1.date }
        pending.sort { $0.dueDate < $1.dueDate }

        let subscriptions = monthlyTotal(for: active, paymentCategory: "subscription", currencyCode: currencyCode, converter: converter, now: now)
        let recurring = monthlyTotal(for: active, paymentCategory: "recurring", currencyCode: currencyCode, converter: converter, now: now)

        return FullFinancialContext.RecurringSection(
            paidThisMonth: paid,
            pendingNext30Days: pending,
            totals: FullFinancialContext.RecurringTotals(
                subscriptionsMonthly: safeDouble(subscriptions),
                recurringMonthly: safeDouble(recurring)
            )
        )
    }

    private func monthlyTotal(
        for payments: [ScheduledPayment],
        paymentCategory: String,
        currencyCode: String,
        converter: CurrencyConverting,
        now: Date
    ) -> Double {
        payments
            .filter { $0.paymentCategory == paymentCategory && $0.transactionType == "expense" }
            .reduce(0.0) { sum, p in
                let converted = converter.convert(
                    Decimal(abs(p.amount)),
                    from: p.currencyCode,
                    to: currencyCode,
                    on: now
                )
                let baseDouble = safeDouble(NSDecimalNumber(decimal: converted).doubleValue)
                return sum + baseDouble * monthlyMultiplier(p)
            }
    }

    private func monthlyMultiplier(_ payment: ScheduledPayment) -> Double {
        guard payment.isRecurring else { return 1.0 }
        let interval = max(1, payment.recurrenceInterval)
        let type = RecurrenceType(rawValue: payment.recurrenceType) ?? .monthly
        switch type {
        case .daily: return 30.0 / Double(interval)
        case .weekly: return 4.33 / Double(interval)
        case .monthly: return 1.0 / Double(interval)
        case .yearly: return 1.0 / (12.0 * Double(interval))
        }
    }

    private func buildPatterns(
        tx: [TransactionItem],
        currencyCode: String,
        converter: CurrencyConverting,
        now: Date,
        calendar: Calendar
    ) -> FullFinancialContext.PatternsSection {
        let last30Start = calendar.date(byAdding: .day, value: -30, to: now) ?? now
        let last30Interval = DateInterval(start: last30Start, end: now)
        let last30Tx = tx.filter { last30Interval.contains($0.date) && $0.category?.isIncome == false }

        let weekdayData = WeekdaySpendingCalculator.calculate(
            transactions: last30Tx,
            interval: last30Interval,
            currencyCode: currencyCode,
            converter: converter
        )
        let weekdaySymbols = calendar.weekdaySymbols
        let weekdayEntries: [FullFinancialContext.WeekdayEntry] = weekdayData.map { day in
            let name = (day.weekday >= 1 && day.weekday <= 7) ? weekdaySymbols[day.weekday - 1] : "?"
            return FullFinancialContext.WeekdayEntry(
                weekday: name,
                total: safeDouble(day.total),
                avgPerDay: safeDouble(day.average),
                sampleSize: day.count,
                dayOccurrences: day.dayOccurrences
            )
        }

        // Needs breakdown for current month expenses
        let monthStart = calendar.dateInterval(of: .month, for: now)?.start ?? now
        let currentMonthTx = tx.filter { $0.date >= monthStart && $0.date <= now && $0.category?.isIncome == false }
        var essential = 0.0, priority = 0.0, optional = 0.0, unclassified = 0.0
        for tx in currentMonthTx {
            let amount = convertAmount(tx, currencyCode: currencyCode, converter: converter)
            switch tx.effectiveNeed {
            case .essential: essential += amount
            case .priority: priority += amount
            case .optional: optional += amount
            case .unclassified: unclassified += amount
            }
        }
        let needs = FullFinancialContext.NeedsBreakdownEntry(
            essential: safeDouble(essential),
            priority: safeDouble(priority),
            optional: safeDouble(optional),
            unclassified: safeDouble(unclassified),
            total: safeDouble(essential + priority + optional + unclassified)
        )

        return FullFinancialContext.PatternsSection(
            weekdayPattern30Days: weekdayEntries,
            needsBreakdownCurrentMonth: needs
        )
    }

    private func buildTagsTop10(
        tx: [TransactionItem],
        allTags: [Tag],
        currencyCode: String,
        converter: CurrencyConverting,
        currentMonthInterval: DateInterval
    ) -> [FullFinancialContext.TagEntry] {
        // CSV-mirror SSOT via resolver + catalog construido del allTags inyectado.
        let tagCatalog = Tag.byIDLookup(allTags)
        var tagTotals: [String: (total: Double, count: Int)] = [:]
        for tx in tx {
            let amount = convertAmount(tx, currencyCode: currencyCode, converter: converter)
            let txTagIDs = tx.resolvedTagIDs(scheduleBackfill: true) ?? []
            for uuid in txTagIDs {
                guard let tag = tagCatalog[uuid] else { continue }
                let entry = tagTotals[tag.name] ?? (total: 0, count: 0)
                tagTotals[tag.name] = (total: entry.total + amount, count: entry.count + 1)
            }
        }
        return tagTotals
            .sorted { $0.value.total > $1.value.total }
            .prefix(10)
            .map { (name, val) in
                FullFinancialContext.TagEntry(
                    name: name,
                    totalCurrentMonth: safeDouble(val.total),
                    txCount: val.count
                )
            }
    }

    private func buildTopTxBySubcategory(
        tx: [TransactionItem],
        currencyCode: String,
        converter: CurrencyConverting
    ) -> [FullFinancialContext.SubcategoryTxEntry] {
        // Group tx by subcategory
        var grouped: [String: (categoryName: String, txs: [TransactionItem])] = [:]
        for tx in tx {
            guard let subName = tx.subcategory?.name else { continue }
            let catName = tx.category?.name ?? "Other"
            var entry = grouped[subName] ?? (categoryName: catName, txs: [])
            entry.txs.append(tx)
            grouped[subName] = entry
        }

        // Compute total per subcat to rank top 10
        let ranked = grouped
            .map { (name: $0.key, total: $0.value.txs.reduce(0.0) { $0 + convertAmount($1, currencyCode: currencyCode, converter: converter) }, categoryName: $0.value.categoryName, txs: $0.value.txs) }
            .sorted { $0.total > $1.total }
            .prefix(10)

        return ranked.map { item in
            let topTxs = item.txs
                .sorted { abs($0.amount) > abs($1.amount) }
                .prefix(10)
                .map { tx -> FullFinancialContext.TxLite in
                    FullFinancialContext.TxLite(
                        date: Self.isoDateFormatter.string(from: tx.date),
                        amount: safeDouble(convertAmount(tx, currencyCode: currencyCode, converter: converter)),
                        merchant: canonicalMerchant(tx),
                        account: tx.account?.name
                    )
                }
            return FullFinancialContext.SubcategoryTxEntry(
                subcategoryName: item.name,
                categoryName: item.categoryName,
                transactions: Array(topTxs)
            )
        }
    }

    // MARK: - Fetchers

    private func fetchTransactions(_ ctx: ModelContext, from: Date, to: Date) -> [TransactionItem] {
        let descriptor = FetchDescriptor<TransactionItem>(
            predicate: #Predicate<TransactionItem> { $0.date >= from && $0.date <= to },
            sortBy: [SortDescriptor(\TransactionItem.date, order: .reverse)]
        )
        return (try? ctx.fetch(descriptor)) ?? []
    }

    private func fetchBudgets(_ ctx: ModelContext) -> [Budget] {
        (try? ctx.fetch(FetchDescriptor<Budget>())) ?? []
    }

    private func fetchAccounts(_ ctx: ModelContext) -> [Account] {
        (try? ctx.fetch(FetchDescriptor<Account>())) ?? []
    }

    private func fetchTags(_ ctx: ModelContext) -> [Tag] {
        (try? ctx.fetch(FetchDescriptor<Tag>())) ?? []
    }

    private func fetchScheduledPayments(_ ctx: ModelContext) -> [ScheduledPayment] {
        (try? ctx.fetch(FetchDescriptor<ScheduledPayment>())) ?? []
    }

    // MARK: - Helpers

    private func convertAmount(_ tx: TransactionItem, currencyCode: String, converter: CurrencyConverting) -> Double {
        tx.chatAmount(in: currencyCode, converter: converter)
    }

    private func canonicalMerchant(_ tx: TransactionItem) -> String? {
        guard let note = tx.note, !note.isEmpty else { return nil }
        let canonical = MerchantCanonicalizer.canonicalize(note)
        return canonical.isEmpty ? nil : canonical
    }

    private func safeDouble(_ value: Double) -> Double {
        value.isFinite ? value : 0
    }

    private static let isoDateFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f
    }()
}
