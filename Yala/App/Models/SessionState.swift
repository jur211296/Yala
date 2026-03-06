//
//  SessionState.swift
//  Yala
//
//  Created by Yala Refactoring.
//

import SwiftData
import SwiftUI
import WidgetKit

// MARK: - Inbox Notification Types

/// Types of drafts pending notification
struct PendingInboxNotification {
    var scheduledPayments: Int = 0
    var subscriptions: Int = 0
    var automations: Int = 0  // applePay + automation

    var total: Int { scheduledPayments + subscriptions + automations }
    var isEmpty: Bool { total == 0 }

    /// Builds breakdown message for mixed type
    /// Example: "2 pagos planificados y 3 registros automáticos"
    var mixedMessageBreakdown: String {
        var parts: [String] = []
        if scheduledPayments > 0 {
            parts.append(L10n.Inbox.Alert.Message.Mixed.scheduled(scheduledPayments))
        }
        if subscriptions > 0 {
            parts.append(L10n.Inbox.Alert.Message.Mixed.subscriptions(subscriptions))
        }
        if automations > 0 {
            parts.append(L10n.Inbox.Alert.Message.Mixed.automations(automations))
        }
        return parts.joined(separator: L10n.Inbox.Alert.Message.Mixed.connector)
    }

    /// Predominant type for message selection
    var notificationType: InboxNotificationType {
        let types = [
            (scheduledPayments > 0, InboxNotificationType.scheduledPayments),
            (subscriptions > 0, InboxNotificationType.subscriptions),
            (automations > 0, InboxNotificationType.automations)
        ].filter { $0.0 }

        if types.count > 1 { return .mixed }
        return types.first?.1 ?? .mixed
    }
}

enum InboxNotificationType {
    case scheduledPayments
    case subscriptions
    case automations
    case mixed
}

/// Deep link destinations from widgets
enum DeepLinkDestination {
    case panel
    case statistics
    case records
    case categories
    case planning
    case budgets
    case inbox
    case scheduledPayments  // Planning > Pagos Planificados
    case recordsStandalone  // Tab Records (standalone)
}

/// Global session state to manage synchronization between views
@MainActor
@Observable
class SessionState {

    /// Shared instance for global access
    static let shared = SessionState()

    // MARK: - Period State

    /// The currently selected period, synchronized across Panel and Statistics
    var selectedPeriod: DetailPeriod {
        didSet {
            // Update globalFilters.dateInterval when period changes
            globalFilters.dateInterval = selectedPeriod.dateInterval(customRange: customDateRange)
        }
    }

    /// Custom date range for .custom period (persisted via UserDefaults)
    var customDateRange: DateInterval? {
        didSet {
            // Persist custom range
            if let range = customDateRange {
                UserDefaults.standard.set(
                    range.start.timeIntervalSince1970, forKey: "customPeriodStart")
                UserDefaults.standard.set(
                    range.end.timeIntervalSince1970, forKey: "customPeriodEnd")
            } else {
                UserDefaults.standard.removeObject(forKey: "customPeriodStart")
                UserDefaults.standard.removeObject(forKey: "customPeriodEnd")
            }
            // Update filter if currently on custom period
            if selectedPeriod == .custom {
                globalFilters.dateInterval = selectedPeriod.dateInterval(
                    customRange: customDateRange)
            }
        }
    }

    // MARK: - Trend Metric State

    /// The currently selected trend metric (Balance/Income/Expense), synchronized across Panel and Statistics
    /// Defaults to .balance
    var selectedTrendMetric: TrendMetric = .balance

    /// Tracks whether the current Expense selection was automatic (due to filters) or manual (user click)
    /// Used to determine if we should auto-reset to Balance when filters are cleared
    var isExpenseAutomatic: Bool = false

    // MARK: - Expenses Only Mode

    /// When true, hides income/transfer UI throughout the app. Data is NOT deleted, only hidden.
    /// Uses stored property (NOT computed) so @Observable tracks changes.
    var isExpensesOnlyMode: Bool = UserDefaults.standard.bool(forKey: "expensesOnlyMode") {
        didSet {
            UserDefaults.standard.set(isExpensesOnlyMode, forKey: "expensesOnlyMode")
            if let appGroup = UserDefaults(suiteName: SharedContainerService.appGroupIdentifier) {
                appGroup.set(isExpensesOnlyMode, forKey: "expensesOnlyMode")
            }
            WidgetCenter.shared.reloadAllTimelines()
            // Clean incompatible state when toggling
            if isExpensesOnlyMode {
                if selectedTrendMetric != .expense { selectedTrendMetric = .expense }
                selectedTransactionNatures = [.expense]
            } else {
                // Deactivating: clear the forced expense filter
                selectedTransactionNatures = []
            }
        }
    }

    // MARK: - Comparison Mode State

    /// Comparison mode for variation chips (P-1 vs A-1), synchronized across Statistics tabs
    /// P-1 = Compare with previous period, A-1 = Compare with same period last year
    var comparisonMode: ComparisonMode = .month

    // MARK: - Global Filter State (shared between Panel and Statistics)

    /// Selected account IDs (empty = all accounts)
    var selectedAccountIDs: Set<PersistentIdentifier> = [] { didSet { resetExcludeModeIfNeeded() } }

    /// Selected category IDs (empty = all categories)
    var selectedCategoryIDs: Set<PersistentIdentifier> = [] { didSet { resetExcludeModeIfNeeded() } }

    /// Selected subcategory IDs (empty = all subcategories)
    /// Changed from names to IDs to handle duplicate subcategory names across categories
    var selectedSubcategoryIDs: Set<PersistentIdentifier> = [] { didSet { resetExcludeModeIfNeeded() } }

    /// Selected natures (empty = all natures)
    var selectedNatures: Set<SubcategoryNature> = [] { didSet { resetExcludeModeIfNeeded() } }

    /// Selected tags (empty = all tags)
    var selectedTags: Set<PersistentIdentifier> = [] { didSet { resetExcludeModeIfNeeded() } }

    /// Selected budget ID for widget highlighting (nil = none selected)
    var selectedBudgetID: PersistentIdentifier?

    /// Selected currencies (empty = all currencies)
    var selectedCurrencies: Set<CurrencyCode> = [] { didSet { resetExcludeModeIfNeeded() } }

    /// Selected transaction natures for filtering income/expense (empty = all)
    var selectedTransactionNatures: Set<TransactionNature> = []

    /// Amount filter condition
    var amountCondition: AmountFilterCondition = .any { didSet { resetExcludeModeIfNeeded() } }

    /// Search text for note filtering
    var searchText: String = "" { didSet { resetExcludeModeIfNeeded() } }

    /// Guard against re-entrant didSet calls during exclude mode transitions
    private var isSwitchingExcludeMode = false

    /// Exclude mode: when true, selected entity filters hide matching items instead of showing only them
    var isExcludeMode: Bool = false {
        didSet {
            guard oldValue != isExcludeMode else { return }
            // Clear entity selections when switching mode to avoid confusion
            // Don't call clearFilters() — it resets isExcludeMode itself, causing a loop
            isSwitchingExcludeMode = true
            selectedAccountIDs.removeAll()
            selectedCategoryIDs.removeAll()
            selectedSubcategoryIDs.removeAll()
            selectedNatures.removeAll()
            selectedTags.removeAll()
            selectedCurrencies.removeAll()
            selectedTransactionNatures.removeAll()
            amountCondition = .any
            searchText = ""
            globalFilters.clearAll()
            isSwitchingExcludeMode = false
        }
    }

    // MARK: - Filter Criteria State

    /// Global filter criteria shared across views (Trends, Records)
    /// Views can bind to this for automatic synchronization.
    var globalFilters: FilterCriteria = .empty

    // MARK: - Computed Properties

    /// Convenience: current date interval based on selectedPeriod
    var currentDateInterval: DateInterval {
        selectedPeriod.dateInterval(customRange: customDateRange)
    }

    /// Check if any global filter is active
    var hasActiveFilters: Bool {
        !selectedAccountIDs.isEmpty || !selectedCategoryIDs.isEmpty
            || !selectedSubcategoryIDs.isEmpty || !selectedNatures.isEmpty
            || !selectedTags.isEmpty || !selectedCurrencies.isEmpty
            || !selectedTransactionNatures.isEmpty
            || amountCondition.isActive || !searchText.isEmpty
    }

    /// Check if any exclude-eligible filter is active (transaction type is NOT excludable)
    private var hasActiveExcludeFilters: Bool {
        !selectedAccountIDs.isEmpty || !selectedCategoryIDs.isEmpty
            || !selectedSubcategoryIDs.isEmpty || !selectedNatures.isEmpty
            || !selectedTags.isEmpty || !selectedCurrencies.isEmpty
            || amountCondition.isActive || !searchText.isEmpty
    }

    /// Auto-reset exclude mode when no exclude-eligible filters remain
    func resetExcludeModeIfNeeded() {
        guard !isSwitchingExcludeMode, isExcludeMode, !hasActiveExcludeFilters else { return }
        isSwitchingExcludeMode = true
        isExcludeMode = false
        isSwitchingExcludeMode = false
    }

    // MARK: - Actions

    /// Clear all global filters (except period)
    func clearFilters() {
        selectedAccountIDs.removeAll()
        selectedCategoryIDs.removeAll()
        selectedSubcategoryIDs.removeAll()
        selectedNatures.removeAll()
        selectedTags.removeAll()
        selectedCurrencies.removeAll()
        selectedTransactionNatures.removeAll()
        selectedBudgetID = nil
        isExcludeMode = false
        amountCondition = .any
        searchText = ""
        globalFilters.clearAll()
    }

    /// Toggle account filter (single-select behavior for Panel compatibility)
    func toggleAccountFilter(_ id: PersistentIdentifier) {
        if selectedAccountIDs.contains(id) {
            selectedAccountIDs.remove(id)
        } else {
            selectedAccountIDs.removeAll()  // Single-select: clear others
            selectedAccountIDs.insert(id)
        }
    }

    /// Toggle category filter
    func toggleCategoryFilter(_ id: PersistentIdentifier) {
        if selectedCategoryIDs.contains(id) {
            selectedCategoryIDs.remove(id)
            // Clear subcategories when category is deselected
            selectedSubcategoryIDs.removeAll()
        } else {
            selectedCategoryIDs.removeAll()  // Single-select for Panel
            selectedCategoryIDs.insert(id)
        }
    }

    /// Toggle subcategory filter
    func toggleSubcategoryFilter(_ id: PersistentIdentifier) {
        if selectedSubcategoryIDs.contains(id) {
            selectedSubcategoryIDs.remove(id)
        } else {
            selectedSubcategoryIDs.removeAll()  // Single-select for Panel
            selectedSubcategoryIDs.insert(id)
        }
    }

    /// Toggle nature filter
    func toggleNatureFilter(_ nature: SubcategoryNature) {
        if selectedNatures.contains(nature) {
            selectedNatures.remove(nature)
        } else {
            selectedNatures.removeAll()  // Single-select for Panel
            selectedNatures.insert(nature)
        }
    }

    /// Toggle tag filter
    func toggleTagFilter(_ id: PersistentIdentifier) {
        if selectedTags.contains(id) {
            selectedTags.remove(id)
        } else {
            selectedTags.insert(id)
        }
    }

    /// Toggle currency filter
    func toggleCurrencyFilter(_ currency: CurrencyCode) {
        if selectedCurrencies.contains(currency) {
            selectedCurrencies.remove(currency)
        } else {
            selectedCurrencies.insert(currency)
        }
    }

    /// Set amount filter condition
    func setAmountCondition(_ condition: AmountFilterCondition) {
        amountCondition = condition
    }

    /// Set search text for note filtering
    func setSearchText(_ text: String) {
        searchText = text
    }

    /// Reset to default state
    func resetToDefaults() {
        selectedPeriod = .allTime
        customDateRange = nil
        clearFilters()
        globalFilters.dateInterval = selectedPeriod.dateInterval()
    }

    // MARK: - Subscription State

    /// Whether the user has an active Pro subscription (mirrors StoreKitManager)
    var isProUser: Bool = false

    // MARK: - Data Wipe State

    /// Flag indicating data wipe is in progress
    /// When true, ContentView shows a loading overlay to prevent @Query observers from crashing
    var isWipingData: Bool = false

    /// Flag to trigger exchange rate reload after data wipe
    /// Set to true after wipe completes, observed by YalaApp to reload rates
    var needsExchangeRateReload: Bool = false

    /// Flag to trigger exchange rate widget recalculation
    /// Set to true after exchange rates are loaded/updated
    var needsExchangeRateWidgetRefresh: Bool = false

    /// Flag to trigger budgets widget recalculation
    /// Set to true after favorites are modified (toggled, reordered)
    var needsBudgetsWidgetRefresh: Bool = false

    /// Version counter for formatting settings (rounded amounts, etc.)
    /// Increment this to force views to re-render with new formatting
    var formattingVersion: Int = 0

    /// Version counter for data mutations — increment to trigger cross-view refresh
    var dataVersion: Int = 0

    func incrementDataVersion() {
        dataVersion += 1
    }

    // MARK: - Share Extension State

    /// Flag to trigger shared image processing (one-shot pattern)
    /// When true, PanelView opens ImageSelectionView and immediately resets to false
    var shouldShowSharedImage: Bool = false

    /// URL of shared image to process (from Share Extension)
    /// When set, PanelView will open ImageSelectionView with this image
    var pendingSharedImageURL: URL?

    /// Flag to trigger Inbox sheet from anywhere in the app
    /// Set by SharedImageProcessor after creating drafts
    var shouldShowInbox: Bool = false

    /// Pending inbox drafts notification info
    /// When not empty, shows an alert modal to notify the user
    var pendingInboxNotification: PendingInboxNotification = .init()

    /// Flag to trigger voice entry from App Shortcut
    /// When true, PanelView will open VoiceRecordingSheet
    var shouldShowVoiceEntry: Bool = false

    /// Flag to trigger image entry from App Shortcut
    /// When true, PanelView will open ImageSelectionView
    var shouldShowImageEntry: Bool = false

    /// Flag to trigger new transaction form from widget deep link
    /// When true, PanelView will open NewTransactionView
    var shouldShowNewTransaction: Bool = false

    /// Flag to trigger upgrade sheet for voice feature from deep link
    var shouldShowUpgradeForVoice: Bool = false

    /// Flag to trigger upgrade sheet for image feature from deep link
    var shouldShowUpgradeForImage: Bool = false

    /// Flag to show subscription success celebration
    var shouldShowSubscriptionSuccess: Bool = false

    /// Flag to show downgrade resolution sheet
    var shouldShowDowngradeResolution: Bool = false

    /// Deep link destination from widgets
    /// When set, app navigates to specified destination and clears this
    var deepLinkDestination: DeepLinkDestination?

    // MARK: - Navigation State

    /// Currently selected main tab (Panel, Statistics, etc.)
    var selectedMainTab: AppTab = .panel {
        didSet {
            // Clear temporary tab when navigating to a permanent tab
            if selectedMainTab != temporaryTab?.appTab && selectedMainTab != .more {
                temporaryTab = nil
            }
        }
    }

    /// Temporary tab shown from "More" - cleared when navigating to another tab
    var temporaryTab: ConfigurableTab?

    /// Currently selected detail tab within Statistics (Trends, Categories, Records)
    var selectedDetailTab: DetailViewTab = .insights

    /// Currently selected tab within Planning (Budgets, Scheduled Payments)
    var selectedPlanningTab: PlanningTab = .budgets

    /// Navigate to a specific detail view from any tab
    func navigateToDetail(_ tab: DetailViewTab) {
        selectedDetailTab = tab
        selectedMainTab = .statistics
    }

    /// Navigate to Scheduled Payments in Planning
    func navigateToScheduledPayments() {
        selectedPlanningTab = .scheduledPayments
        selectedMainTab = .planning
    }

    /// Navigate to Budgets in Planning
    func navigateToBudgets() {
        selectedPlanningTab = .budgets
        selectedMainTab = .planning
    }

    /// Toggle budget filters - if same budget is tapped again, clear filters
    func applyBudgetFilters(_ budget: Budget) {
        let budgetID = budget.persistentModelID

        // Toggle: if same budget selected, clear all
        if selectedBudgetID == budgetID {
            selectedBudgetID = nil
            clearFilters()
            return
        }

        // Clear existing filters before applying new ones
        clearFilters()
        selectedBudgetID = budgetID

        // Apply account filters
        if let accounts = budget.accounts, !accounts.isEmpty {
            selectedAccountIDs = Set(accounts.map { $0.persistentModelID })
        }

        // Apply subcategory filters (use IDs to handle duplicate names across categories)
        if let subcategories = budget.subcategories, !subcategories.isEmpty {
            selectedSubcategoryIDs = Set(subcategories.map { $0.persistentModelID })
        }

        // Apply tag filters
        if let tags = budget.tags, !tags.isEmpty {
            selectedTags = Set(tags.map { $0.persistentModelID })
        }

        // Apply nature filters (parse comma-separated string)
        if let naturesString = budget.natures, !naturesString.isEmpty {
            let natureValues = naturesString.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
            selectedNatures = Set(natureValues.compactMap { SubcategoryNature(rawValue: $0) })
        }
    }

    // MARK: - Initialization

    init() {
        // Load default period from AppStorage or fallback to .allTime
        if let rawValue = UserDefaults.standard.string(forKey: "defaultPeriod"),
            let period = DetailPeriod(rawValue: rawValue)
        {
            self.selectedPeriod = period
        } else {
            self.selectedPeriod = .allTime
        }

        // Load persisted custom date range
        let startTimestamp = UserDefaults.standard.double(forKey: "customPeriodStart")
        let endTimestamp = UserDefaults.standard.double(forKey: "customPeriodEnd")
        if startTimestamp > 0 && endTimestamp > 0 {
            let start = Date(timeIntervalSince1970: startTimestamp)
            let end = Date(timeIntervalSince1970: endTimestamp)
            if start < end {
                self.customDateRange = DateInterval(start: start, end: end)
            }
        }

        // Set initial dateInterval on globalFilters
        self.globalFilters.dateInterval = selectedPeriod.dateInterval(customRange: customDateRange)
    }
}
