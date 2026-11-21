//
//  RecurringFromRecordLogic.swift
//  Yala
//
//  «Hacer recurrente» a partir de un registro que ya existe (encargo del 15-nov): desde el menú y el detalle de un
//  registro, desde la Bandeja («Aprobar y hacer recurrente») y desde Planificación › Pagos («Desde un registro»). Las
//  tres entradas llegan al mismo editor prellenado, y el registro queda como el primer pago, ya pagado, del recurrente:
//  no se crea otro gasto. Aquí solo las decisiones, sin `@Model`; las aplica `RecurringFromRecordService`.
//

import Foundation

enum RecurringFromRecordLogic {

    // MARK: - Cuándo se ofrece

    /// Lo que hace falta saber de un registro para ofrecer «Hacer recurrente».
    struct RecordFacts: Equatable {
        /// Viene de un grupo (`RecordContextActionLogic.Shape.isGroupRecord`): sus recurrentes se crean desde el grupo.
        let isGroupRecord: Bool
        /// Transferencia, saldo inicial o ajuste: un pago planificado solo puede ser gasto o ingreso.
        let hasBalanceAdjustmentType: Bool
        /// Ya es un pago de un recurrente (`scheduledPaymentID`).
        let isLinkedToScheduledPayment: Bool
        /// La cuenta es de sistema (la de Grupos).
        let accountIsSystem: Bool
    }

    /// Se ofrece en un gasto o ingreso propio que todavía no pertenece a ningún recurrente. Lo de un grupo no: el
    /// editor de registros tampoco lo ofrece ahí (L8-6), y el recurrente de grupo se crea desde el grupo.
    static func offersMakeRecurring(_ facts: RecordFacts) -> Bool {
        !facts.isGroupRecord && !facts.hasBalanceAdjustmentType && !facts.isLinkedToScheduledPayment
            && !facts.accountIsSystem
    }

    /// «Aprobar y hacer recurrente» en la Bandeja: un borrador pendiente que no viene ya de un recurrente (ni de una
    /// suscripción ni de un gasto planificado de grupo) y que se aprueba como registro propio.
    static func offersApproveAndMakeRecurring(
        sourceType: DraftSourceType, sourceScheduledPaymentID: String?, isPending: Bool
    ) -> Bool {
        guard isPending, sourceScheduledPaymentID == nil else { return false }
        if ScheduledDraftOccurrenceLogic.holdsAnOccurrence(sourceType) { return false }
        switch sourceType {
        case .groupExpense, .groupSettlement: return false
        default: return true
        }
    }

    // MARK: - Gastos de grupo en «Reusar» (encargo del 21-nov)

    /// Lo que hace falta saber de una fila de grupo para ofrecerla en «Elige un registro».
    struct GroupLegFacts: Equatable {
        let hasSplitExpenseID: Bool
        let hasSplitSettlementID: Bool
        /// Pata derivada de una receta en líneas o pata de venta escrita por el puente (`RecordContextActionLogic.Shape`).
        let isSplitLineLeg: Bool
        let hasBalanceAdjustmentType: Bool
        let isLinkedToScheduledPayment: Bool
        let amount: Double
        /// Subcategoría de sistema del puente («Préstamo a grupos», liquidaciones, saldo inicial).
        let subcategoryIsBridgeSystem: Bool
    }

    /// La fila con el gasto del grupo, la que Registros enseña como «Luz Del Sur · Servicios del hogar · Jurpi»: el total
    /// que pagaste tú (pata real) o tu parte si pagó otro. Fuera la pata de «Préstamo a grupos» (positiva y de sistema),
    /// las liquidaciones, las ventas y las patas derivadas de una receta: no son un gasto que se repita.
    static func isReusableGroupExpense(_ facts: GroupLegFacts) -> Bool {
        facts.hasSplitExpenseID && !facts.hasSplitSettlementID && !facts.isSplitLineLeg
            && !facts.hasBalanceAdjustmentType && !facts.isLinkedToScheduledPayment
            && facts.amount < 0 && !facts.subcategoryIsBridgeSystem
    }

    /// Si el gasto de grupo se puede reusar, o por qué no.
    enum GroupAvailability: Equatable {
        case available
        /// El grupo no está en este teléfono, está oculto para todos o la fila no lleva grupo.
        case groupGone
        case archived
        /// Tu miembro del grupo ya no está activo (saliste o te quitaron).
        case notMember
    }

    /// El editor solo ofrece grupos vivos y no archivados (`loadAvailableGroups`), y un pago de grupo genera su borrador
    /// solo con tu miembro activo (`ScheduledPaymentDraftService.groupGateDecision`).
    static func groupAvailability(
        groupExists: Bool, isHiddenForAll: Bool, isArchived: Bool, currentMemberIsActive: Bool
    ) -> GroupAvailability {
        if !groupExists || isHiddenForAll { return .groupGone }
        if isArchived { return .archived }
        if !currentMemberIsActive { return .notMember }
        return .available
    }

    /// El reparto del pago compartido, como lo guarda `ScheduledPayment` (valor crudo por participante según el modo).
    struct GroupSplit: Equatable {
        let splitType: SplitType
        let participantIDs: [UUID]
        let values: [UUID: Double]
    }

    /// El reparto del gasto, para repetirlo. Participa quien tenía parte (> 0) y sigue activo. Valores: exacto, los
    /// montos; porcentaje, la parte de cada uno sobre el total; partes, la proporción entera si cuadra (si no, exacto).
    /// Si se quitó a alguien y no era a partes iguales, pasa a partes iguales entre los que quedan: sus valores ya no
    /// suman el total. `nil` si no queda nadie.
    static func groupSplit(
        splitType raw: String?, total: Double, shares: [(memberID: UUID, amount: Double)], activeMemberIDs: Set<UUID>
    ) -> GroupSplit? {
        let withShare = shares.filter { $0.amount > 0.0001 }
        let kept = withShare.filter { activeMemberIDs.contains($0.memberID) }
        guard !kept.isEmpty else { return nil }
        var type = SplitType(rawValue: raw ?? "") ?? .equal
        if kept.count < withShare.count && type != .equal { type = .equal }
        let ids = kept.map(\.memberID)
        switch type {
        case .equal:
            return GroupSplit(splitType: .equal, participantIDs: ids, values: [:])
        case .exact:
            return GroupSplit(splitType: .exact, participantIDs: ids, values: amounts(kept))
        case .percentage:
            let base = total > 0 ? total : kept.reduce(0) { $0 + $1.amount }
            var values: [UUID: Double] = [:]
            for share in kept { values[share.memberID] = (share.amount / base * 10_000).rounded() / 100 }
            return GroupSplit(splitType: .percentage, participantIDs: ids, values: values)
        case .shares:
            guard let smallest = kept.map(\.amount).min(), smallest > 0 else {
                return GroupSplit(splitType: .exact, participantIDs: ids, values: amounts(kept))
            }
            var counts: [UUID: Double] = [:]
            for share in kept {
                let ratio = share.amount / smallest
                guard abs(ratio - ratio.rounded()) < 0.02, ratio.rounded() <= 100 else {
                    return GroupSplit(splitType: .exact, participantIDs: ids, values: amounts(kept))
                }
                counts[share.memberID] = ratio.rounded()
            }
            return GroupSplit(splitType: .shares, participantIDs: ids, values: counts)
        }
    }

    private static func amounts(_ shares: [(memberID: UUID, amount: Double)]) -> [UUID: Double] {
        var values: [UUID: Double] = [:]
        for share in shares { values[share.memberID] = share.amount }
        return values
    }

    // MARK: - Prellenado

    /// El nombre del recurrente: la descripción del registro y, sin ella, su subcategoría («Cloudflare», o «Hosting» si
    /// el registro no tiene nota). Vacío si no hay ninguna de las dos: el editor lo pide.
    static func paymentName(note: String?, subcategoryName: String?) -> String {
        let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmed.isEmpty { return trimmed }
        return subcategoryName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    // MARK: - Un recurrente parecido

    /// Un recurrente que ya existe, listo para comparar.
    struct Candidate: Equatable {
        let id: UUID
        let name: String
        let storedBrandID: String?
        let amount: Double
        let currencyCode: String
        let transactionType: String
        let subcategoryID: UUID?
        let isVariableAmount: Bool
        let isActive: Bool
        let isGroupPayment: Bool
    }

    /// El registro que se quiere hacer recurrente.
    struct Probe: Equatable {
        let name: String
        /// Magnitud, sin signo.
        let amount: Double
        let currencyCode: String
        let transactionType: String
        let subcategoryID: UUID?
    }

    /// El recurrente parecido al registro, o `nil`: misma moneda, mismo tipo (gasto o ingreso), monto cercano (±15 %,
    /// el margen de las propuestas de «Pagos que se repiten»; uno de monto variable no se compara por monto) y el mismo
    /// comercio —la misma marca, el mismo nombre o uno que empieza por el otro—. Sin nombre en alguno de los dos, la
    /// misma subcategoría. Dos nombres que no se parecen NO casan por la subcategoría: «Netflix» y «Disney+» comparten
    /// «Streaming» y no son el mismo pago. Entre varios, primero el del mismo comercio y luego el de monto más cercano;
    /// los de grupo y los pausados, fuera.
    static func similarPayment(to probe: Probe, among candidates: [Candidate]) -> Candidate? {
        let probeName = RecurringPaymentDetector.merchantName(probe.name)
        let probeBrand = RecurringPaymentDetector.brand(forChargeName: probe.name)
        let probeCurrency = normalizeCurrencyCode(probe.currencyCode)
        var best: (candidate: Candidate, score: Int, difference: Double)?
        for candidate in candidates {
            guard candidate.isActive, !candidate.isGroupPayment,
                  candidate.transactionType == probe.transactionType,
                  normalizeCurrencyCode(candidate.currencyCode) == probeCurrency else { continue }
            if !candidate.isVariableAmount {
                guard RecurringPaymentDetector.amountMatches(probe.amount, reference: candidate.amount, exact: false)
                else { continue }
            }
            let score: Int
            switch merchantMatch(probeName: probeName, probeBrand: probeBrand, candidate: candidate) {
            case .same: score = 2
            case .different: continue
            case .unknown:
                guard let probeSub = probe.subcategoryID, probeSub == candidate.subcategoryID else { continue }
                score = 1
            }
            let difference = candidate.isVariableAmount ? Double.greatestFiniteMagnitude : abs(candidate.amount - probe.amount)
            if let current = best,
               current.score > score || (current.score == score && current.difference <= difference) {
                continue
            }
            best = (candidate, score, difference)
        }
        return best?.candidate
    }

    private enum MerchantMatch { case same, different, unknown }

    private static func merchantMatch(
        probeName: String, probeBrand: SubscriptionBrand?, candidate: Candidate
    ) -> MerchantMatch {
        let candidateBrand = SubscriptionBrandCatalog.resolve(storedID: candidate.storedBrandID, name: candidate.name)
        if let probeBrand, let candidateBrand { return probeBrand.id == candidateBrand.id ? .same : .different }
        let candidateName = RecurringPaymentDetector.merchantName(candidate.name)
        guard !probeName.isEmpty, !candidateName.isEmpty else { return .unknown }
        if probeName == candidateName || probeName.hasPrefix(candidateName + " ")
            || candidateName.hasPrefix(probeName + " ") {
            return .same
        }
        return .different
    }

    // MARK: - La próxima fecha tras el vínculo

    /// Recurrente NUEVO a partir del registro: el editor lo crea con el primer vencimiento en la fecha del registro, y
    /// ese vencimiento es el registro, ya pagado. La próxima fecha avanza mientras caiga el día del registro o antes, y
    /// también mientras quede antes de hoy: con un registro de hace meses, lo de en medio no se le pide a la Bandeja
    /// (la persona lo tendrá apuntado por su lado y saldría dos veces). Un vencimiento de HOY sí se queda: es el pago
    /// de hoy, que todavía no se ha registrado.
    static func firstPaymentAdvances(
        nextDueDate: Date, recordDate: Date, now: Date, calendar: Calendar = .current
    ) -> Bool {
        let due = calendar.startOfDay(for: nextDueDate)
        return due <= calendar.startOfDay(for: recordDate) || due < calendar.startOfDay(for: now)
    }

    /// Vincular el registro a un recurrente que YA existe: cubre el vencimiento que le toca. La próxima fecha avanza
    /// si el registro es de ese día o posterior, o si se adelantó unos pocos días (el pago se cobró antes de vencer).
    /// Un registro anterior a eso es un pago de antes y no mueve nada.
    static func linkAdvances(
        nextDueDate: Date, recordDate: Date, recurrenceType: String, calendar: Calendar = .current
    ) -> Bool {
        let due = calendar.startOfDay(for: nextDueDate)
        let record = calendar.startOfDay(for: recordDate)
        guard let window = calendar.date(byAdding: .day, value: earlyPaymentDays(recurrenceType), to: record) else {
            return due <= record
        }
        return due <= window
    }

    /// Cuántos días antes de vencer cuenta un pago como el de ese vencimiento. Los márgenes de «Pagos que se repiten»
    /// (4 días al mes, 1 a la semana); al año, una semana; a diario, ninguno.
    static func earlyPaymentDays(_ recurrenceType: String) -> Int {
        switch RecurrenceType(rawValue: recurrenceType) {
        case .daily: return 0
        case .weekly: return RecurringPaymentDetector.weeklyToleranceDays
        case .yearly: return 7
        case .monthly, .none: return RecurringPaymentDetector.monthlyToleranceDays
        }
    }
}
