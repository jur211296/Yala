//
//  CloudSyncSchemaParityTests.swift
//  YalaTests / CloudSync
//
//  Paridad de schema del subsistema de identidad de sync (Modo Nube, I2). Ancla invariantes que,
//  si se rompen en silencio, corromperían la migración/rebind:
//
//  (a) El entity name de `SyncIdentity` es el literal "SyncIdentity" — S-A1: renombrar la CLASE es
//      el ÚNICO gatillo que recrea la tabla VACÍA (pierde las filas testigo). Este literal lo delata.
//  (b) El set EXACTO de propiedades de `SyncIdentity` (molde de CloudKitGroupsSchemaParityTests).
//  (c) Membresía de stores: el store PERSONAL NO contiene `SyncIdentity`; el store SYNC-META SÍ, y
//      es `cloudKitDatabase: .none` (nunca se espeja a CloudKit).
//  (d) Las 6 entidades sincronizables llevan la propiedad `syncID`.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("CloudSync · schema parity")
struct CloudSyncSchemaParityTests {

    private func entity(_ type: any PersistentModel.Type) -> Schema.Entity? {
        // `Schema([type])` expande e incluye las entidades RELACIONADas (via @Relationship), así que
        // `.entities.first` no es el tipo pedido → hay que casar por nombre (= nombre simple de clase).
        let name = String(describing: type)
        return Schema([type]).entities.first { $0.name == name }
    }

    private func propertyNames(_ type: any PersistentModel.Type) -> Set<String> {
        Set((entity(type)?.properties ?? []).map(\.name))
    }

    private func entityNames(_ schema: Schema) -> Set<String> {
        Set(schema.entities.map(\.name))
    }

    // MARK: - (a) Entity name anclado

    @Test func syncIdentity_entityName_isAnchoredLiteral() {
        #expect(entity(SyncIdentity.self)?.name == "SyncIdentity")
    }

    // MARK: - (b) Set EXACTO de propiedades

    @Test func syncIdentity_hasExactPropertySet() {
        let expected: Set<String> = [
            "syncID",
            "entityType",
            "localAnchor",
            "ckRecordName",
            "ckZoneName",
            "ckOwnerName",
            "createdAt",
            "lastReboundAt",
            "schemaVersion",
        ]
        #expect(propertyNames(SyncIdentity.self) == expected)
    }

    // MARK: - (b·I3) Set EXACTO de propiedades de SyncOutbox / SyncCursor

    @Test func syncOutbox_entityName_isAnchoredLiteral() {
        #expect(entity(SyncOutbox.self)?.name == "SyncOutbox")
    }

    @Test func syncOutbox_hasExactPropertySet() {
        let expected: Set<String> = [
            "syncID",
            "entityType",
            "opRaw",
            "hlc",
            "clientMutationID",
            "fieldsJSON",
            "fieldHlcsJSON",
            "author",
            "tombstoneReason",
            "createdAt",
            "rejectedReason",
            "rejectedAt",
            "schemaVersion",
        ]
        #expect(propertyNames(SyncOutbox.self) == expected)
    }

    @Test func syncOutbox_schemaVersion_isFour_afterDeadLetter() {
        // I4 añadió `tombstoneReason` (v2); I8c añadió `fieldHlcsJSON` (v3); I8e añadió el dead-letter
        // (`rejectedReason`/`rejectedAt`, additive) → bump del testigo A1 a 4.
        #expect(CloudSyncSchemaVersions.syncOutbox == 4)
    }

    @Test func syncCursor_entityName_isAnchoredLiteral() {
        #expect(entity(SyncCursor.self)?.name == "SyncCursor")
    }

    @Test func syncCursor_hasExactPropertySet() {
        // I8f-1 añadió `serverSeqCursor` (cursor del pull) + `clockLatestHLC` (reloj durable, D-3);
        // I9 añadió `quarantinePendingCount` (testigo lockstep de la cuarentena), todos additive.
        let expected: Set<String> = [
            "historyTokenData",
            "serverSeqCursor",
            "clockLatestHLC",
            "quarantinePendingCount",
            "schemaVersion",
        ]
        #expect(propertyNames(SyncCursor.self) == expected)
    }

    @Test func syncCursor_schemaVersion_isTwo_afterQuarantineWitness() {
        // I9 añadió `quarantinePendingCount` (additive) → bump del testigo A1 a 2.
        #expect(CloudSyncSchemaVersions.syncCursor == 2)
    }

    // MARK: - (b·I8f) SyncQuarantine

    @Test func syncQuarantine_entityName_isAnchoredLiteral() {
        #expect(entity(SyncQuarantine.self)?.name == "SyncQuarantine")
    }

    @Test func syncQuarantine_hasExactPropertySet() {
        let expected: Set<String> = [
            "serverSeq",
            "entityType",
            "syncID",
            "rawDelta",
            "hlc",
            "createdAt",
            "schemaVersion",
        ]
        #expect(propertyNames(SyncQuarantine.self) == expected)
    }

    // MARK: - (b·I8f/F-2) SyncDanglingRef

    @Test func syncDanglingRef_entityName_isAnchoredLiteral() {
        #expect(entity(SyncDanglingRef.self)?.name == "SyncDanglingRef")
    }

    @Test func syncDanglingRef_hasExactPropertySet() {
        let expected: Set<String> = [
            "entityTable",
            "rowSyncID",
            "column",
            "targetUUID",
            "createdAt",
            "schemaVersion",
        ]
        #expect(propertyNames(SyncDanglingRef.self) == expected)
    }

    // MARK: - (b·I8f-2) SyncUnitClock

    @Test func syncUnitClock_entityName_isAnchoredLiteral() {
        #expect(entity(SyncUnitClock.self)?.name == "SyncUnitClock")
    }

    @Test func syncUnitClock_hasExactPropertySet() {
        let expected: Set<String> = [
            "syncID",
            "entityTable",
            "unitHlcsJSON",
            "updatedAt",
            "schemaVersion",
        ]
        #expect(propertyNames(SyncUnitClock.self) == expected)
    }

    // MARK: - (c) Membresía de stores

    @Test func personalStore_doesNotContain_syncMetaEntities() {
        let personal = entityNames(SwiftDataConfiguration.personalSchema)
        #expect(!personal.contains("SyncIdentity"))
        #expect(!personal.contains("SyncOutbox"))
        #expect(!personal.contains("SyncCursor"))
        #expect(!personal.contains("SyncQuarantine"))
        #expect(!personal.contains("SyncDanglingRef"))
        #expect(!personal.contains("SyncUnitClock"))
    }

    @Test func syncMetaStore_containsExactly_syncMetaEntities_andIsCloudKitNone() {
        let expected: Set<String> = ["SyncIdentity", "SyncOutbox", "SyncCursor", "SyncQuarantine",
                                     "SyncDanglingRef", "SyncUnitClock"]
        #expect(entityNames(SwiftDataConfiguration.syncMetaSchema) == expected)

        let config = SwiftDataConfiguration.syncMetaConfiguration
        // El config sync-meta usa el schema sync-meta…
        #expect(config.schema.flatMap { entityNames($0) } == expected)
        // …y NUNCA CloudKit (`.none`). CloudKitDatabase no es Equatable → comparamos su descripción.
        #expect(String(describing: config.cloudKitDatabase).lowercased().contains("none"))
    }

    // MARK: - (e·I3) Anti-drift: la lista anti-fuga del motor == entity names del store personal

    @Test func engine_personalEntityNames_matchPersonalSchema() {
        #expect(CloudSyncEngine.personalEntityNames == entityNames(SwiftDataConfiguration.personalSchema))
    }

    // MARK: - (d) Identidad de sync por entidad

    /// Las 6 originales llevan el `syncID` sintético.
    @Test func syntheticSyncableEntities_haveSyncIDProperty() {
        let syncable: [any PersistentModel.Type] = [
            TransactionItem.self,
            InboxDraft.self,
            Category.self,
            FavoritePayment.self,
            MerchantMemory.self,
            ExchangeRate.self,
        ]
        for type in syncable {
            #expect(propertyNames(type).contains("syncID"), "\(type) debe tener la propiedad syncID")
        }
    }

    /// Las cableadas en I12 usan su UUID EXISTENTE como identidad de sync (Account/Subcategory =
    /// `shortcutID`; el resto = `id`). El campo debe existir en el schema para que el tombstone
    /// (`.preserveValueOnDeletion`) y el fetch por identidad lo resuelvan.
    @Test func wiredIdentityEntities_haveIdentityProperty() {
        // (tipo, campo de identidad)
        let wired: [(any PersistentModel.Type, String)] = [
            (Budget.self, "id"),
            (ScheduledPayment.self, "id"),
            // Commit B: las 8 restantes.
            (Account.self, "shortcutID"),
            (Subcategory.self, "shortcutID"),
            (Tag.self, "id"),
            (NotificationItem.self, "id"),
            (CashFlowPlan.self, "id"),
            (CashFlowLine.self, "id"),
            (CashFlowOverride.self, "id"),
            (GroupBridgePreference.self, "id"),
        ]
        for (type, field) in wired {
            #expect(propertyNames(type).contains(field),
                    "\(type) debe tener la propiedad de identidad \(field)")
        }
    }

    /// `.preserveValueOnDeletion` en la identidad de las cableadas en I12 no es introspectable vía
    /// `Schema.Entity`; se valida con un tombstone REAL: borrar la fila y comprobar que el history
    /// tombstone conserva el `id`. Store ON-DISK propio en dir temporal (patrón SyncApplyEngineTests)
    /// — NO usa `makeTestContext()` (helper in-memory), así que la regla `.serialized` (≥2
    /// makeTestContext por proceso) NO aplica a esta suite; es el único test con container aquí.
    @MainActor
    @Test func wiredIdentity_isPreservedInTombstone_budget() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SchemaParity-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let personalCfg = ModelConfiguration(
            "SP-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groupsCfg = ModelConfiguration(
            "SP-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMetaCfg = ModelConfiguration(
            "SP-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(for: SwiftDataConfiguration.schema,
                                           configurations: personalCfg, groupsCfg, syncMetaCfg)
        let context = ModelContext(container)

        let budget = Budget(currencyCode: "USD", limitAmount: 100)
        let budgetID = budget.id
        context.insert(budget)
        try context.save()
        context.delete(budget)
        try context.save()

        // El history tombstone del delete debe conservar `id` (= `.preserveValueOnDeletion`).
        let txns = try context.fetchHistory(HistoryDescriptor<DefaultHistoryTransaction>())
        var preservedIDs: [UUID] = []
        for tx in txns {
            for change in tx.changes {
                guard case .delete(let del) = change,
                      let typed = del as? DefaultHistoryDelete<Budget> else { continue }
                if let id = typed.tombstone[\.id] as? UUID { preservedIDs.append(id) }
            }
        }
        #expect(preservedIDs.contains(budgetID),
                "el tombstone de Budget debe conservar `id` (@Attribute(.preserveValueOnDeletion))")
    }
}
