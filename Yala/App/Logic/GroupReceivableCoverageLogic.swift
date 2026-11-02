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
    }

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
    static func coverage(of events: [Event]) -> [UUID: Coverage] {
        struct Lot {
            let saleID: UUID?
            var remaining: Decimal
        }
        var result: [UUID: Coverage] = [:]
        var credits: [Lot] = []
        var debts: [Decimal] = []

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
                // Lo que debías se salda primero: esa parte de la venta queda cobrada en su propia fecha.
                while rest > epsilon, let first = debts.first {
                    let taken = min(rest, first)
                    if let saleID { collect(taken, of: saleID, by: event) }
                    rest -= taken
                    if first - taken > epsilon { debts[0] = first - taken } else { debts.removeFirst() }
                }
                if rest > epsilon { credits.append(Lot(saleID: saleID, remaining: rest)) }
            } else if event.amount < -epsilon {
                var rest = -event.amount
                // Lo que baja tu saldo cubre primero lo más antiguo, venta o gasto adelantado.
                while rest > epsilon, let first = credits.first {
                    let taken = min(rest, first.remaining)
                    if let saleID = first.saleID { collect(taken, of: saleID, by: event) }
                    rest -= taken
                    if first.remaining - taken > epsilon {
                        credits[0].remaining = first.remaining - taken
                    } else {
                        credits.removeFirst()
                    }
                }
                if rest > epsilon { debts.append(rest) }
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

    /// Los movimientos que mueven el saldo de `memberID` en `currencyCode`, con la misma cuenta que `GroupBalanceService`:
    /// el pagador suma el gasto entero y cada miembro resta su parte; quien paga una liquidación suma y quien la recibe
    /// resta. Solo cuentan las liquidaciones confirmadas y los gastos sin saldar, y cada id una vez.
    static func events(
        for memberID: String,
        currencyCode: String,
        expenses: [ExpenseInput],
        settlements: [SettlementInput]
    ) -> [Event] {
        var result: [Event] = []
        var seenExpenses: Set<UUID> = []
        for expense in expenses where expense.currencyCode == currencyCode && !expense.isSettled {
            guard seenExpenses.insert(expense.id).inserted else { continue }
            let myShare = expense.shares.filter { $0.memberID == memberID }.reduce(0) { $0 + $1.amount }
            let paid = expense.paidByMemberID == memberID ? expense.amount : 0
            let delta = decimal(paid) - decimal(myShare)
            guard delta != 0 else { continue }
            result.append(Event(
                id: expense.id, date: expense.date, amount: delta,
                isSale: expense.isSale && expense.paidByMemberID == memberID))
        }
        var seenSettlements: Set<UUID> = []
        for settlement in settlements
        where settlement.currencyCode == currencyCode && settlement.isConfirmed {
            guard seenSettlements.insert(settlement.id).inserted else { continue }
            var delta = Decimal(0)
            if settlement.fromMemberID == memberID { delta += decimal(settlement.amount) }
            if settlement.toMemberID == memberID { delta -= decimal(settlement.amount) }
            guard delta != 0 else { continue }
            result.append(Event(id: settlement.id, date: settlement.date, amount: delta, isSale: false))
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

    /// Un importe como `Double`, para escribirlo en un `TransactionItem`.
    static func double(_ value: Decimal) -> Double {
        NSDecimalNumber(decimal: value).doubleValue
    }
}
