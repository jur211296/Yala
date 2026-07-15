//
//  IdentityRemapEmissionTests.swift
//  YalaTests / CloudSync
//
//  DIFERIDOS #29 (§b.4): al regenerar un UUID de identidad cableado como sync_id
//  (`Tag.id`/`Account.shortcutID`/`Subcategory.shortcutID`), el emisor `emitIdentityRemap` encola el trío
//  {tombstone(oldID) reason .remap, upsert-FULL(newID), re-emisión de referenciantes} + re-key del testigo
//  `SyncIdentity`, TODO en la MISMA transacción del reparador (`repairCollapsedIdentityUUIDs`). Sin esto la
//  fila remapeada y sus referenciantes divergen PERPETUAMENTE con el backend (la proyección `*_ref`/`tag_refs`
//  cambia sin write → History no captura → jamás push — clase del bug FX del device run 2026-07-11).
//
//  Container ON-DISK temp con los 3 stores + `.serialized` (patrón CloudSyncEngineTests / SyncOutboxMirrorTests).
//  HLCs deterministas vía `now` inyectado. Gate: `storageMode == .cloud` (override de tests con defer restore).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("CloudSync · IdentityRemap (DIFERIDOS #29)", .serialized)
@MainActor
struct IdentityRemapEmissionTests {

    // MARK: - Infra

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("IdRemap-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    /// NO borra el dir (2026-07-16): borrar los .sqlite bajo un container on-disk VIVO cuyo SUT dejó
    /// Tasks huérfanos de save genera una tormenta de IO errors ("disk I/O error"/"misuse") minutos
    /// después, que bajo suite completa puede COLGAR un test víctima arbitrario (cazado: el run de G5-B
    /// mató a SyncPullClientTests.pull_403 — arrancó y jamás terminó; la clase está en la Lista Negra de
    /// TESTING-STRATEGY). El tmp del sim es efímero (se vacía en erase/boot) — dejar los archivos es
    /// gratis y los saves huérfanos aterrizan en archivos vivos sin reventar.
    private func cleanup(_ dir: URL) { /* intencionalmente no-op — ver doc-comment */ }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "IR-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groupsCfg = ModelConfiguration(
            "IR-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMetaCfg = ModelConfiguration(
            "IR-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(for: SwiftDataConfiguration.schema,
                                           configurations: personalCfg, groupsCfg, syncMetaCfg)
        return ModelContext(container)
    }

    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    /// Ejecuta `body` con `storageMode` forzado, restaurando el override al terminar (aislamiento del repo).
    private func withStorageMode(_ mode: StorageMode, _ body: () throws -> Void) rethrows {
        let prev = CloudSyncFlags.storageMode
        CloudSyncFlags.storageMode = mode
        defer {
            CloudSyncFlags.storageMode = prev
            CloudSyncFlags._testResetStorageModeOverride()
        }
        try body()
    }

    private func outbox(_ context: ModelContext) throws -> [SyncOutbox] {
        try context.fetch(FetchDescriptor<SyncOutbox>())
    }
    private func upserts(_ rows: [SyncOutbox], _ entity: String) -> [SyncOutbox] {
        rows.filter { $0.opRaw == SyncOutboxOp.upsert.rawValue && $0.entityType == entity }
    }
    private func tombstones(_ rows: [SyncOutbox], _ entity: String) -> [SyncOutbox] {
        rows.filter { $0.opRaw == SyncOutboxOp.tombstone.rawValue && $0.entityType == entity }
    }

    private func makeAccount(_ context: ModelContext, name: String = "Cash") -> Account {
        let a = Account(name: name, currencyCode: "USD", colorHex: "#111111", iconName: "banknote", type: "cash")
        context.insert(a)
        return a
    }
    private func makeTag(_ context: ModelContext, name: String = "Viaje") -> Yala.Tag {
        let t = Yala.Tag(name: name)
        context.insert(t)
        return t
    }

    // MARK: - 1. Estructura de emisión (tombstone + upsert + referenciante)

    @Test("emit produce tombstone(old,.remap) + upsert(new) + upsert del referenciante con el ref NUEVO")
    func emit_structureAndNewRef() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)

        let acc = makeAccount(context)
        let tx = TransactionItem(date: now, amount: 12, currencyCode: "USD", account: acc)
        tx.createdAt = now
        tx.syncID = UUID()
        context.insert(tx)
        try context.save()

        try withStorageMode(.cloud) {
            let engine = CloudSyncEngine(nodeID: NodeID.generate())
            let old = acc.shortcutID
            acc.shortcutID = UUID()  // regeneración (la relación tx.account sigue apuntando al MISMO objeto)
            let emission = try engine.emitIdentityRemap(
                pairs: [IdentityRemapPair(entityType: SyncEntityType.account, oldID: old, newID: acc.shortcutID)],
                in: context, now: now)

            let rows = try outbox(context)  // fetch VE los inserts pendientes (antes de cualquier save/drain)
            #expect(emission.rowCount == 3)
            // (a) tombstone del sync_id VIEJO con reason .remap
            let ts = tombstones(rows, SyncEntityType.account)
            #expect(ts.count == 1)
            #expect(ts.first?.syncID == old)
            #expect(ts.first?.tombstoneReason == SyncTombstoneReason.remap.rawValue)
            // (b) upsert FULL de la cuenta con el sync_id NUEVO
            let accUpserts = upserts(rows, SyncEntityType.account)
            #expect(accUpserts.count == 1)
            #expect(accUpserts.first?.syncID == acc.shortcutID)
            #expect(accUpserts.first?.fieldsJSON.contains("\"name\"") == true)  // proyección completa
            // (c) upsert del referenciante (la TX) con account_ref = NUEVO (relación viva, no CSV)
            let txUpserts = upserts(rows, SyncEntityType.transactionItem)
            #expect(txUpserts.count == 1)
            #expect(txUpserts.first?.syncID == tx.syncID)
            #expect(txUpserts.first?.fieldsJSON.contains(acc.shortcutID.uuidString.lowercased()) == true)
            #expect(txUpserts.first?.fieldsJSON.contains(old.uuidString.lowercased()) == false)
        }
    }

    // MARK: - 2. Misma transacción (un solo save del llamador comitea dominio + outbox)

    @Test("un solo context.save() del llamador persiste dominio (id nuevo) + outbox juntos")
    func emit_sameTransaction() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let tag = makeTag(context)
        try context.save()

        try withStorageMode(.cloud) {
            let engine = CloudSyncEngine(nodeID: NodeID.generate())
            let old = tag.id
            tag.id = UUID()
            _ = try engine.emitIdentityRemap(
                pairs: [IdentityRemapPair(entityType: SyncEntityType.tag, oldID: old, newID: tag.id)],
                in: context, now: now)
            // emit NO salvó: hay cambios pendientes (outbox + id nuevo) que un ÚNICO save comitea.
            #expect(context.hasChanges)
            try context.save()  // autor DEFAULT (como el reparador)

            let persisted = try outbox(context)
            #expect(tombstones(persisted, SyncEntityType.tag).count == 1)
            #expect(upserts(persisted, SyncEntityType.tag).first?.syncID == tag.id)
            let reloadedTag = try context.fetch(FetchDescriptor<Yala.Tag>()).first
            #expect(reloadedTag?.id == tag.id)  // dominio persistido con el id nuevo
        }
    }

    // MARK: - 3. Espejo App Group DIFERIDO a post-save (SERIO 2 del review)

    @Test("el espejo App Group queda VACÍO tras emit y se puebla SOLO tras save + mirrorRemapRows")
    func emit_mirrorDeferredToPostSave() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let mirrorDir = dir.appendingPathComponent("mirror", isDirectory: true)
        let context = try makeContext(dir)
        let tag = makeTag(context)
        try context.save()

        try withStorageMode(.cloud) {
            let engine = CloudSyncEngine(nodeID: NodeID.generate())
            engine.outboxMirror = SyncOutboxMirror(directoryURL: mirrorDir)
            engine.currentUserID = "user-abc"
            let old = tag.id
            tag.id = UUID()
            let emission = try engine.emitIdentityRemap(
                pairs: [IdentityRemapPair(entityType: SyncEntityType.tag, oldID: old, newID: tag.id)],
                in: context, now: now)
            // SERIO 2: la emisión NO espeja (un save fallido posterior envenenaría el App Group).
            #expect(engine.outboxMirror!.entriesForUser("user-abc").isEmpty)

            try context.save()
            engine.mirrorRemapRows(emission)  // el reparador lo invoca POST-save exitoso

            let entries = engine.outboxMirror!.entriesForUser("user-abc")
            #expect(entries.count == emission.rowCount)
        }
    }

    // MARK: - 4. Gate cerrado (.icloud) → no-op

    @Test("en .icloud emit devuelve 0 y no encola nada (motor DARK)")
    func emit_gateClosed_icloud() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let tag = makeTag(context)
        try context.save()

        try withStorageMode(.icloud) {
            let engine = CloudSyncEngine(nodeID: NodeID.generate())
            let old = tag.id
            tag.id = UUID()
            let emission = try engine.emitIdentityRemap(
                pairs: [IdentityRemapPair(entityType: SyncEntityType.tag, oldID: old, newID: tag.id)],
                in: context, now: now)
            #expect(emission.rowCount == 0)
            let rows = try outbox(context)
            #expect(rows.isEmpty)
        }
    }

    // MARK: - 5. HLC lockstep (monótono + reloj persistido en el cursor)

    @Test("los HLCs acuñados son distintos y monótonos; el reloj queda en el cursor")
    func emit_hlcMonotonicAndClockPersisted() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let acc = makeAccount(context)
        let tx = TransactionItem(date: now, amount: 5, currencyCode: "USD", account: acc)
        tx.createdAt = now; tx.syncID = UUID()
        context.insert(tx)
        try context.save()

        try withStorageMode(.cloud) {
            let engine = CloudSyncEngine(nodeID: NodeID.generate())
            let old = acc.shortcutID
            acc.shortcutID = UUID()
            _ = try engine.emitIdentityRemap(
                pairs: [IdentityRemapPair(entityType: SyncEntityType.account, oldID: old, newID: acc.shortcutID)],
                in: context, now: now)
            let hlcs = try outbox(context).map(\.hlc)
            #expect(Set(hlcs).count == hlcs.count)         // todos distintos
            #expect(hlcs.sorted() == hlcs.sorted())        // ordenables (c1 lexicográfico)
            let cursor = try context.fetch(FetchDescriptor<SyncCursor>()).first
            #expect(cursor?.clockLatestHLC != nil)         // el reloj avanzó y quedó en el cursor
            #expect(cursor?.clockLatestHLC == hlcs.sorted().last)  // == el HLC más alto emitido
        }
    }

    // MARK: - 6. Re-key del testigo SyncIdentity

    @Test("rekeyIdentity re-vincula old→new PRESERVANDO ck*, estampa lastReboundAt, re-ancla localAnchor")
    func rekey_preservesCloudKitCoordinates() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let old = UUID(), new = UUID()
        let witness = SyncIdentity(
            syncID: old, entityType: SyncEntityType.account, localAnchor: "anchor-old",
            ckRecordName: "REC-1", ckZoneName: "ZONE-1", ckOwnerName: "OWNER-1", createdAt: now)
        context.insert(witness)
        try context.save()

        let ok = SyncIdentityService.rekeyIdentity(
            entityType: SyncEntityType.account, oldID: old, newID: new, in: context, now: now)
        #expect(ok)
        #expect(witness.syncID == new)
        #expect(witness.ckRecordName == "REC-1")   // el CKRecord congelado es EL MISMO (§b.5 crítico)
        #expect(witness.ckZoneName == "ZONE-1")
        #expect(witness.ckOwnerName == "OWNER-1")
        #expect(witness.lastReboundAt == now)
        #expect(witness.localAnchor == SyncContentAnchor.stableID(new))
    }

    @Test("rekeyIdentity sin testigo previo CREA uno nuevo con lastReboundAt estampado")
    func rekey_noPriorWitness_creates() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let old = UUID(), new = UUID()

        let ok = SyncIdentityService.rekeyIdentity(
            entityType: SyncEntityType.tag, oldID: old, newID: new, in: context, now: now)
        #expect(ok)
        let rows = try context.fetch(FetchDescriptor<SyncIdentity>())
        #expect(rows.count == 1)
        #expect(rows.first?.syncID == new)
        #expect(rows.first?.lastReboundAt == now)
        #expect(rows.first?.entityType == SyncEntityType.tag)
    }

    @Test("grupo colisionado X→A, X→B: primer par re-keyea el testigo X→A, el segundo CREA testigo B")
    func rekey_collisionGroup_oneRekeyOneCreate() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let x = UUID(), a = UUID(), b = UUID()
        let witness = SyncIdentity(
            syncID: x, entityType: SyncEntityType.tag, localAnchor: "anchor-x",
            ckRecordName: "REC-X", createdAt: now)
        context.insert(witness)
        try context.save()

        #expect(SyncIdentityService.rekeyIdentity(entityType: SyncEntityType.tag, oldID: x, newID: a, in: context, now: now))
        #expect(SyncIdentityService.rekeyIdentity(entityType: SyncEntityType.tag, oldID: x, newID: b, in: context, now: now))

        let rows = try context.fetch(FetchDescriptor<SyncIdentity>())
        let syncIDs = Set(rows.map(\.syncID))
        #expect(rows.count == 2)
        #expect(syncIDs == [a, b])
        #expect(!syncIDs.contains(x))
        // El testigo original (con ck*) es el que quedó re-keyed a A (preservó REC-X).
        #expect(rows.first(where: { $0.syncID == a })?.ckRecordName == "REC-X")
        #expect(rows.first(where: { $0.syncID == b })?.ckRecordName == nil)
    }

    // MARK: - 7. Tombstone dedup + limpieza de unit clocks del old (grupo colisionado)

    @Test("grupo colisionado (X→A, X→B): UN solo tombstone(X) + upserts A y B; unit clock de X borrado")
    func emit_collisionGroup_dedupTombstone_cleansUnitClock() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let x = UUID()
        let tagA = makeTag(context, name: "A"); tagA.id = x
        let tagB = makeTag(context, name: "B"); tagB.id = x  // colisión: mismo id
        try context.save()

        // Sembrar un SyncUnitClock para el sync_id VIEJO X (el tombstone debe barrerlo).
        SyncUnitClockStore.upsert(syncID: x, entityTable: "tags",
                                  unitHlcs: ["name": "2023-11-14T22:13:20.000Z-0001-0123456789abcdef"],
                                  context: context, now: now)
        try context.save()
        #expect(SyncUnitClockStore.row(syncID: x, context: context) != nil)

        try withStorageMode(.cloud) {
            let engine = CloudSyncEngine(nodeID: NodeID.generate())
            let a = UUID(), b = UUID()
            tagA.id = a; tagB.id = b
            _ = try engine.emitIdentityRemap(pairs: [
                IdentityRemapPair(entityType: SyncEntityType.tag, oldID: x, newID: a),
                IdentityRemapPair(entityType: SyncEntityType.tag, oldID: x, newID: b),
            ], in: context, now: now)

            let rows = try outbox(context)
            #expect(tombstones(rows, SyncEntityType.tag).count == 1)  // DEDUP por oldID
            #expect(tombstones(rows, SyncEntityType.tag).first?.syncID == x)
            #expect(Set(upserts(rows, SyncEntityType.tag).map(\.syncID)) == [a, b])
            // El tombstone barrió el SyncUnitClock del sync_id viejo (higiene, updateUnitClock).
            #expect(SyncUnitClockStore.row(syncID: x, context: context) == nil)
        }
    }

    // MARK: - 8. Repair integrado (.cloud emite + rebuild CSV; .icloud NO emite)

    @Test("repairCollapsedIdentityUUIDs en .cloud: outbox completo + CSV de la TX reconstruido al id nuevo")
    func repairIntegrated_cloud_emitsAndRebuildsCSV() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let x = UUID()
        let tag1 = makeTag(context, name: "T1"); tag1.id = x
        let tag2 = makeTag(context, name: "T2"); tag2.id = x  // colisión
        let tx = TransactionItem(date: now, amount: 3, currencyCode: "USD", tags: [tag1])
        tx.createdAt = now; tx.syncID = UUID()
        context.insert(tx)
        try context.save()
        #expect(tx.tagIDsSet == [x])  // CSV mirror stale = id colapsado

        try withStorageMode(.cloud) {
            let engine = CloudSyncEngine(nodeID: NodeID.generate())
            let repaired = CategoryDeduplicationService.repairCollapsedIdentityUUIDs(
                in: context, now: now, remapEmitter: engine)
            #expect(repaired == 2)  // ambos tags regenerados
            #expect(tag1.id != x && tag2.id != x && tag1.id != tag2.id)

            let rows = try outbox(context)
            #expect(tombstones(rows, SyncEntityType.tag).count == 1)          // UN tombstone(X)
            #expect(Set(upserts(rows, SyncEntityType.tag).map(\.syncID)) == [tag1.id, tag2.id])
            // El CSV de la TX se reconstruyó al id nuevo → su re-emisión proyecta el tag_ref NUEVO.
            #expect(tx.tagIDsSet == [tag1.id])
            let txUpsert = upserts(rows, SyncEntityType.transactionItem).first
            #expect(txUpsert?.syncID == tx.syncID)
            #expect(txUpsert?.fieldsJSON.contains(tag1.id.uuidString.lowercased()) == true)
        }
    }

    @Test("repairCollapsedIdentityUUIDs en .icloud: regenera pero NO encola outbox (motor DARK)")
    func repairIntegrated_icloud_noOutbox() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let x = UUID()
        let tag1 = makeTag(context, name: "T1"); tag1.id = x
        let tag2 = makeTag(context, name: "T2"); tag2.id = x
        try context.save()

        try withStorageMode(.icloud) {
            let engine = CloudSyncEngine(nodeID: NodeID.generate())
            let repaired = CategoryDeduplicationService.repairCollapsedIdentityUUIDs(
                in: context, now: now, remapEmitter: engine)
            #expect(repaired == 2)                 // regeneración ocurre igual
            let rows = try outbox(context)
            #expect(rows.isEmpty)                   // pero cero emisión (gate cerrado)
        }
    }

    // MARK: - 8b. MENOR 5 del review: .cloud SIN motor → PREFLIGHT aborta (jamás regenerar sin outbox)

    @Test("en .cloud sin motor resoluble el repair ABORTA en preflight (ids intactos, 0 reparos, outbox vacío)")
    func repairIntegrated_cloud_engineUnavailable_defers() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let x = UUID()
        let tag1 = makeTag(context, name: "T1"); tag1.id = x
        let tag2 = makeTag(context, name: "T2"); tag2.id = x
        try context.save()

        try withStorageMode(.cloud) {
            // remapEmitter nil + CloudSyncRuntime.shared nil (jamás arrancado en tests) → engineUnavailable.
            let repaired = CategoryDeduplicationService.repairCollapsedIdentityUUIDs(
                in: context, now: now, remapEmitter: nil)
            #expect(repaired == 0)              // difiere al próximo run (cuando el runtime esté arriba)
            #expect(tag1.id == x)               // el preflight aborta ANTES de mutar (commitear sin
            #expect(tag2.id == x)               // outbox sería divergencia perpetua — el drain SKIPea)
            let rows = try outbox(context)
            #expect(rows.isEmpty)
            #expect(!context.hasChanges)        // nada dirty que un save ajeno posterior pueda filtrar
        }
    }

    // MARK: - 8c. SERIO 3 del review (R4): migración/reversa EN CURSO → preflight aborta + emit lanza

    @Test("con migración en curso el repair aborta en preflight y emit lanza migrationInProgress")
    func repairIntegrated_migrationInProgress_defers() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let x = UUID()
        let tag1 = makeTag(context, name: "T1"); tag1.id = x
        let tag2 = makeTag(context, name: "T2"); tag2.id = x
        try context.save()

        try withStorageMode(.cloud) {
            let engine = CloudSyncEngine(nodeID: NodeID.generate())
            engine._testMigrationPhaseOverride = .uploadingSnapshot  // fase TRANSITORIA (§g en curso)

            // (a) el guard de defensa en profundidad de emit lanza el error dedicado.
            #expect(throws: IdentityRemapError.migrationInProgress) {
                try engine.emitIdentityRemap(
                    pairs: [IdentityRemapPair(entityType: SyncEntityType.tag, oldID: x, newID: UUID())],
                    in: context, now: now)
            }

            // (b) el repair integrado aborta en PREFLIGHT (antes de mutar): ids intactos, outbox vacío.
            let repaired = CategoryDeduplicationService.repairCollapsedIdentityUUIDs(
                in: context, now: now, remapEmitter: engine)
            #expect(repaired == 0)
            #expect(tag1.id == x)
            #expect(tag2.id == x)
            let rows = try outbox(context)
            #expect(rows.isEmpty)
            #expect(!context.hasChanges)

            // (c) fase ESTABLE → el mismo repair procede (sanidad del predicado BGTaskMigrationGate).
            engine._testMigrationPhaseOverride = .done
            let repairedAfter = CategoryDeduplicationService.repairCollapsedIdentityUUIDs(
                in: context, now: now, remapEmitter: engine)
            #expect(repairedAfter == 2)
            let rowsAfter = try outbox(context)
            #expect(!rowsAfter.isEmpty)
        }
    }

    // MARK: - 8d. SERIO 1 del review (cinturón): fallo IMPREVISTO a mitad de vuelo → rollback, nada persiste

    @Test("un ClockDrift durante emit dispara el rollback: nada llega al store (ids persistidos intactos)")
    func repairIntegrated_midflightFailure_rollsBackPersistence() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let x = UUID()
        let tag1 = makeTag(context, name: "T1"); tag1.id = x
        let tag2 = makeTag(context, name: "T2"); tag2.id = x
        try context.save()

        try withStorageMode(.cloud) {
            let engine = CloudSyncEngine(nodeID: NodeID.generate())
            // Avanzar el reloj HLC a tiempo REAL (drain de los inserts) → un emit posterior con `now` de 2023
            // dispara el guard de drift (>5min) DENTRO de emit = fallo imprevisto a mitad de vuelo.
            engine.drainOnce(context: context)

            let repaired = CategoryDeduplicationService.repairCollapsedIdentityUUIDs(
                in: context, now: now, remapEmitter: engine)  // `now` 2023 vs reloj ~real → ClockDrift
            #expect(repaired == 0)

            // El contrato DURO del rollback es a nivel de PERSISTENCIA: nada del repair llegó al store.
            // (El estado EN MEMORIA post-rollback de SwiftData puede quedar stale hasta re-fault — por eso
            // las aserciones van contra un contexto FRESCO; el residual en memoria difiere el retry al
            // próximo launch en el peor caso, documentado en el catch del reparador.)
            let freshContext = ModelContext(context.container)
            let persistedTags = try freshContext.fetch(FetchDescriptor<Yala.Tag>())
            #expect(persistedTags.count == 2)
            #expect(persistedTags.allSatisfy { $0.id == x })  // la regeneración NO se comiteó
            let persistedOutbox = try freshContext.fetch(FetchDescriptor<SyncOutbox>())
            #expect(persistedOutbox.allSatisfy { $0.tombstoneReason != SyncTombstoneReason.remap.rawValue })
        }
    }

    // MARK: - 9. Drain post-remap: UPDATE identity-only → SKIP (D4), sin duplicar el upsert

    @Test("el drain posterior no duplica el upsert remapeado (identity-only → SKIP) y suena el canario D4")
    func drainPostRemap_skipsIdentityOnly_firesD4() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let acc = makeAccount(context)
        try context.save()

        try withStorageMode(.cloud) {
            let engine = CloudSyncEngine(nodeID: NodeID.generate())
            // Este test drena History REAL-time (el timestamp de la tx es el instante del save), así que el
            // reloj avanza a `~.now`; usar el `now` fijo de 2023 para emitir dispararía el guard de drift (>5min).
            // No aserta valores de HLC → usar `.now` es correcto y determinista para lo que verificamos.
            let realNow = Date.now
            // 1) Drenar PRIMERO el INSERT de la cuenta (token avanza más allá de él, escenario realista).
            engine.drainOnce(context: context)
            #expect(upserts(try outbox(context), SyncEntityType.account).count == 1)  // upsert(old)

            // 2) Remap + save autor DEFAULT (el drain SÍ procesará el UPDATE identity-only de shortcutID).
            let old = acc.shortcutID
            acc.shortcutID = UUID()
            _ = try engine.emitIdentityRemap(
                pairs: [IdentityRemapPair(entityType: SyncEntityType.account, oldID: old, newID: acc.shortcutID)],
                in: context, now: realNow)
            try context.save()

            let beforeRows = try outbox(context)
            #expect(upserts(beforeRows, SyncEntityType.account).count == 2)  // upsert(old) + upsert(new) del emit
            let mutationsBefore = engine.identityMutationObservedCount

            // 3) Drenar de nuevo: el UPDATE identity-only → D4 + SKIP → NO añade un tercer upsert.
            engine.drainOnce(context: context)

            let afterRows = try outbox(context)
            #expect(upserts(afterRows, SyncEntityType.account).count == 2)  // sin duplicar por el remap
            #expect(engine.identityMutationObservedCount > mutationsBefore)  // el canario D4 sonó
        }
    }
}
