//
//  InboxArrivalJoin.swift
//  Yala
//
//  Bandeja sin duplicados, lote 2: el punto común que une al llegar. Lo llaman las fuentes que avisan de un cargo —Apple
//  Pay (`ApplePayDraftService`), el aviso del banco (`BankNoticeDraftService`), y el correo del banco, Yala web y tu IA
//  (`BankEmailDraftService.materialize`)— con los borradores que acaban de insertar, ANTES de su guardado.
//
//  Qué hace: cada borrador que llega se compara con los pendientes (`InboxMatchLogic.decide`). Solo con una coincidencia
//  FUERTE se une: el pendiente que sostiene el consumo toma lo que manda (importe del banco, hora exacta, comercio limpio)
//  y apunta lo que trajo el que llega en su `joinRecordRaw`; el que llega se borra sin haberse guardado nunca, así que no
//  viaja a ningún sitio. Lo dudoso y lo ya registrado quedan como hoy, cada uno su pendiente (preguntarlo es el lote 3).
//
//  Por qué antes del guardado (Paso 0, D3): la unión y el alta van en el mismo `save()`. Si falla, quien llama deshace sus
//  altas y `revert` deshace lo que la unión cambió en los pendientes; no hay que deshacer un borrado ya sincronizado.
//
//  Lo que no entra: grupos y cuentas compartidas (decisión 7 de Jürgen; su `Source` es `nil`), lo que la persona dicta o
//  fotografía, los planificados (lote 4), un borrador sin importe y un registro de unión que no se entiende (Paso 0, D8).
//  Si la lectura de los pendientes falla, no se une nada: todo entra como hoy.
//

import Foundation
import SwiftData

@MainActor
enum InboxArrivalJoin {

    /// Un borrador recién insertado y lo que su fuente dijo y el borrador no guarda.
    struct Arrival {
        let draft: InboxDraft
        /// ISO 4217 que dijo la fuente, o `nil` si no lo dijo (un `$` suelto).
        let currencyCode: String?
        /// Lo que la fuente dijo de la tarjeta («****4321», el nombre de la tarjeta de Wallet). Se queda con los últimos 4.
        let last4: String?

        init(draft: InboxDraft, currencyCode: String?, last4: String? = nil) {
            self.draft = draft
            self.currencyCode = currencyCode
            self.last4 = last4
        }
    }

    /// Lo que hizo una pasada: lo que se unió (ya borrado) y cómo deshacer lo que cambió en los pendientes.
    struct Outcome {
        var absorbed: [InboxDraft] = []
        var undo: [HolderUndo] = []
        /// Borradores de pagos planificados que la unión creó para casar un cargo (lote 4): si el guardado falla, se van.
        var created: [InboxDraft] = []

        var joinedCount: Int { absorbed.count }

        func isAbsorbed(_ draft: InboxDraft) -> Bool {
            absorbed.contains { $0 === draft }
        }
    }

    struct HolderUndo {
        let draft: InboxDraft
        let note: String
        let amount: Double?
        let date: Date?
        let account: Account?
        let subcategory: Subcategory?
        let confidenceSubcategory: Double?
        let cachedCurrencyCode: String?
        let needsUserInput: [String]
        let joinRecordRaw: String?
        let updatedAt: Date
    }

    // MARK: - Unir al llegar

    /// Une los que llegan con los pendientes, sin guardar. Devuelve lo que hizo para que quien llama quite de sus altas lo
    /// absorbido y, si su guardado falla, llame a `revert`.
    static func joinBeforeSave(_ arrivals: [Arrival], context: ModelContext, now: Date = .now,
                               calendar: Calendar = .current) -> Outcome {
        var outcome = Outcome()
        let arriving = arrivals.filter { facts(for: $0) != nil }
        guard !arriving.isEmpty else { return outcome }

        let pending: [InboxDraft]
        do {
            let raw = DraftStatus.pending.rawValue
            pending = try context.fetch(FetchDescriptor<InboxDraft>(predicate: #Predicate<InboxDraft> { $0.statusRaw == raw }))
        } catch {
            #if DEBUG
            print("InboxArrivalJoin: Error: \(error)")
            #endif
            return outcome
        }

        let arrivalSet = Set(arrivals.map { ObjectIdentifier($0.draft) })
        var arrivalFactsByDraft: [ObjectIdentifier: InboxJoinRecord.SourceFacts] = [:]
        var consumptions: [InboxMatchLogic.Consumption] = []
        var holderByID: [UUID: InboxDraft] = [:]
        for draft in pending where !arrivalSet.contains(ObjectIdentifier(draft)) && !draft.isDeleted {
            guard let consumption = consumption(of: draft) else { continue }
            consumptions.append(consumption)
            holderByID[consumption.id] = draft
        }

        var planned = PlannedTargets(pending: pending, context: context, calendar: calendar)
        for arrival in arriving {
            guard let arrivalFacts = facts(for: arrival),
                  let candidate = InboxJoinLogic.candidate(
                    id: UUID(), facts: arrivalFacts, fields: fields(of: arrival.draft),
                    fallbackDate: arrival.draft.createdAt) else { continue }
            arrivalFactsByDraft[ObjectIdentifier(arrival.draft)] = arrivalFacts
            let decision = InboxMatchLogic.decide(candidate, pending: consumptions, calendar: calendar)
            if case .join(let consumptionID) = decision,
               let index = consumptions.firstIndex(where: { $0.id == consumptionID }),
               let holder = holderByID[consumptionID] {
                var joined = consumptions[index]
                let holderKey = ObjectIdentifier(holder)
                if joined.absorb(candidate),
                   join(arrival.draft, members: [member(from: arrival.draft, facts: arrivalFacts, joinedAt: now)],
                        into: holder, holderFacts: arrivalFactsByDraft[holderKey] ?? derivedFacts(of: holder),
                        resolved: joined.resolved, holderIsArrival: arrivalSet.contains(holderKey), now: now,
                        outcome: &outcome) {
                    consumptions[index] = joined
                    context.delete(arrival.draft)
                    outcome.absorbed.append(arrival.draft)
                    planned.refresh(holder)
                    continue
                }
            }
            // Lote 4: lo que no se unió a otra fuente y ES un pago planificado completa su borrador (o lo adelanta).
            if let holder = joinPlannedOnArrival(
                arrival.draft, facts: arrivalFacts, candidate: candidate, planned: &planned, context: context,
                now: now, calendar: calendar, outcome: &outcome) {
                context.delete(arrival.draft)
                outcome.absorbed.append(arrival.draft)
                if let joined = consumption(of: holder) {
                    consumptions.removeAll { holderByID[$0.id] === holder }
                    consumptions.append(joined)
                    holderByID[joined.id] = holder
                }
                continue
            }
            // No se unió: queda como pendiente propio, y lo que llega después en la misma tanda puede unirse a él.
            let own = InboxMatchLogic.Consumption(candidate)
            consumptions.append(own)
            holderByID[own.id] = arrival.draft
        }
        return outcome
    }

    /// Deshace lo que la unión cambió en los pendientes que ya existían. Lo absorbido nunca llegó a guardarse: quien llama
    /// deshace sus propias altas.
    static func revert(_ outcome: Outcome) {
        for draft in outcome.created where !draft.isDeleted {
            draft.modelContext?.delete(draft)
        }
        for entry in outcome.undo.reversed() {
            let draft = entry.draft
            // Un borrador de planificado que la unión creó y ya se borró arriba no se toca: escribir en él aborta.
            guard !draft.isDeleted else { continue }
            draft.note = entry.note
            draft.amount = entry.amount
            draft.date = entry.date
            draft.account = entry.account
            draft.subcategory = entry.subcategory
            draft.confidenceSubcategory = entry.confidenceSubcategory
            draft.cachedCurrencyCode = entry.cachedCurrencyCode
            draft.needsUserInput = entry.needsUserInput
            draft.joinRecordRaw = entry.joinRecordRaw
            draft.updatedAt = entry.updatedAt
        }
    }

    /// Une `newMembers` (lo que trae `arrivingDraft`: él solo, o él con lo que ya tenía unido) en `holder`, sin guardar.
    /// `plannedRecord` solo cuando `holder` es el borrador de un planificado sin registro todavía (lote 4).
    static func join(
        _ arrivingDraft: InboxDraft, members newMembers: [InboxJoinRecord.Member], into holder: InboxDraft,
        holderFacts: InboxJoinRecord.SourceFacts?, resolved: InboxMatchLogic.Resolved, holderIsArrival: Bool,
        plannedRecord: (createdByJoin: Bool, isEstimate: Bool)? = nil, now: Date, outcome: inout Outcome
    ) -> Bool {
        let current = fields(of: holder)
        var record: InboxJoinRecord
        switch InboxJoinRecord.read(holder.joinRecordRaw) {
        case .unreadable:
            return false
        case .record(let existing):
            record = existing
        case .none:
            guard let holderFacts else { return false }
            record = InboxJoinRecord(version: InboxJoinRecord.currentVersion, holderSource: holderFacts,
                                     holderBefore: current, holderAfter: current, members: [],
                                     holderCreatedByJoin: plannedRecord.map(\.createdByJoin),
                                     holderIsEstimate: plannedRecord.map(\.isEstimate))
        }

        let merged = InboxJoinLogic.mergedFields(holder: current, arriving: fields(of: arrivingDraft), resolved: resolved)
        record.members.append(contentsOf: newMembers)
        record.holderAfter = merged
        guard let raw = record.encoded() else { return false }

        if !holderIsArrival {
            outcome.undo.append(HolderUndo(
                draft: holder, note: holder.note, amount: holder.amount, date: holder.date, account: holder.account,
                subcategory: holder.subcategory, confidenceSubcategory: holder.confidenceSubcategory,
                cachedCurrencyCode: holder.cachedCurrencyCode,
                needsUserInput: holder.needsUserInput, joinRecordRaw: holder.joinRecordRaw, updatedAt: holder.updatedAt))
        }
        holder.note = merged.note
        holder.amount = merged.amount
        holder.date = merged.date
        if holder.account == nil, let account = arrivingDraft.account { holder.account = account }
        if holder.subcategory == nil, let subcategory = arrivingDraft.subcategory {
            holder.subcategory = subcategory
            holder.confidenceSubcategory = arrivingDraft.confidenceSubcategory
        }
        holder.cachedCurrencyCode = holder.account?.currencyCode ?? merged.cachedCurrencyCode
        holder.needsUserInput = DraftBuilder.computeNeedsUserInput(
            hasAmount: holder.amount != nil, hasAccount: holder.account != nil, hasSubcategory: holder.subcategory != nil)
        holder.joinRecordRaw = raw
        holder.updatedAt = now
        return true
    }

    // MARK: - «Es el mismo» (lote 3)

    /// «Es el mismo» de la Bandeja: une un pendiente ya guardado en otro, por el mismo camino que la unión al llegar
    /// (registro de unión, importe del banco y «Separar» después). `arriving` no puede tener nada unido; `holder` sí. Se
    /// borra `arriving` y se guarda todo en un solo `save()`; si falla, no cambia nada. Devuelve si se unió.
    @discardableResult
    static func joinPending(_ arriving: InboxDraft, into holder: InboxDraft, context: ModelContext,
                            now: Date = .now) -> Bool {
        guard arriving !== holder, arriving.isReadableInInbox, holder.isReadableInInbox,
              case .none = InboxJoinRecord.read(arriving.joinRecordRaw),
              let arrivalFacts = derivedFacts(of: arriving),
              let held = consumption(of: holder),
              let candidate = InboxJoinLogic.candidate(id: UUID(), facts: arrivalFacts, fields: fields(of: arriving),
                                                       fallbackDate: arriving.createdAt) else { return false }
        var joined = held
        guard joined.absorb(candidate) else { return false }

        var outcome = Outcome()
        guard join(arriving, members: [member(from: arriving, facts: arrivalFacts, joinedAt: now)], into: holder,
                   holderFacts: derivedFacts(of: holder), resolved: joined.resolved, holderIsArrival: false, now: now,
                   outcome: &outcome) else { return false }
        do {
            // La fila del que se va se desmonta antes del borrado (crash de iOS 27 al leer un modelo borrado, card f8rj).
            InboxRowPruneCoordinator.shared.pruneRow(arriving.persistentModelID)
            context.delete(arriving)
            SaveBreadcrumb.willSave("InboxArrivalJoin.joinPending")
            try context.save()
            SaveBreadcrumb.didSave("InboxArrivalJoin.joinPending")
            return true
        } catch {
            #if DEBUG
            print("InboxArrivalJoin: Error joining pending drafts: \(error)")
            #endif
            // El borrado no se deshace a mano: `rollback` lo descarta, y con él lo que la unión cambió en `holder`.
            revert(outcome)
            context.rollback()
            return false
        }
    }

    // MARK: - Separar

    /// Deshace la unión de un borrador pendiente: cada fuente absorbida vuelve como pendiente propio, tal como llegó, y el
    /// que la sostenía recupera sus valores donde siguen siendo los que dejó la unión (Paso 0, D6); si era el borrador de un
    /// planificado que creó la unión (lote 4), se borra. Guarda. Devuelve los
    /// borradores que volvió a crear, o `nil` si no había nada que separar o el guardado falló (entonces no cambia nada).
    @discardableResult
    static func separate(_ draft: InboxDraft, context: ModelContext, now: Date = .now) -> [InboxDraft]? {
        guard draft.status == .pending, case .record(let record) = InboxJoinRecord.read(draft.joinRecordRaw) else {
            return nil
        }
        let previous = HolderUndo(
            draft: draft, note: draft.note, amount: draft.amount, date: draft.date, account: draft.account,
            subcategory: draft.subcategory, confidenceSubcategory: draft.confidenceSubcategory,
            cachedCurrencyCode: draft.cachedCurrencyCode,
            needsUserInput: draft.needsUserInput, joinRecordRaw: draft.joinRecordRaw, updatedAt: draft.updatedAt)

        let restored = InboxJoinLogic.restoredFields(current: fields(of: draft), record: record)
        var created: [InboxDraft] = []
        do {
            draft.note = restored.note
            draft.amount = restored.amount
            draft.date = restored.date
            if restored.accountShortcutID != draft.account?.shortcutID {
                draft.account = try restored.accountShortcutID.flatMap {
                    try EntityApplyMap.findAccount(byShortcutID: $0, context: context)
                }
            }
            if restored.subcategoryShortcutID != draft.subcategory?.shortcutID {
                draft.subcategory = try restored.subcategoryShortcutID.flatMap {
                    try EntityApplyMap.findSubcategory(byShortcutID: $0, context: context)
                }
            }
            // Una categoría que solo trajo la unión se va con su confianza.
            if draft.subcategory == nil { draft.confidenceSubcategory = nil }
            draft.cachedCurrencyCode = restored.cachedCurrencyCode
            draft.needsUserInput = DraftBuilder.computeNeedsUserInput(
                hasAmount: draft.amount != nil, hasAccount: draft.account != nil, hasSubcategory: draft.subcategory != nil)
            draft.joinRecordRaw = nil
            draft.updatedAt = now

            for member in record.members {
                let account = try member.fields.accountShortcutID.flatMap {
                    try EntityApplyMap.findAccount(byShortcutID: $0, context: context)
                }
                let subcategory = try member.fields.subcategoryShortcutID.flatMap {
                    try EntityApplyMap.findSubcategory(byShortcutID: $0, context: context)
                }
                let separated = InboxDraft(
                    note: member.fields.note,
                    amount: member.fields.amount,
                    date: member.fields.date,
                    account: account,
                    subcategory: subcategory,
                    rawText: member.rawText,
                    evidence: member.evidence,
                    confidenceAmount: member.confidenceAmount,
                    confidenceDate: member.confidenceDate,
                    confidenceMerchant: member.confidenceMerchant,
                    confidenceSubcategory: subcategory == nil ? nil : member.confidenceSubcategory,
                    needsUserInput: DraftBuilder.computeNeedsUserInput(
                        hasAmount: member.fields.amount != nil, hasAccount: account != nil,
                        hasSubcategory: subcategory != nil)
                )
                // El origen tal cual (también uno que este build no conozca) y el instante de llegada: con él, otro
                // aparato reconoce el borrador de la IA (`AIConnectorDraftLogic.alreadyMaterialized`).
                separated.sourceTypeRaw = member.sourceTypeRaw
                separated.createdAt = member.createdAt
                separated.cachedCurrencyCode = account?.currencyCode ?? member.fields.cachedCurrencyCode
                context.insert(separated)
                created.append(separated)
            }

            SaveBreadcrumb.willSave("InboxArrivalJoin.separate")
            try context.save()
            SaveBreadcrumb.didSave("InboxArrivalJoin.separate")
            if record.holderCreatedByJoin == true { deletePlannedDraftCreatedByJoin(draft, context: context) }
            return created
        } catch {
            #if DEBUG
            print("InboxArrivalJoin: Error separating: \(error)")
            #endif
            created.forEach { context.delete($0) }
            var undo = Outcome()
            undo.undo = [previous]
            revert(undo)
            return nil
        }
    }

    /// Lote 4: el borrador de un planificado que solo existía para sostener el cargo se va al separar (el planificado lo
    /// vuelve a sacar el día que vence). Va en un guardado aparte, ya separado: si falla, queda como el borrador del
    /// planificado con sus valores de antes, que es un estado válido. La fila se desmonta antes del borrado (card f8rj).
    private static func deletePlannedDraftCreatedByJoin(_ draft: InboxDraft, context: ModelContext) {
        InboxRowPruneCoordinator.shared.pruneRow(draft.persistentModelID)
        context.delete(draft)
        do {
            try context.save()
        } catch {
            #if DEBUG
            print("InboxArrivalJoin: Error deleting the planned draft created by a join: \(error)")
            #endif
            context.rollback()
        }
    }

    // MARK: - La IA en otro aparato

    /// Lo que la IA ya dejó en este almacén, también lo que se unió a otro borrador: su instante de llegada, importe y nota
    /// tal como llegaron. Sin esto, otro aparato que trae la cola volvería a crear como nuevo lo que aquí se unió.
    static func aiMaterializations(in drafts: [InboxDraft]) -> [AIConnectorDraftLogic.Existing] {
        var known: [AIConnectorDraftLogic.Existing] = []
        for draft in drafts {
            guard case .record(let record) = InboxJoinRecord.read(draft.joinRecordRaw) else {
                if draft.sourceType == .aiConnector { known.append(AIConnectorDraftLogic.Existing(draft)) }
                continue
            }
            if draft.sourceType == .aiConnector {
                known.append(AIConnectorDraftLogic.Existing(
                    createdAt: draft.createdAt, amount: record.holderBefore.amount, note: record.holderBefore.note))
            }
            for member in record.members where member.sourceTypeRaw == DraftSourceType.aiConnector.rawValue {
                known.append(AIConnectorDraftLogic.Existing(
                    createdAt: member.createdAt, amount: member.fields.amount, note: member.fields.note))
            }
        }
        return known
    }

    // MARK: - Lo que se compara

    static func fields(of draft: InboxDraft) -> InboxJoinRecord.Fields {
        InboxJoinRecord.Fields(
            note: draft.note,
            amount: draft.amount,
            date: draft.date,
            accountShortcutID: draft.account?.shortcutID,
            subcategoryShortcutID: draft.subcategory?.shortcutID,
            cachedCurrencyCode: draft.cachedCurrencyCode
        )
    }

    /// La fuente del emparejador de un borrador de la Bandeja, o `nil` si no entra: no es una fuente que avise de un
    /// cargo, no es pendiente o no tiene importe.
    static func matchSource(of draft: InboxDraft) -> InboxMatchLogic.Source? {
        guard draft.status == .pending, draft.amount != nil, draft.splitExpenseID == nil,
              draft.splitSettlementID == nil else { return nil }
        let isBankNotice = draft.sourceType == .automation && BankNoticeBank.fromEvidence(draft.evidence) != nil
        return InboxMatchLogic.source(for: draft.sourceType, isBankNotice: isBankNotice)
    }

    /// Lo que se sabe de la fuente de un borrador pendiente que ya estaba, leído de lo que el borrador guarda.
    static func derivedFacts(of draft: InboxDraft) -> InboxJoinRecord.SourceFacts? {
        guard let source = matchSource(of: draft) else { return nil }
        var currency = draft.account?.currencyCode ?? draft.cachedCurrencyCode
        var last4: String?
        switch source {
        case .applePay:
            // El importe con su símbolo vive en `rawText`; un `$` suelto no dice la moneda.
            if currency == nil, let parsed = draft.rawText.flatMap(ApplePayAmountParser.parse), parsed.ambiguousSymbol == nil {
                currency = parsed.currency
            }
        case .bankEmail:
            // «BCP · ****4321»
            last4 = InboxMatchLogic.normalizedLast4(draft.evidence?.components(separatedBy: "****").dropFirst().first)
        case .bankNotice, .aiConnector, .web, .manual, .planned:
            break
        }
        return InboxJoinRecord.SourceFacts(
            source: source.rawValue, currencyCode: currency?.uppercased(), last4: last4,
            hasExactTime: source == .applePay || source == .bankNotice)
    }

    static func facts(for arrival: Arrival) -> InboxJoinRecord.SourceFacts? {
        guard let source = matchSource(of: arrival.draft) else { return nil }
        let currency = arrival.currencyCode ?? arrival.draft.account?.currencyCode
        return InboxJoinRecord.SourceFacts(
            source: source.rawValue, currencyCode: currency?.uppercased(),
            last4: InboxMatchLogic.normalizedLast4(arrival.last4),
            hasExactTime: source == .applePay || source == .bankNotice)
    }

    /// El consumo que sostiene un pendiente: él solo, o él con lo que ya absorbió. `nil` si no entra en el emparejador o
    /// su registro de unión no se entiende.
    static func consumption(of draft: InboxDraft) -> InboxMatchLogic.Consumption? {
        let id = UUID()
        switch InboxJoinRecord.read(draft.joinRecordRaw) {
        case .unreadable:
            return nil
        case .record(let record):
            guard matchSource(of: draft) != nil || isPlannedHolder(draft, record: record) else { return nil }
            return InboxJoinLogic.consumption(holderID: id, record: record, fallbackDate: draft.createdAt)
        case .none:
            guard let facts = derivedFacts(of: draft),
                  let candidate = InboxJoinLogic.candidate(id: id, facts: facts, fields: fields(of: draft),
                                                           fallbackDate: draft.createdAt) else { return nil }
            return InboxMatchLogic.Consumption(candidate)
        }
    }

    static func member(
        from draft: InboxDraft, facts: InboxJoinRecord.SourceFacts, joinedAt: Date
    ) -> InboxJoinRecord.Member {
        InboxJoinRecord.Member(
            facts: facts,
            fields: fields(of: draft),
            sourceTypeRaw: draft.sourceTypeRaw,
            createdAt: draft.createdAt,
            rawText: draft.rawText,
            evidence: draft.evidence,
            confidenceAmount: draft.confidenceAmount,
            confidenceDate: draft.confidenceDate,
            confidenceMerchant: draft.confidenceMerchant,
            confidenceSubcategory: draft.confidenceSubcategory,
            joinedAt: joinedAt
        )
    }
}
