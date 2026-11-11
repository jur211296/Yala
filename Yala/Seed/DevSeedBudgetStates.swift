//
//  DevSeedBudgetStates.swift
//  Yala
//
//  Fixture de QA (`-uitest-seed-budget-states`, lote 2.3 · Planificación, decisión 23): cuatro presupuestos mensuales de
//  1.000, cada uno filtrado por su propia etiqueta para que lo gastado sea exacto el día que sea. Los nombres son el
//  porcentaje, no la palabra, para que un test que busca «En el límite» no la encuentre en el nombre:
//
//  - «QA 30»: 300 antes de hoy y 5 hoy (30,5 %). Sin palabra; el cupo del día sale en tono neutro.
//  - «QA 90»: 800 antes de hoy y 100 hoy (90 %). «En el límite», y lo de hoy pasa del cupo del día con tres
//    días o más por delante (el cupo es 200 entre los días que faltan).
//  - «QA 100»: 1.000 (100 % exacto). «Llegaste al límite»: no se pasó.
//  - «QA 118»: 1.180 (118 %). «Te pasaste».
//
//  Lo de «antes de hoy» va al mediodía del día 1 del mes; si hoy es el día 1, va hoy (no hay otro día del mes). Aditivo
//  al perfil de `-uitest-seed`: necesita una cuenta.
//

#if DEBUG
import Foundation
import SwiftData

enum DevSeedBudgetStates {

    static let limit: Double = 1_000

    /// Nombre, lo gastado antes de hoy y lo gastado hoy.
    static let budgets: [(name: String, before: Double, today: Double)] = [
        ("QA 30", 300, 5),
        ("QA 90", 800, 100),
        ("QA 100", 1_000, 0),
        ("QA 118", 1_180, 0),
    ]

    @MainActor
    static func create(in context: ModelContext, now: Date = .now, calendar: Calendar = .current) {
        let accounts: [Account]
        let subcategories: [Subcategory]
        do {
            accounts = try context.fetch(FetchDescriptor<Account>(sortBy: [SortDescriptor(\.name)]))
            subcategories = try context.fetch(FetchDescriptor<Subcategory>())
        } catch {
            print("DevSeedBudgetStates: Error: \(error)")
            return
        }
        let preferred = CurrencyDefaults.currentPreferred
        guard let account = accounts.first(where: {
            !$0.isSystemAccount && !$0.excludeFromStatistics && $0.currencyCode == preferred
        }) else { return }
        // Un gasto con categoría de gasto: la clasificación la decide la categoría.
        let sub = subcategories.first { $0.name == L10n.Subcategory.publicTransport && $0.category?.isIncome == false }

        let startOfToday = calendar.startOfDay(for: now)
        let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? startOfToday
        let earlierDate = startOfMonth == startOfToday
            ? max(startOfToday, now.addingTimeInterval(-120))
            : startOfMonth.addingTimeInterval(12 * 3600)
        let todayDate = max(startOfToday, now.addingTimeInterval(-60))

        for def in budgets {
            let tag = Tag(name: def.name)
            context.insert(tag)
            let budget = Budget(
                currencyCode: preferred,
                limitAmount: limit,
                name: def.name,
                periodType: "monthly",
                tags: [tag]
            )
            context.insert(budget)
            for (amount, date) in [(def.before, earlierDate), (def.today, todayDate)] where amount > 0 {
                let item = TransactionItem(
                    date: date,
                    amount: -amount,
                    currencyCode: account.currencyCode,
                    note: def.name,
                    category: sub?.category,
                    subcategory: sub,
                    account: account,
                    tags: [tag],
                    amountInPreferredCurrency: -amount,
                    preferredCurrencyCode: preferred,
                    isExchangeRateProvisional: false
                )
                context.insert(item)
            }
        }
        do {
            try context.save()
        } catch {
            print("DevSeedBudgetStates: Error: \(error)")
        }
        SessionState.shared.incrementDataVersion()
    }
}
#endif
