//
//  SyncIdentity.swift
//  Yala
//
//  Modelo testigo de la identidad de sync (Modo Nube, incremento I2). Vincula cada fila
//  sincronizable de la app (por su `syncID`) con su ancla de contenido determinista y con las
//  coordenadas del record en CloudKit (capturadas en la migración, I10).
//
//  IMPORTANTE — NUNCA se espeja a CloudKit: vive en un store propio con `cloudKitDatabase: .none`
//  (ver `SwiftDataConfiguration.syncMetaConfiguration`). Es metadata LOCAL del dispositivo: el
//  mapping identidad↔ancla↔record se reconstruye por dispositivo, no viaja. Por eso NO lleva las
//  reglas CloudKit-compat (defaults obligatorios / opcionalidad forzada) de los modelos espejados.
//

import Foundation
import SwiftData

/// Versiones de schema de los modelos del Modo Nube. `schemaVersion` en cada fila es el testigo A1:
/// permite detectar en runtime una fila materializada bajo un schema viejo si el modelo evoluciona.
nonisolated enum CloudSyncSchemaVersions {
    static let syncIdentity = 1
}

/// Nombres canónicos de tipo de entidad para el matching (entityType + ancla) del rebind y para el
/// campo `entityType` de `SyncIdentity`. Literales estables: renombrar la clase `@Model` de una
/// entidad NO debe cambiar estos strings (romperían el rebind cross-migración).
nonisolated enum SyncEntityType {
    static let transactionItem = "TransactionItem"
    static let inboxDraft = "InboxDraft"
    static let category = "Category"
    static let favoritePayment = "FavoritePayment"
    static let merchantMemory = "MerchantMemory"
    static let exchangeRate = "ExchangeRate"
    // I12: las 10 restantes usan su UUID EXISTENTE como identidad de sync (Account/Subcategory =
    // `shortcutID`; el resto = `id`). Literales estables = nombre de clase (invariante de rebind).
    static let scheduledPayment = "ScheduledPayment"
    static let budget = "Budget"
    static let account = "Account"
    static let subcategory = "Subcategory"
    static let tag = "Tag"
    static let notificationItem = "NotificationItem"
    static let cashFlowPlan = "CashFlowPlan"
    static let cashFlowLine = "CashFlowLine"
    static let cashFlowOverride = "CashFlowOverride"
    static let groupBridgePreference = "GroupBridgePreference"
}

/// Fila testigo de identidad de sync. Una por cada entidad sincronizable materializada.
@Model
final class SyncIdentity {

    /// Identidad estable de sync de la fila de negocio (el `syncID` que la entidad espeja). UUIDv4.
    var syncID: UUID = UUID()

    /// Tipo de entidad (`SyncEntityType.*`). Parte de la clave de rebind (entityType + ancla).
    var entityType: String = ""

    /// Ancla de contenido determinista (`SyncContentAnchor`, hex SHA-256). Permite REBIND: recuperar
    /// el `syncID` de una fila borrada+recreada con el mismo contenido.
    var localAnchor: String = ""

    /// Nombre del record en CloudKit. Se captura en la migración (I10, §b.5); `nil` en born-cloud
    /// (aún no ha hecho round-trip a CloudKit).
    var ckRecordName: String?

    /// Nombre de la zona CloudKit del record. Capturado en la migración (I10, §b.5); `nil` en born-cloud.
    var ckZoneName: String?

    /// Owner name de la zona CloudKit. Capturado en la migración (I10, §b.5); `nil` en born-cloud.
    var ckOwnerName: String?

    /// Cuándo se creó esta fila testigo.
    var createdAt: Date = Date.now

    /// Última vez que esta identidad se RE-vinculó a una fila recreada con el mismo contenido
    /// (rebind). `nil` si nunca se rebindó.
    var lastReboundAt: Date?

    /// Versión del schema bajo la que se materializó esta fila (testigo A1).
    var schemaVersion: Int = CloudSyncSchemaVersions.syncIdentity

    init(
        syncID: UUID,
        entityType: String,
        localAnchor: String,
        ckRecordName: String? = nil,
        ckZoneName: String? = nil,
        ckOwnerName: String? = nil,
        createdAt: Date = .now,
        lastReboundAt: Date? = nil,
        schemaVersion: Int = CloudSyncSchemaVersions.syncIdentity
    ) {
        self.syncID = syncID
        self.entityType = entityType
        self.localAnchor = localAnchor
        self.ckRecordName = ckRecordName
        self.ckZoneName = ckZoneName
        self.ckOwnerName = ckOwnerName
        self.createdAt = createdAt
        self.lastReboundAt = lastReboundAt
        self.schemaVersion = schemaVersion
    }
}
