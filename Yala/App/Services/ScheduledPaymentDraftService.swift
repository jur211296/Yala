//
//  ScheduledPaymentDraftService.swift
//  Yala
//
//  Service to create InboxDrafts from due scheduled payments.
//  Phase 10: Refinamiento & Notificaciones
//

import Foundation
import SwiftData

/// Service that checks for due scheduled payments and creates drafts in the inbox
@MainActor
struct ScheduledPaymentDraftService {

    // MARK: - Main Entry Point

    /// Process all due payments and create drafts for them
    /// Returns the number of drafts created
    @discardableResult
    static func processDuePayments(context: ModelContext) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let endOfToday = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: today) ?? today

        // Fetch active payments with nextDueDate <= today
        let predicate = #Predicate<ScheduledPayment> { payment in
            payment.isActive && payment.nextDueDate <= endOfToday
        }

        let descriptor = FetchDescriptor<ScheduledPayment>(predicate: predicate)

        let duePayments: [ScheduledPayment]
        do {
            duePayments = try context.fetch(descriptor)
        } catch {
            #if DEBUG
            print("ScheduledPaymentDraftService: Error fetching due payments: \(error)")
            #endif
            return 0
        }

        var draftsCreated = 0

        for payment in duePayments {
            // Check if draft already exists for this payment
            if hasPendingDraft(for: payment, context: context) {
                continue
            }

            // Create draft
            let draft = createDraft(from: payment)
            context.insert(draft)
            draftsCreated += 1
        }

        // Save changes
        if draftsCreated > 0 {
            do {
                try context.save()
            } catch {
                #if DEBUG
                print("ScheduledPaymentDraftService: Error saving drafts: \(error)")
                #endif
            }
        }

        return draftsCreated
    }

    // MARK: - Draft Creation

    /// Check if a pending draft already exists for this payment
    private static func hasPendingDraft(for payment: ScheduledPayment, context: ModelContext) -> Bool {
        let paymentID = payment.id.uuidString

        let predicate = #Predicate<InboxDraft> { draft in
            draft.sourceScheduledPaymentID == paymentID &&
            draft.statusRaw == "pending"
        }

        let descriptor = FetchDescriptor<InboxDraft>(predicate: predicate)

        let existingDrafts: [InboxDraft]
        do {
            existingDrafts = try context.fetch(descriptor)
        } catch {
            #if DEBUG
            print("ScheduledPaymentDraftService: Error checking for existing draft: \(error)")
            #endif
            return false
        }

        return !existingDrafts.isEmpty
    }

    /// Create an InboxDraft from a ScheduledPayment
    private static func createDraft(from payment: ScheduledPayment) -> InboxDraft {
        // Determine source type based on payment category
        let sourceType: DraftSourceType = payment.paymentCategory == PaymentCategory.subscription.rawValue
            ? .subscription
            : .scheduledPayment

        // Amount with sign (negative for expenses, positive for income)
        let signedAmount: Double
        if payment.transactionType == TransactionType.income.rawValue {
            signedAmount = abs(payment.amount)
        } else {
            signedAmount = -abs(payment.amount)
        }

        let draft = InboxDraft(
            note: payment.name,
            amount: signedAmount,
            date: payment.nextDueDate,
            account: payment.account,
            subcategory: payment.subcategory,
            tags: payment.tags,
            sourceType: sourceType,
            rawText: nil,
            evidence: payment.note,
            confidenceAmount: 1.0,
            confidenceDate: 1.0,
            confidenceMerchant: 1.0,
            confidenceSubcategory: payment.subcategory != nil ? 1.0 : nil,
            needsUserInput: payment.subcategory == nil ? ["subcategory"] : [],
            status: .pending
        )

        // Link to the source payment
        draft.sourceScheduledPaymentID = payment.id.uuidString

        return draft
    }

    // MARK: - Next Due Date Calculation

    /// Advance the payment's nextDueDate to the next occurrence
    static func advanceToNextDueDate(payment: ScheduledPayment) {
        guard payment.isRecurring else {
            // One-time payment: deactivate instead of advancing
            payment.isActive = false
            return
        }

        let calendar = Calendar.current
        guard let recurrenceType = RecurrenceType(rawValue: payment.recurrenceType) else {
            return
        }

        let interval = payment.recurrenceInterval

        switch recurrenceType {
        case .daily:
            if let nextDate = calendar.date(byAdding: .day, value: interval, to: payment.nextDueDate) {
                payment.nextDueDate = nextDate
            }

        case .weekly:
            // For weekly, advance by interval weeks
            if let nextDate = calendar.date(byAdding: .weekOfYear, value: interval, to: payment.nextDueDate) {
                payment.nextDueDate = nextDate
            }

        case .monthly:
            // For monthly, keep the same day of month
            if let nextDate = calendar.date(byAdding: .month, value: interval, to: payment.nextDueDate) {
                // Adjust if the day doesn't exist in the target month
                let targetDay = payment.dayOfMonth ?? calendar.component(.day, from: payment.nextDueDate)
                let maxDay = calendar.range(of: .day, in: .month, for: nextDate)?.count ?? 28
                let adjustedDay = min(targetDay, maxDay)

                var components = calendar.dateComponents([.year, .month], from: nextDate)
                components.day = adjustedDay
                if let adjustedDate = calendar.date(from: components) {
                    payment.nextDueDate = adjustedDate
                } else {
                    payment.nextDueDate = nextDate
                }
            }

        case .yearly:
            if let nextDate = calendar.date(byAdding: .year, value: interval, to: payment.nextDueDate) {
                payment.nextDueDate = nextDate
            }
        }

        // Check if we've passed the end date
        if let endDate = payment.endDate, payment.nextDueDate > endDate {
            payment.isActive = false
        }
    }

    // MARK: - Post-Approval Update

    /// Called after a draft from a scheduled payment is approved
    /// Updates lastPaidDate and advances nextDueDate
    static func handleDraftApproved(draft: InboxDraft, context: ModelContext) {
        guard let paymentIDString = draft.sourceScheduledPaymentID else { return }

        // Fetch all scheduled payments and find the one matching our ID
        let descriptor = FetchDescriptor<ScheduledPayment>()

        let payments: [ScheduledPayment]
        do {
            payments = try context.fetch(descriptor)
        } catch {
            #if DEBUG
            print("ScheduledPaymentDraftService: Error fetching payments for approval: \(error)")
            #endif
            return
        }

        // Find payment by matching UUID
        guard let payment = payments.first(where: {
            $0.id.uuidString == paymentIDString
        }) else { return }

        // Update paid date
        payment.lastPaidDate = Date()

        // Advance to next due date
        advanceToNextDueDate(payment: payment)
    }
}
