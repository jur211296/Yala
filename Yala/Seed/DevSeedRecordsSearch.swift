//
//  DevSeedRecordsSearch.swift
//  Yala
//
//  Fixture de QA (`-uitest-seed-records-search`, decisión 14 de 2.3): un gasto «Almuerzo de trabajo» de 45,90 en la cuenta
//  principal, hace un minuto sin salir de hoy, para buscarlo en Registros por su importe.
//
//  Discriminante: la nota no tiene cifras, así que «45,90» solo lo encuentra la búsqueda por importe. Sin ella, el campo
//  no encuentra nada (o, sin el campo, no hay dónde escribir).
//

#if DEBUG
import Foundation
import SwiftData

enum DevSeedRecordsSearch {

    static let note = "Almuerzo de trabajo"
    static let amount: Double = -45.90

    @MainActor
    static func create(in context: ModelContext, now: Date = .now) {
        let accounts: [Account]
        let subcategories: [Subcategory]
        do {
            accounts = try context.fetch(FetchDescriptor<Account>(sortBy: [SortDescriptor(\.name)]))
            subcategories = try context.fetch(FetchDescriptor<Subcategory>())
        } catch {
            print("DevSeedRecordsSearch: Error: \(error)")
            return
        }
        let preferred = CurrencyDefaults.currentPreferred
        guard let account = accounts.first(where: {
            !$0.isSystemAccount && !$0.excludeFromStatistics && $0.currencyCode == preferred
        }) ?? accounts.first(where: { !$0.isSystemAccount }) else { return }
        let sub = subcategories.first { $0.name == L10n.Subcategory.restaurants }
        let item = TransactionItem(
            date: DevSeedTodayRecord.date(now: now),
            amount: amount,
            currencyCode: account.currencyCode,
            note: note,
            category: sub?.category,
            subcategory: sub,
            account: account,
            amountInPreferredCurrency: account.currencyCode == preferred ? amount : 0,
            preferredCurrencyCode: preferred,
            isExchangeRateProvisional: false
        )
        item.createdAt = now
        context.insert(item)
        if account.currencyCode != preferred { item.recalculatePreferredCurrency(context: context) }
        do {
            try context.save()
        } catch {
            print("DevSeedRecordsSearch: Error: \(error)")
        }
        SessionState.shared.incrementDataVersion()
    }
}
#endif
