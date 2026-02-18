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
    var selectedMonth: Date = Date()

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
        let now = Date()
        if calendar.isDate(selectedMonth, equalTo: now, toGranularity: .month) {
            return L10n.Period.thisMonth
        } else if let lastMonth = calendar.date(byAdding: .month, value: -1, to: now),
                  calendar.isDate(selectedMonth, equalTo: lastMonth, toGranularity: .month) {
            return L10n.Period.lastMonth
        } else if let nextMonth = calendar.date(byAdding: .month, value: 1, to: now),
                  calendar.isDate(selectedMonth, equalTo: nextMonth, toGranularity: .month) {
            return L10n.Period.nextMonth
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: selectedMonth).capitalized
        }
    }

    // MARK: - Paid/Pending Totals

    /// All flat summaries from groupedPayments
    private var allSummaries: [ScheduledPaymentSummary] {
        groupedPayments.flatMap(\.payments)
    }

    /// Monthly total of paid payments (excluding income, matching calculateMonthlyTotal)
    var monthlyTotalPaid: Double {
        allSummaries.filter { $0.isPaidForMonth && $0.payment.transactionType != "income" }
            .reduce(0) { $0 + $1.payment.amount }
    }

    /// Monthly total of pending (unpaid) payments (excluding income)
    var monthlyTotalPending: Double {
        allSummaries.filter { !$0.isPaidForMonth && $0.payment.transactionType != "income" }
            .reduce(0) { $0 + $1.payment.amount }
    }

    /// Grouped payments filtered by paymentStatusFilter
    var filteredGroupedPayments: [(status: DueStatus, payments: [ScheduledPaymentSummary])] {
        if paymentStatusFilter == .all { return groupedPayments }

        let isPaidFilter = paymentStatusFilter == .paid
        return groupedPayments.compactMap { section in
            let filtered = section.payments.filter { $0.isPaidForMonth == isPaidFilter }
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
        } catch {
            #if DEBUG
            print("ScheduledPaymentsViewModel: Error loading payments: \(error)")
            #endif
        }
    }

    // MARK: - Paid Status

    /// Batch load paid count for a set of payments in a given month.
    /// Checks both InboxDraft (approved with sourceScheduledPaymentID) and
    /// TransactionItem (with scheduledPaymentID).
    /// Returns dictionary [paymentIDString: paidCount]
    private func loadPaidStatus(for payments: [ScheduledPayment], month: Date) -> [String: Int] {
        guard let context = modelContext else { return [:] }
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: month) else { return [:] }

        var result: [String: Int] = [:]
        let paymentIDs = Set(payments.map { $0.id.uuidString })

        // Query 1: InboxDrafts approved with sourceScheduledPaymentID
        do {
            var draftDescriptor = FetchDescriptor<InboxDraft>(
                predicate: #Predicate<InboxDraft> { draft in
                    draft.statusRaw == "approved" && draft.sourceScheduledPaymentID != nil
                }
            )
            draftDescriptor.propertiesToFetch = [\.sourceScheduledPaymentID, \.date]
            let approvedDrafts = try context.fetch(draftDescriptor)

            for draft in approvedDrafts {
                guard let spID = draft.sourceScheduledPaymentID, paymentIDs.contains(spID) else { continue }
                // Check if the approved transaction date is within the month
                let draftDate = draft.approvedTransaction?.date ?? draft.date ?? draft.createdAt
                if draftDate >= monthInterval.start && draftDate < monthInterval.end {
                    result[spID, default: 0] += 1
                }
            }
        } catch {
            #if DEBUG
            print("ScheduledPaymentsViewModel: Error loading draft paid status: \(error)")
            #endif
        }

        // Query 2: TransactionItems with scheduledPaymentID
        do {
            var txDescriptor = FetchDescriptor<TransactionItem>(
                predicate: #Predicate<TransactionItem> { tx in
                    tx.scheduledPaymentID != nil
                }
            )
            txDescriptor.propertiesToFetch = [\.scheduledPaymentID, \.date]
            let linkedTransactions = try context.fetch(txDescriptor)

            for tx in linkedTransactions {
                guard let spID = tx.scheduledPaymentID, paymentIDs.contains(spID) else { continue }
                if tx.date >= monthInterval.start && tx.date < monthInterval.end {
                    result[spID, default: 0] += 1
                }
            }
        } catch {
            #if DEBUG
            print("ScheduledPaymentsViewModel: Error loading tx paid status: \(error)")
            #endif
        }

        return result
    }

    // MARK: - Data Calculation

    /// Calculate and group payments for display, filtered by selectedMonth
    func calculatePaymentData(payments: [ScheduledPayment]) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
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

        // Filter by active status
        if hideInactive {
            filtered = filtered.filter { $0.isActive }
        }

        // Apply account filter
        if !selectedAccounts.isEmpty {
            filtered = filtered.filter { payment in
                guard let accountID = payment.account?.persistentModelID else { return false }
                return selectedAccounts.contains(accountID)
            }
        }

        // Apply subcategory filter
        if !selectedSubcategories.isEmpty {
            filtered = filtered.filter { payment in
                guard let subID = payment.subcategory?.persistentModelID else { return false }
                return selectedSubcategories.contains(subID)
            }
        }

        // Apply category filter (if subcategory not set, check category)
        if !selectedCategories.isEmpty && selectedSubcategories.isEmpty {
            filtered = filtered.filter { payment in
                guard let catID = payment.subcategory?.safeCategory.persistentModelID else { return false }
                return selectedCategories.contains(catID)
            }
        }

        // Apply tag filter
        if !selectedTags.isEmpty {
            filtered = filtered.filter { payment in
                let paymentTagIDs = Set((payment.tags ?? []).map { $0.persistentModelID })
                return !paymentTagIDs.isDisjoint(with: selectedTags)
            }
        }

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
                let isPaid = remainingPaid > 0
                if isPaid { remainingPaid -= 1 }

                summaries.append(ScheduledPaymentSummary(
                    payment: payment,
                    dueDate: date,
                    dueStatus: dueStatus,
                    daysUntilDue: daysUntilDue,
                    icon: icon,
                    color: color,
                    isPaidForMonth: isPaid
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
            return ("creditcard.and.123", "#6366F1") // Electric indigo
        } else {
            return ("arrow.trianglehead.2.clockwise.rotate.90", "#6366F1")
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

            // Sort: same currency first, then same account, then amount proximity
            transactions.sort { tx1, tx2 in
                let tx1CurrencyMatch = tx1.currencyCode == payment.currencyCode
                let tx2CurrencyMatch = tx2.currencyCode == payment.currencyCode
                if tx1CurrencyMatch != tx2CurrencyMatch { return tx1CurrencyMatch }

                if let paymentAccount = payment.account {
                    let paymentAccountID = paymentAccount.persistentModelID
                    let tx1AccountMatch = tx1.account?.persistentModelID == paymentAccountID
                    let tx2AccountMatch = tx2.account?.persistentModelID == paymentAccountID
                    if tx1AccountMatch != tx2AccountMatch { return tx1AccountMatch }
                }

                let diff1 = abs(tx1.amount - payment.amount)
                let diff2 = abs(tx2.amount - payment.amount)
                return diff1 < diff2
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

        guard let context = modelContext else { return }
        do {
            try context.save()
            // Refresh paid status
            SessionState.shared.dataVersion += 1
        } catch {
            #if DEBUG
            print("ScheduledPaymentsViewModel: Error associating transaction: \(error)")
            #endif
        }
    }

    // MARK: - Subscriptions Calendar

    /// Get all subscriptions (filtered)
    func getSubscriptions(from payments: [ScheduledPayment]) -> [ScheduledPayment] {
        var filtered = payments.filter { $0.paymentCategory == PaymentCategory.subscription.rawValue }

        // Filter income payments in expenses-only mode
        if SessionState.shared.isExpensesOnlyMode {
            filtered = filtered.filter { $0.transactionType != "income" }
        }

        // Apply filters
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

    /// Get all recurring payments (non-subscription, filtered)
    func getRecurringPayments(from payments: [ScheduledPayment]) -> [ScheduledPayment] {
        var filtered = payments.filter { $0.paymentCategory == PaymentCategory.recurring.rawValue }

        // Filter income payments in expenses-only mode
        if SessionState.shared.isExpensesOnlyMode {
            filtered = filtered.filter { $0.transactionType != "income" }
        }

        // Apply same filters as subscriptions
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

    /// Get payment dates for a subscription in a given month
    func getPaymentDatesInMonth(payment: ScheduledPayment, month: Date) -> [Date] {
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: month) else { return [] }

        var dates: [Date] = []

        // For one-time payments
        if !payment.isRecurring {
            let paymentDate = calendar.startOfDay(for: payment.nextDueDate)
            if monthInterval.contains(paymentDate) {
                dates.append(paymentDate)
            }
            return dates
        }

        // For recurring payments
        guard let recurrenceType = RecurrenceType(rawValue: payment.recurrenceType) else { return [] }

        switch recurrenceType {
        case .daily:
            // Daily: every interval days
            var date = calendar.startOfDay(for: payment.nextDueDate)
            // Go back to find the first occurrence in or before this month
            while date > monthInterval.start {
                date = calendar.date(byAdding: .day, value: -payment.recurrenceInterval, to: date) ?? date
            }
            // Now iterate forward
            while date < monthInterval.end {
                if date >= monthInterval.start {
                    dates.append(date)
                }
                date = calendar.date(byAdding: .day, value: payment.recurrenceInterval, to: date) ?? monthInterval.end
            }

        case .weekly:
            // Weekly: specific weekdays
            let weekdays = parseWeekdays(payment.selectedWeekdays)
            if weekdays.isEmpty { return dates }

            // Iterate through each day of the month
            var date = monthInterval.start
            while date < monthInterval.end {
                let weekday = calendar.component(.weekday, from: date)
                if weekdays.contains(weekday) {
                    dates.append(date)
                }
                date = calendar.date(byAdding: .day, value: 1, to: date) ?? monthInterval.end
            }

        case .monthly:
            // Monthly: specific day of month
            let dayOfMonth = payment.dayOfMonth ?? calendar.component(.day, from: payment.nextDueDate)
            let monthComponents = calendar.dateComponents([.year, .month], from: month)
            if var paymentDate = calendar.date(from: DateComponents(
                year: monthComponents.year,
                month: monthComponents.month,
                day: min(dayOfMonth, calendar.range(of: .day, in: .month, for: month)?.count ?? 28)
            )) {
                paymentDate = calendar.startOfDay(for: paymentDate)
                if monthInterval.contains(paymentDate) {
                    dates.append(paymentDate)
                }
            }

        case .yearly:
            // Yearly: specific month and day
            let targetMonth = payment.yearlyMonth ?? calendar.component(.month, from: payment.nextDueDate)
            let targetDay = payment.yearlyDay ?? calendar.component(.day, from: payment.nextDueDate)
            let monthComponents = calendar.dateComponents([.year, .month], from: month)

            if monthComponents.month == targetMonth {
                if let paymentDate = calendar.date(from: DateComponents(
                    year: monthComponents.year,
                    month: targetMonth,
                    day: targetDay
                )) {
                    let startOfPayment = calendar.startOfDay(for: paymentDate)
                    if monthInterval.contains(startOfPayment) {
                        dates.append(startOfPayment)
                    }
                }
            }
        }

        // Filter out dates before payment creation (M4: no backward propagation)
        let createdDay = calendar.startOfDay(for: payment.createdAt)
        return dates.filter { $0 >= createdDay }
    }

    /// Parse weekdays string "1,3,5" into set of weekday integers
    private func parseWeekdays(_ weekdaysString: String?) -> Set<Int> {
        guard let string = weekdaysString, !string.isEmpty else { return [] }
        return Set(string.split(separator: ",").compactMap { Int($0) })
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
