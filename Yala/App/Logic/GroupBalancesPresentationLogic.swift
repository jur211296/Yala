//
//  GroupBalancesPresentationLogic.swift
//  Yala
//
//  Auditoría UX 2.2 · L13-1 y L13-2 (decisiones de Jürgen del 15-oct). Qué enseña la pestaña de saldos de un grupo:
//  arriba lo tuyo (cuánto te deben o debes), los pagos que te toca confirmar, y las deudas para quedar a mano con las
//  tuyas primero y con su botón; las de otros, sin botón.
//
//  Pura: no lee SwiftData ni pinta nada.
//

import Foundation

enum GroupBalancesPresentationLogic {

    /// Por debajo de esto un saldo es cero: los repartos dejan céntimos sueltos.
    static let epsilon = 0.005

    struct CurrencyAmount: Equatable {
        let currencyCode: String
        /// Siempre positivo: el sentido lo dice en qué lista está.
        let amount: Double
    }

    /// Tu saldo en el grupo, por moneda. Una persona puede deber en una moneda y que le deban en otra.
    struct Summary: Equatable {
        let owedToMe: [CurrencyAmount]
        let iOwe: [CurrencyAmount]

        enum Kind: Equatable {
            /// Te deben (y quizá debes algo en otra moneda: `iOwe` no vacío).
            case owedToMe
            case iOwe
            case settled
        }

        var kind: Kind {
            if !owedToMe.isEmpty { return .owedToMe }
            if !iOwe.isEmpty { return .iOwe }
            return .settled
        }
    }

    /// `nil` sin usuario resuelto en el grupo: no hay «lo tuyo» que contar.
    ///
    /// Sale de las DEUDAS que la pantalla enseña debajo, no del saldo neto por miembro: los dos se redondean por
    /// separado y diferían en un céntimo («$ 46.66» arriba, «$ 40.00 + $ 6.67» debajo). La tarjeta del grupo en la
    /// lista también suma deudas, así que las tres cifras coinciden.
    static func summary(debts: [Debt], currentUserMemberID: String?) -> Summary? {
        guard let me = currentUserMemberID else { return nil }
        var net: [String: Double] = [:]
        for debt in debts {
            if debt.toMemberID == me { net[debt.currencyCode, default: 0] += debt.amount }
            if debt.fromMemberID == me { net[debt.currencyCode, default: 0] -= debt.amount }
        }
        let sorted = net.sorted { $0.key < $1.key }
        let owed = sorted.filter { $0.value > epsilon }
            .map { CurrencyAmount(currencyCode: $0.key, amount: $0.value) }
        let owe = sorted.filter { $0.value < -epsilon }
            .map { CurrencyAmount(currencyCode: $0.key, amount: -$0.value) }
        return Summary(owedToMe: owed, iOwe: owe)
    }

    /// Una deuda entre dos personas, con una línea por moneda.
    struct DebtCard: Identifiable, Equatable {
        let fromMemberID: String
        let toMemberID: String
        let debts: [Debt]
        /// La debes tú o te la deben a ti: lleva «Saldar».
        let involvesMe: Bool
        /// Te la deben a ti (los importes van en el color de «te deben»).
        let isOwedToMe: Bool
        var id: String { "\(fromMemberID)-\(toMemberID)" }
    }

    /// Las tuyas primero, en el orden de siempre; después las de los demás.
    static func debtCards(debts: [Debt], currentUserMemberID: String?) -> [DebtCard] {
        let cards = GroupBalanceRowGrouping.groupByPair(debts).map { pair in
            DebtCard(
                fromMemberID: pair.fromMemberID,
                toMemberID: pair.toMemberID,
                debts: pair.debts,
                involvesMe: currentUserMemberID.map { pair.fromMemberID == $0 || pair.toMemberID == $0 } ?? false,
                isOwedToMe: currentUserMemberID.map { pair.toMemberID == $0 } ?? false
            )
        }
        return cards.filter(\.involvesMe) + cards.filter { !$0.involvesMe }
    }

    /// Un pago que alguien apuntó y que te toca confirmar a ti, que eres quien lo recibe. Solo esos suben a la tarjeta
    /// de «¿Lo recibiste?»; los pendientes de otros esperan a otra persona y se quedan en la lista.
    static func needsMyConfirmation(isConfirmed: Bool, toMemberID: String, currentUserMemberID: String?) -> Bool {
        guard let me = currentUserMemberID else { return false }
        return !isConfirmed && toMemberID == me
    }
}
