//
//  InboxPlannedJoin.swift
//  Yala
//
//  Bandeja sin duplicados, lote 4: el cargo que ES un pago planificado completa el borrador del planificado en vez de
//  crear otro pendiente. La regla es pura (`BandejaPlanificadoMatchLogic`); aquí, el cableado con SwiftData:
//
//  - Al llegar (`InboxArrivalJoin.joinBeforeSave`, tras el emparejador entre fuentes): con una coincidencia FUERTE (alias
//    aprendido, importe dentro de tolerancia o estimado, ±5 días) el que llega se absorbe en el borrador pendiente del
//    planificado; si el planificado aún no tenía borrador para esa ocurrencia, se crea («adelantar») y el registro de unión
//    lo apunta para que «Separar» lo borre. Mismo `save()` que el alta: si falla, `revert` lo deshace todo.
//  - En la Bandeja («¿Es tu pago X?», `confirmPlanned`): lo dudoso —la primera vez que un comercio casa con un planificado,
//    o un fijo con otro importe— lo confirma la persona, y así el comercio queda aprendido.
//
//  El borrador del planificado conserva su nota, cuenta y categoría; toma el importe y la fecha del banco. El planificado
//  no se toca: su próxima fecha avanza al aprobar, como siempre (`ScheduledPaymentDraftService.handleDraftApproved`).
//  Fuera: pagos de grupo (decisión 7) y la pausa de «Solo grupos» (los planificados están parados).
//

import Foundation
import SwiftData

/// Los pagos planificados con los que puede casar un cargo, leídos una sola vez por tanda y al día tras cada unión.
@MainActor
struct InboxPlannedTargets {
    struct Target {
        let payment: ScheduledPayment
        /// Su borrador pendiente, si ya lo tiene.
        let draft: InboxDraft?
        let planned: BandejaPlanificadoMatchLogic.Planned
    }

    private let pending: [InboxDraft]
    private let context: ModelContext
    private let calendar: Calendar
    private var loaded: [Target]?
    private var aliases: [UUID: [String]] = [:]

    init(pending: [InboxDraft], context: ModelContext, calendar: Calendar = .current) {
        self.pending = pending
        self.context = context
        self.calendar = calendar
    }

    /// Los planificados de ahora. Se leen la primera vez que hacen falta: una tanda sin nada que case no los lee.
    mutating func all() -> [Target] {
        if let loaded { return loaded }
        let built = build()
        loaded = built
        return built
    }

    /// Vuelve a leer el planificado de `holder` tras una unión: su borrador, sus fuentes ocupadas y lo aprendido.
    mutating func refresh(_ holder: InboxDraft) {
        guard var targets = loaded, let paymentID = holder.sourceScheduledPaymentID,
              let index = targets.firstIndex(where: { $0.payment.id.uuidString == paymentID }) else { return }
        let payment = targets[index].payment
        if let target = Self.target(payment: payment, draft: holder, aliases: aliases[payment.id] ?? [],
                                    calendar: calendar) {
            targets[index] = target
        } else {
            targets.remove(at: index)
        }
        loaded = targets
    }

    private mutating func build() -> [Target] {
        guard !PersonalRemindersPause.isPaused() else { return [] }
        let payments: [ScheduledPayment]
        let recorded: [InboxDraft]
        do {
            payments = try context.fetch(FetchDescriptor<ScheduledPayment>(predicate: #Predicate<ScheduledPayment> {
                $0.isActive
            })).filter { !$0.isGroupPayment }
            guard !payments.isEmpty else { return [] }
            recorded = try context.fetch(FetchDescriptor<InboxDraft>(predicate: #Predicate<InboxDraft> {
                $0.sourceScheduledPaymentID != nil && $0.joinRecordRaw != nil
            }))
        } catch {
            #if DEBUG
            print("InboxPlannedTargets: Error: \(error)")
            #endif
            return []
        }

        // Lo aprendido (Paso 0, D5): el comercio de cada fuente que ya se unió a un borrador de ese planificado, pendiente
        // o aprobado. Lo descartado no enseña nada.
        var learned: [String: [String]] = [:]
        for draft in recorded where draft.status == .pending || draft.status == .approved {
            guard let paymentID = draft.sourceScheduledPaymentID,
                  case .record(let record) = InboxJoinRecord.read(draft.joinRecordRaw), record.holderIsPlanned else {
                continue
            }
            learned[paymentID, default: []] += record.members.map(\.fields.note)
        }

        var pendingByPayment: [String: InboxDraft] = [:]
        for draft in pending where Self.holdsPlannedOccurrence(draft) {
            guard let paymentID = draft.sourceScheduledPaymentID else { continue }
            if let current = pendingByPayment[paymentID],
               (current.date ?? current.createdAt) <= (draft.date ?? draft.createdAt) { continue }
            pendingByPayment[paymentID] = draft
        }

        var targets: [Target] = []
        for payment in payments {
            let key = payment.id.uuidString
            aliases[payment.id] = learned[key] ?? []
            if let target = Self.target(payment: payment, draft: pendingByPayment[key],
                                        aliases: aliases[payment.id] ?? [], calendar: calendar) {
                targets.append(target)
            }
        }
        return targets
    }

    /// Un borrador pendiente que sostiene una ocurrencia de un pago planificado personal.
    static func holdsPlannedOccurrence(_ draft: InboxDraft) -> Bool {
        guard draft.isReadableInInbox, draft.status == .pending, draft.sourceScheduledPaymentID != nil,
              draft.splitGroupZoneID == nil, draft.splitExpenseID == nil else { return false }
        return draft.sourceType == .scheduledPayment || draft.sourceType == .subscription
    }

    /// El importe con signo de un planificado: gasto negativo, ingreso positivo.
    static func signedAmount(of payment: ScheduledPayment) -> Double {
        payment.transactionType == TransactionType.income.rawValue ? abs(payment.amount) : -abs(payment.amount)
    }

    static func target(payment: ScheduledPayment, draft: InboxDraft?, aliases: [String],
                       calendar: Calendar) -> Target? {
        if let draft {
            guard draft.isReadableInInbox, draft.status == .pending else { return nil }
            var occupied: Set<InboxMatchLogic.Source> = []
            var learned = aliases
            var absorbedSomething = false
            switch InboxJoinRecord.read(draft.joinRecordRaw) {
            case .unreadable:
                return nil
            case .record(let record):
                absorbedSomething = !record.members.isEmpty
                occupied = Set(record.members.compactMap { InboxMatchLogic.Source(rawValue: $0.facts.source) })
                learned += record.members.map(\.fields.note)
            case .none:
                break
            }
            return Target(payment: payment, draft: draft, planned: BandejaPlanificadoMatchLogic.Planned(
                paymentID: payment.id, name: payment.name, aliases: learned,
                amount: draft.amount ?? signedAmount(of: payment),
                currencyCode: draft.account?.currencyCode ?? draft.cachedCurrencyCode
                    ?? (payment.currencyCode.isEmpty ? nil : payment.currencyCode),
                isEstimate: payment.isVariableAmount && !absorbedSomething,
                accountID: draft.account?.shortcutID,
                occurrence: draft.date ?? draft.createdAt,
                occupiedSources: occupied))
        }
        // Sin borrador: el próximo vencimiento, si no está saltado ni pagado ya.
        let due = payment.nextDueDate
        guard !payment.isDateSkipped(due) else { return nil }
        if let lastPaid = payment.lastPaidDate, calendar.startOfDay(for: lastPaid) >= calendar.startOfDay(for: due) {
            return nil
        }
        return Target(payment: payment, draft: nil, planned: BandejaPlanificadoMatchLogic.Planned(
            paymentID: payment.id, name: payment.name, aliases: aliases, amount: signedAmount(of: payment),
            currencyCode: payment.currencyCode.isEmpty ? nil : payment.currencyCode,
            isEstimate: payment.isVariableAmount, accountID: payment.account?.shortcutID, occurrence: due))
    }
}

extension InboxArrivalJoin {

    typealias PlannedTargets = InboxPlannedTargets

    /// Si `draft` es el borrador de un pago planificado que ya absorbió algo: entonces entra en el emparejador entre fuentes
    /// (lo que llega después por otra fuente se une a él, Paso 0 D7).
    static func isPlannedHolder(_ draft: InboxDraft, record: InboxJoinRecord) -> Bool {
        record.holderIsPlanned && InboxPlannedTargets.holdsPlannedOccurrence(draft) && draft.amount != nil
    }

    // MARK: - Al llegar

    /// Si lo que llega casa FUERTE con un planificado, lo absorbe en su borrador (creándolo si hace falta) y devuelve ese
    /// borrador; quien llama borra el que llega. Sin guardar.
    static func joinPlannedOnArrival(
        _ arrivingDraft: InboxDraft, facts: InboxJoinRecord.SourceFacts, candidate: InboxMatchLogic.Candidate,
        planned: inout InboxPlannedTargets, context: ModelContext, now: Date, calendar: Calendar,
        outcome: inout Outcome
    ) -> InboxDraft? {
        let targets = planned.all()
        guard !targets.isEmpty else { return nil }
        let arrival = BandejaPlanificadoMatchLogic.Arrival(
            amount: candidate.amount, currencyCode: candidate.currencyCode, date: candidate.date,
            accountID: candidate.accountID, merchants: [candidate.merchant].compactMap { $0 }, sources: [candidate.source])
        guard let match = BandejaPlanificadoMatchLogic.best(for: arrival, among: targets.map(\.planned),
                                                            calendar: calendar),
              match.level == .strong,
              let target = targets.first(where: { $0.planned.paymentID == match.planned.paymentID }) else { return nil }
        guard let holder = absorbIntoPlanned(
            arrivingDraft, members: [member(from: arrivingDraft, facts: facts, joinedAt: now)],
            candidates: [candidate], target: target, context: context, now: now, outcome: &outcome) else { return nil }
        planned.refresh(holder)
        return holder
    }

    /// Une lo que trae `arrivingDraft` en el borrador del planificado de `target`, sin guardar. Si el planificado no tenía
    /// borrador, lo crea para esa ocurrencia y lo apunta en `outcome.created`. `nil` si no se pudo (y no deja nada creado).
    private static func absorbIntoPlanned(
        _ arrivingDraft: InboxDraft, members: [InboxJoinRecord.Member], candidates: [InboxMatchLogic.Candidate],
        target: InboxPlannedTargets.Target, context: ModelContext, now: Date, outcome: inout Outcome
    ) -> InboxDraft? {
        let holder: InboxDraft
        let created: Bool
        if let existing = target.draft {
            holder = existing
            created = false
        } else {
            holder = ScheduledPaymentDraftService.createDraftForOccurrence(
                from: target.payment, date: target.planned.occurrence, context: context)
            created = true
        }
        func giveUp() -> InboxDraft? {
            if created { context.delete(holder) }
            return nil
        }

        var consumption: InboxMatchLogic.Consumption
        switch InboxJoinRecord.read(holder.joinRecordRaw) {
        case .unreadable:
            return giveUp()
        case .record:
            guard let held = self.consumption(of: holder) else { return giveUp() }
            consumption = held
        case .none:
            consumption = InboxMatchLogic.Consumption(InboxMatchLogic.Candidate(
                source: .planned, amount: holder.amount ?? target.planned.amount,
                currencyCode: target.planned.currencyCode, date: holder.date ?? target.planned.occurrence,
                hasExactTime: false, accountID: holder.account?.shortcutID, merchant: holder.note))
        }
        for candidate in candidates {
            guard consumption.absorb(candidate) else { return giveUp() }
        }

        let holderFacts = InboxJoinRecord.SourceFacts(
            source: InboxMatchLogic.Source.planned.rawValue, currencyCode: target.planned.currencyCode, last4: nil,
            hasExactTime: false)
        guard join(arrivingDraft, members: members, into: holder, holderFacts: holderFacts,
                   resolved: consumption.resolved, holderIsArrival: created,
                   plannedRecord: (createdByJoin: created, isEstimate: target.planned.isEstimate), now: now,
                   outcome: &outcome) else { return giveUp() }
        if created { outcome.created.append(holder) }
        return holder
    }

    // MARK: - «Sí, es ese pago» (la Bandeja)

    /// «Sí, es ese pago»: une un pendiente —solo, o con lo que ya tenía unido— en el borrador del planificado, y así su
    /// comercio queda aprendido. Guarda; si falla, no cambia nada. Devuelve si se unió.
    @discardableResult
    static func confirmPlanned(_ arriving: InboxDraft, paymentID: UUID, context: ModelContext,
                               now: Date = .now) -> Bool {
        guard arriving.isReadableInInbox, matchSource(of: arriving) != nil else { return false }
        let pending: [InboxDraft]
        do {
            let raw = DraftStatus.pending.rawValue
            pending = try context.fetch(FetchDescriptor<InboxDraft>(predicate: #Predicate<InboxDraft> { $0.statusRaw == raw }))
        } catch {
            #if DEBUG
            print("InboxArrivalJoin: Error: \(error)")
            #endif
            return false
        }
        var targets = InboxPlannedTargets(pending: pending, context: context)
        guard let target = targets.all().first(where: { $0.planned.paymentID == paymentID }) else { return false }

        var members: [InboxJoinRecord.Member]
        switch InboxJoinRecord.read(arriving.joinRecordRaw) {
        case .unreadable:
            return false
        case .none:
            guard let facts = derivedFacts(of: arriving) else { return false }
            members = [member(from: arriving, facts: facts, joinedAt: now)]
        case .record(let record):
            // El que sostenía vuelve como lo que llegó primero; lo que ya había absorbido viaja tal cual.
            members = [InboxJoinRecord.Member(
                facts: record.holderSource, fields: record.holderBefore, sourceTypeRaw: arriving.sourceTypeRaw,
                createdAt: arriving.createdAt, rawText: arriving.rawText, evidence: arriving.evidence,
                confidenceAmount: arriving.confidenceAmount, confidenceDate: arriving.confidenceDate,
                confidenceMerchant: arriving.confidenceMerchant, confidenceSubcategory: arriving.confidenceSubcategory,
                joinedAt: now)] + record.members
        }
        let candidates = members.compactMap {
            InboxJoinLogic.candidate(id: UUID(), facts: $0.facts, fields: $0.fields, fallbackDate: $0.createdAt)
        }
        guard candidates.count == members.count else { return false }

        var outcome = Outcome()
        guard absorbIntoPlanned(arriving, members: members, candidates: candidates, target: target, context: context,
                                now: now, outcome: &outcome) != nil else { return false }
        do {
            // La fila del que se va se desmonta antes del borrado (crash de iOS 27 al leer un modelo borrado, card f8rj).
            InboxRowPruneCoordinator.shared.pruneRow(arriving.persistentModelID)
            context.delete(arriving)
            SaveBreadcrumb.willSave("InboxArrivalJoin.confirmPlanned")
            try context.save()
            SaveBreadcrumb.didSave("InboxArrivalJoin.confirmPlanned")
            return true
        } catch {
            #if DEBUG
            print("InboxArrivalJoin: Error confirming planned payment: \(error)")
            #endif
            revert(outcome)
            context.rollback()
            return false
        }
    }
}
