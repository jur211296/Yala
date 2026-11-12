//
//  DevSeedTransactionForm.swift
//  Yala
//
//  Semillas del formulario de registro (lote decidido 2.2 · 02): una sola cuenta (L2-1, L2-6) y favoritos (L2-13, L2-14).
//

#if DEBUG
import Foundation
import SwiftData

struct DevSeedTransactionForm {

    /// Como queda un onboarding de una sola cuenta: «Cuenta Principal» en soles.
    @MainActor
    static func createOneAccount(in context: ModelContext) {
        let principal = Account(
            name: L10n.DevSeed.accountMain,
            currencyCode: "PEN",
            colorHex: "#6366F1",
            iconName: "creditcard.fill",
            type: AccountType.checking.rawValue
        )
        context.insert(principal)
    }

    /// Las dos cuentas de siempre y cuatro favoritos en el orden de Ajustes › Favoritos: «Café» (gasto de 12 con su
    /// categoría), «Sueldo» (ingreso), «Ahorro del mes» (transferencia con origen y destino) y «Transferencia vieja»
    /// (transferencia sin destino, como las guardadas antes de 2.2).
    @MainActor
    static func createWithFavorites(subcategoryLookup: [String: Subcategory], in context: ModelContext) {
        let accounts = DevSeedAccounts.create(in: context)
        let restaurants = subcategoryLookup[L10n.Subcategory.restaurants]
        let salary = subcategoryLookup[L10n.Subcategory.salary]

        let favorites = [
            FavoritePayment(
                name: "Café", transactionType: TransactionType.expense.rawValue, amount: 12, note: "Café",
                account: accounts.cuentaPrincipal, subcategory: restaurants, currencyCode: "PEN", displayOrder: 0),
            FavoritePayment(
                name: "Sueldo", transactionType: TransactionType.income.rawValue, amount: 3000, note: "Sueldo",
                account: accounts.cuentaPrincipal, subcategory: salary, currencyCode: "PEN", displayOrder: 1),
            FavoritePayment(
                name: "Ahorro del mes", transactionType: TransactionType.transfer.rawValue, amount: 200,
                account: accounts.cuentaPrincipal, destinationAccount: accounts.ahorrosUSD, currencyCode: "PEN",
                displayOrder: 2),
            FavoritePayment(
                name: "Transferencia vieja", transactionType: TransactionType.transfer.rawValue, amount: 50,
                account: accounts.cuentaPrincipal, currencyCode: "PEN", displayOrder: 3),
        ]
        for favorite in favorites { context.insert(favorite) }
    }
}
#endif
