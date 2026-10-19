//
//  DevSeedFutureMovement.swift
//  Yala
//
//  Fixture de QA para el saldo de hoy con un movimiento de fecha futura (`-uitest-seed-future-movement`, decisión A de
//  Jürgen del 2026-10-18): un gasto de 250 en la cuenta principal, fechado MAÑANA a las 00:00, la hora que guarda el
//  selector de fecha.
//
//  En la app no se puede apuntar un gasto de mañana a mano (el formulario topa la fecha en hoy); llegan por otros
//  caminos (una liquidación de grupo, otro dispositivo en otro huso). Sin este fixture el «antes» y el «después» del
//  saldo no se podían ver en el simulador.
//
//  Discriminante: con el corte quitado, la cifra del saldo y la tarjeta de la cuenta bajan 250 respecto a la curva,
//  que acaba hoy. Con el corte, las tres dicen lo mismo y el gasto solo se ve en la lista de registros.
//

#if DEBUG
import Foundation
import SwiftData

enum DevSeedFutureMovement {

    static let note = "Pago de mañana"

    @MainActor
    static func create(in context: ModelContext, now: Date = .now) {
        let accounts: [Account]
        do {
            accounts = try context.fetch(FetchDescriptor<Account>(sortBy: [SortDescriptor(\.name)]))
        } catch {
            print("DevSeedFutureMovement: Error: \(error)")
            return
        }
        let preferred = CurrencyDefaults.currentPreferred
        guard let account = accounts.first(where: {
            !$0.isSystemAccount && !$0.excludeFromStatistics && $0.currencyCode == preferred
        }) ?? accounts.first(where: { !$0.isSystemAccount }) else { return }
        let calendar = Calendar.current
        let tomorrow = calendar.dateInterval(of: .day, for: now)?.end
            ?? calendar.startOfDay(for: now).addingTimeInterval(86_400)
        let item = TransactionItem(
            date: tomorrow,
            amount: -250,
            currencyCode: account.currencyCode,
            note: note,
            account: account,
            amountInPreferredCurrency: account.currencyCode == preferred ? -250 : 0,
            preferredCurrencyCode: preferred,
            // Misma divisa: el importe es exacto. En otra, `recalculatePreferredCurrency` lo reescribe y decide el flag.
            isExchangeRateProvisional: false
        )
        context.insert(item)
        if account.currencyCode != preferred { item.recalculatePreferredCurrency(context: context) }
        do {
            try context.save()
        } catch {
            print("DevSeedFutureMovement: Error: \(error)")
        }
        SessionState.shared.incrementDataVersion()
    }
}
#endif
