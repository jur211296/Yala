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
        let summaries = allSummaries.filter { $0.isPaidForMonth && !$0.isSkippedForMonth && $0.payment.transactionType != "income" }
        return convertedTotal(for: summaries, preferredCurrencyCode: preferredCurrencyCode)
    }

    /// Monthly total of pending (unpaid, non-skipped) payments (excluding income), converted to preferred currency
    func monthlyTotalPending(preferredCurrencyCode: String) -> Double {
        let summaries = allSummaries.filter { !$0.isPaidForMonth && !$0.isSkippedForMonth && $0.payment.transactionType != "income" }
        return convertedTotal(for: summaries, preferredCurrencyCode: preferredCurrencyCode)
    }

    private func convertedTotal(for summaries: [ScheduledPaymentSummary], preferredCurrencyCode: String) -> Double {
        let converter = CurrencyConverter.shared
        var total: Double = 0
        for summary in summaries {
            let amount = summary.payment.amount
            if summary.payment.currencyCode != preferredCurrencyCode, amount > 0 {
                let decimal = Decimal(amount)
                let converted: Decimal
                if let context = modelContext {
                    converted = converter.convertWithLatestRate(decimal, from: summary.payment.currencyCode, to: preferredCurrencyCode, context: context)
                } else {
                    converted = converter.convertWithFallback(decimal, from: summary.payment.currencyCode, to: preferredCurrencyCode)
                }
                total += NSDecimalNumber(decimal: converted).doubleValue
            } else {
                total += amount
            }
        }
        return total
    }

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
        self.modelContext = context
        loadPayments()
    }

    func loadPayments() {
        guard let context = modelContext else { return }

        let descriptor = FetchDescriptor<ScheduledPayment>(
            sortBy: [SortDescriptor(\.nextDueDate)]
        )

        do {
            allPayments = try context.fetch(descriptor)
            // Clean up skipped dates older than 1 year (prevents unbounded growth via iCloud sync)
            for payment in allPayments {
                payment.cleanupOldSkippedDates()
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
            filtered = filtered.filter { payment in
                let paymentTagIDs = Set((payment.tags ?? []).map { $0.persistentModelID })
                return !paymentTagIDs.isDisjoint(with: selectedTags)
            }
        }

        return filtered
    }

    private func loadPaidStatus(for payments: [ScheduledPayment], month: Date) -> [String: Int] {
        guard let context = modelContext else { return [:] }
        return ScheduledPaymentPaidStatusHelper.loadPaidStatus(for: payments, month: month, context: context)
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

        // Load paid status for all payments in this month (batch)
        let paidStatus = loadPaidStatus(for: filtered, month: selectedMonth)
        paidStatusForMonth = paidStatus

        // Calculate summaries with one entry per occurrence
        var summaries: [ScheduledPaymentSummary] = []
        for payment in filtered {
            let dates = getPaymentDatesInMonth(payment: payment, month: selectedMonth)
            let paidCount = paidStatus[payment.id.uuidString] ?? 0
            var remainingPaid = paidCount

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
                let isPaid = remainingPaid > 0 && !isSkipped
                if isPaid { remainingPaid -= 1 }

                summaries.append(ScheduledPaymentSummary(
                    payment: payment,
                    dueDate: date,
                    dueStatus: dueStatus,
                    daysUntilDue: daysUntilDue,
                    icon: icon,
                    color: color,
                    isPaidForMonth: isPaid,
                    isSkippedForMonth: isSkipped
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

    /// Open editor for existing payment
    func editPayment(_ payment: ScheduledPayment) {
        editingPayment = payment
        showPaymentEditor = true
    }

    // MARK: - Transaction Association (M3)

    /// Fetch candidate transactions for manual association with a scheduled payment.
    /// Filters: same month, same type (income/expense), same account (if set), no existing association.
    /// Sorted by amount proximity to payment amount.
    func fetchCandidateTransactions(for payment: ScheduledPayment, month: Date) -> [TransactionItem] {
        guard let context = modelContext else { return [] }
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: month) else { return [] }

        let monthStart = monthInterval.start
        let monthEnd = monthInterval.end
        do {
            let descriptor = FetchDescriptor<TransactionItem>(
                predicate: #Predicate<TransactionItem> { tx in
                    tx.date >= monthStart && tx.date < monthEnd &&
                    tx.scheduledPaymentID == nil
                },
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
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
    func advanceOccurrence(payment: ScheduledPayment) {
        guard let context = modelContext else { return }
        guard ScheduledPaymentDraftService.createAdvancedDraft(from: payment, context: context) != nil else { return }
        do {
            try context.save()
            WidgetDataCache.updateCache(context: context)
            SessionState.shared.incrementDataVersion()
        } catch {
            #if DEBUG
            print("ScheduledPaymentsViewModel: Error saving advance: \(error)")
            #endif
        }
        loadPayments()
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

        for subscription in expensePayments {
            // Calculate how many times this subscription occurs in the month
            let occurrences = getPaymentDatesInMonth(payment: subscription, month: month)
            let rawAmount = subscription.amount * Double(occurrences.count)

            // Convert currency if needed
            if let target = targetCurrency, subscription.currencyCode != target, rawAmount > 0 {
                let decimalAmount = Decimal(rawAmount)
                let converted: Decimal
                if let context = modelContext {
                    converted = converter.convertWithLatestRate(
                        decimalAmount, from: subscription.currencyCode, to: target, context: context
                    )
                } else {
                    converted = converter.convertWithFallback(
                        decimalAmount, from: subscription.currencyCode, to: target
                    )
                }
                total += NSDecimalNumber(decimal: converted).doubleValue
            } else {
                total += rawAmount
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
