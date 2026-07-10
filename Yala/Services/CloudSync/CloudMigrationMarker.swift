//
//  CloudMigrationMarker.swift
//  Yala
//
//  Marcador CloudKit del cutover (Modo Nube Fase 4, I10-wiring w6, §g.4 paso 3). Es el ÚLTIMO efecto
//  OBSERVABLE de la migración: se inserta en el store PERSONAL (el que espeja NSPersistentCloudKitContainer)
//  con el mirror AÚN VIVO, así el record `CD_CloudMigrationMarker` se exporta a CloudKit y un 2º device lo
//  detecta en su próximo import → se auto-bloquea (RestoreRouter §4.5, I11/I14 — FUERA de este ciclo).
//
//  Es el ÚNICO @Model nuevo del store espejado. CloudKit-compat (regla del repo): todos los campos con
//  DEFAULT, sin `@Attribute(.unique)`, sin relaciones non-optional. NO se sincroniza al backend Modo Nube
//  (NO está en `CloudSyncEngine.personalEntityNames` — el equivalente server-side es `profiles.migrated_at`,
//  ya lo estampa `migration_progress('cutover')`; capturarlo al outbox lo rechazaría el backend por falta
//  de tabla/manifest).
//
//  REGLA DE DEPLOY (owner-pendiente, RUIDOSA): record type nuevo `CD_CloudMigrationMarker` en el container
//  PERSONAL (`iCloud.com.jurgenschmidt.yala`). ANTES de cualquier cutover REAL en TestFlight, el owner debe
//  desplegar el schema a Production (CloudKit Console) Y actualizar `cloudkit-yala-production.ckdb` en el
//  MISMO PR. En device DEV se autocrea en Development. DARK: nadie lo escribe hasta que una migración real
//  ejecute el paso 3 del cutover.
//

import Foundation
import SwiftData

extension CloudSyncSchemaVersions {
    /// Versión de schema de `CloudMigrationMarker` (testigo A1 en la fila).
    static let cloudMigrationMarker = 1
}

@Model
final class CloudMigrationMarker {

    /// Hash SHA-256 truncado NO reversible del `sub` de la cuenta nube (sin PII — mismo hash que el faro KV).
    var accountHash: String = ""

    /// Instante del cutover confirmado server-side (`profiles.migrated_at`). El `now` INYECTADO del executor.
    var migratedAtStamp: Date = Date.distantPast

    /// `server_seq` de corte para `reconcileFromFrozenCloudKit` (= `SyncCursor.serverSeqCursor` al cutover,
    /// journaleado también en `MigrationState.serverSeqCut`).
    var serverSeqCut: Int64 = 0

    /// `device_id` del líder que escribió el marcador (diagnóstico + `markerReconciliation` self-authored).
    var writerDeviceID: String = ""

    /// Versión del schema bajo la que se materializó esta fila (testigo A1).
    var schemaVersion: Int = CloudSyncSchemaVersions.cloudMigrationMarker

    init(
        accountHash: String = "",
        migratedAtStamp: Date = Date.distantPast,
        serverSeqCut: Int64 = 0,
        writerDeviceID: String = "",
        schemaVersion: Int = CloudSyncSchemaVersions.cloudMigrationMarker
    ) {
        self.accountHash = accountHash
        self.migratedAtStamp = migratedAtStamp
        self.serverSeqCut = serverSeqCut
        self.writerDeviceID = writerDeviceID
        self.schemaVersion = schemaVersion
    }
}
