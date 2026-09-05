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
        // Gate de quiescencia: crea InboxDrafts + `save()` del store personal; diferir durante el
        // import del restore de iCloud (idempotente: re-evalúa los vencimientos en el próximo arranque).
        guard iCloudSyncService.shared.isImportQuiescent else {
            SaveBreadcrumb.deferred("ScheduledPaymentDraftService.processDuePayments", "import not quiescent")
            return 0
        }
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

            // Safety: skip if already paid for this date or later (prevents duplicates from stale nextDueDate)
            if let lastPaid = payment.lastPaidDate,
               calendar.startOfDay(for: lastPaid) >= calendar.startOfDay(for: payment.nextDueDate) {
                advanceToNextDueDate(payment: payment)
                hasChanges = true
                continue
            }

            // Gasto de grupo: validar estado del grupo/membresía antes de materializar el draft.
            // No pausar por una race de sync (grupo aún no importado) — reintentar next launch.
            if payment.isGroupPayment {
                switch groupGateDecision(for: payment, context: context) {
                case .proceed:
                    break
                case .retryLater:
                    continue
                case .pause:
                    payment.isActive = false
                    hasChanges = true
                    continue
                }
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
            let draft = createDraft(from: payment, context: context)
            context.insert(draft)
            draftsCreated += 1
            hasChanges = true
        }

        // Save changes (includes advances from skipped/paid dates, not just new drafts)
        if hasChanges {
            do {
                SaveBreadcrumb.willSave("ScheduledPaymentDraftService.processDuePayments")
                try context.save()
                SaveBreadcrumb.didSave("ScheduledPaymentDraftService.processDuePayments")
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
            // Un draft PENDING (cualquier fecha) ya cubre la próxima ocurrencia — no crear otro.
            // Cubre el draft adelantado (fechado hoy, no en nextDueDate) que de otro modo dejaría
            // que processDuePayments creara un segundo draft al llegar la fecha → doble cobro.
            if drafts.contains(where: { $0.statusRaw == "pending" }) { return true }
            // Los APPROVED se filtran por fecha: uno viejo no debe bloquear una ocurrencia nueva.
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

    /// Check if a transaction already exists linked to this payment within ±1 day of the given date.
    /// The wider window covers timezone offsets or date adjustments during draft approval.
    private static func hasLinkedTransaction(for payment: ScheduledPayment, on date: Date, context: ModelContext) -> Bool {
        let paymentIDString = payment.id.uuidString
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let windowStart = calendar.date(byAdding: .day, value: -1, to: startOfDay),
              let windowEnd = calendar.date(byAdding: .day, value: 2, to: startOfDay) else { return false }

        let predicate = #Predicate<TransactionItem> { tx in
            tx.scheduledPaymentID == paymentIDString &&
            tx.date >= windowStart &&
            tx.date < windowEnd
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

    /// Evalúa el estado del grupo/membresía de un pago planificado de grupo (fetch concreto + do/catch).
    /// La decisión (proceder / reintentar / pausar) es pure-logic en `GroupScheduledPaymentGate`.
    private static func groupGateDecision(for payment: ScheduledPayment, context: ModelContext) -> GroupScheduledPaymentGate.Decision {
        guard let zone = payment.groupZoneID else { return .proceed }

        let group: SplitGroup?
        do {
            var d = FetchDescriptor<SplitGroup>(predicate: #Predicate { $0.cloudKitZoneID == zone })
            d.fetchLimit = 1
            group = try context.fetch(d).first
        } catch {
            #if DEBUG
            print("ScheduledPaymentDraftService: Error fetching group for gate: \(error)")
            #endif
            return .retryLater
        }

        let member: SplitMember?
        do {
            // Identidad RESUELTA: con el flag pelado, al recién llegado el gate lo trataba como
            // no-miembro y el borrador del pago programado del grupo no se creaba nunca.
            let resolved = try GroupExpenseService.resolveCurrentUserMember(inZone: zone, context: context)
            // Un `pendingApproval` se pasa como AUSENTE a propósito. El gate solo distingue «existe» de
            // «está activo», y su rama de no-activo es `.pause`, que escribe `payment.isActive = false`:
            // apagar el pago recurrente de alguien a quien el admin todavía no ha contestado, y que nadie
            // vuelve a encender cuando lo aprueban. El comentario del propio gate dice qué quiere pausar
            // —«removido/salido»— y un pendiente no es ninguno de los dos: es el mismo «todavía no se
            // sabe» que `.retryLater` ya cubre.
            //
            // Sin esto, resolver la identidad EMPEORABA justo al usuario que vino a arreglar: antes su
            // member no se resolvía y el gate reintentaba; ahora se resuelve y le apagaría el pago.
            member = (resolved?.isPendingApproval == true) ? nil : resolved
        } catch {
            #if DEBUG
            print("ScheduledPaymentDraftService: Error fetching member for gate: \(error)")
            #endif
            return .retryLater
        }

        return GroupScheduledPaymentGate.decide(
            groupExists: group != nil,
            isArchived: group?.isArchived ?? false,
            isHidden: group?.isHiddenForAll ?? false,
            memberExists: member != nil,
            memberIsActive: member?.isActive ?? false
        )
    }

    /// Create an InboxDraft from a ScheduledPayment
    private static func createDraft(from payment: ScheduledPayment, context: ModelContext) -> InboxDraft {
        // Determine source type: gasto de grupo recurrente > suscripción > recurrente normal.
        let sourceType: DraftSourceType
        if payment.isGroupPayment {
            sourceType = .groupScheduledExpense
        } else if payment.paymentCategory == PaymentCategory.subscription.rawValue {
            sourceType = .subscription
        } else {
            sourceType = .scheduledPayment
        }

        // Amount with sign (negative for expenses, positive for income)
        let signedAmount: Double
        if payment.transactionType == TransactionType.income.rawValue {
            signedAmount = abs(payment.amount)
        } else {
            signedAmount = -abs(payment.amount)
        }

        // CSV-mirror SSOT: resolver + TagResolver para evitar lazy hydration race.
        let draftTags = TagResolver.fetchOrEmpty(
            ids: payment.resolvedTagIDs(scheduleBackfill: true) ?? [],
            in: context,
            errorContext: "ScheduledPaymentDraftService/createDraft"
        )
        let draft = InboxDraft(
            note: payment.name,
            amount: signedAmount,
            date: payment.nextDueDate,
            account: payment.account,
            subcategory: payment.subcategory,
            tags: draftTags,
            sourceType: sourceType,
            rawText: nil,
            evidence: payment.note,
            confidenceAmount: 1.0,
            confidenceDate: 1.0,
            confidenceMerchant: 1.0,
            confidenceSubcategory: payment.subcategory != nil ? 1.0 : nil,
            needsUserInput: payment.isGroupPayment
                ? []
                : (payment.subcategory == nil ? [DraftInputRequirement.subcategory] : []),
            status: .pending
        )

        // Link to the source payment
        draft.sourceScheduledPaymentID = payment.id.uuidString

        // Gasto de grupo recurrente: zona para el routing/fetch rápido en el Inbox.
        // La config de split (participantes/modo/valores) NO se snapshotea aquí — se lee del
        // ScheduledPayment vía sourceScheduledPaymentID al abrir el form de grupo (SSOT).
        if payment.isGroupPayment {
            draft.splitGroupZoneID = payment.groupZoneID
        }

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
        let draft = createDraft(from: payment, context: context)
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

    // MARK: - Advance Payment (create draft early)

    /// Create a draft for the next occurrence with today's date (advance payment).
    /// Returns the created draft, or nil if a pending draft already exists.
    @discardableResult
    static func createAdvancedDraft(from payment: ScheduledPayment, context: ModelContext) -> InboxDraft? {
        // Guard: don't create if a pending draft already exists for this payment
        let paymentID = payment.id.uuidString
        do {
            let predicate = #Predicate<InboxDraft> { draft in
                draft.sourceScheduledPaymentID == paymentID &&
                draft.statusRaw == "pending"
            }
            var descriptor = FetchDescriptor<InboxDraft>(predicate: predicate)
            descriptor.fetchLimit = 1
            let existing = try context.fetch(descriptor)
            if !existing.isEmpty { return nil }
        } catch {
            #if DEBUG
            print("ScheduledPaymentDraftService: Error checking existing drafts for advance: \(error)")
            #endif
            return nil
        }

        // Create draft with today's date
        let draft = createDraft(from: payment, context: context)
        draft.date = Calendar.current.startOfDay(for: Date.now)
        context.insert(draft)

        // Do NOT advance nextDueDate / set lastPaidDate here: same contract as
        // processDuePayments. The advance happens exactly once when the draft is
        // approved (handleDraftApproved). Advancing here too would double-advance
        // and skip an occurrence for an early-paid payment.
        return draft
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

        // Re-plan de las summaries agendadas (la aprobación cambia el conteo de hoy y
        // la próxima ocurrencia).
        ScheduledPaymentNotificationService.shared.requestSummaryReplan()
    }

    /// Cierra el ciclo tras crear el SplitExpense desde un draft `.groupScheduledExpense`
    /// (F4): marca el pago pagado, avanza la fecha, vincula `scheduledPaymentID` en la TX real
    /// bridgeada (dedup cross-device D1) y borra el draft. Llamado desde el `onExpenseCreated`
    /// del form. A diferencia de `handleDraftApproved`, el resultado es un SplitExpense (+ TX
    /// bridgeadas), no una `approvedTransaction` en el draft.
    static func handleGroupScheduledExpenseApproved(draft: InboxDraft, expenseID: String, context: ModelContext) {
        if let paymentIDString = draft.sourceScheduledPaymentID,
           let paymentUUID = UUID(uuidString: paymentIDString) {
            var descriptor = FetchDescriptor<ScheduledPayment>(predicate: #Predicate { $0.id == paymentUUID })
            descriptor.fetchLimit = 1
            do {
                if let payment = try context.fetch(descriptor).first {
                    payment.lastPaidDate = draft.date ?? Date.now
                    advanceToNextDueDate(payment: payment)
                }
            } catch {
                #if DEBUG
                print("ScheduledPaymentDraftService: error fetching payment for group approval: \(error)")
                #endif
            }

            // Vincular scheduledPaymentID en la TX real (no sistema) para el dedup cross-device.
            let realDescriptor = FetchDescriptor<TransactionItem>(
                predicate: #Predicate { $0.splitExpenseID == expenseID && $0.account?.isSystemAccount == false }
            )
            do {
                if let realTx = try context.fetch(realDescriptor).first {
                    realTx.scheduledPaymentID = paymentIDString
                }
            } catch {
                #if DEBUG
                print("ScheduledPaymentDraftService: error linking scheduledPaymentID: \(error)")
                #endif
            }
        }

        context.delete(draft)
        do {
            try context.save()
        } catch {
            #if DEBUG
            print("ScheduledPaymentDraftService: error saving after group scheduled approval: \(error)")
            #endif
        }

        // Re-plan de las summaries agendadas (misma razón que handleDraftApproved).
        ScheduledPaymentNotificationService.shared.requestSummaryReplan()
    }
}
