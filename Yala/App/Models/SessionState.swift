//
//  SessionState.swift
//  Yala
//
//  Created by Yala Refactoring.
//

import CloudKit
import SwiftData
import SwiftUI
import WidgetKit

// MARK: - Inbox Notification Types

/// Types of drafts pending notification
struct PendingInboxNotification: Equatable {
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
enum DeepLinkDestination: Equatable, Hashable {
    case panel
    case statistics
    case records
    case categories
    case planning
    case budgets
    case inbox
    case scheduledPayments  // Planning > Pagos Planificados
    case recordsStandalone  // Tab Records (standalone)
    case groups             // Grupos (gastos compartidos)
    case groupDetail(groupID: String)  // Grupo especifico
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

    // MARK: - Financial Mindset

    /// User's financial mindset chosen during onboarding: "cashFlow" (Día a día) or "patrimonial" (Control total).
    /// Affects educational UI (balance calculator variants, tips) but NOT features or calculations.
    var financialMindset: String = UserDefaults.standard.string(forKey: AppPreferences.Keys.financialMindset) ?? "cashFlow" {
        didSet {
            guard oldValue != financialMindset else { return }
            UserDefaults.standard.set(financialMindset, forKey: AppPreferences.Keys.financialMindset)
        }
    }

    // MARK: - Expenses Only Mode

    /// When true, hides income/transfer UI throughout the app. Data is NOT deleted, only hidden.
    /// Uses stored property (NOT computed) so @Observable tracks changes.
    var isExpensesOnlyMode: Bool = UserDefaults.standard.bool(forKey: AppPreferences.Keys.expensesOnlyMode) {
        didSet {
            // No-op guard avoids spurious UserDefaults writes (which materialize the key
            // on fresh installs) and WidgetCenter reloads when callers reassign the same value.
            guard oldValue != isExpensesOnlyMode else { return }
            UserDefaults.standard.set(isExpensesOnlyMode, forKey: AppPreferences.Keys.expensesOnlyMode)
            if let appGroup = UserDefaults(suiteName: SharedContainerService.appGroupIdentifier) {
                appGroup.set(isExpensesOnlyMode, forKey: AppPreferences.Keys.expensesOnlyMode)
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
    var selectedNeeds: Set<SubcategoryNeed> = [] { didSet { resetExcludeModeIfNeeded() } }

    /// Selected tags (empty = all tags)
    var selectedTags: Set<PersistentIdentifier> = [] { didSet { resetExcludeModeIfNeeded() } }

    /// Selected budget ID for widget highlighting (nil = none selected)
    var selectedBudgetID: PersistentIdentifier?

    /// Selected currencies (empty = all currencies)
    var selectedCurrencies: Set<CurrencyCode> = [] { didSet { resetExcludeModeIfNeeded() } }

    /// Selected transaction natures for filtering income/expense (empty = all)
    var selectedTransactionNatures: Set<TransactionNature> = []

    /// Returns the single active filter nature, or nil if none or multiple are selected
    var activeFilterNature: TransactionNature? {
        selectedTransactionNatures.count == 1 ? selectedTransactionNatures.first : nil
    }

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
            selectedNeeds.removeAll()
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
            || !selectedSubcategoryIDs.isEmpty || !selectedNeeds.isEmpty
            || !selectedTags.isEmpty || !selectedCurrencies.isEmpty
            || !selectedTransactionNatures.isEmpty
            || amountCondition.isActive || !searchText.isEmpty
    }

    /// Check if any exclude-eligible filter is active (transaction type is NOT excludable)
    private var hasActiveExcludeFilters: Bool {
        !selectedAccountIDs.isEmpty || !selectedCategoryIDs.isEmpty
            || !selectedSubcategoryIDs.isEmpty || !selectedNeeds.isEmpty
            || !selectedTags.isEmpty || !selectedCurrencies.isEmpty
            || amountCondition.isActive || !searchText.isEmpty
    }

    /// Auto-reset exclude mode when no exclude-eligible filters remain
    func resetExcludeModeIfNeeded() {
        guard !isSwitchingExcludeMode, !isBatchingFilterUpdate, isExcludeMode, !hasActiveExcludeFilters else { return }
        isSwitchingExcludeMode = true
        isExcludeMode = false
        isSwitchingExcludeMode = false
    }

    /// Guard against resetExcludeModeIfNeeded during batch filter commits
    private var isBatchingFilterUpdate = false

    /// Batch-set multiple filter properties without triggering intermediate resetExcludeModeIfNeeded calls.
    /// Use when committing filter values from a sheet where isExcludeMode was already set.
    func performBatchFilterUpdate(_ block: () -> Void) {
        isBatchingFilterUpdate = true
        block()
        isBatchingFilterUpdate = false
    }

    // MARK: - Actions

    /// Clear all global filters (except period)
    func clearFilters() {
        selectedAccountIDs.removeAll()
        selectedCategoryIDs.removeAll()
        selectedSubcategoryIDs.removeAll()
        selectedNeeds.removeAll()
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

    /// Toggle need filter
    func toggleNeedFilter(_ need: SubcategoryNeed) {
        if selectedNeeds.contains(need) {
            selectedNeeds.remove(need)
        } else {
            selectedNeeds.removeAll()  // Single-select for Panel
            selectedNeeds.insert(need)
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

        // Reset navigation to initial state (important after data wipe)
        // Mode-aware: groupInvite users default to .groups tab
        selectedMainTab = isGroupInviteMode ? .groups : .panel
        selectedDetailTab = .insights
        selectedPlanningTab = .budgets
    }

    // MARK: - Onboarding Mode

    /// Current onboarding mode — determines tab layout, bridge behavior, and UI gating.
    /// Persisted in UserDefaults, synced via PreferenceSyncService with never-downgrade rule.
    var onboardingMode: OnboardingMode = OnboardingMode.current() {
        didSet {
            OnboardingMode.setCurrent(onboardingMode)
        }
    }

    /// Convenience: true when user arrived via group invitation and hasn't activated full mode
    var isGroupInviteMode: Bool { onboardingMode == .groupInvite }

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

    /// True when user entered via a group notification deep link (reset on next evaluate cycle)
    var enteredViaGroupNotification: Bool = false

    /// Mirrors PanelShell `sheets.showInbox` so the RouterEntryGate can drop
    /// incoming `.showInboxAlert` while the Inbox sheet is already presenting.
    /// Without this, the original bug (notif arrives → fullScreenCover queued
    /// behind the open sheet → surfaces "tardío") could resurrect via a fresh
    /// `.showInboxAlert` raised AFTER the sheet opened.
    var isInboxSheetVisible: Bool = false

    /// Blocker de nivel shell (ContentView) activo, `nil` si el shell está libre.
    /// Escrito SOLO por `ContentView.updateContentViewReadiness` (choke point
    /// único). Los consumidores inferiores (.mainTab/.panel) lo consultan como
    /// guard de drain: con el shell tapado, un intent que setee un sheet propio
    /// ESPERA en cola en vez de consumirse tapado (Clase D). Default "splash":
    /// el splash siempre cubre el boot antes del primer recompute.
    var shellModalBlocker: String? = "splash"

    /// True mientras MainTabView tiene un sheet propio presentado (downgrade /
    /// trialExpired / milestone). Escrito SOLO por MainTabView. Consultado por
    /// el guard de `.panel` y por la matriz de readiness del shell (cross-node:
    /// el cover del inbox alert no debe montarse encima de un sheet de MainTab).
    var isMainTabModalVisible: Bool = false

    /// Version counter for formatting settings (rounded amounts, etc.)
    /// Increment this to force views to re-render with new formatting
    var formattingVersion: Int = 0

    /// Version counter for data mutations — increment to trigger cross-view refresh
    var dataVersion: Int = 0

    /// Flag for deferred remote CloudKit changes — applied on view navigation, not mid-scroll
    private var hasPendingRemoteChanges: Bool = false

    func incrementDataVersion() {
        dataVersion += 1
    }

    /// Mark that remote data arrived — views will pick this up on onAppear
    func markRemoteChangePending() {
        hasPendingRemoteChanges = true
    }

    /// Apply pending remote changes (call from onAppear or handleBecameActive).
    /// Returns `true` si había cambios pendientes y se aplicaron (usado por el re-fire de
    /// intents background para cortar temprano en cuanto el merge aterriza).
    @discardableResult
    func applyPendingChangesIfNeeded() -> Bool {
        guard hasPendingRemoteChanges else { return false }
        hasPendingRemoteChanges = false
        incrementDataVersion()
        return true
    }

    // MARK: - Router-migrated state
    //
    // Previously this section held ~25 transient flags (shouldShow*,
    // pending*, deferred*) coordinated via Task.sleep / onChange observers.
    // All UI routing now flows through AppRouter (see RouterIntent.swift).

    /// Flag set by OnboardingView completion to trigger trial offer after fullScreenCover dismisses.
    /// Persisted in UserDefaults so it survives app kill during the dismiss animation window.
    /// Consumption routed via AppRouter.enqueue(.presentTrialOffer); the flag itself remains here.
    var needsPostOnboardingTrial: Bool = UserDefaults.standard.bool(forKey: "needsPostOnboardingTrial") {
        didSet { UserDefaults.standard.set(needsPostOnboardingTrial, forKey: "needsPostOnboardingTrial") }
    }

    // MARK: - Splash State

    /// Whether the splash screen has been dismissed (gate for router readiness).
    var isSplashDismissed: Bool = false

    /// Pending group ID for deep link navigation to specific group.
    /// Set by AppRouter.navigate(.groupDetail) handler, read by GroupsContainerView.
    var pendingGroupID: String?

    /// Set por el FAB del Panel ("Grupo") para abrir el composer "Nuevo gasto" al
    /// llegar al tab Grupos. Consumido por GroupsContainerView cuando haya un grupo
    /// elegible (espeja el patrón de `pendingGroupID`).
    var pendingNewGroupExpense: Bool = false

    /// URL of a shared image captured from the Share Extension. Not a flag —
    /// it's the payload that ImageSelectionView consumes once opened. The
    /// .presentSharedImage router intent sets this alongside the sheet.
    var pendingSharedImageURL: URL?

    /// Prefill payload del chat para abrir NewTransactionView con datos pre-llenados.
    /// El `.presentNewTransactionFromChatDraft(...)` router intent setea este payload
    /// junto con `showNewTransactionFromChat = true`.
    var pendingChatDraftPrefill: ChatDraftPrefill?

    /// Flag transient que el PanelShell observa para presentar NewTransactionView
    /// con prefill desde chat. La vista lo limpia tras consumir el payload.
    var showNewTransactionFromChat: Bool = false

    /// Broadcast: cuando NewTransactionView persiste una transacción que vino de un
    /// chat draft, setea esta tupla para que el ChatAssistantViewModel observe y
    /// marque el card original como `.saved`. Si NTV se cancela, NO se setea.
    /// El ChatVM lee, marca el card y limpia (también el espejo en UserDefaults).
    struct ChatDraftSavedSignal: Codable, Equatable {
        let messageID: UUID
        let draftID: UUID
        let transactionID: PersistentIdentifier
    }
    var chatDraftSavedSignal: ChatDraftSavedSignal? {
        didSet {
            // Espejo en UserDefaults para que sobreviva crash/kill de la app entre
            // NTV-save y reapertura del chat (sin esto, el card queda .pending y un
            // segundo tap [Save] crearía duplicado).
            let key = "chat_draft_saved_signal"
            if let signal = chatDraftSavedSignal,
               let data = try? JSONEncoder().encode(signal) {
                UserDefaults.standard.set(data, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
    }

    /// Restaura el signal desde UserDefaults si existe — llamado por ChatVM en setContext.
    func restoreChatDraftSavedSignalIfNeeded() {
        guard chatDraftSavedSignal == nil else { return }
        guard let data = UserDefaults.standard.data(forKey: "chat_draft_saved_signal"),
              let signal = try? JSONDecoder().decode(ChatDraftSavedSignal.self, from: data)
        else { return }
        chatDraftSavedSignal = signal  // re-publica → ChatSheetView observa via .onChange si está abierto
    }

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

    /// Currently selected tab within Reports (Comparativa, Flujo de caja).
    /// Global SSOT so the dashboard "Más" can deep-link into a report sub-tab.
    var selectedReportTab: ReportTab = .comparativa

    /// Pending Task that finalizes a deferred main tab selection (when the
    /// destination tab is hidden in "More" and we need to mount it via
    /// `temporaryTab` first). Cancelled if a new selection comes in while a
    /// previous one is still waiting for the runloop tick — prevents the
    /// `didSet` of a concurrent mutation from clearing `temporaryTab` before
    /// the deferred selection lands.
    private var pendingTabSelectionTask: Task<Void, Never>?

    /// Single entry point to change `selectedMainTab` safely. Centralizes the
    /// "mount-then-select" rule required by iOS 18+ TabView when the target
    /// tab is hidden in "More": adding it via `temporaryTab` and waiting one
    /// runloop tick (50 ms) before assigning `selectedMainTab`. If the tab is
    /// already visible, assigns directly with no latency.
    ///
    /// Honors GC-08 invariant: in `groupInvite` mode, only `.groups`, `.more`
    /// and `.search` are reachable; other tabs are silently rejected.
    func selectMainTab(_ tab: AppTab) {
        if isGroupInviteMode {
            let allowed: Set<AppTab> = [.groups, .more, .search]
            guard allowed.contains(tab) else { return }
        }

        let stored = TabBarConfiguration.loadFromStandardDefaults()
        let config = TabBarConfiguration.forMode(
            onboardingMode, stored: stored,
            secondarySessionActive: SecondarySessionStore.isActive())
        let decision = MainTabSelectionLogic.decide(requested: tab, config: config)

        pendingTabSelectionTask?.cancel()
        if decision.requiresDelay, let temp = decision.temporaryTab {
            temporaryTab = temp
            pendingTabSelectionTask = Task {
                try? await Task.sleep(for: .milliseconds(50))
                guard !Task.isCancelled else { return }
                selectedMainTab = decision.selectedTab
            }
        } else {
            selectedMainTab = decision.selectedTab
        }
    }

    /// Navigate to a specific detail view from any tab
    func navigateToDetail(_ tab: DetailViewTab) {
        selectedDetailTab = tab
        selectMainTab(.statistics)
    }

    /// Navigate to Scheduled Payments in Planning
    func navigateToScheduledPayments() {
        selectedPlanningTab = .scheduledPayments
        selectMainTab(.planning)
    }

    /// Navigate to Budgets in Planning
    func navigateToBudgets() {
        selectedPlanningTab = .budgets
        selectMainTab(.planning)
    }

    /// Navigate to a specific Reports sub-tab (Comparativa / Flujo de caja).
    func navigateToReport(_ tab: ReportTab) {
        selectedReportTab = tab
        selectMainTab(.reports)
    }

    /// Navigate to the standalone Records tab (`RecordsStandaloneView`). When
    /// the tab isn't enabled in the configurable tab bar, we use the same
    /// deep-link trick as `AppBootstrapper.setOrDeferDeepLink(.recordsStandalone)`:
    /// set `temporaryTab = .records` so it renders, then switch to it on the
    /// next runloop so SwiftUI picks up the change in the right order.
    func navigateToRecordsStandalone() {
        RouterEntryGate.shared.submit(.navigate(.recordsStandalone))
    }

    /// Navigate to Groups tab
    func navigateToGroups() {
        selectMainTab(.groups)
    }

    /// Atajo desde el FAB del Panel: navega al tab Grupos y pide abrir el composer
    /// "Nuevo gasto" al montar (GroupsContainerView observa `pendingNewGroupExpense`).
    func navigateToGroupsAndComposeExpense() {
        pendingNewGroupExpense = true
        selectMainTab(.groups)
    }

    /// Toggle budget filters - if same budget is tapped again, clear filters.
    ///
    /// Reads filters from the CSV mirror (SSOT) and resolves UUIDs to
    /// `PersistentIdentifier` (consumed by the FilterControlBar chips) via
    /// targeted fetches by `shortcutID`/`id`. `context` is required to do these
    /// fetches; pass `modelContext` from the calling View/Environment.
    func applyBudgetFilters(_ budget: Budget, context: ModelContext) {
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

        // Apply account filters (resolve via shortcutID UUID)
        if let accountUUIDs = budget.resolvedAccountIDs(scheduleBackfill: true), !accountUUIDs.isEmpty {
            let descriptor = FetchDescriptor<Account>(predicate: #Predicate { accountUUIDs.contains($0.shortcutID) })
            do {
                let resolved = try context.fetch(descriptor)
                selectedAccountIDs = Set(resolved.map(\.persistentModelID))
            } catch {
                #if DEBUG
                print("SessionState: applyBudgetFilters account fetch error: \(error)")
                #endif
            }
        }

        // Apply subcategory filters (resolve via shortcutID UUID)
        if let subUUIDs = budget.resolvedSubcategoryIDs(scheduleBackfill: true), !subUUIDs.isEmpty {
            let descriptor = FetchDescriptor<Subcategory>(predicate: #Predicate { subUUIDs.contains($0.shortcutID) })
            do {
                let resolved = try context.fetch(descriptor)
                selectedSubcategoryIDs = Set(resolved.map(\.persistentModelID))
            } catch {
                #if DEBUG
                print("SessionState: applyBudgetFilters subcategory fetch error: \(error)")
                #endif
            }
        }

        // Apply tag filters (resolve via id UUID)
        if let tagUUIDs = budget.resolvedTagIDs(scheduleBackfill: true), !tagUUIDs.isEmpty {
            let descriptor = FetchDescriptor<Tag>(predicate: #Predicate { tagUUIDs.contains($0.id) })
            do {
                let resolved = try context.fetch(descriptor)
                selectedTags = Set(resolved.map(\.persistentModelID))
            } catch {
                #if DEBUG
                print("SessionState: applyBudgetFilters tag fetch error: \(error)")
                #endif
            }
        }

        // Apply need filters (parse comma-separated string)
        if let naturesString = budget.natures, !naturesString.isEmpty {
            let needValues = naturesString.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
            selectedNeeds = Set(needValues.compactMap { SubcategoryNeed(rawValue: $0) })
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

// MARK: - View Extension for Deferred Remote Changes

extension View {
    /// Applies pending remote CloudKit changes when this view appears.
    /// Use on top-level navigation views that observe `sessionState.dataVersion`.
    ///
    /// - Warning: NEVER use on views presented as sheets. Mutating @Observable
    ///   during sheet transition creates an infinite layoutBelowIfNeeded loop
    ///   that triggers watchdog 0x8BADF00D. See: b583ea5e
    func appliesPendingRemoteChanges(_ sessionState: SessionState) -> some View {
        self.onAppear {
            sessionState.applyPendingChangesIfNeeded()
        }
    }
}
