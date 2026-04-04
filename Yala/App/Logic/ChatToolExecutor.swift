//
//  ChatToolExecutor.swift
//  Yala
//
//  Executes Ask Yala chat tools against SwiftData using existing services.
//  NEVER exposes raw transaction notes to the LLM — uses MerchantCanonicalizer.
//

import Foundation
import SwiftData

@MainActor
struct ChatToolExecutor {

    let modelContext: ModelContext
    let currencyCode: String
    let converter: CurrencyConverting

    // MARK: - Execute

    func execute(toolName: String, arguments: String) throws -> [String: Any] {
        guard let tool = ChatToolName(rawValue: toolName) else {
            throw ChatAssistantError.toolExecutionFailed("Unknown tool: \(toolName)")
        }
        guard let data = arguments.data(using: .utf8) else {
            throw ChatAssistantError.toolExecutionFailed("Invalid arguments encoding")
        }

        switch tool {
        case .searchTransactions:
            let params = try JSONDecoder().decode(SearchTransactionsParams.self, from: data)
            return try executeSearchTransactions(params)
        case .spendingSummary:
            let params = try JSONDecoder().decode(SpendingSummaryParams.self, from: data)
            return try executeSpendingSummary(params)
        case .budgetStatus:
            let params = try JSONDecoder().decode(BudgetStatusParams.self, from: data)
            return try executeBudgetStatus(params)
        case .comparePeriods:
            let params = try JSONDecoder().decode(ComparePeriodsParams.self, from: data)
            return try executeComparePeriods(params)
        case .financialOverview:
            let params = try JSONDecoder().decode(FinancialOverviewParams.self, from: data)
            return try executeFinancialOverview(params)
        case .accountBalances:
            let params = try JSONDecoder().decode(AccountBalancesParams.self, from: data)
            return try executeAccountBalances(params)
        case .upcomingPayments:
            let params = try JSONDecoder().decode(UpcomingPaymentsParams.self, from: data)
            return try executeUpcomingPayments(params)
        case .analyzePatterns:
            let params = try JSONDecoder().decode(AnalyzePatternsParams.self, from: data)
            return try executeAnalyzePatterns(params)
        case .spendingProjection:
            let params = try JSONDecoder().decode(SpendingProjectionParams.self, from: data)
            return try executeSpendingProjection(params)
        }
    }

    // MARK: - Tool 1: search_transactions

    private func executeSearchTransactions(_ params: SearchTransactionsParams) throws -> [String: Any] {
        let allTx = try fetchEligibleTransactions()
        let interval = resolveInterval(params.dateRange, dateFrom: params.dateFrom, dateTo: params.dateTo)
        let limit = min(params.limit ?? 10, 50)

        var filtered = allTx.filter { interval.contains($0.date) }

        // Type filter
        if let type = params.type {
            filtered = filtered.filter { tx in
                if type == "income" { return tx.category?.isIncome == true }
                if type == "expense" { return tx.category?.isIncome == false }
                return true
            }
        }

        // Merchant filter (via MerchantCanonicalizer, never raw note)
        if let merchant = params.merchant {
            let canonicalMerchant = MerchantCanonicalizer.canonicalize(merchant)
            filtered = filtered.filter { matchesMerchant($0, canonicalQuery: canonicalMerchant) }
        }

        // Category filter (by name, case-insensitive — matches category OR subcategory)
        var matchedBySubcategory = false
        if let catName = params.category {
            filtered = filtered.filter { tx in
                let matches = matchesCategoryOrSubcategory(tx, name: catName)
                if matches && tx.subcategory?.name.localizedCaseInsensitiveContains(catName) == true {
                    matchedBySubcategory = true
                }
                return matches
            }
        }

        // Currency filter
        if let currency = params.currency {
            filtered = filtered.filter { $0.currencyCode.uppercased() == currency.uppercased() }
        }

        // Amount range filters
        if let minAmount = params.amountMin {
            filtered = filtered.filter { convertAmount($0) >= minAmount }
        }
        if let maxAmount = params.amountMax {
            filtered = filtered.filter { convertAmount($0) <= maxAmount }
        }

        // Tag filter
        if let tagName = params.tag {
            filtered = filtered.filter { tx in
                tx.tags?.contains(where: { $0.name.localizedCaseInsensitiveContains(tagName) }) == true
            }
        }

        // Account filter
        if let accountName = params.account {
            filtered = filtered.filter { tx in
                tx.account?.name.localizedCaseInsensitiveContains(accountName) == true
            }
        }

        // Sort
        if let sortBy = params.sortBy {
            switch sortBy {
            case "amount_desc":
                filtered.sort { convertAmount($0) > convertAmount($1) }
            case "amount_asc":
                filtered.sort { convertAmount($0) < convertAmount($1) }
            default:
                break // already sorted by date (desc) from fetch
            }
        }

        // Build transaction list (safe: no raw note)
        let topTx = Array(filtered.prefix(limit))
        let transactions: [[String: Any]] = topTx.map { tx in
            var dict: [String: Any] = [
                "date": Self.isoDateFormatter.string(from: tx.date),
                "amount": convertAmount(tx),
                "currency": currencyCode,
                "category": tx.category?.name ?? "Uncategorized",
                "type": tx.category?.isIncome == true ? "income" : "expense"
            ]
            if let sub = tx.subcategory?.name { dict["subcategory"] = sub }
            let merchant = safeMerchant(tx)
            if merchant != "Unknown" { dict["merchant"] = merchant }
            return dict
        }

        // Summary
        let totalAmount = filtered.reduce(0.0) { $0 + convertAmount($1) }
        let avgAmount = filtered.isEmpty ? 0 : totalAmount / Double(filtered.count)

        // Previous period comparison
        let prevInterval = previousInterval(for: interval)
        let prevFiltered = allTx.filter { prevInterval.contains($0.date) }
        let prevTotal: Double
        if let merchant = params.merchant {
            let cq = MerchantCanonicalizer.canonicalize(merchant)
            prevTotal = prevFiltered.filter { matchesMerchant($0, canonicalQuery: cq) }.reduce(0.0) { $0 + convertAmount($1) }
        } else if let catName = params.category {
            prevTotal = prevFiltered.filter { tx in
                tx.category?.name.localizedCaseInsensitiveContains(catName) == true ||
                tx.subcategory?.name.localizedCaseInsensitiveContains(catName) == true
            }.reduce(0.0) { $0 + convertAmount($1) }
        } else {
            prevTotal = prevFiltered.reduce(0.0) { $0 + convertAmount($1) }
        }

        // Budget context
        var budgetContext: [String: Any]?
        if let catName = params.category {
            let budgets = try fetchBudgets()
            if let budget = budgets.first(where: {
                $0.isActive && $0.category?.name.localizedCaseInsensitiveContains(catName) == true
            }) {
                let budgetInterval = InsightsCalculator.currentBudgetInterval(for: budget)
                let budgetTx = allTx.filter { tx in
                    tx.category?.persistentModelID == budget.category?.persistentModelID &&
                    budgetInterval.contains(tx.date) &&
                    tx.category?.isIncome == false
                }
                let spent = budgetTx.reduce(0.0) { sum, tx in
                    let converted = converter.convert(Decimal(abs(tx.amount)), from: tx.currencyCode, to: budget.currencyCode, on: tx.date)
                    return sum + NSDecimalNumber(decimal: converted).doubleValue
                }
                budgetContext = [
                    "name": budget.name,
                    "limit": budget.limitAmount,
                    "spent": spent,
                    "usage_percent": budget.limitAmount > 0 ? (spent / budget.limitAmount) * 100 : 0,
                    "days_remaining": max(0, Calendar.current.dateComponents([.day], from: Date.now, to: budgetInterval.end).day ?? 0)
                ]
            }
        }

        var summaryDict: [String: Any] = [
            "count": filtered.count,
            "total": totalAmount,
            "average": avgAmount,
            "currency": currencyCode
        ]
        if matchedBySubcategory, let catName = params.category {
            summaryDict["matched_level"] = "subcategory"
            summaryDict["subcategory_name"] = catName
            if let parentName = filtered.first?.category?.name {
                summaryDict["parent_category"] = parentName
            }
        }

        var result: [String: Any] = [
            "transactions": transactions,
            "summary": summaryDict,
            "comparison": [
                "previous_total": prevTotal,
                "variation_percent": PreviousPeriodHelper.calculateVariation(currentAmount: totalAmount, previousAmount: prevTotal) as Any
            ] as [String: Any]
        ]
        if let bc = budgetContext { result["budget_context"] = bc }
        return result
    }

    // MARK: - Tool 2: spending_summary

    private func executeSpendingSummary(_ params: SpendingSummaryParams) throws -> [String: Any] {
        let allTx = try fetchEligibleTransactions()
        let interval = resolveInterval(params.dateRange)
        let limit = min(params.limit ?? 10, 20)

        let typeFilter: TransactionNature? = params.type == "income" ? .income : params.type == "expense" ? .expense : nil
        let natures: Set<TransactionNature>? = typeFilter.map { [$0] }

        // Filter by date
        var periodTx = allTx.filter { interval.contains($0.date) && ($0.account?.excludeFromStatistics != true) }

        // Amount range filters
        if let minAmount = params.amountMin {
            periodTx = periodTx.filter { convertAmount($0) >= minAmount }
        }
        if let maxAmount = params.amountMax {
            periodTx = periodTx.filter { convertAmount($0) <= maxAmount }
        }

        var groups: [[String: Any]] = []

        switch params.groupBy {
        case "category":
            let topCats = TopSpendingCategoriesCalculator.calculateTopSpending(
                transactions: periodTx, interval: interval,
                currencyCode: currencyCode, transactionNatures: natures, converter: converter
            )
            groups = topCats.prefix(limit).map { cat in
                ["name": cat.category.name, "amount": cat.amount, "percentage": cat.percentage]
            }
        case "subcategory":
            let topSubs = TopSubcategoriesCalculator.calculateTopSubcategories(
                transactions: periodTx, interval: interval,
                currencyCode: currencyCode, transactionNatures: natures, converter: converter
            )
            groups = topSubs.prefix(limit).map { sub in
                ["name": sub.subcategoryName, "amount": sub.amount, "percentage": sub.percentageOfTotal]
            }
        case "merchant":
            let expenseTx = typeFilter == .income ? periodTx : periodTx.filter { $0.category?.isIncome == false }
            var merchantTotals: [String: Double] = [:]
            for tx in expenseTx {
                let merchant = safeMerchant(tx)
                if merchant != "Unknown" {
                    merchantTotals[merchant, default: 0] += convertAmount(tx)
                }
            }
            let total = merchantTotals.values.reduce(0, +)
            groups = merchantTotals.sorted(by: { $0.value > $1.value }).prefix(limit).map { entry in
                ["name": entry.key, "amount": entry.value, "percentage": total > 0 ? (entry.value / total) * 100 : 0]
            }
        case "day", "week":
            let grouping: TrendGrouping = params.groupBy == "day" ? .day : .week
            let cashFlow = CashFlowCalculator.calculateCashFlow(
                transactions: periodTx, interval: interval,
                grouping: grouping, currencyCode: currencyCode, converter: converter
            )
            groups = cashFlow.chartData.prefix(limit).map { data in
                ["date": Self.isoDateFormatter.string(from: data.date), "expense": data.expense, "income": data.income, "net": data.net]
            }
        default:
            break
        }

        // Totals
        let cashFlow = CashFlowCalculator.calculateCashFlow(
            transactions: periodTx, interval: interval,
            grouping: .day, currencyCode: currencyCode, converter: converter
        )
        let days = max(1, Calendar.current.dateComponents([.day], from: interval.start, to: min(interval.end, Date.now)).day ?? 1)
        let dailyAvg = cashFlow.totalExpense / Double(days)

        // Previous period comparison
        let prevInterval = previousInterval(for: interval)
        let prevTx = allTx.filter { prevInterval.contains($0.date) }
        let prevCashFlow = CashFlowCalculator.calculateCashFlow(
            transactions: prevTx, interval: prevInterval,
            grouping: .day, currencyCode: currencyCode, converter: converter
        )

        return [
            "groups": groups,
            "total": cashFlow.totalExpense,
            "total_income": cashFlow.totalIncome,
            "period_label": formatPeriodLabel(interval),
            "comparison": [
                "previous_total": prevCashFlow.totalExpense,
                "variation_percent": PreviousPeriodHelper.calculateVariation(currentAmount: cashFlow.totalExpense, previousAmount: prevCashFlow.totalExpense) as Any
            ] as [String: Any],
            "daily_avg": dailyAvg,
            "currency": currencyCode
        ]
    }

    // MARK: - Tool 3: budget_status

    private func executeBudgetStatus(_ params: BudgetStatusParams) throws -> [String: Any] {
        let budgets = try fetchBudgets().filter(\.isActive)
        let allTx = try fetchEligibleTransactions()

        // Determine reference date: current period or historical
        let currentPeriods: Set<String> = ["this_week", "this_month", "this_year"]
        let isHistorical = params.dateRange.map { !currentPeriods.contains($0) } ?? false
        let referenceInterval: DateInterval? = params.dateRange.flatMap { resolveInterval($0) }

        var filteredBudgets = budgets
        if let catName = params.category {
            filteredBudgets = budgets.filter {
                $0.category?.name.localizedCaseInsensitiveContains(catName) == true ||
                $0.category?.subcategories?.contains(where: { $0.name.localizedCaseInsensitiveContains(catName) }) == true
            }
        }

        let budgetResults: [[String: Any]] = filteredBudgets.compactMap { budget in
            guard budget.limitAmount > 0 else { return nil }

            // Use historical interval or current budget interval
            let budgetInterval: DateInterval
            if isHistorical, let refInterval = referenceInterval {
                budgetInterval = self.budgetInterval(for: budget, containing: refInterval.start)
            } else {
                budgetInterval = InsightsCalculator.currentBudgetInterval(for: budget)
            }

            let budgetTx = allTx.filter { tx in
                tx.category?.persistentModelID == budget.category?.persistentModelID &&
                budgetInterval.contains(tx.date) &&
                tx.category?.isIncome == false
            }
            let spent = budgetTx.reduce(0.0) { sum, tx in
                let converted = converter.convert(Decimal(abs(tx.amount)), from: tx.currencyCode, to: budget.currencyCode, on: tx.date)
                return sum + NSDecimalNumber(decimal: converted).doubleValue
            }
            let usage = (spent / budget.limitAmount) * 100
            let remaining = max(0, budget.limitAmount - spent)
            let daysLeft: Int
            if isHistorical {
                daysLeft = 0
            } else {
                daysLeft = max(0, Calendar.current.dateComponents([.day], from: Date.now, to: budgetInterval.end).day ?? 0)
            }

            return [
                "name": budget.name,
                "category": budget.category?.name ?? "General",
                "limit": budget.limitAmount,
                "spent": spent,
                "remaining": remaining,
                "usage_percent": usage,
                "period": budget.periodType,
                "days_remaining": daysLeft,
                "currency": budget.currencyCode,
                "status": usage >= 100 ? "exceeded" : usage >= 75 ? "at_risk" : "on_track"
            ] as [String: Any]
        }

        return [
            "budgets": budgetResults,
            "summary": [
                "total_budgets": budgetResults.count,
                "exceeded": budgetResults.count(where: { ($0["status"] as? String) == "exceeded" }),
                "at_risk": budgetResults.count(where: { ($0["status"] as? String) == "at_risk" }),
                "on_track": budgetResults.count(where: { ($0["status"] as? String) == "on_track" })
            ] as [String: Any]
        ]
    }

    // MARK: - Tool 4: compare_periods

    private func executeComparePeriods(_ params: ComparePeriodsParams) throws -> [String: Any] {
        let allTx = try fetchEligibleTransactions()
        let intervalA = resolveInterval(params.periodA)
        let intervalB = resolveInterval(params.periodB)

        var txA = allTx.filter { intervalA.contains($0.date) }
        var txB = allTx.filter { intervalB.contains($0.date) }

        // Optional category/subcategory/merchant filter
        if let catName = params.category {
            txA = txA.filter { matchesCategoryOrSubcategory($0, name: catName) }
            txB = txB.filter { matchesCategoryOrSubcategory($0, name: catName) }
        }
        if let merchant = params.merchant {
            let cq = MerchantCanonicalizer.canonicalize(merchant)
            txA = txA.filter { matchesMerchant($0, canonicalQuery: cq) }
            txB = txB.filter { matchesMerchant($0, canonicalQuery: cq) }
        }

        let metric = params.metric
        let valueA: Double
        let valueB: Double
        let countA = txA.count
        let countB = txB.count

        switch metric {
        case "income":
            valueA = txA.filter { $0.category?.isIncome == true }.reduce(0.0) { $0 + convertAmount($1) }
            valueB = txB.filter { $0.category?.isIncome == true }.reduce(0.0) { $0 + convertAmount($1) }
        case "balance":
            let incA = txA.filter { $0.category?.isIncome == true }.reduce(0.0) { $0 + convertAmount($1) }
            let expA = txA.filter { $0.category?.isIncome == false }.reduce(0.0) { $0 + convertAmount($1) }
            let incB = txB.filter { $0.category?.isIncome == true }.reduce(0.0) { $0 + convertAmount($1) }
            let expB = txB.filter { $0.category?.isIncome == false }.reduce(0.0) { $0 + convertAmount($1) }
            valueA = incA - expA
            valueB = incB - expB
        default: // "expense", "category"
            valueA = txA.filter { $0.category?.isIncome == false }.reduce(0.0) { $0 + convertAmount($1) }
            valueB = txB.filter { $0.category?.isIncome == false }.reduce(0.0) { $0 + convertAmount($1) }
        }

        // Category breakdown for expense comparison
        var breakdown: [[String: Any]] = []
        if metric == "expense" || metric == "category" {
            var catsA: [String: Double] = [:]
            var catsB: [String: Double] = [:]
            for tx in txA where tx.category?.isIncome == false {
                let name = tx.category?.name ?? "Other"
                catsA[name, default: 0] += convertAmount(tx)
            }
            for tx in txB where tx.category?.isIncome == false {
                let name = tx.category?.name ?? "Other"
                catsB[name, default: 0] += convertAmount(tx)
            }
            let allCats = Set(catsA.keys).union(catsB.keys)
            breakdown = allCats.sorted().prefix(10).map { name in
                let a = catsA[name] ?? 0
                let b = catsB[name] ?? 0
                return [
                    "name": name,
                    "period_a": a,
                    "period_b": b,
                    "change_percent": PreviousPeriodHelper.calculateVariation(currentAmount: a, previousAmount: b) as Any
                ] as [String: Any]
            }
        }

        return [
            "period_a": ["label": formatPeriodLabel(intervalA), "value": valueA, "count": countA] as [String: Any],
            "period_b": ["label": formatPeriodLabel(intervalB), "value": valueB, "count": countB] as [String: Any],
            "change": [
                "absolute": valueA - valueB,
                "percent": PreviousPeriodHelper.calculateVariation(currentAmount: valueA, previousAmount: valueB) as Any,
                "direction": valueA > valueB ? "up" : valueA < valueB ? "down" : "flat"
            ] as [String: Any],
            "breakdown": breakdown,
            "currency": currencyCode
        ]
    }

    // MARK: - Tool 5: financial_overview

    private func executeFinancialOverview(_ params: FinancialOverviewParams) throws -> [String: Any] {
        let allTx = try fetchEligibleTransactions()
        let budgets = try fetchBudgets()
        let interval = resolveInterval(params.dateRange)

        let periodTx = allTx.filter { interval.contains($0.date) }

        // Cash flow
        let cashFlow = CashFlowCalculator.calculateCashFlow(
            transactions: periodTx, interval: interval,
            grouping: .day, currencyCode: currencyCode, converter: converter
        )

        // Top categories
        let topCats = TopSpendingCategoriesCalculator.calculateTopSpending(
            transactions: periodTx, interval: interval,
            currencyCode: currencyCode, converter: converter
        )

        // Top merchants
        var merchantTotals: [String: (total: Double, count: Int)] = [:]
        for tx in periodTx where tx.category?.isIncome == false {
            let merchant = safeMerchant(tx)
            if merchant != "Unknown" {
                let existing = merchantTotals[merchant] ?? (total: 0, count: 0)
                merchantTotals[merchant] = (total: existing.total + convertAmount(tx), count: existing.count + 1)
            }
        }

        // Budgets at risk
        let budgetsAtRisk: [[String: Any]] = budgets.filter(\.isActive).compactMap { budget in
            guard budget.limitAmount > 0, let cat = budget.category else { return nil }
            let budgetInterval = InsightsCalculator.currentBudgetInterval(for: budget)
            let budgetTx = allTx.filter { tx in
                tx.category?.persistentModelID == cat.persistentModelID &&
                budgetInterval.contains(tx.date) && tx.category?.isIncome == false
            }
            let spent = budgetTx.reduce(0.0) { sum, tx in
                let converted = converter.convert(Decimal(abs(tx.amount)), from: tx.currencyCode, to: budget.currencyCode, on: tx.date)
                return sum + NSDecimalNumber(decimal: converted).doubleValue
            }
            let usage = (spent / budget.limitAmount) * 100
            guard usage >= 75 else { return nil }
            return ["category": cat.name, "spent": spent, "limit": budget.limitAmount, "usage_percent": usage] as [String: Any]
        }

        // Daily average
        let days = max(1, Calendar.current.dateComponents([.day], from: interval.start, to: min(interval.end, Date.now)).day ?? 1)
        let dailyAvg = cashFlow.totalExpense / Double(days)

        // Savings rate
        let savingsRate = cashFlow.totalIncome > 0 ? ((cashFlow.totalIncome - cashFlow.totalExpense) / cashFlow.totalIncome) * 100 : 0

        return [
            "income": cashFlow.totalIncome,
            "expense": cashFlow.totalExpense,
            "balance": cashFlow.netFlow,
            "top_categories": topCats.prefix(5).map { ["name": $0.category.name, "total": $0.amount, "percent": $0.percentage] as [String: Any] },
            "top_merchants": merchantTotals.sorted(by: { $0.value.total > $1.value.total }).prefix(5).map {
                ["name": $0.key, "total": $0.value.total, "count": $0.value.count] as [String: Any]
            },
            "budgets_at_risk": budgetsAtRisk,
            "daily_avg": dailyAvg,
            "savings_rate_percent": savingsRate,
            "period_label": formatPeriodLabel(interval),
            "currency": currencyCode
        ]
    }
}

// MARK: - Private Helpers

extension ChatToolExecutor {

    private func fetchEligibleTransactions() throws -> [TransactionItem] {
        let descriptor = FetchDescriptor<TransactionItem>(
            sortBy: [SortDescriptor(\TransactionItem.date, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).filter { tx in
            tx.balanceAdjustmentType == nil && tx.account?.excludeFromStatistics != true
        }
    }

    private func fetchBudgets() throws -> [Budget] {
        try modelContext.fetch(FetchDescriptor<Budget>())
    }

    // MARK: - Merchant Matching

    /// Match transaction by category or subcategory name (case-insensitive).
    private func matchesCategoryOrSubcategory(_ tx: TransactionItem, name: String) -> Bool {
        tx.category?.name.localizedCaseInsensitiveContains(name) == true ||
        tx.subcategory?.name.localizedCaseInsensitiveContains(name) == true
    }

    /// Match transaction against a pre-canonicalized merchant query.
    private func matchesMerchant(_ tx: TransactionItem, canonicalQuery: String) -> Bool {
        guard let note = tx.note, !note.isEmpty else { return false }
        let canonical = MerchantCanonicalizer.canonicalize(note)
        return canonical.contains(canonicalQuery) ||
               MerchantCanonicalizer.similarity(canonical, canonicalQuery) > 0.7
    }

    private func safeMerchant(_ tx: TransactionItem) -> String {
        guard let note = tx.note, !note.isEmpty else { return "Unknown" }
        let canonical = MerchantCanonicalizer.canonicalize(note)
        return canonical.isEmpty ? "Unknown" : canonical
    }

    // MARK: - Currency Conversion

    private func convertAmount(_ tx: TransactionItem) -> Double {
        if tx.currencyCode == currencyCode { return abs(tx.amount) }
        if tx.preferredCurrencyCode == currencyCode { return abs(tx.amountInPreferredCurrency) }
        let converted = converter.convert(Decimal(abs(tx.amount)), from: tx.currencyCode, to: currencyCode, on: tx.date)
        return NSDecimalNumber(decimal: converted).doubleValue
    }

    // MARK: - Date Resolution

    private func resolveInterval(_ dateRange: String?, dateFrom: String? = nil, dateTo: String? = nil) -> DateInterval {
        guard let rangeStr = dateRange, let range = ChatDateRange(rawValue: rangeStr) else {
            return ChatDateRange.thisMonth.toDateInterval()
        }
        return range.toDateInterval(dateFrom: dateFrom, dateTo: dateTo)
    }

    private func previousInterval(for interval: DateInterval) -> DateInterval {
        let duration = interval.duration
        let prevEnd = interval.start
        let prevStart = prevEnd.addingTimeInterval(-duration)
        return DateInterval(start: prevStart, end: prevEnd)
    }

    // MARK: - Formatters

    private static let isoDateFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f
    }()

    private static let periodFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    private func formatPeriodLabel(_ interval: DateInterval) -> String {
        "\(Self.periodFormatter.string(from: interval.start)) – \(Self.periodFormatter.string(from: interval.end))"
    }

    // MARK: - Budget Interval (historical support)

    /// Compute the budget interval containing a given date, based on budget period type.
    /// Unlike InsightsCalculator.currentBudgetInterval, this supports past dates.
    private func budgetInterval(for budget: Budget, containing date: Date) -> DateInterval {
        let calendar = Calendar.current
        let periodType = BudgetPeriodType(rawValue: budget.periodType) ?? .monthly
        switch periodType {
        case .weekly:
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
            let weekEnd = calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart) ?? date
            return DateInterval(start: weekStart, end: weekEnd)
        case .yearly:
            let yearStart = calendar.dateInterval(of: .year, for: date)?.start ?? date
            let yearEnd = calendar.date(byAdding: .year, value: 1, to: yearStart) ?? date
            return DateInterval(start: yearStart, end: yearEnd)
        case .unique:
            let distantPast = calendar.date(byAdding: .year, value: -10, to: Date.now) ?? date
            let distantFuture = calendar.date(byAdding: .year, value: 10, to: Date.now) ?? date
            return DateInterval(start: distantPast, end: distantFuture)
        case .monthly:
            let monthStart = calendar.dateInterval(of: .month, for: date)?.start ?? date
            let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? date
            return DateInterval(start: monthStart, end: monthEnd)
        }
    }

    // MARK: - Fetch Helpers

    private func fetchAccounts() throws -> [Account] {
        try modelContext.fetch(FetchDescriptor<Account>())
    }

    private func fetchScheduledPayments() throws -> [ScheduledPayment] {
        try modelContext.fetch(FetchDescriptor<ScheduledPayment>())
    }
}

// MARK: - Tool 6: account_balances

extension ChatToolExecutor {

    private func executeAccountBalances(_ params: AccountBalancesParams) throws -> [String: Any] {
        let accounts = try fetchAccounts().filter { !$0.isArchived }
        let allTx = try modelContext.fetch(FetchDescriptor<TransactionItem>())

        var filteredAccounts = accounts
        if let name = params.account {
            filteredAccounts = accounts.filter { $0.name.localizedCaseInsensitiveContains(name) }
        }

        let accountResults: [[String: Any]] = filteredAccounts.map { account in
            let balance = InitialBalanceService.currentBalance(for: account, allTransactions: allTx)
            let lastTxDate = allTx
                .filter { $0.account?.persistentModelID == account.persistentModelID && $0.balanceAdjustmentType == nil }
                .max(by: { $0.date < $1.date })?.date

            var dict: [String: Any] = [
                "name": account.name,
                "type": account.type,
                "balance": balance,
                "currency": account.currencyCode
            ]
            if let date = lastTxDate {
                dict["last_transaction_date"] = Self.isoDateFormatter.string(from: date)
            }
            return dict
        }

        let totalBalance = BalanceHelper.totalBalance(
            accounts: filteredAccounts,
            transactions: allTx,
            preferredCurrencyCode: currencyCode,
            converter: converter
        )

        return [
            "accounts": accountResults,
            "total_balance": totalBalance,
            "currency": currencyCode
        ]
    }
}

// MARK: - Tool 7: upcoming_payments

extension ChatToolExecutor {

    private func executeUpcomingPayments(_ params: UpcomingPaymentsParams) throws -> [String: Any] {
        let payments = try fetchScheduledPayments().filter(\.isActive)
        let daysAhead = min(params.daysAhead ?? 30, 90)
        let calendar = Calendar.current
        let now = Date.now
        let cutoff = calendar.date(byAdding: .day, value: daysAhead, to: now) ?? now

        // Compute dates for current month and next month to span the window
        var upcomingEntries: [(payment: ScheduledPayment, date: Date)] = []

        let monthsToCheck = [now, calendar.date(byAdding: .month, value: 1, to: now) ?? now,
                             calendar.date(byAdding: .month, value: 2, to: now) ?? now]
        for monthDate in monthsToCheck {
            for payment in payments {
                let dates = ScheduledPaymentDateCalculator.paymentDatesInMonth(
                    params: payment.dateCalculatorParams,
                    month: monthDate,
                    calendar: calendar
                )
                for date in dates where date >= now && date <= cutoff {
                    if !payment.isDateSkipped(date) {
                        upcomingEntries.append((payment: payment, date: date))
                    }
                }
            }
        }

        // Filter by category if specified
        if let catName = params.category {
            upcomingEntries = upcomingEntries.filter { entry in
                entry.payment.subcategory?.name.localizedCaseInsensitiveContains(catName) == true ||
                entry.payment.subcategory?.category?.name.localizedCaseInsensitiveContains(catName) == true
            }
        }

        // Sort by date
        upcomingEntries.sort { $0.date < $1.date }

        // Deduplicate (same payment + same date)
        var seen = Set<String>()
        upcomingEntries = upcomingEntries.filter { entry in
            let key = "\(entry.payment.id)-\(Self.isoDateFormatter.string(from: entry.date))"
            return seen.insert(key).inserted
        }

        let paymentResults: [[String: Any]] = upcomingEntries.map { entry in
            let p = entry.payment
            let convertedAmount: Double
            if p.currencyCode == currencyCode {
                convertedAmount = abs(p.amount)
            } else {
                let converted = converter.convert(Decimal(abs(p.amount)), from: p.currencyCode, to: currencyCode, on: entry.date)
                convertedAmount = NSDecimalNumber(decimal: converted).doubleValue
            }
            return [
                "name": p.name,
                "amount": convertedAmount,
                "currency": currencyCode,
                "due_date": Self.isoDateFormatter.string(from: entry.date),
                "recurrence_type": p.isRecurring ? p.recurrenceType : "one_time",
                "category": p.subcategory?.category?.name ?? "",
                "subcategory": p.subcategory?.name ?? "",
                "is_subscription": p.paymentCategory == "subscription",
                "type": p.transactionType
            ] as [String: Any]
        }

        // Monthly totals for active subscriptions and recurring
        let subscriptionsMonthly = monthlyTotal(for: payments, category: "subscription")
        let recurringMonthly = monthlyTotal(for: payments, category: "recurring")

        let totalDue = paymentResults
            .filter { ($0["type"] as? String) == "expense" }
            .reduce(0.0) { $0 + (($1["amount"] as? Double) ?? 0) }

        return [
            "payments": paymentResults,
            "total_due": totalDue,
            "subscriptions_monthly_total": subscriptionsMonthly,
            "recurring_monthly_total": recurringMonthly,
            "days_ahead": daysAhead,
            "currency": currencyCode
        ]
    }

    private func monthlyTotal(for payments: [ScheduledPayment], category: String) -> Double {
        payments
            .filter { $0.paymentCategory == category && $0.transactionType == "expense" }
            .reduce(0.0) { sum, p in
                let converted = converter.convert(Decimal(abs(p.amount)), from: p.currencyCode, to: currencyCode, on: Date.now)
                return sum + NSDecimalNumber(decimal: converted).doubleValue * monthlyMultiplier(p)
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
}

// MARK: - Tool 8: analyze_patterns

extension ChatToolExecutor {

    private func executeAnalyzePatterns(_ params: AnalyzePatternsParams) throws -> [String: Any] {
        guard let analysisType = ChatAnalysisType(rawValue: params.analysisType) else {
            throw ChatAssistantError.toolExecutionFailed("Unknown analysis_type: \(params.analysisType)")
        }

        let allTx = try fetchEligibleTransactions()
        let interval = resolveInterval(params.dateRange)
        let limit = min(params.limit ?? 10, 20)
        var periodTx = allTx.filter { interval.contains($0.date) && $0.category?.isIncome == false }

        if let catName = params.category {
            periodTx = periodTx.filter { matchesCategoryOrSubcategory($0, name: catName) }
        }

        switch analysisType {
        case .smallRecurring:
            return analyzeSmallRecurring(periodTx, interval: interval, threshold: params.thresholdAmount, limit: limit)
        case .frequencyRanking:
            return analyzeFrequencyRanking(periodTx, limit: limit)
        case .unusualSpending:
            return try analyzeUnusualSpending(allTx, periodTx: periodTx, interval: interval, limit: limit)
        case .weekdayPattern:
            return analyzeWeekdayPattern(periodTx, interval: interval)
        case .needsBreakdown:
            return analyzeNeedsBreakdown(periodTx)
        }
    }

    // MARK: small_recurring

    private func analyzeSmallRecurring(_ transactions: [TransactionItem], interval: DateInterval, threshold: Double?, limit: Int) -> [String: Any] {
        let totalExpense = transactions.reduce(0.0) { $0 + convertAmount($1) }
        let days = max(1, Calendar.current.dateComponents([.day], from: interval.start, to: min(interval.end, Date.now)).day ?? 1)
        let dailyAvg = totalExpense / Double(days)
        let thresholdAmount = threshold ?? (dailyAvg * 0.25) // Default: 25% of daily average

        // Group small expenses by merchant
        let smallTx = transactions.filter { convertAmount($0) <= thresholdAmount }
        var merchantGroups: [String: (count: Int, total: Double)] = [:]
        for tx in smallTx {
            let merchant = safeMerchant(tx)
            if merchant != "Unknown" {
                let existing = merchantGroups[merchant] ?? (count: 0, total: 0)
                merchantGroups[merchant] = (count: existing.count + 1, total: existing.total + convertAmount(tx))
            }
        }

        // Only include merchants with 2+ occurrences (recurring pattern)
        let recurring = merchantGroups.filter { $0.value.count >= 2 }
            .sorted { $0.value.total > $1.value.total }
            .prefix(limit)

        let antExpenses: [[String: Any]] = recurring.map { entry in
            [
                "merchant": entry.key,
                "count": entry.value.count,
                "avg_amount": entry.value.count > 0 ? entry.value.total / Double(entry.value.count) : 0,
                "total": entry.value.total
            ] as [String: Any]
        }

        let totalAntSpending = recurring.reduce(0.0) { $0 + $1.value.total }

        return [
            "ant_expenses": antExpenses,
            "total_ant_spending": totalAntSpending,
            "percent_of_total": totalExpense > 0 ? (totalAntSpending / totalExpense) * 100 : 0,
            "threshold_used": thresholdAmount,
            "currency": currencyCode
        ]
    }

    // MARK: frequency_ranking

    private func analyzeFrequencyRanking(_ transactions: [TransactionItem], limit: Int) -> [String: Any] {
        var merchantCounts: [String: (count: Int, total: Double)] = [:]
        for tx in transactions {
            let merchant = safeMerchant(tx)
            if merchant != "Unknown" {
                let existing = merchantCounts[merchant] ?? (count: 0, total: 0)
                merchantCounts[merchant] = (count: existing.count + 1, total: existing.total + convertAmount(tx))
            }
        }

        let sorted = merchantCounts.sorted { $0.value.count > $1.value.count }.prefix(limit)
        let rankings: [[String: Any]] = sorted.map { entry in
            [
                "name": entry.key,
                "count": entry.value.count,
                "total_amount": entry.value.total,
                "avg_amount": entry.value.count > 0 ? entry.value.total / Double(entry.value.count) : 0
            ] as [String: Any]
        }

        return [
            "rankings": rankings,
            "total_transactions": transactions.count,
            "currency": currencyCode
        ]
    }

    // MARK: unusual_spending

    private func analyzeUnusualSpending(_ allTx: [TransactionItem], periodTx: [TransactionItem], interval: DateInterval, limit: Int) throws -> [String: Any] {
        // Baseline: average per category over last 90 days
        let calendar = Calendar.current
        let baselineStart = calendar.date(byAdding: .day, value: -90, to: interval.start) ?? interval.start
        let baselineInterval = DateInterval(start: baselineStart, end: interval.start)
        let baselineTx = allTx.filter { baselineInterval.contains($0.date) && $0.category?.isIncome == false }

        // Compute category averages from baseline
        var catTotals: [String: (total: Double, count: Int)] = [:]
        for tx in baselineTx {
            let catName = tx.category?.name ?? "Other"
            let existing = catTotals[catName] ?? (total: 0, count: 0)
            catTotals[catName] = (total: existing.total + convertAmount(tx), count: existing.count + 1)
        }
        var catAvg: [String: Double] = [:]
        for (name, data) in catTotals where data.count > 0 {
            catAvg[name] = data.total / Double(data.count)
        }

        // Find anomalies: transactions > 2x category average
        var anomalies: [(tx: TransactionItem, avg: Double, deviation: Double)] = []
        for tx in periodTx {
            let catName = tx.category?.name ?? "Other"
            let amount = convertAmount(tx)
            if let avg = catAvg[catName], avg > 0 {
                let deviation = (amount - avg) / avg * 100
                if amount > avg * 2 {
                    anomalies.append((tx: tx, avg: avg, deviation: deviation))
                }
            }
        }

        anomalies.sort { $0.deviation > $1.deviation }
        let topAnomalies: [[String: Any]] = anomalies.prefix(limit).map { entry in
            [
                "date": Self.isoDateFormatter.string(from: entry.tx.date),
                "amount": convertAmount(entry.tx),
                "merchant": safeMerchant(entry.tx),
                "category": entry.tx.category?.name ?? "Other",
                "avg_for_category": entry.avg,
                "deviation_percent": entry.deviation
            ] as [String: Any]
        }

        return [
            "anomalies": topAnomalies,
            "count": topAnomalies.count,
            "currency": currencyCode
        ]
    }

    // MARK: weekday_pattern

    private func analyzeWeekdayPattern(_ transactions: [TransactionItem], interval: DateInterval) -> [String: Any] {
        let weekdayData = WeekdaySpendingCalculator.calculate(
            transactions: transactions,
            interval: interval,
            currencyCode: currencyCode,
            converter: converter
        )

        let maxTotal = weekdayData.max(by: { $0.total < $1.total })?.weekday
        let minTotal = weekdayData.min(by: { $0.total < $1.total })?.weekday

        let weekdays: [[String: Any]] = weekdayData.map { day in
            [
                "name": day.shortName,
                "weekday": day.weekday,
                "total": day.total,
                "average": day.average,
                "count": day.count,
                "is_highest": day.weekday == maxTotal,
                "is_lowest": day.weekday == minTotal
            ] as [String: Any]
        }

        // Weekend (Sat=7, Sun=1) vs weekday totals
        let weekendTotal = weekdayData.filter { $0.weekday == 1 || $0.weekday == 7 }.reduce(0.0) { $0 + $1.total }
        let weekdayTotal = weekdayData.filter { $0.weekday >= 2 && $0.weekday <= 6 }.reduce(0.0) { $0 + $1.total }

        return [
            "weekdays": weekdays,
            "weekend_total": weekendTotal,
            "weekday_total": weekdayTotal,
            "weekend_vs_weekday_percent": weekdayTotal > 0 ? (weekendTotal / weekdayTotal) * 100 : 0,
            "currency": currencyCode
        ]
    }

    // MARK: needs_breakdown

    private func analyzeNeedsBreakdown(_ transactions: [TransactionItem]) -> [String: Any] {
        var needGroups: [String: (amount: Double, categories: [String: Double])] = [
            "essential": (amount: 0, categories: [:]),
            "priority": (amount: 0, categories: [:]),
            "optional": (amount: 0, categories: [:]),
            "unclassified": (amount: 0, categories: [:])
        ]

        for tx in transactions {
            let amount = convertAmount(tx)
            let need = tx.effectiveNeed
            let key: String
            switch need {
            case .essential: key = "essential"
            case .priority: key = "priority"
            case .optional: key = "optional"
            case .unclassified: key = "unclassified"
            }
            let catName = tx.category?.name ?? "Other"
            guard var group = needGroups[key] else { continue }
            group.amount += amount
            group.categories[catName, default: 0] += amount
            needGroups[key] = group
        }

        let total = needGroups.values.reduce(0.0) { $0 + $1.amount }

        func buildGroup(_ key: String) -> [String: Any] {
            let group = needGroups[key]!
            let topCats = group.categories.sorted { $0.value > $1.value }.prefix(3).map(\.key)
            return [
                "amount": group.amount,
                "percent": total > 0 ? (group.amount / total) * 100 : 0,
                "top_categories": topCats
            ] as [String: Any]
        }

        return [
            "essential": buildGroup("essential"),
            "priority": buildGroup("priority"),
            "optional": buildGroup("optional"),
            "unclassified": buildGroup("unclassified"),
            "total": total,
            "currency": currencyCode
        ]
    }
}

// MARK: - Tool 9: spending_projection

extension ChatToolExecutor {

    private func executeSpendingProjection(_ params: SpendingProjectionParams) throws -> [String: Any] {
        let allTx = try fetchEligibleTransactions()
        let calendar = Calendar.current
        let now = Date.now
        let monthStart = calendar.dateInterval(of: .month, for: now)?.start ?? now
        let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? now
        let thisMonthInterval = DateInterval(start: monthStart, end: now)

        var periodTx = allTx.filter { thisMonthInterval.contains($0.date) && $0.category?.isIncome == false }
        if let catName = params.category {
            periodTx = periodTx.filter { matchesCategoryOrSubcategory($0, name: catName) }
        }

        let spentSoFar = periodTx.reduce(0.0) { $0 + convertAmount($1) }
        let daysElapsed = max(1, calendar.dateComponents([.day], from: monthStart, to: now).day ?? 1)
        let daysInMonth = calendar.dateComponents([.day], from: monthStart, to: monthEnd).day ?? 30
        let daysRemaining = max(0, daysInMonth - daysElapsed)
        let dailyBurnRate = spentSoFar / Double(daysElapsed)
        let projectedTotal = spentSoFar + (dailyBurnRate * Double(daysRemaining))

        // Last month comparison
        let lastMonthStart = calendar.date(byAdding: .month, value: -1, to: monthStart) ?? monthStart
        let lastMonthInterval = DateInterval(start: lastMonthStart, end: monthStart)
        var lastMonthTx = allTx.filter { lastMonthInterval.contains($0.date) && $0.category?.isIncome == false }
        if let catName = params.category {
            lastMonthTx = lastMonthTx.filter { matchesCategoryOrSubcategory($0, name: catName) }
        }
        let lastMonthTotal = lastMonthTx.reduce(0.0) { $0 + convertAmount($1) }

        // Budget projection
        var budgetProjection: [String: Any]?
        if let catName = params.category {
            let budgets = try fetchBudgets()
            if let budget = budgets.first(where: {
                $0.isActive && $0.category?.name.localizedCaseInsensitiveContains(catName) == true
            }) {
                let projectedUsage = budget.limitAmount > 0 ? (projectedTotal / budget.limitAmount) * 100 : 0
                let safeDaily = daysRemaining > 0 ? max(0, budget.limitAmount - spentSoFar) / Double(daysRemaining) : 0
                budgetProjection = [
                    "name": budget.name,
                    "limit": budget.limitAmount,
                    "projected_usage_percent": projectedUsage,
                    "safe_daily_budget": safeDaily
                ]
            }
        }

        // Safe daily budget (without specific budget: based on last month as benchmark)
        let safeDailyBudget: Double
        if let bp = budgetProjection, let sd = bp["safe_daily_budget"] as? Double {
            safeDailyBudget = sd
        } else {
            safeDailyBudget = daysRemaining > 0 ? max(0, lastMonthTotal - spentSoFar) / Double(daysRemaining) : 0
        }

        // Upcoming scheduled payments remaining this month (informational)
        let scheduledPayments = try fetchScheduledPayments().filter { $0.isActive && $0.transactionType == "expense" }
        var upcomingScheduledTotal = 0.0
        for payment in scheduledPayments {
            let dates = ScheduledPaymentDateCalculator.paymentDatesInMonth(
                params: payment.dateCalculatorParams,
                month: now,
                calendar: calendar
            )
            for date in dates where date > now && date <= monthEnd {
                if !payment.isDateSkipped(date) {
                    let converted = converter.convert(Decimal(abs(payment.amount)), from: payment.currencyCode, to: currencyCode, on: date)
                    upcomingScheduledTotal += NSDecimalNumber(decimal: converted).doubleValue
                }
            }
        }

        var result: [String: Any] = [
            "spent_so_far": spentSoFar,
            "days_elapsed": daysElapsed,
            "days_remaining": daysRemaining,
            "daily_burn_rate": dailyBurnRate,
            "projected_month_total": projectedTotal,
            "safe_daily_budget": safeDailyBudget,
            "vs_last_month": [
                "total": lastMonthTotal,
                "projected_variation_percent": PreviousPeriodHelper.calculateVariation(currentAmount: projectedTotal, previousAmount: lastMonthTotal) as Any
            ] as [String: Any],
            "upcoming_scheduled_total": upcomingScheduledTotal,
            "currency": currencyCode
        ]
        if let bp = budgetProjection { result["budget_projection"] = bp }
        return result
    }
}
