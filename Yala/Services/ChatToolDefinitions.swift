//
//  ChatToolDefinitions.swift
//  Yala
//
//  JSON Schema definitions for the Ask Yala function calling tools.
//

import Foundation
import OpenAI

enum ChatToolDefinitions {

    static let allTools: [ChatQuery.ChatCompletionToolParam] = [
        searchTransactions,
        spendingSummary,
        budgetStatus,
        comparePeriods,
        financialOverview,
        accountBalances,
        upcomingPayments,
        analyzePatterns,
        spendingProjection
    ]

    // MARK: - Date range enum values (shared)

    private static let dateRangeEnum: [String] = [
        "today", "yesterday", "this_week", "last_week",
        "this_month", "last_month", "this_year",
        "last_7_days", "last_30_days", "custom"
    ]

    private static let periodEnum: [String] = [
        "this_week", "last_week", "this_month", "last_month",
        "this_year", "last_7_days", "last_30_days"
    ]

    // MARK: - 1. search_transactions

    static let searchTransactions = ChatQuery.ChatCompletionToolParam(
        function: .init(
            name: "search_transactions",
            description: "Search and filter transactions by merchant, category, date, type, amount range, tag, or account. Returns matching transactions with summary statistics, comparison with previous period, and budget context.",
            parameters: .schema(
                .type(.object),
                .properties([
                    "merchant": .schema(.type(.string), .description("Merchant/store name to search for")),
                    "category": .schema(.type(.string), .description("Category or subcategory name to filter by")),
                    "date_range": .schema(.type(.string), .enumValues(dateRangeEnum), .description("Predefined date range")),
                    "date_from": .schema(.type(.string), .description("Start date YYYY-MM-DD (only with date_range=custom)")),
                    "date_to": .schema(.type(.string), .description("End date YYYY-MM-DD (only with date_range=custom)")),
                    "type": .schema(.type(.string), .enumValues(["income", "expense"]), .description("Transaction type filter")),
                    "currency": .schema(.type(.string), .description("Currency code filter (ISO 4217)")),
                    "limit": .schema(.type(.integer), .description("Max transactions to return (default 10, max 50)")),
                    "amount_min": .schema(.type(.number), .description("Minimum amount filter")),
                    "amount_max": .schema(.type(.number), .description("Maximum amount filter")),
                    "sort_by": .schema(.type(.string), .enumValues(["date", "amount_desc", "amount_asc"]), .description("Sort order (default: date)")),
                    "tag": .schema(.type(.string), .description("Filter by tag name")),
                    "account": .schema(.type(.string), .description("Filter by account name"))
                ]),
                .required(["date_range"])
            )
        )
    )

    // MARK: - 2. spending_summary

    static let spendingSummary = ChatQuery.ChatCompletionToolParam(
        function: .init(
            name: "spending_summary",
            description: "Get spending grouped by category, subcategory, merchant, day, or week. Includes totals, comparison with previous period, and daily average.",
            parameters: .schema(
                .type(.object),
                .properties([
                    "date_range": .schema(.type(.string), .enumValues(dateRangeEnum), .description("Date range for the summary")),
                    "group_by": .schema(.type(.string), .enumValues(["category", "subcategory", "merchant", "day", "week"]), .description("How to group the spending data")),
                    "type": .schema(.type(.string), .enumValues(["income", "expense"]), .description("Filter by transaction type")),
                    "limit": .schema(.type(.integer), .description("Max groups to return (default 10)")),
                    "amount_min": .schema(.type(.number), .description("Minimum transaction amount to include")),
                    "amount_max": .schema(.type(.number), .description("Maximum transaction amount to include"))
                ]),
                .required(["date_range", "group_by"])
            )
        )
    )

    // MARK: - 3. budget_status

    static let budgetStatus = ChatQuery.ChatCompletionToolParam(
        function: .init(
            name: "budget_status",
            description: "Get status of budgets including spent amount, limit, usage percentage, remaining amount, and days left. Supports current or past periods. Optionally filter by category.",
            parameters: .schema(
                .type(.object),
                .properties([
                    "category": .schema(.type(.string), .description("Category or subcategory name to filter by (optional — returns all active budgets if omitted)")),
                    "date_range": .schema(.type(.string), .enumValues(["this_week", "last_week", "this_month", "last_month", "this_year"]), .description("Period to evaluate (default: current budget period). Use last_month for historical budget analysis."))
                ])
            )
        )
    )

    // MARK: - 4. compare_periods

    static let comparePeriods = ChatQuery.ChatCompletionToolParam(
        function: .init(
            name: "compare_periods",
            description: "Compare financial metrics between two time periods. Shows absolute and percentage changes with optional category breakdown.",
            parameters: .schema(
                .type(.object),
                .properties([
                    "metric": .schema(.type(.string), .enumValues(["expense", "income", "balance", "category"]), .description("Financial metric to compare")),
                    "period_a": .schema(.type(.string), .enumValues(periodEnum), .description("First period (usually current)")),
                    "period_b": .schema(.type(.string), .enumValues(periodEnum), .description("Second period (usually previous)")),
                    "category": .schema(.type(.string), .description("Category or subcategory name to compare")),
                    "merchant": .schema(.type(.string), .description("Merchant to compare"))
                ]),
                .required(["metric", "period_a", "period_b"])
            )
        )
    )

    // MARK: - 5. financial_overview

    static let financialOverview = ChatQuery.ChatCompletionToolParam(
        function: .init(
            name: "financial_overview",
            description: "Get a comprehensive financial overview for a period: income, expenses, balance, top categories, top merchants, budgets at risk, daily average, and savings rate.",
            parameters: .schema(
                .type(.object),
                .properties([
                    "date_range": .schema(.type(.string), .enumValues(periodEnum), .description("Period for the overview"))
                ]),
                .required(["date_range"])
            )
        )
    )

    // MARK: - 6. account_balances

    static let accountBalances = ChatQuery.ChatCompletionToolParam(
        function: .init(
            name: "account_balances",
            description: "Get current balance of accounts. Shows each account's balance, type, and currency, plus total balance in preferred currency.",
            parameters: .schema(
                .type(.object),
                .properties([
                    "account": .schema(.type(.string), .description("Account name to filter (optional — returns all non-archived accounts if omitted)"))
                ])
            )
        )
    )

    // MARK: - 7. upcoming_payments

    static let upcomingPayments = ChatQuery.ChatCompletionToolParam(
        function: .init(
            name: "upcoming_payments",
            description: "Get upcoming scheduled payments and subscriptions within a time window. Shows due dates, amounts, recurrence, and monthly totals for subscriptions and recurring payments.",
            parameters: .schema(
                .type(.object),
                .properties([
                    "days_ahead": .schema(.type(.integer), .description("Number of days ahead to look (default 30, max 90)")),
                    "category": .schema(.type(.string), .description("Filter by category or subcategory name"))
                ])
            )
        )
    )

    // MARK: - 8. analyze_patterns

    static let analyzePatterns = ChatQuery.ChatCompletionToolParam(
        function: .init(
            name: "analyze_patterns",
            description: "Analyze spending patterns: small recurring expenses (gastos hormiga), most frequent merchants, unusual/anomalous spending, weekday patterns, or needs breakdown (essential vs optional).",
            parameters: .schema(
                .type(.object),
                .properties([
                    "analysis_type": .schema(.type(.string), .enumValues([
                        "small_recurring", "frequency_ranking", "unusual_spending",
                        "weekday_pattern", "needs_breakdown"
                    ]), .description("Type of pattern analysis")),
                    "date_range": .schema(.type(.string), .enumValues(dateRangeEnum), .description("Date range to analyze")),
                    "threshold_amount": .schema(.type(.number), .description("Amount threshold for small_recurring (default: auto-calculated from daily average)")),
                    "category": .schema(.type(.string), .description("Filter by category or subcategory name")),
                    "limit": .schema(.type(.integer), .description("Max results to return (default 10)"))
                ]),
                .required(["analysis_type", "date_range"])
            )
        )
    )

    // MARK: - 9. spending_projection

    static let spendingProjection = ChatQuery.ChatCompletionToolParam(
        function: .init(
            name: "spending_projection",
            description: "Project spending for the current month based on daily burn rate. Shows projected total, safe daily budget, comparison vs last month, and budget projection if applicable.",
            parameters: .schema(
                .type(.object),
                .properties([
                    "category": .schema(.type(.string), .description("Category or subcategory to project (optional — projects all spending if omitted)"))
                ])
            )
        )
    )
}
