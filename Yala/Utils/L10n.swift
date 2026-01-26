//
//  L10n.swift
//  Yala
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
        static func greeting(_ name: String) -> String {
            String(format: NSLocalizedString("panel.greeting", comment: ""), name)
        }
        static func title(_ name: String) -> String {
            String(format: NSLocalizedString("panel.title", comment: ""), name)
        }
        static var fabVoice: String {
            NSLocalizedString("panel.fabVoice", comment: "")
        }
        static var fabImage: String {
            NSLocalizedString("panel.fabImage", comment: "")
        }
        static var fabManual: String {
            NSLocalizedString("panel.fabManual", comment: "")
        }
    }

    // MARK: - Trend

    enum Trend {
        static var title: String {
            NSLocalizedString("trend.title", comment: "Trends section title")
        }
        static var balanceTitle: String {
            NSLocalizedString("trend.balance.title", comment: "Balance trend title")
        }
        static var incomeTitle: String {
            NSLocalizedString("trend.income.title", comment: "Income trend title")
        }
        static var expenseTitle: String {
            NSLocalizedString("trend.expense.title", comment: "Expense trend title")
        }
        static var filterBlockedMessage: String {
            NSLocalizedString(
                "trend.filterBlockedMessage",
                comment: "Message shown when user tries to select balance/income with category filters active"
            )
        }
        static var filterBlockedTitle: String {
            NSLocalizedString("trend.filterBlockedTitle", comment: "")
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

    // MARK: - Cash Flow

    enum CashFlow {
        static var title: String { NSLocalizedString("cashFlow.title", comment: "Cash flow title") }
        static var income: String { NSLocalizedString("cashFlow.income", comment: "Income label") }
        static var expense: String {
            NSLocalizedString("cashFlow.expense", comment: "Expense label")
        }
        static var net: String { NSLocalizedString("cashFlow.net", comment: "Net label") }
        static var netFlow: String {
            NSLocalizedString("cashFlow.netFlow", comment: "Net flow label")
        }
    }

    // MARK: - Groupings

    enum Groupings {
        static var daily: String { NSLocalizedString("grouping.day", comment: "") }
        static var weekly: String { NSLocalizedString("grouping.week", comment: "") }
        static var monthly: String { NSLocalizedString("grouping.month", comment: "") }
    }

    // MARK: - Tab

    enum Tab {
        static var panel: String { NSLocalizedString("tab.panel", comment: "") }
        static var statistics: String { NSLocalizedString("tab.statistics", comment: "") }
        static var planning: String { NSLocalizedString("tab.planning", comment: "") }
        static var more: String { NSLocalizedString("tab.more", comment: "") }
        static var search: String { NSLocalizedString("tab.search", comment: "") }
    }

    // MARK: - Period

    enum Period {
        static var thisWeek: String { NSLocalizedString("period.thisWeek", comment: "") }
        static var lastWeek: String { NSLocalizedString("period.lastWeek", comment: "") }
        static var nextWeek: String { NSLocalizedString("period.nextWeek", comment: "") }
        static var last7Days: String { NSLocalizedString("period.last7Days", comment: "") }
        static var last30Days: String {
            NSLocalizedString("period.last30Days", comment: "Last 30 days")
        }
        static var thisMonth: String {
            NSLocalizedString("period.thisMonth", comment: "This month")
        }
        static var lastMonth: String {
            NSLocalizedString("period.lastMonth", comment: "Last month")
        }
        static var nextMonth: String {
            NSLocalizedString("period.nextMonth", comment: "Next month")
        }
        static var thisYear: String { NSLocalizedString("period.thisYear", comment: "This year") }
        static var lastYear: String { NSLocalizedString("period.lastYear", comment: "Last year") }
        static var nextYear: String { NSLocalizedString("period.nextYear", comment: "Next year") }
        static var allTime: String { NSLocalizedString("period.allTime", comment: "All time") }
        static var custom: String { NSLocalizedString("period.custom", comment: "Custom period") }
        static var startDate: String {
            NSLocalizedString("period.startDate", comment: "Start date")
        }
        static var endDate: String { NSLocalizedString("period.endDate", comment: "End date") }
        static var selectRange: String {
            NSLocalizedString("period.selectRange", comment: "Select range")
        }
        static var selectedRange: String {
            NSLocalizedString("period.selectedRange", comment: "Selected range")
        }
    }

    // MARK: - Statistics
    enum Statistics {
        static var title: String { NSLocalizedString("statistics.title", comment: "") }
        static var trends: String { NSLocalizedString("statistics.trends", comment: "") }
        static var categories: String { NSLocalizedString("statistics.categories", comment: "") }
        static var records: String { NSLocalizedString("statistics.records", comment: "") }
        static var noRecordsFiltered: String {
            NSLocalizedString("statistics.noRecordsFiltered", comment: "")
        }
        static var noRecordsDescription: String {
            NSLocalizedString("statistics.noRecordsDescription", comment: "")
        }
        static var periodComparison: String {
            NSLocalizedString("statistics.periodComparison", comment: "")
        }
        static var vsPreviousPeriod: String {
            NSLocalizedString("statistics.vsPreviousPeriod", comment: "")
        }
        static var vsPreviousYear: String {
            NSLocalizedString("statistics.vsPreviousYear", comment: "")
        }
        static var currentPeriod: String {
            NSLocalizedString("statistics.currentPeriod", comment: "")
        }
        static var previousPeriod: String {
            NSLocalizedString("statistics.previousPeriod", comment: "")
        }
        static var latestRecords: String {
            NSLocalizedString("statistics.latestRecords", comment: "")
        }
        static var noCategoryData: String {
            NSLocalizedString("statistics.noCategoryData", comment: "")
        }
        static var noSubcategoryData: String {
            NSLocalizedString("statistics.noSubcategoryData", comment: "")
        }
        static var noExpensesInPeriod: String {
            NSLocalizedString("statistics.noExpensesInPeriod", comment: "")
        }
        static var topCategories: String {
            NSLocalizedString("statistics.topCategories", comment: "")
        }
        static var topSubcategories: String {
            NSLocalizedString("statistics.topSubcategories", comment: "")
        }
        static var noDataToShow: String {
            NSLocalizedString("statistics.noDataToShow", comment: "")
        }
        static var noRecords: String {
            NSLocalizedString("statistics.noRecords", comment: "")
        }
        static var ofExpense: String {
            NSLocalizedString("statistics.ofExpense", comment: "")
        }
        static var spendingAnalysis: String {
            NSLocalizedString("statistics.spendingAnalysis", comment: "")
        }
        static var incomeAnalysis: String {
            NSLocalizedString("statistics.incomeAnalysis", comment: "")
        }
    }

    // MARK: - Nature
    enum Nature {
        static var title: String {
            NSLocalizedString("nature.expensesByNature", comment: "Expenses by nature")
        }
        static var label: String {
            NSLocalizedString("nature.title", comment: "Nature label")
        }
        static var essential: String { NSLocalizedString("nature.essential", comment: "") }
        static var essentialDesc: String {
            NSLocalizedString("nature.essential.desc", comment: "")
        }
        static var priority: String { NSLocalizedString("nature.priority", comment: "") }
        static var priorityDesc: String {
            NSLocalizedString("nature.priority.desc", comment: "")
        }
        static var optional: String { NSLocalizedString("nature.optional", comment: "") }
        static var optionalDesc: String {
            NSLocalizedString("nature.optional.desc", comment: "")
        }
        static var unclassified: String {
            NSLocalizedString("nature.unclassified", comment: "")
        }
        static var unclassifiedDesc: String {
            NSLocalizedString("nature.unclassified.desc", comment: "")
        }
        static var incomeNotApplicable: String {
            NSLocalizedString(
                "nature.incomeNotApplicable",
                comment: "Message shown when income filter is active - nature classification doesn't apply"
            )
        }
    }

    // MARK: - Records

    enum Records {
        static var title: String { NSLocalizedString("records.title", comment: "") }
        static var latest: String { NSLocalizedString("records.latest", comment: "") }
        static var noRecords: String { NSLocalizedString("records.noRecords", comment: "") }
        static func deleteConfirmTitle(_ count: Int) -> String {
            String(format: NSLocalizedString("records.deleteConfirmTitle", comment: ""), count)
        }
    }

    // MARK: - Filters

    enum Filters {
        static var title: String { NSLocalizedString("filters.title", comment: "") }
        static var all: String { NSLocalizedString("filters.all", comment: "") }
        static var allAccounts: String { NSLocalizedString("filters.allAccounts", comment: "") }
        static var allCategories: String { NSLocalizedString("filters.allCategories", comment: "") }
        static var clearFilters: String { NSLocalizedString("filters.clearFilters", comment: "") }
        static var selectCategories: String {
            NSLocalizedString("filters.selectCategories", comment: "")
        }
        static var selectAll: String {
            NSLocalizedString("filters.selectAll", comment: "")
        }
        static var deselectAll: String {
            NSLocalizedString("filters.deselectAll", comment: "")
        }
        static var noSubcategories: String {
            NSLocalizedString("filters.noSubcategories", comment: "")
        }
        static var noneSelected: String {
            NSLocalizedString("filters.noneSelected", comment: "")
        }
        static var allSubcategories: String {
            NSLocalizedString("filters.allSubcategories", comment: "")
        }
        static var filterOptions: String {
            NSLocalizedString("filters.filterOptions", comment: "")
        }
        static var noteContains: String {
            NSLocalizedString("filters.noteContains", comment: "")
        }
        static var selectAccounts: String {
            NSLocalizedString("filters.selectAccounts", comment: "")
        }
        static var selectTags: String {
            NSLocalizedString("filters.selectTags", comment: "")
        }
        static var selectCurrencies: String {
            NSLocalizedString("filters.selectCurrencies", comment: "")
        }
        static var allTags: String {
            NSLocalizedString("filters.allTags", comment: "")
        }
        static var noTags: String {
            NSLocalizedString("filters.noTags", comment: "")
        }
        static var allCurrencies: String {
            NSLocalizedString("filters.allCurrencies", comment: "")
        }
        static var allNatures: String {
            NSLocalizedString("filters.allNatures", comment: "")
        }
        static func selectedCount(_ count: Int) -> String {
            String(format: NSLocalizedString("filters.selectedCount", comment: ""), count)
        }
        static func subcategoriesSelectedCount(_ count: Int) -> String {
            String(format: NSLocalizedString("filters.subcategoriesSelectedCount", comment: ""), count)
        }
    }

    // MARK: - Actions

    enum Action {
        static var cancel: String { NSLocalizedString("action.cancel", comment: "") }
        static var done: String { NSLocalizedString("action.done", comment: "") }
        static var save: String { NSLocalizedString("action.save", comment: "") }
        static var delete: String { NSLocalizedString("action.delete", comment: "") }
        static var edit: String { NSLocalizedString("action.edit", comment: "") }
        static var add: String { NSLocalizedString("action.add", comment: "") }
        static var viewAll: String { NSLocalizedString("action.viewAll", comment: "") }
        static var viewLess: String { NSLocalizedString("action.viewLess", comment: "") }
        static var multipleEdit: String { NSLocalizedString("action.multipleEdit", comment: "") }
        static var back: String { NSLocalizedString("action.back", comment: "") }
        static var next: String { NSLocalizedString("action.next", comment: "") }
        static var duplicate: String { NSLocalizedString("action.duplicate", comment: "") }
        static var favorite: String { NSLocalizedString("action.favorite", comment: "") }
        static var recurring: String { NSLocalizedString("action.recurring", comment: "") }
        static var saveAsFavorite: String { NSLocalizedString("action.saveAsFavorite", comment: "") }
        static var saveAsRecurring: String { NSLocalizedString("action.saveAsRecurring", comment: "") }
        static var savedAsFavorite: String { NSLocalizedString("action.savedAsFavorite", comment: "") }
        static var savedAsRecurring: String { NSLocalizedString("action.savedAsRecurring", comment: "") }
        static var duplicated: String { NSLocalizedString("action.duplicated", comment: "") }
        static var select: String { NSLocalizedString("action.select", comment: "") }
    }

    // MARK: - Search

    enum Search {
        static var noResults: String { NSLocalizedString("search.noResults", comment: "") }
        static var tryAnotherTerm: String { NSLocalizedString("search.tryAnotherTerm", comment: "") }
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
        static var loadError: String { NSLocalizedString("exchangeRate.loadError", comment: "") }
    }

    // MARK: - Currency Names

    enum Currency {
        static var pen: String { NSLocalizedString("currency.pen", comment: "") }
        static var usd: String { NSLocalizedString("currency.usd", comment: "") }
        static var eur: String { NSLocalizedString("currency.eur", comment: "") }
        static var mxn: String { NSLocalizedString("currency.mxn", comment: "") }
        static var cop: String { NSLocalizedString("currency.cop", comment: "") }
        static var brl: String { NSLocalizedString("currency.brl", comment: "") }
        static var gbp: String { NSLocalizedString("currency.gbp", comment: "") }
    }

    // MARK: - Empty States

    enum Empty {
        static var noData: String { NSLocalizedString("empty.noData", comment: "") }
        static var noTransactions: String { NSLocalizedString("empty.noTransactions", comment: "") }
        static var noFavorites: String { NSLocalizedString("empty.noFavorites", comment: "") }
        static var noTags: String { NSLocalizedString("empty.noTags", comment: "") }
        static var noAccounts: String { NSLocalizedString("empty.noAccounts", comment: "") }
        static var noCategories: String { NSLocalizedString("empty.noCategories", comment: "") }
        static var categoriesDescription: String {
            NSLocalizedString("empty.categoriesDescription", comment: "")
        }
        static var noSubcategories: String {
            NSLocalizedString("empty.noSubcategories", comment: "")
        }
        static var noExpenses: String { NSLocalizedString("empty.noExpenses", comment: "") }
        static var tagsDescription: String {
            NSLocalizedString("empty.tagsDescription", comment: "")
        }
        static var accountsDescription: String {
            NSLocalizedString("empty.accountsDescription", comment: "")
        }
    }

    // MARK: - Transaction

    enum Transaction {
        static var new: String { NSLocalizedString("transaction.new", comment: "") }
        static var edit: String { NSLocalizedString("transaction.edit", comment: "") }
        static var newTransaction: String {
            NSLocalizedString("transaction.newTransaction", comment: "")
        }
        static var editTransaction: String {
            NSLocalizedString("transaction.editTransaction", comment: "")
        }
        static var type: String { NSLocalizedString("transaction.type", comment: "") }
        static var amount: String { NSLocalizedString("transaction.amount", comment: "") }
        static var description: String { NSLocalizedString("transaction.description", comment: "") }
        static var note: String { NSLocalizedString("transaction.note", comment: "") }
        static var notePlaceholder: String {
            NSLocalizedString("transaction.notePlaceholder", comment: "")
        }
        static var date: String { NSLocalizedString("transaction.date", comment: "") }
        static var tags: String { NSLocalizedString("transaction.tags", comment: "") }
        static var addTags: String { NSLocalizedString("transaction.addTags", comment: "") }
        static var category: String { NSLocalizedString("transaction.category", comment: "") }
        static var subcategory: String { NSLocalizedString("transaction.subcategory", comment: "") }
        static var select: String { NSLocalizedString("transaction.select", comment: "") }
        static var total: String { NSLocalizedString("transaction.total", comment: "") }
        static var income: String { NSLocalizedString("transaction.income", comment: "") }
        static var expense: String { NSLocalizedString("transaction.expense", comment: "") }
        static var transfer: String { NSLocalizedString("transaction.transfer", comment: "") }
        static var origin: String { NSLocalizedString("transaction.origin", comment: "") }
        static var destination: String { NSLocalizedString("transaction.destination", comment: "") }
        static var sourceAccount: String {
            NSLocalizedString("transaction.sourceAccount", comment: "")
        }
        static var destinationAccount: String {
            NSLocalizedString("transaction.destinationAccount", comment: "")
        }
        static var account: String { NSLocalizedString("transaction.account", comment: "") }
        static var exchangeRate: String {
            NSLocalizedString("transaction.exchangeRate", comment: "")
        }
        static var willReceive: String { NSLocalizedString("transaction.willReceive", comment: "") }
        static var createAnother: String {
            NSLocalizedString("transaction.createAnother", comment: "")
        }
        static var recents: String { NSLocalizedString("transaction.recents", comment: "") }
        static var successTitle: String {
            NSLocalizedString("transaction.successTitle", comment: "")
        }

        enum TransactionType {
            static var expense: String {
                NSLocalizedString("transaction.type.expense", comment: "")
            }
            static var income: String {
                NSLocalizedString("transaction.type.income", comment: "")
            }
            static var transfer: String {
                NSLocalizedString("transaction.type.transfer", comment: "")
            }
        }
    }

    // MARK: - Account

    enum Account {
        static var new: String { NSLocalizedString("account.new", comment: "") }
        static var edit: String { NSLocalizedString("account.edit", comment: "") }
        static var configure: String { NSLocalizedString("account.configure", comment: "") }
        static var name: String { NSLocalizedString("account.name", comment: "") }
        static var accountName: String { NSLocalizedString("account.accountName", comment: "") }
        static var accountNumber: String { NSLocalizedString("account.accountNumber", comment: "") }
        static var type: String { NSLocalizedString("account.type", comment: "") }
        static var currency: String { NSLocalizedString("account.currency", comment: "") }
        static var balance: String { NSLocalizedString("account.balance", comment: "") }
        static var initialBalance: String {
            NSLocalizedString("account.initialBalance", comment: "")
        }
        static var sign: String { NSLocalizedString("account.sign", comment: "") }
        static var positive: String { NSLocalizedString("account.positive", comment: "") }
        static var negative: String { NSLocalizedString("account.negative", comment: "") }
        static var adjustment: String { NSLocalizedString("account.adjustment", comment: "") }
        static var selected: String { NSLocalizedString("account.selected", comment: "") }
        static var selectAccount: String { NSLocalizedString("account.selectAccount", comment: "") }
        static var archived: String { NSLocalizedString("account.archived", comment: "") }
        static var archive: String { NSLocalizedString("account.archive", comment: "") }
        static var unarchive: String { NSLocalizedString("account.unarchive", comment: "") }
        static var excludeFromStats: String {
            NSLocalizedString("account.excludeFromStats", comment: "")
        }
        static var delete: String { NSLocalizedString("account.delete", comment: "") }
        static var deleteError: String { NSLocalizedString("account.deleteError", comment: "") }
        static var deleteBalanceError: String {
            NSLocalizedString("account.deleteBalanceError", comment: "")
        }
        static var addAccount: String { NSLocalizedString("account.addAccount", comment: "") }

        enum AccountType {
            static var general: String { NSLocalizedString("account.type.general", comment: "") }
            static var cash: String { NSLocalizedString("account.type.cash", comment: "") }
            static var current: String { NSLocalizedString("account.type.current", comment: "") }
            static var savings: String { NSLocalizedString("account.type.savings", comment: "") }
            static var creditCard: String {
                NSLocalizedString("account.type.creditCard", comment: "")
            }
            static var investment: String {
                NSLocalizedString("account.type.investment", comment: "")
            }
            static var loan: String { NSLocalizedString("account.type.loan", comment: "") }
            static var other: String { NSLocalizedString("account.type.other", comment: "") }
        }

        // Balance Adjustments
        static var newBalance: String { NSLocalizedString("account.newBalance", comment: "") }
        static var currentBalance: String {
            NSLocalizedString("account.currentBalance", comment: "")
        }
        static func adjustmentPreview(_ amount: String) -> String {
            String(format: NSLocalizedString("account.adjustmentPreview", comment: ""), amount)
        }
        static var initialBalanceNote: String {
            NSLocalizedString("account.initialBalanceNote", comment: "")
        }
        static var adjustmentNote: String {
            NSLocalizedString("account.adjustmentNote", comment: "")
        }
        static func existingInitialBalance(_ amount: String) -> String {
            String(format: NSLocalizedString("account.existingInitialBalance", comment: ""), amount)
        }
        static var modifyInitialBalance: String {
            NSLocalizedString("account.modifyInitialBalance", comment: "")
        }
        static var adjustmentDate: String {
            NSLocalizedString("account.adjustmentDate", comment: "")
        }
        static var finalBalance: String {
            NSLocalizedString("account.finalBalance", comment: "")
        }
        static var adjustByEntry: String {
            NSLocalizedString("account.adjustByEntry", comment: "")
        }
        static var adjustByEntryDesc: String {
            NSLocalizedString("account.adjustByEntryDesc", comment: "")
        }
        static var changeInitialBalanceName: String {
            NSLocalizedString("account.changeInitialBalanceName", comment: "")
        }
        static var changeInitialBalanceDesc: String {
            NSLocalizedString("account.changeInitialBalanceDesc", comment: "")
        }

    }

    // MARK: - Category

    enum Category {
        static var new: String { NSLocalizedString("category.new", comment: "") }
        static var edit: String { NSLocalizedString("category.edit", comment: "") }
        static var editTitle: String { NSLocalizedString("category.editTitle", comment: "") }
        static var name: String { NSLocalizedString("category.name", comment: "") }
        static var nature: String { NSLocalizedString("category.nature", comment: "") }
        static var show: String { NSLocalizedString("category.show", comment: "") }
        static var hiddenTitle: String { NSLocalizedString("category.hiddenTitle", comment: "") }
        static var hiddenDescription: String {
            NSLocalizedString("category.hiddenDescription", comment: "")
        }
        static var addSubcategory: String {
            NSLocalizedString("category.addSubcategory", comment: "")
        }
        static var subcategories: String {
            NSLocalizedString("category.subcategories", comment: "")
        }
        static var noSubcategoriesYet: String {
            NSLocalizedString("category.noSubcategoriesYet", comment: "")
        }
        static var requiresSubcategory: String {
            NSLocalizedString("category.requiresSubcategory", comment: "")
        }
        static var addOneSubcategory: String {
            NSLocalizedString("category.addOneSubcategory", comment: "")
        }
        static var delete: String { NSLocalizedString("category.delete", comment: "") }
        static var deleteConfirmTitle: String {
            NSLocalizedString("category.deleteConfirmTitle", comment: "")
        }
        static var deleteConfirmMessage: String {
            NSLocalizedString("category.deleteConfirmMessage", comment: "")
        }
        static var cannotDeleteTitle: String {
            NSLocalizedString("category.cannotDeleteTitle", comment: "")
        }
        static func cannotDeleteMessage(_ count: Int) -> String {
            String(
                format: NSLocalizedString("category.cannotDeleteMessage", comment: ""),
                count
            )
        }
        static var newCategory: String {
            NSLocalizedString("category.newCategory", comment: "")
        }
        static var namePlaceholder: String {
            NSLocalizedString("category.namePlaceholder", comment: "")
        }
        static var activeSubcategories: String {
            NSLocalizedString("category.activeSubcategories", comment: "")
        }
        static var hiddenSubcategories: String {
            NSLocalizedString("category.hiddenSubcategories", comment: "")
        }
        static var details: String {
            NSLocalizedString("category.details", comment: "")
        }
        static var others: String {
            NSLocalizedString("category.others", comment: "")
        }
    }

    // MARK: - Subcategory

    enum Subcategory {
        static var newTitle: String { NSLocalizedString("subcategory.newTitle", comment: "") }
        static var editTitle: String { NSLocalizedString("subcategory.editTitle", comment: "") }
        static var delete: String { NSLocalizedString("subcategory.delete", comment: "") }
        static var deleteConfirmTitle: String {
            NSLocalizedString("subcategory.deleteConfirmTitle", comment: "")
        }
        static var deleteConfirmMessage: String {
            NSLocalizedString("subcategory.deleteConfirmMessage", comment: "")
        }
        static var cannotDeleteTitle: String {
            NSLocalizedString("subcategory.cannotDeleteTitle", comment: "")
        }
        static func cannotDeleteMessage(_ count: Int) -> String {
            String(
                format: NSLocalizedString("subcategory.cannotDeleteMessage", comment: ""),
                count
            )
        }

        // Transfer sheet
        static var transferTitle: String {
            NSLocalizedString("subcategory.transferTitle", comment: "")
        }
        static var transferHeader: String {
            NSLocalizedString("subcategory.transferHeader", comment: "")
        }
        static func transferDescription(_ count: Int, _ name: String) -> String {
            String(
                format: NSLocalizedString("subcategory.transferDescription", comment: ""),
                count,
                name
            )
        }
        static var transferToSpecific: String {
            NSLocalizedString("subcategory.transferToSpecific", comment: "")
        }
        static var transferToSpecificDesc: String {
            NSLocalizedString("subcategory.transferToSpecificDesc", comment: "")
        }
        static var transferToUnassigned: String {
            NSLocalizedString("subcategory.transferToUnassigned", comment: "")
        }
        static var transferToUnassignedDesc: String {
            NSLocalizedString("subcategory.transferToUnassignedDesc", comment: "")
        }
        static var deleteTransactions: String {
            NSLocalizedString("subcategory.deleteTransactions", comment: "")
        }
        static var deleteTransactionsDesc: String {
            NSLocalizedString("subcategory.deleteTransactionsDesc", comment: "")
        }
        static var selectDestination: String {
            NSLocalizedString("subcategory.selectDestination", comment: "")
        }
        static var deleteTransactionsConfirmTitle: String {
            NSLocalizedString("subcategory.deleteTransactionsConfirmTitle", comment: "")
        }
        static var deleteTransactionsConfirm: String {
            NSLocalizedString("subcategory.deleteTransactionsConfirm", comment: "")
        }
        static func deleteTransactionsConfirmMessage(_ count: Int) -> String {
            String(
                format: NSLocalizedString("subcategory.deleteTransactionsConfirmMessage", comment: ""),
                count
            )
        }
        static var details: String {
            NSLocalizedString("subcategory.details", comment: "")
        }
        static var namePlaceholder: String {
            NSLocalizedString("subcategory.namePlaceholder", comment: "")
        }
        static var unassigned: String {
            NSLocalizedString("subcategory.unassigned", comment: "")
        }
        static var noSubcategory: String {
            NSLocalizedString("subcategories.noSubcategory", comment: "")
        }
    }

    // MARK: - Tag

    enum Tag {
        static var new: String { NSLocalizedString("tag.new", comment: "") }
        static var edit: String { NSLocalizedString("tag.edit", comment: "") }
        static var newTag: String { NSLocalizedString("tag.newTag", comment: "") }
        static var editTag: String { NSLocalizedString("tag.editTag", comment: "") }
        static var createFirstDescription: String {
            NSLocalizedString("tag.createFirstDescription", comment: "")
        }
        static var delete: String { NSLocalizedString("tag.delete", comment: "") }
        static var deleteConfirmation: String {
            NSLocalizedString("tag.deleteConfirmation", comment: "")
        }
        static var namePlaceholder: String {
            NSLocalizedString("tag.namePlaceholder", comment: "")
        }
        static var color: String {
            NSLocalizedString("tag.color", comment: "")
        }
        static func colorSelected(_ hex: String) -> String {
            String(format: NSLocalizedString("tag.colorSelected", comment: ""), hex)
        }
    }

    // MARK: - Alert

    enum Alert {
        static var unsavedChanges: String { NSLocalizedString("alert.unsavedChanges", comment: "") }
        static var discardChanges: String { NSLocalizedString("alert.discardChanges", comment: "") }
        static var keepEditing: String { NSLocalizedString("alert.keepEditing", comment: "") }
        static var confirmDelete: String { NSLocalizedString("alert.confirmDelete", comment: "") }
        static var deleteWarning: String { NSLocalizedString("alert.deleteWarning", comment: "") }
    }

    // MARK: - Import

    enum Import {
        static var title: String { NSLocalizedString("import.title", comment: "") }
        static var selectFile: String { NSLocalizedString("import.selectFile", comment: "") }
        static var importing: String { NSLocalizedString("import.importing", comment: "") }
        static var downloadTemplate: String {
            NSLocalizedString("import.downloadTemplate", comment: "")
        }
        static var createCategories: String {
            NSLocalizedString("import.createCategories", comment: "")
        }
        static var continueBtn: String { NSLocalizedString("import.continue", comment: "") }
        static var noAccountsAvailable: String {
            NSLocalizedString("import.noAccountsAvailable", comment: "")
        }
        static var createAccountFirst: String {
            NSLocalizedString("import.createAccountFirst", comment: "")
        }
        static var completed: String {
            NSLocalizedString("import.completed", comment: "")
        }
        static var importError: String {
            NSLocalizedString("import.error", comment: "")
        }
        static var templateGenerated: String {
            NSLocalizedString("import.templateGenerated", comment: "")
        }
        static var templateGeneratedMessage: String {
            NSLocalizedString("import.templateGeneratedMessage", comment: "")
        }
        static var introDescription: String {
            NSLocalizedString("import.introDescription", comment: "")
        }
        static var templateDescription: String {
            NSLocalizedString("import.templateDescription", comment: "")
        }
        static var categoriesDescription: String {
            NSLocalizedString("import.categoriesDescription", comment: "")
        }
        static var selectAccount: String {
            NSLocalizedString("import.selectAccount", comment: "")
        }
        static var fileUrlError: String {
            NSLocalizedString("import.fileUrlError", comment: "")
        }
        static var createAccountBeforeImport: String {
            NSLocalizedString("import.createAccountBeforeImport", comment: "")
        }

        // Multi-currency import
        static var multiCurrencyDetected: String {
            NSLocalizedString("import.multiCurrencyDetected", comment: "")
        }
        static var assignAccountPerCurrency: String {
            NSLocalizedString("import.assignAccountPerCurrency", comment: "")
        }
        static var selectAccountForCurrency: String {
            NSLocalizedString("import.selectAccountForCurrency", comment: "")
        }
        static func currenciesDetected(_ count: Int) -> String {
            String(format: NSLocalizedString("import.currenciesDetected", comment: ""), count)
        }
        static func recordsImportedMultiCurrency(_ count: Int, _ currencies: Int) -> String {
            String(format: NSLocalizedString("import.recordsImportedMultiCurrency", comment: ""), count, currencies)
        }
        static func noAccountsForCurrency(_ currency: String) -> String {
            String(format: NSLocalizedString("import.noAccountsForCurrency", comment: ""), currency)
        }
        static var noCurrenciesDetected: String {
            NSLocalizedString("import.noCurrenciesDetected", comment: "")
        }
        static var importAction: String {
            NSLocalizedString("import.importAction", comment: "")
        }
    }

    // MARK: - Export

    enum Export {
        static var title: String { NSLocalizedString("export.title", comment: "") }
        static var filters: String { NSLocalizedString("export.filters", comment: "") }
        static var columns: String { NSLocalizedString("export.columns", comment: "") }
        static var summary: String { NSLocalizedString("export.summary", comment: "") }
        static var format: String { NSLocalizedString("export.format", comment: "") }
        static var period: String { NSLocalizedString("export.period", comment: "") }
        static var selectAll: String { NSLocalizedString("export.selectAll", comment: "") }
        static var deselectAll: String { NSLocalizedString("export.deselectAll", comment: "") }
        static var customizeFile: String { NSLocalizedString("export.customizeFile", comment: "") }
        static var csvGeneratedSuccess: String {
            NSLocalizedString("export.csvGeneratedSuccess", comment: "")
        }
        static var confirmExport: String { NSLocalizedString("export.confirmExport", comment: "") }
        static var selectColumns: String {
            NSLocalizedString("export.selectColumns", comment: "")
        }
        static var availableColumns: String {
            NSLocalizedString("export.availableColumns", comment: "")
        }
        static var columnsDescription: String {
            NSLocalizedString("export.columnsDescription", comment: "")
        }
        static var summaryAndExport: String {
            NSLocalizedString("export.summaryAndExport", comment: "")
        }
        static var summaryDescription: String {
            NSLocalizedString("export.summaryDescription", comment: "")
        }
        static var filtersSummary: String {
            NSLocalizedString("export.filtersSummary", comment: "")
        }
        static var columnsToExport: String {
            NSLocalizedString("export.columnsToExport", comment: "")
        }
        static var exportToCSV: String {
            NSLocalizedString("export.exportToCSV", comment: "")
        }
        static var exportBtn: String {
            NSLocalizedString("export.exportBtn", comment: "")
        }
        static var exportError: String {
            NSLocalizedString("export.exportError", comment: "")
        }
        static var exportCompleted: String {
            NSLocalizedString("export.exportCompleted", comment: "")
        }
        static var backToSettings: String {
            NSLocalizedString("export.backToSettings", comment: "")
        }
        static var exportData: String {
            NSLocalizedString("export.exportData", comment: "")
        }
        static var greaterThan: String {
            NSLocalizedString("export.greaterThan", comment: "")
        }
        static var lessThan: String {
            NSLocalizedString("export.lessThan", comment: "")
        }
        static var selectSingleCurrency: String {
            NSLocalizedString("export.selectSingleCurrency", comment: "")
        }
        static var allAvailable: String {
            NSLocalizedString("export.allAvailable", comment: "")
        }
        static var noTagsSelected: String {
            NSLocalizedString("export.noTagsSelected", comment: "")
        }
        static var noSubcategorySelected: String {
            NSLocalizedString("export.noSubcategorySelected", comment: "")
        }
        static var any: String {
            NSLocalizedString("export.any", comment: "")
        }
        static var between: String {
            NSLocalizedString("export.between", comment: "")
        }
        static var condition: String {
            NSLocalizedString("export.condition", comment: "")
        }
        static var noneSelected: String {
            NSLocalizedString("export.noneSelected", comment: "")
        }
        static func accountsSelected(_ count: Int) -> String {
            String(format: NSLocalizedString("export.accountsSelected", comment: ""), count)
        }
        static var allCategories: String {
            NSLocalizedString("export.allCategories", comment: "")
        }
        static func subcategoriesSelected(_ count: Int) -> String {
            String(format: NSLocalizedString("export.subcategoriesSelected", comment: ""), count)
        }
        static var allTags: String {
            NSLocalizedString("export.allTags", comment: "")
        }
        static var allCurrencies: String {
            NSLocalizedString("export.allCurrencies", comment: "")
        }
    }

    // MARK: - Favorites

    enum Favorites {
        static var title: String { NSLocalizedString("favorites.title", comment: "") }
        static var new: String { NSLocalizedString("favorites.new", comment: "") }
        static var edit: String { NSLocalizedString("favorites.edit", comment: "") }
        static var noFavorites: String { NSLocalizedString("favorites.noFavorites", comment: "") }
        static var createTemplate: String {
            NSLocalizedString("favorites.createTemplate", comment: "")
        }
        static var newTitle: String {
            NSLocalizedString("favorites.newTitle", comment: "")
        }
        static var editTitle: String {
            NSLocalizedString("favorites.editTitle", comment: "")
        }
        static var namePlaceholder: String {
            NSLocalizedString("favorites.namePlaceholder", comment: "")
        }
        static var notConfigured: String {
            NSLocalizedString("favorites.notConfigured", comment: "")
        }
        static var descriptionPlaceholder: String {
            NSLocalizedString("favorites.descriptionPlaceholder", comment: "")
        }
        static var saveDescription: String {
            NSLocalizedString("favorites.saveDescription", comment: "")
        }
    }

    // MARK: - Scheduled

    enum Scheduled {
        static var saveDescription: String {
            NSLocalizedString("scheduled.saveDescription", comment: "")
        }
    }

    // MARK: - Settings

    enum Settings {
        static var title: String { NSLocalizedString("settings.title", comment: "") }
        static var theme: String { NSLocalizedString("settings.theme", comment: "") }
        static var themeDescription: String {
            NSLocalizedString("settings.themeDescription", comment: "")
        }
        static var currency: String { NSLocalizedString("settings.currency", comment: "") }
        static var appIcon: String { NSLocalizedString("settings.appIcon", comment: "") }
        static var appIconDescription: String {
            NSLocalizedString("settings.appIconDescription", comment: "")
        }
        static var personalization: String {
            NSLocalizedString("settings.personalization", comment: "")
        }
        static var personalizationDescription: String {
            NSLocalizedString("settings.personalizationDescription", comment: "")
        }
        static var accounts: String { NSLocalizedString("settings.accounts", comment: "") }
        static var categories: String { NSLocalizedString("settings.categories", comment: "") }
        static var tags: String { NSLocalizedString("settings.tags", comment: "") }
        static var notifications: String {
            NSLocalizedString("settings.notifications", comment: "")
        }
        static var favorites: String { NSLocalizedString("settings.favorites", comment: "") }
        static var budgetsFavorites: String {
            NSLocalizedString("settings.budgetsFavorites", comment: "")
        }
        static var budgetsFavoritesInfo: String {
            NSLocalizedString("settings.budgetsFavoritesInfo", comment: "")
        }
        static var budgetsFavoritesEmptyHint: String {
            NSLocalizedString("settings.budgetsFavoritesEmptyHint", comment: "")
        }
        static var budgetsFavoritesReorder: String {
            NSLocalizedString("settings.budgetsFavoritesReorder", comment: "")
        }
        static var tabBarConfig: String {
            NSLocalizedString("settings.tabBarConfig", comment: "")
        }
        static var tabBarConfigInfo: String {
            NSLocalizedString("settings.tabBarConfigInfo", comment: "")
        }
        static var tabBarConfigActive: String {
            NSLocalizedString("settings.tabBarConfigActive", comment: "")
        }
        static var tabBarConfigAvailable: String {
            NSLocalizedString("settings.tabBarConfigAvailable", comment: "")
        }
        static var tabBarConfigReorderHint: String {
            NSLocalizedString("settings.tabBarConfigReorderHint", comment: "")
        }
        static var tabBarConfigMinWarning: String {
            NSLocalizedString("settings.tabBarConfigMinWarning", comment: "")
        }
        static var tabBarConfigMaxWarning: String {
            NSLocalizedString("settings.tabBarConfigMaxWarning", comment: "")
        }
        static var plannedPayments: String {
            NSLocalizedString("settings.plannedPayments", comment: "")
        }
        static var voiceInputEnabled: String {
            NSLocalizedString("settings.voiceInputEnabled", comment: "")
        }
        static var voiceLanguage: String {
            NSLocalizedString("settings.voiceLanguage", comment: "")
        }
        static var imageInputEnabled: String {
            NSLocalizedString("settings.imageInputEnabled", comment: "")
        }
        static var resetData: String { NSLocalizedString("settings.resetData", comment: "") }
        static var version: String { NSLocalizedString("settings.version", comment: "") }
        static var light: String { NSLocalizedString("settings.light", comment: "") }
        static var dark: String { NSLocalizedString("settings.dark", comment: "") }
        static var system: String { NSLocalizedString("settings.system", comment: "") }
        static var defaultCurrency: String {
            NSLocalizedString("settings.defaultCurrency", comment: "")
        }
        static var currentIcon: String { NSLocalizedString("settings.currentIcon", comment: "") }
        static var resetAllData: String { NSLocalizedString("settings.resetAllData", comment: "") }
        static var deleteAllData: String {
            NSLocalizedString("settings.deleteAllData", comment: "")
        }
        static var currencyAndExchange: String {
            NSLocalizedString("settings.currencyAndExchange", comment: "")
        }
        static var currencyDescription: String {
            NSLocalizedString("settings.currencyDescription", comment: "")
        }
        static var preferredCurrency: String {
            NSLocalizedString("settings.preferredCurrency", comment: "")
        }
        static var exchangeRate: String { NSLocalizedString("settings.exchangeRate", comment: "") }
        static var secondaryCurrencies: String {
            NSLocalizedString("settings.secondaryCurrencies", comment: "")
        }
        static var secondaryCurrenciesHint: String {
            NSLocalizedString("settings.secondaryCurrenciesHint", comment: "")
        }

        static var versionInfo: String { NSLocalizedString("settings.versionInfo", comment: "") }

        // Sections
        static var organization: String { NSLocalizedString("settings.organization", comment: "") }
        static var preferences: String { NSLocalizedString("settings.preferences", comment: "") }
        static var data: String { NSLocalizedString("settings.data", comment: "") }
        static var security: String { NSLocalizedString("settings.security", comment: "") }
        static var help: String { NSLocalizedString("settings.help", comment: "") }
        static var legal: String { NSLocalizedString("settings.legal", comment: "") }

        // Rows
        static var importData: String { NSLocalizedString("settings.importData", comment: "") }
        static var exportData: String { NSLocalizedString("settings.exportData", comment: "") }
        static var wipeData: String { NSLocalizedString("settings.wipeData", comment: "") }
        static var faceId: String { NSLocalizedString("settings.faceId", comment: "") }
        static var permissions: String { NSLocalizedString("settings.permissions", comment: "") }
        static var subscriptions: String {
            NSLocalizedString("settings.subscriptions", comment: "")
        }
        static var rateApp: String { NSLocalizedString("settings.rateApp", comment: "") }
        static var tips: String { NSLocalizedString("settings.tips", comment: "") }
        static var faq: String { NSLocalizedString("settings.faq", comment: "") }
        static var contact: String { NSLocalizedString("settings.contact", comment: "") }
        static var privacy: String { NSLocalizedString("settings.privacy", comment: "") }
        static var terms: String { NSLocalizedString("settings.terms", comment: "") }

        // system, light, dark removed (duplicates)

        static var defaultPeriod: String {
            NSLocalizedString("settings.defaultPeriod", comment: "")
        }
        static var defaultPeriodDescription: String {
            NSLocalizedString("settings.defaultPeriodDescription", comment: "")
        }
        static var colorfulIcons: String {
            NSLocalizedString("settings.colorfulIcons", comment: "")
        }
        static var colorfulIconsDescription: String {
            NSLocalizedString("settings.colorfulIconsDescription", comment: "")
        }
        static var firstWeekday: String {
            NSLocalizedString("settings.firstWeekday", comment: "")
        }
        static var firstWeekdayDescription: String {
            NSLocalizedString("settings.firstWeekdayDescription", comment: "")
        }
        static var sunday: String {
            NSLocalizedString("settings.sunday", comment: "")
        }
        static var monday: String {
            NSLocalizedString("settings.monday", comment: "")
        }
        static var widgetHints: String {
            NSLocalizedString("settings.widgetHints", comment: "")
        }
        static var widgetHintsDescription: String {
            NSLocalizedString("settings.widgetHintsDescription", comment: "")
        }
        static var decimalPlaces: String {
            NSLocalizedString("settings.decimalPlaces", comment: "")
        }
        static var decimalPlacesDescription: String {
            NSLocalizedString("settings.decimalPlacesDescription", comment: "")
        }
        static var decimalsNone: String {
            NSLocalizedString("settings.decimalsNone", comment: "")
        }
        static var decimalsOne: String {
            NSLocalizedString("settings.decimalsOne", comment: "")
        }
        static var decimalsTwo: String {
            NSLocalizedString("settings.decimalsTwo", comment: "")
        }
        static var currencyFormat: String {
            NSLocalizedString("settings.currencyFormat", comment: "")
        }
        static var currencyFormatDescription: String {
            NSLocalizedString("settings.currencyFormatDescription", comment: "")
        }
        static var currencyCode: String {
            NSLocalizedString("settings.currencyCode", comment: "")
        }
        static var currencySymbol: String {
            NSLocalizedString("settings.currencySymbol", comment: "")
        }
        // resetData removed (duplicate)
        static var resetDataDescription: String {
            NSLocalizedString("settings.resetDataDescription", comment: "")
        }
        // deleteAllData removed (duplicate)
        static var deleteDataConfirmation: String {
            NSLocalizedString("settings.deleteDataConfirmation", comment: "")
        }
        static var deleteDataWarning: String {
            NSLocalizedString("settings.deleteDataWarning", comment: "")
        }
        static var delete: String { NSLocalizedString("settings.delete", comment: "") }
        static var cancel: String { NSLocalizedString("settings.cancel", comment: "") }
        static var iconOriginal: String { NSLocalizedString("settings.iconOriginal", comment: "") }
        static var iconDark: String { NSLocalizedString("settings.iconDark", comment: "") }
        static var iconLight: String { NSLocalizedString("settings.iconLight", comment: "") }
        static var iconNeon: String { NSLocalizedString("settings.iconNeon", comment: "") }
        static var deleteAllDataAction: String {
            NSLocalizedString("settings.deleteAllDataAction", comment: "")
        }
        static var deletingData: String {
            NSLocalizedString("settings.deletingData", comment: "")
        }
        static var appIconTitle: String {
            NSLocalizedString("settings.appIconTitle", comment: "")
        }
        static var iconNotSupported: String {
            NSLocalizedString("settings.iconNotSupported", comment: "")
        }
        static func iconChangeFailed(_ error: String) -> String {
            String(format: NSLocalizedString("settings.iconChangeFailed", comment: ""), error)
        }
        static var deleteDataError: String {
            NSLocalizedString("settings.deleteDataError", comment: "")
        }
        static var deleteDataUnknownError: String {
            NSLocalizedString("settings.deleteDataUnknownError", comment: "")
        }
    }

    // MARK: - Profile

    enum Profile {
        static var title: String { NSLocalizedString("profile.title", comment: "") }
        static var edit: String { NSLocalizedString("profile.edit", comment: "") }
        static var importSuccess: String { NSLocalizedString("profile.importSuccess", comment: "") }
        static var importError: String { NSLocalizedString("profile.importError", comment: "") }
        static var appearance: String { NSLocalizedString("profile.appearance", comment: "") }
        static var personalDetails: String {
            NSLocalizedString("profile.personalDetails", comment: "")
        }
        static var changePhoto: String { NSLocalizedString("profile.changePhoto", comment: "") }
        static var addPhoto: String { NSLocalizedString("profile.addPhoto", comment: "") }
        static var yourName: String { NSLocalizedString("profile.yourName", comment: "") }
        static var aliasPlaceholder: String {
            NSLocalizedString("profile.aliasPlaceholder", comment: "")
        }
        static var characters: String { NSLocalizedString("profile.characters", comment: "") }
        static var minChars: String { NSLocalizedString("profile.minChars", comment: "") }
        static var maxChars: String { NSLocalizedString("profile.maxChars", comment: "") }
        static var allowedChars: String { NSLocalizedString("profile.allowedChars", comment: "") }
        static var aliasAvailable: String {
            NSLocalizedString("profile.aliasAvailable", comment: "")
        }
        static var aliasHelper: String { NSLocalizedString("profile.aliasHelper", comment: "") }
        static var privacyTitle: String { NSLocalizedString("profile.privacyTitle", comment: "") }
        static var privacyDesc: String { NSLocalizedString("profile.privacyDesc", comment: "") }
        static var aliasFutureNote: String {
            NSLocalizedString("profile.aliasFutureNote", comment: "")
        }
    }

    // MARK: - Common

    enum Common {
        static var accept: String { NSLocalizedString("common.accept", comment: "") }
        static var name: String { NSLocalizedString("common.name", comment: "") }
        static var alias: String { NSLocalizedString("common.alias", comment: "") }
        static var color: String { NSLocalizedString("common.color", comment: "") }
        static var icon: String { NSLocalizedString("common.icon", comment: "") }
        static var changeIcon: String { NSLocalizedString("common.changeIcon", comment: "") }
        static var search: String { NSLocalizedString("common.search", comment: "") }
        static var loading: String { NSLocalizedString("common.loading", comment: "") }
        static var error: String { NSLocalizedString("common.error", comment: "") }
        static var success: String { NSLocalizedString("common.success", comment: "") }
        static var unknownError: String { NSLocalizedString("common.unknownError", comment: "") }
        static var saveError: String { NSLocalizedString("common.saveError", comment: "") }
        static var deleteError: String { NSLocalizedString("common.deleteError", comment: "") }
        static var dataPrivacy: String { NSLocalizedString("common.dataPrivacy", comment: "") }
        static var active: String { NSLocalizedString("common.active", comment: "") }
        static var inactive: String { NSLocalizedString("common.inactive", comment: "") }
        static var hidden: String { NSLocalizedString("common.hidden", comment: "") }
        static var archived: String { NSLocalizedString("common.archived", comment: "") }
        static var recent: String { NSLocalizedString("common.recent", comment: "") }
        static var updatingRecords: String {
            NSLocalizedString("common.updatingRecords", comment: "")
        }
        static var recalculatingConversions: String {
            NSLocalizedString("common.recalculatingConversions", comment: "")
        }
        static var next: String { NSLocalizedString("common.next", comment: "") }
        static var moreOptions: String { NSLocalizedString("common.moreOptions", comment: "") }
        static var comingSoon: String { NSLocalizedString("common.comingSoon", comment: "") }
        static var all: String { NSLocalizedString("common.all", comment: "") }
        static var others: String { NSLocalizedString("common.others", comment: "") }
        static var remaining: String { NSLocalizedString("common.remaining", comment: "") }
        static var uncategorized: String { NSLocalizedString("common.uncategorized", comment: "") }
        static var date: String { NSLocalizedString("common.date", comment: "") }
        static var amount: String { NSLocalizedString("common.amount", comment: "") }
        static var base: String { NSLocalizedString("common.base", comment: "") }
        static var selectedDate: String { NSLocalizedString("common.selectedDate", comment: "") }
        static var selectedValue: String { NSLocalizedString("common.selectedValue", comment: "") }
        static var selectColor: String { NSLocalizedString("common.selectColor", comment: "") }
        static var useThisColor: String { NSLocalizedString("common.useThisColor", comment: "") }
        static var newColor: String { NSLocalizedString("common.newColor", comment: "") }
        static var understood: String { NSLocalizedString("common.understood", comment: "") }
        static var cannotUndo: String { NSLocalizedString("common.cannotUndo", comment: "") }
        static var general: String { NSLocalizedString("common.general", comment: "") }
        static var status: String { NSLocalizedString("common.status", comment: "") }
        static var actions: String { NSLocalizedString("common.actions", comment: "") }
        static var lastUpdate: String { NSLocalizedString("common.lastUpdate", comment: "") }
        static var cancel: String { NSLocalizedString("action.cancel", comment: "") }
        static var apply: String { NSLocalizedString("common.apply", comment: "Apply action") }
        static var selected: String { NSLocalizedString("common.selected", comment: "") }
        static var details: String { NSLocalizedString("common.details", comment: "") }
        static var select: String { NSLocalizedString("common.select", comment: "") }
    }

    // MARK: - Widgets

    enum Widget {
        static var today: String { NSLocalizedString("widget.today", comment: "") }
        static var noData: String { NSLocalizedString("widget.noData", comment: "") }
        static var loading: String { NSLocalizedString("widget.loading", comment: "") }
        static var preferences: String { NSLocalizedString("widget.preferences", comment: "") }
        static var visible: String { NSLocalizedString("widget.visible", comment: "") }
        static var size: String { NSLocalizedString("widget.size", comment: "") }
        static var compact: String { NSLocalizedString("widget.compact", comment: "") }
        static var expanded: String { NSLocalizedString("widget.expanded", comment: "") }
        static var top3: String { NSLocalizedString("widget.top3", comment: "") }
        static var top5: String { NSLocalizedString("widget.top5", comment: "") }
        static var summary: String { NSLocalizedString("widget.summary", comment: "") }
        static var list: String { NSLocalizedString("widget.list", comment: "") }
        static var calendar: String { NSLocalizedString("widget.calendar", comment: "") }
        static var preferencesDescription: String {
            NSLocalizedString("widget.preferences.description", comment: "")
        }
        static var resetLayout: String { NSLocalizedString("widget.resetLayout", comment: "") }
        static var alwaysVisible: String { NSLocalizedString("widget.alwaysVisible", comment: "") }
        static var fixedPosition: String { NSLocalizedString("widget.fixedPosition", comment: "") }
        static var sizeLabel: String { NSLocalizedString("widget.sizeLabel", comment: "") }
        static var main: String { NSLocalizedString("widget.main", comment: "") }
        static var topCategories: String { NSLocalizedString("widget.topCategories", comment: "") }
        static var topSubcategories: String {
            NSLocalizedString("widget.topSubcategories", comment: "")
        }

        static var subcategories: String { NSLocalizedString("widget.subcategories", comment: "") }
        static var categories: String { NSLocalizedString("widget.categories", comment: "") }
        static var noExpensesPeriod: String {
            NSLocalizedString("widget.noExpensesPeriod", comment: "")
        }
        static var noExpensesSubcategoriesPeriod: String {
            NSLocalizedString("widget.noExpensesSubcategoriesPeriod", comment: "")
        }
        static var noExpensesNaturePeriod: String {
            NSLocalizedString("widget.noExpensesNaturePeriod", comment: "")
        }
        static var noExpensesDescriptionCategories: String {
            NSLocalizedString("widget.noExpensesDescriptionCategories", comment: "")
        }
        static var noExpensesDescriptionSubcategories: String {
            NSLocalizedString("widget.noExpensesDescriptionSubcategories", comment: "")
        }
        static var of: String { NSLocalizedString("widget.of", comment: "") }
        static var ofTotal: String { NSLocalizedString("widget.ofTotal", comment: "") }
        static var ofExpense: String { NSLocalizedString("widget.ofExpense", comment: "") }
        static var categoryAbbr: String { NSLocalizedString("widget.categoryAbbr", comment: "") }
        static var distributionByCategory: String {
            NSLocalizedString("widget.distributionByCategory", comment: "")
        }
        static var distributionBySubcategory: String {
            NSLocalizedString("widget.distributionBySubcategory", comment: "")
        }
        static var distributionByNature: String {
            NSLocalizedString("widget.distributionByNature", comment: "")
        }
        static var distributionByTag: String {
            NSLocalizedString("widget.distributionByTag", comment: "")
        }
        static var noDataForPeriod: String {
            NSLocalizedString("widget.noDataForPeriod", comment: "")
        }
        static func selectCurrencies(_ currency: String) -> String {
            String(format: NSLocalizedString("widget.selectCurrencies", comment: ""), currency)
        }
        static var currenciesToCompare: String {
            NSLocalizedString("widget.currenciesToCompare", comment: "")
        }
        static var noRecordsForFilters: String {
            NSLocalizedString("widget.noRecordsForFilters", comment: "")
        }
        static var recordsWillAppear: String {
            NSLocalizedString("widget.recordsWillAppear", comment: "")
        }
        static var total: String { NSLocalizedString("widget.total", comment: "") }

        // Widget Hints
        enum Hint {
            static var trend: String {
                NSLocalizedString("widget.hint.trend", comment: "")
            }
            static var topCategories: String {
                NSLocalizedString("widget.hint.topCategories", comment: "")
            }
            static var topSubcategories: String {
                NSLocalizedString("widget.hint.topSubcategories", comment: "")
            }
            static var categoriesPie: String {
                NSLocalizedString("widget.hint.categoriesPie", comment: "")
            }
            static var subcategoriesPie: String {
                NSLocalizedString("widget.hint.subcategoriesPie", comment: "")
            }
            static var tagsPie: String {
                NSLocalizedString("widget.hint.tagsPie", comment: "")
            }
            static var natureTrend: String {
                NSLocalizedString("widget.hint.natureTrend", comment: "")
            }
            static var cashFlow: String {
                NSLocalizedString("widget.hint.cashFlow", comment: "")
            }
            static var recentRecords: String {
                NSLocalizedString("widget.hint.recentRecords", comment: "")
            }
            static var budgets: String {
                NSLocalizedString("widget.hint.budgets", comment: "")
            }
            static var exchangeRate: String {
                NSLocalizedString("widget.hint.exchangeRate", comment: "")
            }
            static var scheduledPayments: String {
                NSLocalizedString("widget.hint.scheduledPayments", comment: "")
            }
            static var spendingAnalysis: String {
                NSLocalizedString("widget.hint.spendingAnalysis", comment: "")
            }
            static var incomeAnalysis: String {
                NSLocalizedString("widget.hint.incomeAnalysis", comment: "")
            }
        }
    }

    // MARK: - Widget Types

    enum WidgetType {
        static var trend: String { NSLocalizedString("widgetType.trend", comment: "") }
        static var topSpending: String { NSLocalizedString("widgetType.topSpending", comment: "") }
        static var topSubcategories: String {
            NSLocalizedString("widgetType.topSubcategories", comment: "")
        }
        static var cashFlow: String { NSLocalizedString("widgetType.cashFlow", comment: "") }
        static var categoriesPie: String {
            NSLocalizedString("widgetType.categoriesPie", comment: "")
        }
        static var subcategoriesPie: String {
            NSLocalizedString("widgetType.subcategoriesPie", comment: "")
        }
        static var latestRecords: String {
            NSLocalizedString("widgetType.latestRecords", comment: "")
        }
        static var expensesByNature: String {
            NSLocalizedString("widgetType.expensesByNature", comment: "")
        }
        static var exchangeRate: String {
            NSLocalizedString("widgetType.exchangeRate", comment: "")
        }
        static var budgets: String {
            NSLocalizedString("widgetType.budgets", comment: "")
        }
        static var scheduledPayments: String {
            NSLocalizedString("widgetType.scheduledPayments", comment: "")
        }
    }

    // MARK: - Budgets

    enum Budgets {
        enum Widget {
            static var selectFavorites: String {
                NSLocalizedString("budgets.widget.selectFavorites", comment: "")
            }
        }
    }

    // MARK: - Planning

    enum Planning {
        static var title: String { NSLocalizedString("planning.title", comment: "") }
        static var budgets: String { NSLocalizedString("planning.budgets", comment: "") }
        static var goals: String { NSLocalizedString("planning.goals", comment: "") }
        static var comingSoon: String { NSLocalizedString("planning.comingSoon", comment: "") }
        static var scheduledPayments: String {
            NSLocalizedString("planning.scheduledPayments", comment: "")
        }
    }

    // MARK: - Profile
    // MARK: - Icon Picker

    enum IconPicker {
        static var title: String { NSLocalizedString("iconPicker.title", comment: "") }
        static var preview: String { NSLocalizedString("iconPicker.preview", comment: "") }
        static var shopping: String { NSLocalizedString("iconPicker.shopping", comment: "") }
        static var food: String { NSLocalizedString("iconPicker.food", comment: "") }
        static var transport: String {
            NSLocalizedString("iconPicker.transport", comment: "")
        }
        static var finance: String { NSLocalizedString("iconPicker.finance", comment: "") }
        static var home: String { NSLocalizedString("iconPicker.home", comment: "") }
        static var services: String { NSLocalizedString("iconPicker.services", comment: "") }
        static var entertainment: String {
            NSLocalizedString("iconPicker.entertainment", comment: "")
        }
        static var sports: String { NSLocalizedString("iconPicker.sports", comment: "") }
        static var health: String { NSLocalizedString("iconPicker.health", comment: "") }
        static var personalCare: String {
            NSLocalizedString("iconPicker.personalCare", comment: "")
        }
        static var education: String {
            NSLocalizedString("iconPicker.education", comment: "")
        }
        static var work: String { NSLocalizedString("iconPicker.work", comment: "") }
        static var pets: String { NSLocalizedString("iconPicker.pets", comment: "") }
        static var nature: String { NSLocalizedString("iconPicker.nature", comment: "") }
        static var tech: String { NSLocalizedString("iconPicker.tech", comment: "") }
        static var travel: String { NSLocalizedString("iconPicker.travel", comment: "") }
        static var communication: String {
            NSLocalizedString("iconPicker.communication", comment: "")
        }
        static var tools: String { NSLocalizedString("iconPicker.tools", comment: "") }
        static var security: String { NSLocalizedString("iconPicker.security", comment: "") }
        static var symbols: String { NSLocalizedString("iconPicker.symbols", comment: "") }
        static var direction: String {
            NSLocalizedString("iconPicker.direction", comment: "")
        }
        static var other: String { NSLocalizedString("iconPicker.other", comment: "") }
    }

    // MARK: - CashFlow View Type

    enum CashFlowViewType {
        static var total: String { NSLocalizedString("cashFlowViewType.total", comment: "") }
        static var byAccount: String {
            NSLocalizedString("cashFlowViewType.byAccount", comment: "")
        }
        static var byCurrency: String {
            NSLocalizedString("cashFlowViewType.byCurrency", comment: "")
        }
    }

    // MARK: - List View Type

    enum ListViewType {
        static var categories: String { NSLocalizedString("listViewType.categories", comment: "") }
        static var subcategories: String {
            NSLocalizedString("listViewType.subcategories", comment: "")
        }
    }

    // MARK: - Comparison Mode

    enum Comparison {
        static var month: String { NSLocalizedString("comparison.month", comment: "Month comparison") }
        static var year: String { NSLocalizedString("comparison.year", comment: "Year comparison") }
        static var monthShort: String { NSLocalizedString("comparison.monthShort", comment: "Short for previous period") }
        static var yearShort: String { NSLocalizedString("comparison.yearShort", comment: "Short for previous year") }
    }

    // MARK: - Validation

    enum Validation {
        static var enterAmountGreaterThanZero: String {
            NSLocalizedString("validation.enterAmountGreaterThanZero", comment: "")
        }
        static var selectSourceAccount: String {
            NSLocalizedString("validation.selectSourceAccount", comment: "")
        }
        static var selectDestinationAccount: String {
            NSLocalizedString("validation.selectDestinationAccount", comment: "")
        }
        static var accountsMustBeDifferent: String {
            NSLocalizedString("validation.accountsMustBeDifferent", comment: "")
        }
        static var selectAccount: String {
            NSLocalizedString("validation.selectAccount", comment: "")
        }
        static var selectSubcategory: String {
            NSLocalizedString("validation.selectSubcategory", comment: "")
        }
    }

    // MARK: - Transfer

    enum Transfer {
        static func transferTo(_ accountName: String) -> String {
            String(format: NSLocalizedString("transfer.transferTo", comment: ""), accountName)
        }
        static func transferFrom(_ accountName: String) -> String {
            String(format: NSLocalizedString("transfer.transferFrom", comment: ""), accountName)
        }
        static var categoryName: String {
            NSLocalizedString("transfer.categoryName", comment: "")
        }
    }

    enum More {
        static var sections: String {
            NSLocalizedString("more.sections", comment: "")
        }
    }

    // MARK: - Onboarding

    enum Onboarding {
        static var welcomeTitle: String {
            NSLocalizedString("onboarding.welcomeTitle", comment: "")
        }
        static var welcomeSubtitle: String {
            NSLocalizedString("onboarding.welcomeSubtitle", comment: "")
        }
        static var nameLabel: String {
            NSLocalizedString("onboarding.nameLabel", comment: "")
        }
        static var namePlaceholder: String {
            NSLocalizedString("onboarding.namePlaceholder", comment: "")
        }
        static var currencyTitle: String {
            NSLocalizedString("onboarding.currencyTitle", comment: "")
        }
        static var currencySubtitle: String {
            NSLocalizedString("onboarding.currencySubtitle", comment: "")
        }
        static var secondaryTitle: String {
            NSLocalizedString("onboarding.secondaryTitle", comment: "")
        }
        static var secondarySubtitle: String {
            NSLocalizedString("onboarding.secondarySubtitle", comment: "")
        }
        static func secondaryHint(_ count: Int, _ max: Int) -> String {
            String(format: NSLocalizedString("onboarding.secondaryHint", comment: ""), count, max)
        }
        static var periodTitle: String {
            NSLocalizedString("onboarding.periodTitle", comment: "")
        }
        static var periodSubtitle: String {
            NSLocalizedString("onboarding.periodSubtitle", comment: "")
        }
        static var finish: String {
            NSLocalizedString("onboarding.finish", comment: "")
        }
    }

    // MARK: - Bulk Edit

    enum BulkEdit {
        static var currencyWarning: String {
            NSLocalizedString("bulkEdit.currencyWarning", comment: "")
        }
        static func editCount(_ count: Int) -> String {
            String(format: NSLocalizedString("bulkEdit.editCount", comment: ""), count)
        }
        static var successMessage: String {
            NSLocalizedString("bulkEdit.successMessage", comment: "")
        }
        static var commonTags: String {
            NSLocalizedString("bulkEdit.commonTags", comment: "")
        }
        static var partialTags: String {
            NSLocalizedString("bulkEdit.partialTags", comment: "")
        }
        static var availableTags: String {
            NSLocalizedString("bulkEdit.availableTags", comment: "")
        }
    }

    // MARK: - Voice Language

    enum VoiceLanguage {
        static var system: String {
            NSLocalizedString("voiceLanguage.system", comment: "")
        }
        static var spanish: String {
            NSLocalizedString("voiceLanguage.spanish", comment: "")
        }
        static var english: String {
            NSLocalizedString("voiceLanguage.english", comment: "")
        }
    }

    // MARK: - Inbox

    enum Inbox {
        static var title: String {
            NSLocalizedString("inbox.title", comment: "")
        }
        static var pending: String {
            NSLocalizedString("inbox.pending", comment: "")
        }
        static var archived: String {
            NSLocalizedString("inbox.archived", comment: "")
        }
        static var noDescription: String {
            NSLocalizedString("inbox.noDescription", comment: "")
        }
        static var noAmount: String {
            NSLocalizedString("inbox.noAmount", comment: "")
        }
        static var missingLabel: String {
            NSLocalizedString("inbox.missingLabel", comment: "")
        }
        static var needsAccount: String {
            NSLocalizedString("inbox.needsAccount", comment: "")
        }
        static var needsSubcategory: String {
            NSLocalizedString("inbox.needsSubcategory", comment: "")
        }
        static var approve: String {
            NSLocalizedString("inbox.approve", comment: "")
        }
        static var delete: String {
            NSLocalizedString("inbox.delete", comment: "")
        }
        static var noPending: String {
            NSLocalizedString("inbox.noPending", comment: "")
        }
        static var noPendingDescription: String {
            NSLocalizedString("inbox.noPendingDescription", comment: "")
        }
        static var noArchived: String {
            NSLocalizedString("inbox.noArchived", comment: "")
        }
        static var noArchivedDescription: String {
            NSLocalizedString("inbox.noArchivedDescription", comment: "")
        }
        static func selectedCount(_ count: Int) -> String {
            String(format: NSLocalizedString("inbox.selectedCount", comment: ""), count)
        }
        static var editDraft: String {
            NSLocalizedString("inbox.editDraft", comment: "")
        }
        static var cannotApprove: String {
            NSLocalizedString("inbox.cannotApprove", comment: "")
        }
        static var sourceVoice: String {
            NSLocalizedString("inbox.sourceVoice", comment: "")
        }
        static var sourceEmail: String {
            NSLocalizedString("inbox.sourceEmail", comment: "")
        }
        static var sourceScreenshot: String {
            NSLocalizedString("inbox.sourceScreenshot", comment: "")
        }
        static var sourceScreenshotList: String {
            NSLocalizedString("inbox.sourceScreenshotList", comment: "")
        }
        static var sourceReceipt: String {
            NSLocalizedString("inbox.sourceReceipt", comment: "")
        }
        static var errorNoAccount: String {
            NSLocalizedString("inbox.errorNoAccount", comment: "")
        }
        static var errorNoAmount: String {
            NSLocalizedString("inbox.errorNoAmount", comment: "")
        }
        static var errorNoSubcategory: String {
            NSLocalizedString("inbox.errorNoSubcategory", comment: "")
        }
        static var duplicateWarningTitle: String {
            NSLocalizedString("inbox.duplicateWarningTitle", comment: "")
        }
        static var duplicateWarningMessage: String {
            NSLocalizedString("inbox.duplicateWarningMessage", comment: "")
        }
        static var createAnyway: String {
            NSLocalizedString("inbox.createAnyway", comment: "")
        }
        static func deleteConfirmMessage(_ count: Int) -> String {
            String(format: NSLocalizedString("inbox.deleteConfirmMessage", comment: ""), count)
        }
        static func approveableCount(_ count: Int, _ total: Int) -> String {
            String(format: NSLocalizedString("inbox.approveableCount", comment: ""), count, total)
        }
        static var saveLater: String {
            NSLocalizedString("inbox.saveLater", comment: "")
        }
        static var deleteTitle: String {
            NSLocalizedString("inbox.deleteTitle", comment: "")
        }
        static var deleteMessage: String {
            NSLocalizedString("inbox.deleteMessage", comment: "")
        }
        static var reject: String {
            NSLocalizedString("inbox.reject", comment: "")
        }
        static var returnToPending: String {
            NSLocalizedString("inbox.returnToPending", comment: "")
        }
        static var discardChangesTitle: String {
            NSLocalizedString("inbox.discardChangesTitle", comment: "")
        }
        static var discardChanges: String {
            NSLocalizedString("inbox.discardChanges", comment: "")
        }
        static var keepEditing: String {
            NSLocalizedString("inbox.keepEditing", comment: "")
        }
        static var discardChangesMessage: String {
            NSLocalizedString("inbox.discardChangesMessage", comment: "")
        }
        static var approveSuccess: String {
            NSLocalizedString("inbox.approveSuccess", comment: "")
        }
        static var approveNext: String {
            NSLocalizedString("inbox.approveNext", comment: "")
        }
        static var transactionCreated: String {
            NSLocalizedString("inbox.transactionCreated", comment: "")
        }
        static var transactionsCreated: String {
            NSLocalizedString("inbox.transactionsCreated", comment: "")
        }
        static var viewInRecords: String {
            NSLocalizedString("inbox.viewInRecords", comment: "")
        }
        static var backToInbox: String {
            NSLocalizedString("inbox.backToInbox", comment: "")
        }
    }

    // MARK: - Voice Input

    enum Voice {
        static var title: String {
            NSLocalizedString("voice.title", comment: "")
        }
        static var recording: String {
            NSLocalizedString("voice.recording", comment: "")
        }
        static var pleaseWait: String {
            NSLocalizedString("voice.pleaseWait", comment: "")
        }
        static var tapToRecord: String {
            NSLocalizedString("voice.tapToRecord", comment: "")
        }
        static var youCanSay: String {
            NSLocalizedString("voice.youCanSay", comment: "")
        }
        static var hintTypeExample: String {
            NSLocalizedString("voice.hintTypeExample", comment: "")
        }
        static var hintAmountExample: String {
            NSLocalizedString("voice.hintAmountExample", comment: "")
        }
        static var hintSubcategoryExample: String {
            NSLocalizedString("voice.hintSubcategoryExample", comment: "")
        }
        static var hintMerchantExample: String {
            NSLocalizedString("voice.hintMerchantExample", comment: "")
        }
        static var hintTagExample: String {
            NSLocalizedString("voice.hintTagExample", comment: "")
        }
        static var hintDateExample: String {
            NSLocalizedString("voice.hintDateExample", comment: "")
        }
        static var exampleLabel: String {
            NSLocalizedString("voice.exampleLabel", comment: "")
        }
        static var example1: String {
            NSLocalizedString("voice.example1", comment: "")
        }
        static var example2: String {
            NSLocalizedString("voice.example2", comment: "")
        }
        static var example3: String {
            NSLocalizedString("voice.example3", comment: "")
        }
        static var processingAudio: String {
            NSLocalizedString("voice.processingAudio", comment: "")
        }
        static var analyzing: String {
            NSLocalizedString("voice.analyzing", comment: "")
        }
        static var parsing: String {
            NSLocalizedString("voice.parsing", comment: "")
        }
        static var saving: String {
            NSLocalizedString("voice.saving", comment: "")
        }
        static var errorNoAmount: String {
            NSLocalizedString("voice.errorNoAmount", comment: "")
        }
    }

    // MARK: - Image Input

    enum Image {
        static var title: String {
            NSLocalizedString("image.title", comment: "")
        }
        static var selectTitle: String {
            NSLocalizedString("image.selectTitle", comment: "")
        }
        static var selectSubtitle: String {
            NSLocalizedString("image.selectSubtitle", comment: "")
        }
        static var selectButton: String {
            NSLocalizedString("image.selectButton", comment: "")
        }
        static var processing: String {
            NSLocalizedString("image.processing", comment: "")
        }
        static var processingSubtitle: String {
            NSLocalizedString("image.processingSubtitle", comment: "")
        }
        static var errorTitle: String {
            NSLocalizedString("image.errorTitle", comment: "")
        }
        static var errorLoad: String {
            NSLocalizedString("image.errorLoad", comment: "")
        }
        static var errorNoData: String {
            NSLocalizedString("image.errorNoData", comment: "")
        }
        static var errorUnrecognized: String {
            NSLocalizedString("image.errorUnrecognized", comment: "")
        }
        static var errorGeneric: String {
            NSLocalizedString("image.errorGeneric", comment: "")
        }
        static var transactionDetected: String {
            NSLocalizedString("image.transactionDetected", comment: "")
        }
        static var transactionsDetectedCount: String {
            NSLocalizedString("image.transactionsDetectedCount", comment: "")
        }
        static var reviewDraft: String {
            NSLocalizedString("image.reviewDraft", comment: "")
        }
        static var transactionsDetected: String {
            NSLocalizedString("image.transactionsDetected", comment: "")
        }
        static var goToInbox: String {
            NSLocalizedString("image.goToInbox", comment: "")
        }
        static func transactionsDetectedMessage(_ count: Int) -> String {
            String(format: NSLocalizedString("image.transactionsDetectedMessage", comment: ""), count)
        }
    }
}

// MARK: - App Locale

/// Centralized locale configuration for date formatters and charts.
/// This makes it easy to change the app's locale in one place.
enum AppLocale {
    /// Supported language codes (must match available .lproj localizations)
    private static let supportedLanguages = ["es", "en", "de", "fr", "it", "pt"]

    /// The app's current locale for date formatting.
    /// Uses the system locale if supported, otherwise defaults to English.
    static var current: Locale {
        let preferredLanguage = Locale.preferredLanguages.first ?? "en"
        let languageCode = String(preferredLanguage.prefix(2))

        if supportedLanguages.contains(languageCode) {
            return Locale(identifier: preferredLanguage)
        }
        return Locale(identifier: "en_US")  // Default fallback
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
