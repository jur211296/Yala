//
//  RecurringFromRecordService.swift
//  Yala
//
//  Aplica sobre los datos lo que decide `RecurringFromRecordLogic`: lee el registro para prellenar el editor, busca un
//  recurrente parecido y deja el registro como un pago del recurrente. Nunca crea otra transacción.
//

import Foundation
import SwiftData

@MainActor
enum RecurringFromRecordService {

    // MARK: - Leer el registro

    static func facts(of record: TransactionItem) -> RecurringFromRecordLogic.RecordFacts {
        RecurringFromRecordLogic.RecordFacts(
            isGroupRecord: RecordContextActionLogic.Shape(record: record).isGroupRecord,
            hasBalanceAdjustmentType: record.balanceAdjustmentType != nil,
            isLinkedToScheduledPayment: record.scheduledPaymentID != nil,
            accountIsSystem: record.account?.isSystemAccount ?? false)
    }

    /// Si «Hacer recurrente» se ofrece para este registro. Un registro borrado o sin contexto, no.
    static func offersMakeRecurring(_ record: TransactionItem) -> Bool {
        guard !record.isDeleted, record.modelContext != nil else { return false }
        return RecurringFromRecordLogic.offersMakeRecurring(facts(of: record))
    }

    static func transactionType(of record: TransactionItem) -> TransactionType {
        TransactionClassificationLogic.isIncome(record) ? .income : .expense
    }

    /// El editor de recurrentes prellenado con el registro: monto, moneda, categoría, cuenta, etiquetas, nota y el día
    /// del registro como día de cobro. La frecuencia es la del editor por defecto: mensual.
    static func prefill(from record: TransactionItem) -> ScheduledPaymentPrefill {
        let tagIDs: Set<PersistentIdentifier>
        if let context = record.modelContext {
            let ids = record.resolvedTagIDs(scheduleBackfill: false) ?? []
            tagIDs = Set(TagResolver.fetchOrEmpty(ids: ids, in: context, errorContext: "RecurringFromRecord/prefill")
                .map(\.persistentModelID))
        } else {
            tagIDs = []
        }
        return ScheduledPaymentPrefill(
            transactionType: transactionType(of: record).rawValue,
            amount: AmountInputHelper.formatWithGrouping(abs(record.amount)),
            note: record.note ?? "",
            account: record.account,
            subcategory: record.subcategory,
            tagIDs: tagIDs,
            needOverride: record.needOverride.flatMap { SubcategoryNeed(rawValue: $0) },
            currencyCode: record.currencyCode,
            transactionDate: record.date,
            name: RecurringFromRecordLogic.paymentName(note: record.note, subcategoryName: record.subcategory?.name))
    }

    // MARK: - Un recurrente parecido

    /// El recurrente que ya cubre este registro, si lo hay (`RecurringFromRecordLogic.similarPayment`). Una lectura que
    /// falla no ofrece nada: se crea uno nuevo, como si no hubiera parecido.
    static func similarPayment(for record: TransactionItem, in context: ModelContext) -> ScheduledPayment? {
        let payments: [ScheduledPayment]
        do {
            payments = try context.fetch(FetchDescriptor<ScheduledPayment>(predicate: #Predicate { $0.isActive }))
        } catch {
            #if DEBUG
            print("RecurringFromRecordService: Error fetching scheduled payments: \(error)")
            #endif
            return nil
        }
        let probe = RecurringFromRecordLogic.Probe(
            name: RecurringFromRecordLogic.paymentName(note: record.note, subcategoryName: nil),
            amount: abs(record.amount),
            currencyCode: record.currencyCode,
            transactionType: transactionType(of: record).rawValue,
            subcategoryID: record.subcategory?.shortcutID)
        let candidates = payments.map {
            RecurringFromRecordLogic.Candidate(
                id: $0.id, name: $0.name, storedBrandID: $0.brandLogoID, amount: $0.amount,
                currencyCode: $0.currencyCode, transactionType: $0.transactionType,
                subcategoryID: $0.subcategory?.shortcutID, isVariableAmount: $0.isVariableAmount,
                isActive: $0.isActive, isGroupPayment: $0.isGroupPayment)
        }
        guard let match = RecurringFromRecordLogic.similarPayment(to: probe, among: candidates) else { return nil }
        return payments.first { $0.id == match.id }
    }

    // MARK: - Vincular

    /// Recurrente recién creado desde el registro: el registro es su primer pago, ya pagado. Avanza la próxima fecha
    /// más allá del registro (`firstPaymentAdvances`) y guarda. Devuelve el recurrente, o `nil` si no se encontró o no
    /// se pudo guardar.
    @discardableResult
    static func linkAsFirstPayment(
        _ record: TransactionItem, paymentID: UUID, context: ModelContext, now: Date = .now
    ) -> ScheduledPayment? {
        guard !record.isDeleted, let payment = fetchPayment(paymentID, in: context) else { return nil }
        record.scheduledPaymentID = payment.id.uuidString
        payment.lastPaidDate = max(payment.lastPaidDate ?? record.date, record.date)
        advance(payment) {
            RecurringFromRecordLogic.firstPaymentAdvances(nextDueDate: $0, recordDate: record.date, now: now)
        }
        return save(context) ? payment : nil
    }

    /// Vincula el registro a un recurrente que ya existía («Vincular a «Cloudflare»»). Si cubre el vencimiento que toca
    /// (`linkAdvances`), la próxima fecha avanza y el borrador pendiente de ese mismo vencimiento, si lo hay, pasa a
    /// descartados: sería el mismo gasto dos veces. Devuelve si guardó.
    @discardableResult
    static func link(_ record: TransactionItem, to payment: ScheduledPayment, context: ModelContext) -> Bool {
        guard !record.isDeleted, !payment.isDeleted else { return false }
        let scheduleBefore = payment.occurrenceSchedule
        record.scheduledPaymentID = payment.id.uuidString
        payment.lastPaidDate = max(payment.lastPaidDate ?? record.date, record.date)
        let covered = advance(payment) {
            RecurringFromRecordLogic.linkAdvances(
                nextDueDate: $0, recordDate: record.date, recurrenceType: payment.recurrenceType)
        }
        if !covered.isEmpty {
            retirePendingDrafts(of: payment, heldAt: covered, schedule: scheduleBefore, in: context)
        }
        return save(context)
    }

    // MARK: - Piezas

    /// Avanza la próxima fecha mientras `shouldAdvance` lo pida y el recurrente siga activo (uno de una sola vez se
    /// apaga al avanzar). Devuelve los vencimientos que dejó atrás, al inicio del día.
    @discardableResult
    private static func advance(_ payment: ScheduledPayment, while shouldAdvance: (Date) -> Bool) -> [Date] {
        let calendar = Calendar.current
        var passed: [Date] = []
        var steps = 0
        while payment.isActive, shouldAdvance(payment.nextDueDate), steps < 1_000 {
            let before = payment.nextDueDate
            passed.append(calendar.startOfDay(for: before))
            ScheduledPaymentDraftService.advanceToNextDueDate(payment: payment)
            steps += 1
            guard payment.nextDueDate != before else { break }
        }
        if !passed.isEmpty { ScheduledPaymentNotificationService.shared.requestSummaryReplan() }
        return passed
    }

    /// Los pendientes del recurrente que retenían un vencimiento ya cubierto pasan a descartados (no se borran: la fila
    /// puede estar montada en la Bandeja). Mismo cambio que hace `processDuePayments` con los de una ocurrencia saltada.
    private static func retirePendingDrafts(
        of payment: ScheduledPayment, heldAt covered: [Date],
        schedule: ScheduledDraftOccurrenceLogic.Schedule, in context: ModelContext
    ) {
        let paymentID = payment.id.uuidString
        let drafts: [InboxDraft]
        do {
            drafts = try context.fetch(FetchDescriptor<InboxDraft>(predicate: #Predicate<InboxDraft> {
                $0.sourceScheduledPaymentID == paymentID && $0.statusRaw == "pending"
            }))
        } catch {
            #if DEBUG
            print("RecurringFromRecordService: Error fetching pending drafts: \(error)")
            #endif
            return
        }
        let coveredDays = Set(covered)
        for draft in drafts where !draft.isDeleted && draft.status == .pending
            && ScheduledDraftOccurrenceLogic.holdsAnOccurrence(draft.sourceType) {
            let held = ScheduledDraftOccurrenceLogic.heldOccurrence(
                draftDate: draft.date ?? draft.createdAt, schedule: schedule)
            guard coveredDays.contains(held) else { continue }
            DraftService.cacheArchiveDisplayValues(draft)
            draft.status = .rejected
            draft.updatedAt = Date.now
        }
    }

    private static func fetchPayment(_ id: UUID, in context: ModelContext) -> ScheduledPayment? {
        var descriptor = FetchDescriptor<ScheduledPayment>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        do {
            return try context.fetch(descriptor).first
        } catch {
            #if DEBUG
            print("RecurringFromRecordService: Error fetching scheduled payment: \(error)")
            #endif
            return nil
        }
    }

    private static func save(_ context: ModelContext) -> Bool {
        do {
            try context.save()
            WidgetDataCache.updateCache(context: context)
            SessionState.shared.incrementDataVersion()
            return true
        } catch {
            #if DEBUG
            print("RecurringFromRecordService: Error saving link: \(error)")
            #endif
            return false
        }
    }
}
