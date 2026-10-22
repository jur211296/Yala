//
//  ScheduledPaymentEditorViewModel.swift
//  Yala
//
//  ViewModel for ScheduledPaymentEditorView - handles data loading and save/delete operations.
//

import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class ScheduledPaymentEditorViewModel {

    // MARK: - Dependencies

    private var modelContext: ModelContext?
    private var deletionService: EntityDeletionService?

    // MARK: - Data

    private(set) var allAccounts: [Account] = []
    private(set) var allTags: [Tag] = []

    // MARK: - State

    private(set) var showSaveError = false

    // MARK: - Computed Properties

    /// A0-Bridge: excluye cuentas sistema (`isSystemAccount`) de pickers manuales.
    var activeAccounts: [Account] {
        allAccounts.filter { !$0.isArchived && !$0.isSystemAccount }
    }

    var activeTags: [Tag] {
        allTags.filter { $0.isActive }
    }

    // MARK: - Context Injection

    func setContext(_ context: ModelContext, deletionService: EntityDeletionService) {
        self.modelContext = context
        self.deletionService = deletionService
        loadData()
    }

    // MARK: - Data Loading

    func loadData() {
        guard let context = modelContext else { return }

        // Load accounts
        let accountDescriptor = FetchDescriptor<Account>(sortBy: [SortDescriptor(\Account.name)])
        do {
            allAccounts = try context.fetch(accountDescriptor)
        } catch {
            #if DEBUG
            print("ScheduledPaymentEditorViewModel: Error loading accounts: \(error)")
            #endif
            allAccounts = []
        }

        // Load tags
        let tagDescriptor = FetchDescriptor<Tag>(sortBy: [SortDescriptor(\Tag.name)])
        do {
            allTags = try context.fetch(tagDescriptor)
        } catch {
            #if DEBUG
            print("ScheduledPaymentEditorViewModel: Error loading tags: \(error)")
            #endif
            allTags = []
        }
    }

    // MARK: - Save Operation

    func savePayment(
        existing: ScheduledPayment?,
        name: String,
        amount: Double,
        note: String,
        currencyCode: String,
        transactionType: String,
        paymentCategory: PaymentCategory,
        account: Account?,
        subcategory: Subcategory?,
        selectedTags: Set<PersistentIdentifier>,
        isRecurring: Bool,
        recurrenceType: RecurrenceType,
        recurrenceInterval: Int,
        paymentDate: Date,
        dayOfMonth: Int?,
        selectedWeekdays: Set<Int>,
        yearlyMonth: Int?,
        yearlyDay: Int?,
        endDate: Date?,
        notifyOnDueDate: Bool,
        notifyDaysBefore: Int,
        isActive: Bool,
        needOverride: String? = nil,
        isVariableAmount: Bool = false,
        splitTotalAmount: Double? = nil,
        groupZoneID: String? = nil,
        splitType: String? = nil,
        splitParticipantIDs: [UUID] = [],
        splitValues: [UUID: Double] = [:]
    ) -> UUID? {
        guard let context = modelContext else { return nil }

        // Get tags array
        let tagsArray = activeTags.filter { selectedTags.contains($0.persistentModelID) }

        // Convert selectedWeekdays set to comma-separated string
        let weekdaysStr = selectedWeekdays.sorted().map { String($0) }.joined(separator: ",")

        let paymentID: UUID

        if let existingPayment = existing {
            // Update existing
            existingPayment.name = name
            existingPayment.amount = amount
            existingPayment.note = note.isEmpty ? nil : note
            existingPayment.currencyCode = currencyCode
            existingPayment.transactionType = transactionType
            existingPayment.paymentCategory = paymentCategory.rawValue
            existingPayment.account = account
            existingPayment.subcategory = subcategory
            existingPayment.setTags(from: tagsArray)
            existingPayment.needOverride = needOverride

            // Recurrence
            existingPayment.isRecurring = isRecurring
            existingPayment.recurrenceType = recurrenceType.rawValue
            existingPayment.recurrenceInterval = recurrenceInterval
            existingPayment.nextDueDate = paymentDate
            existingPayment.dayOfMonth = recurrenceType == .monthly ? dayOfMonth : nil
            existingPayment.selectedWeekdays = recurrenceType == .weekly ? weekdaysStr : nil
            existingPayment.yearlyMonth = recurrenceType == .yearly ? yearlyMonth : nil
            existingPayment.yearlyDay = recurrenceType == .yearly ? yearlyDay : nil
            existingPayment.endDate = isRecurring ? endDate : nil

            existingPayment.notifyOnDueDate = notifyOnDueDate
            existingPayment.notifyDaysBefore = notifyDaysBefore
            existingPayment.isActive = isActive
            existingPayment.isVariableAmount = isVariableAmount

            // Group shared expense (F3) — nil/[] limpia los campos si se apagó el toggle.
            existingPayment.groupZoneID = groupZoneID
            existingPayment.splitTotalAmount = splitTotalAmount
            existingPayment.splitType = splitType
            existingPayment.setSplitConfig(participantIDs: splitParticipantIDs, values: splitValues)

            paymentID = existingPayment.id
        } else {
            // Create new
            let newPayment = ScheduledPayment(
                name: name,
                note: note.isEmpty ? nil : note,
                amount: amount,
                currencyCode: currencyCode,
                transactionType: transactionType,
                account: account,
                subcategory: subcategory,
                tags: tagsArray,
                needOverride: needOverride,
                isRecurring: isRecurring,
                recurrenceType: recurrenceType.rawValue,
                recurrenceInterval: recurrenceInterval,
                nextDueDate: paymentDate,
                dayOfMonth: recurrenceType == .monthly ? dayOfMonth : nil,
                selectedWeekdays: recurrenceType == .weekly ? weekdaysStr : nil,
                yearlyMonth: recurrenceType == .yearly ? yearlyMonth : nil,
                yearlyDay: recurrenceType == .yearly ? yearlyDay : nil,
                endDate: isRecurring ? endDate : nil,
                paymentCategory: paymentCategory.rawValue,
                notifyOnDueDate: notifyOnDueDate,
                notifyDaysBefore: notifyDaysBefore,
                isActive: isActive,
                isVariableAmount: isVariableAmount
            )
            context.insert(newPayment)

            // Group shared expense (F3)
            newPayment.groupZoneID = groupZoneID
            newPayment.splitTotalAmount = splitTotalAmount
            newPayment.splitType = splitType
            newPayment.setSplitConfig(participantIDs: splitParticipantIDs, values: splitValues)

            paymentID = newPayment.id
        }

        do {
            try context.save()
            WidgetDataCache.updateCache(context: context)
            SessionState.shared.incrementDataVersion()
            ScheduledPaymentNotificationService.shared.requestSummaryReplan()

            return paymentID
        } catch {
            #if DEBUG
            print("ScheduledPaymentEditorViewModel: Error saving payment: \(error)")
            #endif
            showSaveError = true
            return nil
        }
    }

    // MARK: - Delete Operation

    func deletePayment(_ payment: ScheduledPayment) -> Bool {
        guard let context = modelContext, let service = deletionService else { return false }

        service.setContext(context)
        do {
            try service.deleteScheduledPayment(payment)
            WidgetDataCache.updateCache(context: context)
            SessionState.shared.incrementDataVersion()
            return true
        } catch {
            #if DEBUG
            print("ScheduledPaymentEditorViewModel: Error deleting payment: \(error)")
            #endif
            showSaveError = true
            return false
        }
    }

    func dismissSaveError() {
        showSaveError = false
    }
}
