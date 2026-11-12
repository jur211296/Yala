//
//  DevSeedUncategorizedExpense.swift
//  Yala
//
//  Fixture de QA para el trozo «Sin categoría» de los desgloses por categoría (`-uitest-seed-uncategorized-expense`,
//  decisión A de Jürgen del 2026-10-23): un gasto de 40 SIN categoría en la cuenta principal, fechado hoy.
//
//  En la app no se puede guardar un gasto sin categoría a mano (el formulario la pide); llegan por importación o por
//  grupos. Sin este fixture el «antes» y el «después» de la tarta no se podían ver en el simulador.
//
//  Discriminante: sin el trozo, la tarta y el ranking suman 40 menos que el gasto del mes que enseña el hero.
//

#if DEBUG
import Foundation
import SwiftData

enum DevSeedUncategorizedExpense {

    static let note = "Gasto sin categoría"
    static let amount = -40.0

    @MainActor
    static func create(in context: ModelContext, now: Date = .now) {
        let accounts: [Account]
        do {
            accounts = try context.fetch(FetchDescriptor<Account>(sortBy: [SortDescriptor(\.name)]))
        } catch {
            print("DevSeedUncategorizedExpense: Error: \(error)")
            return
        }
        let preferred = CurrencyDefaults.currentPreferred
        guard let account = accounts.first(where: {
            !$0.isSystemAccount && !$0.excludeFromStatistics && $0.currencyCode == preferred
        }) else { return }
        let item = TransactionItem(
            date: now,
            amount: amount,
            currencyCode: account.currencyCode,
            note: note,
            account: account,
            amountInPreferredCurrency: amount,
            preferredCurrencyCode: preferred,
            isExchangeRateProvisional: false
        )
        context.insert(item)
        do {
            try context.save()
        } catch {
            print("DevSeedUncategorizedExpense: Error: \(error)")
        }
        SessionState.shared.incrementDataVersion()
    }
}
#endif
