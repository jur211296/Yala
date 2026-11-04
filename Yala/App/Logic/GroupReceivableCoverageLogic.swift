//
//  GroupReceivableCoverageLogic.swift
//  Yala
//
//  Grupos B · card 9 (versión final acordada el 2026-11-01, `docs/disenos/grupos-tu-parte-en-lineas/README.md`, «El ingreso
//  cuenta el día que te pagan»): qué parte de cada venta por cobrar ya está cobrada, y en qué fecha.
//
//  La regla es TU SALDO en el grupo, lo más antiguo primero. Cada movimiento del grupo que te toca, en la divisa de la venta,
//  sube o baja tu saldo:
//    · suben: lo que pagaste por otros (gastos adelantados), tus ventas y lo que pagas tú en una liquidación;
//    · bajan: tu parte de lo que pagó otro y lo que te pagan en una liquidación.
//  Lo que sube queda como un LOTE a favor con su fecha. Lo que baja consume primero el lote más antiguo, sea venta o gasto
//  adelantado; si consume una venta, esa parte queda cobrada con la fecha del movimiento que bajó el saldo. Lo que no es
//  venta es una devolución y no cuenta como ingreso, igual que hoy.
//
//  De ahí salen los cuatro casos de la página (escenario 6): un pago parcial cubre primero la cena de enero; una venta
//  cubierta a medias deja el resto por cobrar; una deuda cruzada que deja el saldo en cero cubre la venta entera; y con
//  «simplificar deudas» cuenta tu saldo, no quién paga a quién (una liquidación entre otros dos no te mueve el saldo).
//
//  Si debías algo cuando llega la venta, la venta lo salda primero: esa parte queda cobrada en la fecha de la venta (te
//  pagaron por adelantado, con lo que el otro puso por ti). Sin eso, un saldo en cero dejaría la venta por cobrar.
//
//  Pura y determinista: dos aparatos con el mismo grupo dan el mismo reparto (orden por fecha y, a igualdad, por id).
//
//  ENTRE DIVISAS (decisión A de Jürgen, 2026-11-02, card «una venta en otra divisa no se cobra con un pago en la moneda
//  del grupo»). Con «deudas en una sola moneda» el grupo neta todas las divisas, y un pago en la moneda del grupo puede
//  cubrir una venta en otra. Entonces el reparto corre con todas las divisas juntas (`coverage(of:convert:)`): lo que
//  baja tu saldo cubre lo más antiguo de CUALQUIER divisa, convertido con el tipo de cambio del día del movimiento que
//  cubre (el pago) y fijo desde ahí: repasar otro día no lo recalcula. Sin la opción, cada divisa va por su lado.
//

import Foundation

nonisolated enum GroupReceivableCoverageLogic {

    /// Un movimiento del grupo visto desde tu saldo, en una sola divisa.
    struct Event: Equatable, Sendable {
        /// El gasto o la liquidación. Es también la identidad de la parte cobrada que produce.
        let id: UUID
        let date: Date
        /// Con signo: `+` sube tu saldo (te deben más), `−` lo baja.
        let amount: Decimal
        /// Una venta tuya (solo cuenta con `amount > 0`).
        let isSale: Bool
        /// La divisa del movimiento. Sin conversión entre divisas, un movimiento solo cubre o salda los de su divisa.
        var currencyCode: String = ""
    }

    /// Convierte `amount` de `from` a `to` con el tipo de cambio de `date` (el día del movimiento que cubre).
    typealias Convert = (_ amount: Decimal, _ from: String, _ to: String, _ date: Date) -> Decimal

    /// Una parte cobrada de una venta: cuánto, cuándo y qué movimiento la cubrió.
    struct Portion: Equatable, Sendable {
        let eventID: UUID
        let date: Date
        let amount: Decimal
    }

    /// El estado de una venta: lo que te debían, lo cobrado (por movimiento, en orden) y lo que queda.
    struct Coverage: Equatable, Sendable {
        let saleID: UUID
        let owed: Decimal
        var collected: [Portion]
        var remaining: Decimal { owed - collected.reduce(Decimal(0)) { $0 + $1.amount } }
    }

    /// Por debajo de un céntimo no queda nada por cobrar ni nada cobrado.
    static let epsilon = Decimal(string: "0.005", locale: Locale(identifier: "en_US_POSIX")) ?? 0

    /// El resto que el grupo ya da por saldado: `GroupBalanceService` no ofrece deudas de 0,01 o menos. Un resto así, con la
    /// venta ya cobrada en parte, va con la última parte cobrada: si no, quedaría «por cobrar» un céntimo que nadie va a pagar.
    static let settledResidue = Decimal(string: "0.01", locale: Locale(identifier: "en_US_POSIX")) ?? 0

    /// El reparto de lo cobrado de cada venta de `events`.
    ///
    /// - Parameter convert: con él, un movimiento cubre o salda también los de otra divisa, convertidos con el tipo de
    ///   cambio del día del movimiento que cubre. Sin él (el caso de siempre), solo los de su divisa.
    static func coverage(of events: [Event], convert: Convert? = nil) -> [UUID: Coverage] {
        struct Lot {
            let saleID: UUID?
            let currencyCode: String
            var remaining: Decimal
        }
        var result: [UUID: Coverage] = [:]
        var credits: [Lot] = []
        var debts: [Lot] = []

        /// El siguiente lote que `event` puede tomar: el más antiguo de su divisa o, con conversión, de cualquiera.
        func nextIndex(in lots: [Lot], for event: Event) -> Int? {
            if convert != nil { return lots.isEmpty ? nil : 0 }
            return lots.firstIndex { $0.currencyCode == event.currencyCode }
        }

        /// Toma de `lot` hasta `rest` (en la divisa del evento). Devuelve lo tomado en la divisa del LOTE y lo que eso
        /// gasta de `rest`. La conversión es la del día del evento; si se lleva el lote entero, lo gastado se convierte
        /// de vuelta para que el resto siga en la divisa del evento.
        ///
        /// Un pago entre divisas va redondeado al céntimo de SU divisa (el «Sugerido»), y ese céntimo, convertido, puede
        /// valer más de un céntimo del lote (S/ 0,04 por cada dólar de 3,7; ¥ 1,5 con un tipo de 150). Por eso el lote se
        /// da por cubierto si falta menos de lo que vale un céntimo del pago, y lo que sobra del pago por ese redondeo
        /// (un céntimo o menos) no queda como deuda: el grupo ya no ofrece deudas de 0,01 o menos.
        func take(_ rest: Decimal, from lot: Lot, by event: Event) -> (inLot: Decimal, spent: Decimal) {
            guard lot.currencyCode != event.currencyCode, let convert else {
                let taken = min(rest, lot.remaining)
                return (taken, taken)
            }
            let restInLot = rounded(convert(rest, event.currencyCode, lot.currencyCode, event.date))
            let oneCentInLot = convert(settledResidue, event.currencyCode, lot.currencyCode, event.date)
            if restInLot + max(epsilon, oneCentInLot) >= lot.remaining {
                let back = rounded(convert(lot.remaining, lot.currencyCode, event.currencyCode, event.date))
                let spent = rest - back <= settledResidue ? rest : back
                return (lot.remaining, spent)
            }
            return (restInLot, rest)
        }

        func collect(_ amount: Decimal, of saleID: UUID, by event: Event) {
            guard amount > epsilon else { return }
            guard var coverage = result[saleID] else { return }
            if let last = coverage.collected.last, last.eventID == event.id {
                coverage.collected[coverage.collected.count - 1] = Portion(
                    eventID: event.id, date: event.date, amount: last.amount + amount)
            } else {
                coverage.collected.append(Portion(eventID: event.id, date: event.date, amount: amount))
            }
            result[saleID] = coverage
        }

        for event in ordered(events) {
            if event.amount > epsilon {
                var rest = event.amount
                let saleID: UUID? = event.isSale ? event.id : nil
                if let saleID { result[saleID] = Coverage(saleID: saleID, owed: event.amount, collected: []) }
                // Lo que debías se salda primero: esa parte de la venta queda cobrada en su propia fecha. Lo cobrado va en
                // la divisa de la venta, que es la del evento: `spent`.
                while rest > epsilon, let index = nextIndex(in: debts, for: event) {
                    let debt = debts[index]
                    let (inLot, spent) = take(rest, from: debt, by: event)
                    if let saleID { collect(spent, of: saleID, by: event) }
                    rest -= spent
                    if debt.remaining - inLot > epsilon { debts[index].remaining = debt.remaining - inLot } else {
                        debts.remove(at: index)
                    }
                    if inLot <= 0 && spent <= 0 { break }
                }
                if rest > epsilon {
                    credits.append(Lot(saleID: saleID, currencyCode: event.currencyCode, remaining: rest))
                }
            } else if event.amount < -epsilon {
                var rest = -event.amount
                // Lo que baja tu saldo cubre primero lo más antiguo, venta o gasto adelantado. Lo cobrado va en la divisa
                // de la venta, que es la del lote: `inLot`.
                while rest > epsilon, let index = nextIndex(in: credits, for: event) {
                    let credit = credits[index]
                    let (inLot, spent) = take(rest, from: credit, by: event)
                    if let saleID = credit.saleID { collect(inLot, of: saleID, by: event) }
                    rest -= spent
                    if credit.remaining - inLot > epsilon {
                        credits[index].remaining = credit.remaining - inLot
                    } else {
                        credits.remove(at: index)
                    }
                    if inLot <= 0 && spent <= 0 { break }
                }
                if rest > epsilon {
                    debts.append(Lot(saleID: nil, currencyCode: event.currencyCode, remaining: rest))
                }
            }
        }
        // El resto que el grupo ya da por saldado va con la última parte cobrada (`settledResidue`).
        for (saleID, coverage) in result {
            let remaining = coverage.remaining
            guard remaining > 0, remaining <= settledResidue, let last = coverage.collected.last else { continue }
            var folded = coverage
            folded.collected[folded.collected.count - 1] = Portion(
                eventID: last.eventID, date: last.date, amount: last.amount + remaining)
            result[saleID] = folded
        }
        return result
    }

    /// Lo más antiguo primero; a igualdad de fecha, por id (el mismo orden en todos los aparatos).
    static func ordered(_ events: [Event]) -> [Event] {
        events.sorted {
            if $0.date != $1.date { return $0.date < $1.date }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    // MARK: - Del grupo a los movimientos

    /// Un gasto del grupo, en valores planos.
    struct ExpenseInput: Equatable, Sendable {
        let id: UUID
        let date: Date
        let amount: Double
        let currencyCode: String
        let paidByMemberID: String
        /// Los gastos marcados como saldados no cuentan en los saldos del grupo (`GroupBalanceService`).
        let isSettled: Bool
        /// Lo que le toca a cada miembro.
        let shares: [Share]
        /// Lo pagaste tú con una categoría de ingreso (`GroupSaleBridgeLogic.isSale`).
        let isSale: Bool
    }

    /// La parte de un miembro en un gasto.
    struct Share: Equatable, Sendable {
        let memberID: String
        let amount: Double
    }

    /// Una liquidación del grupo, en valores planos.
    struct SettlementInput: Equatable, Sendable {
        let id: UUID
        let date: Date
        let amount: Double
        let currencyCode: String
        let fromMemberID: String
        let toMemberID: String
        let isConfirmed: Bool
    }

    /// Los movimientos que mueven el saldo de `memberID` en `currencyCode` (con `nil`, en todas las divisas), con la misma
    /// cuenta que `GroupBalanceService`: el pagador suma el gasto entero y cada miembro resta su parte; quien paga una
    /// liquidación suma y quien la recibe resta. Solo cuentan las liquidaciones confirmadas y los gastos sin saldar, y
    /// cada id una vez.
    static func events(
        for memberID: String,
        currencyCode: String?,
        expenses: [ExpenseInput],
        settlements: [SettlementInput]
    ) -> [Event] {
        var result: [Event] = []
        var seenExpenses: Set<UUID> = []
        for expense in expenses
        where (currencyCode == nil || expense.currencyCode == currencyCode) && !expense.isSettled {
            guard seenExpenses.insert(expense.id).inserted else { continue }
            let myShare = expense.shares.filter { $0.memberID == memberID }.reduce(0) { $0 + $1.amount }
            let paid = expense.paidByMemberID == memberID ? expense.amount : 0
            let delta = decimal(paid) - decimal(myShare)
            guard delta != 0 else { continue }
            result.append(Event(
                id: expense.id, date: expense.date, amount: delta,
                isSale: expense.isSale && expense.paidByMemberID == memberID, currencyCode: expense.currencyCode))
        }
        var seenSettlements: Set<UUID> = []
        for settlement in settlements
        where (currencyCode == nil || settlement.currencyCode == currencyCode) && settlement.isConfirmed {
            guard seenSettlements.insert(settlement.id).inserted else { continue }
            var delta = Decimal(0)
            if settlement.fromMemberID == memberID { delta += decimal(settlement.amount) }
            if settlement.toMemberID == memberID { delta -= decimal(settlement.amount) }
            guard delta != 0 else { continue }
            result.append(Event(
                id: settlement.id, date: settlement.date, amount: delta, isSale: false,
                currencyCode: settlement.currencyCode))
        }
        return result
    }

    /// Un importe del grupo como `Decimal` redondeado al céntimo: `Decimal(Double)` arrastra la cola binaria.
    static func decimal(_ value: Double) -> Decimal {
        // Por su texto, como `GroupSplitLinesBridgeLogic.decimal`.
        var exact = Decimal(string: String(value), locale: Locale(identifier: "en_US_POSIX")) ?? Decimal(value)
        var rounded = Decimal()
        NSDecimalRound(&rounded, &exact, 2, .plain)
        return rounded
    }

    /// Un importe convertido, al céntimo.
    static func rounded(_ value: Decimal) -> Decimal {
        var exact = value
        var result = Decimal()
        NSDecimalRound(&result, &exact, 2, .plain)
        return result
    }

    /// Un importe como `Double`, para escribirlo en un `TransactionItem`.
    static func double(_ value: Decimal) -> Double {
        NSDecimalNumber(decimal: value).doubleValue
    }
}
