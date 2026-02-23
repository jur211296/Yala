//
//  L10n.swift
//  Yala
//
//  Localization helper for type-safe string access.
//

import Foundation

// MARK: - Language Manager

/// Manages in-app language override for users whose device language is not supported.
enum LanguageManager {
    private static let overrideKey = "appLanguageOverride"

    /// Supported languages with native names and flags
    static let supportedLanguages: [(code: String, nativeName: String, flag: String)] = [
        ("es", "Español", "🇪🇸"),
        ("en", "English", "🇺🇸"),
        ("de", "Deutsch", "🇩🇪"),
        ("fr", "Français", "🇫🇷"),
        ("it", "Italiano", "🇮🇹"),
        ("pt", "Português", "🇧🇷")
    ]

    /// Whether the device's preferred language is one of our supported languages
    static var deviceLanguageIsSupported: Bool {
        let deviceLang = String(Locale.preferredLanguages.first?.prefix(2) ?? "en")
        return supportedLanguages.contains { $0.code == deviceLang }
    }

    /// User's language override (nil = use system language)
    static var overrideLanguage: String? {
        get { UserDefaults.standard.string(forKey: overrideKey) }
        set { UserDefaults.standard.set(newValue, forKey: overrideKey) }
    }

    /// Bundle for loading localized strings (override or main)
    static var bundle: Bundle {
        guard let override = overrideLanguage,
              let path = Bundle.main.path(forResource: override, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return .main
        }
        return bundle
    }
}

/// Shorthand for localized string with language override support
private func ls(_ key: String, comment: String = "") -> String {
    NSLocalizedString(key, bundle: LanguageManager.bundle, comment: comment)
}

// MARK: - Localized Strings

/// Namespace for localized strings.
/// Usage: L10n.Panel.accounts or L10n.Trend.balance
enum L10n {

    // MARK: - Panel

    enum Panel {
        static var accounts: String {
            ls("panel.accounts", comment: "Accounts section title")
        }
        static var widgets: String {
            ls("panel.widgets", comment: "Widgets section title")
        }
        static var totalBalance: String {
            ls("panel.totalBalance", comment: "Total balance label")
        }
        static func greeting(_ name: String) -> String {
            String(format: ls("panel.greeting", comment: ""), name)
        }
        static func title(_ name: String) -> String {
            String(format: ls("panel.title", comment: ""), name)
        }
        static var fabVoice: String {
            ls("panel.fabVoice", comment: "")
        }
        static var fabImage: String {
            ls("panel.fabImage", comment: "")
        }
        static var fabManual: String {
            ls("panel.fabManual", comment: "")
        }
        static var spent: String {
            ls("panel.spent", comment: "Spent label for expenses-only mode account cards")
        }
    }

    // MARK: - Balance Status

    enum BalanceStatus {
        static var good: String { ls("balance.status.good", comment: "") }
        static var critical: String { ls("balance.status.critical", comment: "") }
        static var normal: String { ls("balance.status.normal", comment: "") }
    }

    // MARK: - Budget

    enum Budget {
        static var noInactive: String { ls("budget.noInactive", comment: "") }
    }

    // MARK: - Trend

    enum Trend {
        static var title: String {
            ls("trend.title", comment: "Trends section title")
        }
        static var balanceTitle: String {
            ls("trend.balance.title", comment: "Balance trend title")
        }
        static var incomeTitle: String {
            ls("trend.income.title", comment: "Income trend title")
        }
        static var expenseTitle: String {
            ls("trend.expense.title", comment: "Expense trend title")
        }
        static var filterBlockedMessage: String {
            ls(
                "trend.filterBlockedMessage",
                comment: "Message shown when user tries to select balance/income with category filters active"
            )
        }
        static var filterBlockedTitle: String {
            ls("trend.filterBlockedTitle", comment: "")
        }
    }

    // MARK: - Trend Types

    enum TrendType {
        static var balance: String {
            ls("trendType.balance", comment: "Balance type")
        }
        static var income: String { ls("trendType.income", comment: "Income type") }
        static var expense: String {
            ls("trendType.expense", comment: "Expense type")
        }
    }

    // MARK: - Cash Flow

    enum CashFlow {
        static var title: String { ls("cashFlow.title", comment: "Cash flow title") }
        static var income: String { ls("cashFlow.income", comment: "Income label") }
        static var expense: String {
            ls("cashFlow.expense", comment: "Expense label")
        }
        static var net: String { ls("cashFlow.net", comment: "Net label") }
        static var netFlow: String {
            ls("cashFlow.netFlow", comment: "Net flow label")
        }
    }

    // MARK: - Groupings

    enum Groupings {
        static var daily: String { ls("grouping.day", comment: "") }
        static var weekly: String { ls("grouping.week", comment: "") }
        static var monthly: String { ls("grouping.month", comment: "") }
    }

    // MARK: - Tab

    enum Tab {
        static var panel: String { ls("tab.panel", comment: "") }
        static var statistics: String { ls("tab.statistics", comment: "") }
        static var planning: String { ls("tab.planning", comment: "") }
        static var more: String { ls("tab.more", comment: "") }
        static var search: String { ls("tab.search", comment: "") }
        static var records: String { ls("tab.records", comment: "") }
    }

    // MARK: - Period

    enum Period {
        static var thisWeek: String { ls("period.thisWeek", comment: "") }
        static var lastWeek: String { ls("period.lastWeek", comment: "") }
        static var nextWeek: String { ls("period.nextWeek", comment: "") }
        static var last7Days: String { ls("period.last7Days", comment: "") }
        static var last30Days: String {
            ls("period.last30Days", comment: "Last 30 days")
        }
        static var thisMonth: String {
            ls("period.thisMonth", comment: "This month")
        }
        static var lastMonth: String {
            ls("period.lastMonth", comment: "Last month")
        }
        static var nextMonth: String {
            ls("period.nextMonth", comment: "Next month")
        }
        static var thisYear: String { ls("period.thisYear", comment: "This year") }
        static var lastYear: String { ls("period.lastYear", comment: "Last year") }
        static var nextYear: String { ls("period.nextYear", comment: "Next year") }
        static var allTime: String { ls("period.allTime", comment: "All time") }
        static var custom: String { ls("period.custom", comment: "Custom period") }
        static var startDate: String {
            ls("period.startDate", comment: "Start date")
        }
        static var endDate: String { ls("period.endDate", comment: "End date") }
        static var selectRange: String {
            ls("period.selectRange", comment: "Select range")
        }
        static var selectedRange: String {
            ls("period.selectedRange", comment: "Selected range")
        }
    }

    // MARK: - Statistics
    enum Statistics {
        static var title: String { ls("statistics.title", comment: "") }
        static var trends: String { ls("statistics.trends", comment: "") }
        static var categories: String { ls("statistics.categories", comment: "") }
        static var records: String { ls("statistics.records", comment: "") }
        static var noRecordsFiltered: String {
            ls("statistics.noRecordsFiltered", comment: "")
        }
        static var noRecordsDescription: String {
            ls("statistics.noRecordsDescription", comment: "")
        }
        static var periodComparison: String {
            ls("statistics.periodComparison", comment: "")
        }
        static var vsPreviousPeriod: String {
            ls("statistics.vsPreviousPeriod", comment: "")
        }
        static var vsPreviousYear: String {
            ls("statistics.vsPreviousYear", comment: "")
        }
        static var currentPeriod: String {
            ls("statistics.currentPeriod", comment: "")
        }
        static var previousPeriod: String {
            ls("statistics.previousPeriod", comment: "")
        }
        static var latestRecords: String {
            ls("statistics.latestRecords", comment: "")
        }
        static var noCategoryData: String {
            ls("statistics.noCategoryData", comment: "")
        }
        static var noSubcategoryData: String {
            ls("statistics.noSubcategoryData", comment: "")
        }
        static var noExpensesInPeriod: String {
            ls("statistics.noExpensesInPeriod", comment: "")
        }
        static var topCategories: String {
            ls("statistics.topCategories", comment: "")
        }
        static var topSubcategories: String {
            ls("statistics.topSubcategories", comment: "")
        }
        static var noDataToShow: String {
            ls("statistics.noDataToShow", comment: "")
        }
        static var noRecords: String {
            ls("statistics.noRecords", comment: "")
        }
        static var ofExpense: String {
            ls("statistics.ofExpense", comment: "")
        }
        static var spendingAnalysis: String {
            ls("statistics.spendingAnalysis", comment: "")
        }
        static var incomeAnalysis: String {
            ls("statistics.incomeAnalysis", comment: "")
        }
    }

    // MARK: - Nature
    enum Nature {
        static var title: String {
            ls("nature.expensesByNature", comment: "Expenses by nature")
        }
        static var label: String {
            ls("nature.title", comment: "Nature label")
        }
        static var essential: String { ls("nature.essential", comment: "") }
        static var essentialDesc: String {
            ls("nature.essential.desc", comment: "")
        }
        static var priority: String { ls("nature.priority", comment: "") }
        static var priorityDesc: String {
            ls("nature.priority.desc", comment: "")
        }
        static var optional: String { ls("nature.optional", comment: "") }
        static var optionalDesc: String {
            ls("nature.optional.desc", comment: "")
        }
        static var unclassified: String {
            ls("nature.unclassified", comment: "")
        }
        static var unclassifiedDesc: String {
            ls("nature.unclassified.desc", comment: "")
        }
        static var incomeNotApplicable: String {
            ls(
                "nature.incomeNotApplicable",
                comment: "Message shown when income filter is active - nature classification doesn't apply"
            )
        }
    }

    // MARK: - Records

    enum Records {
        static var title: String { ls("records.title", comment: "") }
        static var latest: String { ls("records.latest", comment: "") }
        static var noRecords: String { ls("records.noRecords", comment: "") }
        static func deleteConfirmTitle(_ count: Int) -> String {
            String(format: ls("records.deleteConfirmTitle", comment: ""), count)
        }
    }

    // MARK: - Filters

    enum Filters {
        static var title: String { ls("filters.title", comment: "") }
        static var all: String { ls("filters.all", comment: "") }
        static var allAccounts: String { ls("filters.allAccounts", comment: "") }
        static var allCategories: String { ls("filters.allCategories", comment: "") }
        static var clearFilters: String { ls("filters.clearFilters", comment: "") }
        static var selectCategories: String {
            ls("filters.selectCategories", comment: "")
        }
        static var selectAll: String {
            ls("filters.selectAll", comment: "")
        }
        static var deselectAll: String {
            ls("filters.deselectAll", comment: "")
        }
        static var noSubcategories: String {
            ls("filters.noSubcategories", comment: "")
        }
        static var noneSelected: String {
            ls("filters.noneSelected", comment: "")
        }
        static var allSubcategories: String {
            ls("filters.allSubcategories", comment: "")
        }
        static var filterOptions: String {
            ls("filters.filterOptions", comment: "")
        }
        static var noteContains: String {
            ls("filters.noteContains", comment: "")
        }
        static var selectAccounts: String {
            ls("filters.selectAccounts", comment: "")
        }
        static var selectTags: String {
            ls("filters.selectTags", comment: "")
        }
        static var selectCurrencies: String {
            ls("filters.selectCurrencies", comment: "")
        }
        static var allTags: String {
            ls("filters.allTags", comment: "")
        }
        static var noTags: String {
            ls("filters.noTags", comment: "")
        }
        static var allCurrencies: String {
            ls("filters.allCurrencies", comment: "")
        }
        static var allNatures: String {
            ls("filters.allNatures", comment: "")
        }
        static func selectedCount(_ count: Int) -> String {
            String(format: ls("filters.selectedCount", comment: ""), count)
        }
        static func subcategoriesSelectedCount(_ count: Int) -> String {
            String(format: ls("filters.subcategoriesSelectedCount", comment: ""), count)
        }
        static var categories: String { ls("filters.categories", comment: "") }
        static var type: String { ls("filters.type", comment: "") }
        static var nature: String { ls("filters.nature", comment: "") }
        static var currency: String { ls("filters.currency", comment: "") }
    }

    // MARK: - Actions

    enum Action {
        static var apply: String { ls("action.apply", comment: "") }
        static var cancel: String { ls("action.cancel", comment: "") }
        static var done: String { ls("action.done", comment: "") }
        static var save: String { ls("action.save", comment: "") }
        static var delete: String { ls("action.delete", comment: "") }
        static var edit: String { ls("action.edit", comment: "") }
        static var add: String { ls("action.add", comment: "") }
        static var viewAll: String { ls("action.viewAll", comment: "") }
        static var viewLess: String { ls("action.viewLess", comment: "") }
        static var multipleEdit: String { ls("action.multipleEdit", comment: "") }
        static var back: String { ls("action.back", comment: "") }
        static var next: String { ls("action.next", comment: "") }
        static var duplicate: String { ls("action.duplicate", comment: "") }
        static var favorite: String { ls("action.favorite", comment: "") }
        static var recurring: String { ls("action.recurring", comment: "") }
        static var saveAsFavorite: String { ls("action.saveAsFavorite", comment: "") }
        static var saveAsRecurring: String { ls("action.saveAsRecurring", comment: "") }
        static var savedAsFavorite: String { ls("action.savedAsFavorite", comment: "") }
        static var savedAsRecurring: String { ls("action.savedAsRecurring", comment: "") }
        static var duplicated: String { ls("action.duplicated", comment: "") }
        static var select: String { ls("action.select", comment: "") }
        static var retry: String { ls("action.retry", comment: "") }
        static var later: String { ls("action.later", comment: "") }
        static var close: String { ls("action.close", comment: "") }
        static var reorder: String { ls("action.reorder", comment: "") }
    }

    // MARK: - Accessibility

    enum Accessibility {
        static var closeMenu: String { ls("accessibility.closeMenu", comment: "") }
        static var newRecord: String { ls("accessibility.newRecord", comment: "") }
        static var clearFilters: String { ls("accessibility.clearFilters", comment: "") }
        static var cancelRecording: String { ls("accessibility.cancelRecording", comment: "") }
        static var stopRecording: String { ls("accessibility.stopRecording", comment: "") }
        static var startRecording: String { ls("accessibility.startRecording", comment: "") }
        static var cancelPreview: String { ls("accessibility.cancelPreview", comment: "") }
        static var cancelProcessing: String { ls("accessibility.cancelProcessing", comment: "") }
        static var cashFlowChart: String { ls("accessibility.cashFlowChart", comment: "") }
        static var categoryPieChart: String { ls("accessibility.categoryPieChart", comment: "") }
        static var subcategoryPieChart: String { ls("accessibility.subcategoryPieChart", comment: "") }
        static var tagPieChart: String { ls("accessibility.tagPieChart", comment: "") }
        static var widgetFixed: String { ls("accessibility.widgetFixed", comment: "") }
        static var favoriteTemplates: String { ls("accessibility.favoriteTemplates", comment: "") }
        static var exceeded: String { ls("accessibility.exceeded", comment: "") }
        static var inbox: String { ls("accessibility.inbox", comment: "") }
        static var widgetPreferences: String { ls("accessibility.widgetPreferences", comment: "") }
        static var createAccountFirst: String { ls("accessibility.createAccountFirst", comment: "") }
        static var removeFilter: String { ls("accessibility.removeFilter", comment: "") }
    }

    // MARK: - Search

    enum Search {
        static var noResults: String { ls("search.noResults", comment: "") }
        static var tryAnotherTerm: String { ls("search.tryAnotherTerm", comment: "") }
        static func resultsCount(_ count: Int) -> String { String(format: ls("search.resultsCount", comment: ""), count) }

        enum Filter {
            static var all: String { ls("search.filter.all", comment: "") }
            static var note: String { ls("search.filter.note", comment: "") }
            static var category: String { ls("search.filter.category", comment: "") }
            static var subcategory: String { ls("search.filter.subcategory", comment: "") }
            static var account: String { ls("search.filter.account", comment: "") }
            static var nature: String { ls("search.filter.nature", comment: "") }
            static var tag: String { ls("search.filter.tag", comment: "") }
        }
    }

    // MARK: - Date Helpers

    enum Date {
        static var today: String { ls("date.today", comment: "") }
        static var yesterday: String { ls("date.yesterday", comment: "") }

        static func weekOf(_ date: String) -> String {
            String(format: ls("date.weekOf %@", comment: ""), date)
        }
    }

    // MARK: - Exchange Rate

    enum ExchangeRate {
        static var title: String { ls("exchangeRate.title", comment: "") }
        static var updated: String { ls("exchangeRate.updated", comment: "") }
        static var loadError: String { ls("exchangeRate.loadError", comment: "") }
        static var noSecondaryCurrenciesHint: String {
            ls("exchangeRate.noSecondaryCurrenciesHint", comment: "")
        }
        static var noSecondaryCurrenciesPath: String {
            ls("exchangeRate.noSecondaryCurrenciesPath", comment: "")
        }
    }

    // MARK: - Currency Names

    enum Currency {
        // Latinoamérica
        static var pen: String { ls("currency.pen", comment: "") }
        static var usd: String { ls("currency.usd", comment: "") }
        static var mxn: String { ls("currency.mxn", comment: "") }
        static var cop: String { ls("currency.cop", comment: "") }
        static var brl: String { ls("currency.brl", comment: "") }
        static var ars: String { ls("currency.ars", comment: "") }
        static var clp: String { ls("currency.clp", comment: "") }
        static var uyu: String { ls("currency.uyu", comment: "") }
        static var bob: String { ls("currency.bob", comment: "") }
        static var pyg: String { ls("currency.pyg", comment: "") }
        static var crc: String { ls("currency.crc", comment: "") }
        static var gtq: String { ls("currency.gtq", comment: "") }
        static var hnl: String { ls("currency.hnl", comment: "") }
        static var nio: String { ls("currency.nio", comment: "") }
        static var pab: String { ls("currency.pab", comment: "") }
        static var dop: String { ls("currency.dop", comment: "") }
        // Europa
        static var eur: String { ls("currency.eur", comment: "") }
        static var gbp: String { ls("currency.gbp", comment: "") }
        static var chf: String { ls("currency.chf", comment: "") }
        static var sek: String { ls("currency.sek", comment: "") }
        static var nok: String { ls("currency.nok", comment: "") }
        static var dkk: String { ls("currency.dkk", comment: "") }
        static var pln: String { ls("currency.pln", comment: "") }
        static var czk: String { ls("currency.czk", comment: "") }
        static var huf: String { ls("currency.huf", comment: "") }
        static var ron: String { ls("currency.ron", comment: "") }
        static var rub: String { ls("currency.rub", comment: "") }
        static var uah: String { ls("currency.uah", comment: "") }
        static var `try`: String { ls("currency.try", comment: "") }
        // Asia
        static var jpy: String { ls("currency.jpy", comment: "") }
        static var cny: String { ls("currency.cny", comment: "") }
        static var krw: String { ls("currency.krw", comment: "") }
        static var inr: String { ls("currency.inr", comment: "") }
        static var idr: String { ls("currency.idr", comment: "") }
        static var php: String { ls("currency.php", comment: "") }
        static var thb: String { ls("currency.thb", comment: "") }
        static var myr: String { ls("currency.myr", comment: "") }
        static var sgd: String { ls("currency.sgd", comment: "") }
        static var hkd: String { ls("currency.hkd", comment: "") }
        static var twd: String { ls("currency.twd", comment: "") }
        static var vnd: String { ls("currency.vnd", comment: "") }
        // Oceanía
        static var aud: String { ls("currency.aud", comment: "") }
        static var nzd: String { ls("currency.nzd", comment: "") }
        // Medio Oriente
        static var aed: String { ls("currency.aed", comment: "") }
        static var sar: String { ls("currency.sar", comment: "") }
        static var ils: String { ls("currency.ils", comment: "") }
        static var qar: String { ls("currency.qar", comment: "") }
        static var kwd: String { ls("currency.kwd", comment: "") }
        // África
        static var zar: String { ls("currency.zar", comment: "") }
        static var egp: String { ls("currency.egp", comment: "") }
        static var ngn: String { ls("currency.ngn", comment: "") }
        static var kes: String { ls("currency.kes", comment: "") }
        static var mad: String { ls("currency.mad", comment: "") }
        // Norteamérica
        static var cad: String { ls("currency.cad", comment: "") }

        /// Nombres cortos en plural (sin país) para ejemplos de voz
        enum Plural {
            // Latinoamérica
            static var pen: String { ls("currency.plural.pen", comment: "") }
            static var usd: String { ls("currency.plural.usd", comment: "") }
            static var mxn: String { ls("currency.plural.mxn", comment: "") }
            static var cop: String { ls("currency.plural.cop", comment: "") }
            static var brl: String { ls("currency.plural.brl", comment: "") }
            static var ars: String { ls("currency.plural.ars", comment: "") }
            static var clp: String { ls("currency.plural.clp", comment: "") }
            static var uyu: String { ls("currency.plural.uyu", comment: "") }
            static var bob: String { ls("currency.plural.bob", comment: "") }
            static var pyg: String { ls("currency.plural.pyg", comment: "") }
            static var crc: String { ls("currency.plural.crc", comment: "") }
            static var gtq: String { ls("currency.plural.gtq", comment: "") }
            static var hnl: String { ls("currency.plural.hnl", comment: "") }
            static var nio: String { ls("currency.plural.nio", comment: "") }
            static var pab: String { ls("currency.plural.pab", comment: "") }
            static var dop: String { ls("currency.plural.dop", comment: "") }
            // Europa
            static var eur: String { ls("currency.plural.eur", comment: "") }
            static var gbp: String { ls("currency.plural.gbp", comment: "") }
            static var chf: String { ls("currency.plural.chf", comment: "") }
            static var sek: String { ls("currency.plural.sek", comment: "") }
            static var nok: String { ls("currency.plural.nok", comment: "") }
            static var dkk: String { ls("currency.plural.dkk", comment: "") }
            static var pln: String { ls("currency.plural.pln", comment: "") }
            static var czk: String { ls("currency.plural.czk", comment: "") }
            static var huf: String { ls("currency.plural.huf", comment: "") }
            static var ron: String { ls("currency.plural.ron", comment: "") }
            static var rub: String { ls("currency.plural.rub", comment: "") }
            static var uah: String { ls("currency.plural.uah", comment: "") }
            static var `try`: String { ls("currency.plural.try", comment: "") }
            // Asia
            static var jpy: String { ls("currency.plural.jpy", comment: "") }
            static var cny: String { ls("currency.plural.cny", comment: "") }
            static var krw: String { ls("currency.plural.krw", comment: "") }
            static var inr: String { ls("currency.plural.inr", comment: "") }
            static var idr: String { ls("currency.plural.idr", comment: "") }
            static var php: String { ls("currency.plural.php", comment: "") }
            static var thb: String { ls("currency.plural.thb", comment: "") }
            static var myr: String { ls("currency.plural.myr", comment: "") }
            static var sgd: String { ls("currency.plural.sgd", comment: "") }
            static var hkd: String { ls("currency.plural.hkd", comment: "") }
            static var twd: String { ls("currency.plural.twd", comment: "") }
            static var vnd: String { ls("currency.plural.vnd", comment: "") }
            // Oceanía
            static var aud: String { ls("currency.plural.aud", comment: "") }
            static var nzd: String { ls("currency.plural.nzd", comment: "") }
            // Medio Oriente
            static var aed: String { ls("currency.plural.aed", comment: "") }
            static var sar: String { ls("currency.plural.sar", comment: "") }
            static var ils: String { ls("currency.plural.ils", comment: "") }
            static var qar: String { ls("currency.plural.qar", comment: "") }
            static var kwd: String { ls("currency.plural.kwd", comment: "") }
            // África
            static var zar: String { ls("currency.plural.zar", comment: "") }
            static var egp: String { ls("currency.plural.egp", comment: "") }
            static var ngn: String { ls("currency.plural.ngn", comment: "") }
            static var kes: String { ls("currency.plural.kes", comment: "") }
            static var mad: String { ls("currency.plural.mad", comment: "") }
            // Norteamérica
            static var cad: String { ls("currency.plural.cad", comment: "") }
        }
    }

    // MARK: - Continents

    enum Continent {
        static var latinAmerica: String { ls("continent.latinAmerica", comment: "") }
        static var europe: String { ls("continent.europe", comment: "") }
        static var asia: String { ls("continent.asia", comment: "") }
        static var oceania: String { ls("continent.oceania", comment: "") }
        static var middleEast: String { ls("continent.middleEast", comment: "") }
        static var africa: String { ls("continent.africa", comment: "") }
        static var northAmerica: String { ls("continent.northAmerica", comment: "") }
    }

    // MARK: - Empty States

    enum Empty {
        static var noData: String { ls("empty.noData", comment: "") }
        static var noTransactions: String { ls("empty.noTransactions", comment: "") }
        static var noFavorites: String { ls("empty.noFavorites", comment: "") }
        static var noTags: String { ls("empty.noTags", comment: "") }
        static var noAccounts: String { ls("empty.noAccounts", comment: "") }
        static var noCategories: String { ls("empty.noCategories", comment: "") }
        static var categoriesDescription: String {
            ls("empty.categoriesDescription", comment: "")
        }
        static var noSubcategories: String {
            ls("empty.noSubcategories", comment: "")
        }
        static var noExpenses: String { ls("empty.noExpenses", comment: "") }
        static var tagsDescription: String {
            ls("empty.tagsDescription", comment: "")
        }
        static var accountsDescription: String {
            ls("empty.accountsDescription", comment: "")
        }
    }

    // MARK: - Transaction

    enum Transaction {
        static var new: String { ls("transaction.new", comment: "") }
        static var edit: String { ls("transaction.edit", comment: "") }
        static var newTransaction: String {
            ls("transaction.newTransaction", comment: "")
        }
        static var editTransaction: String {
            ls("transaction.editTransaction", comment: "")
        }
        static var type: String { ls("transaction.type", comment: "") }
        static var amount: String { ls("transaction.amount", comment: "") }
        static var description: String { ls("transaction.description", comment: "") }
        static var descriptionHint: String {
            ls("transaction.descriptionHint", comment: "")
        }
        static var note: String { ls("transaction.note", comment: "") }
        static var notePlaceholder: String {
            ls("transaction.notePlaceholder", comment: "")
        }
        static var date: String { ls("transaction.date", comment: "") }
        static var tags: String { ls("transaction.tags", comment: "") }
        static var addTags: String { ls("transaction.addTags", comment: "") }
        static var category: String { ls("transaction.category", comment: "") }
        static var subcategory: String { ls("transaction.subcategory", comment: "") }
        static var select: String { ls("transaction.select", comment: "") }
        static var total: String { ls("transaction.total", comment: "") }
        static var income: String { ls("transaction.income", comment: "") }
        static var expense: String { ls("transaction.expense", comment: "") }
        static var transfer: String { ls("transaction.transfer", comment: "") }
        static var origin: String { ls("transaction.origin", comment: "") }
        static var destination: String { ls("transaction.destination", comment: "") }
        static var sourceAccount: String {
            ls("transaction.sourceAccount", comment: "")
        }
        static var destinationAccount: String {
            ls("transaction.destinationAccount", comment: "")
        }
        static var account: String { ls("transaction.account", comment: "") }
        static var exchangeRate: String {
            ls("transaction.exchangeRate", comment: "")
        }
        static var willReceive: String { ls("transaction.willReceive", comment: "") }
        static var createAnother: String {
            ls("transaction.createAnother", comment: "")
        }
        static var recents: String { ls("transaction.recents", comment: "") }
        static var successTitle: String {
            ls("transaction.successTitle", comment: "")
        }

        enum TransactionType {
            static var expense: String {
                ls("transaction.type.expense", comment: "")
            }
            static var income: String {
                ls("transaction.type.income", comment: "")
            }
            static var transfer: String {
                ls("transaction.type.transfer", comment: "")
            }
        }
    }

    // MARK: - Account

    enum Account {
        static var new: String { ls("account.new", comment: "") }
        static var edit: String { ls("account.edit", comment: "") }
        static var configure: String { ls("account.configure", comment: "") }
        static var name: String { ls("account.name", comment: "") }
        static var accountName: String { ls("account.accountName", comment: "") }
        static var accountNumber: String { ls("account.accountNumber", comment: "") }
        static var type: String { ls("account.type", comment: "") }
        static var currency: String { ls("account.currency", comment: "") }
        static var balance: String { ls("account.balance", comment: "") }
        static var initialBalance: String {
            ls("account.initialBalance", comment: "")
        }
        static var sign: String { ls("account.sign", comment: "") }
        static var positive: String { ls("account.positive", comment: "") }
        static var negative: String { ls("account.negative", comment: "") }
        static var adjustment: String { ls("account.adjustment", comment: "") }
        static var selected: String { ls("account.selected", comment: "") }
        static var selectAccount: String { ls("account.selectAccount", comment: "") }
        static var archived: String { ls("account.archived", comment: "") }
        static var archive: String { ls("account.archive", comment: "") }
        static var unarchive: String { ls("account.unarchive", comment: "") }
        static var excludeFromStats: String {
            ls("account.excludeFromStats", comment: "")
        }
        static var delete: String { ls("account.delete", comment: "") }
        static var deleteError: String { ls("account.deleteError", comment: "") }
        static var deleteBalanceError: String {
            ls("account.deleteBalanceError", comment: "")
        }
        static var addAccount: String { ls("account.addAccount", comment: "") }

        enum AccountType {
            static var general: String { ls("account.type.general", comment: "") }
            static var cash: String { ls("account.type.cash", comment: "") }
            static var current: String { ls("account.type.current", comment: "") }
            static var savings: String { ls("account.type.savings", comment: "") }
            static var creditCard: String {
                ls("account.type.creditCard", comment: "")
            }
            static var investment: String {
                ls("account.type.investment", comment: "")
            }
            static var loan: String { ls("account.type.loan", comment: "") }
            static var other: String { ls("account.type.other", comment: "") }
        }

        // Balance Adjustments
        static var newBalance: String { ls("account.newBalance", comment: "") }
        static var currentBalance: String {
            ls("account.currentBalance", comment: "")
        }
        static func adjustmentPreview(_ amount: String) -> String {
            String(format: ls("account.adjustmentPreview", comment: ""), amount)
        }
        static var initialBalanceNote: String {
            ls("account.initialBalanceNote", comment: "")
        }
        static var adjustmentNote: String {
            ls("account.adjustmentNote", comment: "")
        }
        static func existingInitialBalance(_ amount: String) -> String {
            String(format: ls("account.existingInitialBalance", comment: ""), amount)
        }
        static var modifyInitialBalance: String {
            ls("account.modifyInitialBalance", comment: "")
        }
        static var adjustmentDate: String {
            ls("account.adjustmentDate", comment: "")
        }
        static var finalBalance: String {
            ls("account.finalBalance", comment: "")
        }
        static var adjustByEntry: String {
            ls("account.adjustByEntry", comment: "")
        }
        static var adjustByEntryDesc: String {
            ls("account.adjustByEntryDesc", comment: "")
        }
        static var changeInitialBalanceName: String {
            ls("account.changeInitialBalanceName", comment: "")
        }
        static var changeInitialBalanceDesc: String {
            ls("account.changeInitialBalanceDesc", comment: "")
        }

    }

    // MARK: - Category

    enum Category {
        static var new: String { ls("category.new", comment: "") }
        static var edit: String { ls("category.edit", comment: "") }
        static var editTitle: String { ls("category.editTitle", comment: "") }
        static var name: String { ls("category.name", comment: "") }
        static var nature: String { ls("category.nature", comment: "") }
        static var show: String { ls("category.show", comment: "") }
        static var hiddenTitle: String { ls("category.hiddenTitle", comment: "") }
        static var hiddenDescription: String {
            ls("category.hiddenDescription", comment: "")
        }
        static var addSubcategory: String {
            ls("category.addSubcategory", comment: "")
        }
        static var subcategories: String {
            ls("category.subcategories", comment: "")
        }
        static var noSubcategoriesYet: String {
            ls("category.noSubcategoriesYet", comment: "")
        }
        static var requiresSubcategory: String {
            ls("category.requiresSubcategory", comment: "")
        }
        static var addOneSubcategory: String {
            ls("category.addOneSubcategory", comment: "")
        }
        static var delete: String { ls("category.delete", comment: "") }
        static var deleteConfirmTitle: String {
            ls("category.deleteConfirmTitle", comment: "")
        }
        static var deleteConfirmMessage: String {
            ls("category.deleteConfirmMessage", comment: "")
        }
        static var cannotDeleteTitle: String {
            ls("category.cannotDeleteTitle", comment: "")
        }
        static func cannotDeleteMessage(_ count: Int) -> String {
            String(
                format: ls("category.cannotDeleteMessage", comment: ""),
                count
            )
        }
        static var newCategory: String {
            ls("category.newCategory", comment: "")
        }
        static var namePlaceholder: String {
            ls("category.namePlaceholder", comment: "")
        }
        static var activeSubcategories: String {
            ls("category.activeSubcategories", comment: "")
        }
        static var hiddenSubcategories: String {
            ls("category.hiddenSubcategories", comment: "")
        }
        static var details: String {
            ls("category.details", comment: "")
        }
        static var others: String {
            ls("category.others", comment: "")
        }
        // Seed names
        static var food: String { ls("category.food", comment: "") }
        static var shopping: String { ls("category.shopping", comment: "") }
        static var transport: String { ls("category.transport", comment: "") }
        static var finance: String { ls("category.finance", comment: "") }
        static var housing: String { ls("category.housing", comment: "") }
        static var entertainment: String { ls("category.entertainment", comment: "") }
        static var personal: String { ls("category.personal", comment: "") }
        static var pets: String { ls("category.pets", comment: "") }
        static var vehicle: String { ls("category.vehicle", comment: "") }
        static var incomeCategory: String { ls("category.income", comment: "") }
        static var other: String { ls("category.other", comment: "") }
    }

    // MARK: - Subcategory

    enum Subcategory {
        static var newTitle: String { ls("subcategory.newTitle", comment: "") }
        static var editTitle: String { ls("subcategory.editTitle", comment: "") }
        static var delete: String { ls("subcategory.delete", comment: "") }
        static var deleteConfirmTitle: String {
            ls("subcategory.deleteConfirmTitle", comment: "")
        }
        static var deleteConfirmMessage: String {
            ls("subcategory.deleteConfirmMessage", comment: "")
        }
        static var cannotDeleteTitle: String {
            ls("subcategory.cannotDeleteTitle", comment: "")
        }
        static func cannotDeleteMessage(_ count: Int) -> String {
            String(
                format: ls("subcategory.cannotDeleteMessage", comment: ""),
                count
            )
        }

        // Transfer sheet
        static var transferTitle: String {
            ls("subcategory.transferTitle", comment: "")
        }
        static var transferHeader: String {
            ls("subcategory.transferHeader", comment: "")
        }
        static func transferDescription(_ count: Int, _ name: String) -> String {
            String(
                format: ls("subcategory.transferDescription", comment: ""),
                count,
                name
            )
        }
        static var transferToSpecific: String {
            ls("subcategory.transferToSpecific", comment: "")
        }
        static var transferToSpecificDesc: String {
            ls("subcategory.transferToSpecificDesc", comment: "")
        }
        static var transferToUnassigned: String {
            ls("subcategory.transferToUnassigned", comment: "")
        }
        static var transferToUnassignedDesc: String {
            ls("subcategory.transferToUnassignedDesc", comment: "")
        }
        static var deleteTransactions: String {
            ls("subcategory.deleteTransactions", comment: "")
        }
        static var deleteTransactionsDesc: String {
            ls("subcategory.deleteTransactionsDesc", comment: "")
        }
        static var selectDestination: String {
            ls("subcategory.selectDestination", comment: "")
        }
        static var deleteTransactionsConfirmTitle: String {
            ls("subcategory.deleteTransactionsConfirmTitle", comment: "")
        }
        static var deleteTransactionsConfirm: String {
            ls("subcategory.deleteTransactionsConfirm", comment: "")
        }
        static func deleteTransactionsConfirmMessage(_ count: Int) -> String {
            String(
                format: ls("subcategory.deleteTransactionsConfirmMessage", comment: ""),
                count
            )
        }
        static var details: String {
            ls("subcategory.details", comment: "")
        }
        static var namePlaceholder: String {
            ls("subcategory.namePlaceholder", comment: "")
        }
        static var unassigned: String {
            ls("subcategory.unassigned", comment: "")
        }
        static var noSubcategory: String {
            ls("subcategories.noSubcategory", comment: "")
        }
        // Seed names - Alimentación
        static var delivery: String { ls("subcategory.delivery", comment: "") }
        static var restaurants: String { ls("subcategory.restaurants", comment: "") }
        static var supplements: String { ls("subcategory.supplements", comment: "") }
        static var supermarkets: String { ls("subcategory.supermarkets", comment: "") }
        // Seed names - Compras
        static var personalCare: String { ls("subcategory.personalCare", comment: "") }
        static var pharmacy: String { ls("subcategory.pharmacy", comment: "") }
        static var homeDecor: String { ls("subcategory.homeDecor", comment: "") }
        static var otherShopping: String { ls("subcategory.otherShopping", comment: "") }
        static var gifts: String { ls("subcategory.gifts", comment: "") }
        static var clothing: String { ls("subcategory.clothing", comment: "") }
        static var tech: String { ls("subcategory.tech", comment: "") }
        // Seed names - Transporte
        static var occasionalMobility: String { ls("subcategory.occasionalMobility", comment: "") }
        static var rideshare: String { ls("subcategory.rideshare", comment: "") }
        static var publicTransport: String { ls("subcategory.publicTransport", comment: "") }
        // Seed names - Finanzas
        static var fees: String { ls("subcategory.fees", comment: "") }
        static var taxes: String { ls("subcategory.taxes", comment: "") }
        static var pensions: String { ls("subcategory.pensions", comment: "") }
        static var loans: String { ls("subcategory.loans", comment: "") }
        static var insurance: String { ls("subcategory.insurance", comment: "") }
        // Seed names - Hogar
        static var rent: String { ls("subcategory.rent", comment: "") }
        static var maintenance: String { ls("subcategory.maintenance", comment: "") }
        static var otherHousing: String { ls("subcategory.otherHousing", comment: "") }
        static var supportStaff: String { ls("subcategory.supportStaff", comment: "") }
        static var homeInsurance: String { ls("subcategory.homeInsurance", comment: "") }
        static var utilities: String { ls("subcategory.utilities", comment: "") }
        // Seed names - Entretenimiento
        static var bars: String { ls("subcategory.bars", comment: "") }
        static var sports: String { ls("subcategory.sports", comment: "") }
        static var shows: String { ls("subcategory.shows", comment: "") }
        static var nightlife: String { ls("subcategory.nightlife", comment: "") }
        static var hobbies: String { ls("subcategory.hobbies", comment: "") }
        static var coupleDates: String { ls("subcategory.coupleDates", comment: "") }
        static var streaming: String { ls("subcategory.streaming", comment: "") }
        static var travel: String { ls("subcategory.travel", comment: "") }
        // Seed names - Personal
        static var consulting: String { ls("subcategory.consulting", comment: "") }
        static var beauty: String { ls("subcategory.beauty", comment: "") }
        static var education: String { ls("subcategory.education", comment: "") }
        static var fitness: String { ls("subcategory.fitness", comment: "") }
        static var health: String { ls("subcategory.health", comment: "") }
        static var leisureSubs: String { ls("subcategory.leisureSubs", comment: "") }
        static var utilitySubs: String { ls("subcategory.utilitySubs", comment: "") }
        static var phone: String { ls("subcategory.phone", comment: "") }
        // Seed names - Mascotas
        static var petAccessories: String { ls("subcategory.petAccessories", comment: "") }
        static var petFood: String { ls("subcategory.petFood", comment: "") }
        static var vet: String { ls("subcategory.vet", comment: "") }
        static var petServices: String { ls("subcategory.petServices", comment: "") }
        // Seed names - Vehículo
        static var fuel: String { ls("subcategory.fuel", comment: "") }
        static var parking: String { ls("subcategory.parking", comment: "") }
        static var leasing: String { ls("subcategory.leasing", comment: "") }
        static var vehicleMaintenance: String { ls("subcategory.vehicleMaintenance", comment: "") }
        static var vehicleLoan: String { ls("subcategory.vehicleLoan", comment: "") }
        static var vehicleInsurance: String { ls("subcategory.vehicleInsurance", comment: "") }
        // Seed names - Ingresos
        static var rentalIncome: String { ls("subcategory.rentalIncome", comment: "") }
        static var subsidies: String { ls("subcategory.subsidies", comment: "") }
        static var freelance: String { ls("subcategory.freelance", comment: "") }
        static var dividends: String { ls("subcategory.dividends", comment: "") }
        static var refunds: String { ls("subcategory.refunds", comment: "") }
        static var giftIncome: String { ls("subcategory.giftIncome", comment: "") }
        static var salary: String { ls("subcategory.salary", comment: "") }
        static var sales: String { ls("subcategory.sales", comment: "") }
        static var accountTransfer: String { ls("subcategory.accountTransfer", comment: "") }
        // Seed names - Otros
        static var balanceAdjustment: String { ls("subcategory.balanceAdjustment", comment: "") }
        static var accountTransferOther: String { ls("subcategory.accountTransferOther", comment: "") }
    }

    // MARK: - Tag

    enum Tag {
        static var new: String { ls("tag.new", comment: "") }
        static var edit: String { ls("tag.edit", comment: "") }
        static var newTag: String { ls("tag.newTag", comment: "") }
        static var editTag: String { ls("tag.editTag", comment: "") }
        static var createFirstDescription: String {
            ls("tag.createFirstDescription", comment: "")
        }
        static var delete: String { ls("tag.delete", comment: "") }
        static var deleteConfirmation: String {
            ls("tag.deleteConfirmation", comment: "")
        }
        static var namePlaceholder: String {
            ls("tag.namePlaceholder", comment: "")
        }
        static var color: String {
            ls("tag.color", comment: "")
        }
        static func colorSelected(_ hex: String) -> String {
            String(format: ls("tag.colorSelected", comment: ""), hex)
        }
    }

    // MARK: - Alert

    enum Alert {
        static var unsavedChanges: String { ls("alert.unsavedChanges", comment: "") }
        static var discardChanges: String { ls("alert.discardChanges", comment: "") }
        static var keepEditing: String { ls("alert.keepEditing", comment: "") }
        static var confirmDelete: String { ls("alert.confirmDelete", comment: "") }
        static var deleteWarning: String { ls("alert.deleteWarning", comment: "") }
    }

    // MARK: - Import

    enum Import {
        static var title: String { ls("import.title", comment: "") }
        static var selectFile: String { ls("import.selectFile", comment: "") }
        static var importing: String { ls("import.importing", comment: "") }
        static var downloadTemplate: String {
            ls("import.downloadTemplate", comment: "")
        }
        static var createCategories: String {
            ls("import.createCategories", comment: "")
        }
        static var continueBtn: String { ls("import.continue", comment: "") }
        static var noAccountsAvailable: String {
            ls("import.noAccountsAvailable", comment: "")
        }
        static var createAccountFirst: String {
            ls("import.createAccountFirst", comment: "")
        }
        static var completed: String {
            ls("import.completed", comment: "")
        }
        static var importError: String {
            ls("import.error", comment: "")
        }
        static var templateGenerated: String {
            ls("import.templateGenerated", comment: "")
        }
        static var templateGeneratedMessage: String {
            ls("import.templateGeneratedMessage", comment: "")
        }
        static var introDescription: String {
            ls("import.introDescription", comment: "")
        }
        static var templateDescription: String {
            ls("import.templateDescription", comment: "")
        }
        static var categoriesDescription: String {
            ls("import.categoriesDescription", comment: "")
        }
        static var selectAccount: String {
            ls("import.selectAccount", comment: "")
        }
        static var fileUrlError: String {
            ls("import.fileUrlError", comment: "")
        }
        static var createAccountBeforeImport: String {
            ls("import.createAccountBeforeImport", comment: "")
        }

        // Multi-currency import
        static var multiCurrencyDetected: String {
            ls("import.multiCurrencyDetected", comment: "")
        }
        static var assignAccountPerCurrency: String {
            ls("import.assignAccountPerCurrency", comment: "")
        }
        static var selectAccountForCurrency: String {
            ls("import.selectAccountForCurrency", comment: "")
        }
        static func currenciesDetected(_ count: Int) -> String {
            String(format: ls("import.currenciesDetected", comment: ""), count)
        }
        static func recordsImported(_ count: Int) -> String {
            String(format: ls("import.recordsImported", comment: ""), count)
        }
        static func recordsImportedMultiCurrency(_ count: Int, _ currencies: Int) -> String {
            String(format: ls("import.recordsImportedMultiCurrency", comment: ""), count, currencies)
        }
        static func noAccountsForCurrency(_ currency: String) -> String {
            String(format: ls("import.noAccountsForCurrency", comment: ""), currency)
        }
        static var noCurrenciesDetected: String {
            ls("import.noCurrenciesDetected", comment: "")
        }
        static var importAction: String {
            ls("import.importAction", comment: "")
        }
    }

    // MARK: - Export

    enum Export {
        static var title: String { ls("export.title", comment: "") }
        static var filters: String { ls("export.filters", comment: "") }
        static var columns: String { ls("export.columns", comment: "") }
        static var summary: String { ls("export.summary", comment: "") }
        static var format: String { ls("export.format", comment: "") }
        static var period: String { ls("export.period", comment: "") }
        static var selectAll: String { ls("export.selectAll", comment: "") }
        static var deselectAll: String { ls("export.deselectAll", comment: "") }
        static var customizeFile: String { ls("export.customizeFile", comment: "") }
        static var csvGeneratedSuccess: String {
            ls("export.csvGeneratedSuccess", comment: "")
        }
        static var confirmExport: String { ls("export.confirmExport", comment: "") }
        static var selectColumns: String {
            ls("export.selectColumns", comment: "")
        }
        static var availableColumns: String {
            ls("export.availableColumns", comment: "")
        }
        static var columnsDescription: String {
            ls("export.columnsDescription", comment: "")
        }
        static var summaryAndExport: String {
            ls("export.summaryAndExport", comment: "")
        }
        static var summaryDescription: String {
            ls("export.summaryDescription", comment: "")
        }
        static var filtersSummary: String {
            ls("export.filtersSummary", comment: "")
        }
        static var columnsToExport: String {
            ls("export.columnsToExport", comment: "")
        }
        static var exportToCSV: String {
            ls("export.exportToCSV", comment: "")
        }
        static var exportBtn: String {
            ls("export.exportBtn", comment: "")
        }
        static var exportError: String {
            ls("export.exportError", comment: "")
        }
        static var exportCompleted: String {
            ls("export.exportCompleted", comment: "")
        }
        static var backToSettings: String {
            ls("export.backToSettings", comment: "")
        }
        static var exportData: String {
            ls("export.exportData", comment: "")
        }
        static var greaterThan: String {
            ls("export.greaterThan", comment: "")
        }
        static var lessThan: String {
            ls("export.lessThan", comment: "")
        }
        static var selectSingleCurrency: String {
            ls("export.selectSingleCurrency", comment: "")
        }
        static var allAvailable: String {
            ls("export.allAvailable", comment: "")
        }
        static var noTagsSelected: String {
            ls("export.noTagsSelected", comment: "")
        }
        static var noSubcategorySelected: String {
            ls("export.noSubcategorySelected", comment: "")
        }
        static var any: String {
            ls("export.any", comment: "")
        }
        static var between: String {
            ls("export.between", comment: "")
        }
        static var condition: String {
            ls("export.condition", comment: "")
        }
        static var noneSelected: String {
            ls("export.noneSelected", comment: "")
        }
        static func accountsSelected(_ count: Int) -> String {
            String(format: ls("export.accountsSelected", comment: ""), count)
        }
        static var allCategories: String {
            ls("export.allCategories", comment: "")
        }
        static func subcategoriesSelected(_ count: Int) -> String {
            String(format: ls("export.subcategoriesSelected", comment: ""), count)
        }
        static var allTags: String {
            ls("export.allTags", comment: "")
        }
        static var allCurrencies: String {
            ls("export.allCurrencies", comment: "")
        }

        // Column display names
        static var columnDate: String { ls("export.column.date", comment: "") }
        static var columnAmount: String { ls("export.column.amount", comment: "") }
        static var columnCurrency: String { ls("export.column.currency", comment: "") }
        static var columnAccount: String { ls("export.column.account", comment: "") }
        static var columnCategory: String { ls("export.column.category", comment: "") }
        static var columnSubcategory: String { ls("export.column.subcategory", comment: "") }
        static var columnTags: String { ls("export.column.tags", comment: "") }
        static var columnNote: String { ls("export.column.note", comment: "") }

        // Column descriptions
        static var columnDateDesc: String { ls("export.column.date.description", comment: "") }
        static var columnAmountDesc: String { ls("export.column.amount.description", comment: "") }
        static var columnCurrencyDesc: String { ls("export.column.currency.description", comment: "") }
        static var columnAccountDesc: String { ls("export.column.account.description", comment: "") }
        static var columnCategoryDesc: String { ls("export.column.category.description", comment: "") }
        static var columnSubcategoryDesc: String { ls("export.column.subcategory.description", comment: "") }
        static var columnTagsDesc: String { ls("export.column.tags.description", comment: "") }
        static var columnNoteDesc: String { ls("export.column.note.description", comment: "") }
    }

    // MARK: - Favorites

    enum Favorites {
        static var title: String { ls("favorites.title", comment: "") }
        static var new: String { ls("favorites.new", comment: "") }
        static var edit: String { ls("favorites.edit", comment: "") }
        static var noFavorites: String { ls("favorites.noFavorites", comment: "") }
        static var createTemplate: String {
            ls("favorites.createTemplate", comment: "")
        }
        static var newTitle: String {
            ls("favorites.newTitle", comment: "")
        }
        static var editTitle: String {
            ls("favorites.editTitle", comment: "")
        }
        static var namePlaceholder: String {
            ls("favorites.namePlaceholder", comment: "")
        }
        static var notConfigured: String {
            ls("favorites.notConfigured", comment: "")
        }
        static var descriptionPlaceholder: String {
            ls("favorites.descriptionPlaceholder", comment: "")
        }
        static var saveDescription: String {
            ls("favorites.saveDescription", comment: "")
        }
    }

    // MARK: - Scheduled

    enum Scheduled {
        static var saveDescription: String {
            ls("scheduled.saveDescription", comment: "")
        }

        static var paid: String {
            ls("scheduled.paid", comment: "Paid badge for scheduled payments")
        }

        static var draftCreatedTitle: String {
            ls("scheduled.draftCreatedTitle", comment: "Alert title when drafts created")
        }

        static func draftCreatedMessage(_ count: Int) -> String {
            String(format: ls("scheduled.draftCreatedMessage", comment: "Alert message"), count)
        }

        static var viewInbox: String {
            ls("scheduled.viewInbox", comment: "Button to view inbox")
        }

        enum Recurrence {
            static var daily: String { ls("scheduled.recurrence.daily", comment: "") }
            static var weekly: String { ls("scheduled.recurrence.weekly", comment: "") }
            static var monthly: String { ls("scheduled.recurrence.monthly", comment: "") }
            static var yearly: String { ls("scheduled.recurrence.yearly", comment: "") }
            static var day: String { ls("scheduled.recurrence.day", comment: "") }
            static var week: String { ls("scheduled.recurrence.week", comment: "") }
            static var month: String { ls("scheduled.recurrence.month", comment: "") }
            static var year: String { ls("scheduled.recurrence.year", comment: "") }
            static var days: String { ls("scheduled.recurrence.days", comment: "") }
            static var weeks: String { ls("scheduled.recurrence.weeks", comment: "") }
            static var months: String { ls("scheduled.recurrence.months", comment: "") }
            static var years: String { ls("scheduled.recurrence.years", comment: "") }
        }

        enum Category {
            static var recurring: String { ls("scheduled.category.recurring", comment: "") }
            static var subscription: String { ls("scheduled.category.subscription", comment: "") }
        }

        enum Status {
            static var past: String { ls("scheduled.status.past", comment: "") }
            static var today: String { ls("scheduled.status.today", comment: "") }
            static var upcoming: String { ls("scheduled.status.upcoming", comment: "") }
        }

        enum Filter {
            static var all: String { ls("scheduled.filter.all", comment: "") }
            static var paid: String { ls("scheduled.filter.paid", comment: "") }
            static var pending: String { ls("scheduled.filter.pending", comment: "") }
        }

        enum Tab {
            static var recurring: String { ls("scheduled.tab.recurring", comment: "") }
            static var subscriptions: String { ls("scheduled.tab.subscriptions", comment: "") }
            static var all: String { ls("scheduled.tab.all", comment: "") }
        }

        enum Widget {
            static var count: String { ls("scheduled.widget.count", comment: "") }
            static var emptyTitle: String { ls("scheduled.widget.empty.title", comment: "") }
            static var emptyMessage: String { ls("scheduled.widget.empty.message", comment: "") }
            static var daysAgo: String { ls("scheduled.widget.daysAgo", comment: "") }
            static var tomorrow: String { ls("scheduled.widget.tomorrow", comment: "") }
            static var inDays: String { ls("scheduled.widget.inDays", comment: "") }
        }

        enum Editor {
            static var recurrence: String { ls("scheduled.editor.recurrence", comment: "") }
            static var dayOfMonth: String { ls("scheduled.editor.day.of.month", comment: "") }
            static var isSubscription: String { ls("scheduled.is.subscription", comment: "") }
            static var onetime: String { ls("scheduled.recurrence.onetime", comment: "") }
            static var recurring: String { ls("scheduled.recurrence.recurring", comment: "") }
            static var every: String { ls("scheduled.every", comment: "") }
            static var whichDays: String { ls("scheduled.which.days", comment: "") }
            static var paymentDate: String { ls("scheduled.payment.date", comment: "") }
            static var startDate: String { ls("scheduled.start.date", comment: "") }
            static var hasEndDate: String { ls("scheduled.has.end.date", comment: "") }
            static var endDate: String { ls("scheduled.end.date", comment: "") }
            static var yearlyDate: String { ls("scheduled.yearly.date", comment: "") }
        }
    }

    // MARK: - Settings

    enum Settings {
        static var title: String { ls("settings.title", comment: "") }
        static var theme: String { ls("settings.theme", comment: "") }
        static var themeDescription: String {
            ls("settings.themeDescription", comment: "")
        }
        static var currency: String { ls("settings.currency", comment: "") }
        static var appIcon: String { ls("settings.appIcon", comment: "") }
        static var appIconDescription: String {
            ls("settings.appIconDescription", comment: "")
        }
        static var personalization: String {
            ls("settings.personalization", comment: "")
        }
        static var personalizationDescription: String {
            ls("settings.personalizationDescription", comment: "")
        }
        static var sectionInterface: String { ls("settings.sectionInterface", comment: "") }
        static var sectionCalendar: String { ls("settings.sectionCalendar", comment: "") }
        static var sectionIndicators: String { ls("settings.sectionIndicators", comment: "") }
        static var sectionFormat: String { ls("settings.sectionFormat", comment: "") }
        static var accounts: String { ls("settings.accounts", comment: "") }
        static var categories: String { ls("settings.categories", comment: "") }
        static var tags: String { ls("settings.tags", comment: "") }
        static var notifications: String {
            ls("settings.notifications", comment: "")
        }
        static var favorites: String { ls("settings.favorites", comment: "") }
        static var budgetsFavorites: String {
            ls("settings.budgetsFavorites", comment: "")
        }
        static var budgetsFavoritesInfo: String {
            ls("settings.budgetsFavoritesInfo", comment: "")
        }
        static var budgetsFavoritesEmptyHint: String {
            ls("settings.budgetsFavoritesEmptyHint", comment: "")
        }
        static var budgetsFavoritesReorder: String {
            ls("settings.budgetsFavoritesReorder", comment: "")
        }
        static var tabBarConfig: String {
            ls("settings.tabBarConfig", comment: "")
        }
        static var tabBarConfigInfo: String {
            ls("settings.tabBarConfigInfo", comment: "")
        }
        static var tabBarConfigActive: String {
            ls("settings.tabBarConfigActive", comment: "")
        }
        static var tabBarConfigAvailable: String {
            ls("settings.tabBarConfigAvailable", comment: "")
        }
        static var tabBarConfigReorderHint: String {
            ls("settings.tabBarConfigReorderHint", comment: "")
        }
        static var tabBarConfigMinWarning: String {
            ls("settings.tabBarConfigMinWarning", comment: "")
        }
        static var tabBarConfigMaxWarning: String {
            ls("settings.tabBarConfigMaxWarning", comment: "")
        }
        static var plannedPayments: String {
            ls("settings.plannedPayments", comment: "")
        }
        static var voiceInputEnabled: String {
            ls("settings.voiceInputEnabled", comment: "")
        }
        static var voiceLanguage: String {
            ls("settings.voiceLanguage", comment: "")
        }
        static var appLanguage: String {
            ls("settings.appLanguage", comment: "")
        }
        static var appLanguageRestart: String {
            ls("settings.appLanguageRestart", comment: "")
        }
        static var imageInputEnabled: String {
            ls("settings.imageInputEnabled", comment: "")
        }
        static var resetData: String { ls("settings.resetData", comment: "") }
        static var version: String { ls("settings.version", comment: "") }
        static var light: String { ls("settings.light", comment: "") }
        static var dark: String { ls("settings.dark", comment: "") }
        static var system: String { ls("settings.system", comment: "") }
        static var themeIndigo: String { ls("settings.theme.indigo", comment: "") }
        static var themeRosa: String { ls("settings.theme.rosa", comment: "") }
        static var themeTeal: String { ls("settings.theme.teal", comment: "") }
        static var defaultCurrency: String {
            ls("settings.defaultCurrency", comment: "")
        }
        static var currentIcon: String { ls("settings.currentIcon", comment: "") }
        static var resetAllData: String { ls("settings.resetAllData", comment: "") }
        static var deleteAllData: String {
            ls("settings.deleteAllData", comment: "")
        }
        static var currencyAndExchange: String {
            ls("settings.currencyAndExchange", comment: "")
        }
        static var currencyDescription: String {
            ls("settings.currencyDescription", comment: "")
        }
        static var preferredCurrency: String {
            ls("settings.preferredCurrency", comment: "")
        }
        static var exchangeRate: String { ls("settings.exchangeRate", comment: "") }
        static var secondaryCurrencies: String {
            ls("settings.secondaryCurrencies", comment: "")
        }
        static var secondaryCurrenciesHint: String {
            ls("settings.secondaryCurrenciesHint", comment: "")
        }
        static var showMoreCurrencies: String {
            ls("settings.showMoreCurrencies", comment: "")
        }
        static var recommendedCurrencies: String {
            ls("settings.recommendedCurrencies", comment: "")
        }

        static var versionInfo: String { ls("settings.versionInfo", comment: "") }

        // Sections
        static var organization: String { ls("settings.organization", comment: "") }
        static var preferences: String { ls("settings.preferences", comment: "") }
        static var data: String { ls("settings.data", comment: "") }
        static var security: String { ls("settings.security", comment: "") }
        static var help: String { ls("settings.help", comment: "") }
        static var legal: String { ls("settings.legal", comment: "") }

        // Rows
        static var importData: String { ls("settings.importData", comment: "") }
        static var exportData: String { ls("settings.exportData", comment: "") }
        static var wipeData: String { ls("settings.wipeData", comment: "") }
        static var faceId: String { ls("settings.faceId", comment: "") }
        static var permissions: String { ls("settings.permissions", comment: "") }
        static var subscriptions: String {
            ls("settings.subscriptions", comment: "")
        }
        static var rateApp: String { ls("settings.rateApp", comment: "") }
        static var tutorials: String { ls("settings.tutorials", comment: "") }
        static var faq: String { ls("settings.faq", comment: "") }
        static var contact: String { ls("settings.contact", comment: "") }
        static var privacy: String { ls("settings.privacy", comment: "") }
        static var terms: String { ls("settings.terms", comment: "") }

        // system, light, dark removed (duplicates)

        static var defaultPeriod: String {
            ls("settings.defaultPeriod", comment: "")
        }
        static var defaultPeriodDescription: String {
            ls("settings.defaultPeriodDescription", comment: "")
        }
        static var colorfulIcons: String {
            ls("settings.colorfulIcons", comment: "")
        }
        static var colorfulIconsDescription: String {
            ls("settings.colorfulIconsDescription", comment: "")
        }
        static var firstWeekday: String {
            ls("settings.firstWeekday", comment: "")
        }
        static var firstWeekdayDescription: String {
            ls("settings.firstWeekdayDescription", comment: "")
        }
        static var sunday: String {
            ls("settings.sunday", comment: "")
        }
        static var monday: String {
            ls("settings.monday", comment: "")
        }
        static var widgetHints: String {
            ls("settings.widgetHints", comment: "")
        }
        static var widgetHintsDescription: String {
            ls("settings.widgetHintsDescription", comment: "")
        }
        static var showVariations: String {
            ls("settings.showVariations", comment: "")
        }
        static var showVariationsDescription: String {
            ls("settings.showVariationsDescription", comment: "")
        }
        static var averageLine: String {
            ls("settings.averageLine", comment: "")
        }
        static var averageLineDescription: String {
            ls("settings.averageLineDescription", comment: "")
        }
        static var averageLineOff: String {
            ls("settings.averageLine.off", comment: "")
        }
        static var averageLineTotal: String {
            ls("settings.averageLine.total", comment: "")
        }
        static var averageLineSegmented: String {
            ls("settings.averageLine.segmented", comment: "")
        }
        static var averageLineOffDescription: String {
            ls("settings.averageLine.offDescription", comment: "")
        }
        static var averageLineTotalDescription: String {
            ls("settings.averageLine.totalDescription", comment: "")
        }
        static var averageLineSegmentedDescription: String {
            ls("settings.averageLine.segmentedDescription", comment: "")
        }
        static var decimalPlaces: String {
            ls("settings.decimalPlaces", comment: "")
        }
        static var decimalPlacesDescription: String {
            ls("settings.decimalPlacesDescription", comment: "")
        }
        static var decimalsNone: String {
            ls("settings.decimalsNone", comment: "")
        }
        static var decimalsOne: String {
            ls("settings.decimalsOne", comment: "")
        }
        static var decimalsTwo: String {
            ls("settings.decimalsTwo", comment: "")
        }
        static var currencyFormat: String {
            ls("settings.currencyFormat", comment: "")
        }
        static var currencyFormatDescription: String {
            ls("settings.currencyFormatDescription", comment: "")
        }
        static var currencyCode: String {
            ls("settings.currencyCode", comment: "")
        }
        static var currencySymbol: String {
            ls("settings.currencySymbol", comment: "")
        }
        // resetData removed (duplicate)
        static var resetDataDescription: String {
            ls("settings.resetDataDescription", comment: "")
        }
        // deleteAllData removed (duplicate)
        static var deleteDataConfirmation: String {
            ls("settings.deleteDataConfirmation", comment: "")
        }
        static var deleteDataWarning: String {
            ls("settings.deleteDataWarning", comment: "")
        }
        static var wipeICloudWarning: String {
            ls("settings.wipeICloudWarning", comment: "")
        }
        static var delete: String { ls("settings.delete", comment: "") }
        static var cancel: String { ls("settings.cancel", comment: "") }
        static var iconOriginal: String { ls("settings.iconOriginal", comment: "") }
        static var iconDark: String { ls("settings.iconDark", comment: "") }
        static var iconLight: String { ls("settings.iconLight", comment: "") }
        static var iconNeon: String { ls("settings.iconNeon", comment: "") }
        static var deleteAllDataAction: String {
            ls("settings.deleteAllDataAction", comment: "")
        }
        static var deletingData: String {
            ls("settings.deletingData", comment: "")
        }
        static var appIconTitle: String {
            ls("settings.appIconTitle", comment: "")
        }
        static var iconNotSupported: String {
            ls("settings.iconNotSupported", comment: "")
        }
        static func iconChangeFailed(_ error: String) -> String {
            String(format: ls("settings.iconChangeFailed", comment: ""), error)
        }
        static var deleteDataError: String {
            ls("settings.deleteDataError", comment: "")
        }
        static var deleteDataUnknownError: String {
            ls("settings.deleteDataUnknownError", comment: "")
        }

        // Expenses Only Mode
        static var sectionUsageMode: String { ls("settings.sectionUsageMode", comment: "") }
        static var expensesOnlyMode: String { ls("settings.expensesOnlyMode", comment: "") }
        static var expensesOnlyModeDescription: String { ls("settings.expensesOnlyModeDescription", comment: "") }
        static var expensesOnlyActivateTitle: String { ls("settings.expensesOnlyActivateTitle", comment: "") }
        static var expensesOnlyActivateMessage: String { ls("settings.expensesOnlyActivateMessage", comment: "") }
        static var expensesOnlyActivateConfirm: String { ls("settings.expensesOnlyActivateConfirm", comment: "") }
        static var expensesOnlyDeactivateTitle: String { ls("settings.expensesOnlyDeactivateTitle", comment: "") }
        static var expensesOnlyDeactivateMessage: String { ls("settings.expensesOnlyDeactivateMessage", comment: "") }
        static var expensesOnlyDeactivateConfirm: String { ls("settings.expensesOnlyDeactivateConfirm", comment: "") }
        static var expensesOnlyActive: String { ls("settings.expensesOnlyActive", comment: "") }
        static var categoryHidden: String { ls("settings.categoryHidden", comment: "") }
    }

    // MARK: - Profile

    enum Profile {
        static var defaultName: String { ls("profile.defaultName", comment: "") }
        static var title: String { ls("profile.title", comment: "") }
        static var edit: String { ls("profile.edit", comment: "") }
        static var importSuccess: String { ls("profile.importSuccess", comment: "") }
        static var importError: String { ls("profile.importError", comment: "") }
        static var appearance: String { ls("profile.appearance", comment: "") }
        static var personalDetails: String {
            ls("profile.personalDetails", comment: "")
        }
        static var changePhoto: String { ls("profile.changePhoto", comment: "") }
        static var addPhoto: String { ls("profile.addPhoto", comment: "") }
        static var yourName: String { ls("profile.yourName", comment: "") }
        static var aliasPlaceholder: String {
            ls("profile.aliasPlaceholder", comment: "")
        }
        static var characters: String { ls("profile.characters", comment: "") }
        static var minChars: String { ls("profile.minChars", comment: "") }
        static var maxChars: String { ls("profile.maxChars", comment: "") }
        static var allowedChars: String { ls("profile.allowedChars", comment: "") }
        static var aliasAvailable: String {
            ls("profile.aliasAvailable", comment: "")
        }
        static var aliasHelper: String { ls("profile.aliasHelper", comment: "") }
        static var privacyTitle: String { ls("profile.privacyTitle", comment: "") }
        static var privacyDesc: String { ls("profile.privacyDesc", comment: "") }
        static var aliasFutureNote: String {
            ls("profile.aliasFutureNote", comment: "")
        }
        static var proMember: String {
            ls("profile.proMember", comment: "Pro member subtitle")
        }
        static var choosePhoto: String { ls("profile.choosePhoto", comment: "") }
        static var chooseIcon: String { ls("profile.chooseIcon", comment: "") }
        static var removeAvatar: String { ls("profile.removeAvatar", comment: "") }
        static var editAvatar: String { ls("profile.editAvatar", comment: "") }
    }

    // MARK: - Common

    enum Common {
        static var accept: String { ls("common.accept", comment: "") }
        static var name: String { ls("common.name", comment: "") }
        static var alias: String { ls("common.alias", comment: "") }
        static var color: String { ls("common.color", comment: "") }
        static var icon: String { ls("common.icon", comment: "") }
        static var changeIcon: String { ls("common.changeIcon", comment: "") }
        static var search: String { ls("common.search", comment: "") }
        static var loading: String { ls("common.loading", comment: "") }
        static var error: String { ls("common.error", comment: "") }
        static var success: String { ls("common.success", comment: "") }
        static var unknownError: String { ls("common.unknownError", comment: "") }
        static var saveError: String { ls("common.saveError", comment: "") }
        static var deleteError: String { ls("common.deleteError", comment: "") }
        static var dataPrivacy: String { ls("common.dataPrivacy", comment: "") }
        static var active: String { ls("common.active", comment: "") }
        static var inactive: String { ls("common.inactive", comment: "") }
        static var hidden: String { ls("common.hidden", comment: "") }
        static var archived: String { ls("common.archived", comment: "") }
        static var recent: String { ls("common.recent", comment: "") }
        static var updatingRecords: String {
            ls("common.updatingRecords", comment: "")
        }
        static var recalculatingConversions: String {
            ls("common.recalculatingConversions", comment: "")
        }
        static var next: String { ls("common.next", comment: "") }
        static var moreOptions: String { ls("common.moreOptions", comment: "") }
        static var comingSoon: String { ls("common.comingSoon", comment: "") }
        static var all: String { ls("common.all", comment: "") }
        static var others: String { ls("common.others", comment: "") }
        static var remaining: String { ls("common.remaining", comment: "") }
        static var uncategorized: String { ls("common.uncategorized", comment: "") }
        static var date: String { ls("common.date", comment: "") }
        static var amount: String { ls("common.amount", comment: "") }
        static var base: String { ls("common.base", comment: "") }
        static var selectedDate: String { ls("common.selectedDate", comment: "") }
        static var selectedValue: String { ls("common.selectedValue", comment: "") }
        static var selectColor: String { ls("common.selectColor", comment: "") }
        static var useThisColor: String { ls("common.useThisColor", comment: "") }
        static var newColor: String { ls("common.newColor", comment: "") }
        static var understood: String { ls("common.understood", comment: "") }
        static var cannotUndo: String { ls("common.cannotUndo", comment: "") }
        static var general: String { ls("common.general", comment: "") }
        static var status: String { ls("common.status", comment: "") }
        static var actions: String { ls("common.actions", comment: "") }
        static var lastUpdate: String { ls("common.lastUpdate", comment: "") }
        static var cancel: String { ls("action.cancel", comment: "") }
        static var apply: String { ls("common.apply", comment: "Apply action") }
        static var selected: String { ls("common.selected", comment: "") }
        static var details: String { ls("common.details", comment: "") }
        static var select: String { ls("common.select", comment: "") }
        static var seeAll: String { ls("common.seeAll", comment: "") }
        static var none: String { ls("common.none", comment: "") }
        static var ok: String { ls("common.ok", comment: "") }
    }

    // MARK: - Widgets

    enum Widget {
        static var today: String { ls("widget.today", comment: "") }
        static var noData: String { ls("widget.noData", comment: "") }
        static var loading: String { ls("widget.loading", comment: "") }
        static var preferences: String { ls("widget.preferences", comment: "") }
        static var visible: String { ls("widget.visible", comment: "") }
        static var size: String { ls("widget.size", comment: "") }
        static var compact: String { ls("widget.compact", comment: "") }
        static var expanded: String { ls("widget.expanded", comment: "") }
        static var top3: String { ls("widget.top3", comment: "") }
        static var top5: String { ls("widget.top5", comment: "") }
        static var summary: String { ls("widget.summary", comment: "") }
        static var list: String { ls("widget.list", comment: "") }
        static var calendar: String { ls("widget.calendar", comment: "") }
        static var preferencesDescription: String {
            ls("widget.preferences.description", comment: "")
        }
        static var resetLayout: String { ls("widget.resetLayout", comment: "") }
        static var alwaysVisible: String { ls("widget.alwaysVisible", comment: "") }
        static var fixedPosition: String { ls("widget.fixedPosition", comment: "") }
        static var sizeLabel: String { ls("widget.sizeLabel", comment: "") }
        static var main: String { ls("widget.main", comment: "") }
        static var topCategories: String { ls("widget.topCategories", comment: "") }
        static var topSubcategories: String {
            ls("widget.topSubcategories", comment: "")
        }

        static var subcategories: String { ls("widget.subcategories", comment: "") }
        static var categories: String { ls("widget.categories", comment: "") }
        static var noExpensesPeriod: String {
            ls("widget.noExpensesPeriod", comment: "")
        }
        static var noExpensesSubcategoriesPeriod: String {
            ls("widget.noExpensesSubcategoriesPeriod", comment: "")
        }
        static var noExpensesNaturePeriod: String {
            ls("widget.noExpensesNaturePeriod", comment: "")
        }
        static var noExpensesDescriptionCategories: String {
            ls("widget.noExpensesDescriptionCategories", comment: "")
        }
        static var noExpensesDescriptionSubcategories: String {
            ls("widget.noExpensesDescriptionSubcategories", comment: "")
        }
        static var of: String { ls("widget.of", comment: "") }
        static var ofTotal: String { ls("widget.ofTotal", comment: "") }
        static var ofExpense: String { ls("widget.ofExpense", comment: "") }
        static var categoryAbbr: String { ls("widget.categoryAbbr", comment: "") }
        static var distributionByCategory: String {
            ls("widget.distributionByCategory", comment: "")
        }
        static var distributionBySubcategory: String {
            ls("widget.distributionBySubcategory", comment: "")
        }
        static var distributionByNature: String {
            ls("widget.distributionByNature", comment: "")
        }
        static var distributionByTag: String {
            ls("widget.distributionByTag", comment: "")
        }
        static var noDataForPeriod: String {
            ls("widget.noDataForPeriod", comment: "")
        }
        static func selectCurrencies(_ currency: String) -> String {
            String(format: ls("widget.selectCurrencies", comment: ""), currency)
        }
        static var currenciesToCompare: String {
            ls("widget.currenciesToCompare", comment: "")
        }
        static var noRecordsForFilters: String {
            ls("widget.noRecordsForFilters", comment: "")
        }
        static var recordsWillAppear: String {
            ls("widget.recordsWillAppear", comment: "")
        }
        static var total: String { ls("widget.total", comment: "") }
        static var average: String { ls("widget.average", comment: "") }

        // Widget Hints
        enum Hint {
            static var trend: String {
                ls("widget.hint.trend", comment: "")
            }
            static var topCategories: String {
                ls("widget.hint.topCategories", comment: "")
            }
            static var topSubcategories: String {
                ls("widget.hint.topSubcategories", comment: "")
            }
            static var categoriesPie: String {
                ls("widget.hint.categoriesPie", comment: "")
            }
            static var subcategoriesPie: String {
                ls("widget.hint.subcategoriesPie", comment: "")
            }
            static var tagsPie: String {
                ls("widget.hint.tagsPie", comment: "")
            }
            static var natureTrend: String {
                ls("widget.hint.natureTrend", comment: "")
            }
            static var cashFlow: String {
                ls("widget.hint.cashFlow", comment: "")
            }
            static var recentRecords: String {
                ls("widget.hint.recentRecords", comment: "")
            }
            static var budgets: String {
                ls("widget.hint.budgets", comment: "")
            }
            static var exchangeRate: String {
                ls("widget.hint.exchangeRate", comment: "")
            }
            static var scheduledPayments: String {
                ls("widget.hint.scheduledPayments", comment: "")
            }
            static var spendingAnalysis: String {
                ls("widget.hint.spendingAnalysis", comment: "")
            }
            static var incomeAnalysis: String {
                ls("widget.hint.incomeAnalysis", comment: "")
            }
        }
    }

    // MARK: - Widget Types

    enum WidgetType {
        static var trend: String { ls("widgetType.trend", comment: "") }
        static var topSpending: String { ls("widgetType.topSpending", comment: "") }
        static var topSubcategories: String {
            ls("widgetType.topSubcategories", comment: "")
        }
        static var cashFlow: String { ls("widgetType.cashFlow", comment: "") }
        static var categoriesPie: String {
            ls("widgetType.categoriesPie", comment: "")
        }
        static var subcategoriesPie: String {
            ls("widgetType.subcategoriesPie", comment: "")
        }
        static var latestRecords: String {
            ls("widgetType.latestRecords", comment: "")
        }
        static var expensesByNature: String {
            ls("widgetType.expensesByNature", comment: "")
        }
        static var expensesByTag: String {
            ls("widgetType.expensesByTag", comment: "")
        }
        static var exchangeRate: String {
            ls("widgetType.exchangeRate", comment: "")
        }
        static var budgets: String {
            ls("widgetType.budgets", comment: "")
        }
        static var scheduledPayments: String {
            ls("widgetType.scheduledPayments", comment: "")
        }
    }

    // MARK: - Budgets

    enum Budgets {
        enum Widget {
            static var selectFavorites: String {
                ls("budgets.widget.selectFavorites", comment: "")
            }
            static var noFavoritesTitle: String {
                ls("budgets.widget.noFavorites.title", comment: "")
            }
            static var noFavoritesMessage: String {
                ls("budgets.widget.noFavorites.message", comment: "")
            }
        }

        static var emptyTitle: String { ls("budgets.empty.title", comment: "") }
        static var emptyMessage: String { ls("budgets.empty.message", comment: "") }

        // Alert notifications
        static var alertsTitle: String {
            ls("budgets.alerts.title", comment: "")
        }
        static var alertsEnable: String {
            ls("budgets.alerts.enable", comment: "")
        }
        static var alertsThresholds: String {
            ls("budgets.alerts.thresholds", comment: "")
        }
        /// "Presupuesto \"%@\" al 50%% — %@ de %@ gastados" (name, spent, limit)
        static func alertMessage50(_ name: String, _ spent: String, _ limit: String) -> String {
            String(format: ls("budgets.alerts.message.50", comment: ""), name, spent, limit)
        }

        /// "Presupuesto \"%@\" al 75%% — %@ de %@ gastados" (name, spent, limit)
        static func alertMessage75(_ name: String, _ spent: String, _ limit: String) -> String {
            String(format: ls("budgets.alerts.message.75", comment: ""), name, spent, limit)
        }

        /// "Cuidado: \"%@\" casi agotado — %@ de %@" (name, spent, limit)
        static func alertMessage90(_ name: String, _ spent: String, _ limit: String) -> String {
            String(format: ls("budgets.alerts.message.90", comment: ""), name, spent, limit)
        }

        /// "Presupuesto \"%@\" agotado — Gastaste %@ de %@" (name, spent, limit)
        static func alertMessage100(_ name: String, _ spent: String, _ limit: String) -> String {
            String(format: ls("budgets.alerts.message.100", comment: ""), name, spent, limit)
        }

        /// Hint when budget alerts are globally disabled
        static var alertsGlobalDisabledHint: String { ls("budgets.alerts.globalDisabledHint", comment: "") }
    }

    // MARK: - Planning

    enum Planning {
        static var title: String { ls("planning.title", comment: "") }
        static var budgets: String { ls("planning.budgets", comment: "") }
        static var goals: String { ls("planning.goals", comment: "") }
        static var comingSoon: String { ls("planning.comingSoon", comment: "") }
        static var scheduledPayments: String {
            ls("planning.scheduledPayments", comment: "")
        }
    }

    // MARK: - Profile
    // MARK: - Icon Picker

    enum IconPicker {
        static var title: String { ls("iconPicker.title", comment: "") }
        static var preview: String { ls("iconPicker.preview", comment: "") }
        static var shopping: String { ls("iconPicker.shopping", comment: "") }
        static var food: String { ls("iconPicker.food", comment: "") }
        static var transport: String {
            ls("iconPicker.transport", comment: "")
        }
        static var finance: String { ls("iconPicker.finance", comment: "") }
        static var home: String { ls("iconPicker.home", comment: "") }
        static var services: String { ls("iconPicker.services", comment: "") }
        static var entertainment: String {
            ls("iconPicker.entertainment", comment: "")
        }
        static var sports: String { ls("iconPicker.sports", comment: "") }
        static var health: String { ls("iconPicker.health", comment: "") }
        static var personalCare: String {
            ls("iconPicker.personalCare", comment: "")
        }
        static var education: String {
            ls("iconPicker.education", comment: "")
        }
        static var work: String { ls("iconPicker.work", comment: "") }
        static var pets: String { ls("iconPicker.pets", comment: "") }
        static var nature: String { ls("iconPicker.nature", comment: "") }
        static var tech: String { ls("iconPicker.tech", comment: "") }
        static var travel: String { ls("iconPicker.travel", comment: "") }
        static var communication: String {
            ls("iconPicker.communication", comment: "")
        }
        static var tools: String { ls("iconPicker.tools", comment: "") }
        static var security: String { ls("iconPicker.security", comment: "") }
        static var symbols: String { ls("iconPicker.symbols", comment: "") }
        static var direction: String {
            ls("iconPicker.direction", comment: "")
        }
        static var other: String { ls("iconPicker.other", comment: "") }
    }

    // MARK: - CashFlow View Type

    enum CashFlowViewType {
        static var total: String { ls("cashFlowViewType.total", comment: "") }
        static var byAccount: String {
            ls("cashFlowViewType.byAccount", comment: "")
        }
        static var byCurrency: String {
            ls("cashFlowViewType.byCurrency", comment: "")
        }
    }

    // MARK: - List View Type

    enum ListViewType {
        static var categories: String { ls("listViewType.categories", comment: "") }
        static var subcategories: String {
            ls("listViewType.subcategories", comment: "")
        }
    }

    // MARK: - Comparison Mode

    enum Comparison {
        static var month: String { ls("comparison.month", comment: "Month comparison") }
        static var year: String { ls("comparison.year", comment: "Year comparison") }
        static var monthShort: String { ls("comparison.monthShort", comment: "Short for previous period") }
        static var yearShort: String { ls("comparison.yearShort", comment: "Short for previous year") }
    }

    // MARK: - Validation

    enum Validation {
        static var enterAmountGreaterThanZero: String {
            ls("validation.enterAmountGreaterThanZero", comment: "")
        }
        static var selectSourceAccount: String {
            ls("validation.selectSourceAccount", comment: "")
        }
        static var selectDestinationAccount: String {
            ls("validation.selectDestinationAccount", comment: "")
        }
        static var accountsMustBeDifferent: String {
            ls("validation.accountsMustBeDifferent", comment: "")
        }
        static var selectAccount: String {
            ls("validation.selectAccount", comment: "")
        }
        static var selectSubcategory: String {
            ls("validation.selectSubcategory", comment: "")
        }
        static var futureDateTitle: String {
            ls("validation.futureDateTitle", comment: "")
        }
        static var futureDateMessage: String {
            ls("validation.futureDateMessage", comment: "")
        }
    }

    // MARK: - Transfer

    enum Transfer {
        static func transferTo(_ accountName: String) -> String {
            String(format: ls("transfer.transferTo", comment: ""), accountName)
        }
        static func transferFrom(_ accountName: String) -> String {
            String(format: ls("transfer.transferFrom", comment: ""), accountName)
        }
        static var categoryName: String {
            ls("transfer.categoryName", comment: "")
        }
    }

    enum More {
        static var sections: String {
            ls("more.sections", comment: "")
        }
    }

    // MARK: - Onboarding

    enum Onboarding {
        static var welcomeTitle: String {
            ls("onboarding.welcomeTitle", comment: "")
        }
        static var welcomeSubtitle: String {
            ls("onboarding.welcomeSubtitle", comment: "")
        }
        static var nameLabel: String {
            ls("onboarding.nameLabel", comment: "")
        }
        static var namePlaceholder: String {
            ls("onboarding.namePlaceholder", comment: "")
        }
        static var currencyTitle: String {
            ls("onboarding.currencyTitle", comment: "")
        }
        static var currencySubtitle: String {
            ls("onboarding.currencySubtitle", comment: "")
        }
        static var secondaryTitle: String {
            ls("onboarding.secondaryTitle", comment: "")
        }
        static var secondarySubtitle: String {
            ls("onboarding.secondarySubtitle", comment: "")
        }
        static func secondaryHint(_ count: Int, _ max: Int) -> String {
            String(format: ls("onboarding.secondaryHint", comment: ""), count, max)
        }
        static var periodTitle: String {
            ls("onboarding.periodTitle", comment: "")
        }
        static var periodSubtitle: String {
            ls("onboarding.periodSubtitle", comment: "")
        }
        static var finish: String {
            ls("onboarding.finish", comment: "")
        }
        static var defaultAccountName: String {
            ls("onboarding.defaultAccountName", comment: "")
        }
        static var categoriesTitle: String {
            ls("onboarding.categoriesTitle", comment: "")
        }
        static var categoriesSubtitle: String {
            ls("onboarding.categoriesSubtitle", comment: "")
        }
        static var categoriesYes: String {
            ls("onboarding.categoriesYes", comment: "")
        }
        static var categoriesNo: String {
            ls("onboarding.categoriesNo", comment: "")
        }
        static var categoriesRecommended: String {
            ls("onboarding.categoriesRecommended", comment: "")
        }
        static var categoriesInfo: String {
            ls("onboarding.categoriesInfo", comment: "")
        }
        static var notificationsTitle: String {
            ls("onboarding.notificationsTitle", comment: "")
        }
        static var notificationsSubtitle: String {
            ls("onboarding.notificationsSubtitle", comment: "")
        }
        static var notificationsSkip: String {
            ls("onboarding.notificationsSkip", comment: "")
        }
        static var notificationsSelectAll: String {
            ls("onboarding.notificationsSelectAll", comment: "")
        }
        static var notificationsDeselectAll: String {
            ls("onboarding.notificationsDeselectAll", comment: "")
        }
        static var recommended: String {
            ls("onboarding.recommended", comment: "")
        }
        static var languageTitle: String {
            ls("onboarding.languageTitle", comment: "")
        }
        static var languageSubtitle: String {
            ls("onboarding.languageSubtitle", comment: "")
        }
        // Expenses Only Mode step
        static var expensesOnlyTitle: String {
            ls("onboarding.expensesOnlyTitle", comment: "")
        }
        static var expensesOnlySubtitle: String {
            ls("onboarding.expensesOnlySubtitle", comment: "")
        }
        static var expensesOnlyOptionAll: String {
            ls("onboarding.expensesOnlyOptionAll", comment: "")
        }
        static var expensesOnlyOptionExpenses: String {
            ls("onboarding.expensesOnlyOptionExpenses", comment: "")
        }
        static var privacyTitle: String { ls("onboarding.privacyTitle", comment: "") }
        static var privacySubtitle: String { ls("onboarding.privacySubtitle", comment: "") }
        static var privacyLocal: String { ls("onboarding.privacyLocal", comment: "") }
        static var privacyNoTracking: String { ls("onboarding.privacyNoTracking", comment: "") }
        static var privacyIcloud: String { ls("onboarding.privacyIcloud", comment: "") }
        static var privacyNoSharing: String { ls("onboarding.privacyNoSharing", comment: "") }
        static var privacyTutorialsHint: String { ls("onboarding.privacyTutorialsHint", comment: "") }
    }

    // MARK: - Bulk Edit

    enum BulkEdit {
        static var currencyWarning: String {
            ls("bulkEdit.currencyWarning", comment: "")
        }
        static func editCount(_ count: Int) -> String {
            String(format: ls("bulkEdit.editCount", comment: ""), count)
        }
        static var successMessage: String {
            ls("bulkEdit.successMessage", comment: "")
        }
        static var commonTags: String {
            ls("bulkEdit.commonTags", comment: "")
        }
        static var partialTags: String {
            ls("bulkEdit.partialTags", comment: "")
        }
        static var availableTags: String {
            ls("bulkEdit.availableTags", comment: "")
        }
    }

    // MARK: - Voice Language

    enum VoiceLanguage {
        static var system: String {
            ls("voiceLanguage.system", comment: "")
        }
        static var spanish: String {
            ls("voiceLanguage.spanish", comment: "")
        }
        static var english: String {
            ls("voiceLanguage.english", comment: "")
        }
    }

    // MARK: - Inbox

    enum Inbox {
        static var title: String {
            ls("inbox.title", comment: "")
        }
        static var pending: String {
            ls("inbox.pending", comment: "")
        }
        static var archived: String {
            ls("inbox.archived", comment: "")
        }
        static var noDescription: String {
            ls("inbox.noDescription", comment: "")
        }
        static var noAmount: String {
            ls("inbox.noAmount", comment: "")
        }
        static var missingLabel: String {
            ls("inbox.missingLabel", comment: "")
        }
        static var needsAccount: String {
            ls("inbox.needsAccount", comment: "")
        }
        static var needsSubcategory: String {
            ls("inbox.needsSubcategory", comment: "")
        }
        static var approve: String {
            ls("inbox.approve", comment: "")
        }
        static var delete: String {
            ls("inbox.delete", comment: "")
        }
        static var noPending: String {
            ls("inbox.noPending", comment: "")
        }
        static var noPendingDescription: String {
            ls("inbox.noPendingDescription", comment: "")
        }
        static var bulkHint: String {
            ls("inbox.bulkHint", comment: "")
        }
        static var newTag: String {
            ls("inbox.newTag", comment: "")
        }
        static var noArchived: String {
            ls("inbox.noArchived", comment: "")
        }
        static var noArchivedDescription: String {
            ls("inbox.noArchivedDescription", comment: "")
        }
        static func selectedCount(_ count: Int) -> String {
            String(format: ls("inbox.selectedCount", comment: ""), count)
        }
        static var editDraft: String {
            ls("inbox.editDraft", comment: "")
        }
        static var cannotApprove: String {
            ls("inbox.cannotApprove", comment: "")
        }
        static var sourceVoice: String {
            ls("inbox.sourceVoice", comment: "")
        }
        static var sourceEmail: String {
            ls("inbox.sourceEmail", comment: "")
        }
        static var sourceScreenshot: String {
            ls("inbox.sourceScreenshot", comment: "")
        }
        static var sourceScreenshotList: String {
            ls("inbox.sourceScreenshotList", comment: "")
        }
        static var sourceReceipt: String {
            ls("inbox.sourceReceipt", comment: "")
        }
        static var sourceScheduledPayment: String {
            ls("inbox.sourceScheduledPayment", comment: "")
        }
        static var sourceSubscription: String {
            ls("inbox.sourceSubscription", comment: "")
        }
        static var sourceApplePay: String {
            ls("inbox.sourceApplePay", comment: "")
        }
        static var sourceAutomation: String {
            ls("inbox.sourceAutomation", comment: "")
        }
        static var sourceSiri: String {
            ls("inbox.sourceSiri", comment: "")
        }
        static var errorNoAccount: String {
            ls("inbox.errorNoAccount", comment: "")
        }
        static var errorNoAmount: String {
            ls("inbox.errorNoAmount", comment: "")
        }
        static var errorNoSubcategory: String {
            ls("inbox.errorNoSubcategory", comment: "")
        }
        static var errorArchivedAccount: String {
            ls("inbox.errorArchivedAccount", comment: "")
        }
        static var errorFutureDate: String {
            ls("inbox.errorFutureDate", comment: "")
        }
        static var duplicateWarningTitle: String {
            ls("inbox.duplicateWarningTitle", comment: "")
        }
        static var duplicateWarningMessage: String {
            ls("inbox.duplicateWarningMessage", comment: "")
        }
        static var createAnyway: String {
            ls("inbox.createAnyway", comment: "")
        }
        static func deleteConfirmMessage(_ count: Int) -> String {
            String(format: ls("inbox.deleteConfirmMessage", comment: ""), count)
        }
        static func approveableCount(_ count: Int, _ total: Int) -> String {
            String(format: ls("inbox.approveableCount", comment: ""), count, total)
        }
        static var saveLater: String {
            ls("inbox.saveLater", comment: "")
        }
        static var deleteTitle: String {
            ls("inbox.deleteTitle", comment: "")
        }
        static var deleteMessage: String {
            ls("inbox.deleteMessage", comment: "")
        }
        static var reject: String {
            ls("inbox.reject", comment: "")
        }
        static var returnToPending: String {
            ls("inbox.returnToPending", comment: "")
        }
        static var discardChangesTitle: String {
            ls("inbox.discardChangesTitle", comment: "")
        }
        static var discardChanges: String {
            ls("inbox.discardChanges", comment: "")
        }
        static var keepEditing: String {
            ls("inbox.keepEditing", comment: "")
        }
        static var discardChangesMessage: String {
            ls("inbox.discardChangesMessage", comment: "")
        }
        static var approveSuccess: String {
            ls("inbox.approveSuccess", comment: "")
        }
        static var approveNext: String {
            ls("inbox.approveNext", comment: "")
        }
        static var transactionCreated: String {
            ls("inbox.transactionCreated", comment: "")
        }
        static var transactionsCreated: String {
            ls("inbox.transactionsCreated", comment: "")
        }
        static var viewInRecords: String {
            ls("inbox.viewInRecords", comment: "")
        }
        static var backToInbox: String {
            ls("inbox.backToInbox", comment: "")
        }

        // MARK: Alert Modal

        enum Alert {
            enum Title {
                static var scheduled: String {
                    ls("inbox.alert.title.scheduled", comment: "")
                }
                static var subscriptions: String {
                    ls("inbox.alert.title.subscriptions", comment: "")
                }
                static var automations: String {
                    ls("inbox.alert.title.automations", comment: "")
                }
                static var mixed: String {
                    ls("inbox.alert.title.mixed", comment: "")
                }
            }

            enum Message {
                static func scheduled(_ count: Int) -> String {
                    String(format: ls("inbox.alert.message.scheduled", comment: ""), count)
                }
                static func subscriptions(_ count: Int) -> String {
                    String(format: ls("inbox.alert.message.subscriptions", comment: ""), count)
                }
                static func automations(_ count: Int) -> String {
                    String(format: ls("inbox.alert.message.automations", comment: ""), count)
                }

                enum Mixed {
                    static func scheduled(_ count: Int) -> String {
                        String(format: ls("inbox.alert.message.mixed.scheduled", comment: ""), count)
                    }
                    static func subscriptions(_ count: Int) -> String {
                        String(format: ls("inbox.alert.message.mixed.subscriptions", comment: ""), count)
                    }
                    static func automations(_ count: Int) -> String {
                        String(format: ls("inbox.alert.message.mixed.automations", comment: ""), count)
                    }
                    static var connector: String {
                        ls("inbox.alert.message.mixed.connector", comment: "")
                    }
                }
            }
        }
    }

    // MARK: - Voice Input

    enum Voice {
        static var title: String {
            ls("voice.title", comment: "")
        }
        static var recording: String {
            ls("voice.recording", comment: "")
        }
        static var recorded: String {
            ls("voice.recorded", comment: "")
        }
        static var pleaseWait: String {
            ls("voice.pleaseWait", comment: "")
        }
        static var tapToRecord: String {
            ls("voice.tapToRecord", comment: "")
        }
        static var youCanSay: String {
            ls("voice.youCanSay", comment: "")
        }
        static var hintTypeExample: String {
            ls("voice.hintTypeExample", comment: "")
        }
        static var hintAmountExample: String {
            ls("voice.hintAmountExample", comment: "")
        }
        static var hintSubcategoryExample: String {
            ls("voice.hintSubcategoryExample", comment: "")
        }
        static var hintMerchantExample: String {
            ls("voice.hintMerchantExample", comment: "")
        }
        static var hintTagExample: String {
            ls("voice.hintTagExample", comment: "")
        }
        static var hintDateExample: String {
            ls("voice.hintDateExample", comment: "")
        }
        static var exampleLabel: String {
            ls("voice.exampleLabel", comment: "")
        }
        static var example1: String {
            ls("voice.example1", comment: "")
        }
        static var example2: String {
            ls("voice.example2", comment: "")
        }
        static var example3: String {
            ls("voice.example3", comment: "")
        }
        static var processingAudio: String {
            ls("voice.processingAudio", comment: "")
        }
        static var analyzing: String {
            ls("voice.analyzing", comment: "")
        }
        static var parsing: String {
            ls("voice.parsing", comment: "")
        }
        static var saving: String {
            ls("voice.saving", comment: "")
        }
        static var errorNoAmount: String {
            ls("voice.errorNoAmount", comment: "")
        }
        static var errorNoApiKey: String {
            ls("voice.errorNoApiKey", comment: "")
        }
        static var errorNoConnection: String {
            ls("voice.errorNoConnection", comment: "")
        }
        static var errorMicPermission: String {
            ls("voice.errorMicPermission", comment: "")
        }
        static var errorSaveFailed: String {
            ls("voice.errorSaveFailed", comment: "")
        }
        static var openSettings: String {
            ls("voice.openSettings", comment: "")
        }
        static var tryImage: String {
            ls("voice.tryImage", comment: "")
        }
    }

    // MARK: - Image Input

    enum Image {
        static var title: String {
            ls("image.title", comment: "")
        }
        static var selectTitle: String {
            ls("image.selectTitle", comment: "")
        }
        static var selectSubtitle: String {
            ls("image.selectSubtitle", comment: "")
        }
        static var selectButton: String {
            ls("image.selectButton", comment: "")
        }
        static var processing: String {
            ls("image.processing", comment: "")
        }
        static var processingSubtitle: String {
            ls("image.processingSubtitle", comment: "")
        }
        static var errorTitle: String {
            ls("image.errorTitle", comment: "")
        }
        static var errorLoad: String {
            ls("image.errorLoad", comment: "")
        }
        static var errorNoData: String {
            ls("image.errorNoData", comment: "")
        }
        static var errorUnrecognized: String {
            ls("image.errorUnrecognized", comment: "")
        }
        static var errorGeneric: String {
            ls("image.errorGeneric", comment: "")
        }
        static var errorPhotoPermission: String {
            ls("image.errorPhotoPermission", comment: "")
        }
        static var errorCorrupted: String {
            ls("image.errorCorrupted", comment: "")
        }
        static var errorSaveFailed: String {
            ls("image.errorSaveFailed", comment: "")
        }
        static var errorNoApiKey: String {
            ls("image.errorNoApiKey", comment: "")
        }
        static var errorNoConnection: String {
            ls("image.errorNoConnection", comment: "")
        }
        static var openSettings: String {
            ls("image.openSettings", comment: "")
        }
        static var transactionDetected: String {
            ls("image.transactionDetected", comment: "")
        }
        static var transactionsDetectedCount: String {
            ls("image.transactionsDetectedCount", comment: "")
        }
        static var reviewDraft: String {
            ls("image.reviewDraft", comment: "")
        }
        static var transactionsDetected: String {
            ls("image.transactionsDetected", comment: "")
        }
        static var goToInbox: String {
            ls("image.goToInbox", comment: "")
        }
        static func transactionsDetectedMessage(_ count: Int) -> String {
            String(format: ls("image.transactionsDetectedMessage", comment: ""), count)
        }
        static func analyzingIn(_ seconds: Int) -> String {
            String(format: ls("image.analyzingIn", comment: ""), seconds)
        }
        static func imagesSelected(_ count: Int) -> String {
            String(format: ls("image.imagesSelected", comment: ""), count)
        }
        static var youCanUpload: String {
            ls("image.youCanUpload", comment: "")
        }
        static var hintReceipts: String {
            ls("image.hintReceipts", comment: "")
        }
        static var hintBankScreenshots: String {
            ls("image.hintBankScreenshots", comment: "")
        }
        static var hintRestaurantTickets: String {
            ls("image.hintRestaurantTickets", comment: "")
        }
        static var hintStatements: String {
            ls("image.hintStatements", comment: "")
        }
        static var hintPaymentProofs: String {
            ls("image.hintPaymentProofs", comment: "")
        }
        static var hintMultiple: String {
            ls("image.hintMultiple", comment: "")
        }
        static var exampleLabel: String {
            ls("image.exampleLabel", comment: "")
        }
        static var example1: String {
            ls("image.example1", comment: "")
        }
        static var example2: String {
            ls("image.example2", comment: "")
        }
        static var example3: String {
            ls("image.example3", comment: "")
        }
    }

    // MARK: - Biometric

    enum Biometric {
        static var title: String { ls("biometric.title", comment: "") }
        static var description: String { ls("biometric.description", comment: "") }
        static var enableLock: String { ls("biometric.enableLock", comment: "") }
        static var lockAfter: String { ls("biometric.lockAfter", comment: "") }
        static var timeoutImmediate: String {
            ls("biometric.timeout.immediate", comment: "")
        }
        static var timeoutOneMinute: String {
            ls("biometric.timeout.oneMinute", comment: "")
        }
        static var timeoutFiveMinutes: String {
            ls("biometric.timeout.fiveMinutes", comment: "")
        }
        static var timeoutFifteenMinutes: String {
            ls("biometric.timeout.fifteenMinutes", comment: "")
        }
        static var authReason: String { ls("biometric.authReason", comment: "") }
        static var enableReason: String { ls("biometric.enableReason", comment: "") }
        static var authFailed: String { ls("biometric.authFailed", comment: "") }
        static var authFailedMessage: String {
            ls("biometric.authFailedMessage", comment: "")
        }
        static var locked: String { ls("biometric.locked", comment: "") }
        static var unlockPrompt: String { ls("biometric.unlockPrompt", comment: "") }
        static var unlock: String { ls("biometric.unlock", comment: "") }
        static var passcode: String { ls("biometric.passcode", comment: "") }
        static var enableLockHint: String {
            ls("biometric.enableLockHint", comment: "")
        }
        static var lockAfterHint: String {
            ls("biometric.lockAfterHint", comment: "")
        }
    }

    // MARK: - Subscription
    enum Subscription {
        static var title: String { ls("subscription.title", comment: "") }
        static var paywallTitle: String { ls("subscription.paywallTitle", comment: "") }
        static var paywallSubtitle: String { ls("subscription.paywallSubtitle", comment: "") }
        static var subscribe: String { ls("subscription.subscribe", comment: "") }
        static var processing: String { ls("subscription.processing", comment: "") }
        static var restore: String { ls("subscription.restore", comment: "") }
        static var planMonthly: String { ls("subscription.planMonthly", comment: "") }
        static var planYearly: String { ls("subscription.planYearly", comment: "") }
        static var perYear: String { ls("subscription.perYear", comment: "") }
        static func perMonth(_ price: String) -> String {
            String(format: ls("subscription.perMonth", comment: ""), price)
        }
        static func saveBadge(_ percent: Int) -> String {
            String(format: ls("subscription.saveBadge", comment: ""), percent)
        }
        static var featureVoice: String { ls("subscription.feature.voice", comment: "") }
        static var featureImage: String { ls("subscription.feature.image", comment: "") }
        static var featureReports: String { ls("subscription.feature.reports", comment: "") }
        static var featureCurrencies: String { ls("subscription.feature.currencies", comment: "") }
        static var featureThemes: String { ls("subscription.feature.themes", comment: "") }
        static var featureExport: String { ls("subscription.feature.export", comment: "") }
        static var legalFooter: String { ls("subscription.legalFooter", comment: "") }
        static var termsLink: String { ls("subscription.termsLink", comment: "") }
        static var errorTitle: String { ls("subscription.errorTitle", comment: "") }
        static var activeTitle: String { ls("subscription.activeTitle", comment: "") }
        static var activeSubtitle: String { ls("subscription.activeSubtitle", comment: "") }
        static var currentPlan: String { ls("subscription.currentPlan", comment: "") }
        static var renewsOn: String { ls("subscription.renewsOn", comment: "") }
        static var manageInAppStore: String { ls("subscription.manageInAppStore", comment: "") }
        static var startFreeTrial: String { ls("subscription.startFreeTrial", comment: "") }
        static func trialThenPrice(_ days: String, _ price: String) -> String {
            String(format: ls("subscription.trialThenPrice", comment: ""), days, price)
        }
    }

    // MARK: - Trial Offer
    enum TrialOffer {
        static var title: String { ls("subscription.trialOffer.title", comment: "") }
        static var subtitle: String { ls("subscription.trialOffer.subtitle", comment: "") }
        static var startTrial: String { ls("subscription.trialOffer.startTrial", comment: "") }
        static var maybeLater: String { ls("subscription.trialOffer.maybeLater", comment: "") }
    }

    enum Tutorials {
        static var subtitle: String { ls("tutorials.subtitle", comment: "") }
        static var stepsCount: String { ls("tutorials.stepsCount", comment: "") }
        static var next: String { ls("tutorials.next", comment: "") }
        static var previous: String { ls("tutorials.previous", comment: "") }
        static var done: String { ls("tutorials.done", comment: "") }
        static var start: String { ls("tutorials.start", comment: "") }
        static var understood: String { ls("tutorials.understood", comment: "") }
        static var nextTutorial: String { ls("tutorials.nextTutorial", comment: "") }

        // Categories
        static var categoryGettingStarted: String { ls("tutorials.category.gettingStarted", comment: "") }
        static var categoryDailyUse: String { ls("tutorials.category.dailyUse", comment: "") }
        static var categoryPersonalization: String { ls("tutorials.category.personalization", comment: "") }
        static var categoryAdvanced: String { ls("tutorials.category.advanced", comment: "") }
        static var categoryPowerUser: String { ls("tutorials.category.powerUser", comment: "") }

        // 1. createAccount (3 steps)
        static var createAccountTitle: String { ls("tutorials.createAccount.title", comment: "") }
        static var createAccountIntroTitle: String { ls("tutorials.createAccount.intro.title", comment: "") }
        static var createAccountIntroDesc: String { ls("tutorials.createAccount.intro.desc", comment: "") }
        static var createAccountStep0Title: String { ls("tutorials.createAccount.step0.title", comment: "") }
        static var createAccountStep0Desc: String { ls("tutorials.createAccount.step0.desc", comment: "") }
        static var createAccountStep1Title: String { ls("tutorials.createAccount.step1.title", comment: "") }
        static var createAccountStep1Desc: String { ls("tutorials.createAccount.step1.desc", comment: "") }
        static var createAccountStep2Title: String { ls("tutorials.createAccount.step2.title", comment: "") }
        static var createAccountStep2Desc: String { ls("tutorials.createAccount.step2.desc", comment: "") }
        static var createAccountCompletionTitle: String { ls("tutorials.createAccount.completion.title", comment: "") }
        static var createAccountCompletionDesc: String { ls("tutorials.createAccount.completion.desc", comment: "") }

        // 2. createCategories (4 steps)
        static var createCategoriesTitle: String { ls("tutorials.createCategories.title", comment: "") }
        static var createCategoriesIntroTitle: String { ls("tutorials.createCategories.intro.title", comment: "") }
        static var createCategoriesIntroDesc: String { ls("tutorials.createCategories.intro.desc", comment: "") }
        static var createCategoriesStep0Title: String { ls("tutorials.createCategories.step0.title", comment: "") }
        static var createCategoriesStep0Desc: String { ls("tutorials.createCategories.step0.desc", comment: "") }
        static var createCategoriesStep1Title: String { ls("tutorials.createCategories.step1.title", comment: "") }
        static var createCategoriesStep1Desc: String { ls("tutorials.createCategories.step1.desc", comment: "") }
        static var createCategoriesStep2Title: String { ls("tutorials.createCategories.step2.title", comment: "") }
        static var createCategoriesStep2Desc: String { ls("tutorials.createCategories.step2.desc", comment: "") }
        static var createCategoriesStep3Title: String { ls("tutorials.createCategories.step3.title", comment: "") }
        static var createCategoriesStep3Desc: String { ls("tutorials.createCategories.step3.desc", comment: "") }
        static var createCategoriesCompletionTitle: String { ls("tutorials.createCategories.completion.title", comment: "") }
        static var createCategoriesCompletionDesc: String { ls("tutorials.createCategories.completion.desc", comment: "") }

        // 3. createTags (2 steps)
        static var createTagsTitle: String { ls("tutorials.createTags.title", comment: "") }
        static var createTagsIntroTitle: String { ls("tutorials.createTags.intro.title", comment: "") }
        static var createTagsIntroDesc: String { ls("tutorials.createTags.intro.desc", comment: "") }
        static var createTagsStep0Title: String { ls("tutorials.createTags.step0.title", comment: "") }
        static var createTagsStep0Desc: String { ls("tutorials.createTags.step0.desc", comment: "") }
        static var createTagsStep1Title: String { ls("tutorials.createTags.step1.title", comment: "") }
        static var createTagsStep1Desc: String { ls("tutorials.createTags.step1.desc", comment: "") }
        static var createTagsCompletionTitle: String { ls("tutorials.createTags.completion.title", comment: "") }
        static var createTagsCompletionDesc: String { ls("tutorials.createTags.completion.desc", comment: "") }

        // 4. createRecord (4 steps)
        static var createRecordTitle: String { ls("tutorials.createRecord.title", comment: "") }
        static var createRecordIntroTitle: String { ls("tutorials.createRecord.intro.title", comment: "") }
        static var createRecordIntroDesc: String { ls("tutorials.createRecord.intro.desc", comment: "") }
        static var createRecordStep0Title: String { ls("tutorials.createRecord.step0.title", comment: "") }
        static var createRecordStep0Desc: String { ls("tutorials.createRecord.step0.desc", comment: "") }
        static var createRecordStep1Title: String { ls("tutorials.createRecord.step1.title", comment: "") }
        static var createRecordStep1Desc: String { ls("tutorials.createRecord.step1.desc", comment: "") }
        static var createRecordStep2Title: String { ls("tutorials.createRecord.step2.title", comment: "") }
        static var createRecordStep2Desc: String { ls("tutorials.createRecord.step2.desc", comment: "") }
        static var createRecordStep3Title: String { ls("tutorials.createRecord.step3.title", comment: "") }
        static var createRecordStep3Desc: String { ls("tutorials.createRecord.step3.desc", comment: "") }
        static var createRecordCompletionTitle: String { ls("tutorials.createRecord.completion.title", comment: "") }
        static var createRecordCompletionDesc: String { ls("tutorials.createRecord.completion.desc", comment: "") }

        // 5. importData (2 steps)
        static var importDataTitle: String { ls("tutorials.importData.title", comment: "") }
        static var importDataIntroTitle: String { ls("tutorials.importData.intro.title", comment: "") }
        static var importDataIntroDesc: String { ls("tutorials.importData.intro.desc", comment: "") }
        static var importDataStep0Title: String { ls("tutorials.importData.step0.title", comment: "") }
        static var importDataStep0Desc: String { ls("tutorials.importData.step0.desc", comment: "") }
        static var importDataStep1Title: String { ls("tutorials.importData.step1.title", comment: "") }
        static var importDataStep1Desc: String { ls("tutorials.importData.step1.desc", comment: "") }
        static var importDataCompletionTitle: String { ls("tutorials.importData.completion.title", comment: "") }
        static var importDataCompletionDesc: String { ls("tutorials.importData.completion.desc", comment: "") }

        // 6. createBudgets (4 steps)
        static var createBudgetsTitle: String { ls("tutorials.createBudgets.title", comment: "") }
        static var createBudgetsIntroTitle: String { ls("tutorials.createBudgets.intro.title", comment: "") }
        static var createBudgetsIntroDesc: String { ls("tutorials.createBudgets.intro.desc", comment: "") }
        static var createBudgetsStep0Title: String { ls("tutorials.createBudgets.step0.title", comment: "") }
        static var createBudgetsStep0Desc: String { ls("tutorials.createBudgets.step0.desc", comment: "") }
        static var createBudgetsStep1Title: String { ls("tutorials.createBudgets.step1.title", comment: "") }
        static var createBudgetsStep1Desc: String { ls("tutorials.createBudgets.step1.desc", comment: "") }
        static var createBudgetsStep2Title: String { ls("tutorials.createBudgets.step2.title", comment: "") }
        static var createBudgetsStep2Desc: String { ls("tutorials.createBudgets.step2.desc", comment: "") }
        static var createBudgetsStep3Title: String { ls("tutorials.createBudgets.step3.title", comment: "") }
        static var createBudgetsStep3Desc: String { ls("tutorials.createBudgets.step3.desc", comment: "") }
        static var createBudgetsCompletionTitle: String { ls("tutorials.createBudgets.completion.title", comment: "") }
        static var createBudgetsCompletionDesc: String { ls("tutorials.createBudgets.completion.desc", comment: "") }

        // 7. createScheduledPayments (5 steps)
        static var createScheduledPaymentsTitle: String { ls("tutorials.createScheduledPayments.title", comment: "") }
        static var createScheduledPaymentsIntroTitle: String { ls("tutorials.createScheduledPayments.intro.title", comment: "") }
        static var createScheduledPaymentsIntroDesc: String { ls("tutorials.createScheduledPayments.intro.desc", comment: "") }
        static var createScheduledPaymentsStep0Title: String { ls("tutorials.createScheduledPayments.step0.title", comment: "") }
        static var createScheduledPaymentsStep0Desc: String { ls("tutorials.createScheduledPayments.step0.desc", comment: "") }
        static var createScheduledPaymentsStep1Title: String { ls("tutorials.createScheduledPayments.step1.title", comment: "") }
        static var createScheduledPaymentsStep1Desc: String { ls("tutorials.createScheduledPayments.step1.desc", comment: "") }
        static var createScheduledPaymentsStep2Title: String { ls("tutorials.createScheduledPayments.step2.title", comment: "") }
        static var createScheduledPaymentsStep2Desc: String { ls("tutorials.createScheduledPayments.step2.desc", comment: "") }
        static var createScheduledPaymentsStep3Title: String { ls("tutorials.createScheduledPayments.step3.title", comment: "") }
        static var createScheduledPaymentsStep3Desc: String { ls("tutorials.createScheduledPayments.step3.desc", comment: "") }
        static var createScheduledPaymentsStep4Title: String { ls("tutorials.createScheduledPayments.step4.title", comment: "") }
        static var createScheduledPaymentsStep4Desc: String { ls("tutorials.createScheduledPayments.step4.desc", comment: "") }
        static var createScheduledPaymentsCompletionTitle: String { ls("tutorials.createScheduledPayments.completion.title", comment: "") }
        static var createScheduledPaymentsCompletionDesc: String { ls("tutorials.createScheduledPayments.completion.desc", comment: "") }

        // 8. createFavorites (2 steps)
        static var createFavoritesTitle: String { ls("tutorials.createFavorites.title", comment: "") }
        static var createFavoritesIntroTitle: String { ls("tutorials.createFavorites.intro.title", comment: "") }
        static var createFavoritesIntroDesc: String { ls("tutorials.createFavorites.intro.desc", comment: "") }
        static var createFavoritesStep0Title: String { ls("tutorials.createFavorites.step0.title", comment: "") }
        static var createFavoritesStep0Desc: String { ls("tutorials.createFavorites.step0.desc", comment: "") }
        static var createFavoritesStep1Title: String { ls("tutorials.createFavorites.step1.title", comment: "") }
        static var createFavoritesStep1Desc: String { ls("tutorials.createFavorites.step1.desc", comment: "") }
        static var createFavoritesCompletionTitle: String { ls("tutorials.createFavorites.completion.title", comment: "") }
        static var createFavoritesCompletionDesc: String { ls("tutorials.createFavorites.completion.desc", comment: "") }

        // 9. editPanel (3 steps)
        static var editPanelTitle: String { ls("tutorials.editPanel.title", comment: "") }
        static var editPanelIntroTitle: String { ls("tutorials.editPanel.intro.title", comment: "") }
        static var editPanelIntroDesc: String { ls("tutorials.editPanel.intro.desc", comment: "") }
        static var editPanelStep0Title: String { ls("tutorials.editPanel.step0.title", comment: "") }
        static var editPanelStep0Desc: String { ls("tutorials.editPanel.step0.desc", comment: "") }
        static var editPanelStep1Title: String { ls("tutorials.editPanel.step1.title", comment: "") }
        static var editPanelStep1Desc: String { ls("tutorials.editPanel.step1.desc", comment: "") }
        static var editPanelStep2Title: String { ls("tutorials.editPanel.step2.title", comment: "") }
        static var editPanelStep2Desc: String { ls("tutorials.editPanel.step2.desc", comment: "") }
        static var editPanelCompletionTitle: String { ls("tutorials.editPanel.completion.title", comment: "") }
        static var editPanelCompletionDesc: String { ls("tutorials.editPanel.completion.desc", comment: "") }

        // 10. panelFiltering (5 steps)
        static var panelFilteringTitle: String { ls("tutorials.panelFiltering.title", comment: "") }
        static var panelFilteringIntroTitle: String { ls("tutorials.panelFiltering.intro.title", comment: "") }
        static var panelFilteringIntroDesc: String { ls("tutorials.panelFiltering.intro.desc", comment: "") }
        static var panelFilteringStep0Title: String { ls("tutorials.panelFiltering.step0.title", comment: "") }
        static var panelFilteringStep0Desc: String { ls("tutorials.panelFiltering.step0.desc", comment: "") }
        static var panelFilteringStep1Title: String { ls("tutorials.panelFiltering.step1.title", comment: "") }
        static var panelFilteringStep1Desc: String { ls("tutorials.panelFiltering.step1.desc", comment: "") }
        static var panelFilteringStep2Title: String { ls("tutorials.panelFiltering.step2.title", comment: "") }
        static var panelFilteringStep2Desc: String { ls("tutorials.panelFiltering.step2.desc", comment: "") }
        static var panelFilteringStep3Title: String { ls("tutorials.panelFiltering.step3.title", comment: "") }
        static var panelFilteringStep3Desc: String { ls("tutorials.panelFiltering.step3.desc", comment: "") }
        static var panelFilteringStep4Title: String { ls("tutorials.panelFiltering.step4.title", comment: "") }
        static var panelFilteringStep4Desc: String { ls("tutorials.panelFiltering.step4.desc", comment: "") }
        static var panelFilteringCompletionTitle: String { ls("tutorials.panelFiltering.completion.title", comment: "") }
        static var panelFilteringCompletionDesc: String { ls("tutorials.panelFiltering.completion.desc", comment: "") }

        // 11. inboxApproval (4 steps)
        static var inboxApprovalTitle: String { ls("tutorials.inboxApproval.title", comment: "") }
        static var inboxApprovalIntroTitle: String { ls("tutorials.inboxApproval.intro.title", comment: "") }
        static var inboxApprovalIntroDesc: String { ls("tutorials.inboxApproval.intro.desc", comment: "") }
        static var inboxApprovalStep0Title: String { ls("tutorials.inboxApproval.step0.title", comment: "") }
        static var inboxApprovalStep0Desc: String { ls("tutorials.inboxApproval.step0.desc", comment: "") }
        static var inboxApprovalStep1Title: String { ls("tutorials.inboxApproval.step1.title", comment: "") }
        static var inboxApprovalStep1Desc: String { ls("tutorials.inboxApproval.step1.desc", comment: "") }
        static var inboxApprovalStep2Title: String { ls("tutorials.inboxApproval.step2.title", comment: "") }
        static var inboxApprovalStep2Desc: String { ls("tutorials.inboxApproval.step2.desc", comment: "") }
        static var inboxApprovalStep3Title: String { ls("tutorials.inboxApproval.step3.title", comment: "") }
        static var inboxApprovalStep3Desc: String { ls("tutorials.inboxApproval.step3.desc", comment: "") }
        static var inboxApprovalCompletionTitle: String { ls("tutorials.inboxApproval.completion.title", comment: "") }
        static var inboxApprovalCompletionDesc: String { ls("tutorials.inboxApproval.completion.desc", comment: "") }

        // 12. applePay (4 steps)
        static var applePayTitle: String { ls("tutorials.applePay.title", comment: "") }
        static var applePayIntroTitle: String { ls("tutorials.applePay.intro.title", comment: "") }
        static var applePayIntroDesc: String { ls("tutorials.applePay.intro.desc", comment: "") }
        static var applePayStep0Title: String { ls("tutorials.applePay.step0.title", comment: "") }
        static var applePayStep0Desc: String { ls("tutorials.applePay.step0.desc", comment: "") }
        static var applePayStep1Title: String { ls("tutorials.applePay.step1.title", comment: "") }
        static var applePayStep1Desc: String { ls("tutorials.applePay.step1.desc", comment: "") }
        static var applePayStep2Title: String { ls("tutorials.applePay.step2.title", comment: "") }
        static var applePayStep2Desc: String { ls("tutorials.applePay.step2.desc", comment: "") }
        static var applePayStep3Title: String { ls("tutorials.applePay.step3.title", comment: "") }
        static var applePayStep3Desc: String { ls("tutorials.applePay.step3.desc", comment: "") }
        static var applePayCompletionTitle: String { ls("tutorials.applePay.completion.title", comment: "") }
        static var applePayCompletionDesc: String { ls("tutorials.applePay.completion.desc", comment: "") }
    }

    enum FAQ {
        static var subtitle: String { ls("faq.subtitle", comment: "") }
        static var sectionGeneral: String { ls("faq.section.general", comment: "") }
        static var sectionData: String { ls("faq.section.data", comment: "") }
        static var sectionPro: String { ls("faq.section.pro", comment: "") }
        static var whatIsYalaQ: String { ls("faq.whatIsYala.q", comment: "") }
        static var whatIsYalaA: String { ls("faq.whatIsYala.a", comment: "") }
        static var howToRecordQ: String { ls("faq.howToRecord.q", comment: "") }
        static var howToRecordA: String { ls("faq.howToRecord.a", comment: "") }
        static var multiCurrencyQ: String { ls("faq.multiCurrency.q", comment: "") }
        static var multiCurrencyA: String { ls("faq.multiCurrency.a", comment: "") }
        static var changeCategoryQ: String { ls("faq.changeCategory.q", comment: "") }
        static var changeCategoryA: String { ls("faq.changeCategory.a", comment: "") }
        static var importDataQ: String { ls("faq.importData.q", comment: "") }
        static var importDataA: String { ls("faq.importData.a", comment: "") }
        static var exportDataQ: String { ls("faq.exportData.q", comment: "") }
        static var exportDataA: String { ls("faq.exportData.a", comment: "") }
        static var deleteDataQ: String { ls("faq.deleteData.q", comment: "") }
        static var deleteDataA: String { ls("faq.deleteData.a", comment: "") }
        static var whatIsProQ: String { ls("faq.whatIsPro.q", comment: "") }
        static var whatIsProA: String { ls("faq.whatIsPro.a", comment: "") }
        static var cancelSubQ: String { ls("faq.cancelSub.q", comment: "") }
        static var cancelSubA: String { ls("faq.cancelSub.a", comment: "") }
    }

    // MARK: - Notifications

    enum Notifications {
        static var title: String { ls("notifications.title", comment: "") }
        static var addNew: String { ls("notifications.addNew", comment: "") }
        static var edit: String { ls("notifications.edit", comment: "") }
        static var delete: String { ls("notifications.delete", comment: "") }
        static var deleteConfirm: String { ls("notifications.deleteConfirm", comment: "") }
        static var permissionRequired: String { ls("notifications.permissionRequired", comment: "") }
        static var permissionMessage: String { ls("notifications.permissionMessage", comment: "") }
        static var openSettings: String { ls("notifications.openSettings", comment: "") }

        // Form fields
        static var name: String { ls("notifications.name", comment: "") }
        static var namePlaceholder: String { ls("notifications.namePlaceholder", comment: "") }
        static var text: String { ls("notifications.text", comment: "") }
        static var textPlaceholder: String { ls("notifications.textPlaceholder", comment: "") }
        static var time: String { ls("notifications.time", comment: "") }
        static var active: String { ls("notifications.active", comment: "") }

        // Report data types
        static var dataBalance: String { ls("notifications.data.balance", comment: "") }
        static var dataExpenses: String { ls("notifications.data.expenses", comment: "") }
        static var dataIncome: String { ls("notifications.data.income", comment: "") }
        static var dataTopCategory: String { ls("notifications.data.topCategory", comment: "") }
        static var selectData: String { ls("notifications.selectData", comment: "") }

        // Day preferences
        static var daySunday: String { ls("notifications.day.sunday", comment: "") }
        static var dayMonday: String { ls("notifications.day.monday", comment: "") }
        static var dayLastOfMonth: String { ls("notifications.day.lastOfMonth", comment: "") }
        static var dayFirstOfMonth: String { ls("notifications.day.firstOfMonth", comment: "") }
        static var selectDay: String { ls("notifications.selectDay", comment: "") }
        static var allDays: String { ls("notifications.allDays", comment: "") }
        static var selectWeekdays: String { ls("notifications.selectWeekdays", comment: "") }

        // Default notification names (Brand Voice friendly)
        static var endOfDayName: String { ls("notifications.endOfDay.name", comment: "") }
        static var endOfDayText: String { ls("notifications.endOfDay.text", comment: "") }
        static var lunchTimeName: String { ls("notifications.lunchTime.name", comment: "") }
        static var lunchTimeText: String { ls("notifications.lunchTime.text", comment: "") }

        // Reports
        static var dailyReportName: String { ls("notifications.dailyReport.name", comment: "") }
        static var weeklyReportName: String { ls("notifications.weeklyReport.name", comment: "") }
        static var monthlyReportName: String { ls("notifications.monthlyReport.name", comment: "") }

        // Report hints (shown in list)
        static func dailyReportHint(_ time: String, _ data: String) -> String {
            String(format: ls("notifications.dailyReport.hint", comment: ""), time, data)
        }
        static func weeklyReportHint(_ data: String, _ day: String) -> String {
            String(format: ls("notifications.weeklyReport.hint", comment: ""), data, day)
        }
        static func monthlyReportHint(_ data: String, _ day: String) -> String {
            String(format: ls("notifications.monthlyReport.hint", comment: ""), data, day)
        }

        // System notifications
        static var scheduledPaymentsName: String { ls("notifications.scheduledPayments.name", comment: "") }
        static var scheduledPaymentsHint: String { ls("notifications.scheduledPayments.hint", comment: "") }
        static var announcementsName: String { ls("notifications.announcements.name", comment: "") }
        static var announcementsHint: String { ls("notifications.announcements.hint", comment: "") }

        // Empty state
        static var emptyTitle: String { ls("notifications.empty.title", comment: "") }
        static var emptyMessage: String { ls("notifications.empty.message", comment: "") }

        // Test notification
        static var testNotification: String { ls("notifications.testNotification", comment: "") }

        // Test report samples (by period)
        static var testBalanceDaily: String { ls("notifications.testReport.balance.daily", comment: "") }
        static var testBalanceWeekly: String { ls("notifications.testReport.balance.weekly", comment: "") }
        static var testBalanceMonthly: String { ls("notifications.testReport.balance.monthly", comment: "") }
        static var testExpensesDaily: String { ls("notifications.testReport.expenses.daily", comment: "") }
        static var testExpensesWeekly: String { ls("notifications.testReport.expenses.weekly", comment: "") }
        static var testExpensesMonthly: String { ls("notifications.testReport.expenses.monthly", comment: "") }
        static var testIncomeDaily: String { ls("notifications.testReport.income.daily", comment: "") }
        static var testIncomeWeekly: String { ls("notifications.testReport.income.weekly", comment: "") }
        static var testIncomeMonthly: String { ls("notifications.testReport.income.monthly", comment: "") }
        static var testTopCategoryDaily: String { ls("notifications.testReport.topCategory.daily", comment: "") }
        static var testTopCategoryWeekly: String { ls("notifications.testReport.topCategory.weekly", comment: "") }
        static var testTopCategoryMonthly: String { ls("notifications.testReport.topCategory.monthly", comment: "") }
        static var testScheduledPayment: String { ls("notifications.testReport.scheduledPayment", comment: "") }

        // Section headers
        static var sectionReminders: String { ls("notifications.section.reminders", comment: "") }
        static var sectionReports: String { ls("notifications.section.reports", comment: "") }
        static var sectionSystem: String { ls("notifications.section.system", comment: "") }
        static var sectionCustom: String { ls("notifications.section.custom", comment: "") }

        // Budget alerts
        static var budgetAlertsTitle: String { ls("notifications.budgetAlerts.title", comment: "") }
        static var budgetAlertsHint: String { ls("notifications.budgetAlerts.hint", comment: "") }

        // MARK: - Scheduled Payment Notifications (personalized)

        enum ScheduledPayment {
            /// "Hoy vence: %@ por %@" (name, amount)
            static func dueToday(_ name: String, _ amount: String) -> String {
                String(format: ls("notifications.scheduledPayment.dueToday", comment: ""), name, amount)
            }

            /// "En %d día(s) vence: %@ por %@" (days, name, amount)
            static func dueSoon(_ days: Int, _ name: String, _ amount: String) -> String {
                String(format: ls("notifications.scheduledPayment.dueSoon", comment: ""), days, name, amount)
            }

            /// "Pago vencido: %@ por %@" (name, amount)
            static func overdue(_ name: String, _ amount: String) -> String {
                String(format: ls("notifications.scheduledPayment.overdue", comment: ""), name, amount)
            }

            /// "Hoy recibes: %@ de %@" (amount, name)
            static func dueTodayIncome(_ amount: String, _ name: String) -> String {
                String(format: ls("notifications.scheduledPayment.dueToday.income", comment: ""), amount, name)
            }

            /// "En %d día(s) recibes: %@ de %@" (days, amount, name)
            static func dueSoonIncome(_ days: Int, _ amount: String, _ name: String) -> String {
                String(format: ls("notifications.scheduledPayment.dueSoon.income", comment: ""), days, amount, name)
            }

            /// "Ingreso pendiente: %@ de %@" (amount, name)
            static func overdueIncome(_ amount: String, _ name: String) -> String {
                String(format: ls("notifications.scheduledPayment.overdue.income", comment: ""), amount, name)
            }
        }

        // MARK: - Report Notifications (with real data)

        /// "Tu balance actual: %@" (amount)
        static func reportBalance(_ amount: String) -> String {
            String(format: ls("notifications.report.balance", comment: ""), amount)
        }

        /// "Gastaste: %@" (amount)
        static func reportExpenses(_ amount: String) -> String {
            String(format: ls("notifications.report.expenses", comment: ""), amount)
        }

        /// "Recibiste: %@" (amount)
        static func reportIncome(_ amount: String) -> String {
            String(format: ls("notifications.report.income", comment: ""), amount)
        }

        /// "Tu mayor gasto: %@" (category)
        static func reportTopCategory(_ category: String) -> String {
            String(format: ls("notifications.report.topCategory", comment: ""), category)
        }

        // Empty state messages
        static var emptyExpensesDaily: String { ls("notifications.report.empty.expenses.daily", comment: "") }
        static var emptyExpensesWeekly: String { ls("notifications.report.empty.expenses.weekly", comment: "") }
        static var emptyExpensesMonthly: String { ls("notifications.report.empty.expenses.monthly", comment: "") }
        static var emptyIncome: String { ls("notifications.report.empty.income", comment: "") }
        static var emptyTopCategory: String { ls("notifications.report.empty.topCategory", comment: "") }
    }

    // MARK: - Weekday

    enum Weekday {
        static var shortSunday: String { ls("weekday.short.sunday", comment: "") }
        static var shortMonday: String { ls("weekday.short.monday", comment: "") }
        static var shortTuesday: String { ls("weekday.short.tuesday", comment: "") }
        static var shortWednesday: String { ls("weekday.short.wednesday", comment: "") }
        static var shortThursday: String { ls("weekday.short.thursday", comment: "") }
        static var shortFriday: String { ls("weekday.short.friday", comment: "") }
        static var shortSaturday: String { ls("weekday.short.saturday", comment: "") }
    }

    // MARK: - iCloud Sync

    enum iCloud {
        static var title: String { ls("icloud.title", comment: "") }
        static var description: String { ls("icloud.description", comment: "") }
        static var privacyNote: String { ls("icloud.privacyNote", comment: "") }
        static var statusSynced: String { ls("icloud.statusSynced", comment: "") }
        static var statusSyncing: String { ls("icloud.statusSyncing", comment: "") }
        static var statusNoAccount: String { ls("icloud.statusNoAccount", comment: "") }
        static var statusError: String { ls("icloud.statusError", comment: "") }
        static func lastSync(_ time: String) -> String {
            String(format: ls("icloud.lastSync", comment: ""), time)
        }
        static var noAccountWarning: String { ls("icloud.noAccountWarning", comment: "") }
        static var syncingData: String { ls("icloud.syncingData", comment: "") }
        static var syncingDescription: String { ls("icloud.syncingDescription", comment: "") }
        static var syncingSkip: String { ls("icloud.syncing.skip", comment: "") }
        static var dataFoundTitle: String { ls("icloud.dataFoundTitle", comment: "") }
        static var dataFoundMessage: String { ls("icloud.dataFoundMessage", comment: "") }
        static var dataFoundAction: String { ls("icloud.dataFoundAction", comment: "") }
        static var syncingBanner: String { ls("icloud.syncingBanner", comment: "") }
        static var remoteWipeTitle: String { ls("icloud.remoteWipe.title", comment: "") }
        static var remoteWipeMessage: String { ls("icloud.remoteWipe.message", comment: "") }
        static var remoteWipeConfirm: String { ls("icloud.remoteWipe.confirm", comment: "") }
        static var remoteWipeCancel: String { ls("icloud.remoteWipe.cancel", comment: "") }
    }

    // MARK: - Shortcut Notifications

    enum Shortcut {
        enum Notification {
            static var title: String { ls("shortcut.notification.title", comment: "") }
            static var expense: String { ls("shortcut.notification.expense", comment: "") }
            static var income: String { ls("shortcut.notification.income", comment: "") }
            static func body(_ type: String, _ amount: String, _ note: String) -> String {
                String(format: ls("shortcut.notification.body", comment: ""), type, amount, note)
            }
        }
    }

    // MARK: - Tips

    enum Tips {
        static var subtitle: String { ls("tips.subtitle", comment: "") }

        enum Section {
            static var quickEntry: String { ls("tips.section.quickEntry", comment: "") }
            static var organize: String { ls("tips.section.organize", comment: "") }
            static var advanced: String { ls("tips.section.advanced", comment: "") }
        }

        enum Voice {
            static var title: String { ls("tips.voice.title", comment: "") }
            static var detail: String { ls("tips.voice.detail", comment: "") }
        }

        enum Camera {
            static var title: String { ls("tips.camera.title", comment: "") }
            static var detail: String { ls("tips.camera.detail", comment: "") }
        }

        enum Favorites {
            static var title: String { ls("tips.favorites.title", comment: "") }
            static var detail: String { ls("tips.favorites.detail", comment: "") }
        }

        enum Budgets {
            static var title: String { ls("tips.budgets.title", comment: "") }
            static var detail: String { ls("tips.budgets.detail", comment: "") }
        }

        enum Tags {
            static var title: String { ls("tips.tags.title", comment: "") }
            static var detail: String { ls("tips.tags.detail", comment: "") }
        }

        enum Filters {
            static var title: String { ls("tips.filters.title", comment: "") }
            static var detail: String { ls("tips.filters.detail", comment: "") }
        }

        enum Export {
            static var title: String { ls("tips.export.title", comment: "") }
            static var detail: String { ls("tips.export.detail", comment: "") }
        }

        enum FaceID {
            static var title: String { ls("tips.faceID.title", comment: "") }
            static var detail: String { ls("tips.faceID.detail", comment: "") }
        }

        enum Siri {
            static var title: String { ls("tips.siri.title", comment: "") }
            static var detail: String { ls("tips.siri.detail", comment: "") }
            static var close: String { ls("tips.siri.close", comment: "") }
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
    /// Respects language override if set, otherwise uses system locale.
    static var current: Locale {
        // User override takes priority
        if let override = LanguageManager.overrideLanguage {
            return Locale(identifier: override)
        }
        // System locale
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
