//
//  ScheduledPaymentsViewModel.swift
//  Neto
//
//  ViewModel for managing scheduled payments, filtering, and UI state
//

import Foundation
import SwiftData
import SwiftUI

@Observable
final class ScheduledPaymentsViewModel {

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
}
