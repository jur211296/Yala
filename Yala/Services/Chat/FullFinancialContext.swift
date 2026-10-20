//
//  FullFinancialContext.swift
//  Yala
//
//  Single struct serializable to JSON con TODA la data financiera relevante del
//  user. Se inyecta en el system prompt de Yala IA en cada llamada (Opción B
//  context-rich). El LLM responde directo sin function calling.
//
//  Keys del JSON en inglés (los LLMs procesan keys EN universalmente). Valores
//  localizados (nombres reales: "Mercado", "Restaurantes").
//

import Foundation

struct FullFinancialContext: Codable, Equatable {
    let metadata: Metadata
    let balances: BalancesSection
    let periods: PeriodsSection
    let categories: [CategoryEntry]
    let uncategorized: UncategorizedBucket
    let merchantsTop20: [MerchantEntry]
    let budgets: [BudgetEntry]
    let recurring: RecurringSection
    let patterns: PatternsSection
    let tagsTop10: [TagEntry]
    let topTxBySubcategory: [SubcategoryTxEntry]
    let anomalies: [AnomalyEntry]?
    /// Los 12 meses cerrados antes del mes en curso, del más reciente al más antiguo (revisión del 2026-10-20). Con el
    /// mes en curso de `periods` son los «últimos 13 meses» que promete el aviso del chat; hasta ese día el modelo solo
    /// veía cuatro y contestaba «no tengo datos de mayo».
    var monthlyHistory: [MonthSummary] = []
    /// Ingresos por categoría y subcategoría: `categories` es solo de gastos, y «¿cuánto me pagaron por freelance?» no
    /// tenía respuesta.
    var incomeCategories: [IncomeCategoryEntry] = []
    /// La tasa más reciente de cada divisa de las cuentas a la principal, para convertir lo que pregunten.
    var fxRates: [FxRateEntry] = []
    /// El mes más caro, el más barato y las medias de `monthlyHistory`: el banco midió que, leyendo 12 filas, el modelo
    /// se saltaba diciembre y daba marzo como el mes más caro.
    var monthlyHistorySummary: MonthlyHistorySummary? = nil
    /// Lo que queda del mes, ya sumado: días, lo que queda de los presupuestos y lo programado hasta fin de mes. El
    /// banco midió que el modelo sumaba mal cuatro presupuestos para «¿cuánto puedo gastar por día?».
    var monthOutlook: MonthOutlook? = nil

    enum CodingKeys: String, CodingKey {
        case metadata, balances, periods, categories, uncategorized
        case merchantsTop20 = "merchants_top_20"
        case budgets, recurring, patterns
        case tagsTop10 = "tags_top_10"
        case topTxBySubcategory = "top_tx_by_subcategory"
        case anomalies
        case monthlyHistory = "monthly_history"
        case incomeCategories = "income_categories"
        case fxRates = "fx_rates"
        case monthlyHistorySummary = "monthly_history_summary"
        case monthOutlook = "month_outlook"
    }

    /// Serialize to compact JSON for system prompt injection.
    ///
    /// Lanza en vez de devolver `{}`: con un objeto vacío el modelo contestaba con seguridad que no había datos
    /// (ticket `chat-context-encoding-failure-is-silent`).
    func toJSONString() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(self)
        guard let str = String(data: data, encoding: .utf8) else {
            throw EncodingError.invalidValue(self, .init(codingPath: [], debugDescription: "JSON no es UTF-8"))
        }
        return str
    }
}

// MARK: - Metadata

extension FullFinancialContext {

    struct Metadata: Codable, Equatable {
        let dateToday: String       // ISO yyyy-MM-dd
        let weekday: String         // "Sunday" .. "Saturday"
        let monthLabel: String      // e.g., "April 2026"
        let currency: String        // "USD"
        let currencyDisplay: String // "$" or "USD"
        let language: String        // "es", "en", etc.
        let country: String         // "PE", "US", etc.
        let excludedAccounts: [String] // Names of accounts excluded from aggregates
        /// Qué mes (AAAA-MM) es cada período mensual de `periods` y de los `total_*` de categorías: el banco midió que
        /// «hace tres meses» se leía como `two_months_ago`.
        var periodMonths: [String: String]? = nil

        enum CodingKeys: String, CodingKey {
            case periodMonths = "period_months"
            case dateToday = "date_today"
            case weekday
            case monthLabel = "month_label"
            case currency
            case currencyDisplay = "currency_display"
            case language, country
            case excludedAccounts = "excluded_accounts"
        }
    }
}

// MARK: - Balances

extension FullFinancialContext {

    struct BalancesSection: Codable, Equatable {
        let accounts: [AccountEntry]
        let totalBalance: Double
        /// Si `totalBalance` suma las cuentas de Grupos (`type == "system"`), igual que el total del Panel con
        /// «Grupos en el total» (`includeGroupsInPanelTotal`). Esas cuentas salen en `accounts` en los dos casos.
        let totalIncludesGroups: Bool

        enum CodingKeys: String, CodingKey {
            case accounts
            case totalBalance = "total_balance"
            case totalIncludesGroups = "total_includes_groups"
        }
    }

    /// Una cuenta. Si es una tarjeta con varias divisas (entrega 4), `balance` y `currency` son los de su principal,
    /// `lines` trae las demás divisas y `card_total` lo suma todo en la divisa preferida. En una cuenta sin líneas los
    /// tres campos nuevos no se escriben y el JSON es el de siempre.
    struct AccountEntry: Codable, Equatable {
        let name: String
        let type: String
        let balance: Double
        let currency: String
        var lines: [LineEntry]? = nil
        /// Principal y líneas convertidas a la divisa preferida con la tasa más reciente: un total aproximado.
        var cardTotal: Double? = nil
        var cardTotalIsApproximate: Bool? = nil
        /// Una cuenta sin líneas en otra divisa: su saldo en la divisa principal con la tasa más reciente. Sin él, «¿cuánto
        /// vale en soles lo que tengo en dólares?» acababa en «no tengo la tasa».
        var balanceInMainCurrency: Double? = nil
        var balanceInMainCurrencyIsApproximate: Bool? = nil

        enum CodingKeys: String, CodingKey {
            case name, type, balance, currency, lines
            case cardTotal = "card_total"
            case cardTotalIsApproximate = "card_total_is_approximate"
            case balanceInMainCurrency = "balance_in_main_currency"
            case balanceInMainCurrencyIsApproximate = "balance_in_main_currency_is_approximate"
        }
    }

    /// Una línea de una tarjeta: su saldo en su divisa.
    struct LineEntry: Codable, Equatable {
        let name: String
        let balance: Double
        let currency: String
    }
}

// MARK: - Periods

extension FullFinancialContext {

    struct PeriodsSection: Codable, Equatable {
        let today: PeriodSummary
        let currentWeek: PeriodSummary
        let lastWeek: PeriodSummary
        let last4Weeks: [WeekSummary]
        let currentMonth: PeriodSummary
        /// El mes pasado ENTERO: para «¿cuánto gasté el mes pasado?».
        let lastMonth: PeriodSummary
        /// El mes pasado hasta el día equivalente a hoy: lo que se compara con `currentMonth`
        /// mientras el mes está en curso. Sin él, a mitad de mes el chat comparaba lo que va del mes
        /// con el mes pasado entero y respondía «gastas menos» (banco de `chat.answer`, 2026-10-07).
        let lastMonthToDate: PeriodSummary
        let twoMonthsAgo: PeriodSummary
        let threeMonthsAgo: PeriodSummary
        let currentYear: PeriodSummary
        /// Ayer entero (revisión del 2026-10-20): «¿cuánto gasté ayer?» se contestaba sumando a ojo.
        var yesterday: PeriodSummary? = nil
        /// El mismo mes del año pasado, ENTERO: el banco midió que, buscándolo en `monthly_history`, el modelo decía que
        /// no lo tenía.
        var sameMonthLastYear: PeriodSummary? = nil

        enum CodingKeys: String, CodingKey {
            case today
            case currentWeek = "current_week"
            case lastWeek = "last_week"
            case last4Weeks = "last_4_weeks"
            case currentMonth = "current_month"
            case lastMonth = "last_month"
            case lastMonthToDate = "last_month_to_date"
            case twoMonthsAgo = "two_months_ago"
            case threeMonthsAgo = "three_months_ago"
            case currentYear = "current_year"
            case yesterday
            case sameMonthLastYear = "same_month_last_year"
        }
    }

    struct PeriodSummary: Codable, Equatable {
        let income: Double
        let expense: Double
        let balance: Double
        let txCount: Int
        let dailyAvg: Double
        let savingsRatePercent: Double?  // null if income == 0

        /// La misma señal de «aproximado» que las pantallas pintan con «≈», aquí en **booleano y no
        /// en glifo**.
        ///
        /// El destino de esta struct es el system prompt del modelo, no la pantalla: los tres
        /// importes de arriba son `Double` justamente para que el modelo pueda sumar y comparar sin
        /// parsear texto, y meterles un «≈ 1234» los convertiría en `String`. Un booleano hermano
        /// dice lo mismo sin romper eso. Va **por lado** por el motivo de siempre: `expense` y
        /// `income` se preguntan por separado.
        let incomeIsApproximate: Bool
        let expenseIsApproximate: Bool
        let balanceIsApproximate: Bool

        enum CodingKeys: String, CodingKey {
            case income, expense, balance
            case txCount = "tx_count"
            case dailyAvg = "daily_avg"
            case savingsRatePercent = "savings_rate_percent"
            case incomeIsApproximate = "income_is_approximate"
            case expenseIsApproximate = "expense_is_approximate"
            case balanceIsApproximate = "balance_is_approximate"
        }
    }

    struct WeekSummary: Codable, Equatable {
        let weekStart: String   // ISO yyyy-MM-dd
        let income: Double
        let expense: Double
        let incomeIsApproximate: Bool
        let expenseIsApproximate: Bool

        enum CodingKeys: String, CodingKey {
            case weekStart = "week_start"
            case income, expense
            case incomeIsApproximate = "income_is_approximate"
            case expenseIsApproximate = "expense_is_approximate"
        }
    }
}

// MARK: - Categories

extension FullFinancialContext {

    struct CategoryEntry: Codable, Equatable {
        let name: String
        let totalCurrentMonth: Double
        let totalLastMonth: Double              // el mes pasado entero
        let totalLastMonthToDate: Double        // el mes pasado hasta el día equivalente a hoy
        let totalTwoMonthsAgo: Double
        let variationPercentVsLastMonthToDate: Double?  // contra `totalLastMonthToDate`; null si fue 0
        let txCountCurrentMonth: Int
        let subcategories: [SubcategoryEntry]
        /// Lo que va del año (revisión del 2026-10-20): «¿cuánto gasté en supermercado este año?».
        var totalCurrentYear: Double = 0

        enum CodingKeys: String, CodingKey {
            case name
            case totalCurrentMonth = "total_current_month"
            case totalLastMonth = "total_last_month"
            case totalLastMonthToDate = "total_last_month_to_date"
            case totalTwoMonthsAgo = "total_two_months_ago"
            case variationPercentVsLastMonthToDate = "variation_percent_vs_last_month_to_date"
            case txCountCurrentMonth = "tx_count_current_month"
            case subcategories
            case totalCurrentYear = "total_current_year"
        }
    }

    struct SubcategoryEntry: Codable, Equatable {
        let name: String
        let totalCurrentMonth: Double
        let totalLastMonth: Double
        let totalLastMonthToDate: Double
        let totalTwoMonthsAgo: Double
        let variationPercentVsLastMonthToDate: Double?
        let txCountCurrentMonth: Int
        var totalCurrentYear: Double = 0

        enum CodingKeys: String, CodingKey {
            case name
            case totalCurrentMonth = "total_current_month"
            case totalLastMonth = "total_last_month"
            case totalLastMonthToDate = "total_last_month_to_date"
            case totalTwoMonthsAgo = "total_two_months_ago"
            case variationPercentVsLastMonthToDate = "variation_percent_vs_last_month_to_date"
            case txCountCurrentMonth = "tx_count_current_month"
            case totalCurrentYear = "total_current_year"
        }
    }

    /// Un mes cerrado de `monthly_history`: totales y lo que más pesó.
    struct MonthSummary: Codable, Equatable {
        let month: String        // yyyy-MM
        let income: Double
        let expense: Double
        let balance: Double      // ingresos − gastos del mes
        /// Solo cuando es `true` (con `false` la clave no se escribe: son 12 meses y casi siempre es `false`).
        let incomeIsApproximate: Bool?
        let expenseIsApproximate: Bool?
        let topExpenseCategories: [NamedTotal]
        let topExpenseSubcategories: [NamedTotal]
        let topIncomeSubcategories: [NamedTotal]

        enum CodingKeys: String, CodingKey {
            case month, income, expense, balance
            case incomeIsApproximate = "income_is_approximate"
            case expenseIsApproximate = "expense_is_approximate"
            case topExpenseCategories = "top_categories"
            case topExpenseSubcategories = "top_subcategories"
            case topIncomeSubcategories = "top_income"
        }
    }

    struct MonthlyHistorySummary: Codable, Equatable {
        let highestExpenseMonth: String
        let highestExpense: Double
        let lowestExpenseMonth: String
        let lowestExpense: Double
        let averageExpense: Double
        let averageIncome: Double
        let averageBalance: Double
        /// Totales por año natural de los meses de la historia (con el mes en curso): un año a medias dice cuántos meses
        /// trae. El banco midió dos sumas distintas de octubre a diciembre de 2025 en dos corridas.
        var byYear: [YearTotal] = []

        enum CodingKeys: String, CodingKey {
            case byYear = "by_year"
            case highestExpenseMonth = "highest_expense_month"
            case highestExpense = "highest_expense"
            case lowestExpenseMonth = "lowest_expense_month"
            case lowestExpense = "lowest_expense"
            case averageExpense = "average_expense"
            case averageIncome = "average_income"
            case averageBalance = "average_balance"
        }
    }

    struct YearTotal: Codable, Equatable {
        let year: String
        let months: Int
        let income: Double
        let expense: Double
    }

    struct MonthOutlook: Codable, Equatable {
        /// Días que quedan del mes contando hoy.
        let daysLeft: Int
        /// Lo que queda de los presupuestos MENSUALES activos en la divisa principal (`limit − spent`, sin negativos).
        let budgetsRemaining: Double
        /// Pagos e ingresos programados que aún tocan este mes (después de hoy).
        let pendingPaymentsUntilMonthEnd: Double
        let pendingIncomeUntilMonthEnd: Double

        enum CodingKeys: String, CodingKey {
            case daysLeft = "days_left"
            case budgetsRemaining = "all_budgets_remaining"
            case pendingPaymentsUntilMonthEnd = "pending_payments_until_month_end"
            case pendingIncomeUntilMonthEnd = "pending_income_until_month_end"
        }
    }

    /// Un nombre de categoría o subcategoría con su total (y la categoría madre si es una subcategoría).
    struct NamedTotal: Codable, Equatable {
        let name: String
        var category: String? = nil
        let total: Double
    }

    /// Una categoría de ingresos con sus subcategorías.
    struct IncomeCategoryEntry: Codable, Equatable {
        let name: String
        let totalCurrentMonth: Double
        let totalLastMonth: Double
        let totalCurrentYear: Double
        let subcategories: [IncomeSubcategoryEntry]

        enum CodingKeys: String, CodingKey {
            case name
            case totalCurrentMonth = "total_current_month"
            case totalLastMonth = "total_last_month"
            case totalCurrentYear = "total_current_year"
            case subcategories
        }
    }

    struct IncomeSubcategoryEntry: Codable, Equatable {
        let name: String
        let totalCurrentMonth: Double
        let totalLastMonth: Double
        let totalCurrentYear: Double

        enum CodingKeys: String, CodingKey {
            case name
            case totalCurrentMonth = "total_current_month"
            case totalLastMonth = "total_last_month"
            case totalCurrentYear = "total_current_year"
        }
    }

    /// Cuánto vale 1 unidad de `currency` en la divisa principal, con la tasa más reciente.
    struct FxRateEntry: Codable, Equatable {
        let currency: String
        let rateToMainCurrency: Double
        let isApproximate: Bool

        enum CodingKeys: String, CodingKey {
            case currency
            case rateToMainCurrency = "rate_to_main_currency"
            case isApproximate = "is_approximate"
        }
    }

    /// Bucket explícito para tx con `category == nil` — se mantienen visibles al LLM.
    struct UncategorizedBucket: Codable, Equatable {
        let totalCurrentMonth: Double
        let txCountCurrentMonth: Int

        enum CodingKeys: String, CodingKey {
            case totalCurrentMonth = "total_current_month"
            case txCountCurrentMonth = "tx_count_current_month"
        }
    }
}

// MARK: - Merchants

extension FullFinancialContext {

    struct MerchantEntry: Codable, Equatable {
        let name: String       // canonicalized
        let totalCurrentMonth: Double
        let totalLastMonth: Double
        let totalLastMonthToDate: Double
        let txCount: Int
        let avgAmount: Double
        let variationPercentVsLastMonthToDate: Double?

        enum CodingKeys: String, CodingKey {
            case name
            case totalCurrentMonth = "total_current_month"
            case totalLastMonth = "total_last_month"
            case totalLastMonthToDate = "total_last_month_to_date"
            case txCount = "tx_count"
            case avgAmount = "avg_amount"
            case variationPercentVsLastMonthToDate = "variation_percent_vs_last_month_to_date"
        }
    }
}

// MARK: - Budgets

extension FullFinancialContext {

    struct BudgetEntry: Codable, Equatable {
        let name: String
        let category: String?
        let limit: Double
        let spent: Double
        let usagePercent: Double?      // null if limit == 0
        let daysLeft: Int
        let status: BudgetStatus
        let periodType: String         // "monthly" | "weekly" | "yearly" | "unique"
        let currency: String

        enum CodingKeys: String, CodingKey {
            case name, category, limit, spent
            case usagePercent = "usage_percent"
            case daysLeft = "days_left"
            case status
            case periodType = "period_type"
            case currency
        }
    }

    enum BudgetStatus: String, Codable, Equatable {
        case onTrack = "on_track"
        case atRisk = "at_risk"
        case exceeded
        case noLimit = "no_limit"
    }
}

// MARK: - Recurring

extension FullFinancialContext {

    struct RecurringSection: Codable, Equatable {
        let paidThisMonth: [RecurringPaidEntry]
        let pendingNext30Days: [RecurringPendingEntry]
        let totals: RecurringTotals
        /// Todos los pagos programados activos con su próxima fecha (revisión del 2026-10-20): «¿qué suscripciones
        /// pago?» solo veía lo cobrado este mes y lo de los próximos 30 días.
        var active: [RecurringActiveEntry] = []

        enum CodingKeys: String, CodingKey {
            case paidThisMonth = "paid_this_month"
            case pendingNext30Days = "pending_next_30_days"
            case totals
            case active
        }
    }

    struct RecurringActiveEntry: Codable, Equatable {
        let name: String
        let amount: Double           // en la divisa principal
        let isIncome: Bool
        let type: String             // "subscription" | "recurring" | "one_time"
        let frequency: String        // "daily" | "weekly" | "monthly" | "yearly" | "once"
        let every: Int?              // cada cuántos períodos; sin la clave, cada uno
        let nextDate: String?        // ISO yyyy-MM-dd
        let subcategory: String?

        enum CodingKeys: String, CodingKey {
            case name, amount
            case isIncome = "is_income"
            case type, frequency, every
            case nextDate = "next_date"
            case subcategory
        }
    }

    struct RecurringPaidEntry: Codable, Equatable {
        let name: String
        let amount: Double
        let date: String   // ISO yyyy-MM-dd
        let category: String?
        let subcategory: String?
    }

    struct RecurringPendingEntry: Codable, Equatable {
        let name: String
        let amount: Double
        let dueDate: String  // ISO yyyy-MM-dd
        let category: String?
        let subcategory: String?
        let type: String     // "subscription" | "recurring" | "one_time"
        /// Un ingreso programado (un sueldo) salía en la lista de «pagos» pendientes sin nada que lo distinguiera.
        var isIncome: Bool = false

        enum CodingKeys: String, CodingKey {
            case name, amount
            case dueDate = "due_date"
            case category, subcategory, type
            case isIncome = "is_income"
        }
    }

    struct RecurringTotals: Codable, Equatable {
        let subscriptionsMonthly: Double
        let recurringMonthly: Double

        enum CodingKeys: String, CodingKey {
            case subscriptionsMonthly = "subscriptions_monthly"
            case recurringMonthly = "recurring_monthly"
        }
    }
}

// MARK: - Patterns

extension FullFinancialContext {

    struct PatternsSection: Codable, Equatable {
        let weekdayPattern30Days: [WeekdayEntry]
        let needsBreakdownCurrentMonth: NeedsBreakdownEntry

        enum CodingKeys: String, CodingKey {
            case weekdayPattern30Days = "weekday_pattern_30_days"
            case needsBreakdownCurrentMonth = "needs_breakdown_current_month"
        }
    }

    /// Weekday pattern entry — incluye `sampleSize` (count de tx) Y `dayOccurrences`
    /// (cuántos `<weekday>` hay en el periodo) para que el LLM pueda razonar sobre
    /// representatividad. Resuelve bug #2 (caso "domingo S/3400" dominado por 1-2 tx).
    struct WeekdayEntry: Codable, Equatable {
        let weekday: String      // "Sunday" .. "Saturday"
        let total: Double
        let avgPerDay: Double    // total / dayOccurrences
        let sampleSize: Int      // count de tx (== `count` del calculator)
        let dayOccurrences: Int  // cuántas veces aparece este weekday en los 30d

        enum CodingKeys: String, CodingKey {
            case weekday, total
            case avgPerDay = "avg_per_day"
            case sampleSize = "sample_size"
            case dayOccurrences = "day_occurrences"
        }
    }

    struct NeedsBreakdownEntry: Codable, Equatable {
        let essential: Double
        let priority: Double
        let optional: Double
        let unclassified: Double
        let total: Double
    }
}

// MARK: - Tags

extension FullFinancialContext {

    struct TagEntry: Codable, Equatable {
        let name: String
        let totalCurrentMonth: Double
        let txCount: Int

        enum CodingKeys: String, CodingKey {
            case name
            case totalCurrentMonth = "total_current_month"
            case txCount = "tx_count"
        }
    }
}

// MARK: - Top transactions per subcategory

extension FullFinancialContext {

    struct SubcategoryTxEntry: Codable, Equatable {
        let subcategoryName: String
        let categoryName: String
        let transactions: [TxLite]

        enum CodingKeys: String, CodingKey {
            case subcategoryName = "subcategory_name"
            case categoryName = "category_name"
            case transactions
        }
    }

    struct TxLite: Codable, Equatable {
        let date: String      // ISO yyyy-MM-dd
        let amount: Double
        let merchant: String? // canonicalized
        let account: String?
    }
}
