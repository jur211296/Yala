//
//  InboxMatchLogic.swift
//  Yala
//
//  Bandeja sin duplicados, lote 1 (opción B de `docs/propuestas/bandeja-sin-duplicados/README.md`, decidida por Jürgen
//  el 24-nov): el EMPAREJADOR entre fuentes. Con Apple Pay, el aviso del banco y el correo del banco conectados, un mismo
//  café llega tres veces; aquí se decide cuándo son el mismo consumo, y qué fuente manda en cada campo cuando se unen.
//  Pura: sin `ModelContext` ni UI. El cableado al llegar cada borrador, el campo que recuerda lo unido y «Separar» son
//  el lote 2; la fila de la Bandeja, el 3; los pagos planificados, el 4.
//
//  La idea que lo hace seguro: cada fuente cuenta cada pago UNA sola vez. Apple Pay no manda dos veces el mismo pago, ni
//  el aviso, ni el correo (ya filtrado por su id). Así que dos borradores de la MISMA fuente nunca se funden —dos cafés
//  iguales por Apple Pay son dos cafés— y un consumo absorbe como mucho uno de cada otra fuente (uno a uno).
//
//  La regla, campo a campo (sección 3·B de la propuesta):
//
//  | Campo    | Fuerte (se une solo)                                  | Dudosa (se pregunta)                            |
//  |----------|-------------------------------------------------------|-------------------------------------------------|
//  | Tipo     | mismo signo                                           | —                                               |
//  | Cuenta   | la misma, o una sin cuenta y los últimos 4 casan      | una sin cuenta y nada que la contradiga         |
//  | Importe  | misma moneda (las dos dichas), ±0,01                  | misma moneda ±3 %, u otra moneda convertida ±4 % |
//  | Tiempo   | ≤ 6 h con hora en los dos; con solo el día, ese día   | hasta 72 h (3 días de calendario si falta hora) |
//  |          | o el siguiente al de la hora; sin hora en ninguno, el |                                                 |
//  |          | mismo día                                             |                                                 |
//  | Comercio | parecido (palabras normalizadas; vacío no resta)      | distinto                                        |
//  | Fuentes  | distintas, y libre en el consumo                      | —                                               |
//
//  Grupos y cuentas compartidas quedan fuera (decisión 7): sus borradores no tienen `Source` y no entran.
//

import Foundation

nonisolated enum InboxMatchLogic {

    // MARK: - Fuentes

    /// De dónde llegó un borrador, para el emparejador. Solo las fuentes que avisan de un cargo y llegan solas.
    nonisolated enum Source: String, CaseIterable, Sendable {
        case applePay
        case bankNotice
        case bankEmail
        case aiConnector
        case web
        /// Un movimiento ya guardado a mano, o uno guardado cuyo origen no se sabe. Solo aparece en lo guardado.
        case manual
        /// El borrador de un pago planificado que absorbió un cargo (lote 4, `BandejaPlanificadoMatchLogic`). Solo sostiene
        /// un consumo: nunca llega como fuente, y sin nada unido no entra en el emparejador. Va el último en importe, hora y
        /// comercio: lo que manda es lo que dijo el banco, y el importe del planificado puede ser un estimado.
        case planned
    }

    /// La fuente del emparejador para un borrador de la Bandeja, o `nil` si no entra. El aviso del banco y Yala web
    /// comparten `.automation`; los separa el banco en la evidencia (`BankNoticeOrigin`), que el llamador ya lee.
    /// Fuera: grupos (decisión 7), planificados y suscripciones (lote 4), y lo que la persona dicta o fotografía (Siri,
    /// voz, foto, capturas), que no avisa de un cargo: lo cuenta ella.
    @MainActor
    static func source(for sourceType: DraftSourceType, isBankNotice: Bool) -> Source? {
        switch sourceType {
        case .applePay: return .applePay
        case .emailAlert: return .bankEmail
        case .automation: return isBankNotice ? .bankNotice : .web
        case .aiConnector: return .aiConnector
        case .voice, .receiptPhoto, .screenshotList, .screenshotSingle, .scheduledPayment, .subscription, .siri,
             .groupExpense, .groupSettlement, .manual, .groupScheduledExpense:
            return nil
        }
    }

    // MARK: - Lo que se compara

    /// Un borrador pendiente o un movimiento guardado, visto por el emparejador.
    nonisolated struct Candidate: Equatable, Sendable {
        let id: UUID
        let source: Source
        /// Con signo: gasto negativo, ingreso positivo.
        let amount: Double
        /// ISO 4217 en mayúsculas, o `nil` si la fuente no la dijo (un `$` suelto).
        let currencyCode: String?
        let date: Date
        /// `false` si la fuente solo trae el día (el correo lo pone a mediodía; la IA y la web, el día que dijeron).
        let hasExactTime: Bool
        let accountID: UUID?
        /// Últimos 4 de la tarjeta que dijo la fuente, o los de la cuenta resuelta.
        let last4: String?
        let merchant: String?

        init(
            id: UUID = UUID(), source: Source, amount: Double, currencyCode: String?, date: Date, hasExactTime: Bool,
            accountID: UUID? = nil, last4: String? = nil, merchant: String? = nil
        ) {
            self.id = id
            self.source = source
            self.amount = amount
            self.currencyCode = currencyCode?.uppercased()
            self.date = date
            self.hasExactTime = hasExactTime
            self.accountID = accountID
            self.last4 = last4
            self.merchant = merchant
        }
    }

    /// Convierte un importe de una moneda a otra con las tasas que tenga la app, o `nil` si no puede.
    typealias Converter = @Sendable (_ amount: Double, _ from: String, _ to: String) -> Double?

    nonisolated enum Level: Int, Comparable, Sendable {
        case none = 0
        case doubtful = 1
        case strong = 2

        static func < (lhs: Level, rhs: Level) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    /// El veredicto campo a campo. El conjunto vale lo que su campo más flojo.
    nonisolated struct Comparison: Equatable, Sendable {
        var kind: Level
        var sources: Level
        var account: Level
        var amount: Level
        var time: Level
        var merchant: Level
        /// Para elegir entre varios candidatos del mismo nivel: cuánto se separan en el tiempo (los días sin hora
        /// cuentan enteros) y en el importe (fracción del mayor).
        var timeGap: TimeInterval
        var amountGap: Double

        var level: Level { min(kind, sources, account, amount, time, merchant) }
    }

    // MARK: - Tolerancias

    static let strongAmountTolerance = 0.01
    static let doubtfulAmountFraction = 0.03
    static let otherCurrencyFraction = 0.04
    static let strongTimeWindow: TimeInterval = 6 * 3600
    static let doubtfulTimeWindow: TimeInterval = 72 * 3600
    static let doubtfulDayWindow = 3

    // MARK: - Comparar dos

    static func compare(
        _ a: Candidate, _ b: Candidate, converter: Converter? = nil, calendar: Calendar = .current
    ) -> Comparison {
        let amount = amountLevel(a, b, converter: converter)
        let time = timeLevel(a, b, calendar: calendar)
        return Comparison(
            kind: kindLevel(a.amount, b.amount),
            sources: a.source == b.source ? .none : .strong,
            account: accountLevel(a, b),
            amount: amount.level,
            time: time.level,
            merchant: merchantsLookAlike(a.merchant, b.merchant) ? .strong : .doubtful,
            timeGap: time.gap,
            amountGap: amount.gap
        )
    }

    /// Un ingreso nunca se une a un gasto: el reembolso del mismo café es otro movimiento. Importe cero, tampoco.
    static func kindLevel(_ a: Double, _ b: Double) -> Level {
        guard a != 0, b != 0 else { return .none }
        return (a < 0) == (b < 0) ? .strong : .none
    }

    static func accountLevel(_ a: Candidate, _ b: Candidate) -> Level {
        if let first = a.accountID, let second = b.accountID {
            return first == second ? .strong : .none
        }
        if let first = normalizedLast4(a.last4), let second = normalizedLast4(b.last4) {
            return first == second ? .strong : .none
        }
        return .doubtful
    }

    static func amountLevel(_ a: Candidate, _ b: Candidate, converter: Converter?) -> (level: Level, gap: Double) {
        let first = abs(a.amount)
        let second = abs(b.amount)
        let larger = max(first, second)
        guard larger > 0 else { return (.none, 1) }

        if let from = a.currencyCode, let to = b.currencyCode, from != to {
            guard second > 0, let converter, let converted = converter(first, from, to) else { return (.none, 1) }
            let gap = abs(abs(converted) - second) / second
            return (gap <= otherCurrencyFraction + 1e-9 ? .doubtful : .none, gap)
        }
        let difference = abs(first - second)
        let gap = difference / larger
        // Una moneda que la fuente no dijo no deja unir solo: puede ser otra con el mismo número.
        let bothKnown = a.currencyCode != nil && b.currencyCode != nil
        if difference <= strongAmountTolerance + 1e-9 { return (bothKnown ? .strong : .doubtful, gap) }
        return (gap <= doubtfulAmountFraction + 1e-9 ? .doubtful : .none, gap)
    }

    static func timeLevel(_ a: Candidate, _ b: Candidate, calendar: Calendar) -> (level: Level, gap: TimeInterval) {
        if a.hasExactTime && b.hasExactTime {
            let gap = abs(a.date.timeIntervalSince(b.date))
            if gap <= strongTimeWindow { return (.strong, gap) }
            return (gap <= doubtfulTimeWindow ? .doubtful : .none, gap)
        }
        if a.hasExactTime || b.hasExactTime {
            // El correo fecha el cargo el día que lo asienta: el de la compra o el siguiente (23:50 del 15 y correo del
            // 16). Nunca antes.
            let exact = a.hasExactTime ? a : b
            let dayOnly = a.hasExactTime ? b : a
            let days = dayDifference(from: exact.date, to: dayOnly.date, calendar: calendar)
            let gap = TimeInterval(abs(days)) * 86_400
            if days == 0 || days == 1 { return (.strong, gap) }
            return (abs(days) <= doubtfulDayWindow ? .doubtful : .none, gap)
        }
        let days = dayDifference(from: a.date, to: b.date, calendar: calendar)
        let gap = TimeInterval(abs(days)) * 86_400
        if days == 0 { return (.strong, gap) }
        return (abs(days) <= doubtfulDayWindow ? .doubtful : .none, gap)
    }

    /// Días de calendario de `start` a `end`, con signo. `Int.max` si el calendario no sabe contarlos.
    static func dayDifference(from start: Date, to end: Date, calendar: Calendar) -> Int {
        let from = calendar.startOfDay(for: start)
        let to = calendar.startOfDay(for: end)
        return calendar.dateComponents([.day], from: from, to: to).day ?? Int.max
    }

    // MARK: - Comercio

    /// Palabras que los bancos y los atajos añaden y no dicen quién cobró.
    static let merchantNoise: Set<String> = [
        "sac", "eirl", "srl", "ltda", "inc", "llc", "com", "www", "http", "https",
        "lima", "peru", "per", "compra", "consumo", "pago", "pagos", "pos", "visa", "mastercard", "amex",
        "tarjeta", "debito", "credito", "online", "linea", "the", "del", "los", "las", "con", "por", "para",
    ]

    /// Las palabras que cuentan de un comercio: sin acentos ni mayúsculas, de 3 letras o más, no solo cifras y sin ruido.
    static func merchantTokens(_ merchant: String?) -> [String] {
        guard let merchant else { return [] }
        let folded = merchant.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "es"))
        let words = folded.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init)
        return words.filter { word in
            word.count >= 3 && !word.allSatisfy(\.isNumber) && !merchantNoise.contains(word)
        }
    }

    /// Dos comercios se parecen si comparten una palabra, o si una de 4 letras o más de uno aparece dentro del otro
    /// («Wong» en «WONGSUPERMERCADO», «uber» en «DLC*UBER»). Vacío no resta: el correo a veces no lo trae.
    static func merchantsLookAlike(_ a: String?, _ b: String?) -> Bool {
        let first = merchantTokens(a)
        let second = merchantTokens(b)
        guard !first.isEmpty, !second.isEmpty else { return true }
        if !Set(first).isDisjoint(with: second) { return true }
        let joinedFirst = first.joined()
        let joinedSecond = second.joined()
        return first.contains { $0.count >= 4 && joinedSecond.contains($0) }
            || second.contains { $0.count >= 4 && joinedFirst.contains($0) }
    }

    /// Los últimos 4 dígitos de lo que diga la fuente («****1234», «1234»), o `nil` si no hay 4 cifras.
    static func normalizedLast4(_ value: String?) -> String? {
        guard let digits = value?.filter(\.isNumber), digits.count >= 4 else { return nil }
        return String(digits.suffix(4))
    }

    // MARK: - El consumo: lo que ya se unió

    /// Un pendiente de la Bandeja y lo que absorbió de otras fuentes. `id` es el del borrador que lo sostiene (el
    /// primero que llegó).
    nonisolated struct Consumption: Equatable, Sendable {
        /// El borrador que sostiene el consumo: el primero que llegó.
        let holder: Candidate
        /// Lo que absorbió de otras fuentes, en el orden en que llegó.
        private(set) var absorbed: [Candidate] = []

        init(_ first: Candidate) {
            holder = first
        }

        var id: UUID { holder.id }
        var members: [Candidate] { [holder] + absorbed }

        var sources: Set<Source> { Set(members.map(\.source)) }

        /// Uno de cada fuente: una fuente que ya está no entra otra vez.
        func canAbsorb(_ candidate: Candidate) -> Bool { !sources.contains(candidate.source) }

        @discardableResult
        mutating func absorb(_ candidate: Candidate) -> Bool {
            guard canAbsorb(candidate) else { return false }
            absorbed.append(candidate)
            return true
        }

        var resolved: Resolved { InboxMatchLogic.resolve(first: holder, others: absorbed) }
    }

    // MARK: - Qué fuente manda

    nonisolated struct Money: Equatable, Sendable {
        let amount: Double
        let currencyCode: String?
    }

    /// El borrador que queda de un consumo, y de dónde salió cada campo.
    nonisolated struct Resolved: Equatable, Sendable {
        let money: Money
        let moneySource: Source
        /// Lo que dijo otra fuente cuando no coincide con el importe que manda (Apple Pay en dólares): queda de evidencia.
        let originalMoney: Money?
        let date: Date
        let hasExactTime: Bool
        let dateSource: Source
        let accountID: UUID?
        let accountSource: Source?
        let last4: String?
        let merchant: String?
        let merchantSource: Source?
        let sources: [Source]
    }

    /// Importe y moneda: del banco, que es lo que salió de la cuenta. El correo antes que el aviso: es el cargo asentado.
    static let moneyPriority: [Source] = [.bankEmail, .bankNotice, .applePay, .web, .aiConnector, .manual, .planned]
    /// Comercio: Apple Pay lo trae limpio; después lo que eligió la persona (web) o su IA; el texto del banco, al final. El
    /// nombre del planificado no cuenta como comercio: el borrador del planificado conserva su nota aparte
    /// (`InboxJoinLogic.mergedFields`).
    static let merchantPriority: [Source] = [.applePay, .web, .aiConnector, .bankNotice, .bankEmail, .manual, .planned]
    /// Hora: Apple Pay o el aviso, los que la traen.
    static let timePriority: [Source] = [.applePay, .bankNotice, .bankEmail, .aiConnector, .web, .manual, .planned]
    /// Cuenta: quien traiga la tarjeta o los últimos 4.
    static let accountPriority: [Source] = [.bankNotice, .bankEmail, .applePay, .aiConnector, .web, .manual, .planned]

    static func ordered(_ members: [Candidate], by priority: [Source]) -> [Candidate] {
        let rank: (Candidate) -> Int = { priority.firstIndex(of: $0.source) ?? priority.count }
        return members.enumerated().sorted { lhs, rhs in
            rank(lhs.element) != rank(rhs.element) ? rank(lhs.element) < rank(rhs.element) : lhs.offset < rhs.offset
        }.map(\.element)
    }

    /// Qué queda de un consumo. Recibe el primero aparte para que nunca falte quien mande.
    static func resolve(first: Candidate, others: [Candidate]) -> Resolved {
        let members = [first] + others
        let byMoney = ordered(members, by: moneyPriority)
        let moneyWinner = byMoney.first ?? first
        let money = Money(amount: moneyWinner.amount, currencyCode: moneyWinner.currencyCode)
        let original = byMoney.dropFirst().first { other in
            other.currencyCode != money.currencyCode
                || abs(abs(other.amount) - abs(money.amount)) > strongAmountTolerance + 1e-9
        }

        let byTime = ordered(members, by: timePriority)
        let timeWinner = byTime.first(where: \.hasExactTime) ?? byTime.first ?? first

        let byAccount = ordered(members, by: accountPriority)
        let accountWinner = byAccount.first { $0.accountID != nil && normalizedLast4($0.last4) != nil }
            ?? byAccount.first { $0.accountID != nil }
        let last4 = byAccount.lazy.compactMap { normalizedLast4($0.last4) }.first

        let merchantWinner = ordered(members, by: merchantPriority).first { member in
            !(member.merchant?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        }

        return Resolved(
            money: money,
            moneySource: moneyWinner.source,
            originalMoney: original.map { Money(amount: $0.amount, currencyCode: $0.currencyCode) },
            date: timeWinner.date,
            hasExactTime: timeWinner.hasExactTime,
            dateSource: timeWinner.source,
            accountID: accountWinner?.accountID,
            accountSource: accountWinner?.source,
            last4: last4,
            merchant: merchantWinner?.merchant,
            merchantSource: merchantWinner?.source,
            sources: members.map(\.source)
        )
    }

    /// Lo que llega comparado con un consumo: contra lo que manda en él, y con su fuente ocupada si ya la tiene.
    static func compare(
        _ candidate: Candidate, with consumption: Consumption, converter: Converter? = nil, calendar: Calendar = .current
    ) -> Comparison {
        let resolved = consumption.resolved
        let standIn = Candidate(
            id: consumption.id,
            source: resolved.moneySource,
            amount: resolved.money.amount,
            currencyCode: resolved.money.currencyCode,
            date: resolved.date,
            hasExactTime: resolved.hasExactTime,
            accountID: resolved.accountID,
            last4: resolved.last4,
            merchant: resolved.merchant
        )
        var comparison = compare(candidate, standIn, converter: converter, calendar: calendar)
        comparison.sources = consumption.canAbsorb(candidate) ? .strong : .none
        return comparison
    }

    // MARK: - Qué pasa al llegar

    nonisolated enum Decision: Equatable, Sendable {
        /// Coincidencia fuerte con un pendiente: se une solo (con «Separar» a un toque, lote 2).
        case join(consumptionID: UUID)
        /// Coincidencia dudosa con un pendiente: entra como pendiente propio y la Bandeja pregunta «¿Es el mismo gasto?».
        case askSameExpense(consumptionID: UUID)
        /// Se parece a algo ya guardado: «Ya registrado · Descartar / Guardar igual». Nunca se une solo.
        case alreadyRecorded(savedID: UUID, level: Level)
        /// Nada se le parece: pendiente nuevo.
        case new
    }

    /// Qué hacer con un borrador que llega, frente a los pendientes y a lo guardado de los últimos días. Lo fuerte gana a
    /// lo dudoso, y un pendiente a lo guardado del mismo nivel (el pendiente es el que se va a guardar). Entre varios del
    /// mismo nivel, el más cercano en el tiempo, luego en el importe, y luego el que llegó antes.
    static func decide(
        _ arriving: Candidate,
        pending: [Consumption],
        saved: [Candidate] = [],
        converter: Converter? = nil,
        calendar: Calendar = .current
    ) -> Decision {
        let pendingBest = best(pending.map { consumption in
            (consumption.id, compare(arriving, with: consumption, converter: converter, calendar: calendar))
        })
        let savedBest = best(saved.map { movement in
            (movement.id, compare(arriving, movement, converter: converter, calendar: calendar))
        })

        if let pendingBest, pendingBest.level == .strong { return .join(consumptionID: pendingBest.id) }
        if let savedBest, savedBest.level == .strong { return .alreadyRecorded(savedID: savedBest.id, level: .strong) }
        if let pendingBest, pendingBest.level == .doubtful { return .askSameExpense(consumptionID: pendingBest.id) }
        if let savedBest, savedBest.level == .doubtful { return .alreadyRecorded(savedID: savedBest.id, level: .doubtful) }
        return .new
    }

    private static func best(_ options: [(UUID, Comparison)]) -> (id: UUID, level: Level)? {
        var winner: (id: UUID, comparison: Comparison)?
        for (id, comparison) in options where comparison.level > .none {
            guard let incumbent = winner?.comparison else {
                winner = (id, comparison)
                continue
            }
            let better: Bool
            if comparison.level != incumbent.level {
                better = comparison.level > incumbent.level
            } else if comparison.timeGap != incumbent.timeGap {
                better = comparison.timeGap < incumbent.timeGap
            } else {
                better = comparison.amountGap < incumbent.amountGap
            }
            if better { winner = (id, comparison) }
        }
        return winner.map { ($0.id, $0.comparison.level) }
    }

    // MARK: - Una tanda

    nonisolated struct Question: Equatable, Sendable {
        nonisolated enum Kind: Equatable, Sendable {
            case sameExpense(consumptionID: UUID)
            case alreadyRecorded(savedID: UUID, level: Level)
        }

        let arrivalID: UUID
        let kind: Kind
    }

    nonisolated struct Outcome: Equatable, Sendable {
        var consumptions: [Consumption]
        var questions: [Question]
    }

    /// Lo que llega, en el orden en que llega, sobre los pendientes que ya había: cada uno se une, pregunta o queda solo.
    static func pair(
        _ arrivals: [Candidate],
        pending: [Consumption] = [],
        saved: [Candidate] = [],
        converter: Converter? = nil,
        calendar: Calendar = .current
    ) -> Outcome {
        var outcome = Outcome(consumptions: pending, questions: [])
        for arriving in arrivals {
            let decision = decide(arriving, pending: outcome.consumptions, saved: saved, converter: converter, calendar: calendar)
            switch decision {
            case .join(let consumptionID):
                if let index = outcome.consumptions.firstIndex(where: { $0.id == consumptionID }),
                   outcome.consumptions[index].absorb(arriving) {
                    continue
                }
                outcome.consumptions.append(Consumption(arriving))
            case .askSameExpense(let consumptionID):
                outcome.consumptions.append(Consumption(arriving))
                outcome.questions.append(Question(arrivalID: arriving.id, kind: .sameExpense(consumptionID: consumptionID)))
            case .alreadyRecorded(let savedID, let level):
                outcome.consumptions.append(Consumption(arriving))
                outcome.questions.append(
                    Question(arrivalID: arriving.id, kind: .alreadyRecorded(savedID: savedID, level: level))
                )
            case .new:
                outcome.consumptions.append(Consumption(arriving))
            }
        }
        return outcome
    }
}
