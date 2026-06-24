//
//  GroupBalanceRowGrouping.swift
//  Yala
//
//  Agrupa balances y deudas de un grupo para presentarlos en UNA fila por miembro
//  (o por par), con los montos de cada moneda en líneas dentro de la misma fila —
//  en vez de repetir el mismo nombre/par por cada moneda. Pure-logic, testeable.
//

import Foundation

enum GroupBalanceRowGrouping {

    struct MemberBalanceGroup: Identifiable {
        let memberID: String
        let displayName: String
        /// Saldo neto por moneda (orden estable por código). El signo lo da `net`.
        let amounts: [(currencyCode: String, net: Double)]
        var id: String { memberID }
    }

    struct DebtPairGroup: Identifiable {
        let fromMemberID: String
        let toMemberID: String
        /// Una `Debt` por moneda (preservada para liquidar cada moneda por separado).
        let debts: [Debt]
        var id: String { "\(fromMemberID)-\(toMemberID)" }
    }

    /// Agrupa balances por miembro: una entrada por miembro con sus montos por moneda.
    /// Monedas ordenadas por código; miembros por `displayName` (case-insensitive).
    static func groupByMember(_ balances: [MemberBalance]) -> [MemberBalanceGroup] {
        var order: [String] = []
        var byMember: [String: (name: String, amounts: [(String, Double)])] = [:]
        for balance in balances {
            if byMember[balance.memberID] == nil {
                byMember[balance.memberID] = (balance.displayName, [])
                order.append(balance.memberID)
            }
            byMember[balance.memberID]?.amounts.append((balance.currencyCode, balance.netBalance))
        }
        return order.map { id -> MemberBalanceGroup in
            let entry = byMember[id] ?? (id, [])
            let amounts = entry.amounts
                .sorted { $0.0 < $1.0 }
                .map { (currencyCode: $0.0, net: $0.1) }
            return MemberBalanceGroup(memberID: id, displayName: entry.name, amounts: amounts)
        }
        .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    /// Agrupa deudas por par `from→to`: una entrada por par con una `Debt` por moneda
    /// (orden de aparición de los pares; monedas ordenadas por código dentro del par).
    static func groupByPair(_ debts: [Debt]) -> [DebtPairGroup] {
        var order: [String] = []
        var byPair: [String: (from: String, to: String, debts: [Debt])] = [:]
        for debt in debts {
            let key = "\(debt.fromMemberID)-\(debt.toMemberID)"
            if byPair[key] == nil {
                byPair[key] = (debt.fromMemberID, debt.toMemberID, [])
                order.append(key)
            }
            byPair[key]?.debts.append(debt)
        }
        return order.map { key in
            let entry = byPair[key] ?? ("", "", [])
            return DebtPairGroup(
                fromMemberID: entry.from,
                toMemberID: entry.to,
                debts: entry.debts.sorted { $0.currencyCode < $1.currencyCode }
            )
        }
    }
}
