//
//  ScheduledPaymentsViewModel.swift
//  Yala
//
//  ViewModel for managing scheduled payments, filtering, and UI state
//

import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class ScheduledPaymentsViewModel {

    private static let monthYearFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f
    }()

    // MARK: - Dependencies

    private var modelContext: ModelContext?

    // MARK: - Debounce state

    private var recalculateTask: Task<Void, Never>?
    private var pendingReload = false
    private(set) var isInBackground = false

    // MARK: - Monthly totals cache

    private struct MonthlyTotalsCache {
        let monthAnchor: Date
        let preferredCurrency: String
        let paid: Double
        let pending: Double
    }
    private var cachedMonthlyTotals: MonthlyTotalsCache?

    // MARK: - Data

    private(set) var allPayments: [ScheduledPayment] = []

    // MARK: - Tab State

    /// Currently selected tab (recurring, subscriptions, all)
    var selectedTab: ScheduledPaymentsTab = .all

    // MARK: - Filter State

    /// Selected account IDs for filtering
    var selectedAccounts: Set<PersistentIdentifier> = []

    /// Selected category IDs for filtering
    var selectedCategories: Set<PersistentIdentifier> = []

    /// Selected subcategory IDs for filtering
    var selectedSubcategories: Set<PersistentIdentifier> = []

    /// Selected tag IDs for filtering
    var selectedTags: Set<PersistentIdentifier> = []

    /// Selected transaction natures (income/expense)
    var selectedTransactionNatures: Set<String> = []

    // MARK: - UI State

    /// Whether to show the filters sheet
    var showFiltersSheet: Bool = false

    /// Whether to show the payment editor sheet
    var showPaymentEditor: Bool = false

    /// The payment being edited (nil for new payment)
    var editingPayment: ScheduledPayment?

    /// Whether to hide inactive payments
    var hideInactive: Bool = false

    // MARK: - View Mode State

    /// View mode for payments tabs (list or calendar) - applies to all tabs
    var paymentsViewMode: PaymentsViewMode = .list

    /// Selected month for both list and calendar views (shared)
    var selectedMonth: Date = Date.now

    /// Whether to show the period selector sheet
    var showPeriodSelector: Bool = false

    // MARK: - Computed Data

    /// Payments grouped by due status (filtered by selectedMonth)
    var groupedPayments: [(status: DueStatus, payments: [ScheduledPaymentSummary])] = []

    /// Paid count for each payment in the selected month (paymentID -> count)
    private(set) var paidStatusForMonth: [String: Int] = [:]

    /// Cached paid amounts — pre-computed in calculatePaymentData(), consumed by calculateMonthlyTotal()
    private(set) var cachedPaidAmounts: [String: [PaidOccurrenceInfo]] = [:]

    /// Payment status filter (all/paid/pending)
    var paymentStatusFilter: PaymentStatusFilter = .all

    /// Smart label for the selected month
    var monthYearLabel: String {
        let calendar = Calendar.current
        let now = Date.now
        if calendar.isDate(selectedMonth, equalTo: now, toGranularity: .month) {
            return L10n.Period.thisMonth
        } else if let lastMonth = calendar.date(byAdding: .month, value: -1, to: now),
                  calendar.isDate(selectedMonth, equalTo: lastMonth, toGranularity: .month) {
            return L10n.Period.lastMonth
        } else if let nextMonth = calendar.date(byAdding: .month, value: 1, to: now),
                  calendar.isDate(selectedMonth, equalTo: nextMonth, toGranularity: .month) {
            return L10n.Period.nextMonth
        } else {
            return Self.monthYearFormatter.string(from: selectedMonth).capitalized
        }
    }

    // MARK: - Paid/Pending Totals

    /// All flat summaries from groupedPayments
    private var allSummaries: [ScheduledPaymentSummary] {
        groupedPayments.flatMap(\.payments)
    }

    /// Monthly total of paid payments (excluding income and skipped), converted to preferred currency
    func monthlyTotalPaid(preferredCurrencyCode: String) -> Double {
        ensureMonthlyTotalsCached(preferredCurrencyCode: preferredCurrencyCode).paid
    }

    /// Monthly total of pending (unpaid, non-skipped) payments (excluding income), converted to preferred currency
    func monthlyTotalPending(preferredCurrencyCode: String) -> Double {
        ensureMonthlyTotalsCached(preferredCurrencyCode: preferredCurrencyCode).pending
    }

    /// Returns cached totals if valid; otherwise computes paid+pending in a single pass and caches.
    @discardableResult
    private func ensureMonthlyTotalsCached(preferredCurrencyCode: String) -> (paid: Double, pending: Double) {
        let anchor = Calendar.current.startOfMonth(for: selectedMonth)
        if let cache = cachedMonthlyTotals,
           cache.preferredCurrency == preferredCurrencyCode,
           Calendar.current.isDate(cache.monthAnchor, equalTo: selectedMonth, toGranularity: .month) {
            return (cache.paid, cache.pending)
        }

        let converter = CurrencyConverter.shared
        var paid: Double = 0
        var pending: Double = 0
        for summary in allSummaries {
            guard !summary.isSkippedForMonth,
                  summary.payment.transactionType != "income" else { continue }
            let amount = summary.displayAmount
            let sourceCurrency = summary.displayCurrencyCode
            let contribution: Double
            if sourceCurrency != preferredCurrencyCode, amount > 0 {
                let decimal = Decimal(amount)
                let converted: Decimal
                if let context = modelContext {
                    converted = converter.convertWithLatestRate(decimal, from: sourceCurrency, to: preferredCurrencyCode, context: context)
                } else {
                    converted = converter.convertWithFallback(decimal, from: sourceCurrency, to: preferredCurrencyCode)
                }
                contribution = NSDecimalNumber(decimal: converted).doubleValue
            } else {
                contribution = amount
            }
            if summary.isPaidForMonth {
                paid += contribution
            } else {
                pending += contribution
            }
        }

        cachedMonthlyTotals = MonthlyTotalsCache(
            monthAnchor: anchor,
            preferredCurrency: preferredCurrencyCode,
            paid: paid,
            pending: pending
        )
        return (paid, pending)
    }

    private func invalidateMonthlyTotals() { cachedMonthlyTotals = nil }

    /// Grouped payments filtered by paymentStatusFilter
    var filteredGroupedPayments: [(status: DueStatus, payments: [ScheduledPaymentSummary])] {
        if paymentStatusFilter == .all { return groupedPayments }

        return groupedPayments.compactMap { section in
            let filtered: [ScheduledPaymentSummary]
            switch paymentStatusFilter {
            case .paid:
                filtered = section.payments.filter { $0.isPaidForMonth }
            case .pending:
                filtered = section.payments.filter { !$0.isPaidForMonth && !$0.isSkippedForMonth }
            case .all:
                filtered = section.payments
            }
            guard !filtered.isEmpty else { return nil }
            return (status: section.status, payments: filtered)
        }
    }

    // MARK: - Filter Computed Properties

    /// Whether any filters are active
    var hasActiveFilters: Bool {
        !selectedAccounts.isEmpty ||
        !selectedCategories.isEmpty ||
        !selectedSubcategories.isEmpty ||
        !selectedTags.isEmpty ||
        !selectedTransactionNatures.isEmpty
    }

    /// Count of active filters
    var activeFilterCount: Int {
        var count = 0
        if !selectedAccounts.isEmpty { count += 1 }
        if !selectedCategories.isEmpty || !selectedSubcategories.isEmpty { count += 1 }
        if !selectedTags.isEmpty { count += 1 }
        if !selectedTransactionNatures.isEmpty { count += 1 }
        return count
    }

    // MARK: - Initialization

    init() {}

    // MARK: - Context Setup

    func setContext(_ context: ModelContext) {
        let isNewContext = self.modelContext !== context
        self.modelContext = context
        if isNewContext { loadPayments() }
    }

    func loadPayments() {
        guard let context = modelContext else { return }

        let descriptor = FetchDescriptor<ScheduledPayment>(
            sortBy: [SortDescriptor(\.nextDueDate)]
        )

        do {
            let fetched = try context.fetch(descriptor)
            if fetched != allPayments {
                allPayments = fetched
                // Clean up skipped dates older than 1 year (prevents unbounded growth via iCloud sync)
                for payment in allPayments {
                    payment.cleanupOldSkippedDates()
                }
            }
        } catch {
            #if DEBUG
            print("ScheduledPaymentsViewModel: Error loading payments: \(error)")
            #endif
        }
    }

    // MARK: - Skip/Unskip

    func skipOccurrence(payment: ScheduledPayment, date: Date) {
        guard let context = modelContext else { return }
        payment.skipDate(date)
        rejectPendingDraft(for: payment)
        do {
            try context.save()
            WidgetDataCache.updateCache(context: context)
            SessionState.shared.incrementDataVersion()
        } catch {
            #if DEBUG
            print("ScheduledPaymentsViewModel: Error saving skip: \(error)")
            #endif
        }
        loadPayments()
    }

    func unskipOccurrence(payment: ScheduledPayment, date: Date) {
        guard let context = modelContext else { return }
        payment.unskipDate(date)
        ScheduledPaymentDraftService.recreateDraftIfNeeded(for: payment, date: date, context: context)
        do {
            try context.save()
            WidgetDataCache.updateCache(context: context)
            SessionState.shared.incrementDataVersion()
        } catch {
            #if DEBUG
            print("ScheduledPaymentsViewModel: Error saving unskip: \(error)")
            #endif
        }
        loadPayments()
    }

    private func rejectPendingDraft(for payment: ScheduledPayment) {
        guard let context = modelContext else { return }
        let paymentID = payment.id.uuidString
        do {
            let descriptor = FetchDescriptor<InboxDraft>(
                predicate: #Predicate<InboxDraft> { draft in
                    draft.statusRaw == "pending" && draft.sourceScheduledPaymentID != nil
                }
            )
            let drafts = try context.fetch(descriptor)
            for draft in drafts where draft.sourceScheduledPaymentID == paymentID {
                draft.statusRaw = "rejected"
            }
        } catch {
            #if DEBUG
            print("ScheduledPaymentsViewModel: Error rejecting draft: \(error)")
            #endif
        }
    }

    // MARK: - Paid Status

    /// Apply shared filters (active, accounts, subcategories, categories, tags, natures) to a payment list.
    private func applyPaymentFilters(_ payments: [ScheduledPayment]) -> [ScheduledPayment] {
        var filtered = payments

        if hideInactive {
            filtered = filtered.filter { $0.isActive }
        }
        if !selectedAccounts.isEmpty {
            filtered = filtered.filter { payment in
                guard let accountID = payment.account?.persistentModelID else { return false }
                return selectedAccounts.contains(accountID)
            }
        }
        if !selectedSubcategories.isEmpty {
            filtered = filtered.filter { payment in
                guard let subID = payment.subcategory?.persistentModelID else { return false }
                return selectedSubcategories.contains(subID)
            }
        }
        if !selectedCategories.isEmpty && selectedSubcategories.isEmpty {
            filtered = filtered.filter { payment in
                guard let catID = payment.subcategory?.safeCategory.persistentModelID else { return false }
                return selectedCategories.contains(catID)
            }
        }
        if !selectedTags.isEmpty {
            // CSV-mirror SSOT: map selectedTags (PersistentIdentifier) → Set<UUID> via local Tag fetch,
            // then compare against payment.resolvedTagIDs (CSV-first with M2M fallback).
            let selectedTagUUIDs: Set<UUID>
            do {
                let allTags = try (modelContext?.fetch(FetchDescriptor<Tag>())) ?? []
                selectedTagUUIDs = Set(
                    allTags.filter { selectedTags.contains($0.persistentModelID) }.map(\.id)
                )
            } catch {
                #if DEBUG
                print("ScheduledPaymentsViewModel: applyPaymentFilters tag fetch error: \(error)")
                #endif
                selectedTagUUIDs = []
            }
            if !selectedTagUUIDs.isEmpty {
                filtered = filtered.filter { payment in
                    let paymentTagIDs = payment.resolvedTagIDs(scheduleBackfill: true) ?? []
                    return !paymentTagIDs.isDisjoint(with: selectedTagUUIDs)
                }
            }
        }

        return filtered
    }

    private func loadPaidAmounts(for payments: [ScheduledPayment], month: Date) -> [String: [PaidOccurrenceInfo]] {
        guard let context = modelContext else { return [:] }
        return ScheduledPaymentPaidStatusHelper.loadPaidAmounts(for: payments, month: month, context: context)
    }

    // MARK: - Data Calculation

    /// Calculate and group payments for display, filtered by selectedMonth
    func calculatePaymentData(payments: [ScheduledPayment]) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date.now)
        let isCurrentMonth = calendar.isDate(selectedMonth, equalTo: today, toGranularity: .month)
        let isPastMonth = calendar.startOfMonth(for: selectedMonth) < calendar.startOfMonth(for: today)

        // Filter by tab (payment category)
        var filtered = payments
        if let categoryFilter = selectedTab.categoryFilter {
            filtered = filtered.filter { $0.paymentCategory == categoryFilter }
        }

        // Filter income payments in expenses-only mode
        if SessionState.shared.isExpensesOnlyMode {
            filtered = filtered.filter { $0.transactionType != "income" }
        }

        // Apply shared filters
        filtered = applyPaymentFilters(filtered)

        // Apply transaction nature filter (income/expense)
        if !selectedTransactionNatures.isEmpty {
            filtered = filtered.filter { payment in
                selectedTransactionNatures.contains(payment.transactionType)
            }
        }

        // Filter to only payments with occurrences in selectedMonth
        filtered = filtered.filter { payment in
            !getPaymentDatesInMonth(payment: payment, month: selectedMonth).isEmpty
        }

        // Load paid amounts for ALL payments (not just filtered) so calculateMonthlyTotal() can use the cache
        cachedPaidAmounts = loadPaidAmounts(for: payments, month: selectedMonth)
        let paidAmounts = cachedPaidAmounts
        paidStatusForMonth = paidAmounts.mapValues(\.count)

        // Calculate summaries with one entry per occurrence
        var summaries: [ScheduledPaymentSummary] = []
        for payment in filtered {
            let dates = getPaymentDatesInMonth(payment: payment, month: selectedMonth)
            var remainingInfos = paidAmounts[payment.id.uuidString] ?? []

            for date in dates.sorted() {
                let dueStatus: DueStatus
                if isPastMonth {
                    dueStatus = .past
                } else if isCurrentMonth {
                    let dueDate = calendar.startOfDay(for: date)
                    let daysUntil = calendar.dateComponents([.day], from: today, to: dueDate).day ?? 0
                    if daysUntil < 0 { dueStatus = .past }
                    else if daysUntil == 0 { dueStatus = .today }
                    else { dueStatus = .upcoming }
                } else {
                    dueStatus = .upcoming
                }

                let daysUntilDue = calendar.dateComponents([.day], from: today, to: date).day ?? 0
                let (icon, color) = getPaymentDisplayProperties(payment: payment)
                let isSkipped = payment.isDateSkipped(date)
                let isPaid = !remainingInfos.isEmpty && !isSkipped
                var occurrencePaidAmount: Double? = nil
                var occurrencePaidCurrency: String? = nil
                if isPaid {
                    let info = remainingInfos.removeFirst()
                    occurrencePaidAmount = info.amount
                    occurrencePaidCurrency = info.currencyCode
                }

                summaries.append(ScheduledPaymentSummary(
                    payment: payment,
                    dueDate: date,
                    dueStatus: dueStatus,
                    daysUntilDue: daysUntilDue,
                    icon: icon,
                    color: color,
                    isPaidForMonth: isPaid,
                    isSkippedForMonth: isSkipped,
                    paidAmount: occurrencePaidAmount,
                    paidCurrencyCode: occurrencePaidCurrency
                ))
            }
        }

        // Group by due status
        let grouped = Dictionary(grouping: summaries) { $0.dueStatus }

        // Sort by status order and create final array
        groupedPayments = DueStatus.allCases
            .compactMap { status -> (status: DueStatus, payments: [ScheduledPaymentSummary])? in
                guard let payments = grouped[status], !payments.isEmpty else { return nil }
                // Sort payments within each status by due date
                let sortedPayments = payments.sorted { $0.dueDate < $1.dueDate }
                return (status: status, payments: sortedPayments)
            }
            .sorted { $0.status.sortOrder < $1.status.sortOrder }

        invalidateMonthlyTotals()
    }

    // MARK: - Display Properties

    /// Determine display icon and color for a payment
    func getPaymentDisplayProperties(payment: ScheduledPayment) -> (icon: String, color: String) {
        // If has subcategory, use its icon/color
        if let subcategory = payment.subcategory {
            let icon = subcategory.iconName ?? subcategory.safeCategory.iconName ?? "creditcard.fill"
            let color = subcategory.colorHex ?? subcategory.safeCategory.colorHex
            return (icon, color)
        }

        // Default based on payment category
        if payment.paymentCategory == PaymentCategory.subscription.rawValue {
            return ("creditcard.and.123", AppConstants.defaultColorHex) // Electric indigo
        } else {
            return ("arrow.trianglehead.2.clockwise.rotate.90", AppConstants.defaultColorHex)
        }
    }

    // MARK: - Filter Actions

    /// Clear all filters
    func clearFilters() {
        selectedAccounts.removeAll()
        selectedCategories.removeAll()
        selectedSubcategories.removeAll()
        selectedTags.removeAll()
        selectedTransactionNatures.removeAll()
    }

    // MARK: - Editor Actions

    /// Open editor for new payment
    func createNewPayment() {
        editingPayment = nil
        showPaymentEditor = true
    }

    // MARK: - Transaction Association (M3)

    /// Fetch candidate transactions for manual association with a scheduled payment.
    /// Filters: within ±15 days of the occurrence date, same type (income/expense), no existing association.
    /// The window spans adjacent months so a payment registered just before/after the due date is still found.
    /// Sorted by amount proximity to payment amount.
    func fetchCandidateTransactions(for payment: ScheduledPayment, referenceDate: Date) -> [TransactionItem] {
        guard let context = modelContext else { return [] }
        let calendar = Calendar.current
        let referenceDay = calendar.startOfDay(for: referenceDate)
        guard let windowStart = calendar.date(byAdding: .day, value: -15, to: referenceDay),
              let windowEnd = calendar.date(byAdding: .day, value: 16, to: referenceDay) else { return [] }

        do {
            var descriptor = FetchDescriptor<TransactionItem>(
                predicate: #Predicate<TransactionItem> { tx in
                    tx.date >= windowStart && tx.date < windowEnd &&
                    tx.scheduledPaymentID == nil
                },
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            descriptor.fetchLimit = 100 // Perf: candidate picker — window-bounded + unlinked
            var transactions = try context.fetch(descriptor)

            // Filter by transaction type (income matches income, expense matches expense)
            let isPaymentIncome = payment.transactionType == "income"
            transactions = transactions.filter { tx in
                let isTxIncome = tx.category?.isIncome ?? false
                return isTxIncome == isPaymentIncome
            }

            // Sort: note match > subcategory > currency > account > amount proximity > recency
            transactions.sort { tx1, tx2 in
                // 1. Note contains payment name (case-insensitive)
                let tx1NoteMatch = tx1.note?.localizedCaseInsensitiveContains(payment.name) == true
                let tx2NoteMatch = tx2.note?.localizedCaseInsensitiveContains(payment.name) == true
                if tx1NoteMatch != tx2NoteMatch { return tx1NoteMatch }

                // 2. Same subcategory
                if let paymentSubID = payment.subcategory?.persistentModelID {
                    let tx1SubMatch = tx1.subcategory?.persistentModelID == paymentSubID
                    let tx2SubMatch = tx2.subcategory?.persistentModelID == paymentSubID
                    if tx1SubMatch != tx2SubMatch { return tx1SubMatch }
                }

                // 3. Currency match
                let tx1CurrencyMatch = tx1.currencyCode == payment.currencyCode
                let tx2CurrencyMatch = tx2.currencyCode == payment.currencyCode
                if tx1CurrencyMatch != tx2CurrencyMatch { return tx1CurrencyMatch }

                // 4. Account match
                if let paymentAccount = payment.account {
                    let paymentAccountID = paymentAccount.persistentModelID
                    let tx1AccountMatch = tx1.account?.persistentModelID == paymentAccountID
                    let tx2AccountMatch = tx2.account?.persistentModelID == paymentAccountID
                    if tx1AccountMatch != tx2AccountMatch { return tx1AccountMatch }
                }

                // 5. Amount proximity
                let diff1 = abs(tx1.amount - payment.amount)
                let diff2 = abs(tx2.amount - payment.amount)
                if diff1 != diff2 { return diff1 < diff2 }

                // 6. Most recent first
                return tx1.date > tx2.date
            }

            return transactions
        } catch {
            #if DEBUG
            print("ScheduledPaymentsViewModel: Error fetching candidate transactions: \(error)")
            #endif
            return []
        }
    }

    /// Associate a transaction with a scheduled payment
    func associateTransaction(_ transaction: TransactionItem, to payment: ScheduledPayment) {
        transaction.scheduledPaymentID = payment.id.uuidString

        // Update paid date and advance to next occurrence (fixes duplicate draft bug)
        payment.lastPaidDate = transaction.date
        ScheduledPaymentDraftService.advanceToNextDueDate(payment: payment)

        // Reject any pending draft for this payment
        rejectPendingDraft(for: payment)

        guard let context = modelContext else { return }
        do {
            try context.save()
            WidgetDataCache.updateCache(context: context)
            SessionState.shared.incrementDataVersion()
        } catch {
            #if DEBUG
            print("ScheduledPaymentsViewModel: Error associating transaction: \(error)")
            #endif
        }
    }

    /// Unlink a transaction from its scheduled payment
    func unlinkTransaction(_ transaction: TransactionItem) {
        transaction.scheduledPaymentID = nil

        guard let context = modelContext else { return }
        do {
            try context.save()
            WidgetDataCache.updateCache(context: context)
            SessionState.shared.incrementDataVersion()
        } catch {
            #if DEBUG
            print("ScheduledPaymentsViewModel: Error unlinking transaction: \(error)")
            #endif
        }
    }

    /// Unlink all transactions for a scheduled payment on a specific date (batch save)
    func unlinkTransactionsForDate(paymentID: UUID, date: Date) {
        guard let context = modelContext else { return }
        let calendar = Calendar.current
        let paymentIDString = paymentID.uuidString

        do {
            let predicate = #Predicate<TransactionItem> { tx in
                tx.scheduledPaymentID == paymentIDString
            }
            let descriptor = FetchDescriptor<TransactionItem>(predicate: predicate)
            let linkedTransactions = try context.fetch(descriptor)

            var didUnlink = false
            for tx in linkedTransactions {
                if calendar.isDate(tx.date, inSameDayAs: date) {
                    tx.scheduledPaymentID = nil
                    didUnlink = true
                }
            }

            if didUnlink {
                try context.save()
                WidgetDataCache.updateCache(context: context)
                SessionState.shared.incrementDataVersion()
            }
        } catch {
            #if DEBUG
            print("ScheduledPaymentsViewModel: Error unlinking transactions for date: \(error)")
            #endif
        }
    }

    // MARK: - Advance Occurrence

    /// Advance (pay early) the next occurrence of a scheduled payment.
    /// Creates a draft with today's date and advances nextDueDate.
    @discardableResult
    func advanceOccurrence(payment: ScheduledPayment) -> InboxDraft? {
        guard let context = modelContext else { return nil }
        guard let draft = ScheduledPaymentDraftService.createAdvancedDraft(from: payment, context: context) else { return nil }
        do {
            try context.save()
            WidgetDataCache.updateCache(context: context)
            SessionState.shared.incrementDataVersion()
        } catch {
            #if DEBUG
            print("ScheduledPaymentsViewModel: Error saving advance: \(error)")
            #endif
            return nil
        }
        loadPayments()
        return draft
    }

    // MARK: - Fetch Linked Transactions

    /// Fetch transactions linked to a scheduled payment (for real history data).
    func fetchLinkedTransactions(for payment: ScheduledPayment, months: Int = 4) -> [TransactionItem] {
        guard let context = modelContext else { return [] }
        let calendar = Calendar.current
        let paymentIDString = payment.id.uuidString
        guard let startDate = calendar.date(byAdding: .month, value: -months, to: Date.now) else { return [] }

        do {
            let predicate = #Predicate<TransactionItem> { tx in
                tx.scheduledPaymentID == paymentIDString &&
                tx.date >= startDate
            }
            let descriptor = FetchDescriptor<TransactionItem>(
                predicate: predicate,
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            return try context.fetch(descriptor)
        } catch {
            #if DEBUG
            print("ScheduledPaymentsViewModel: Error fetching linked transactions: \(error)")
            #endif
            return []
        }
    }

    // MARK: - Subscriptions Calendar

    /// Get all subscriptions (filtered)
    func getSubscriptions(from payments: [ScheduledPayment]) -> [ScheduledPayment] {
        var filtered = payments.filter { $0.paymentCategory == PaymentCategory.subscription.rawValue }
        if SessionState.shared.isExpensesOnlyMode {
            filtered = filtered.filter { $0.transactionType != "income" }
        }
        return applyPaymentFilters(filtered)
    }

    /// Get all recurring payments (non-subscription, filtered)
    func getRecurringPayments(from payments: [ScheduledPayment]) -> [ScheduledPayment] {
        var filtered = payments.filter { $0.paymentCategory == PaymentCategory.recurring.rawValue }
        if SessionState.shared.isExpensesOnlyMode {
            filtered = filtered.filter { $0.transactionType != "income" }
        }
        return applyPaymentFilters(filtered)
    }

    /// Calculate total monthly subscription spending for a given month, converting all amounts to preferredCurrencyCode
    func calculateMonthlyTotal(subscriptions: [ScheduledPayment], for month: Date, preferredCurrencyCode: String? = nil) -> Double {
        var total: Double = 0
        let converter = CurrencyConverter.shared
        let targetCurrency = preferredCurrencyCode

        // Only count expenses (exclude income payments)
        let expensePayments = subscriptions.filter { $0.isActive && $0.transactionType != "income" }

        let paidAmounts = cachedPaidAmounts

        for payment in expensePayments {
            let occurrences = getPaymentDatesInMonth(payment: payment, month: month)
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

                if let target = targetCurrency, currency != target, amount > 0 {
                    let decimalAmount = Decimal(amount)
                    let converted: Decimal
                    if let context = modelContext {
                        converted = converter.convertWithLatestRate(decimalAmount, from: currency, to: target, context: context)
                    } else {
                        converted = converter.convertWithFallback(decimalAmount, from: currency, to: target)
                    }
                    total += NSDecimalNumber(decimal: converted).doubleValue
                } else {
                    total += amount
                }
            }
        }

        return total
    }

    /// Get payment dates for a subscription in a given month (delegates to shared calculator)
    func getPaymentDatesInMonth(payment: ScheduledPayment, month: Date) -> [Date] {
        ScheduledPaymentDateCalculator.paymentDatesInMonth(
            params: payment.dateCalculatorParams, month: month
        )
    }

    /// Move calendar to previous month
    func previousMonth() {
        let calendar = Calendar.current
        if let newMonth = calendar.date(byAdding: .month, value: -1, to: selectedMonth) {
            selectedMonth = newMonth
        }
    }

    /// Move calendar to next month
    func nextMonth() {
        let calendar = Calendar.current
        if let newMonth = calendar.date(byAdding: .month, value: 1, to: selectedMonth) {
            selectedMonth = newMonth
        }
    }

    // MARK: - Debounced Recalculation

    /// Suppresses recalculation when the app leaves active state — prevents 0x8BADF00D.
    func setBackground(_ value: Bool) {
        isInBackground = value
        if value {
            recalculateTask?.cancel()
            recalculateTask = nil
            pendingReload = false
        }
    }

    /// Cancel any pending recalculation (call from `.onDisappear`).
    func cancelRecalculation() {
        recalculateTask?.cancel()
    }

    /// Compute-only debounced (150ms). Use when a filter/UI input changed
    /// but the underlying DB hasn't mutated (tab switch, selectedMonth change).
    func recalculateData() {
        scheduleRecalculation(reload: false)
    }

    /// Reload + compute debounced (150ms). Use when DB mutations could have
    /// occurred (editor dismiss, `dataVersion` bump).
    func reloadAndRecalculate() {
        scheduleRecalculation(reload: true)
    }

    /// Shared debounce (150ms). `pendingReload` ensures a reload request isn't lost
    /// if a subsequent compute-only call arrives within the debounce window.
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
            if shouldReload { loadPayments() }
            calculatePaymentData(payments: allPayments)
        }
    }
}

// MARK: - Subscriptions View Mode

enum PaymentsViewMode: String, CaseIterable, Identifiable {
    case list
    case calendar

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .list: return "list.bullet"
        case .calendar: return "calendar"
        }
    }
}
