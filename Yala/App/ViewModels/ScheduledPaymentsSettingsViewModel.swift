//
//  ScheduledPaymentsSettingsViewModel.swift
//  Yala
//
//  ViewModel for ScheduledPaymentsSettingsView - handles scheduled payments list operations.
//  Fase D: Arquitectura - @Query → ViewModels
//

import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class ScheduledPaymentsSettingsViewModel {

    // MARK: - Dependencies

    private var modelContext: ModelContext?

    // MARK: - Data

    private(set) var allPayments: [ScheduledPayment] = []

    // MARK: - UI State

    var showEditor = false
    var paymentToEdit: ScheduledPayment?
    var selectedTab: ScheduledPaymentsTab = .all
    var showDeleteError = false

    // MARK: - Computed Properties

    var filteredPayments: [ScheduledPayment] {
        switch selectedTab {
        case .all:
            return allPayments
        case .recurring:
            return allPayments.filter { $0.paymentCategory == PaymentCategory.recurring.rawValue }
        case .subscriptions:
            return allPayments.filter { $0.paymentCategory == PaymentCategory.subscription.rawValue }
        }
    }

    var isEmpty: Bool {
        filteredPayments.isEmpty
    }

    // MARK: - Context Injection

    func setContext(_ context: ModelContext) {
        self.modelContext = context
        loadPayments()
    }

    // MARK: - Data Loading

    func loadPayments() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<ScheduledPayment>(sortBy: [SortDescriptor(\ScheduledPayment.name)])
        do {
            allPayments = try context.fetch(descriptor)
        } catch {
            #if DEBUG
            print("ScheduledPaymentsSettingsViewModel: Error loading payments: \(error)")
            #endif
            allPayments = []
        }
    }

    // MARK: - Payment Operations

    func deletePayments(at offsets: IndexSet) {
        guard let context = modelContext else { return }

        let service = EntityDeletionService.shared
        service.setContext(context)

        do {
            for index in offsets {
                let payment = filteredPayments[index]
                try service.deleteScheduledPayment(payment)
            }
            WidgetDataCache.updateCache(context: context)
            SessionState.shared.incrementDataVersion()
            loadPayments()
        } catch {
            #if DEBUG
            print("ScheduledPaymentsSettingsViewModel: Error deleting payments: \(error)")
            #endif
            showDeleteError = true
        }
    }

    func openEditor(for payment: ScheduledPayment?) {
        paymentToEdit = payment
        showEditor = true
    }

    func closeEditor() {
        paymentToEdit = nil
        showEditor = false
        loadPayments()
    }
}
