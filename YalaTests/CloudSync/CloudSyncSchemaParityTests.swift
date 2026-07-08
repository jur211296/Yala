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

    // MARK: - (c) Membresía de stores

    @Test func personalStore_doesNotContain_syncIdentity() {
        #expect(!entityNames(SwiftDataConfiguration.personalSchema).contains("SyncIdentity"))
    }

    @Test func syncMetaStore_containsOnly_syncIdentity_andIsCloudKitNone() {
        #expect(entityNames(SwiftDataConfiguration.syncMetaSchema) == ["SyncIdentity"])

        let config = SwiftDataConfiguration.syncMetaConfiguration
        // El config sync-meta usa el schema sync-meta…
        #expect(config.schema.flatMap { entityNames($0) } == ["SyncIdentity"])
        // …y NUNCA CloudKit (`.none`). CloudKitDatabase no es Equatable → comparamos su descripción.
        #expect(String(describing: config.cloudKitDatabase).lowercased().contains("none"))
    }

    // MARK: - (d) Las 6 entidades sincronizables llevan `syncID`

    @Test func allSyncableEntities_haveSyncIDProperty() {
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
}
