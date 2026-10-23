//
//  FavoritePaymentDestinationMigrationTests.swift
//  YalaTests
//
//  UX 2.2 · L2-14: `FavoritePayment.destinationAccount` es una relación nueva del esquema personal. Un teléfono que
//  actualiza llega con un almacén escrito por el modelo viejo, con favoritos dentro; tiene que abrir, leerlos y poder
//  guardar el destino. El modelo viejo se reconstruye quitando la relación (y su inversa) del que SwiftData genera
//  para los mismos tipos, así que no hay una copia del esquema escrita a mano que pueda envejecer.
//

import CoreData
import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("L2-14 · migración del favorito con destino", .serialized)
struct FavoritePaymentDestinationMigrationTests {

    private static let personalTypes: [any PersistentModel.Type] = [
        Category.self, Subcategory.self, Tag.self, Account.self, TransactionItem.self, Budget.self,
        ExchangeRate.self, FavoritePayment.self, ScheduledPayment.self, InboxDraft.self, MerchantMemory.self,
        NotificationItem.self, CashFlowPlan.self, CashFlowLine.self, CashFlowOverride.self,
        GroupBridgePreference.self, CloudMigrationMarker.self,
    ]

    /// El modelo de antes de 2.2: el de hoy sin `destinationAccount` ni su inversa.
    private func modelBeforeDestination() throws -> NSManagedObjectModel {
        let current = try #require(NSManagedObjectModel.makeManagedObjectModel(for: Self.personalTypes))
        let model = try #require(current.copy() as? NSManagedObjectModel)
        let favorite = try #require(model.entitiesByName["FavoritePayment"])
        let account = try #require(model.entitiesByName["Account"])
        // Control: el modelo de hoy SÍ tiene la relación. Sin esto, quitar algo que no está daría un verde sin medir nada.
        #expect(favorite.relationshipsByName["destinationAccount"] != nil)
        #expect(account.relationshipsByName["destinationFavoritePayments"] != nil)
        favorite.properties = favorite.properties.filter { $0.name != "destinationAccount" }
        account.properties = account.properties.filter { $0.name != "destinationFavoritePayments" }
        return model
    }

    /// Rellena los atributos obligatorios sin valor por defecto (los opcionales se quedan vacíos).
    private func fillRequired(_ object: NSManagedObject) {
        for (name, attribute) in object.entity.attributesByName where !attribute.isOptional {
            guard object.value(forKey: name) == nil else { continue }
            switch attribute.attributeType {
            case .stringAttributeType: object.setValue("", forKey: name)
            case .booleanAttributeType: object.setValue(false, forKey: name)
            case .dateAttributeType: object.setValue(Date(), forKey: name)
            case .doubleAttributeType, .floatAttributeType, .decimalAttributeType: object.setValue(0, forKey: name)
            case .integer16AttributeType, .integer32AttributeType, .integer64AttributeType: object.setValue(0, forKey: name)
            case .UUIDAttributeType: object.setValue(UUID(), forKey: name)
            case .binaryDataAttributeType: object.setValue(Data(), forKey: name)
            default: break
            }
        }
    }

    @Test func unAlmacenConFavoritosViejos_abreYLosUsa() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FavDestMigration-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            do { try FileManager.default.removeItem(at: directory) } catch {
                print("FavoritePaymentDestinationMigrationTests: Error: limpiar el directorio: \(error)")
            }
        }
        let url = directory.appendingPathComponent("Yala.store")

        // 1. El almacén de antes: una cuenta, un favorito de gasto y uno de transferencia (que entonces no podía
        //    guardar destino).
        do {
            let oldModel = try modelBeforeDestination()
            let coordinator = NSPersistentStoreCoordinator(managedObjectModel: oldModel)
            try coordinator.addPersistentStore(type: .sqlite, at: url)
            let context = NSManagedObjectContext(.mainQueue)
            context.persistentStoreCoordinator = coordinator

            let account = NSEntityDescription.insertNewObject(forEntityName: "Account", into: context)
            fillRequired(account)
            account.setValue("Cuenta Principal", forKey: "name")
            account.setValue("PEN", forKey: "currencyCode")

            for (name, type) in [("Café", "expense"), ("Ahorro", "transfer")] {
                let favorite = NSEntityDescription.insertNewObject(forEntityName: "FavoritePayment", into: context)
                fillRequired(favorite)
                favorite.setValue(name, forKey: "name")
                favorite.setValue(type, forKey: "transactionType")
                favorite.setValue(25.0, forKey: "amount")
                favorite.setValue(account, forKey: "account")
            }
            try context.save()
            for store in coordinator.persistentStores { try coordinator.remove(store) }
        }

        // 2. La app de hoy abre ese almacén.
        let configuration = ModelConfiguration(
            schema: Schema(Self.personalTypes), url: url, cloudKitDatabase: .none)
        let container = try ModelContainer(for: Schema(Self.personalTypes), configurations: [configuration])
        let context = ModelContext(container)

        let favorites = try context.fetch(FetchDescriptor<FavoritePayment>(sortBy: [SortDescriptor(\.name)]))
        #expect(favorites.map(\.name) == ["Ahorro", "Café"])
        let transfer = try #require(favorites.first { $0.name == "Ahorro" })
        #expect(transfer.type == .transfer)
        #expect(transfer.destinationAccount == nil)
        #expect(transfer.account?.name == "Cuenta Principal")

        // 3. Y puede guardar el destino.
        let savings = Account(name: "Ahorros", currencyCode: "USD", colorHex: "#6366F1", iconName: "banknote.fill",
                              type: AccountType.savings.rawValue)
        context.insert(savings)
        transfer.destinationAccount = savings
        try context.save()

        let reread = try ModelContext(container).fetch(FetchDescriptor<FavoritePayment>())
            .first { $0.name == "Ahorro" }
        #expect(reread?.destinationAccount?.name == "Ahorros")
    }
}
