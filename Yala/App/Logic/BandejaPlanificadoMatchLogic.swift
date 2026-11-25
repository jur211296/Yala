//
//  BandejaPlanificadoMatchLogic.swift
//  Yala
//
//  Bandeja sin duplicados, lote 4 (opción B de `docs/propuestas/bandeja-sin-duplicados/README.md`, decidida por Jürgen el
//  24-nov): el cargo que llega por Apple Pay, el aviso o el correo del banco, la web o tu IA y que ES un pago planificado
//  no crea otro pendiente: completa el borrador del planificado. Aquí se decide cuándo lo es. Pura: sin `ModelContext`;
//  el cableado está en `InboxArrivalJoin` (al llegar) y en la Bandeja (la pregunta).
//
//  La regla, campo a campo (Paso 0 del encargo, D2):
//
//  | Campo      | Fuerte (se une solo)                              | Dudosa (se pregunta)                              |
//  |------------|---------------------------------------------------|---------------------------------------------------|
//  | Quién      | un alias aprendido del comercio                   | solo el nombre del planificado («la primera vez») |
//  | Tipo       | mismo signo                                       | —                                                 |
//  | Tiempo     | ±5 días de calendario de la ocurrencia            | —                                                 |
//  | Importe    | estimado: de la mitad al doble; fijo: ±0,01       | fijo: hasta ±25 %; otra moneda convertida, o una  |
//  |            |                                                   | moneda que la fuente no dijo                      |
//  | Cuenta     | la misma, o una de las dos sin cuenta             | distinta                                          |
//  | Fuentes    | la fuente no está ya en el borrador del planificado| —                                                |
//
//  El alias se aprende sin campo nuevo (D5): son los comercios de lo que ya se unió a los borradores de ese planificado.
//

import Foundation

nonisolated enum BandejaPlanificadoMatchLogic {

    // MARK: - Tolerancias

    static let dayWindow = 5
    static let strongAmountTolerance = InboxMatchLogic.strongAmountTolerance
    /// Un fijo cuyo cargo difiere hasta este tanto se pregunta: una subida de precio, una comisión.
    static let fixedAskFraction = 0.25
    /// Un estimado toma el cargo real entre la mitad y el doble.
    static let estimateMinRatio = 0.5
    static let estimateMaxRatio = 2.0

    // MARK: - Lo que se compara

    /// Un pago planificado visto por el emparejador, con la ocurrencia que el cargo cubriría.
    nonisolated struct Planned: Equatable, Sendable {
        let paymentID: UUID
        let name: String
        /// Los comercios aprendidos: lo que ya se unió a sus borradores.
        let aliases: [String]
        /// Con signo: gasto negativo, ingreso positivo. Si su borrador ya absorbió un cargo, el de ese cargo.
        let amount: Double
        let currencyCode: String?
        /// El importe es un estimado (`isVariableAmount`) y nada real lo sustituyó todavía.
        let isEstimate: Bool
        let accountID: UUID?
        /// El día de la ocurrencia: la fecha de su borrador pendiente, o su próximo vencimiento.
        let occurrence: Date
        /// Las fuentes que su borrador ya absorbió: una que ya está no entra otra vez (uno a uno).
        let occupiedSources: Set<InboxMatchLogic.Source>

        init(paymentID: UUID, name: String, aliases: [String] = [], amount: Double, currencyCode: String?,
             isEstimate: Bool, accountID: UUID? = nil, occurrence: Date,
             occupiedSources: Set<InboxMatchLogic.Source> = []) {
            self.paymentID = paymentID
            self.name = name
            self.aliases = aliases
            self.amount = amount
            self.currencyCode = currencyCode?.uppercased()
            self.isEstimate = isEstimate
            self.accountID = accountID
            self.occurrence = occurrence
            self.occupiedSources = occupiedSources
        }
    }

    /// Un cargo que llega, o un pendiente con lo que ya absorbió.
    nonisolated struct Arrival: Equatable, Sendable {
        let amount: Double
        let currencyCode: String?
        let date: Date
        let accountID: UUID?
        /// El comercio de cada fuente del consumo (uno si llegó solo).
        let merchants: [String]
        let sources: Set<InboxMatchLogic.Source>

        init(amount: Double, currencyCode: String?, date: Date, accountID: UUID? = nil, merchants: [String],
             sources: Set<InboxMatchLogic.Source>) {
            self.amount = amount
            self.currencyCode = currencyCode?.uppercased()
            self.date = date
            self.accountID = accountID
            self.merchants = merchants
            self.sources = sources
        }

        /// Lo que manda en un consumo del emparejador: importe y moneda del banco, su fecha, su cuenta, y el comercio de
        /// cada fuente.
        init(_ consumption: InboxMatchLogic.Consumption) {
            let resolved = consumption.resolved
            self.init(
                amount: resolved.money.amount, currencyCode: resolved.money.currencyCode, date: resolved.date,
                accountID: resolved.accountID,
                merchants: consumption.members.compactMap(\.merchant),
                sources: consumption.sources)
        }
    }

    typealias Level = InboxMatchLogic.Level

    nonisolated struct Comparison: Equatable, Sendable {
        var identity: Level
        var kind: Level
        var time: Level
        var amount: Level
        var account: Level
        var sources: Level
        /// Para elegir entre varios: días hasta la ocurrencia y diferencia de importe (fracción del planificado).
        var dayGap: Int
        var amountGap: Double

        var level: Level { min(identity, kind, time, amount, account, sources) }
        /// Si casó por un alias aprendido y no solo por el nombre.
        var byAlias: Bool { identity == .strong }
    }

    // MARK: - Comparar

    static func compare(
        _ arrival: Arrival, _ planned: Planned, converter: InboxMatchLogic.Converter? = nil,
        calendar: Calendar = .current
    ) -> Comparison {
        let days = InboxMatchLogic.dayDifference(from: planned.occurrence, to: arrival.date, calendar: calendar)
        let amount = amountLevel(arrival, planned, converter: converter)
        return Comparison(
            identity: identityLevel(merchants: arrival.merchants, name: planned.name, aliases: planned.aliases),
            kind: InboxMatchLogic.kindLevel(arrival.amount, planned.amount == 0 ? arrival.amount : planned.amount),
            time: days != Int.max && abs(days) <= dayWindow ? .strong : .none,
            amount: amount.level,
            account: accountLevel(arrival.accountID, planned.accountID),
            sources: arrival.sources.isDisjoint(with: planned.occupiedSources) ? .strong : .none,
            dayGap: days == Int.max ? Int.max : abs(days),
            amountGap: amount.gap
        )
    }

    /// Quién: un alias aprendido es fuerte; solo el nombre del planificado, dudoso (se pregunta la primera vez). Un
    /// comercio vacío no dice nada: sin palabras de un lado o del otro no casa (a diferencia del emparejador entre fuentes,
    /// donde lo vacío no resta: ahí ya casan importe y hora; aquí el nombre ES la prueba).
    static func identityLevel(merchants: [String], name: String, aliases: [String]) -> Level {
        let arriving = merchants.filter { !InboxMatchLogic.merchantTokens($0).isEmpty }
        guard !arriving.isEmpty else { return .none }
        let learned = aliases.filter { !InboxMatchLogic.merchantTokens($0).isEmpty }
        if arriving.contains(where: { merchant in learned.contains { InboxMatchLogic.merchantsLookAlike(merchant, $0) } }) {
            return .strong
        }
        guard !InboxMatchLogic.merchantTokens(name).isEmpty else { return .none }
        return arriving.contains { InboxMatchLogic.merchantsLookAlike($0, name) } ? .doubtful : .none
    }

    static func accountLevel(_ arriving: UUID?, _ planned: UUID?) -> Level {
        guard let arriving, let planned else { return .strong }
        return arriving == planned ? .strong : .doubtful
    }

    static func amountLevel(
        _ arrival: Arrival, _ planned: Planned, converter: InboxMatchLogic.Converter?
    ) -> (level: Level, gap: Double) {
        var real = abs(arrival.amount)
        var cap: Level = .strong
        if let from = arrival.currencyCode, let to = planned.currencyCode, from != to {
            guard let converter, let converted = converter(real, from, to) else { return (.none, 1) }
            real = abs(converted)
            cap = .doubtful
        } else if arrival.currencyCode == nil || planned.currencyCode == nil {
            // Un `$` suelto puede ser otra moneda con el mismo número: no une solo.
            cap = .doubtful
        }
        let expected = abs(planned.amount)
        guard real > 0 else { return (.none, 1) }
        guard expected > 0 else {
            // Un estimado sin importe toma el que llegue; un fijo sin importe no tiene con qué casar.
            return (planned.isEstimate ? min(.strong, cap) : .none, 1)
        }
        let gap = abs(real - expected) / expected
        let level: Level
        if planned.isEstimate {
            let ratio = real / expected
            level = ratio >= estimateMinRatio - 1e-9 && ratio <= estimateMaxRatio + 1e-9 ? .strong : .none
        } else if abs(real - expected) <= strongAmountTolerance + 1e-9 {
            level = .strong
        } else {
            level = gap <= fixedAskFraction + 1e-9 ? .doubtful : .none
        }
        return (min(level, cap), gap)
    }

    // MARK: - Elegir

    nonisolated struct Match: Equatable, Sendable {
        let planned: Planned
        let comparison: Comparison

        var level: Level { comparison.level }
    }

    /// El planificado que mejor casa con lo que llega, o `nil` si ninguno. Lo fuerte gana a lo dudoso; entre iguales, la
    /// ocurrencia más cercana y luego el importe más parecido.
    static func best(
        for arrival: Arrival, among planned: [Planned], converter: InboxMatchLogic.Converter? = nil,
        calendar: Calendar = .current
    ) -> Match? {
        var winner: Match?
        for candidate in planned {
            let comparison = compare(arrival, candidate, converter: converter, calendar: calendar)
            guard comparison.level > .none else { continue }
            guard let incumbent = winner else {
                winner = Match(planned: candidate, comparison: comparison)
                continue
            }
            if isBetter(comparison, than: incumbent.comparison) {
                winner = Match(planned: candidate, comparison: comparison)
            }
        }
        return winner
    }

    static func isBetter(_ lhs: Comparison, than rhs: Comparison) -> Bool {
        if lhs.level != rhs.level { return lhs.level > rhs.level }
        if lhs.dayGap != rhs.dayGap { return lhs.dayGap < rhs.dayGap }
        return lhs.amountGap < rhs.amountGap
    }

    // MARK: - Las preguntas de la Bandeja

    nonisolated struct Question: Equatable, Sendable {
        /// Índice en las llegadas.
        let arrival: Int
        let paymentID: UUID
        let level: Level
    }

    /// «¿Es tu pago X?» para los pendientes que casan con un planificado y no se unieron solos: uno a uno, la mejor pareja
    /// primero (un planificado recibe una sola pregunta, y cada pendiente también). `excluded` dice qué parejas ya se
    /// contestaron con «No» (índice de llegada, pago).
    static func questions(
        arrivals: [Arrival], planned: [Planned], excluded: (Int, UUID) -> Bool = { _, _ in false },
        converter: InboxMatchLogic.Converter? = nil, calendar: Calendar = .current
    ) -> [Question] {
        var options: [(question: Question, comparison: Comparison)] = []
        for (index, arrival) in arrivals.enumerated() {
            for candidate in planned where !excluded(index, candidate.paymentID) {
                let comparison = compare(arrival, candidate, converter: converter, calendar: calendar)
                guard comparison.level > .none else { continue }
                options.append((Question(arrival: index, paymentID: candidate.paymentID, level: comparison.level),
                                comparison))
            }
        }
        options.sort { lhs, rhs in
            if isBetter(lhs.comparison, than: rhs.comparison) { return true }
            if isBetter(rhs.comparison, than: lhs.comparison) { return false }
            return lhs.question.arrival < rhs.question.arrival
        }
        var usedArrivals: Set<Int> = []
        var usedPayments: Set<UUID> = []
        var chosen: [Question] = []
        for option in options
        where !usedArrivals.contains(option.question.arrival) && !usedPayments.contains(option.question.paymentID) {
            usedArrivals.insert(option.question.arrival)
            usedPayments.insert(option.question.paymentID)
            chosen.append(option.question)
        }
        return chosen.sorted { $0.arrival < $1.arrival }
    }
}
