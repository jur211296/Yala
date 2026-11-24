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

    // MARK: - Gastos de grupo en «Reusar» (encargo del 21-nov)

    static func groupFacts(of record: TransactionItem) -> RecurringFromRecordLogic.GroupLegFacts {
        let shape = RecordContextActionLogic.Shape(record: record)
        return RecurringFromRecordLogic.GroupLegFacts(
            hasSplitExpenseID: shape.hasSplitExpenseID,
            hasSplitSettlementID: shape.hasSplitSettlementID,
            isSplitLineLeg: shape.isSplitLineLeg,
            hasBalanceAdjustmentType: shape.hasBalanceAdjustmentType,
            isLinkedToScheduledPayment: record.scheduledPaymentID != nil,
            amount: record.amount,
            subcategoryIsBridgeSystem: record.subcategory?.isSystem ?? false)
    }

    /// La fila con el gasto de un grupo, la que «Reusar» ofrece (`RecurringFromRecordLogic.isReusableGroupExpense`).
    static func isReusableGroupExpense(_ record: TransactionItem) -> Bool {
        guard !record.isDeleted, record.modelContext != nil else { return false }
        return RecurringFromRecordLogic.isReusableGroupExpense(groupFacts(of: record))
    }

    /// Lo que lista «Elige un registro»: lo propio que se puede hacer recurrente y el gasto de cada grupo, uno por
    /// gasto (la primera fila que llegue de cada `splitExpenseID`).
    static func reusableRecords(_ records: [TransactionItem]) -> [TransactionItem] {
        var seenExpenses: Set<String> = []
        return records.filter { record in
            if offersMakeRecurring(record) { return true }
            guard isReusableGroupExpense(record), let expenseID = record.splitExpenseID else { return false }
            return seenExpenses.insert(expenseID).inserted
        }
    }

    /// Si se puede reusar el gasto de grupo de cada zona, leído una vez por zona. La clave vacía es la fila sin zona.
    static func groupAvailabilities(
        for records: [TransactionItem], in context: ModelContext
    ) -> [String: RecurringFromRecordLogic.GroupAvailability] {
        var result: [String: RecurringFromRecordLogic.GroupAvailability] = [:]
        for record in records where record.splitExpenseID != nil {
            let zone = record.splitGroupZoneID ?? ""
            guard result[zone] == nil else { continue }
            result[zone] = groupAvailability(zone: zone, in: context)
        }
        return result
    }

    static func groupAvailability(zone: String, in context: ModelContext) -> RecurringFromRecordLogic.GroupAvailability {
        guard !zone.isEmpty else { return .groupGone }
        let group = fetchGroup(zone: zone, in: context)
        let memberActive: Bool
        do {
            memberActive = try GroupExpenseService.resolveCurrentUserMember(inZone: zone, context: context)?.isActive
                ?? false
        } catch {
            #if DEBUG
            print("RecurringFromRecordService: Error resolving current member: \(error)")
            #endif
            memberActive = false
        }
        return RecurringFromRecordLogic.groupAvailability(
            groupExists: group != nil, isHiddenForAll: group?.isHiddenForAll ?? false,
            isArchived: group?.isArchived ?? false, currentMemberIsActive: memberActive)
    }

    /// El pago compartido que repite el gasto del registro: grupo, moneda, total y reparto entre quienes siguen activos.
    /// `nil` si el gasto ya no está en el teléfono o no queda nadie con parte.
    static func groupPrefill(from record: TransactionItem, in context: ModelContext) -> ScheduledPaymentGroupPrefill? {
        guard let rawID = record.splitExpenseID, let expenseID = UUID(uuidString: rawID) else { return nil }
        var descriptor = FetchDescriptor<SplitExpense>(predicate: #Predicate { $0.id == expenseID })
        descriptor.fetchLimit = 1
        do {
            guard let expense = try context.fetch(descriptor).first, !expense.isDeleted else { return nil }
            let zone = expense.groupZoneID
            let shares = try context.fetch(FetchDescriptor<SplitShare>(predicate: #Predicate { $0.expenseID == expenseID }))
            let members = try context.fetch(FetchDescriptor<SplitMember>(
                predicate: #Predicate { $0.groupZoneID == zone }, sortBy: [SortDescriptor(\.joinedAt)]))
            let active = Set(members.filter(\.isActive).map(\.id))
            // En el orden del grupo (quien entró antes, primero): el del selector de división.
            let position = Dictionary(members.enumerated().map { ($1.id, $0) }, uniquingKeysWith: { first, _ in first })
            let pairs = shares
                .compactMap { share in UUID(uuidString: share.memberID).map { (memberID: $0, amount: share.amount) } }
                .sorted { (position[$0.memberID] ?? Int.max) < (position[$1.memberID] ?? Int.max) }
            guard let split = RecurringFromRecordLogic.groupSplit(
                splitType: expense.splitType, total: expense.amount, shares: pairs, activeMemberIDs: active)
            else { return nil }
            return ScheduledPaymentGroupPrefill(
                groupZoneID: zone, currencyCode: expense.currencyCode, totalAmount: expense.amount,
                splitType: split.splitType, participantIDs: split.participantIDs, values: split.values)
        } catch {
            #if DEBUG
            print("RecurringFromRecordService: Error reading the group expense: \(error)")
            #endif
            return nil
        }
    }

    private static func fetchGroup(zone: String, in context: ModelContext) -> SplitGroup? {
        var descriptor = FetchDescriptor<SplitGroup>(predicate: #Predicate { $0.cloudKitZoneID == zone })
        descriptor.fetchLimit = 1
        do {
            return try context.fetch(descriptor).first
        } catch {
            #if DEBUG
            print("RecurringFromRecordService: Error fetching group: \(error)")
            #endif
            return nil
        }
    }

    static func transactionType(of record: TransactionItem) -> TransactionType {
        TransactionClassificationLogic.isIncome(record) ? .income : .expense
    }

    /// El editor de recurrentes prellenado con el registro: monto, moneda, categoría, cuenta, etiquetas, nota y el día
    /// del registro como día de cobro. La frecuencia es la del editor por defecto: mensual. De un gasto de grupo, además,
    /// el grupo y su reparto (`groupPrefill`): el monto pasa a ser el total, sin etiquetas (un pago compartido no las
    /// lleva) y sin la cuenta de sistema «Grupos», que no se puede elegir.
    static func prefill(from record: TransactionItem) -> ScheduledPaymentPrefill {
        let base = personalPrefill(from: record)
        guard isReusableGroupExpense(record), let context = record.modelContext,
              let group = groupPrefill(from: record, in: context) else { return base }
        let account = selectableAccount(of: record)
        var shared = ScheduledPaymentPrefill(
            transactionType: TransactionType.expense.rawValue,
            amount: AmountInputHelper.formatWithGrouping(group.totalAmount),
            note: base.note,
            account: account,
            subcategory: base.subcategory,
            tagIDs: [],
            needOverride: base.needOverride,
            currencyCode: group.currencyCode,
            transactionDate: base.transactionDate,
            name: base.name)
        shared.group = group
        return shared
    }

    /// La cuenta del registro, si el formulario la puede ofrecer: ni archivada ni la de sistema «Grupos». Un recurrente en
    /// una cuenta archivada dejaría sus borradores en ella (21-nov): sin cuenta, el formulario pide elegir una.
    private static func selectableAccount(of record: TransactionItem) -> Account? {
        guard let account = record.account, !account.isArchived, !account.isSystemAccount else { return nil }
        return account
    }

    private static func personalPrefill(from record: TransactionItem) -> ScheduledPaymentPrefill {
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
            account: selectableAccount(of: record),
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

    // MARK: - Desde el formulario de registro (hoja «Hacer recurrente», 23-nov)

    /// Lo que Nuevo registro (o Editar) tiene del registro al tocar «Hacer recurrente». De aquí salen las dos salidas de
    /// la hoja —una frecuencia rápida y «Más opciones…»—, así que las dos copian lo mismo (pedido de Jürgen del 23-nov).
    struct FormRecord {
        let transactionType: TransactionType
        /// Magnitud, sin signo: el formulario la guarda así.
        let amount: Double
        /// La divisa del importe, la que enseña la pantalla, sin convertir (card 4k2q).
        let currencyCode: String
        let note: String
        let account: Account?
        let subcategory: Subcategory?
        let tags: [Tag]
        /// La necesidad elegida en el formulario; `nil` = la de la subcategoría.
        let need: SubcategoryNeed?
        let date: Date

        /// El nombre del pago: la descripción y, sin ella, la subcategoría (`RecurringFromRecordLogic.paymentName`).
        var paymentName: String {
            RecurringFromRecordLogic.paymentName(note: note, subcategoryName: subcategory?.name)
        }

        /// La necesidad que se guarda en el pago: solo si no es la que ya trae la subcategoría.
        var needOverrideToStore: String? {
            need.flatMap { $0 != subcategory?.need ? $0.rawValue : nil }
        }
    }

    /// «Más opciones…»: el editor completo, con todo lo del registro ya puesto. El nombre es el mismo que el de la opción
    /// rápida; sin descripción ni subcategoría queda vacío y el editor lo pide.
    static func moreOptionsPrefill(from form: FormRecord) -> ScheduledPaymentPrefill {
        ScheduledPaymentPrefill(
            transactionType: form.transactionType.rawValue,
            amount: AmountInputHelper.formatWithGrouping(form.amount),
            note: form.note,
            account: form.account,
            subcategory: form.subcategory,
            tagIDs: Set(form.tags.map(\.persistentModelID)),
            needOverride: form.need,
            currencyCode: form.currencyCode,
            transactionDate: form.date,
            name: form.paymentName)
    }

    /// Una frecuencia de la hoja: crea el pago con todo lo del registro y el ancla de su fecha (el día de la semana, el
    /// del mes o el día y el mes). Sin nombre posible, el del tipo («Gasto»). `nil` sin cuenta o si no se pudo guardar.
    static func createQuickPayment(
        from form: FormRecord,
        recurrence: RecurrenceType,
        context: ModelContext,
        deletionService: EntityDeletionService
    ) -> UUID? {
        guard let account = form.account else { return nil }
        let anchor = RecurringQuickChoiceLogic.anchor(for: form.date)
        let name = form.paymentName.isEmpty ? form.transactionType.displayName : form.paymentName
        let editor = ScheduledPaymentEditorViewModel()
        editor.setContext(context, deletionService: deletionService)
        return editor.savePayment(
            existing: nil,
            name: name,
            amount: form.amount,
            note: form.note,
            currencyCode: form.currencyCode,
            transactionType: form.transactionType.rawValue,
            paymentCategory: .recurring,
            account: account,
            subcategory: form.subcategory,
            selectedTags: Set(form.tags.map(\.persistentModelID)),
            isRecurring: true,
            recurrenceType: recurrence,
            recurrenceInterval: 1,
            paymentDate: Calendar.current.startOfDay(for: form.date),
            dayOfMonth: anchor.dayOfMonth,
            selectedWeekdays: [anchor.weekday],
            yearlyMonth: anchor.month,
            yearlyDay: anchor.dayOfMonth,
            endDate: nil,
            notifyOnDueDate: true,
            notifyDaysBefore: 0,
            isActive: true,
            needOverride: form.needOverrideToStore
        )
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
