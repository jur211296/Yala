import Foundation
import SwiftData
import SwiftUI

// MARK: - Widget Data Structs
// Equatable value types that collapse many @Observable tracking points into one per widget.
// SwiftUI observes the struct (1 observer) instead of N individual properties.

struct PanelTrendData: Equatable {
    var processedTrendPoints: [BarPoint] = []
    var rawTrendPoints: [BarPoint] = []
    var processedYDomain: ClosedRange<Double> = 0...100
    var currentInterval: DateInterval = DateInterval(start: .distantPast, end: .distantPast)
    var currentPeriod: DetailPeriod = .thisYear
    var trendTotalIncome: Double = 0
    var trendTotalExpense: Double = 0
    var trendFinalBalance: Double = 0
    var trendGrouping: TrendGrouping = .day
    var dataTrendType: TrendType = .balance
    var currentBalance: Double = 0
}

struct PanelCategoriesData: Equatable {
    var topSpendingCategories: [CategorySpendingSummary] = []
    var previousTotalAmount: Double? = nil
}

struct PanelSubcategoriesData: Equatable {
    var topSubcategories: [SubcategorySpendingSummary] = []
    var previousTotalAmount: Double? = nil
}

struct PanelNeedData: Equatable {
    var needTrendPoints: [NeedTrendPoint] = []
    var previousTotalAmount: Double? = nil
    var previousAmounts: [SubcategoryNeed: Double] = [:]
    var needGrouping: TrendGrouping = .day
}

struct PanelCashFlowData: Equatable {
    var cashFlowSummary: CashFlowSummary? = nil
    var cashFlowGrouping: TrendGrouping = .day
}

struct PanelBudgetsData: Equatable {
    var topBudgetSummaries: [BudgetSummary] = []
    var hasBudgetsButNoFavorites: Bool = false
}

struct PanelExchangeRateData: Equatable {
    var exchangeRateWidgetData: ExchangeRateWidgetData? = nil
    var exchangeRateGrouping: TrendGrouping = .day
}

struct ScheduledPaymentListItem: Equatable, Identifiable {
    let id: String
    let name: String
    let amount: Double
    let currencyCode: String
    let isIncome: Bool
    let isVariableAmount: Bool
    let icon: String
    let color: String
    let dueDate: Date
    let dueStatus: DueStatus
    let dueDateLabel: String
    let isPaid: Bool
    let isSkipped: Bool
}

struct ScheduledPaymentCalendarEntry: Equatable, Identifiable {
    let id: String
    let name: String
    let isPaid: Bool
    let isSkipped: Bool
}

struct PanelScheduledPaymentsData: Equatable {
    var monthlyTotal: Double = 0
    var activeCount: Int = 0
    var displayMonth: Date = .now
    var periodLabel: String = ""
    var upcomingPayments: [ScheduledPaymentListItem] = []
    var paymentsByDay: [Int: [ScheduledPaymentCalendarEntry]] = [:]
}

/// Pre-computed payload for the Panel 2.0 "Salud Financiera" section.
/// `score` stays `nil` until the first successful calculation so the view knows to hide.
struct PanelHealthData: Equatable {
    var score: FinancialScore? = nil
}

struct PanelWeekdayData: Equatable {
    var weekdaySpending: [WeekdaySpending] = []
}

/// Pre-computed payload for the TagsPie widget in the Distribución section.
struct PanelTagsData: Equatable {
    var topTags: [TagSpendingSummary] = []
    var previousTotalAmount: Double? = nil
}

/// Pre-computed payload for the period comparison page of the Trends carousel.
/// Shape mirrors the inputs of `PeriodComparisonChartView`. When
/// `supportsComparison` is false (period is `.allTime`) the view renders a
/// custom empty state instead of the chart.
struct PanelPeriodComparisonData: Equatable {
    var currentPoints: [BarPoint] = []
    var previousPoints: [BarPoint] = []
    var yDomain: ClosedRange<Double> = 0...1
    var currentInterval: DateInterval = DateInterval(start: .now, end: .now)
    var previousInterval: DateInterval = DateInterval(start: .now, end: .now)
    var grouping: TrendGrouping = .day
    var comparisonMode: ComparisonMode = .month
    var trendType: TrendType = .balance
    var period: DetailPeriod = .thisMonth
    var currentTotal: Double = 0
    var previousTotal: Double? = nil
    var supportsComparison: Bool = true

    var deltaPercent: Double? {
        guard supportsComparison, let prev = previousTotal, prev != 0 else { return nil }
        return PreviousPeriodHelper.calculateVariation(currentAmount: currentTotal, previousAmount: prev)
    }
}

/// Pre-computed payload for the Panel 2.0 Hero del mes (P20-04).
/// `data` stays `nil` until the first `calculateHeroWidget()` pass so the
/// view knows to skip rendering during the initial skeleton frame.
struct PanelHeroData: Equatable {
    var data: HeroMonthData? = nil
}

@MainActor
@Observable
final class PanelViewModel {

    // MARK: - Constants

    // MARK: - Static Formatters

    private static let dateKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    private static let monthYearFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f
    }()

    private static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        return f
    }()

    // MARK: - Dependencies

    private var modelContext: ModelContext?

    /// Exchange rate service - injected or falls back to shared singleton
    private var exchangeRateService: ExchangeRateService = .shared

    /// Currency converter - injected or falls back to shared singleton
    private var currencyConverter: CurrencyConverter = .shared

    /// Default currency code — synced from PanelView's @AppStorage
    private(set) var defaultCurrencyCode: String = CurrencyCode.pen.rawValue

    /// Session state — weak to avoid retain cycle
    private weak var sessionState: SessionState?

    /// AppPreferences SSOT for per-section widget order/hidden (P20-03).
    /// Injected by `PanelView` via `setAppPreferences(_:)` on `.task`, BEFORE
    /// `setContext(...)`. While nil (bootstrap), `isWidgetVisible(_:)` returns
    /// `true` fallback and `activeWidgets(in:)` falls back to legacy filtering.
    private var appPreferences: AppPreferences?

    // MARK: - Recalculation State

    /// Debounced recalculation task — coalesces rapid onChange cascades
    private var recalculateTask: Task<Void, Never>?

    /// Whether a pending debounced task needs to reload data from SwiftData
    private var pendingReload = false

    /// Whether the app is in background — suppresses recalculation to prevent 0x8BADF00D
    private(set) var isInBackground = false

    // MARK: - Loaded Data

    private(set) var accounts: [Account] = []
    private(set) var tags: [Tag] = []
    private(set) var categories: [Category] = []
    private(set) var allSubcategories: [Subcategory] = []
    private(set) var transactions: [TransactionItem] = []
    private(set) var budgets: [Budget] = []
    private(set) var scheduledPayments: [ScheduledPayment] = []
    private(set) var pendingDrafts: [InboxDraft] = []
    private(set) var groupGlobalSummary: GroupGlobalSummary?

    var hasGroupsWithPendingBalances: Bool {
        guard let summary = groupGlobalSummary else { return false }
        return !summary.totalOwedToMe.isEmpty || !summary.totalIOwe.isEmpty || summary.pendingSettlements > 0
    }

    // MARK: - State

    /// True after first loadData() completes. PanelView shows skeleton placeholder while false.
    private(set) var isReady: Bool = false

    /// Panel sections the user has hidden. Synced from
    /// `AppPreferences.panelSectionsHidden` via `PanelView.onChange`. Hidden
    /// sections skip their calculation and keep their cached output until the
    /// section is re-shown.
    var hiddenSections: Set<PanelSectionKind> = []

    /// Whether a Panel section currently contributes to `performCalculation`.
    /// Sections with `canBeHidden == false` always compute.
    func isSectionVisible(_ kind: PanelSectionKind) -> Bool {
        guard kind.canBeHidden else { return true }
        return !hiddenSections.contains(kind)
    }

    // MARK: - Filter Properties (SSOT: Read/Write from SessionState)

    var selectedAccountID: PersistentIdentifier? {
        get { SessionState.shared.selectedAccountIDs.first }
        set {
            SessionState.shared.selectedAccountIDs.removeAll()
            if let id = newValue { SessionState.shared.selectedAccountIDs.insert(id) }
        }
    }

    var selectedPeriod: DetailPeriod {
        get { SessionState.shared.selectedPeriod }
        set { SessionState.shared.selectedPeriod = newValue }
    }

    var customDateRange: DateInterval? {
        get { SessionState.shared.customDateRange }
        set { SessionState.shared.customDateRange = newValue }
    }

    // Widget Configuration Manager (delegated)
    let widgetConfig = WidgetConfigManager()

    // Computed property exposing the legacy JSON's widget configs (for `size` and
    // `scheduledPaymentsMode` only — order and visibility are SSOT'd in AppPreferences).
    var widgetConfigs: [WidgetConfig] {
        get { widgetConfig.configs }
        set { widgetConfig.configs = newValue }
    }

    // MARK: - Constants

    /// Minimum data points before applying moving average smoothing (avoids over-smoothing sparse data)
    private let movingAverageSmoothingThreshold = 30
    /// Window size for moving average calculation (14-day rolling average for yearly view)
    private let movingAverageWindowSize = 14

    // Note: Widget config persistence now handled by WidgetConfigManager

    // MARK: - Context Setup

    /// Sets the model context and optionally injects services.
    func setContext(
        _ context: ModelContext,
        exchangeRateService: ExchangeRateService? = nil,
        currencyConverter: CurrencyConverter? = nil,
        defaultCurrencyCode: String,
        sessionState: SessionState
    ) {
        self.modelContext = context
        if let service = exchangeRateService {
            self.exchangeRateService = service
        }
        if let converter = currencyConverter {
            self.currencyConverter = converter
        }
        self.defaultCurrencyCode = defaultCurrencyCode
        self.sessionState = sessionState
    }

    func loadData() {
        guard let context = modelContext else { return }

        // Equality checks prevent unnecessary @Observable notifications, which break the
        // loadData → onChange(of: transactions) → recalculateData → loadData feedback loop.

        var accountsDesc = FetchDescriptor<Account>(sortBy: [SortDescriptor(\.name)])
        accountsDesc.fetchLimit = 100
        do {
            let fetched = try context.fetch(accountsDesc)
            if fetched != accounts { accounts = fetched }
        } catch {
            #if DEBUG
            print("PanelViewModel: Error loading accounts: \(error)")
            #endif
        }

        var tagsDesc = FetchDescriptor<Tag>(sortBy: [SortDescriptor(\.name)])
        tagsDesc.fetchLimit = 200
        do {
            let fetched = try context.fetch(tagsDesc)
            if fetched != tags { tags = fetched }
        } catch {
            #if DEBUG
            print("PanelViewModel: Error loading tags: \(error)")
            #endif
        }

        var categoriesDesc = FetchDescriptor<Category>(sortBy: [SortDescriptor(\.sortOrder)])
        categoriesDesc.fetchLimit = 100
        do {
            let fetched = try context.fetch(categoriesDesc)
            if fetched != categories { categories = fetched }
        } catch {
            #if DEBUG
            print("PanelViewModel: Error loading categories: \(error)")
            #endif
        }

        var subcategoriesDesc = FetchDescriptor<Subcategory>(sortBy: [SortDescriptor(\.name)])
        subcategoriesDesc.fetchLimit = 500
        do {
            let fetched = try context.fetch(subcategoriesDesc)
            if fetched != allSubcategories { allSubcategories = fetched }
        } catch {
            #if DEBUG
            print("PanelViewModel: Error loading subcategories: \(error)")
            #endif
        }

        var transactionsDesc = FetchDescriptor<TransactionItem>(
            sortBy: [
                SortDescriptor(\.date, order: .reverse),
                SortDescriptor(\.createdAt, order: .reverse)
            ]
        )
        transactionsDesc.fetchLimit = 2000
        do {
            let fetched = try context.fetch(transactionsDesc)
            if fetched != transactions { transactions = fetched }
        } catch {
            #if DEBUG
            print("PanelViewModel: Error loading transactions: \(error)")
            #endif
        }

        var budgetsDesc = FetchDescriptor<Budget>(
            predicate: #Predicate<Budget> { $0.isActive },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        budgetsDesc.fetchLimit = 50
        do {
            let fetched = try context.fetch(budgetsDesc)
            if fetched != budgets { budgets = fetched }
        } catch {
            #if DEBUG
            print("PanelViewModel: Error loading budgets: \(error)")
            #endif
        }

        var paymentsDesc = FetchDescriptor<ScheduledPayment>(
            sortBy: [SortDescriptor(\.nextDueDate)]
        )
        paymentsDesc.fetchLimit = 200
        do {
            let fetched = try context.fetch(paymentsDesc)
            if fetched != scheduledPayments { scheduledPayments = fetched }
        } catch {
            #if DEBUG
            print("PanelViewModel: Error loading scheduled payments: \(error)")
            #endif
        }

        var draftsDesc = FetchDescriptor<InboxDraft>(
            predicate: #Predicate<InboxDraft> { $0.statusRaw == "pending" }
        )
        draftsDesc.fetchLimit = 100
        do {
            let fetched = try context.fetch(draftsDesc)
            if fetched != pendingDrafts { pendingDrafts = fetched }
        } catch {
            #if DEBUG
            print("PanelViewModel: Error loading pending drafts: \(error)")
            #endif
        }

        // Pre-compute transaction date range — O(1) since transactions are sorted by date desc
        let newStart = transactions.last?.date ?? .now
        let newEnd = transactions.first?.date ?? .now
        if newStart != transactionDateRange.start || newEnd != transactionDateRange.end {
            transactionDateRange = (start: newStart, end: newEnd)
        }

        // Pre-compute account balances (not period-dependent — only changes when transactions change)
        calculateAccountBalances()

        // Load group balance summary for widget
        loadGroupSummary(context: context)

        if !isReady { isReady = true }
    }

    private func loadGroupSummary(context: ModelContext) {
        do {
            let allExpenses = try context.fetch(FetchDescriptor<SplitExpense>())
            guard !allExpenses.isEmpty else {
                groupGlobalSummary = nil
                return
            }
            let allShares = try context.fetch(FetchDescriptor<SplitShare>())
            let allSettlements = try context.fetch(FetchDescriptor<SplitSettlement>())
            let allMembers = try context.fetch(FetchDescriptor<SplitMember>())
            let currentUserMemberIDs = Set(allMembers.filter(\.isCurrentUser).map(\.id).map(\.uuidString))

            groupGlobalSummary = GroupBalanceService.globalSummary(
                allExpenses: allExpenses,
                allShares: allShares,
                allSettlements: allSettlements,
                currentUserMemberIDs: currentUserMemberIDs
            )
        } catch {
            #if DEBUG
            print("PanelViewModel: Error loading group summary: \(error)")
            #endif
            groupGlobalSummary = nil
        }
    }

    // MARK: - Widget Data (struct-backed — reduces observation surface)

    var trendChart = PanelTrendData()
    var categoriesWidget = PanelCategoriesData()
    var subcategoriesWidget = PanelSubcategoriesData()
    var needWidget = PanelNeedData()
    var cashFlowWidget = PanelCashFlowData()
    var budgetsWidget = PanelBudgetsData()
    var exchangeRateWidget = PanelExchangeRateData()
    var scheduledPaymentsWidget = PanelScheduledPaymentsData()
    var healthWidget = PanelHealthData()
    var heroWidget = PanelHeroData()
    var weekdayWidget = PanelWeekdayData()
    var periodComparisonWidget = PanelPeriodComparisonData()
    var tagsWidget = PanelTagsData()

    /// Reemplaza el rule-based `subtext` del hero cuando es Pro + consent y
    /// hay cache hit o la API respondió. Nil ⇒ el view usa fallback
    /// rule-based inmediato (también determina la visibilidad del badge
    /// "Pro" en `PanelHeroSection`, derivado de `!= nil`).
    var heroAISubtitle: String? = nil

    // Pre-computed account data — eliminates passing [TransactionItem] to AccountsCarouselView
    private(set) var accountBalances: [PersistentIdentifier: Double] = [:]
    private(set) var accountPeriodExpenses: [PersistentIdentifier: Double] = [:]

    // Pre-computed transaction date range — eliminates iterating all transactions in body eval
    private(set) var transactionDateRange: (start: Date, end: Date) = (.now, .now)

    // Backward-compatible read-only accessors (do NOT create independent observers)
    var topSpendingCategories: [CategorySpendingSummary] { categoriesWidget.topSpendingCategories }
    var previousCategoriesTotalAmount: Double? { categoriesWidget.previousTotalAmount }
    var topSubcategories: [SubcategorySpendingSummary] { subcategoriesWidget.topSubcategories }
    var previousSubcategoriesTotalAmount: Double? { subcategoriesWidget.previousTotalAmount }
    var topTags: [TagSpendingSummary] { tagsWidget.topTags }
    var previousTagsTotalAmount: Double? { tagsWidget.previousTotalAmount }
    var needTrendPoints: [NeedTrendPoint] { needWidget.needTrendPoints }
    var previousNeedTotalAmount: Double? { needWidget.previousTotalAmount }
    var previousNeedAmounts: [SubcategoryNeed: Double] { needWidget.previousAmounts }
    var cashFlowSummary: CashFlowSummary? { cashFlowWidget.cashFlowSummary }
    var latestRecords: [TransactionItem] { _latestRecords }
    var topBudgetSummaries: [BudgetSummary] { budgetsWidget.topBudgetSummaries }
    var hasBudgetsButNoFavorites: Bool { budgetsWidget.hasBudgetsButNoFavorites }
    var exchangeRateWidgetData: ExchangeRateWidgetData? { exchangeRateWidget.exchangeRateWidgetData }
    var exchangeRateGrouping: TrendGrouping { exchangeRateWidget.exchangeRateGrouping }
    var processedTrendPoints: [BarPoint] { trendChart.processedTrendPoints }
    var rawTrendPoints: [BarPoint] { trendChart.rawTrendPoints }
    var processedYDomain: ClosedRange<Double> { trendChart.processedYDomain }
    var currentInterval: DateInterval { trendChart.currentInterval }
    var currentPeriod: DetailPeriod { trendChart.currentPeriod }
    var trendTotalIncome: Double { trendChart.trendTotalIncome }
    var trendTotalExpense: Double { trendChart.trendTotalExpense }
    var trendFinalBalance: Double { trendChart.trendFinalBalance }
    var trendGrouping: TrendGrouping { trendChart.trendGrouping }
    var dataTrendType: TrendType { trendChart.dataTrendType }
    var currentBalance: Double { trendChart.currentBalance }
    var cashFlowGrouping: TrendGrouping { cashFlowWidget.cashFlowGrouping }
    var needGrouping: TrendGrouping { needWidget.needGrouping }

    var chartTransactions: [ChartTransaction] = []

    // Stored separately — SwiftData model identity comparison may miss in-place mutations
    private var _latestRecords: [TransactionItem] = []
    var subcategoriesWidgetFilter: PersistentIdentifier?

    var selectedSubcategoryIDs: Set<PersistentIdentifier> {
        get { SessionState.shared.selectedSubcategoryIDs }
        set { SessionState.shared.selectedSubcategoryIDs = newValue }
    }

    var selectedBudgetID: PersistentIdentifier? {
        SessionState.shared.selectedBudgetID
    }

    var selectedNeed: SubcategoryNeed? {
        get { SessionState.shared.selectedNeeds.first }
        set {
            SessionState.shared.selectedNeeds.removeAll()
            if let n = newValue { SessionState.shared.selectedNeeds.insert(n) }
        }
    }

    var selectedTags: Set<PersistentIdentifier> {
        get { SessionState.shared.selectedTags }
        set { SessionState.shared.selectedTags = newValue }
    }

    var selectedCurrencies: Set<CurrencyCode> {
        get { SessionState.shared.selectedCurrencies }
        set { SessionState.shared.selectedCurrencies = newValue }
    }

    var amountCondition: AmountFilterCondition {
        get { SessionState.shared.amountCondition }
        set { SessionState.shared.amountCondition = newValue }
    }

    var searchText: String {
        get { SessionState.shared.searchText }
        set { SessionState.shared.searchText = newValue }
    }

    var selectedTransactionNatures: Set<TransactionNature> {
        get { SessionState.shared.selectedTransactionNatures }
        set { SessionState.shared.selectedTransactionNatures = newValue }
    }

    var isExcludeMode: Bool {
        get { SessionState.shared.isExcludeMode }
        set { SessionState.shared.isExcludeMode = newValue }
    }

    // Need, CashFlow, LatestRecords, Budgets — now struct-backed (see computed accessors above)

    // Scheduled Payments Widget State
    var scheduledPaymentsWidgetFilter: ScheduledPaymentsWidgetFilter = .all {
        didSet {
            if oldValue != scheduledPaymentsWidgetFilter {
                scheduleRecalculation(reload: false)
            }
        }
    }

    // ExchangeRate, Trend chart, KPI values — now struct-backed (see computed accessors above)
    /// Tracks the last period for which exchange rate was calculated (to avoid redundant recalculations)
    private var lastExchangeRatePeriod: DetailPeriod?

    /// Selected currencies to compare against the preferred currency (max 2).
    var selectedComparisonCurrencies: [CurrencyCode] = []

    typealias BarPoint = Yala.BarPoint

    // Loading State - tracks when heavy calculations are in progress
    var isCalculating: Bool = false

    /// Derive trendType from chip (single source of truth)
    /// Note: Auto-expense logic for category/subcategory filters is handled in PanelView onChange handlers
    /// which properly check if categories are expense-only before setting the filter.
    private func enforceTrendLock(sessionState: SessionState) {
        let resolved: TrendType
        if sessionState.isExpensesOnlyMode {
            resolved = .expense
        } else if sessionState.selectedTransactionNatures.count == 1 {
            if sessionState.selectedTransactionNatures.contains(.income) {
                resolved = .income
            } else {
                resolved = .expense
            }
        } else if sessionState.selectedTransactionNatures.isEmpty {
            resolved = .balance
        } else {
            return // mixed selection — keep current
        }
        // Guard: @Observable fires notifications even when value is identical,
        // which triggers onChange(of: trendType) → recalculateData → infinite loop.
        if resolved != trendType { trendType = resolved }
    }

    // MARK: - SessionState Synchronization (SSOT: Filters are now computed properties)
    // These functions are kept for backward compatibility but do minimal work
    // since filter properties now read/write directly to SessionState

    /// Sync non-filter state FROM SessionState (call on appear/resume)
    func syncFromSessionState(_ sessionState: SessionState) {
        let metric = convertMetricToTrendType(sessionState.selectedTrendMetric)
        if metric != trendType { trendType = metric }
        enforceTrendLock(sessionState: sessionState)
    }

    /// Sync non-filter state TO SessionState (call after changes)
    func syncToSessionState(_ sessionState: SessionState) {
        let metric = convertTrendTypeToMetric(self.trendType)
        // Guard: prevents onChange(of: selectedTrendMetric) → recalculateData loop
        if metric != sessionState.selectedTrendMetric {
            sessionState.selectedTrendMetric = metric
        }
    }

    /// Convert TrendMetric to TrendType
    private func convertMetricToTrendType(_ metric: TrendMetric) -> TrendType {
        switch metric {
        case .balance: return .balance
        case .income: return .income
        case .expense: return .expense
        }
    }

    /// Convert TrendType to TrendMetric
    private func convertTrendTypeToMetric(_ type: TrendType) -> TrendMetric {
        switch type {
        case .balance: return .balance
        case .income: return .income
        case .expense: return .expense
        }
    }

    // MARK: - Dependencies / Configuration

    init() {
        // WidgetConfigManager loads its own configs in init
        loadExchangeRateCurrencySelection()
    }

    // MARK: - Widget Logic

    /// Visible widgets of a section, driven by `AppPreferences.panel<Section>Order/Hidden`
    /// (SSOT since P20-03). The function is self-healing:
    ///  - filters raw values that don't belong to this section (foreign / corrupt entries)
    ///  - dedupes duplicates
    ///  - appends known section defaults missing from stored order (widget types added in
    ///    future versions appear at the tail automatically)
    ///  - excludes entries listed in `panel<Section>Hidden`
    /// Then maps each `WidgetType` to its `WidgetConfig` in `widgetConfigs` (preserving
    /// legacy `size` and `scheduledPaymentsMode`) or synthesizes a default one if missing.
    ///
    /// Bootstrap fallback: when `appPreferences` is still nil (e.g. first frame before
    /// `setAppPreferences` is called), returns the legacy filter so render is never
    /// empty. The next frame, after injection, re-renders with the real state.
    func activeWidgets(in section: PanelSectionKind) -> [WidgetConfig] {
        guard appPreferences != nil else {
            // Bootstrap fallback — legacy filter.
            return widgetConfigs.filter { $0.type.panelSection == section && $0.isVisible }
        }
        let hidden = Set(draftHidden[section] ?? appPreferences?.hidden(for: section) ?? [])
        let visibleRaw = buildOrderedRawWidgets(for: section).filter { !hidden.contains($0) }

        return visibleRaw.compactMap { raw -> WidgetConfig? in
            guard let type = WidgetType(rawValue: raw) else { return nil }
            if let existing = widgetConfigs.first(where: { $0.type == type }) {
                // Legacy `isVisible` is overridden — per-section SSOT already filtered hidden.
                var config = existing
                config.isVisible = true
                return config
            }
            return WidgetConfig(id: UUID(), type: type, isVisible: true, size: .medium)
        }
    }

    /// Full ordered list of widget types in a section (visible + hidden), draft-or-persisted.
    /// Used by `PanelSectionPreferencesSheet` to render every row (including hidden ones
    /// with their toggle off).
    func orderedWidgetTypes(in section: PanelSectionKind) -> [WidgetType] {
        buildOrderedRawWidgets(for: section).compactMap { WidgetType(rawValue: $0) }
    }

    /// Self-healing resolution of the per-section widget order:
    /// 1. Pull stored order (draft-or-persisted); empty on fresh install.
    /// 2. Drop raw values foreign to this section (corruption guard).
    /// 3. Deduplicate.
    /// 4. Append section defaults missing from stored order (widget types added in
    ///    future app versions appear at the tail automatically).
    private func buildOrderedRawWidgets(for section: PanelSectionKind) -> [String] {
        let sectionTypes = WidgetType.defaultWidgets(in: section)
        let sectionRawValues = Set(sectionTypes.map(\.rawValue))

        let stored = draftOrder[section] ?? appPreferences?.order(for: section) ?? []
        var seen: Set<String> = []
        var orderedRaw: [String] = []
        for raw in stored where sectionRawValues.contains(raw) && !seen.contains(raw) {
            seen.insert(raw)
            orderedRaw.append(raw)
        }
        for type in sectionTypes where !seen.contains(type.rawValue) {
            orderedRaw.append(type.rawValue)
        }
        return orderedRaw
    }

    /// True when a widget is currently marked visible (draft-or-persisted).
    func isWidgetHidden(_ type: WidgetType) -> Bool {
        let section = type.panelSection
        let hidden = draftHidden[section] ?? appPreferences?.hidden(for: section) ?? []
        return hidden.contains(type.rawValue)
    }

    /// True when a widget should render and compute. Checks both the section-level
    /// hidden flag (P20-02) and the per-widget hidden flag (P20-03). Consults draft
    /// so widgets stop computing immediately when toggled in the sheet, without
    /// waiting for the 200ms debounce.
    /// Permissive fallback during bootstrap: when `appPreferences` is nil, returns
    /// `true` to avoid incorrectly gating compute on the first frame.
    func isWidgetVisible(_ type: WidgetType) -> Bool {
        guard let prefs = appPreferences else { return true }
        let section = type.panelSection
        if prefs.panelSectionsHidden.contains(section.rawValue) { return false }
        let hidden = draftHidden[section] ?? prefs.hidden(for: section)
        return !hidden.contains(type.rawValue)
    }

    /// Inject AppPreferences. Called by `PanelView` in `.task` BEFORE `setContext(...)`
    /// so the first `performCalculation()` sees the real per-widget visibility state.
    func setAppPreferences(_ prefs: AppPreferences) {
        self.appPreferences = prefs
    }

    // MARK: - Section Preferences Mutators (P20-03)
    //
    // Draft state + 200ms debounce batches rapid reorder/toggle operations from
    // `PanelSectionPreferencesSheet`. Writes flush on sheet dismiss via
    // `flushPendingSectionWrites()`. Reset writes synchronously and clears drafts.

    private var draftOrder: [PanelSectionKind: [String]] = [:]
    private var draftHidden: [PanelSectionKind: [String]] = [:]
    private var pendingSectionWrites: [PanelSectionKind: Task<Void, Never>] = [:]

    private static let sectionWriteDebounce: Duration = .milliseconds(200)

    /// Reorder widgets within a section. Updates draft instantly (UI sees new order),
    /// debounces the AppPreferences write by 200ms to batch rapid drags. No-op drags
    /// (drop on same position) exit early — no draft mutation, no observer notification.
    func moveWidgetInSection(_ kind: PanelSectionKind, from source: IndexSet, to destination: Int) {
        let current = draftOrder[kind] ?? orderedWidgetTypes(in: kind).map(\.rawValue)
        var updated = current
        updated.move(fromOffsets: source, toOffset: destination)
        guard updated != current else { return }
        draftOrder[kind] = updated
        scheduleSectionWrite(for: kind)
    }

    /// Toggle per-widget visibility. Mutation is instant; persistence is debounced.
    /// Early-returns when the toggle is already in the requested state.
    func setWidgetHidden(_ type: WidgetType, hidden: Bool) {
        let kind = type.panelSection
        let current = draftHidden[kind] ?? appPreferences?.hidden(for: kind) ?? []
        let contains = current.contains(type.rawValue)
        guard contains != hidden else { return }
        var hiddenSet = Set(current)
        if hidden {
            hiddenSet.insert(type.rawValue)
        } else {
            hiddenSet.remove(type.rawValue)
        }
        draftHidden[kind] = Array(hiddenSet)
        scheduleSectionWrite(for: kind)
    }

    /// Clears section's Order + Hidden so `activeWidgets(in:)` falls back to
    /// `WidgetType.defaultWidgets(in:)`. Cancels any pending debounce, clears draft,
    /// and writes synchronously — the user expects "Restablecer" to take effect now.
    func resetSectionPreferences(_ kind: PanelSectionKind) {
        pendingSectionWrites[kind]?.cancel()
        pendingSectionWrites[kind] = nil
        draftOrder[kind] = nil
        draftHidden[kind] = nil
        appPreferences?.setOrder([], for: kind)
        appPreferences?.setHidden([], for: kind)
    }

    /// Flushes all pending debounced writes synchronously. Called from sheet
    /// `.onDisappear` so drag-then-dismiss-quickly sequences never lose state.
    func flushPendingSectionWrites() {
        let pending = pendingSectionWrites
        pendingSectionWrites.removeAll()
        for (kind, task) in pending {
            task.cancel()
            commitDraft(for: kind)
        }
    }

    private func scheduleSectionWrite(for kind: PanelSectionKind) {
        pendingSectionWrites[kind]?.cancel()
        pendingSectionWrites[kind] = Task { @MainActor [weak self] in
            try? await Task.sleep(for: Self.sectionWriteDebounce)
            guard !Task.isCancelled else { return }
            guard let self else { return }
            self.commitDraft(for: kind)
            self.pendingSectionWrites[kind] = nil
        }
    }

    private func commitDraft(for kind: PanelSectionKind) {
        guard let prefs = appPreferences else {
            draftOrder[kind] = nil
            draftHidden[kind] = nil
            return
        }
        if let order = draftOrder[kind] {
            prefs.setOrder(order, for: kind)
            draftOrder[kind] = nil
        }
        if let hidden = draftHidden[kind] {
            prefs.setHidden(hidden, for: kind)
            draftHidden[kind] = nil
        }
    }

    // MARK: - Hero KPI Preferences Mutators (P20-04b)
    //
    // Mirrors the section mutators above but simpler: Hero KPIs are a single
    // global set, not per-section. The `panelHeroKPIsCustomized` flag gates
    // between "never touched" (return defaults) and "customised" (respect the
    // stored arrays verbatim, even when empty). The flag flips on the first
    // move/toggle; `resetHeroKPIPreferences()` flips it back to `false`.

    private var draftHeroOrder: [String]?
    private var draftHeroHidden: [String]?
    private var pendingHeroWrite: Task<Void, Never>?

    /// Resolves the full ordered list of KPIs, draft-or-persisted, self-healing
    /// against corruption and future KPIs (missing entries are appended at the
    /// tail of the resolved list).
    func orderedHeroKPIs() -> [HeroKPI] {
        let isCustomized = appPreferences?.panelHeroKPIsCustomized ?? false
        // Defaults fast path — avoids self-heal work on every render for
        // first-time users.
        if !isCustomized, draftHeroOrder == nil {
            return HeroKPI.defaultOrder
        }

        let stored = draftHeroOrder ?? appPreferences?.panelHeroKPIsOrder ?? []
        var seen: Set<HeroKPI> = []
        var resolved: [HeroKPI] = []
        for raw in stored {
            guard let kpi = HeroKPI(rawValue: raw), !seen.contains(kpi) else { continue }
            seen.insert(kpi)
            resolved.append(kpi)
        }
        for kpi in HeroKPI.defaultOrder where !seen.contains(kpi) {
            resolved.append(kpi)
        }
        return resolved
    }

    /// True when the KPI should NOT render as a pill. Respects deliberate
    /// empty arrays only after the user flipped the customised flag.
    func isHeroKPIHidden(_ kpi: HeroKPI) -> Bool {
        let isCustomized = appPreferences?.panelHeroKPIsCustomized ?? false
        if !isCustomized, draftHeroHidden == nil {
            return HeroKPI.defaultHidden.contains(kpi)
        }
        let hidden = draftHeroHidden ?? appPreferences?.panelHeroKPIsHidden ?? []
        return hidden.contains(kpi.rawValue)
    }

    /// Returns the KPIs that should render, capped at `max` (default 3 — the
    /// hero's layout). Callers pass `.max` when they need the total active
    /// count (e.g. the sheet gating the last-active toggle).
    func activeHeroKPIs(max: Int = 3) -> [HeroKPI] {
        let active = orderedHeroKPIs().filter { !isHeroKPIHidden($0) }
        return Array(active.prefix(max))
    }

    /// Reorder within the full Hero KPI list (actives + hidden together).
    /// No-op when the drag lands on the same slot. Flips the customised flag
    /// on the first non-default change, via `scheduleHeroKPIWrite`.
    func moveHeroKPI(from source: IndexSet, to destination: Int) {
        let current = draftHeroOrder ?? orderedHeroKPIs().map(\.rawValue)
        var updated = current
        updated.move(fromOffsets: source, toOffset: destination)
        guard updated != current else { return }
        draftHeroOrder = updated
        scheduleHeroKPIWrite()
    }

    /// Reorder among ACTIVE KPIs only (the reorder sub-sheet's world). The
    /// `source`/`destination` indices refer to the `activeHeroKPIs(max: .max)`
    /// array. We rebuild the full order by walking `orderedHeroKPIs()` in
    /// place: hidden KPIs keep their absolute slots; each active slot draws
    /// the next element from the reordered active list. That way moving an
    /// active pill never shuffles a hidden KPI.
    func moveActiveHeroKPI(from source: IndexSet, to destination: Int) {
        let ordered = orderedHeroKPIs()
        let actives = ordered.filter { !isHeroKPIHidden($0) }
        var reorderedActives = actives
        reorderedActives.move(fromOffsets: source, toOffset: destination)
        guard reorderedActives != actives else { return }

        var iterator = reorderedActives.makeIterator()
        let newOrder: [HeroKPI] = ordered.map { kpi in
            isHeroKPIHidden(kpi) ? kpi : (iterator.next() ?? kpi)
        }
        draftHeroOrder = newOrder.map(\.rawValue)
        scheduleHeroKPIWrite()
    }

    /// Toggle per-KPI visibility. Instant UI mutation; the write is debounced.
    /// When flipping the first toggle on a fresh install, we materialise the
    /// current effective state (`defaultHidden` via `isHeroKPIHidden`) into
    /// the draft — otherwise `panelHeroKPIsHidden == []` would be treated as
    /// "nothing hidden" and defaults would silently drop.
    func setHeroKPIHidden(_ kpi: HeroKPI, hidden: Bool) {
        let effectiveHidden: Set<String> = Set(
            HeroKPI.allCases
                .filter { isHeroKPIHidden($0) }
                .map(\.rawValue)
        )
        let alreadyHidden = effectiveHidden.contains(kpi.rawValue)
        guard alreadyHidden != hidden else { return }
        var updated = effectiveHidden
        if hidden { updated.insert(kpi.rawValue) } else { updated.remove(kpi.rawValue) }
        draftHeroHidden = HeroKPI.allCases
            .map(\.rawValue)
            .filter { updated.contains($0) }
        scheduleHeroKPIWrite()
    }

    /// Cancels any pending debounce, clears drafts, writes empty arrays and
    /// flips `panelHeroKPIsCustomized` back to `false` — fully returns to the
    /// "never touched" state. The user expects "Restablecer" to take effect
    /// immediately, so this is synchronous.
    func resetHeroKPIPreferences() {
        pendingHeroWrite?.cancel()
        pendingHeroWrite = nil
        draftHeroOrder = nil
        draftHeroHidden = nil
        appPreferences?.panelHeroKPIsOrder = []
        appPreferences?.panelHeroKPIsHidden = []
        appPreferences?.panelHeroKPIsCustomized = false
    }

    /// Flushes pending write synchronously (called by the sheet's
    /// `.onDisappear` so the data is committed before the VM reloads).
    func flushPendingHeroKPIWrites() {
        pendingHeroWrite?.cancel()
        pendingHeroWrite = nil
        commitHeroKPIDraft()
    }

    /// Debounces the Hero KPI write by 200ms — batches rapid reorder/toggle
    /// operations into a single `AppPreferences` commit.
    private func scheduleHeroKPIWrite() {
        pendingHeroWrite?.cancel()
        pendingHeroWrite = Task { @MainActor [weak self] in
            try? await Task.sleep(for: Self.sectionWriteDebounce)
            guard !Task.isCancelled else { return }
            self?.commitHeroKPIDraft()
        }
    }

    /// Writes drafts to `AppPreferences` and flips the customised flag on
    /// first change. Called by the debounce timer or by
    /// `flushPendingHeroKPIWrites()`.
    private func commitHeroKPIDraft() {
        guard let prefs = appPreferences else {
            draftHeroOrder = nil
            draftHeroHidden = nil
            return
        }
        var mutated = false
        if let order = draftHeroOrder {
            prefs.panelHeroKPIsOrder = order
            draftHeroOrder = nil
            mutated = true
        }
        if let hidden = draftHeroHidden {
            prefs.panelHeroKPIsHidden = hidden
            draftHeroHidden = nil
            mutated = true
        }
        if mutated, !prefs.panelHeroKPIsCustomized {
            prefs.panelHeroKPIsCustomized = true
        }
    }

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
    /// Uses pre-calculated amountInPreferredCurrency for optimal performance.
    func totalBalanceInDefaultCurrency(
        accounts: [Account],
        transactions: [TransactionItem],
        defaultCurrencyCode: String
    ) -> Double {
        return BalanceHelper.totalBalance(
            accounts: accounts,
            transactions: transactions,
            preferredCurrencyCode: defaultCurrencyCode
        )
    }

    /// Calculates the displayed balance (either total or selected account).
    /// Uses date-specific exchange rates for each transaction for accuracy.
    func displayedBalanceInDefaultCurrency(
        accounts: [Account],
        transactions: [TransactionItem],
        defaultCurrencyCode: String
    ) -> Double {
        return BalanceHelper.displayedBalance(
            accounts: accounts,
            transactions: transactions,
            selectedAccountID: self.selectedAccountID,
            preferredCurrencyCode: defaultCurrencyCode
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

    /// Calculates total expenses for a specific account in the current period.
    /// Used in expenses-only mode to show "Spent" instead of balance.
    func expenseForPeriod(
        for account: Account,
        allTransactions: [TransactionItem]
    ) -> Double {
        let interval = panelDateInterval
        let total = allTransactions
            .filter { transaction in
                guard transaction.account?.persistentModelID == account.persistentModelID else { return false }
                guard interval.contains(transaction.date) else { return false }
                guard transaction.balanceAdjustmentType == nil else { return false }
                guard transaction.category?.isIncome == false else { return false }
                return true
            }
            .reduce(0.0) { $0 + abs($1.amount) }
        return total
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

    // MARK: - Navigation

    /// Navigates to a Statistics detail tab, setting temporary tab if Statistics is hidden.
    /// Moved from PanelView to eliminate closure parameters in child views.
    func navigateToStatistics(_ detailTab: DetailViewTab) {
        let json = UserDefaults.standard.string(forKey: TabBarConfiguration.storageKey)
            ?? TabBarConfiguration.default.toJSON()
        let isVisible = TabBarConfiguration.fromJSON(json).activeTabs.contains(.statistics)
        if !isVisible { sessionState?.temporaryTab = .statistics }
        sessionState?.navigateToDetail(detailTab)
    }

    /// Whether voice input can be used (requires active accounts and visible subcategories).
    var canUseVoiceInput: Bool {
        accounts.contains { !$0.isArchived } && allSubcategories.contains { $0.isVisible }
    }

    // MARK: - Layout Logic

    // Note: computeLayoutRows is now handled by WidgetConfigManager

    func ensureAccountsSortOrderConsistency(
        accounts: [Account],
        currentOrder: [String]
    ) -> [String] {
        let activeAccounts = accounts.filter { !$0.isArchived }
        let activeNames = activeAccounts.map { $0.name }

        if activeNames.isEmpty {
            return []
        }

        var newOrder = currentOrder.filter { activeNames.contains($0) }

        for name in activeNames where !newOrder.contains(name) {
            newOrder.append(name)
        }

        return newOrder
    }

    private func convertToPreferredCurrency(
        amount: Decimal,
        from source: CurrencyCode,
        to target: CurrencyCode
    ) -> Decimal {
        if source == target {
            return amount
        }

        // Use CurrencyConverter with API rates for consistency with chart calculations
        return currencyConverter.convertWithLatestRate(
            amount,
            from: source.rawValue,
            to: target.rawValue
        )
    }

    // MARK: - Trend Logic (Year Only - Tight Range)

    // MARK: - Trend Logic (Dynamic Period)

    /// Intervalo de fecha calculado basado en el periodo seleccionado:
    var panelDateInterval: DateInterval {
        // Use the centralized date interval logic from DetailPeriod models
        return selectedPeriod.dateInterval(customRange: customDateRange)
    }

    // MARK: - Trend & Balance Status Logic

    var selectedCategoryID: PersistentIdentifier? {
        get { SessionState.shared.selectedCategoryIDs.first }
        set {
            SessionState.shared.selectedCategoryIDs.removeAll()
            if let id = newValue { SessionState.shared.selectedCategoryIDs.insert(id) }
        }
    }

    // Trend State (standalone — not struct-backed because they're user-interactive)
    var balanceStatus: BalanceStatus = .unknown
    var historicalThreshold: Double = 0
    var trendType: TrendType = .balance
    var focusedDate: Date? = nil

    /// Calculates trend data and status based on the current period, selected account, and selected category.
    /// Refactored for smooth UX - all calculations done first, then state updated in one batch.
    /// Optimized with lazy evaluation - only calculates visible widgets.
    func calculateTrendData(
        accounts: [Account],
        transactions: [TransactionItem],
        defaultCurrencyCode: String,
        context: ModelContext,
        sessionState: SessionState
    ) {
        // 1. Build shared calculation context
        let calcContext = buildCalculationContext(
            accounts: accounts,
            transactions: transactions,
            defaultCurrencyCode: defaultCurrencyCode
        )

        // Per-widget visibility (P20-03 promoted guards from section- to widget-level).
        let trendVisible = isWidgetVisible(.trend)
        let cashFlowVisible = isWidgetVisible(.cashFlow)
        let needVisible = isWidgetVisible(.expensesByNeed)
        let categoriesVisible = isWidgetVisible(.categoriesPie)
        let subcategoriesVisible = isWidgetVisible(.subcategoriesPie)
        let weekdayVisible = isWidgetVisible(.weekdayBar)
        let tagsVisible = isWidgetVisible(.tagsPie)

        // 2. Calculate widget data per visible widget

        // Trend chart
        var newTrendPoints: (points: [BarPoint], rawPoints: [BarPoint], yDomain: ClosedRange<Double>)?
        var newTrendTotalIncome = trendTotalIncome
        var newTrendTotalExpense = trendTotalExpense
        var newTrendFinalBalance = trendFinalBalance
        if trendVisible {
            // For balance, use all transactions (no date filter) to calculate running balance
            let transactionsForTrend = trendType == .balance
                ? calcContext.balanceTransactions
                : calcContext.filteredTransactions
            let result = TrendDataProcessor.processTrendData(
                transactions: transactionsForTrend,
                accounts: calcContext.eligibleAccounts,
                metric: trendType,
                period: calcContext.period,
                grouping: calcContext.trendGrouping,
                interval: calcContext.effectiveInterval,
                currencyCode: calcContext.defaultCurrencyCode
            )
            newTrendPoints = (result.points, result.rawPoints, result.yDomain)
            newTrendTotalIncome = result.totalIncome
            newTrendTotalExpense = result.totalExpense
            newTrendFinalBalance = result.finalBalance
        }

        // Categories — Distribución
        var newTopSpendingCategories = topSpendingCategories
        var newPreviousCategoriesTotal = categoriesWidget.previousTotalAmount
        if categoriesVisible {
            let categoriesResult = calculateCategoriesWidget(context: calcContext)
            newTopSpendingCategories = categoriesResult.categories
            newPreviousCategoriesTotal = categoriesResult.previousTotal
        }

        // Subcategories — Distribución
        var newTopSubcategories = topSubcategories
        var newPreviousSubcategoriesTotal = subcategoriesWidget.previousTotalAmount
        if subcategoriesVisible {
            let subcategoriesResult = calculateSubcategoriesWidget(context: calcContext)
            newTopSubcategories = subcategoriesResult.subcategories
            newPreviousSubcategoriesTotal = subcategoriesResult.previousTotal
        }

        // Cash Flow — Tendencias
        var newCashFlowSummary = cashFlowWidget.cashFlowSummary
        if cashFlowVisible {
            newCashFlowSummary = calculateCashFlowWidget(context: calcContext)
        }

        // Need Trend — Tendencias
        var newNeedTrendPoints = needWidget.needTrendPoints
        var newPreviousNeedTotal = needWidget.previousTotalAmount
        var newPreviousNeedAmounts = needWidget.previousAmounts
        if needVisible {
            let needResult = calculateNeedWidget(context: calcContext)
            newNeedTrendPoints = needResult.points
            newPreviousNeedTotal = needResult.previousTotal
            newPreviousNeedAmounts = needResult.previousAmounts
        }

        if weekdayVisible {
            calculateWeekdayWidget(context: calcContext)
        }

        if tagsVisible {
            calculateTagsWidget(context: calcContext)
        }

        // Second page of the Trends carousel — same visibility guard as the trend chart
        if trendVisible {
            calculatePeriodComparisonWidget(context: calcContext)
        }

        // Latest Records — always computes (non-toggleable section)
        let newLatestRecords = calculateLatestRecordsWidget(context: calcContext)

        // 3. BATCH STATE UPDATE — Atomic struct assignments collapse ~21 individual
        // @Observable notifications into ~6 struct-level comparisons.
        enforceTrendLock(sessionState: sessionState)

        let newBalance = displayedBalanceInDefaultCurrency(
            accounts: accounts,
            transactions: transactions,
            defaultCurrencyCode: defaultCurrencyCode
        )

        if trendVisible, let trendPoints = newTrendPoints {
            let newTrend = PanelTrendData(
                processedTrendPoints: trendPoints.points,
                rawTrendPoints: trendPoints.rawPoints,
                processedYDomain: trendPoints.yDomain,
                currentInterval: calcContext.effectiveInterval,
                currentPeriod: self.selectedPeriod,
                trendTotalIncome: newTrendTotalIncome,
                trendTotalExpense: newTrendTotalExpense,
                trendFinalBalance: newTrendFinalBalance,
                trendGrouping: calcContext.trendGrouping,
                dataTrendType: self.trendType,
                currentBalance: newBalance
            )
            if newTrend != trendChart { trendChart = newTrend }
        }

        if needVisible {
            let newNeed = PanelNeedData(
                needTrendPoints: newNeedTrendPoints,
                previousTotalAmount: newPreviousNeedTotal,
                previousAmounts: newPreviousNeedAmounts,
                needGrouping: calcContext.needGrouping
            )
            if newNeed != needWidget { needWidget = newNeed }
        }

        if cashFlowVisible {
            let newCashFlow = PanelCashFlowData(
                cashFlowSummary: newCashFlowSummary,
                cashFlowGrouping: calcContext.cashFlowGrouping
            )
            if newCashFlow != cashFlowWidget { cashFlowWidget = newCashFlow }
        }

        if categoriesVisible {
            let newCategories = PanelCategoriesData(
                topSpendingCategories: newTopSpendingCategories,
                previousTotalAmount: newPreviousCategoriesTotal
            )
            if newCategories != categoriesWidget { categoriesWidget = newCategories }
        }

        if subcategoriesVisible {
            let newSubcategories = PanelSubcategoriesData(
                topSubcategories: newTopSubcategories,
                previousTotalAmount: newPreviousSubcategoriesTotal
            )
            if newSubcategories != subcategoriesWidget { subcategoriesWidget = newSubcategories }
        }

        if newLatestRecords != _latestRecords { _latestRecords = newLatestRecords }

        // 4. Exchange Rate Widget Data (conditional refresh)
        updateExchangeRateDataIfNeeded(defaultCurrencyCode: defaultCurrencyCode, context: context)
    }

    // MARK: - Calculation Context Helpers

    /// Determine trend/cashFlow/need groupings based on selected period
    private func determineGroupings() -> (trend: TrendGrouping, cashFlow: TrendGrouping, need: TrendGrouping) {
        let trend = selectedPeriod.chartGrouping
        let (cashFlow, need): (TrendGrouping, TrendGrouping) = {
            switch selectedPeriod {
            case .thisWeek, .last7Days:
                return (.day, .day)
            case .thisMonth, .lastMonth, .last30Days:
                return (.day, .day)
            case .thisYear, .lastYear, .allTime, .custom:
                return (.month, .month)
            }
        }()
        return (trend, cashFlow, need)
    }

    /// Compute eligible accounts and their IDs (archived accounts still count)
    private func computeEligibleAccounts(from accounts: [Account]) -> (accounts: [Account], ids: Set<PersistentIdentifier>) {
        let eligible = accounts.filter { account in
            guard !account.excludeFromStatistics else { return false }
            guard let selectedID = selectedAccountID else { return true }
            if isExcludeMode {
                return account.persistentModelID != selectedID
            } else {
                return account.persistentModelID == selectedID
            }
        }
        return (eligible, Set(eligible.map { $0.persistentModelID }))
    }

    /// Build pie chart transactions: filtered WITHOUT category/subcategory for dimming behavior
    private func buildPieContextTransactions(
        from transactions: [TransactionItem],
        eligibleAccountIDs: Set<PersistentIdentifier>,
        effectiveInterval: DateInterval
    ) -> [TransactionItem] {
        let calendar = Calendar.current
        return transactions.filter { transaction in
            guard let account = transaction.account else { return false }
            if !eligibleAccountIDs.contains(account.persistentModelID) { return false }
            if !effectiveInterval.contains(transaction.date) { return false }
            guard transaction.balanceAdjustmentType == nil else { return false }

            // Focused Date Filter
            if let focus = focusedDate {
                if !calendar.isDate(transaction.date, inSameDayAs: focus) { return false }
            }

            // Category/Subcategory filters excluded for pie dimming behavior,
            // EXCEPT when filtering comes from a budget selection or exclude mode
            if selectedBudgetID != nil && !selectedSubcategoryIDs.isEmpty {
                guard let subID = transaction.subcategory?.persistentModelID,
                    selectedSubcategoryIDs.contains(subID)
                else { return false }
            } else if isExcludeMode {
                if let selectedCatID = selectedCategoryID,
                   transaction.category?.persistentModelID == selectedCatID {
                    return false
                }
                if !selectedSubcategoryIDs.isEmpty,
                   let subID = transaction.subcategory?.persistentModelID,
                   selectedSubcategoryIDs.contains(subID) {
                    return false
                }
            }

            // Need Filter (still applies to pie charts)
            if let need = selectedNeed {
                if let sub = transaction.subcategory {
                    if sub.need != need { return false }
                } else {
                    if need != .unclassified { return false }
                }
            }

            // Tag Filter
            if !selectedTags.isEmpty {
                let transactionTagIDs = Set((transaction.tags ?? []).map { $0.persistentModelID })
                if transactionTagIDs.isDisjoint(with: selectedTags) { return false }
            }

            // Currency Filter
            if !selectedCurrencies.isEmpty {
                guard let txCurrency = CurrencyCode(rawValue: transaction.currencyCode) else {
                    return false
                }
                if !selectedCurrencies.contains(txCurrency) { return false }
            }

            // Amount Filter
            if amountCondition.isActive {
                let amountDecimal = Decimal(transaction.amount)
                if !amountCondition.matches(amountDecimal) { return false }
            }

            // Search/Note Filter
            if !searchText.isEmpty {
                let noteMatches = transaction.note?.localizedCaseInsensitiveContains(searchText) ?? false
                if !noteMatches { return false }
            }

            return true
        }
    }

    /// Pre-compute need-filtered transactions for pie widgets
    private func buildNeedFilteredTransactions(from pieContextTransactions: [TransactionItem]) -> [TransactionItem] {
        guard let need = selectedNeed else { return pieContextTransactions }
        return pieContextTransactions.filter { txn in
            if let sub = txn.subcategory {
                return sub.need == need
            } else {
                return need == .unclassified
            }
        }
    }

    /// Pre-compute fully-filtered transactions (need + subcategory)
    private func buildFullyFilteredTransactions(from needFiltered: [TransactionItem]) -> [TransactionItem] {
        guard !selectedSubcategoryIDs.isEmpty else { return needFiltered }
        return needFiltered.filter { tx in
            guard let subID = tx.subcategory?.persistentModelID else { return false }
            return selectedSubcategoryIDs.contains(subID)
        }
    }

    /// Refresh exchange rate widget data only when needed (period change, error, or settings change)
    private func updateExchangeRateDataIfNeeded(defaultCurrencyCode: String, context: ModelContext) {
        let periodChanged = lastExchangeRatePeriod != selectedPeriod
        let hasError = exchangeRateWidgetData?.hasError == true
        let needsRefresh = SessionState.shared.needsExchangeRateWidgetRefresh
        let needsExchangeRateData = exchangeRateWidgetData == nil || periodChanged || hasError || needsRefresh
        guard needsExchangeRateData else { return }

        lastExchangeRatePeriod = selectedPeriod
        if needsRefresh {
            SessionState.shared.needsExchangeRateWidgetRefresh = false
            reloadCurrenciesFromSettings()
        }
        calculateExchangeRateData(
            preferredCurrencyCode: defaultCurrencyCode,
            context: context
        )
    }

    // MARK: - Filter Criteria Builder

    /// Builds FilterCriteria from SessionState for use with FilterService.
    /// Accounts NOT included — pre-filtered by eligibleAccountIDs (handles excludeFromStatistics).
    func buildFilterCriteria(
        dateInterval: DateInterval? = nil,
        includeCategories: Bool = true
    ) -> FilterCriteria {
        var criteria = FilterCriteria()
        criteria.selectedTags = selectedTags
        criteria.selectedCurrencies = selectedCurrencies
        criteria.isExcludeMode = isExcludeMode
        criteria.amountCondition = amountCondition
        criteria.searchText = searchText
        criteria.dateInterval = dateInterval

        if includeCategories {
            criteria.selectedCategories = SessionState.shared.selectedCategoryIDs
            criteria.selectedSubcategories = selectedSubcategoryIDs
            criteria.selectedNeeds = SessionState.shared.selectedNeeds
        }

        return criteria
    }

    // MARK: - Calculation Context Builder

    /// Builds the shared context for all widget calculations
    private func buildCalculationContext(
        accounts: [Account],
        transactions: [TransactionItem],
        defaultCurrencyCode: String
    ) -> PanelCalculationContext {
        let calendar = Calendar.current

        let (newTrendGrouping, newCashFlowGrouping, newNeedGrouping) = determineGroupings()
        let (eligibleAccounts, eligibleAccountIDs) = computeEligibleAccounts(from: accounts)

        // Filter transactions by account + date + global filters
        let fullCriteria = buildFilterCriteria(dateInterval: panelDateInterval)
        let filtered = transactions.filter { transaction in
            guard let account = transaction.account else { return false }
            if !eligibleAccountIDs.contains(account.persistentModelID) { return false }

            // Focused Date Filter (PanelVM-specific: chart scrubbing)
            if let focus = focusedDate {
                if !calendar.isDate(transaction.date, inSameDayAs: focus) { return false }
            }

            return FilterService.matchesCriteria(transaction, criteria: fullCriteria)
        }

        // Transactions filtered by all criteria EXCEPT date and categories (for previous period comparison)
        // Excludes adjustments like expenseFiltered does
        let comparisonCriteria = buildFilterCriteria(includeCategories: false)
        let transactionsWithoutDateFilter = transactions.filter { transaction in
            guard transaction.balanceAdjustmentType == nil else { return false }
            guard let account = transaction.account else { return false }
            if !eligibleAccountIDs.contains(account.persistentModelID) { return false }
            return FilterService.matchesCriteria(transaction, criteria: comparisonCriteria)
        }

        // Balance transactions: same filters as filtered BUT without date filter
        // INCLUDES adjustments (needed for running balance calculation)
        let balanceCriteria = buildFilterCriteria()  // dateInterval = nil → no date filter
        let balanceTransactions = transactions.filter { transaction in
            guard let account = transaction.account else { return false }
            if !eligibleAccountIDs.contains(account.persistentModelID) { return false }
            return FilterService.matchesCriteria(transaction, criteria: balanceCriteria)
        }

        // Expense-filtered transactions (excludes adjustments and initial balances)
        let expenseFiltered = filtered.filter { $0.balanceAdjustmentType == nil }

        // Calculate effective interval (optimized for All Time)
        // Note: Use endOfToday (stable within the same day) instead of Date.now to prevent
        // currentInterval from changing on every recalculation, which causes unnecessary re-renders.
        let effectiveInterval: DateInterval
        if selectedPeriod == .allTime {
            let endOfToday = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: .now)) ?? .now
            if let firstTxDate = filtered.map(\.date).min() {
                let start =
                    calendar.date(
                        from: calendar.dateComponents([.year, .month], from: firstTxDate))
                    ?? firstTxDate
                effectiveInterval = DateInterval(start: start, end: endOfToday)
            } else {
                let startOfYear = calendar.date(
                    from: calendar.dateComponents([.year], from: .now)) ?? .now
                effectiveInterval = DateInterval(start: startOfYear, end: endOfToday)
            }
        } else {
            effectiveInterval = self.panelDateInterval
        }

        // Context transactions for other widgets (respects all filters including category/subcategory)
        let contextTransactions = expenseFiltered.filter { txn in
            effectiveInterval.contains(txn.date)
        }

        let finalContextTransactions: [TransactionItem]
        if let focus = focusedDate {
            finalContextTransactions = contextTransactions.filter {
                Calendar.current.isDate($0.date, inSameDayAs: focus)
            }
        } else {
            finalContextTransactions = contextTransactions
        }

        let pieContextTransactions = buildPieContextTransactions(
            from: transactions,
            eligibleAccountIDs: eligibleAccountIDs,
            effectiveInterval: effectiveInterval
        )
        let needFiltered = buildNeedFilteredTransactions(from: pieContextTransactions)
        let fullyFiltered = buildFullyFilteredTransactions(from: needFiltered)

        // Transactions for need widget - has cat/subcat filters but NO need filter
        // This allows the need widget to show ALL needs with visual dimming
        let needWidgetTxns = expenseFiltered.filter { txn in
            effectiveInterval.contains(txn.date)
        }

        return PanelCalculationContext(
            accounts: accounts,
            transactions: transactions,
            defaultCurrencyCode: defaultCurrencyCode,
            converter: currencyConverter,
            eligibleAccounts: eligibleAccounts,
            eligibleAccountIDs: eligibleAccountIDs,
            filteredTransactions: filtered,
            expenseFilteredTransactions: expenseFiltered,
            contextTransactions: finalContextTransactions,
            needFilteredTransactions: needFiltered,
            fullyFilteredTransactions: fullyFiltered,
            needWidgetTransactions: needWidgetTxns,
            transactionsWithoutDateFilter: transactionsWithoutDateFilter,
            balanceTransactions: balanceTransactions,
            period: selectedPeriod,
            effectiveInterval: effectiveInterval,
            trendGrouping: newTrendGrouping,
            cashFlowGrouping: newCashFlowGrouping,
            needGrouping: newNeedGrouping,
            focusedDate: focusedDate,
            selectedCategoryID: selectedCategoryID,
            selectedSubcategoryIDs: selectedSubcategoryIDs,
            selectedNeed: selectedNeed,
            subcategoriesWidgetFilter: subcategoriesWidgetFilter,
            selectedTransactionNatures: selectedTransactionNatures
        )
    }

    /// Calculate top spending categories with period comparison
    /// Uses needFilteredTransactions (not fullyFiltered) so that subcategory selection
    /// only dims categories visually, rather than filtering out other categories' data
    /// Returns: (categories, previousPeriodTotal)
    private func calculateCategoriesWidget(context: PanelCalculationContext)
        -> (categories: [CategorySpendingSummary], previousTotal: Double?)
    {
        // Calculate current period data using need-filtered transactions
        // This ensures category pie shows ALL categories (selection = visual dim, not data filter)
        // Pass transactionNatures filter - empty means show expenses only (default)
        let naturesFilter: Set<TransactionNature>? = context.selectedTransactionNatures.isEmpty
            ? nil
            : context.selectedTransactionNatures

        var currentData = TopSpendingCategoriesCalculator.calculateTopSpending(
            transactions: context.needFilteredTransactions,
            interval: context.effectiveInterval,
            currencyCode: context.defaultCurrencyCode,
            transactionNatures: naturesFilter,
            converter: context.converter
        )

        // Skip previous period calculation for "All Time" (no meaningful comparison)
        guard context.period != .allTime else {
            return (currentData, nil)
        }

        // Calculate previous period data for comparison
        let previousInterval = PreviousPeriodHelper.previousInterval(
            for: context.period,
            mode: .month,  // Default to -1 period comparison
            customRange: nil
        )

        // Filter transactions for previous period (using date-independent filter)
        let previousTransactions = context.transactionsWithoutDateFilter.filter {
            previousInterval.contains($0.date)
        }

        let previousData = TopSpendingCategoriesCalculator.calculateTopSpending(
            transactions: previousTransactions,
            interval: previousInterval,
            currencyCode: context.defaultCurrencyCode,
            transactionNatures: naturesFilter,
            converter: context.converter
        )

        // Calculate the ACTUAL previous period total (sum of ALL categories from previous period)
        let previousTotal = previousData.reduce(0) { $0 + $1.amount }

        // Create lookup dictionary for previous amounts by category ID
        let previousAmounts = Dictionary(
            uniqueKeysWithValues: previousData.map { ($0.category.persistentModelID, $0.amount) }
        )

        // Assign previousAmount to current data
        for index in currentData.indices {
            let categoryID = currentData[index].category.persistentModelID
            currentData[index].previousAmount = previousAmounts[categoryID]
        }

        return (currentData, previousTotal > 0 ? previousTotal : nil)
    }

    /// Calculate top subcategories with period comparison
    /// Uses needFilteredTransactions (not fullyFiltered) so that subcategory selection
    /// only dims subcategories visually, rather than filtering out other subcategories' data
    /// Returns: (subcategories, previousPeriodTotal)
    private func calculateSubcategoriesWidget(context: PanelCalculationContext)
        -> (subcategories: [SubcategorySpendingSummary], previousTotal: Double?)
    {
        // Use pre-filtered transactions from context (need already applied)
        let effectiveCategoryFilter =
            context.selectedCategoryID ?? context.subcategoriesWidgetFilter

        // Use need-filtered transactions (category filter applies separately)
        // This ensures subcategory pie shows ALL subcategories (selection = visual dim, not data filter)
        // Pass transactionNatures filter - empty means show expenses only (default)
        let naturesFilter: Set<TransactionNature>? = context.selectedTransactionNatures.isEmpty
            ? nil
            : context.selectedTransactionNatures

        var currentData = TopSubcategoriesCalculator.calculateTopSubcategories(
            transactions: context.needFilteredTransactions,
            interval: context.effectiveInterval,
            currencyCode: context.defaultCurrencyCode,
            categoryFilter: effectiveCategoryFilter,
            transactionNatures: naturesFilter,
            converter: context.converter
        )

        // Skip previous period calculation for "All Time" (no meaningful comparison)
        guard context.period != .allTime else {
            return (currentData, nil)
        }

        // Calculate previous period data for comparison
        let previousInterval = PreviousPeriodHelper.previousInterval(
            for: context.period,
            mode: .month,  // Default to -1 period comparison
            customRange: nil
        )

        // Filter transactions for previous period (using date-independent filter)
        let previousTransactions = context.transactionsWithoutDateFilter.filter {
            previousInterval.contains($0.date)
        }

        let previousData = TopSubcategoriesCalculator.calculateTopSubcategories(
            transactions: previousTransactions,
            interval: previousInterval,
            currencyCode: context.defaultCurrencyCode,
            categoryFilter: effectiveCategoryFilter,
            transactionNatures: naturesFilter,
            converter: context.converter
        )

        // Calculate the ACTUAL previous period total (sum of ALL subcategories from previous period)
        let previousTotal = previousData.reduce(0) { $0 + $1.amount }

        // Create lookup dictionary for previous amounts by subcategory ID (more reliable than name)
        let previousAmounts = Dictionary(
            uniqueKeysWithValues: previousData.compactMap { summary -> (PersistentIdentifier, Double)? in
                guard let id = summary.persistentID else { return nil }
                return (id, summary.amount)
            }
        )

        // Assign previousAmount to current data
        for index in currentData.indices {
            if let id = currentData[index].persistentID {
                currentData[index].previousAmount = previousAmounts[id]
            }
        }

        return (currentData, previousTotal > 0 ? previousTotal : nil)
    }

    /// Calculate cash flow summary (excludes adjustments/initial balances)
    private func calculateCashFlowWidget(context: PanelCalculationContext) -> CashFlowSummary? {
        return CashFlowCalculator.calculateCashFlow(
            transactions: context.expenseFilteredTransactions,
            interval: context.effectiveInterval,
            grouping: context.cashFlowGrouping,
            currencyCode: context.defaultCurrencyCode,
            converter: context.converter
        )
    }

    /// Calculate latest records (excludes adjustments/initial balances)
    /// In expenses-only mode, also excludes income transactions.
    private func calculateLatestRecordsWidget(context: PanelCalculationContext) -> [TransactionItem]
    {
        var filtered = context.expenseFilteredTransactions
            .filter { context.effectiveInterval.contains($0.date) }

        // In expenses-only mode, exclude income transactions
        if SessionState.shared.isExpensesOnlyMode {
            filtered = filtered.filter { $0.category?.isIncome != true }
        }

        return Array(
            filtered
                .sorted {
                    return $0.createdAt > $1.createdAt
                }
                .prefix(5)
        )
    }

    /// Calculate need trend points with period comparison
    /// Uses needWidgetTransactions (has cat/subcat filters but NO need filter)
    /// This allows the need widget to show ALL needs with visual dimming
    /// Returns: (points, previousTotal, previousAmountsByNeed)
    private func calculateNeedWidget(context: PanelCalculationContext)
        -> (points: [NeedTrendPoint], previousTotal: Double?, previousAmounts: [SubcategoryNeed: Double])
    {
        let preferredCurrency = CurrencyCode(rawValue: context.defaultCurrencyCode) ?? .pen

        let currentPoints = NeedTrendHelper.calculateTrend(
            transactions: context.needWidgetTransactions,
            grouping: context.needGrouping,
            interval: context.effectiveInterval,
            preferredCurrency: preferredCurrency,
            converter: context.converter
        )

        // Skip previous period calculation for "All Time" (no meaningful comparison)
        guard context.period != .allTime else {
            return (currentPoints, nil, [:])
        }

        // Calculate previous period data for comparison
        let previousInterval = PreviousPeriodHelper.previousInterval(
            for: context.period,
            mode: .month,
            customRange: nil
        )

        // Filter transactions for previous period
        let previousTransactions = context.transactionsWithoutDateFilter.filter {
            previousInterval.contains($0.date)
        }

        let previousPoints = NeedTrendHelper.calculateTrend(
            transactions: previousTransactions,
            grouping: context.needGrouping,
            interval: previousInterval,
            preferredCurrency: preferredCurrency,
            converter: context.converter
        )

        // Calculate totals by need for previous period
        var prevNeedAmounts: [SubcategoryNeed: Double] = [:]
        var prevNeedTotal: Double = 0
        for point in previousPoints {
            prevNeedAmounts[.essential, default: 0] += point.essential
            prevNeedAmounts[.priority, default: 0] += point.priority
            prevNeedAmounts[.optional, default: 0] += point.optional
            prevNeedAmounts[.unclassified, default: 0] += point.unclassified
            prevNeedTotal += point.total
        }

        return (currentPoints, prevNeedTotal > 0 ? prevNeedTotal : nil, prevNeedAmounts)
    }

    // State for Filter Logic
    var isCategorySelectionImplicit: Bool = false

    // Helper to toggle Category explicitly (from Widget)
    func toggleCategoryFilter(_ id: PersistentIdentifier) {
        if selectedCategoryID == id {
            selectedCategoryID = nil
            isCategorySelectionImplicit = false
        } else {
            selectedCategoryID = id
            isCategorySelectionImplicit = false
        }
    }

    /// Multi-select toggle for the Panel's TagsPie widget. Reuses
    /// `selectedTags` (backed by `SessionState.shared.selectedTags`); the
    /// Panel's filter pipeline already propagates this selection to every
    /// widget via `buildPanelCalculationContext` + `FilterCriteria.selectedTags`.
    func toggleTagFilter(_ id: PersistentIdentifier) {
        if selectedTags.contains(id) {
            selectedTags.remove(id)
        } else {
            selectedTags.insert(id)
        }
    }

    // Helper to toggle subcategory (single-select behavior for widget interaction)
    // Changed from String (name) to PersistentIdentifier to handle duplicate names across categories
    func toggleSubcategoryFilter(
        _ subcategoryID: PersistentIdentifier,
        transactions: [TransactionItem],
        accounts: [Account],
        defaultCurrencyCode: String,
        context: ModelContext,
        sessionState: SessionState
    ) {
        if selectedSubcategoryIDs.contains(subcategoryID) && selectedSubcategoryIDs.count == 1 {
            // Deselect Subcategory (only if it's the only one selected)
            selectedSubcategoryIDs.removeAll()

            if isCategorySelectionImplicit {
                // If category was auto-selected (Scenario 1), clear it too -> "All"
                selectedCategoryID = nil
                isCategorySelectionImplicit = false
            }
            // If category was explicitly selected (Scenario 2), KEEP it -> "Category X"
        } else {
            // Select New Subcategory (single-select: clear others first)
            selectedSubcategoryIDs = [subcategoryID]

            // Find parent category for this subcategory by persistentID
            if let summary = topSubcategories.first(where: { $0.persistentID == subcategoryID }),
                let cat = summary.category
            {

                if selectedCategoryID == cat.persistentModelID {
                    // We are already in this category.
                    // Keep implicit state as is (if explicit, it stays explicit. matches "Scenario 2")
                } else {
                    // Switching to a NEW category context (Scenario 3 / 1)
                    self.selectedCategoryID = cat.persistentModelID
                    self.isCategorySelectionImplicit = true
                }
            }
        }

        // Recalculate immediately to ensure UI is in sync
        calculateTrendData(
            accounts: accounts,
            transactions: transactions,
            defaultCurrencyCode: defaultCurrencyCode,
            context: context,
            sessionState: sessionState
        )
    }

    /// Convenience for widget sections that don't have access to raw params
    func toggleSubcategoryFilterFromPanel(_ subcategoryID: PersistentIdentifier) {
        guard let sessionState, let context = modelContext else { return }
        toggleSubcategoryFilter(
            subcategoryID,
            transactions: transactions,
            accounts: accounts,
            defaultCurrencyCode: defaultCurrencyCode,
            context: context,
            sessionState: sessionState
        )
    }

    func toggleNeedFilter(_ need: SubcategoryNeed) {
        if selectedNeed == need {
            selectedNeed = nil
        } else {
            selectedNeed = need
        }
    }

    // MARK: - Exchange Rate Widget Logic

    /// Loads currency selection from secondaryCurrencies (onboarding/settings).
    /// This is the single source of truth for which currencies to display.
    private func loadExchangeRateCurrencySelection() {
        if let secondaryCurrenciesRaw = UserDefaults.standard.string(forKey: "secondaryCurrencies"),
           !secondaryCurrenciesRaw.isEmpty {
            let currencies = secondaryCurrenciesRaw
                .split(separator: ",")
                .compactMap { CurrencyCode(rawValue: String($0)) }

            selectedComparisonCurrencies = Array(currencies.prefix(2))
        } else {
            selectedComparisonCurrencies = []
        }
    }

    /// Reloads currencies from secondaryCurrencies when settings change
    private func reloadCurrenciesFromSettings() {
        loadExchangeRateCurrencySelection()
    }


    /// Calculates exchange rate data for the widget.
    func calculateExchangeRateData(
        preferredCurrencyCode: String,
        context: ModelContext
    ) {
        let preferredCurrency = CurrencyCode(rawValue: preferredCurrencyCode) ?? .pen

        // Only calculate rates for user-selected secondary currencies (2-3 max)
        // instead of all 47 currencies — huge performance win
        let targetCurrencies = selectedComparisonCurrencies.filter { $0 != preferredCurrency }

        // Determine grouping based on period
        let newGrouping: TrendGrouping = switch selectedPeriod {
        case .thisWeek, .last7Days: .day
        case .thisMonth, .lastMonth, .last30Days: .week
        default: .month
        }

        // For "All Time", use the actual stored data range instead of 10 years
        let interval: DateInterval
        if selectedPeriod == .allTime {
            if let storedRange = exchangeRateService.getStoredDateRange(context: context) {
                interval = storedRange
            } else {
                interval = panelDateInterval
            }
        } else {
            interval = panelDateInterval
        }

        // Get the latest rate for current display
        let latestRate = exchangeRateService.getLatestRate(context: context)

        guard let latestRate = latestRate else {
            let newER = PanelExchangeRateData(
                exchangeRateWidgetData: ExchangeRateWidgetData(
                    preferredCurrency: preferredCurrencyCode,
                    errorMessage: L10n.ExchangeRate.loadError
                ),
                exchangeRateGrouping: newGrouping
            )
            if newER != exchangeRateWidget { exchangeRateWidget = newER }
            return
        }

        // Calculate current rates for selected comparison currencies only
        let currentRates = ExchangeRateWidgetHelper.calculateRatesFromPreferred(
            preferredCurrency: preferredCurrencyCode,
            targetCurrencies: targetCurrencies.map { $0.rawValue },
            exchangeRate: latestRate
        )

        // Use API timestamp if available, otherwise fall back to parsing dateKey
        let currentRatesDate: Date =
            latestRate.timestamp
            ?? {
                Self.dateKeyFormatter.date(from: latestRate.dateKey) ?? Date.now
            }()

        // Build chart points for selected comparison currencies only
        let chartPoints = ExchangeRateWidgetHelper.buildChartPoints(
            interval: interval,
            grouping: newGrouping,
            preferredCurrency: preferredCurrencyCode,
            targetCurrencies: targetCurrencies.map { $0.rawValue },
            context: context
        )

        let newER = PanelExchangeRateData(
            exchangeRateWidgetData: ExchangeRateWidgetData(
                preferredCurrency: preferredCurrencyCode,
                currentRates: currentRates,
                currentRatesDate: currentRatesDate,
                chartPoints: chartPoints
            ),
            exchangeRateGrouping: newGrouping
        )
        if newER != exchangeRateWidget { exchangeRateWidget = newER }
    }

    /// Updates the selected comparison currencies.
    func updateComparisonCurrencies(_ currencies: [CurrencyCode]) {
        // Limit to max 2
        selectedComparisonCurrencies = Array(currencies.prefix(2))
    }

    // MARK: - Budgets Widget Calculation

    /// Calculate budget summaries for the widget (favorite budgets first, then active)
    func calculateBudgetsWidget(
        budgets: [Budget],
        transactions: [TransactionItem],
        defaultCurrencyCode: String,
        excludedCategoryIDs: Set<PersistentIdentifier> = [],
        excludedSubcategoryIDs: Set<PersistentIdentifier> = []
    ) {
        // Check if there are budgets but none are favorites
        let hasBudgets = !budgets.isEmpty
        let favoriteBudgets = budgets.filter { $0.isFavorite }
        let newHasBudgetsButNoFavorites = hasBudgets && favoriteBudgets.isEmpty

        // Get budgets to display: favorites first (sorted by order), then fill with active non-favorites
        let sortedFavorites = favoriteBudgets.sorted { $0.favoriteOrder < $1.favoriteOrder }

        // Calculate summaries for favorite budgets
        let summaries = sortedFavorites.compactMap { budget -> BudgetSummary? in
            calculateBudgetSummary(
                budget: budget,
                transactions: transactions,
                defaultCurrencyCode: defaultCurrencyCode,
                excludedCategoryIDs: excludedCategoryIDs,
                excludedSubcategoryIDs: excludedSubcategoryIDs
            )
        }

        let newBudgets = PanelBudgetsData(
            topBudgetSummaries: summaries,
            hasBudgetsButNoFavorites: newHasBudgetsButNoFavorites
        )
        if newBudgets != budgetsWidget { budgetsWidget = newBudgets }
    }

    /// Calculate summary for a single budget
    private func calculateBudgetSummary(
        budget: Budget,
        transactions: [TransactionItem],
        defaultCurrencyCode: String,
        excludedCategoryIDs: Set<PersistentIdentifier> = [],
        excludedSubcategoryIDs: Set<PersistentIdentifier> = []
    ) -> BudgetSummary? {
        // Get budget period date interval
        let interval = getBudgetDateInterval(budget: budget)

        // Filter transactions by date
        var filtered = transactions.filter { interval.contains($0.date) }

        // Apply session exclude filters (user-excluded categories/subcategories)
        if !excludedCategoryIDs.isEmpty || !excludedSubcategoryIDs.isEmpty {
            filtered = filtered.filter { transaction in
                if !excludedCategoryIDs.isEmpty,
                   let catID = transaction.category?.persistentModelID,
                   excludedCategoryIDs.contains(catID) { return false }
                if !excludedSubcategoryIDs.isEmpty,
                   let subID = transaction.subcategory?.persistentModelID,
                   excludedSubcategoryIDs.contains(subID) { return false }
                return true
            }
        }

        // Apply budget filters

        // Account filter
        if let accounts = budget.accounts, !accounts.isEmpty {
            let accountIDs = Set(accounts.map { $0.persistentModelID })
            filtered = filtered.filter { transaction in
                if let accountID = transaction.account?.persistentModelID {
                    return accountIDs.contains(accountID)
                }
                return false
            }
        }

        // Subcategory filter
        if let subcategories = budget.subcategories, !subcategories.isEmpty {
            let subIDs = Set(subcategories.map { $0.persistentModelID })
            filtered = filtered.filter { transaction in
                if let subID = transaction.subcategory?.persistentModelID {
                    return subIDs.contains(subID)
                }
                return false
            }
        }

        // Tag filter
        if let budgetTags = budget.tags, !budgetTags.isEmpty {
            let tagIDs = Set(budgetTags.map { $0.persistentModelID })
            filtered = filtered.filter { transaction in
                let transactionTagIDs = Set((transaction.tags ?? []).map { $0.persistentModelID })
                return !transactionTagIDs.isDisjoint(with: tagIDs)
            }
        }

        // Need filter
        if let naturesString = budget.natures, !naturesString.isEmpty {
            let natures = naturesString.split(separator: ",")
                .compactMap { SubcategoryNeed(rawValue: String($0).trimmingCharacters(in: .whitespaces)) }

            filtered = filtered.filter { transaction in
                natures.contains(transaction.effectiveNeed)
            }
        }

        // Only count expenses (not income)
        filtered = filtered.filter { $0.category?.isIncome == false }

        // Sum amounts in budget's currency
        let spent = filtered.reduce(0.0) { sum, transaction in
            let amount: Double
            if transaction.currencyCode == budget.currencyCode {
                // Same currency as budget — use original amount
                amount = transaction.amount
            } else if transaction.preferredCurrencyCode == budget.currencyCode {
                // Preferred currency matches budget — use pre-converted amount
                amount = transaction.amountInPreferredCurrency
            } else if let _ = modelContext,
                      let fromCode = CurrencyCode(rawValue: transaction.currencyCode),
                      let toCode = CurrencyCode(rawValue: budget.currencyCode) {
                // Different currency — convert using latest rates
                let converted = convertToPreferredCurrency(
                    amount: Decimal(transaction.amount),
                    from: fromCode,
                    to: toCode
                )
                amount = NSDecimalNumber(decimal: converted).doubleValue
            } else {
                amount = transaction.amount
            }
            return sum + abs(amount)
        }

        let percentage = budget.limitAmount > 0 ? (spent / budget.limitAmount) * 100.0 : 0.0
        let daysRemaining = getBudgetDaysRemaining(budget: budget, interval: interval)
        let status = getBudgetStatus(budget: budget, spending: spent)
        let (icon, color) = budget.displayProperties

        return BudgetSummary(
            budget: budget,
            spent: spent,
            percentage: percentage,
            daysRemaining: daysRemaining,
            status: status,
            icon: icon,
            color: color
        )
    }

    /// Get date interval for a budget period
    private func getBudgetDateInterval(budget: Budget) -> DateInterval {
        let calendar = Calendar.current

        guard let periodType = BudgetPeriodType(rawValue: budget.periodType) else {
            let start = calendar.startOfMonth(for: Date.now)
            let end = calendar.date(byAdding: .month, value: 1, to: start) ?? start
            return DateInterval(start: start, end: end)
        }

        switch periodType {
        case .weekly:
            let weekStart = calendar.startOfWeek(for: Date.now)
            let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
            return DateInterval(start: weekStart, end: weekEnd)

        case .monthly:
            let monthStart = calendar.startOfMonth(for: Date.now)
            let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart
            return DateInterval(start: monthStart, end: monthEnd)

        case .yearly:
            let year = calendar.component(.year, from: Date.now)
            let yearStart = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) ?? Date.now
            let yearEnd = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1)) ?? yearStart
            return DateInterval(start: yearStart, end: yearEnd)

        case .unique:
            guard let start = budget.startDate, let end = budget.endDate else {
                let monthStart = calendar.startOfMonth(for: Date.now)
                let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart
                return DateInterval(start: monthStart, end: monthEnd)
            }
            return DateInterval(start: start, end: end)
        }
    }

    /// Calculate days remaining in budget period
    private func getBudgetDaysRemaining(budget: Budget, interval: DateInterval) -> Int {
        let calendar = Calendar.current
        let today = Date.now

        if today > interval.end {
            return -1  // Period has ended
        }

        guard interval.contains(today) else { return 0 }

        let components = calendar.dateComponents([.day], from: today, to: interval.end)
        return max(0, components.day ?? 0)
    }

    /// Determine budget status
    private func getBudgetStatus(budget: Budget, spending: Double) -> BudgetStatus {
        guard budget.isActive else { return .inactive }
        return spending >= budget.limitAmount ? .exceeded : .active
    }

    /// Get display properties for budget

    // MARK: - Recalculation (moved from PanelView)

    /// Update default currency code — called from PanelView when @AppStorage changes
    func updateDefaultCurrencyCode(_ code: String) {
        defaultCurrencyCode = code
    }

    /// Set background state — suppresses recalculation to prevent 0x8BADF00D
    func setBackground(_ value: Bool) {
        isInBackground = value
        if value {
            recalculateTask?.cancel()
            recalculateTask = nil
            pendingReload = false
        }
    }

    /// Cancel any pending recalculation
    func cancelRecalculation() {
        recalculateTask?.cancel()
    }

    /// Debounced recalculation (150ms) — coalesces rapid onChange cascades.
    /// Does NOT reload from SwiftData — filter changes only need recalculation.
    func recalculateData() {
        scheduleRecalculation(reload: false)
    }

    // MARK: - Practice Cleanup

    func deletePracticeItem(_ item: PracticeCleanupItem) {
        guard let ctx = modelContext else { return }
        do {
            for pid in item.allPersistentIDs {
                switch item.kind {
                case .transaction: try deletePracticeModel(TransactionItem.self, id: pid, context: ctx)
                case .draft: try deletePracticeModel(InboxDraft.self, id: pid, context: ctx)
                case .budget: try deletePracticeModel(Budget.self, id: pid, context: ctx)
                case .scheduledPayment: try deletePracticeModel(ScheduledPayment.self, id: pid, context: ctx)
                }
            }
            try ctx.save()
        } catch {
            #if DEBUG
            print("SetupChecklist: Error deleting practice item: \(error)")
            #endif
        }
    }

    private func deletePracticeModel<T: PersistentModel>(_ type: T.Type, id: PersistentIdentifier, context: ModelContext) throws {
        let all = try context.fetch(FetchDescriptor<T>())
        guard let match = all.first(where: { $0.persistentModelID == id }) else {
            #if DEBUG
            print("SetupChecklist: Practice \(T.self) not found — ID mismatch")
            #endif
            return
        }
        context.delete(match)
    }

    /// Debounced reload + recalculation — used when actual data may have changed
    func reloadAndRecalculate() {
        scheduleRecalculation(reload: true)
    }

    /// Shared debounce (150ms). `pendingReload` ensures a reload request isn't lost
    /// if a subsequent calculate-only call arrives within the debounce window.
    /// Guarded by isInBackground to prevent 0x8BADF00D during snapshot capture.
    private func scheduleRecalculation(reload: Bool) {
        guard !isInBackground else { return }
        guard UIApplication.shared.applicationState == .active else { return }
        if reload { pendingReload = true }
        recalculateTask?.cancel()
        recalculateTask = Task { @MainActor in
            do { try await Task.sleep(for: .milliseconds(150)) } catch { return }
            guard !Task.isCancelled else { return }
            let shouldReload = pendingReload
            pendingReload = false
            if shouldReload {
                loadData()
            }
            performCalculation()
        }
    }

    /// Runs all widget calculations from cached data (no SwiftData fetch).
    private func performCalculation() {
        guard let sessionState, let context = modelContext else { return }
        calculateTrendData(
            accounts: accounts,
            transactions: transactions,
            defaultCurrencyCode: defaultCurrencyCode,
            context: context,
            sessionState: sessionState
        )
        if isWidgetVisible(.budgets) {
            calculateBudgetsWidget(
                budgets: budgets,
                transactions: transactions,
                defaultCurrencyCode: defaultCurrencyCode,
                excludedCategoryIDs: sessionState.isExcludeMode ? sessionState.selectedCategoryIDs : [],
                excludedSubcategoryIDs: sessionState.isExcludeMode ? sessionState.selectedSubcategoryIDs : []
            )
        }
        // Shared paidAmounts fetch between the scheduled-payments widget and the
        // Salud Financiera section when both target the current calendar month.
        // If they target different months (e.g. user navigating planification to a
        // past month), each section falls back to its own fetch.
        let scheduledVisible = isWidgetVisible(.scheduledPayments)
        let healthVisible = isSectionVisible(.health)
        var sharedPaidAmounts: [String: [PaidOccurrenceInfo]]? = nil
        let calendar = Calendar.current
        let currentMonthInterval = calendar.dateInterval(of: .month, for: .now)
        let currentMonthStart = currentMonthInterval?.start
        let planMonthStart = calendar.dateInterval(of: .month, for: scheduledPaymentsDisplayMonth)?.start
        let canShareFetch = scheduledVisible
            && healthVisible
            && currentMonthStart != nil
            && currentMonthStart == planMonthStart

        // Cache the filter once — used by both fetch branches below.
        let activePayments: [ScheduledPayment] = (canShareFetch || healthVisible)
            ? scheduledPayments.filter { $0.isActive }
            : []

        if canShareFetch, let monthStart = currentMonthStart {
            sharedPaidAmounts = ScheduledPaymentPaidStatusHelper.loadPaidAmounts(
                for: activePayments, month: monthStart, context: context
            )
        }

        if scheduledVisible {
            calculateScheduledPaymentsWidget(injectedPaidAmounts: sharedPaidAmounts)
        }

        if healthVisible {
            let paidForHealth: [String: [PaidOccurrenceInfo]]
            if let shared = sharedPaidAmounts {
                paidForHealth = shared
            } else if let monthStart = currentMonthStart {
                paidForHealth = ScheduledPaymentPaidStatusHelper.loadPaidAmounts(
                    for: activePayments, month: monthStart, context: context
                )
            } else {
                paidForHealth = [:]
            }
            calculateHealthWidget(paidAmounts: paidForHealth)
        }

        calculateAccountPeriodExpenses()
        // Hero always computes — it replaces the Panel title and cannot be
        // hidden (see epic out-of-scope). Cheap O(n) pass over `transactions`;
        // the equality guard in `calculateHeroWidget()` suppresses no-op
        // @Observable notifications when the data hasn't changed.
        calculateHeroWidget(monthInterval: currentMonthInterval)
    }

    private func calculateWeekdayWidget(context: PanelCalculationContext) {
        let spending = WeekdaySpendingCalculator.calculate(
            transactions: context.filteredTransactions,
            interval: context.effectiveInterval,
            currencyCode: context.defaultCurrencyCode,
            converter: currencyConverter
        )
        let newData = PanelWeekdayData(weekdaySpending: spending)
        if newData != weekdayWidget { weekdayWidget = newData }
    }

    /// TagsPie widget (Distribución). Enriches each tag summary with its
    /// previous-period amount (mirrors `calculateCategoriesWidget`/`calculateSubcategoriesWidget`)
    /// so the pie shows per-tag variation — otherwise the second calculation
    /// would be pure waste.
    private func calculateTagsWidget(context: PanelCalculationContext) {
        var currentData = TagSpendingCalculator.calculateTopSpending(
            transactions: context.filteredTransactions,
            interval: context.effectiveInterval,
            currencyCode: context.defaultCurrencyCode
        )

        guard context.period != .allTime else {
            let newData = PanelTagsData(topTags: currentData, previousTotalAmount: nil)
            if newData != tagsWidget { tagsWidget = newData }
            return
        }

        let previousInterval = PreviousPeriodHelper.previousInterval(
            for: context.period,
            mode: .month,
            customRange: nil
        )
        let previousTransactions = context.transactionsWithoutDateFilter.filter {
            previousInterval.contains($0.date)
        }
        let previousData = TagSpendingCalculator.calculateTopSpending(
            transactions: previousTransactions,
            interval: previousInterval,
            currencyCode: context.defaultCurrencyCode
        )

        let previousTotal = previousData.reduce(0) { $0 + $1.amount }
        let previousAmounts = Dictionary(
            uniqueKeysWithValues: previousData.map { ($0.tag.persistentModelID, $0.amount) }
        )
        for index in currentData.indices {
            currentData[index].previousAmount = previousAmounts[currentData[index].tag.persistentModelID]
        }

        let newData = PanelTagsData(
            topTags: currentData,
            previousTotalAmount: previousTotal > 0 ? previousTotal : nil
        )
        if newData != tagsWidget { tagsWidget = newData }
    }

    /// Mode is `.year` for `.thisYear`, `.month` otherwise. `.allTime` disables
    /// the comparison (no bounded previous interval). Metric mirrors the trend
    /// chart via `SessionState.selectedTrendMetric`, forced to `.expense` when
    /// `isExpensesOnlyMode` is active.
    private func calculatePeriodComparisonWidget(context: PanelCalculationContext) {
        guard context.period != .allTime else {
            let newData = PanelPeriodComparisonData(supportsComparison: false)
            if newData != periodComparisonWidget { periodComparisonWidget = newData }
            return
        }

        let session = SessionState.shared
        let metric: TrendMetric = session.isExpensesOnlyMode ? .expense : session.selectedTrendMetric
        let trendType = convertMetricToTrendType(metric)
        let isBalance = (trendType == .balance)
        let mode: ComparisonMode = context.period == .thisYear ? .year : .month

        let previousInterval = PreviousPeriodHelper.previousInterval(
            for: context.period,
            mode: mode,
            customRange: session.customDateRange
        )

        let currentTxs: [TransactionItem]
        let previousTxs: [TransactionItem]
        if isBalance {
            // Running balance requires all transactions without date filter
            currentTxs = context.balanceTransactions
            previousTxs = context.balanceTransactions
        } else {
            currentTxs = context.filteredTransactions
            previousTxs = context.transactionsWithoutDateFilter.filter {
                previousInterval.contains($0.date)
            }
        }

        let currentResult = TrendDataProcessor.processTrendData(
            transactions: currentTxs,
            accounts: context.eligibleAccounts,
            metric: trendType,
            period: context.period,
            grouping: .day,
            interval: context.effectiveInterval,
            currencyCode: context.defaultCurrencyCode
        )

        let previousResult = TrendDataProcessor.processTrendData(
            transactions: previousTxs,
            accounts: context.eligibleAccounts,
            metric: trendType,
            period: context.period,
            grouping: .day,
            interval: previousInterval,
            currencyCode: context.defaultCurrencyCode
        )

        let allValues = currentResult.points.map(\.value) + previousResult.points.map(\.value)
        let yDomain: ClosedRange<Double>
        if let minV = allValues.min(), let maxV = allValues.max() {
            let padding = (maxV - minV) * 0.1
            yDomain = (minV - padding)...(maxV + padding)
        } else {
            yDomain = 0...1
        }

        let currentTotal = currentResult.points.last?.value ?? 0
        let previousTotal: Double? = previousResult.points.isEmpty
            ? nil
            : (previousResult.points.last?.value ?? 0)

        let newData = PanelPeriodComparisonData(
            currentPoints: currentResult.points,
            previousPoints: previousResult.points,
            yDomain: yDomain,
            currentInterval: context.effectiveInterval,
            previousInterval: previousInterval,
            grouping: .day,
            comparisonMode: mode,
            trendType: trendType,
            period: context.period,
            currentTotal: currentTotal,
            previousTotal: previousTotal,
            supportsComparison: true
        )
        if newData != periodComparisonWidget { periodComparisonWidget = newData }
    }

    /// Pre-computes the Financial Score for the Panel 2.0 "Salud Financiera" section.
    /// Called from `performCalculation()` only when `.health` section is visible.
    private func calculateHealthWidget(paidAmounts: [String: [PaidOccurrenceInfo]]) {
        let newScore = FinancialScoreCalculator.calculate(
            transactions: transactions,
            budgets: budgets,
            scheduledPayments: scheduledPayments,
            paidAmounts: paidAmounts
        )
        let newData = PanelHealthData(score: newScore)
        if newData != healthWidget { healthWidget = newData }
    }

    /// Pre-computes the Hero del mes payload (P20-04).
    ///
    /// Runs on every `performCalculation()` because the Hero replaces the
    /// Panel title and is always visible. It stays cheap:
    ///  - single O(n) pass over `transactions` restricted to the current
    ///    calendar month,
    ///  - zero new fetches (all models are already loaded),
    ///  - uses `TransactionItem.amountInPreferredCurrency` — the snapshot
    ///    conversion already persisted on each transaction, so there is no
    ///    live call to `CurrencyConverter` here.
    /// Only budgets with `periodType == "monthly"` feed the total; mixing
    /// weekly/yearly would distort the ratio. Pro-rating other periodicities
    /// is a future refinement tracked in the epic.
    private func calculateHeroWidget(monthInterval: DateInterval?) {
        guard let monthInterval else { return }

        // Mes anterior natural — independiente del selectedPeriod del Panel,
        // el Hero siempre compara contra el mes calendario anterior.
        let prevStart = Calendar.current.date(byAdding: .month, value: -1, to: monthInterval.start) ?? monthInterval.start
        let prevInterval = DateInterval(start: prevStart, end: monthInterval.start)

        var monthIncome: Double = 0
        var monthExpense: Double = 0
        var prevExpense: Double = 0
        var prevHasAnyTx = false
        for tx in transactions where tx.balanceAdjustmentType == nil {
            let amount = abs(tx.amountInPreferredCurrency)
            let isIncome = tx.category?.isIncome == true
            if monthInterval.contains(tx.date) {
                if isIncome { monthIncome += amount } else { monthExpense += amount }
            } else if prevInterval.contains(tx.date) {
                prevHasAnyTx = true
                if !isIncome { prevExpense += amount }
            }
        }

        let totalMonthlyBudget = budgets
            .filter { $0.periodType == "monthly" }
            .reduce(0.0) { $0 + $1.limitAmount }

        let newData = HeroMonthCalculator.calculate(
            monthIncome: monthIncome,
            monthExpense: monthExpense,
            totalMonthlyBudget: totalMonthlyBudget
        )
        let wrapped = PanelHeroData(data: newData)
        let dataChanged = wrapped != heroWidget
        if dataChanged { heroWidget = wrapped }

        lastHeroTrendContext = TrendContext(
            prevExpense: prevExpense,
            prevHasAnyTx: prevHasAnyTx,
            totalMonthlyBudget: totalMonthlyBudget,
            monthInterval: monthInterval
        )

        // Re-generar IA solo cuando la data del hero cambió — evita spam de
        // telemetry cuando performCalculation corre múltiples veces.
        if dataChanged {
            generateHeroAIIfEligible(data: newData)
        }
    }

    // MARK: - Hero IA

    /// Snapshot de los agregados del mes anterior + budget que necesita
    /// `generateHeroAIIfEligible`. Recalculado en cada `calculateHeroWidget`
    /// para que `retriggerHeroAI` (invocado por observadores de consent/Pro)
    /// no tenga que re-iterar `transactions`.
    private struct TrendContext {
        let prevExpense: Double
        let prevHasAnyTx: Bool
        let totalMonthlyBudget: Double
        let monthInterval: DateInterval
    }

    private var lastHeroTrendContext: TrendContext?

    /// Cache-key único de telemetría; `trackOnce` dedupea por sesión.
    private static let heroTelemetryKey = "panelHero"

    /// Task en vuelo — permite cancelar la anterior si llega otro trigger
    /// (evita last-writer-wins stale cuando Pro/consent togglean en rápido).
    private var heroAITask: Task<Void, Never>?

    /// Reintenta la generación del mensaje IA usando el último `heroWidget`
    /// computado. Lo llaman los observers de `PanelView` cuando cambia
    /// consent o estado Pro.
    func retriggerHeroAI() {
        guard let data = heroWidget.data else { return }
        generateHeroAIIfEligible(data: data)
    }

    /// Genera el mensaje IA si el usuario es Pro + tiene consent. Free o Pro
    /// sin consent quedan en rule-based silencioso (`heroAISubtitle = nil`).
    private func generateHeroAIIfEligible(data: HeroMonthData) {
        guard FeatureGateService.shared.canAccess(.smartInsightsAI),
              appPreferences?.aiInsightsConsentAccepted == true,
              let trend = lastHeroTrendContext else {
            heroAITask?.cancel()
            heroAITask = nil
            heroAISubtitle = nil
            return
        }

        let ctx = buildHeroContext(data: data, trend: trend)

        if let cached = HeroMessageCache.read(),
           cached.hash == HeroMessageCache.contextHash(ctx) {
            heroAISubtitle = cached.text
            TelemetryService.trackOnce(.panelHeroAICacheHit, key: Self.heroTelemetryKey)
            return
        }

        heroAITask?.cancel()
        heroAITask = Task { [weak self] in
            guard let self else { return }
            do {
                let text = try await InsightsLLMService.shared.generateHeroMessage(context: ctx)
                guard !Task.isCancelled else { return }
                self.heroAISubtitle = text
                TelemetryService.track(.panelHeroAIGenerated)
            } catch {
                guard !Task.isCancelled else { return }
                self.heroAISubtitle = nil
            }
        }
    }

    /// Construye el `HeroContext` a partir de los agregados ya calculados en
    /// `calculateHeroWidget`. Cero fetches y cero iteraciones extra.
    private func buildHeroContext(data: HeroMonthData, trend: TrendContext) -> HeroContext {
        let spendingTrend: HeroSpendingTrend?
        if !trend.prevHasAnyTx || trend.prevExpense <= 0 {
            spendingTrend = nil
        } else {
            let ratio = data.expense / trend.prevExpense
            if ratio > 1.05 { spendingTrend = .up }
            else if ratio < 0.95 { spendingTrend = .down }
            else { spendingTrend = .flat }
        }

        let percentBudget: Double? = trend.totalMonthlyBudget > 0
            ? data.expense / trend.totalMonthlyBudget
            : nil

        let rawName = appPreferences?.userName ?? ""
        let userName: String? = rawName.isEmpty ? nil : rawName

        return HeroContext(
            state: data.state,
            financialScore: healthWidget.score.flatMap(\.total),
            percentBudgetUsed: percentBudget,
            spendingTrend: spendingTrend,
            monthName: Self.monthNameFormatter.string(from: trend.monthInterval.start).localizedCapitalized,
            userName: userName,
            daysRemaining: data.daysRemaining,
            locale: AppLocale.current.identifier
        )
    }

    private static let monthNameFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = AppLocale.current
        f.dateFormat = "MMMM"
        return f
    }()

    /// Pre-computes total account balances (not period-dependent).
    /// Called from loadData() — only when transactions actually change.
    private func calculateAccountBalances() {
        let batchBalances = AccountBalanceCalculator.batchCalculateBalances(
            accounts: accounts,
            transactions: transactions
        )
        let newBalances = batchBalances.mapValues { ($0 as NSDecimalNumber).doubleValue }
        if newBalances != accountBalances { accountBalances = newBalances }
    }

    /// Pre-computes period-specific expenses per account (expenses-only mode).
    /// Called from performCalculation() — recalculates on period/filter changes.
    private func calculateAccountPeriodExpenses() {
        let interval = panelDateInterval
        var newExpenses: [PersistentIdentifier: Double] = [:]
        for account in accounts {
            newExpenses[account.persistentModelID] = 0
        }
        for transaction in transactions {
            guard let account = transaction.account else { continue }
            let accountID = account.persistentModelID
            guard newExpenses[accountID] != nil else { continue }
            guard interval.contains(transaction.date) else { continue }
            guard transaction.balanceAdjustmentType == nil else { continue }
            guard transaction.category?.isIncome == false else { continue }
            newExpenses[accountID] = (newExpenses[accountID] ?? 0) + abs(transaction.amount)
        }
        if newExpenses != accountPeriodExpenses { accountPeriodExpenses = newExpenses }
    }

    // MARK: - Scheduled Payments Widget Calculation

    /// Display month derived from selectedPeriod — mirrors logic previously in ScheduledPaymentsWidget.
    private var scheduledPaymentsDisplayMonth: Date {
        let calendar = Calendar.current
        let now = Date.now
        switch selectedPeriod {
        case .thisWeek, .last7Days, .last30Days, .thisMonth:
            return now
        case .lastMonth:
            return calendar.date(byAdding: .month, value: -1, to: now) ?? now
        case .thisYear:
            return now
        case .lastYear:
            return calendar.date(byAdding: .year, value: -1, to: now) ?? now
        case .allTime:
            return now
        case .custom:
            return customDateRange?.start ?? now
        }
    }

    private func formatScheduledDueDate(days: Int, date: Date) -> String {
        if days < 0 {
            return String(format: L10n.Scheduled.Widget.daysAgo, abs(days))
        } else if days == 0 {
            return L10n.Date.today
        } else if days == 1 {
            return L10n.Scheduled.Widget.tomorrow
        } else if days <= 7 {
            return String(format: L10n.Scheduled.Widget.inDays, days)
        } else {
            return Self.shortDateFormatter.string(from: date)
        }
    }

    /// Pre-computes all scheduled payments widget data from cached models.
    /// Called from performCalculation() — runs outside the SwiftUI render pass.
    ///
    /// - Parameter injectedPaidAmounts: Optional pre-computed paidAmounts map. When provided,
    ///   skips the internal fetch and uses the injected value. Used by `performCalculation()`
    ///   to share the fetch with `calculateHealthWidget()` when both sections are visible and
    ///   they target the same month. Pass `nil` to preserve the original (self-fetch) behavior.
    private func calculateScheduledPaymentsWidget(
        injectedPaidAmounts: [String: [PaidOccurrenceInfo]]? = nil
    ) {
        guard let context = modelContext else { return }

        let displayMonth = scheduledPaymentsDisplayMonth
        let calendar = Calendar.current

        // 1. Filter payments (replaces widget's filteredPayments computed property)
        let filtered: [ScheduledPayment]
        if let categoryFilter = scheduledPaymentsWidgetFilter.paymentCategoryFilter {
            filtered = scheduledPayments.filter { $0.isActive && $0.paymentCategory == categoryFilter }
        } else {
            filtered = scheduledPayments.filter { $0.isActive }
        }

        // 2. Load paid amounts (use injected if provided to share with health section,
        // else fetch — moves from widget's .task(id:) to here)
        let paidAmounts: [String: [PaidOccurrenceInfo]] = injectedPaidAmounts
            ?? ScheduledPaymentPaidStatusHelper.loadPaidAmounts(
                for: filtered, month: displayMonth, context: context
            )

        // 3. Calculate monthly total (moves from widget's calculateMonthlyTotal())
        var monthlyTotal: Double = 0
        if calendar.dateInterval(of: .month, for: displayMonth) != nil {
            let converter = currencyConverter
            let expensePayments = filtered.filter { $0.transactionType != "income" }

            for payment in expensePayments {
                let occurrences = ScheduledPaymentDateCalculator.paymentDatesInMonth(
                    params: payment.dateCalculatorParams, month: displayMonth
                )
                var remainingInfos = paidAmounts[payment.id.uuidString] ?? []

                for date in occurrences.sorted() {
                    let isSkipped = payment.isDateSkipped(date)
                    let amount: Double
                    let currency: String
                    if !remainingInfos.isEmpty && !isSkipped {
                        let info = remainingInfos.removeFirst()
                        amount = info.amount
                        currency = info.currencyCode
                    } else if !isSkipped {
                        amount = payment.amount
                        currency = payment.currencyCode
                    } else {
                        continue
                    }

                    if currency != defaultCurrencyCode, amount > 0 {
                        let converted = converter.convertWithLatestRate(
                            Decimal(amount),
                            from: currency,
                            to: defaultCurrencyCode,
                            context: context
                        )
                        monthlyTotal += NSDecimalNumber(decimal: converted).doubleValue
                    } else {
                        monthlyTotal += amount
                    }
                }
            }
        }

        // 4. Build upcoming payments list (moves from widget's getUpcomingPayments())
        let today = calendar.startOfDay(for: Date.now)
        var listItems: [ScheduledPaymentListItem] = []

        for payment in filtered {
            let dates = ScheduledPaymentDateCalculator.paymentDatesInMonth(
                params: payment.dateCalculatorParams, month: displayMonth
            )
            let paidCount = paidAmounts[payment.id.uuidString]?.count ?? 0
            var remainingPaid = paidCount

            let icon = payment.subcategory?.iconName
                ?? payment.subcategory?.category?.iconName
                ?? (payment.paymentCategory == PaymentCategory.subscription.rawValue
                    ? PaymentCategory.subscription.iconName
                    : PaymentCategory.recurring.iconName)
            let color = payment.subcategory?.colorHex
                ?? payment.subcategory?.category?.colorHex
                ?? AppConstants.defaultColorHex

            for date in dates.sorted() {
                let dueDate = calendar.startOfDay(for: date)
                let days = calendar.dateComponents([.day], from: today, to: dueDate).day ?? 0
                let dueStatus: DueStatus = days < 0 ? .past : (days == 0 ? .today : .upcoming)
                let isSkipped = payment.isDateSkipped(date)
                let isPaid = remainingPaid > 0 && !isSkipped
                if isPaid { remainingPaid -= 1 }

                listItems.append(ScheduledPaymentListItem(
                    id: "\(payment.persistentModelID)-\(date.timeIntervalSince1970)",
                    name: payment.name,
                    amount: payment.amount,
                    currencyCode: payment.currencyCode,
                    isIncome: payment.transactionType == "income",
                    isVariableAmount: payment.isVariableAmount,
                    icon: icon,
                    color: color,
                    dueDate: dueDate,
                    dueStatus: dueStatus,
                    dueDateLabel: formatScheduledDueDate(days: days, date: date),
                    isPaid: isPaid,
                    isSkipped: isSkipped
                ))
            }
        }

        // Filter to pending only, sort by date, limit to 3
        let upcomingPayments = Array(
            listItems
                .filter { !$0.isPaid && !$0.isSkipped }
                .sorted { $0.dueDate < $1.dueDate }
                .prefix(3)
        )

        // 5. Build calendar paymentsByDay (moves from widget's calendarGrid)
        var paymentsByDay: [Int: [ScheduledPaymentCalendarEntry]] = [:]
        for payment in filtered {
            let dates = ScheduledPaymentDateCalculator.paymentDatesInMonth(
                params: payment.dateCalculatorParams, month: displayMonth
            ).sorted()
            let paidCount = paidAmounts[payment.id.uuidString]?.count ?? 0
            var remainingPaid = paidCount

            for date in dates {
                let day = calendar.component(.day, from: date)
                let isSkipped = payment.isDateSkipped(date)
                let isPaid = remainingPaid > 0 && !isSkipped
                if isPaid { remainingPaid -= 1 }
                paymentsByDay[day, default: []].append(ScheduledPaymentCalendarEntry(
                    id: "\(payment.persistentModelID)-\(date.timeIntervalSince1970)",
                    name: payment.name,
                    isPaid: isPaid,
                    isSkipped: isSkipped
                ))
            }
        }

        // 6. Assemble and compare
        let newData = PanelScheduledPaymentsData(
            monthlyTotal: monthlyTotal,
            activeCount: filtered.count,
            displayMonth: displayMonth,
            periodLabel: Self.monthYearFormatter.string(from: displayMonth).capitalized,
            upcomingPayments: upcomingPayments,
            paymentsByDay: paymentsByDay
        )
        if newData != scheduledPaymentsWidget { scheduledPaymentsWidget = newData }
    }
}

// MARK: - Calendar Extension for Budget Calculations

