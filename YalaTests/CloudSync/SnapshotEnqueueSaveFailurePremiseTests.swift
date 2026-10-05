//
//  SnapshotEnqueueSaveFailurePremiseTests.swift
//  YalaTests
//
//  Las premisas que cerraron el ticket `a-failed-snapshot-enqueue-save-leaves-the-journal-unsaved` sin tocar código.
//
//  El ticket temía esto: el `save()` del encolado del snapshot (o el de la identidad, o el del adopt) lanza, sus
//  filas se quedan sucias en el contexto compartido, y el `save()` siguiente —el del journal— falla por ellas. La
//  medición dijo que ese `save()` no puede fallar POR SUS FILAS, solo por causas que tumban cualquier save del
//  store (disco lleno, E/S), y esas tumban también el del journal. Estos tests fijan las dos patas:
//
//  1. El journal vive en el MISMO store que el outbox, el cursor, los relojes por unidad y las identidades. Si
//     algún día se separa, un fallo del store del outbox ya no arrastraría al journal y el ticket se reabre.
//  2. Un escritor en OTRO contexto que modifica o borra la misma fila no hace lanzar el `save()` de este: SwiftData
//     resuelve el conflicto sin error. Si cambia la política de merge, el contexto compartido sí podría quedarse
//     sin poder guardar y el ticket se reabre.
//
//  Los stores van en disco (no in-memory): el conflicto de bloqueo optimista solo existe contra un SQLite real.
//

import Foundation
import SwiftData
import Testing
@testable import Yala

@Suite(.serialized)
@MainActor
struct SnapshotEnqueueSaveFailurePremiseTests {

    // MARK: - Pata 1: el journal comparte store con todo lo que encolan los tres productores

    @Test func journalSharesTheSyncMetaStoreWithEverythingTheEnqueueWrites() {
        let names = Set(SwiftDataConfiguration.syncMetaSchema.entities.map(\.name))
        // Lo que escribe `enqueueSnapshotRows` (filas, relojes por unidad, reloj del cursor), lo que escribe la
        // identidad (testigos) y el journal.
        for entity in ["SyncOutbox", "SyncUnitClock", "SyncCursor", "SyncIdentity", "MigrationState"] {
            #expect(names.contains(entity), "\(entity) ya no vive en el store sync-meta")
        }
        // Y el journal NO vive en el store personal: si estuviera en los dos, la pata 1 no diría nada.
        let personal = Set(SwiftDataConfiguration.personalSchema.entities.map(\.name))
        #expect(!personal.contains("MigrationState"))
    }

    // MARK: - Pata 2: un conflicto con otro contexto no hace lanzar el save

    /// El encolado del snapshot: actualiza el reloj del cursor y un reloj por unidad, e inserta filas de outbox. Otro
    /// contexto ha modificado el cursor y BORRADO el reloj por unidad entre medias. El save no lanza, y el del journal
    /// que viene detrás, tampoco.
    @Test func enqueueSaveSurvivesAConcurrentWriterOnTheSameRows() throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        let shared = ModelContext(fixture.container)
        shared.autosaveEnabled = false

        let cursor = SyncCursor(clockLatestHLC: "h0")
        let unitClock = SyncUnitClock(syncID: UUID(), entityTable: "transaction_items", unitHlcsJSON: "{}")
        let journal = MigrationState()
        journal.setPhase(.uploadingSnapshot)
        shared.insert(cursor)
        shared.insert(unitClock)
        shared.insert(journal)
        try shared.save()

        // El otro escritor, en su propio contexto, guarda primero.
        let other = ModelContext(fixture.container)
        let otherCursor = try #require(try other.fetch(FetchDescriptor<SyncCursor>()).first)
        otherCursor.clockLatestHLC = "h-ajeno"
        let otherClock = try #require(try other.fetch(FetchDescriptor<SyncUnitClock>()).first)
        other.delete(otherClock)
        try other.save()

        // El encolado sobre el contexto compartido, con su snapshot viejo de las dos filas.
        cursor.clockLatestHLC = "h1"
        unitClock.unitHlcsJSON = #"{"amount":"h1"}"#
        shared.insert(SyncOutbox(
            syncID: UUID(), entityType: "transaction_items", op: .upsert, hlc: "h1", fieldsJSON: "{}",
            author: CloudSyncEngine.outboxSaveAuthor))
        #expect(throws: Never.self) { try shared.save() }

        // El journal guarda detrás, y el disco lo tiene.
        journal.setPhase(.failedRollback)
        #expect(throws: Never.self) { try shared.save() }
        let fresh = ModelContext(fixture.container)
        let stored = try #require(try fresh.fetch(FetchDescriptor<MigrationState>()).first)
        #expect(stored.readPhase().phase == .failedRollback)
        #expect(try fresh.fetchCount(FetchDescriptor<SyncOutbox>()) == 1)
    }

    /// La identidad y el backfill del adopt: escriben `syncID` en filas de DOMINIO (store personal, con el espejo
    /// vivo) e insertan testigos en el sync-meta, todo en un save. El importador del espejo modifica una de esas filas
    /// y borra otra entre medias. El save no lanza, y el del journal, tampoco.
    @Test func identitySaveSurvivesTheMirrorImporterTouchingTheSameDomainRows() throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        let shared = ModelContext(fixture.container)
        shared.autosaveEnabled = false

        let kept = ExchangeRate(dateKey: "2026-10-01", base: "USD", rates: Data())
        let deleted = ExchangeRate(dateKey: "2026-10-02", base: "USD", rates: Data())
        let journal = MigrationState()
        journal.setPhase(.assigningIdentity)
        shared.insert(kept)
        shared.insert(deleted)
        shared.insert(journal)
        try shared.save()

        // El importador, en su contexto.
        let importer = ModelContext(fixture.container)
        let rates = try importer.fetch(FetchDescriptor<ExchangeRate>())
        let importedKept = try #require(rates.first { $0.dateKey == "2026-10-01" })
        let importedDeleted = try #require(rates.first { $0.dateKey == "2026-10-02" })
        importedKept.base = "EUR"
        importer.delete(importedDeleted)
        try importer.save()

        // El backfill sobre el contexto compartido, con su snapshot viejo de las dos filas.
        let keptID = UUID()
        kept.syncID = keptID
        deleted.syncID = UUID()
        shared.insert(SyncIdentity(syncID: keptID, entityType: SyncEntityType.exchangeRate, localAnchor: "a"))
        #expect(throws: Never.self) { try shared.save() }

        journal.setPhase(.failedRollback)
        #expect(throws: Never.self) { try shared.save() }
        let fresh = ModelContext(fixture.container)
        let stored = try #require(try fresh.fetch(FetchDescriptor<MigrationState>()).first)
        #expect(stored.readPhase().phase == .failedRollback)
        #expect(try fresh.fetchCount(FetchDescriptor<SyncIdentity>()) == 1)
    }

    // MARK: - Fixture: los dos stores de producción, en disco

    /// Un container con la forma del de producción: el store personal y el sync-meta, cada uno en su fichero, y un
    /// contexto que abarca los dos. Solo con `ExchangeRate` en el personal: no tiene relaciones, así que no arrastra
    /// el resto del schema (y con `cloudKitDatabase: .none`, regla de testing).
    @MainActor
    private struct Fixture {
        let container: ModelContainer
        let directory: URL

        init() throws {
            directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("SnapshotEnqueuePremise-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let personalSchema = Schema([ExchangeRate.self])
            let syncMetaSchema = SwiftDataConfiguration.syncMetaSchema
            let personal = ModelConfiguration(
                "Personal", schema: personalSchema, url: directory.appendingPathComponent("personal.store"),
                cloudKitDatabase: .none)
            let syncMeta = ModelConfiguration(
                "SyncMeta", schema: syncMetaSchema, url: directory.appendingPathComponent("syncmeta.store"),
                cloudKitDatabase: .none)
            // El schema del container une los dos. La lista repite la de `syncMetaSchema` (el `Schema` no devuelve sus
            // tipos): si se desalinean, el container no se monta y el test sale rojo, que es la señal que se quiere.
            let full = Schema([ExchangeRate.self] + Self.syncMetaTypes)
            container = try ModelContainer(for: full, configurations: personal, syncMeta)
        }

        static let syncMetaTypes: [any PersistentModel.Type] = [
            SyncIdentity.self, SyncOutbox.self, SyncCursor.self, SyncQuarantine.self, SyncDanglingRef.self,
            SyncUnitClock.self, MigrationState.self, GroupSyncOutbox.self, GroupSyncCursor.self,
        ]

        func cleanup() {
            do {
                try FileManager.default.removeItem(at: directory)
            } catch {
                #if DEBUG
                print("SnapshotEnqueueSaveFailurePremiseTests: no se pudo borrar \(directory.path): \(error)")
                #endif
            }
        }
    }
}
