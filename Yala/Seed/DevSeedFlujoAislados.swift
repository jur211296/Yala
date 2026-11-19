//
//  DevSeedFlujoAislados.swift
//  Yala
//
//  Fixture de QA del flujo de caja (`-uitest-seed-flujo-aislados`, encargo
//  `2026-11-19-flujo-aislados-promedio-y-detalle-mes`): el ejemplo de Jürgen del 19-nov, una línea «Fitness y actividad
//  física» con dos meses muy por encima del resto. Añade dos compras grandes en Fitness —hace 3 meses y el mes pasado— a
//  la semilla `realista`, que ya trae el gimnasio de 150 cada mes. Con ellas, el promedio de 6 meses de la línea sube a
//  ~600; sin ellas (aisladas), se queda en 150.
//
//  Aditivo al perfil de `-uitest-seed`.
//

#if DEBUG
import Foundation
import SwiftData

enum DevSeedFlujoAislados {

    /// Las dos compras: meses atrás desde el mes en curso, día, importe y nota.
    static let compras: [(mesesAtras: Int, dia: Int, importe: Double, nota: String)] = [
        (3, 14, -1_450, "Bicicleta de spinning"),
        (1, 9, -1_280, "Inscripción a la maratón y zapatillas"),
    ]

    @MainActor
    static func create(in context: ModelContext, now: Date = .now) {
        let accounts: [Account]
        let subcategories: [Subcategory]
        do {
            accounts = try context.fetch(FetchDescriptor<Account>(sortBy: [SortDescriptor(\.name)]))
            subcategories = try context.fetch(FetchDescriptor<Subcategory>())
        } catch {
            print("DevSeedFlujoAislados: Error: \(error)")
            return
        }
        let preferred = CurrencyDefaults.currentPreferred
        guard let account = accounts.first(where: {
            !$0.isSystemAccount && !$0.excludeFromStatistics && $0.currencyCode == preferred
        }) ?? accounts.first(where: { !$0.isSystemAccount }),
              let fitness = subcategories.first(where: { $0.name == L10n.Subcategory.fitness }) else { return }
        let calendar = Calendar.current
        guard let mesActual = calendar.dateInterval(of: .month, for: now)?.start else { return }
        for compra in compras {
            guard let mes = calendar.date(byAdding: .month, value: -compra.mesesAtras, to: mesActual),
                  let fecha = calendar.date(byAdding: DateComponents(day: compra.dia - 1, hour: 18), to: mes)
            else { continue }
            let item = TransactionItem(
                date: fecha,
                amount: compra.importe,
                currencyCode: account.currencyCode,
                note: compra.nota,
                account: account,
                amountInPreferredCurrency: account.currencyCode == preferred ? compra.importe : 0,
                preferredCurrencyCode: preferred,
                isExchangeRateProvisional: false
            )
            context.insert(item)
            item.category = fitness.category
            item.subcategory = fitness
            if account.currencyCode != preferred { item.recalculatePreferredCurrency(context: context) }
        }
        do {
            try context.save()
        } catch {
            print("DevSeedFlujoAislados: Error: \(error)")
        }
        SessionState.shared.incrementDataVersion()
    }
}
#endif
