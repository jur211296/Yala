//
//  L10n.swift
//  Neto
//
//  Localization helper for type-safe string access.
//

import Foundation

/// Namespace for localized strings.
/// Usage: L10n.Panel.accounts or L10n.Trend.balance
enum L10n {

    // MARK: - Panel

    enum Panel {
        static var accounts: String {
            NSLocalizedString("panel.accounts", comment: "Accounts section title")
        }
        static var widgets: String {
            NSLocalizedString("panel.widgets", comment: "Widgets section title")
        }
        static var totalBalance: String {
            NSLocalizedString("panel.totalBalance", comment: "Total balance label")
        }
    }

    // MARK: - Trend

    enum Trend {
        static var balanceTitle: String {
            NSLocalizedString("trend.balance.title", comment: "Balance trend title")
        }
        static var incomeTitle: String {
            NSLocalizedString("trend.income.title", comment: "Income trend title")
        }
        static var expenseTitle: String {
            NSLocalizedString("trend.expense.title", comment: "Expense trend title")
        }
    }

    // MARK: - Trend Types

    enum TrendType {
        static var balance: String {
            NSLocalizedString("trendType.balance", comment: "Balance type")
        }
        static var income: String { NSLocalizedString("trendType.income", comment: "Income type") }
        static var expense: String {
            NSLocalizedString("trendType.expense", comment: "Expense type")
        }
    }

    // MARK: - Periods

    enum Period {
        static var thisMonth: String {
            NSLocalizedString("period.thisMonth", comment: "This month")
        }
        static var lastMonth: String {
            NSLocalizedString("period.lastMonth", comment: "Last month")
        }
        static var last30Days: String {
            NSLocalizedString("period.last30Days", comment: "Last 30 days")
        }
        static var thisYear: String { NSLocalizedString("period.thisYear", comment: "This year") }
        static var lastYear: String { NSLocalizedString("period.lastYear", comment: "Last year") }
        static var allTime: String { NSLocalizedString("period.allTime", comment: "All time") }
    }

    // MARK: - Groupings

    enum Grouping {
        static var day: String { NSLocalizedString("grouping.day", comment: "Day grouping") }
        static var week: String { NSLocalizedString("grouping.week", comment: "Week grouping") }
        static var month: String { NSLocalizedString("grouping.month", comment: "Month grouping") }
    }

    // MARK: - Cash Flow

    enum CashFlow {
        static var title: String { NSLocalizedString("cashFlow.title", comment: "Cash flow title") }
        static var income: String { NSLocalizedString("cashFlow.income", comment: "Income label") }
        static var expense: String {
            NSLocalizedString("cashFlow.expense", comment: "Expense label")
        }
        static var net: String { NSLocalizedString("cashFlow.net", comment: "Net label") }
    }

    // MARK: - Categories

    enum Categories {
        static var title: String {
            NSLocalizedString("categories.title", comment: "Categories title")
        }
        static var topSpending: String {
            NSLocalizedString("categories.topSpending", comment: "Top spending")
        }
        static var others: String {
            NSLocalizedString("categories.others", comment: "Others category")
        }
        static var noCategory: String {
            NSLocalizedString("categories.noCategory", comment: "No category")
        }
    }

    // MARK: - Subcategories

    enum Subcategories {
        static var title: String { NSLocalizedString("subcategories.title", comment: "") }
        static var noSubcategory: String {
            NSLocalizedString("subcategories.noSubcategory", comment: "")
        }
    }

    // MARK: - Nature

    enum Nature {
        static var title: String {
            NSLocalizedString("nature.expensesByNature", comment: "Expenses by nature")
        }
        static var essential: String { NSLocalizedString("nature.essential", comment: "") }
        static var discretionary: String { NSLocalizedString("nature.discretionary", comment: "") }
        static var unclassified: String { NSLocalizedString("nature.unclassified", comment: "") }
    }

    // MARK: - Records

    enum Records {
        static var title: String { NSLocalizedString("records.title", comment: "") }
        static var latest: String { NSLocalizedString("records.latest", comment: "") }
        static var noRecords: String { NSLocalizedString("records.noRecords", comment: "") }
    }

    // MARK: - Filters

    enum Filters {
        static var all: String { NSLocalizedString("filters.all", comment: "") }
        static var allAccounts: String { NSLocalizedString("filters.allAccounts", comment: "") }
        static var allCategories: String { NSLocalizedString("filters.allCategories", comment: "") }
        static var clearFilters: String { NSLocalizedString("filters.clearFilters", comment: "") }
    }

    // MARK: - Actions

    enum Action {
        static var cancel: String { NSLocalizedString("action.cancel", comment: "") }
        static var done: String { NSLocalizedString("action.done", comment: "") }
        static var save: String { NSLocalizedString("action.save", comment: "") }
        static var delete: String { NSLocalizedString("action.delete", comment: "") }
        static var edit: String { NSLocalizedString("action.edit", comment: "") }
        static var add: String { NSLocalizedString("action.add", comment: "") }
    }

    // MARK: - Date Helpers

    enum Date {
        static var today: String { NSLocalizedString("date.today", comment: "") }
        static var yesterday: String { NSLocalizedString("date.yesterday", comment: "") }

        static func weekOf(_ date: String) -> String {
            String(format: NSLocalizedString("date.weekOf %@", comment: ""), date)
        }
    }

    // MARK: - Exchange Rate

    enum ExchangeRate {
        static var title: String { NSLocalizedString("exchangeRate.title", comment: "") }
        static var updated: String { NSLocalizedString("exchangeRate.updated", comment: "") }
    }

    // MARK: - Empty States

    enum Empty {
        static var noData: String { NSLocalizedString("empty.noData", comment: "") }
        static var noTransactions: String { NSLocalizedString("empty.noTransactions", comment: "") }
    }
}

// MARK: - App Locale

/// Centralized locale configuration for date formatters and charts.
/// This makes it easy to change the app's locale in one place.
enum AppLocale {
    /// Supported language codes
    private static let supportedLanguages = ["es", "en"]

    /// The app's current locale for date formatting.
    /// Uses the system locale if supported, otherwise defaults to Spanish.
    static var current: Locale {
        let preferredLanguage = Locale.preferredLanguages.first ?? "es"
        let languageCode = String(preferredLanguage.prefix(2))

        if supportedLanguages.contains(languageCode) {
            return Locale(identifier: preferredLanguage)
        }
        return Locale(identifier: "es_ES")  // Default fallback
    }

    /// Short identifier for SwiftUI .locale() modifiers
    static var identifier: String {
        current.identifier
    }

    /// Creates a configured DateFormatter with the app's locale
    static func dateFormatter(dateFormat: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = current
        formatter.dateFormat = dateFormat
        return formatter
    }
}
