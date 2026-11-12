//
//  DevSeedTodayRecord.swift
//  Yala
//
//  Fixture de QA (`-uitest-seed-today-record`, card 30pv): un gasto «Bus» de 12 en la cuenta principal, fechado hace un
//  minuto sin salir de hoy y creado al final del arranque. Es el último registro creado, así que sale primero en
//  «Últimos registros» del Panel en «Este mes» sea el día que sea.
//
//  Por qué existe: `UsageModeUITests` usaba el «Bus» de la semilla `minimal`, que sale al azar en los últimos 7 días. El
//  1 y el 2 de noviembre ninguno cayó entre los cinco más recientes del mes en curso, y el control del Panel salía rojo
//  antes de probar nada.
//
//  Discriminante: «Empezar de cero» borra los registros; con el borrado roto, este «Bus» seguiría en el Panel.
//

#if DEBUG
import Foundation
import SwiftData

enum DevSeedTodayRecord {

    static var note: String { L10n.DevSeed.noteBus }
    static let amount: Double = -12

    /// Hace un minuto, sin salir de hoy (a las 00:00:30, las 00:00:00).
    static func date(now: Date = .now, calendar: Calendar = .current) -> Date {
        max(calendar.startOfDay(for: now), now.addingTimeInterval(-60))
    }

    @MainActor
    static func create(in context: ModelContext, now: Date = .now) {
        let accounts: [Account]
        let subcategories: [Subcategory]
        do {
            accounts = try context.fetch(FetchDescriptor<Account>(sortBy: [SortDescriptor(\.name)]))
            subcategories = try context.fetch(FetchDescriptor<Subcategory>())
        } catch {
            print("DevSeedTodayRecord: Error: \(error)")
            return
        }
        let preferred = CurrencyDefaults.currentPreferred
        guard let account = accounts.first(where: {
            !$0.isSystemAccount && !$0.excludeFromStatistics && $0.currencyCode == preferred
        }) ?? accounts.first(where: { !$0.isSystemAccount }) else { return }
        let sub = subcategories.first { $0.name == L10n.Subcategory.publicTransport }
        let date = date(now: now)
        let item = TransactionItem(
            date: date,
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
        // `createdAt` en el instante del fixture, no en `date`: corre tras la semilla, y lo que ésta siembra «hoy» lleva
        // `createdAt` de hace segundos. «Últimos registros» ordena por `createdAt`; con la fecha de hace un minuto, un
        // día con cinco registros sembrados lo dejaba fuera (lo cazó la review).
        item.createdAt = now
        context.insert(item)
        if account.currencyCode != preferred { item.recalculatePreferredCurrency(context: context) }
        do {
            try context.save()
        } catch {
            print("DevSeedTodayRecord: Error: \(error)")
        }
        SessionState.shared.incrementDataVersion()
    }
}
#endif
