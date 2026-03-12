//
//  DevSeedAccounts.swift
//  Yala
//
//  Creates 2 accounts for dev seed data.
//

#if DEBUG
import Foundation
import SwiftData

struct DevSeedAccounts {

    struct Result {
        let cuentaPrincipal: Account
        let ahorrosUSD: Account
    }

    @MainActor
    static func create(in context: ModelContext) -> Result {
        let principal = Account(
            name: "Cuenta Principal",
            currencyCode: "PEN",
            colorHex: "#6366F1",
            iconName: "creditcard.fill",
            type: AccountType.checking.rawValue
        )
        context.insert(principal)

        let ahorros = Account(
            name: "Ahorros USD",
            currencyCode: "USD",
            colorHex: "#6366F1",
            iconName: "banknote.fill",
            type: AccountType.savings.rawValue
        )
        context.insert(ahorros)

        return Result(cuentaPrincipal: principal, ahorrosUSD: ahorros)
    }
}
#endif
