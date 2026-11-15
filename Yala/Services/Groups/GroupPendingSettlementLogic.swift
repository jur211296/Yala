//
//  GroupPendingSettlementLogic.swift
//  Yala
//
//  Grupos 2.3 · una deuda con un pago esperando confirmación (opción B; Jürgen, comentario en la card, 2026-11-13):
//  - La tarjeta de la deuda dice «Hay un pago de S/ X por confirmar», y «Todo» de «Saldar» ofrece solo lo que queda
//    fuera de ese pago. Si el pago cubre la deuda entera, no se ofrece saldarla otra vez.
//  - «Sí, lo recibí» avisa antes de confirmar si el pago ya no cabe en la deuda (otro pago la saldó): confirmarlo
//    dejaría pagado de más.
//
//  Los saldos siguen contando solo pagos confirmados (`GroupBalanceService`): esta lógica no los toca, solo lee las deudas
//  ya calculadas y los pagos pendientes.
//
//  Lógica pura: la vista solo la llama.
//

import Foundation

nonisolated enum GroupPendingSettlementLogic {

    /// Lo que la lógica necesita de un pago (`SplitSettlement`), sin depender de SwiftData.
    struct Payment: Equatable, Sendable {
        let fromMemberID: String
        let toMemberID: String
        let amount: Double
        let currencyCode: String
        let isConfirmed: Bool
    }

    /// Menos de medio céntimo no cuenta, como en «Saldar» (`SettlementSaldar23Logic.tolerance`).
    static let tolerance: Double = SettlementSaldar23Logic.tolerance

    // MARK: - La tarjeta de la deuda

    /// Lo que espera confirmación sobre una deuda: la misma pareja, en el mismo sentido y en la misma moneda.
    struct PendingOnDebt: Equatable, Sendable {
        /// La suma de los pagos sin confirmar.
        let pendingAmount: Double
        /// Cuántos pagos son («Hay un pago…» o «Hay pagos…»).
        let count: Int
        /// Lo que queda de la deuda fuera de esos pagos (nunca negativo).
        let remaining: Double
        /// Los pagos cubren la deuda entera: no se ofrece saldarla otra vez.
        var coversDebt: Bool { remaining < GroupPendingSettlementLogic.tolerance }
    }

    /// `nil` si la deuda no tiene ningún pago esperando.
    static func pending(on debt: Debt, payments: [Payment]) -> PendingOnDebt? {
        let matching = payments.filter {
            !$0.isConfirmed
                && $0.fromMemberID == debt.fromMemberID
                && $0.toMemberID == debt.toMemberID
                && $0.currencyCode == debt.currencyCode
                && $0.amount > 0
        }
        guard !matching.isEmpty else { return nil }
        let total = matching.reduce(0) { $0 + $1.amount }
        return PendingOnDebt(pendingAmount: total, count: matching.count, remaining: max(0, debt.amount - total))
    }

    /// La deuda que abre «Saldar»: su «Todo» es lo que queda fuera de los pagos por confirmar. `nil` si esos pagos ya la
    /// cubren (no se ofrece saldar dos veces lo mismo).
    static func debtToSettle(_ debt: Debt, payments: [Payment]) -> Debt? {
        guard let pending = pending(on: debt, payments: payments) else { return debt }
        guard !pending.coversDebt else { return nil }
        return Debt(fromMemberID: debt.fromMemberID, toMemberID: debt.toMemberID,
                    amount: pending.remaining, currencyCode: debt.currencyCode)
    }

    // MARK: - «Sí, lo recibí»

    /// Qué pasa si quien recibe confirma el pago.
    enum ConfirmCheck: Equatable, Sendable {
        /// Cabe en lo que se debe: se confirma sin preguntar.
        case fits
        /// La deuda ya no existe (otro pago la saldó): confirmarlo dejaría pagado de más todo el pago.
        case alreadySettled
        /// Solo quedaba `owed`: confirmarlo dejaría pagado de más la diferencia.
        case exceeds(owed: Double)
    }

    /// `pairDebts`: las deudas de cada par, sin juntar con «Menos pagos» (con «Menos pagos» apagado, son las del grupo).
    /// `debtsWereConverted`: las deudas vienen consolidadas a la moneda del grupo; ahí no se puede comparar con un pago en
    /// su moneda original, y no se avisa (mejor no preguntar que preguntar en falso).
    static func confirmCheck(_ payment: Payment, pairDebts: [Debt], debtsWereConverted: Bool) -> ConfirmCheck {
        guard !payment.isConfirmed, payment.amount > 0, !debtsWereConverted else { return .fits }
        let owed = pairDebts
            .filter {
                $0.fromMemberID == payment.fromMemberID && $0.toMemberID == payment.toMemberID
                    && $0.currencyCode == payment.currencyCode
            }
            .reduce(0) { $0 + $1.amount }
        if payment.amount - owed < tolerance { return .fits }
        return owed < tolerance ? .alreadySettled : .exceeds(owed: owed)
    }
}
