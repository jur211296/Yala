//
//  SpikeS4IntentOutOfBandTests.swift
//  YalaTests / Spikes
//
//  SPIKE I0 · S4 — App Intent crea entidad sin-clave out-of-band + ventana create→delete
//  ANTES de cualquier vuelta de drain.
//
//  PREMISA DEL DISEÑO OBSOLETA (mejor de lo esperado): el diseño referencia
//  `QuickExpenseIntent.swift:208,577` (init directo de `InboxDraft` + `save()` sobre un 2º
//  ModelContainer, SIN pasar por `DraftService`). En jul-2026 los intents de Apple Pay y Siri
//  migraron al patrón de cola App Group (`ApplePayPendingStore`/`SiriPendingStore`) → YA NO
//  tocan SwiftData. Inventario verificado (ver mensaje del spike): CERO write-sites de SwiftData
//  en intents. La ventana "create-sin-syncID desde un intent" NO existe hoy → no hay 2º
//  ModelContainer sobre el store. Queda por validar la parte GENÉRICA del diseño (§c.2, §a.3):
//  qué ve el History cuando una entidad se crea y se borra ANTES de cualquier drain, y si el
//  `syncID` preservado (o su ausencia) es legible → sostiene el breadcrumb `CloudSyncIdentityGap`.
//
//  Escenarios (store on-disk, `.none`):
//   (i)  create+save → delete+save en transacciones SEPARADAS, syncID NUNCA asignado
//        (el flujo "App Intent crea, usuario borra desde Inbox antes del drain").
//        → ¿el History muestra insert Y delete? ¿el tombstone lleva syncID nil (el gap)?
//   (ii) create+delete en el MISMO save() (sin save intermedio) → ¿el History coalescea el
//        net-zero (no registra nada) o registra ambos?
//   (iii) create CON syncID asignado (barrido defensivo / gate) → delete → tombstone lleva el
//        syncID → confirma que asignar syncID ANTES del delete CIERRA el gap.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

enum SpikeS4 {
    /// Forma de `InboxDraft`: entidad sin-clave creable out-of-band, con syncID preservado opcional.
    @Model final class S4Draft {
        var text: String = ""
        @Attribute(.preserveValueOnDeletion) var syncID: UUID?
        init(text: String, syncID: UUID? = nil) {
            self.text = text; self.syncID = syncID
        }
    }
}

/// Qué observa el History para una entidad en una ventana dada.
struct HistoryObservation: CustomStringConvertible {
    var insertCount: Int
    var deleteCount: Int
    var tombstoneSyncIDs: [UUID?] // por cada delete: el syncID leído (nil = gap)
    var description: String {
        "inserts=\(insertCount) deletes=\(deleteCount) tombstoneSyncIDs=\(tombstoneSyncIDs.map { $0?.uuidString ?? "nil" })"
    }
}

@Suite("SpikeS4 · create+delete out-of-band antes del drain (on-disk)", .serialized)
@MainActor
struct SpikeS4IntentOutOfBandTests {

    private func freshStoreURL(_ tag: String) -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SpikeS4-\(tag)-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("store.sqlite")
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    private func makeContainer(_ url: URL) throws -> ModelContainer {
        let schema = Schema([SpikeS4.S4Draft.self])
        return try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none))
    }

    private func observe(_ ctx: ModelContext) throws -> HistoryObservation {
        // El subscript del tombstone devuelve `(any Sendable)?` → castear al tipo real (UUID).
        let syncKP: KeyPath<SpikeS4.S4Draft, UUID?> = \.syncID
        let txns = try ctx.fetchHistory(HistoryDescriptor<DefaultHistoryTransaction>())
        var inserts = 0, deletes = 0
        var tombs: [UUID?] = []
        for tx in txns {
            for change in tx.changes {
                switch change {
                case .insert(let c):
                    if c is DefaultHistoryInsert<SpikeS4.S4Draft> { inserts += 1 }
                case .delete(let c):
                    if let d = c as? DefaultHistoryDelete<SpikeS4.S4Draft> {
                        deletes += 1
                        tombs.append(d.tombstone[syncKP] as? UUID)
                    }
                case .update:
                    break
                }
            }
        }
        return HistoryObservation(insertCount: inserts, deleteCount: deletes, tombstoneSyncIDs: tombs)
    }

    // MARK: - (i) create+save → delete+save separados, syncID NUNCA asignado (el gap)

    @Test("(i) create y delete en saves SEPARADOS, sin syncID → History ve insert+delete; tombstone syncID = nil (el gap)")
    func createThenDelete_separateSaves_noSyncID() throws {
        let url = freshStoreURL("gap")
        defer { cleanup(url) }
        let ctx = ModelContext(try makeContainer(url))

        let draft = SpikeS4.S4Draft(text: "apple-pay-draft", syncID: nil)
        ctx.insert(draft)
        try ctx.save()          // create (drain aún no corrió)
        ctx.delete(draft)
        try ctx.save()          // delete inmediato desde Inbox

        let obs = try observe(ctx)
        print("SPIKE-S4 (i) \(obs)")
        #expect(obs.insertCount == 1)
        #expect(obs.deleteCount == 1, "un create+delete en saves separados debe emitir insert Y delete en la history")
        // El gap: el tombstone lleva syncID nil → el motor debe registrar CloudSyncIdentityGap
        // (benigno para InboxDraft; escala a syncID síncrono para TransactionItem).
        #expect(obs.tombstoneSyncIDs == [nil], "sin syncID asignado, el tombstone del delete no puede reconstruir identidad")
    }

    // MARK: - (ii) create+delete en el MISMO save() (net-zero) → ¿coalesce?

    @Test("(ii) create+delete en el MISMO save() → observar si el History coalescea el net-zero")
    func createAndDelete_sameSave_coalescing() throws {
        let url = freshStoreURL("coalesce")
        defer { cleanup(url) }
        let ctx = ModelContext(try makeContainer(url))

        let draft = SpikeS4.S4Draft(text: "ephemeral", syncID: UUID())
        ctx.insert(draft)
        ctx.delete(draft)
        try ctx.save()          // NUNCA se persistió un estado intermedio

        let obs = try observe(ctx)
        print("SPIKE-S4 (ii) same-save net-zero → \(obs)")
        // Documentamos la realidad: Core Data/SwiftData típicamente NO registra un objeto
        // insertado y borrado en el mismo save (net-zero → nada que subir → sin tombstone
        // espurio, que es lo DESEABLE para el diseño). Afirmación adaptativa.
        #expect(obs.insertCount >= 0 && obs.deleteCount >= 0, "outcome documentado: \(obs)")
    }

    // MARK: - (iii) create CON syncID (barrido/gate) → delete → tombstone lleva el syncID

    @Test("(iii) syncID asignado ANTES del delete → el tombstone lo lleva → gap CERRADO")
    func syncIDAssignedBeforeDelete_closesGap() throws {
        let url = freshStoreURL("closed")
        defer { cleanup(url) }
        let ctx = ModelContext(try makeContainer(url))

        let sid = UUID()
        let draft = SpikeS4.S4Draft(text: "swept", syncID: sid)
        ctx.insert(draft)
        try ctx.save()          // el barrido defensivo del drain le asignó syncID al crear/arrancar
        ctx.delete(draft)
        try ctx.save()

        let obs = try observe(ctx)
        print("SPIKE-S4 (iii) syncID-antes-del-delete → \(obs)")
        #expect(obs.deleteCount == 1)
        #expect(obs.tombstoneSyncIDs == [sid], "con syncID asignado antes del delete, el tombstone reconstruye la identidad → gap cerrado")
    }
}
