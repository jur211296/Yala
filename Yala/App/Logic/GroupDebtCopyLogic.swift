//
//  GroupDebtCopyLogic.swift
//  Yala
//
//  Las frases con cifra de los avisos de administrar un grupo (auditoría UX 2.2 · L19-4, L19-10 y L19-11, decididas
//  por Jürgen el 18-oct): quitar a alguien que debe, salir con deuda y eliminar bloqueado dicen CUÁNTO y A QUIÉN.
//
//  Las relaciones de persona a persona salen de las deudas que ya enseña el grupo (`GroupDetailViewModel.debts`, que
//  respeta «simplificar» y «moneda única»): así el aviso dice lo mismo que Saldos. El bloqueo de eliminar sale de las
//  deudas simplificadas por divisa (`GroupRoundingResidueLogic.outstandingDebts`), que es lo que decide el bloqueo.
//

import Foundation

enum GroupDebtCopyLogic {

    /// Las deudas en las que participa `subjectID`.
    static func debts(involving subjectID: String, in debts: [Debt]) -> [Debt] {
        debts.filter { $0.fromMemberID == subjectID || $0.toMemberID == subjectID }
    }

    /// Una frase por PAREJA en la que participa `subjectID`, contada desde quien mira (`currentMemberID`), con las
    /// divisas juntas («S/ 110.00 + $ 40.00», como el resto de Grupos):
    ///
    /// - «Ana te debe S/ 80.00.» / «Debes S/ 80.00 a Ana.» cuando la otra parte es quien mira.
    /// - «Ana le debe S/ 30.00 a Beto.» cuando no.
    static func relationSentences(
        about subjectID: String,
        debts: [Debt],
        currentMemberID: String?,
        name: (String) -> String,
        money: (Double, String) -> String
    ) -> [String] {
        struct Pair: Hashable { let from: String; let to: String }
        var order: [Pair] = []
        var byPair: [Pair: [Debt]] = [:]
        for debt in Self.debts(involving: subjectID, in: debts) {
            let pair = Pair(from: debt.fromMemberID, to: debt.toMemberID)
            if byPair[pair] == nil { order.append(pair) }
            byPair[pair, default: []].append(debt)
        }
        return order.map { pair in
            let amount = amounts((byPair[pair] ?? []).map { ($0.amount, $0.currencyCode) }, money: money)
            if let me = currentMemberID, pair.to == me {
                return L10n.UXL19.owesYou(name(pair.from), amount)
            }
            if let me = currentMemberID, pair.from == me {
                return L10n.UXL19.youOwe(name(pair.to), amount)
            }
            return L10n.UXL19.owesOther(name(pair.from), amount, name(pair.to))
        }
    }

    /// «S/ 110.00 + $ 40.00»: las cifras de varias divisas como las escribe el resto de Grupos, en orden de divisa.
    static func amounts(_ values: [(Double, String)], money: (Double, String) -> String) -> String {
        var byCurrency: [String: Double] = [:]
        for (value, currency) in values { byCurrency[currency, default: 0] += value }
        return byCurrency.sorted { $0.key < $1.key }.map { money($0.value, $0.key) }.joined(separator: " + ")
    }

    /// Quién debe y cuánto, para el bloqueo de «Eliminar»: «Beto debe $ 30.00 y Carla debe S/ 20.00.».
    /// Suma por persona y divisa lo que debe en `debts`; sin deudas, `nil`.
    static func debtorsSentence(
        debts: [Debt],
        currentMemberID: String?,
        name: (String) -> String,
        money: (Double, String) -> String
    ) -> String? {
        var owed: [String: [String: Double]] = [:]
        for debt in debts where debt.amount > 0.01 {
            owed[debt.fromMemberID, default: [:]][debt.currencyCode, default: 0] += debt.amount
        }
        guard !owed.isEmpty else { return nil }
        // El orden de aparición: primero quien mira, después por nombre (estable entre recálculos).
        let ordered = owed.keys.sorted { lhs, rhs in
            if lhs == currentMemberID { return true }
            if rhs == currentMemberID { return false }
            let ln = name(lhs), rn = name(rhs)
            return ln == rn ? lhs < rhs : ln < rn
        }
        let parts: [String] = ordered.compactMap { memberID in
            guard let byCurrency = owed[memberID] else { return nil }
            let amounts = Self.amounts(byCurrency.map { ($0.value, $0.key) }, money: money)
            return memberID == currentMemberID
                ? L10n.UXL19.youOweNet(amounts)
                : L10n.UXL19.memberOwes(name(memberID), amounts)
        }
        return joined(parts) + "."
    }

    /// «S/ 190.00 y $ 46.67»: una lista con la conjunción del idioma de la app.
    static func joined(_ items: [String]) -> String {
        let formatter = ListFormatter()
        formatter.locale = AppLocale.current
        return formatter.string(from: items) ?? items.joined(separator: ", ")
    }
}
