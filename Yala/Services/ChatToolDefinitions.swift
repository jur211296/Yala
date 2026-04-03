//
//  ChatToolDefinitions.swift
//  Yala
//
//  JSON Schema definitions for the 5 Ask Yala function calling tools.
//

import Foundation
import OpenAI

enum ChatToolDefinitions {

    static let allTools: [ChatQuery.ChatCompletionToolParam] = [
        searchTransactions,
        spendingSummary,
        budgetStatus,
        comparePeriods,
        financialOverview
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
            description: "Search and filter transactions by merchant, category, date, type, or currency. Returns matching transactions with summary statistics, comparison with previous period, and budget context.",
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
                    "limit": .schema(.type(.integer), .description("Max transactions to return (default 10, max 50)"))
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
                    "limit": .schema(.type(.integer), .description("Max groups to return (default 10)"))
                ]),
                .required(["date_range", "group_by"])
            )
        )
    )

    // MARK: - 3. budget_status

    static let budgetStatus = ChatQuery.ChatCompletionToolParam(
        function: .init(
            name: "budget_status",
            description: "Get current status of budgets including spent amount, limit, usage percentage, remaining amount, and days left in period. Optionally filter by category name.",
            parameters: .schema(
                .type(.object),
                .properties([
                    "category": .schema(.type(.string), .description("Filter by category name (optional — returns all active budgets if omitted)"))
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
                    "category": .schema(.type(.string), .description("Category to compare (for metric=category)")),
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
}
