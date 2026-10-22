//
//  SpikeS3MultiStoreHistoryTests.swift
//  YalaTests / Spikes
//
//  SPIKE I0 · S3 — History atribuido POR-STORE con 2 stores en un mismo mainContext.
//
//  Réplica del setup de producción (`YalaApp.sharedModelContainer`): UN `ModelContainer`
//  con DOS `ModelConfiguration` (dos URLs on-disk distintas; en prod personal `.private` +
//  grupos `.none` — aquí ambos `.none`), tipos "personales" en el store 1 y tipos "grupos"
//  en el store 2. Un `save()` del mainContext que toca AMBOS stores.
//
//  Preguntas (diseño §S3):
//   1. ¿Las transacciones de History quedan atribuidas a su store respectivo?
//   2. Prueba NEGATIVA (anti-fuga): un fetch de history "del store personal" ¿devuelve CERO
//      cambios de los tipos del OTRO store? (evita filtrar datos de Grupos al backend personal).
//   3. ¿Qué mecanismo de aislamiento existe DE VERDAD? ¿`HistoryDescriptor` permite scoping por
//      store (via `DefaultHistoryTransaction.storeIdentifier`), o el history es por-container y
//      hay que filtrar por entity type (fallback del diseño → los 16 personales)?
//

import Foundation
import SwiftData
import Testing

@testable import Yala

enum SpikeS3 {
    /// Tipo del store "personal".
    @Model final class S3Personal {
        var name: String = ""
        var syncID: UUID?
        init(name: String, syncID: UUID? = nil) {
            self.name = name; self.syncID = syncID
        }
    }
    /// Tipo del store "grupos" — NUNCA debe filtrarse al drain personal.
    @Model final class S3Groups {
        var secret: String = ""
        init(secret: String) { self.secret = secret }
    }
}

@Suite("SpikeS3 · history por-store con 2 stores en un mainContext (on-disk)", .serialized)
@MainActor
struct SpikeS3MultiStoreHistoryTests {

    private func freshDir(_ tag: String) -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SpikeS3-\(tag)-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ dir: URL) {
        try? FileManager.default.removeItem(at: dir)
    }

    /// Container de DOS stores, espejo de producción: full schema + 2 configs con URLs distintas.
    private func makeTwoStoreContainer(_ dir: URL) throws -> (ModelContainer, URL, URL) {
        let personalURL = dir.appendingPathComponent("personal.sqlite")
        let groupsURL = dir.appendingPathComponent("groups.sqlite")
        let fullSchema = Schema([SpikeS3.S3Personal.self, SpikeS3.S3Groups.self])
        let personalCfg = ModelConfiguration(
            "S3Personal", schema: Schema([SpikeS3.S3Personal.self]), url: personalURL, cloudKitDatabase: .none
        )
        let groupsCfg = ModelConfiguration(
            "S3Groups", schema: Schema([SpikeS3.S3Groups.self]), url: groupsURL, cloudKitDatabase: .none
        )
        let container = try ModelContainer(for: fullSchema, configurations: personalCfg, groupsCfg)
        return (container, personalURL, groupsURL)
    }

    /// Recoge, por `storeIdentifier`, el set de nombres de entidad que aparecen en los CHANGES.
    private func entityNamesByStore(_ txns: [DefaultHistoryTransaction]) -> [String: Set<String>] {
        var out: [String: Set<String>] = [:]
        for tx in txns {
            for change in tx.changes {
                let id: PersistentIdentifier
                switch change {
                case .insert(let c): id = c.changedPersistentIdentifier
                case .update(let c): id = c.changedPersistentIdentifier
                case .delete(let c): id = c.changedPersistentIdentifier
                }
                out[tx.storeIdentifier, default: []].insert(id.entityName)
            }
        }
        return out
    }

    @Test("Un save que toca AMBOS stores → history atribuida por store; el drain personal NO ve tipos de Grupos")
    func historyIsAttributedPerStore_noGroupLeak() throws {
        let dir = freshDir("attr")
        defer { cleanup(dir) }
        let (container, _, _) = try makeTwoStoreContainer(dir)
        let ctx = ModelContext(container)

        // Un ÚNICO save() que muta AMBOS stores (como el mainContext de prod).
        ctx.insert(SpikeS3.S3Personal(name: "expense", syncID: UUID()))
        ctx.insert(SpikeS3.S3Groups(secret: "group-only-data"))
        try ctx.save()

        let txns = try ctx.fetchHistory(HistoryDescriptor<DefaultHistoryTransaction>())
        let byStore = entityNamesByStore(txns)
        let storeIDs = Set(txns.map { $0.storeIdentifier })
        print("SPIKE-S3: storeIdentifiers distintos = \(storeIDs.count)")
        print("SPIKE-S3: entityNames por store = \(byStore)")

        // (1) ¿Hay ≥2 store identifiers distintos? → history ES por-store.
        #expect(storeIDs.count >= 2, "un save que toca 2 stores debe producir history con 2 storeIdentifiers distintos")

        // (2) Ninguna transacción MEZCLA entidades de ambos stores (cada tx pertenece a UN store).
        let mixedTx = byStore.values.contains { $0.contains("S3Personal") && $0.contains("S3Groups") }
        #expect(!mixedTx, "ninguna transacción de history debe contener entidades de AMBOS stores")

        // (3) Identificar el store personal por su entidad y confirmar que NO contiene S3Groups.
        let personalStores = byStore.filter { $0.value.contains("S3Personal") }
        let groupsStores = byStore.filter { $0.value.contains("S3Groups") }
        #expect(!personalStores.isEmpty && !groupsStores.isEmpty)
        for (_, names) in personalStores {
            #expect(!names.contains("S3Groups"), "el store personal NO debe exponer tipos de Grupos en su history")
        }
    }

    @Test("Scoping por storeIdentifier via HistoryDescriptor predicate → SOLO el store personal, CERO de Grupos")
    func scopingByStoreIdentifier_predicateFiltersOtherStore() throws {
        let dir = freshDir("scope")
        defer { cleanup(dir) }
        let (container, _, _) = try makeTwoStoreContainer(dir)
        let ctx = ModelContext(container)

        // Paso 1: escribir SOLO en el store personal, para descubrir su storeIdentifier.
        ctx.insert(SpikeS3.S3Personal(name: "seed", syncID: UUID()))
        try ctx.save()
        let afterPersonalOnly = try ctx.fetchHistory(HistoryDescriptor<DefaultHistoryTransaction>())
        let personalStoreID = afterPersonalOnly.first?.storeIdentifier
        print("SPIKE-S3 scope: personalStoreID = \(personalStoreID ?? "nil")")

        // Paso 2: ahora escribir en AMBOS stores.
        ctx.insert(SpikeS3.S3Personal(name: "expense2", syncID: UUID()))
        ctx.insert(SpikeS3.S3Groups(secret: "leak-me-if-you-can"))
        try ctx.save()

        guard let personalStoreID else {
            #expect(Bool(false), "no se pudo capturar el storeIdentifier del store personal")
            return
        }

        // ¿El descriptor ACEPTA un predicate por storeIdentifier? (mecanismo de aislamiento real).
        var scopingByStoreIDWorks = true
        var groupEntitiesLeaked = 0
        do {
            let descriptor = HistoryDescriptor<DefaultHistoryTransaction>(
                predicate: #Predicate { $0.storeIdentifier == personalStoreID }
            )
            let scoped = try ctx.fetchHistory(descriptor)
            let names = entityNamesByStore(scoped)
            print("SPIKE-S3 scope: history filtrada por storeIdentifier → \(names)")
            for (sid, ents) in names {
                #expect(sid == personalStoreID, "la history filtrada debe pertenecer SOLO al store personal")
                if ents.contains("S3Groups") { groupEntitiesLeaked += 1 }
            }
        } catch {
            scopingByStoreIDWorks = false
            print("SPIKE-S3 scope: predicate por storeIdentifier LANZÓ = \(error)")
        }

        print("SPIKE-S3 VEREDICTO scoping: predicate-por-storeIdentifier funciona = \(scopingByStoreIDWorks); fugas de S3Groups = \(groupEntitiesLeaked)")
        // El mecanismo de aislamiento PRINCIPAL: si el scoping por storeIdentifier funciona,
        // el drain filtra por store; si NO, el fallback (filtrar por entity_type de los 16
        // personales) pasa de fallback a mecanismo PRINCIPAL. Documentamos cuál es la realidad.
        #expect(groupEntitiesLeaked == 0, "bajo scoping por store NO deben aparecer entidades de Grupos")
    }
}
