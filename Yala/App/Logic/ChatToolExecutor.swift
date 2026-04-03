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
        let periodTx = allTx.filter { interval.contains($0.date) && ($0.account?.excludeFromStatistics != true) }

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

        var filteredBudgets = budgets
        if let catName = params.category {
            filteredBudgets = budgets.filter {
                $0.category?.name.localizedCaseInsensitiveContains(catName) == true ||
                $0.category?.subcategories?.contains(where: { $0.name.localizedCaseInsensitiveContains(catName) }) == true
            }
        }

        let budgetResults: [[String: Any]] = filteredBudgets.compactMap { budget in
            guard budget.limitAmount > 0 else { return nil }
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
            let usage = (spent / budget.limitAmount) * 100
            let remaining = max(0, budget.limitAmount - spent)
            let daysLeft = max(0, Calendar.current.dateComponents([.day], from: Date.now, to: budgetInterval.end).day ?? 0)

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
                "at_risk": budgetResults.count(where: { ($0["status"] as? String) == "at_risk" || ($0["status"] as? String) == "exceeded" }),
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
}
