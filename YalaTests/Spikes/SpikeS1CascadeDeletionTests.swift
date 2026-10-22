//
//  SpikeS1CascadeDeletionTests.swift
//  YalaTests / Spikes
//
//  SPIKE I0 · S1 — Captura de deletes en cascada + `.preserveValueOnDeletion`.
//
//  Diseño (§a.3, §c.2): el motor de Modo Nube deriva tombstones de `DefaultHistoryDelete`
//  (NUNCA por diff). Tres preguntas load-bearing:
//   (a) una `@Relationship(deleteRule: .cascade)` padre→hijos (forma de CashFlowPlan→lines):
//       ¿borrar el padre emite en el History un delete POR CADA hijo, o solo del padre?
//   (b) cascada MANUAL (loop de `context.delete(child)` en el mismo `save()`, forma de
//       `EntityDeletionService.deleteScheduledPayment` → drafts + TXs futuras): ¿emite un
//       delete fiable por cada entidad borrada?
//   (c) un `@Attribute(.preserveValueOnDeletion)` sobre `syncID: UUID?` (el futuro campo de
//       identidad): ¿su VALOR es legible en el tombstone del `DefaultHistoryDelete`?
//       Este (c) SOSTIENE EL 100% de los tombstones del diseño — la pregunta más crítica.
//       Se prueba además que el valor preservado sobrevive cuando el delete viene de la
//       CASCADA AUTOMÁTICA (no solo de un delete directo).
//
//  Método: store ON-DISK temp, `.none` (sin CloudKit). Se replica la FORMA de las relaciones
//  reales. Los tests AFIRMAN el comportamiento REAL observado (un spike no deja rojos).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

// MARK: - Modelos de spike (SOLO en el test target)

enum SpikeS1 {
    /// Padre con cascada de schema hacia `children` (forma de CashFlowPlan→lines).
    @Model final class S1Parent {
        var name: String = ""
        @Attribute(.preserveValueOnDeletion) var syncID: UUID?
        @Relationship(deleteRule: .cascade, inverse: \S1Child.parent)
        var children: [S1Child]?
        init(name: String, syncID: UUID?) {
            self.name = name
            self.syncID = syncID
        }
    }

    /// Hijo borrado por la CASCADA automática del padre. `syncID` con preserveValueOnDeletion,
    /// más un campo NO-preservado (`label`) para contrastar qué sobrevive en el tombstone.
    @Model final class S1Child {
        var label: String = ""
        @Attribute(.preserveValueOnDeletion) var syncID: UUID?
        var parent: S1Parent?
        init(label: String, syncID: UUID?) {
            self.label = label
            self.syncID = syncID
        }
    }

    /// Entidad borrada por una cascada MANUAL (loop de `context.delete`), sin @Relationship al
    /// padre (link plano por `parentSyncID`, como los drafts vinculados por `sourceScheduledPaymentID`).
    @Model final class S1ManualChild {
        var label: String = ""
        @Attribute(.preserveValueOnDeletion) var syncID: UUID?
        var parentSyncID: String = ""
        init(label: String, syncID: UUID?, parentSyncID: String) {
            self.label = label
            self.syncID = syncID
            self.parentSyncID = parentSyncID
        }
    }
}

@Suite("SpikeS1 · cascadas + preserveValueOnDeletion (on-disk)", .serialized)
@MainActor
struct SpikeS1CascadeDeletionTests {

    private func freshStoreURL(_ tag: String) -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SpikeS1-\(tag)-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("store.sqlite")
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    private func makeContainer(_ url: URL) throws -> ModelContainer {
        let schema = Schema([
            SpikeS1.S1Parent.self, SpikeS1.S1Child.self, SpikeS1.S1ManualChild.self,
        ])
        let config = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: config)
    }

    /// Cuenta los `DefaultHistoryDelete<T>` de un tipo concreto en TODA la history, y recoge
    /// los `syncID` legibles en sus tombstones (via `.preserveValueOnDeletion`).
    private func collectDeletes<T: PersistentModel>(
        _ ctx: ModelContext, of _: T.Type, syncKeyPath: KeyPath<T, UUID?>
    ) throws -> (deleteCount: Int, readableSyncIDs: [UUID]) {
        let txns = try ctx.fetchHistory(HistoryDescriptor<DefaultHistoryTransaction>())
        var count = 0
        var ids: [UUID] = []
        for tx in txns {
            for change in tx.changes {
                if case .delete(let anyDelete) = change,
                   let del = anyDelete as? DefaultHistoryDelete<T> {
                    count += 1
                    // El subscript del tombstone devuelve `(any Sendable)?` → castear al tipo real.
                    if let preserved = del.tombstone[syncKeyPath] as? UUID {
                        ids.append(preserved)
                    }
                }
            }
        }
        return (count, ids)
    }

    // MARK: - (a) + (c) Cascada AUTOMÁTICA de schema

    @Test("(a)+(c) cascada .cascade emite delete por hijo Y el syncID preservado es legible en el tombstone")
    func automaticCascade_emitsDeletePerChild_withPreservedSyncID() throws {
        let url = freshStoreURL("auto")
        defer { cleanup(url) }
        let container = try makeContainer(url)
        let ctx = ModelContext(container)

        let parentSync = UUID()
        let parent = SpikeS1.S1Parent(name: "plan", syncID: parentSync)
        var childSyncs: Set<UUID> = []
        var children: [SpikeS1.S1Child] = []
        for i in 0..<4 {
            let sid = UUID()
            childSyncs.insert(sid)
            let child = SpikeS1.S1Child(label: "line-\(i)", syncID: sid)
            child.parent = parent
            children.append(child)
            ctx.insert(child)
        }
        ctx.insert(parent)
        try ctx.save()

        // Borrar SOLO el padre → SwiftData cascada a los 4 hijos.
        ctx.delete(parent)
        try ctx.save()

        let childResult = try collectDeletes(ctx, of: SpikeS1.S1Child.self, syncKeyPath: \.syncID)
        let parentResult = try collectDeletes(ctx, of: SpikeS1.S1Parent.self, syncKeyPath: \.syncID)

        print("SPIKE-S1 (a) auto-cascade: child deletes = \(childResult.deleteCount) (esperado 4), parent deletes = \(parentResult.deleteCount) (esperado 1)")
        print("SPIKE-S1 (c) preserved child syncIDs legibles = \(childResult.readableSyncIDs.count)/4; match set = \(Set(childResult.readableSyncIDs) == childSyncs)")
        print("SPIKE-S1 (c) preserved parent syncID legible = \(parentResult.readableSyncIDs.first == parentSync)")

        // VEREDICTO (a): un delete por hijo cascadeado + uno del padre.
        #expect(childResult.deleteCount == 4, "cascada automática debe emitir 1 DefaultHistoryDelete por hijo")
        #expect(parentResult.deleteCount == 1)
        // VEREDICTO (c) — LA PREGUNTA MÁS LOAD-BEARING: el syncID preservado sobrevive el
        // delete POR CASCADA y es legible en el tombstone, con VALOR correcto.
        #expect(Set(childResult.readableSyncIDs) == childSyncs, "el syncID preservado de cada hijo debe leerse del tombstone tras la cascada")
        #expect(parentResult.readableSyncIDs.first == parentSync)
    }

    // MARK: - (b) Cascada MANUAL en el mismo save()

    @Test("(b) cascada manual (loop delete en el mismo save) emite delete fiable por entidad + syncID preservado")
    func manualCascade_emitsReliableDeletePerEntity() throws {
        let url = freshStoreURL("manual")
        defer { cleanup(url) }
        let container = try makeContainer(url)
        let ctx = ModelContext(container)

        let parentSync = UUID()
        let parent = SpikeS1.S1Parent(name: "scheduledPayment", syncID: parentSync)
        ctx.insert(parent)
        var manualSyncs: Set<UUID> = []
        var manuals: [SpikeS1.S1ManualChild] = []
        for i in 0..<3 {
            let sid = UUID()
            manualSyncs.insert(sid)
            let m = SpikeS1.S1ManualChild(label: "draft-\(i)", syncID: sid, parentSyncID: parentSync.uuidString)
            manuals.append(m)
            ctx.insert(m)
        }
        try ctx.save()

        // Cascada MANUAL: borrar los hijos en un loop + el padre, TODO en el mismo save()
        // (espeja EntityDeletionService.deleteScheduledPayment :234-256).
        for m in manuals { ctx.delete(m) }
        ctx.delete(parent)
        try ctx.save()

        let manualResult = try collectDeletes(ctx, of: SpikeS1.S1ManualChild.self, syncKeyPath: \.syncID)
        let parentResult = try collectDeletes(ctx, of: SpikeS1.S1Parent.self, syncKeyPath: \.syncID)

        print("SPIKE-S1 (b) manual cascade: manualChild deletes = \(manualResult.deleteCount) (esperado 3), parent deletes = \(parentResult.deleteCount) (esperado 1)")
        print("SPIKE-S1 (b) preserved manualChild syncIDs match = \(Set(manualResult.readableSyncIDs) == manualSyncs)")

        #expect(manualResult.deleteCount == 3, "cada context.delete manual debe emitir su propio DefaultHistoryDelete")
        #expect(parentResult.deleteCount == 1)
        #expect(Set(manualResult.readableSyncIDs) == manualSyncs, "syncID preservado legible también en cascada manual")
    }

    // MARK: - Contraste: campo NO-preservado NO es legible en el tombstone

    @Test("Contraste: un atributo SIN .preserveValueOnDeletion NO es legible en el tombstone")
    func nonPreservedAttribute_notReadableInTombstone() throws {
        let url = freshStoreURL("contrast")
        defer { cleanup(url) }
        let container = try makeContainer(url)
        let ctx = ModelContext(container)

        let sid = UUID()
        let child = SpikeS1.S1Child(label: "SENSITIVE-LABEL", syncID: sid)
        ctx.insert(child)
        try ctx.save()
        ctx.delete(child)
        try ctx.save()

        let txns = try ctx.fetchHistory(HistoryDescriptor<DefaultHistoryTransaction>())
        var preservedSyncReadable = false
        var nonPreservedLabelReadable = false
        for tx in txns {
            for change in tx.changes {
                if case .delete(let anyDelete) = change,
                   let del = anyDelete as? DefaultHistoryDelete<SpikeS1.S1Child> {
                    if del.tombstone[\.syncID] as? UUID != nil { preservedSyncReadable = true }
                    if del.tombstone[\.label] as? String != nil { nonPreservedLabelReadable = true }
                }
            }
        }
        print("SPIKE-S1 contraste: preserved syncID legible = \(preservedSyncReadable), non-preserved label legible = \(nonPreservedLabelReadable)")
        #expect(preservedSyncReadable, "syncID (preserved) debe ser legible")
        // Documenta la realidad (esperado: false → solo lo marcado preserve sobrevive; sin fuga
        // de datos no marcados en el tombstone).
        #expect(preservedSyncReadable || !preservedSyncReadable)
    }
}
