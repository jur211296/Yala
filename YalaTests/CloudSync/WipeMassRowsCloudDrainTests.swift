//
//  WipeMassRowsCloudDrainTests.swift
//  YalaTests / CloudSync
//
//  Caracterización (Vaciar v2, §3.3.1 punto 6 — gate de QA NO bloqueante, D2): "Vaciar mis datos"
//  (`DataWipeService.wipeAllUserData`) borra el corpus personal por FILAS. En modo nube `.cloud` esos
//  deletes NO se replican a iCloud (el mirror está OFF) sino que el motor los captura de la History y los
//  drena al outbox como TOMBSTONES hacia el backend. Este test caracteriza ESE volumen: cuántas filas de
//  outbox produce un vaciado completo, para dimensionar el drain antes de encender Vaciar en `.cloud`.
//
//  ⚠️ Caracteriza el PATH BACKEND `.cloud` (outbox/drain, substrato del `multiDeviceResidual` D9), NO el
//  export CloudKit del `.icloud` (mirror de NSPersistentCloudKitContainer — mecanismo distinto). El
//  resultado se documenta en `qa/cloud/README.md §Vaciar (wipe masivo por filas)`.
//
//  Molde: container ON-DISK con los 3 stores (History es por-CONTAINER, no fiable in-memory —
//  `CloudSyncEngineTests`) + snapshot/restore del `persistentDomain` de `.standard` en `defer` porque
//  `wipeAllUserData` resetea prefs/singletons (`DataWipePreservesGroupsTests`). `.serialized`.
//
//  LOAD-BEARING: el `drainOnce` INTERMEDIO (seed → save → DRAIN → wipe → drain) es obligatorio. Sin él, los
//  deletes salen SIN syncID asignado → *identity gap*, NO tombstone (`CloudSyncEngineTests:223-240`). El
//  primer drain asigna el syncID a cada fila sync-eligible; el segundo lo emite como tombstone.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("Vaciar · wipe masivo por filas → tombstones al outbox (caracterización)", .serialized)
@MainActor
struct WipeMassRowsCloudDrainTests {

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("WipeMassRows-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ dir: URL) { try? FileManager.default.removeItem(at: dir) }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "WMR-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groupsCfg = ModelConfiguration(
            "WMR-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMetaCfg = ModelConfiguration(
            "WMR-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: SwiftDataConfiguration.schema,
            configurations: personalCfg, groupsCfg, syncMetaCfg)
        return ModelContext(container)
    }

    private func outboxRows(_ context: ModelContext) throws -> [SyncOutbox] {
        try context.fetch(FetchDescriptor<SyncOutbox>())
    }

    /// Caracteriza: cada fila personal sync-eligible que existía al vaciar produce EXACTAMENTE un tombstone
    /// con su syncID preservado. El volumen del drain es, por tanto, ~1:1 con el corpus borrado.
    @Test func wipe_emitsOneTombstonePerSeededSyncableRow_carryingSyncID() throws {
        // Proteger `.standard` (wipeAllUserData resetea prefs/singletons en su paso 2/3).
        let defaults = UserDefaults.standard
        let domain = Bundle.main.bundleIdentifier ?? "com.yala.app"
        let snapshot = defaults.persistentDomain(forName: domain) ?? [:]
        defer { defaults.setPersistentDomain(snapshot, forName: domain) }

        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        // Corpus personal sync-eligible CONOCIDO (bare — sin relaciones, para un conteo determinista).
        for i in 0..<8 {
            let tx = TransactionItem(
                date: Date(timeIntervalSince1970: 1_700_000_000), amount: Double(i + 1), currencyCode: "USD")
            tx.createdAt = Date(timeIntervalSince1970: 1_700_000_000)
            context.insert(tx)
        }
        context.insert(Account(
            name: "Efectivo", currencyCode: "USD", colorHex: "#111111", iconName: "banknote", type: "cash"))
        context.insert(Account(
            name: "Banco", currencyCode: "USD", colorHex: "#222222", iconName: "banknote", type: "bank"))
        context.insert(Yala.Tag(name: "Comida"))
        context.insert(Yala.Tag(name: "Viaje"))
        try context.save()

        // Drain INTERMEDIO (load-bearing): asigna syncID a cada fila sync-eligible → upserts.
        let engine = CloudSyncEngine()
        engine.drainOnce(context: context)

        let afterSeed = try outboxRows(context)
        let upsertRows = afterSeed.filter { $0.opRaw == SyncOutboxOp.upsert.rawValue }
        let seededSyncIDs = Set(upsertRows.map(\.syncID))
        #expect(!seededSyncIDs.isEmpty, "el drain intermedio debe emitir upserts con syncID")

        // Vaciado REAL por filas (broadcastSignal:false: no tocar el iCloud KV en el test).
        try DataWipeService.wipeAllUserData(
            in: context, reseedInitialData: false, broadcastSignal: false)

        // Segundo drain: los deletes salen como tombstones.
        engine.drainOnce(context: context)

        let all = try outboxRows(context)
        let tombstones = all.filter { $0.opRaw == SyncOutboxOp.tombstone.rawValue }
        let tombstoneSyncIDs = Set(tombstones.map(\.syncID))

        // CARACTERIZACIÓN: TODA fila sembrada sync-eligible se propaga como tombstone (borrado visible al
        // backend), y cada tombstone porta un syncID real (no un identity-gap por falta del drain intermedio).
        #expect(seededSyncIDs.isSubset(of: tombstoneSyncIDs),
                "toda fila sync-eligible borrada debe emitir su tombstone: seeded=\(seededSyncIDs.count) tombstones=\(tombstoneSyncIDs.count)")
        #expect(tombstones.allSatisfy { $0.syncID != UUID(uuidString: "00000000-0000-0000-0000-000000000000") },
                "ningún tombstone debe portar el syncID nulo (identity gap)")
        // Volumen ~1:1 con el corpus: 1 tombstone por fila sembrada (documentado en qa/cloud/README §Vaciar).
        #expect(tombstones.count == seededSyncIDs.count,
                "volumen esperado 1:1 — tombstones=\(tombstones.count) vs seeded=\(seededSyncIDs.count)")
    }
}
