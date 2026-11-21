//
//  DevSeedLongNames.swift
//  Yala
//
//  Fixture de QA de la hoja B1 de Nuevo registro (`-uitest-seed-long-names`, encargo del 2026-11-20): el peor caso de la
//  fila de abajo, que va siempre en una línea. Una cuenta con nombre largo en soles («Interbank Sueldo Soles»), otra en
//  dólares, la subcategoría «Mantenimiento y reparaciones», tres etiquetas y un favorito de gasto con todo puesto.
//  Aditivo e idempotente: va sobre el perfil (pensado para `formulario`) y no duplica nada al relanzar.
//

#if DEBUG
import Foundation
import SwiftData

enum DevSeedLongNames {
    static let longAccountName = "Interbank Sueldo Soles"
    static let dollarAccountName = "Ahorros en dólares Interbank"
    static let longSubcategoryName = "Mantenimiento y reparaciones"
    static let tagNames = ["Casa", "Urgente", "Mensual"]
    static let favoriteName = "Gasfitero"

    @MainActor
    static func create(in context: ModelContext) {
        do {
            let accounts = try context.fetch(FetchDescriptor<Account>())
            let soles = accounts.first { $0.name == longAccountName } ?? insertAccount(
                longAccountName, currency: "PEN", color: "#0EA5E9", in: context)
            if !accounts.contains(where: { $0.name == dollarAccountName }) {
                _ = insertAccount(dollarAccountName, currency: "USD", color: "#22C55E", in: context)
            }

            let categories = try context.fetch(FetchDescriptor<Category>())
            let subcategories = try context.fetch(FetchDescriptor<Subcategory>())
            var subcategory = subcategories.first { $0.name == longSubcategoryName }
            if subcategory == nil, let home = categories.first(where: { !$0.isIncome && !$0.isSystem }) {
                let created = Subcategory(
                    name: longSubcategoryName, isDefaultSeed: false, natureRawValue: SubcategoryNeed.essential.rawValue,
                    iconName: "wrench.and.screwdriver.fill", category: home)
                context.insert(created)
                subcategory = created
            }

            let existingTags = try context.fetch(FetchDescriptor<Tag>())
            var tags: [Tag] = []
            for (index, name) in tagNames.enumerated() {
                if let tag = existingTags.first(where: { $0.name == name }) {
                    tags.append(tag)
                } else {
                    let tag = Tag(name: name, colorHex: Tag.defaultColors[index % Tag.defaultColors.count],
                                  iconName: "tag.fill")
                    context.insert(tag)
                    tags.append(tag)
                }
            }

            let favorites = try context.fetch(FetchDescriptor<FavoritePayment>())
            if !favorites.contains(where: { $0.name == favoriteName }) {
                let favorite = FavoritePayment(
                    name: favoriteName, transactionType: TransactionType.expense.rawValue, amount: 180,
                    note: favoriteName, account: soles, subcategory: subcategory, tags: Array(tags.prefix(2)),
                    currencyCode: "PEN",
                    displayOrder: favorites.count)
                context.insert(favorite)
            }
            try context.save()
        } catch {
            print("DevSeedLongNames: Error: \(error)")
        }
    }

    @MainActor
    private static func insertAccount(_ name: String, currency: String, color: String, in context: ModelContext) -> Account {
        let account = Account(name: name, currencyCode: currency, colorHex: color, iconName: "building.columns.fill",
                              type: AccountType.checking.rawValue)
        context.insert(account)
        return account
    }
}
#endif
