//
//  DevSeedExtraFavorites.swift
//  Yala
//
//  Fixture de QA de la fila de Favoritos de Nuevo registro (`-uitest-seed-extra-favorites <n>`, encargo del 2026-11-21):
//  suma `n` favoritos de gasto, cada uno con otra subcategoría para que el icono cambie, y con dos nombres largos a partir
//  del tercero. Así se mide la fila con 1, 3, 5 y 10 favoritos: chips completos, bolitas de solo icono y scroll.
//  Aditivo e idempotente: va sobre el perfil (pensado para `formulario`, que ya trae «Café») y no duplica al relanzar.
//

#if DEBUG
import Foundation
import SwiftData

enum DevSeedExtraFavorites {
    static let names = ["Taxi", "Mercado", "Mantenimiento del edificio", "Farmacia", "Supermercado Plaza Vea",
                        "Gimnasio", "Netflix", "Luz del Sur", "Almuerzo"]

    /// El número que sigue a `-uitest-seed-extra-favorites`, o nil si la corrida no lo pide.
    static var requestedCount: Int? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-uitest-seed-extra-favorites"),
              arguments.indices.contains(index + 1) else { return nil }
        return Int(arguments[index + 1])
    }

    @MainActor
    static func create(count: Int, in context: ModelContext) {
        do {
            let favorites = try context.fetch(FetchDescriptor<FavoritePayment>())
            let account = try context.fetch(FetchDescriptor<Account>()).first
            let subcategories = try context.fetch(FetchDescriptor<Subcategory>())
                .filter { $0.category?.isIncome == false && $0.category?.isSystem == false }
            var order = favorites.count
            for (index, name) in names.prefix(max(0, count)).enumerated()
            where !favorites.contains(where: { $0.name == name }) {
                let subcategory = subcategories.isEmpty ? nil : subcategories[(index * 3) % subcategories.count]
                context.insert(FavoritePayment(
                    name: name, transactionType: TransactionType.expense.rawValue, amount: Double(10 + index * 5),
                    note: name, account: account, subcategory: subcategory, currencyCode: "PEN", displayOrder: order))
                order += 1
            }
            try context.save()
        } catch {
            print("DevSeedExtraFavorites: Error: \(error)")
        }
    }
}
#endif
