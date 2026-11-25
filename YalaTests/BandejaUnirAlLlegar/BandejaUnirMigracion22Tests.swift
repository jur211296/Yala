//
//  BandejaUnirMigracion22Tests.swift
//  YalaTests
//
//  Bandeja sin duplicados, lote 2: `InboxDraft.joinRecordRaw` es un campo nuevo del store personal. Esta prueba abre con el
//  modelo de ahora una base creada con el de 2.2 y comprueba que los borradores siguen ahí, con sus valores, y que el campo
//  nuevo nace vacío y se puede escribir (Paso 0, D11).
//
//  El modelo de 2.2 no vive en el repo como código. Se reconstruye así: el `NSManagedObjectModel` que SwiftData genera hoy,
//  sin los atributos que el esquema de PRODUCCIÓN de iCloud (`Cloudkit Schemas/yala-production.ckdb`, el de 2.2) no tiene.
//  Hoy eso quita `InboxDraft.joinRecordRaw`, y la prueba lo exige: si quitara nada, no estaría probando la migración.
//

import CoreData
import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Bandeja sin duplicados · una base de 2.2 migra sin perder borradores", .serialized)
@MainActor
struct BandejaUnirMigracion22Tests {

    /// Los tipos de `SwiftDataConfiguration.personalSchema` (la misma lista que `PersonalCloudKitSchemaParityTests`).
    private static let personalTypes: [any PersistentModel.Type] = [
        Category.self, Subcategory.self, Tag.self, Account.self, TransactionItem.self, Budget.self, ExchangeRate.self,
        FavoritePayment.self, ScheduledPayment.self, InboxDraft.self, MerchantMemory.self, NotificationItem.self,
        CashFlowPlan.self, CashFlowLine.self, CashFlowOverride.self, GroupBridgePreference.self, CloudMigrationMarker.self,
    ]

    private func productionSnapshot() throws -> [String: [String: String]] {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Cloudkit Schemas/yala-production.ckdb")
        return PersonalCloudKitSchemaParityTests.parseSnapshot(try String(contentsOf: url, encoding: .utf8))
    }

    /// El modelo de hoy sin lo que la producción de iCloud no tiene. Devuelve también lo que quitó, por entidad.
    private func model22() throws -> (NSManagedObjectModel, [String: [String]]) {
        let current = try #require(NSManagedObjectModel.makeManagedObjectModel(for: Self.personalTypes))
        let old = try #require(current.copy() as? NSManagedObjectModel)
        let snapshot = try productionSnapshot()
        var removed: [String: [String]] = [:]
        for entity in old.entities {
            guard let name = entity.name, let fields = snapshot["CD_\(name)"] else { continue }
            let kept = entity.properties.filter { property in
                guard property is NSAttributeDescription else { return true }
                let present = fields["CD_\(property.name)"] != nil
                if !present { removed[name, default: []].append(property.name) }
                return present
            }
            entity.properties = kept
        }
        return (old, removed)
    }

    @Test func unaBaseDe22_abreConElModeloDeHoy_conSusBorradores() throws {
        let (old, removed) = try model22()
        #expect(removed["InboxDraft"]?.contains("joinRecordRaw") == true,
                "control: el modelo de 2.2 no tiene el campo nuevo (si no, no se prueba ninguna migración)")

        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("BandejaUnir22-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        retireTestStoreDirectoryLater(dir)
        let url = dir.appendingPathComponent("personal.sqlite")

        // 1 · La base de 2.2, con dos borradores pendientes escritos por Core Data.
        let created = Date(timeIntervalSince1970: 1_790_000_000)
        do {
            let coordinator = NSPersistentStoreCoordinator(managedObjectModel: old)
            let store = try coordinator.addPersistentStore(type: .sqlite, at: url)
            let context = NSManagedObjectContext(.mainQueue)
            context.persistentStoreCoordinator = coordinator
            for (note, amount) in [("Starbucks", -42.5), ("Wong", -89.9)] {
                let draft = NSEntityDescription.insertNewObject(forEntityName: "InboxDraft", into: context)
                draft.setValue(note, forKey: "note")
                draft.setValue(amount, forKey: "amount")
                draft.setValue(DraftSourceType.applePay.rawValue, forKey: "sourceTypeRaw")
                draft.setValue(DraftStatus.pending.rawValue, forKey: "statusRaw")
                draft.setValue(created, forKey: "createdAt")
                draft.setValue(created, forKey: "updatedAt")
            }
            try context.save()
            try coordinator.remove(store)
        }

        // 2 · La app de hoy la abre.
        let configuration = ModelConfiguration(
            "Personal22", schema: SwiftDataConfiguration.personalSchema, url: url, cloudKitDatabase: .none)
        let container = try ModelContainer(for: SwiftDataConfiguration.personalSchema, configurations: configuration)
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let drafts = try context.fetch(FetchDescriptor<InboxDraft>(sortBy: [SortDescriptor(\.note)]))
        #expect(drafts.map(\.note) == ["Starbucks", "Wong"], "ningún borrador se pierde")
        #expect(drafts.map(\.amount) == [-42.5, -89.9])
        #expect(drafts.allSatisfy { $0.status == .pending && $0.sourceType == .applePay && $0.createdAt == created })
        #expect(drafts.allSatisfy { $0.joinRecordRaw == nil }, "el campo nuevo nace vacío")

        // 3 · Y el campo nuevo se guarda.
        let first = try #require(drafts.first)
        first.joinRecordRaw = #"{"version":1}"#
        try context.save()
        let again = ModelContext(container)
        let reread = try again.fetch(FetchDescriptor<InboxDraft>()).first { $0.note == "Starbucks" }
        #expect(reread?.joinRecordRaw == #"{"version":1}"#)
    }
}
