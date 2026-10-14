//
//  InboxBulkApproveSummaryLogic.swift
//  Yala
//
//  La línea bajo «N transacciones creadas» al aprobar varios borradores (UX 2.2 · L4-13, variante 2):
//  «S/ 60.50 en total · Cuenta Principal».
//

import Foundation

enum InboxBulkApproveSummaryLogic {

    /// Lo que se sabe de cada registro creado.
    struct Item: Equatable {
        let amount: Double
        let currencyCode: String
        let accountName: String?
    }

    struct Summary: Equatable {
        /// Suma de los importes, en positivo. `nil` si no hay UNA cifra honesta que dar.
        let total: Double?
        let currencyCode: String?
        /// La cuenta, solo si todos fueron a la misma.
        let accountName: String?

        var isEmpty: Bool { total == nil && accountName == nil }
    }

    /// Cada parte sale solo si es la misma para todos: un total que mezcle divisas o gastos con ingresos no dice
    /// cuánto se guardó, y una cuenta entre varias no es «la» cuenta. En ese caso esa parte se calla.
    static func summary(of items: [Item]) -> Summary {
        guard !items.isEmpty else { return Summary(total: nil, currencyCode: nil, accountName: nil) }

        let currencies = Set(items.map(\.currencyCode))
        let directions = Set(items.map { $0.amount < 0 })
        let total: Double?
        let currencyCode: String?
        if currencies.count == 1, directions.count == 1, let code = currencies.first {
            total = items.reduce(0) { $0 + abs($1.amount) }
            currencyCode = code
        } else {
            total = nil
            currencyCode = nil
        }

        let accounts = Set(items.map(\.accountName))
        let accountName: String?
        if accounts.count == 1, let only = accounts.first, let name = only, !name.isEmpty {
            accountName = name
        } else {
            accountName = nil
        }

        return Summary(total: total, currencyCode: currencyCode, accountName: accountName)
    }
}
