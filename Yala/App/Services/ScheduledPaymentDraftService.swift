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
        let today = calendar.startOfDay(for: Date.now)
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
        var hasChanges = false

        for payment in duePayments {
            // Skip if this date has been pre-skipped by user
            if payment.isDateSkipped(payment.nextDueDate) {
                advanceToNextDueDate(payment: payment)
                hasChanges = true
                continue
            }

            // Safety: skip if already paid for this date (prevents duplicates from sync/reactivation)
            if let lastPaid = payment.lastPaidDate,
               calendar.isDate(lastPaid, inSameDayAs: payment.nextDueDate) {
                advanceToNextDueDate(payment: payment)
                hasChanges = true
                continue
            }

            // Check if draft already exists for this payment (pending or approved)
            if hasExistingDraft(for: payment, on: payment.nextDueDate, context: context) {
                continue
            }

            // Check if a transaction already exists linked to this payment for this date
            if hasLinkedTransaction(for: payment, on: payment.nextDueDate, context: context) {
                advanceToNextDueDate(payment: payment)
                hasChanges = true
                continue
            }

            // Create draft
            let draft = createDraft(from: payment)
            context.insert(draft)
            draftsCreated += 1
            hasChanges = true
        }

        // Save changes (includes advances from skipped/paid dates, not just new drafts)
        if hasChanges {
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

    /// Check if a pending or approved draft already exists for this payment on the given date
    private static func hasExistingDraft(for payment: ScheduledPayment, on date: Date, context: ModelContext) -> Bool {
        let paymentID = payment.id.uuidString
        let calendar = Calendar.current

        let predicate = #Predicate<InboxDraft> { draft in
            draft.sourceScheduledPaymentID == paymentID &&
            (draft.statusRaw == "pending" || draft.statusRaw == "approved")
        }

        let descriptor = FetchDescriptor<InboxDraft>(predicate: predicate)

        do {
            let drafts = try context.fetch(descriptor)
            return drafts.contains { draft in
                guard let draftDate = draft.date else { return false }
                return calendar.isDate(draftDate, inSameDayAs: date)
            }
        } catch {
            #if DEBUG
            print("ScheduledPaymentDraftService: Error checking for existing draft: \(error)")
            #endif
            return false
        }
    }

    /// Check if a transaction already exists linked to this payment on the given date
    private static func hasLinkedTransaction(for payment: ScheduledPayment, on date: Date, context: ModelContext) -> Bool {
        let paymentIDString = payment.id.uuidString
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return false }

        let predicate = #Predicate<TransactionItem> { tx in
            tx.scheduledPaymentID == paymentIDString &&
            tx.date >= startOfDay &&
            tx.date < endOfDay
        }

        var descriptor = FetchDescriptor<TransactionItem>(predicate: predicate)
        descriptor.fetchLimit = 1
        do {
            let transactions = try context.fetch(descriptor)
            return !transactions.isEmpty
        } catch {
            #if DEBUG
            print("ScheduledPaymentDraftService: Error checking for linked transaction: \(error)")
            #endif
            return false
        }
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
            tags: payment.tags ?? [],
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

    // MARK: - Draft Recreation (Unskip)

    /// Recreate a draft when user unskips a date that is today or in the past.
    /// Only creates if no pending/approved draft already exists for this payment in that month.
    static func recreateDraftIfNeeded(for payment: ScheduledPayment, date: Date, context: ModelContext) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date.now)
        let targetDate = calendar.startOfDay(for: date)

        // Only recreate for dates that are today or past
        guard targetDate <= today else { return }

        // Don't duplicate if pending/approved draft exists for this date
        guard !hasExistingDraft(for: payment, on: date, context: context) else { return }

        // Check no approved draft exists for this payment in the same month
        let paymentID = payment.id.uuidString
        guard let monthInterval = calendar.dateInterval(of: .month, for: date) else { return }
        let monthStart = monthInterval.start
        let monthEnd = monthInterval.end

        do {
            let predicate = #Predicate<InboxDraft> { draft in
                draft.sourceScheduledPaymentID == paymentID &&
                (draft.statusRaw == "approved" || draft.statusRaw == "pending")
            }
            let descriptor = FetchDescriptor<InboxDraft>(predicate: predicate)
            let existingDrafts = try context.fetch(descriptor)

            // Check if any existing draft falls within the same month
            for draft in existingDrafts {
                let draftDate = draft.date ?? draft.createdAt
                if draftDate >= monthStart && draftDate < monthEnd {
                    return // Already has a draft for this month
                }
            }
        } catch {
            #if DEBUG
            print("ScheduledPaymentDraftService: Error checking existing drafts for unskip: \(error)")
            #endif
            return
        }

        // Create draft with the specific unskipped date (not payment.nextDueDate)
        let draft = createDraft(from: payment)
        draft.date = targetDate
        context.insert(draft)
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
        guard let paymentIDString = draft.sourceScheduledPaymentID,
              let paymentUUID = UUID(uuidString: paymentIDString) else { return }

        // Fetch the specific scheduled payment by ID
        let predicate = #Predicate<ScheduledPayment> { payment in
            payment.id == paymentUUID
        }
        var descriptor = FetchDescriptor<ScheduledPayment>(predicate: predicate)
        descriptor.fetchLimit = 1

        let payment: ScheduledPayment
        do {
            guard let found = try context.fetch(descriptor).first else { return }
            payment = found
        } catch {
            #if DEBUG
            print("ScheduledPaymentDraftService: Error fetching payment for approval: \(error)")
            #endif
            return
        }

        // Update paid date (use draft's date for retroactive approvals)
        payment.lastPaidDate = draft.date ?? Date.now

        // Link approved transaction to this scheduled payment
        draft.approvedTransaction?.scheduledPaymentID = payment.id.uuidString

        // Advance to next due date
        advanceToNextDueDate(payment: payment)
    }
}
