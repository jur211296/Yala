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

    /// Currently displayed month in calendar view
    var calendarDisplayedMonth: Date = Date()

    // MARK: - Computed Data

    /// Payments grouped by due status
    var groupedPayments: [(status: DueStatus, payments: [ScheduledPaymentSummary])] = []

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
            print("ScheduledPaymentsViewModel: Error loading payments: \(error)")
        }
    }

    // MARK: - Data Calculation

    /// Calculate and group payments for display
    func calculatePaymentData(payments: [ScheduledPayment]) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Filter by tab (payment category)
        var filtered = payments
        if let categoryFilter = selectedTab.categoryFilter {
            filtered = filtered.filter { $0.paymentCategory == categoryFilter }
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
                guard let catID = payment.subcategory?.category.persistentModelID else { return false }
                return selectedCategories.contains(catID)
            }
        }

        // Apply tag filter
        if !selectedTags.isEmpty {
            filtered = filtered.filter { payment in
                let paymentTagIDs = Set(payment.tags.map { $0.persistentModelID })
                return !paymentTagIDs.isDisjoint(with: selectedTags)
            }
        }

        // Apply transaction nature filter (income/expense)
        if !selectedTransactionNatures.isEmpty {
            filtered = filtered.filter { payment in
                selectedTransactionNatures.contains(payment.transactionType)
            }
        }

        // Calculate summaries with due status
        let summaries = filtered.map { payment -> ScheduledPaymentSummary in
            let dueDate = calendar.startOfDay(for: payment.nextDueDate)
            let daysUntilDue = calendar.dateComponents([.day], from: today, to: dueDate).day ?? 0

            let dueStatus: DueStatus
            if daysUntilDue < 0 {
                dueStatus = .past
            } else if daysUntilDue == 0 {
                dueStatus = .today
            } else {
                dueStatus = .upcoming
            }

            let (icon, color) = getPaymentDisplayProperties(payment: payment)

            return ScheduledPaymentSummary(
                payment: payment,
                dueStatus: dueStatus,
                daysUntilDue: daysUntilDue,
                icon: icon,
                color: color
            )
        }

        // Group by due status
        let grouped = Dictionary(grouping: summaries) { $0.dueStatus }

        // Sort by status order and create final array
        groupedPayments = DueStatus.allCases
            .compactMap { status -> (status: DueStatus, payments: [ScheduledPaymentSummary])? in
                guard let payments = grouped[status], !payments.isEmpty else { return nil }
                // Sort payments within each status by due date
                let sortedPayments = payments.sorted { $0.payment.nextDueDate < $1.payment.nextDueDate }
                return (status: status, payments: sortedPayments)
            }
            .sorted { $0.status.sortOrder < $1.status.sortOrder }
    }

    // MARK: - Display Properties

    /// Determine display icon and color for a payment
    func getPaymentDisplayProperties(payment: ScheduledPayment) -> (icon: String, color: String) {
        // If has subcategory, use its icon/color
        if let subcategory = payment.subcategory {
            let icon = subcategory.iconName ?? subcategory.category.iconName ?? "creditcard.fill"
            let color = subcategory.colorHex ?? subcategory.category.colorHex
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

    // MARK: - Subscriptions Calendar

    /// Get all subscriptions (filtered)
    func getSubscriptions(from payments: [ScheduledPayment]) -> [ScheduledPayment] {
        var filtered = payments.filter { $0.paymentCategory == PaymentCategory.subscription.rawValue }

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
                guard let catID = payment.subcategory?.category.persistentModelID else { return false }
                return selectedCategories.contains(catID)
            }
        }
        if !selectedTags.isEmpty {
            filtered = filtered.filter { payment in
                let paymentTagIDs = Set(payment.tags.map { $0.persistentModelID })
                return !paymentTagIDs.isDisjoint(with: selectedTags)
            }
        }

        return filtered
    }

    /// Get all recurring payments (non-subscription, filtered)
    func getRecurringPayments(from payments: [ScheduledPayment]) -> [ScheduledPayment] {
        var filtered = payments.filter { $0.paymentCategory == PaymentCategory.recurring.rawValue }

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
                guard let catID = payment.subcategory?.category.persistentModelID else { return false }
                return selectedCategories.contains(catID)
            }
        }
        if !selectedTags.isEmpty {
            filtered = filtered.filter { payment in
                let paymentTagIDs = Set(payment.tags.map { $0.persistentModelID })
                return !paymentTagIDs.isDisjoint(with: selectedTags)
            }
        }

        return filtered
    }

    /// Calculate total monthly subscription spending for a given month
    func calculateMonthlyTotal(subscriptions: [ScheduledPayment], for month: Date) -> Double {
        var total: Double = 0

        for subscription in subscriptions where subscription.isActive {
            // Calculate how many times this subscription occurs in the month
            let occurrences = getPaymentDatesInMonth(payment: subscription, month: month)
            total += subscription.amount * Double(occurrences.count)
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

        return dates
    }

    /// Parse weekdays string "1,3,5" into set of weekday integers
    private func parseWeekdays(_ weekdaysString: String?) -> Set<Int> {
        guard let string = weekdaysString, !string.isEmpty else { return [] }
        return Set(string.split(separator: ",").compactMap { Int($0) })
    }

    /// Move calendar to previous month
    func previousMonth() {
        let calendar = Calendar.current
        if let newMonth = calendar.date(byAdding: .month, value: -1, to: calendarDisplayedMonth) {
            calendarDisplayedMonth = newMonth
        }
    }

    /// Move calendar to next month
    func nextMonth() {
        let calendar = Calendar.current
        if let newMonth = calendar.date(byAdding: .month, value: 1, to: calendarDisplayedMonth) {
            calendarDisplayedMonth = newMonth
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
