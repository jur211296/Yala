//
//  DevSeedBudgetOverLimitHistory.swift
//  Yala
//
//  Fixture de QA (`-uitest-seed-budget-over-history`, «Ajusta el límite a lo real», 21-nov-2026): un presupuesto
//  mensual de 1.000, «QA historial», filtrado por su propia etiqueta, creado hace seis meses y pasado este mes (3.000: el 300 %, por encima de
//  «Movilidad» de `minimal` —209 %—, para ser el que la hoja propone mejorar)
//  y en 3 de los 4 meses completos anteriores (1.210, 1.185, 980, 1.345). La hoja de Salud financiera propone subirlo a
//  1.200 (el promedio, 1.180, redondeado hacia arriba). Aditivo al perfil de `-uitest-seed`: necesita una cuenta.
//

#if DEBUG
import Foundation
import SwiftData

enum DevSeedBudgetOverLimitHistory {

    static let name = "QA historial"
    static let limit: Double = 1_000
    /// Lo gastado este mes y en los cuatro meses completos anteriores, del más reciente al más viejo.
    static let thisMonth: Double = 3_000
    static let previousMonths: [Double] = [1_210, 1_185, 980, 1_345]

    @MainActor
    static func create(in context: ModelContext, now: Date = .now, calendar: Calendar = .current) {
        let accounts: [Account]
        do {
            accounts = try context.fetch(FetchDescriptor<Account>(sortBy: [SortDescriptor(\.name)]))
        } catch {
            print("DevSeedBudgetOverLimitHistory: Error: \(error)")
            return
        }
        let preferred = CurrencyDefaults.currentPreferred
        guard let account = accounts.first(where: {
            !$0.isSystemAccount && !$0.excludeFromStatistics && $0.currencyCode == preferred
        }) else { return }
        // Sin categoría: así no entra en ningún presupuesto de la semilla por categoría (Movilidad lo absorbía).

        let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? calendar.startOfDay(for: now)
        let created = calendar.date(byAdding: .month, value: -6, to: startOfMonth) ?? startOfMonth
        let tag = Tag(name: name)
        context.insert(tag)
        let budget = Budget(
            currencyCode: preferred,
            limitAmount: limit,
            name: name,
            periodType: "monthly",
            tags: [tag],
            createdAt: created
        )
        context.insert(budget)

        // Este mes, en su primer instante con margen (hoy puede ser el día 1); los anteriores, a mitad de mes.
        let thisMonthDate = max(startOfMonth, now.addingTimeInterval(-120))
        var gastos: [(Double, Date)] = [(thisMonth, thisMonthDate)]
        for (offset, amount) in previousMonths.enumerated() {
            guard let month = calendar.date(byAdding: .month, value: -(offset + 1), to: startOfMonth),
                  let mid = calendar.date(byAdding: .day, value: 14, to: month) else { continue }
            gastos.append((amount, mid.addingTimeInterval(12 * 3600)))
        }
        for (amount, date) in gastos {
            context.insert(TransactionItem(
                date: date,
                amount: -amount,
                currencyCode: account.currencyCode,
                note: name,
                category: nil,
                subcategory: nil,
                account: account,
                tags: [tag],
                amountInPreferredCurrency: -amount,
                preferredCurrencyCode: preferred,
                isExchangeRateProvisional: false
            ))
        }
        do {
            try context.save()
        } catch {
            print("DevSeedBudgetOverLimitHistory: Error: \(error)")
        }
        SessionState.shared.incrementDataVersion()
    }
}
#endif
