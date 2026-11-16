//
//  GroupSplitLinesSummaryLogic.swift
//  Yala
//
//  Grupos B · la línea resumen bajo la tarjeta «Tu parte» (maqueta `opcion-b.html`, escenarios 1 y 2):
//  «Debes S/ 510.00 a Pía · Sip sube S/ 500.00». Dice qué no cambia (lo que debes a quien pagó) y qué cuentas suben por
//  las recargas. Lógica pura: la vista formatea.
//

import Foundation

enum GroupSplitLinesSummaryLogic {

    enum Part: Equatable {
        /// Lo que debes a quien pagó. Solo si pagó otro: partir no lo cambia.
        case owe(amount: Decimal, to: String)
        /// Lo que sube una cuenta por las recargas que van a ella (sumadas).
        case raises(account: String, amount: Decimal)
    }

    /// Las partes de la línea, en orden: primero la deuda, luego cada cuenta en el orden de su primera recarga.
    /// - Parameters:
    ///   - paidByOther: el gasto lo pagó otro miembro (Caso B). Si pagaste tú no debes nada por tu parte.
    ///   - payerName: el nombre de quien pagó; sin nombre no se dice a quién.
    ///   - accountNames: el nombre de cada cuenta por su `shortcutID`. Una recarga sin cuenta elegida, o a una cuenta que
    ///     ya no está, no se cuenta.
    static func parts(
        paidByOther: Bool,
        payerName: String?,
        share: Decimal,
        lines: [GroupSplitLinesRecipe.Line],
        accountNames: [UUID: String]
    ) -> [Part] {
        var result: [Part] = []
        if paidByOther, share > 0, let payerName, !payerName.isEmpty {
            result.append(.owe(amount: share, to: payerName))
        }
        var order: [UUID] = []
        var totals: [UUID: Decimal] = [:]
        for line in lines where line.kind == .transfer && line.amount > 0 {
            guard let id = line.destinationAccountID, accountNames[id] != nil else { continue }
            if totals[id] == nil { order.append(id) }
            totals[id, default: 0] += line.amount
        }
        for id in order {
            guard let name = accountNames[id], let amount = totals[id] else { continue }
            result.append(.raises(account: name, amount: amount))
        }
        return result
    }
}
