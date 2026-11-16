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

    // MARK: - Mejoras necesarias 2.3 · lote 06

    /// Lo que te deben y lo que debes SIN netear, con las sumas de las tarjetas de debajo.
    struct CrossDebts: Equatable {
        let owedToMe: [CurrencyAmount]
        let iOwe: [CurrencyAmount]
    }

    /// `nil` salvo que en alguna moneda debas y te deban a la vez, que es lo que el neto esconde: con «Menos pagos»
    /// apagado las deudas van por pareja, y «debes S/ 40 a Ana» y «Beto te debe S/ 30» dan una cifra de «debes S/ 10»
    /// cuya frase decía «Nadie te debe nada». Con «Menos pagos» encendido no pasa nunca (cada persona solo paga o cobra).
    static func crossDebts(debts: [Debt], currentUserMemberID: String?) -> CrossDebts? {
        guard let me = currentUserMemberID else { return nil }
        var owed: [String: Double] = [:]
        var owe: [String: Double] = [:]
        for debt in debts {
            if debt.toMemberID == me { owed[debt.currencyCode, default: 0] += debt.amount }
            if debt.fromMemberID == me { owe[debt.currencyCode, default: 0] += debt.amount }
        }
        let crosses = owed.contains { code, amount in amount > epsilon && (owe[code] ?? 0) > epsilon }
        guard crosses else { return nil }
        func amounts(_ byCurrency: [String: Double]) -> [CurrencyAmount] {
            byCurrency.filter { $0.value > epsilon }.sorted { $0.key < $1.key }
                .map { CurrencyAmount(currencyCode: $0.key, amount: $0.value) }
        }
        return CrossDebts(owedToMe: amounts(owed), iOwe: amounts(owe))
    }

    /// Qué frase va bajo la cifra de un grupo.
    enum SummarySentence: Equatable {
        /// «Te deben X y tú debes Y.»: debes y te deben en la misma moneda.
        case both(owedToMe: [CurrencyAmount], iOwe: [CurrencyAmount])
        /// «Y tú debes Y.»: te deben en una moneda y debes en otra.
        case alsoOwe([CurrencyAmount])
        /// «Tú no le debes nada a nadie.»
        case owedToMeOnly
        /// «Nadie te debe nada.»
        case iOweOnly
        /// «Nadie te debe y tú no debes nada.»
        case settled
    }

    /// La frase tiene que ser verdad con «Menos pagos» encendido y apagado: con un cruce, dice las dos sumas.
    static func summarySentence(summary: Summary, cross: CrossDebts?) -> SummarySentence {
        if let cross { return .both(owedToMe: cross.owedToMe, iOwe: cross.iOwe) }
        switch summary.kind {
        case .owedToMe: return summary.iOwe.isEmpty ? .owedToMeOnly : .alsoOwe(summary.iOwe)
        case .iOwe: return .iOweOnly
        case .settled: return .settled
        }
    }

    /// El rótulo gris sobre la cifra de un grupo.
    enum GroupCaption: Equatable {
        case owedToMe
        case iOwe
        /// «Estás a mano en este grupo»: nadie te debe y no debes nada.
        case settled
        /// El neto es cero, pero debes y te deben («Menos pagos» apagado): «Estás a mano» encima de «Tú pagas a Ana»
        /// se contradecía.
        case evenWithDebts
    }

    static func groupCaption(summary: Summary, cross: CrossDebts?) -> GroupCaption {
        switch summary.kind {
        case .owedToMe: return .owedToMe
        case .iOwe: return .iOwe
        case .settled: return cross == nil ? .settled : .evenWithDebts
        }
    }

    /// Quién paga a quién contado desde ti: «Tú pagas a Ana», «Beto te paga» o «Beto paga a Ana».
    enum PairRole: Equatable {
        case youPay
        case paysYou
        case others
    }

    static func pairRole(fromMemberID: String, toMemberID: String, currentUserMemberID: String?) -> PairRole {
        guard let me = currentUserMemberID else { return .others }
        if fromMemberID == me { return .youPay }
        if toMemberID == me { return .paysYou }
        return .others
    }

    /// El vacío de Saldos: un grupo sin nada apuntado no está «al día», está sin gastos.
    enum EmptyState: Equatable {
        case noEntries
        case settled
    }

    static func emptyState(hasExpenses: Bool, hasSettlements: Bool) -> EmptyState {
        hasExpenses || hasSettlements ? .settled : .noEntries
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
