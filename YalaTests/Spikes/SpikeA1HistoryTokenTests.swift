//
//  SpikeA1HistoryTokenTests.swift
//  YalaTests / Spikes
//
//  SPIKE S-A1 · Pregunta 2 — ¿El token de SwiftData History (`DefaultHistoryToken` vía
//  `HistoryDescriptor`) SOBREVIVE una lightweight migration?
//
//  El diseño §d.5 apoya el "residual honesto" de A31 en que el invariante
//  `deleteHistory`-al-2xx protege el delta write→drain SIEMPRE QUE el history token
//  sobreviva la migración. Si el token se invalida y el fetch devuelve VACÍO EN SILENCIO
//  (sin lanzar `tokenExpired`), ese delta se pierde sin señal → el PEOR caso.
//
//  Método: store ON-DISK, escribe transacciones, captura el último token, cierra, reabre
//  con schema migrado (additive), y trata de fetchear el history POSTERIOR al token.
//  Se clasifica el resultado en: devuelve transacciones / lanza error / VACÍO silencioso.
//
//  Test verde = afirma el comportamiento REAL observado (spike no deja rojos).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

// Reusa los modelos de spike de SpikeA1MigrationRecreationTests
// (SpikeBaseV1.SpikeOutbox / SpikeAdditiveV2.SpikeOutbox) — mismo target, mismo entity name.

/// Resultado de intentar leer history tras la migración, filtrando por un token pre-migración.
enum HistoryAfterMigration: CustomStringConvertible {
    /// `fetchHistory(after: token)` devolvió ≥1 transacción → el token SOBREVIVIÓ y es usable.
    case returnedTransactions(Int)
    /// `fetchHistory` LANZÓ (p.ej. token expirado / incompatible) → falla RUIDOSA (recuperable).
    case threw(String)
    /// `fetchHistory` devolvió VACÍO sin lanzar, PESE a haber insertado tras migrar → el PEOR caso.
    case silentEmpty

    var description: String {
        switch self {
        case .returnedTransactions(let n): return "returnedTransactions(\(n))"
        case .threw(let e): return "threw(\(e))"
        case .silentEmpty: return "silentEmpty"
        }
    }
}

@Suite("SpikeA1 · Q2 — SwiftData History token survival across migration", .serialized)
@MainActor
struct SpikeA1HistoryTokenTests {

    private func freshStoreURL() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SpikeA1Hist-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("store.sqlite")
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    /// ¿La history está disponible del todo en este store on-disk? (control positivo).
    @Test("Control: history se registra y se lee en un store on-disk (sin migración)")
    func historyIsTrackedOnDisk() throws {
        let url = freshStoreURL()
        defer { cleanup(url) }
        let schema = Schema([SpikeBaseV1.SpikeOutbox.self])
        let config = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: config)
        let ctx = ModelContext(container)
        ctx.insert(SpikeBaseV1.SpikeOutbox(syncID: "a", payload: "p", hlc: "h"))
        try ctx.save()

        do {
            let txns = try ctx.fetchHistory(HistoryDescriptor<DefaultHistoryTransaction>())
            print("SPIKE-A1 Q2 control: history txns count = \(txns.count); lastToken? = \(txns.last?.token != nil)")
            // No forzamos >0 duro (algunas configs no habilitan history); documentamos.
            #expect(txns.count >= 0)
        } catch {
            print("SPIKE-A1 Q2 control: fetchHistory THREW = \(error)")
            // Que lance aquí ya es un hallazgo: la history no está disponible en este setup.
            #expect(Bool(true), "history no disponible: \(error)")
        }
    }

    @Test("Token pre-migración → lectura de history tras lightweight migration")
    func historyToken_afterMigration() throws {
        let url = freshStoreURL()
        defer { cleanup(url) }

        // ---- Fase 1: store V1, escribir transacciones, capturar último token. ----
        var capturedToken: DefaultHistoryToken?
        var preCount = 0
        do {
            let schema = Schema([SpikeBaseV1.SpikeOutbox.self])
            let config = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: config)
            let ctx = ModelContext(container)
            // Tres saves = tres transacciones de history.
            for i in 0..<3 {
                ctx.insert(SpikeBaseV1.SpikeOutbox(syncID: "id-\(i)", payload: "d\(i)", hlc: "h\(i)"))
                try ctx.save()
            }
            do {
                let txns = try ctx.fetchHistory(HistoryDescriptor<DefaultHistoryTransaction>())
                preCount = txns.count
                capturedToken = txns.last?.token
            } catch {
                print("SPIKE-A1 Q2: pre-migration fetchHistory threw = \(error)")
            }
            print("SPIKE-A1 Q2: pre-migration history count = \(preCount), token captured = \(capturedToken != nil)")
        }
        // container V1 liberado al salir del scope.

        // ---- Fase 2: reabrir con schema migrado (additive) sobre la MISMA URL. ----
        let schemaV2 = Schema([SpikeAdditiveV2.SpikeOutbox.self])
        let configV2 = ModelConfiguration(schema: schemaV2, url: url, cloudKitDatabase: .none)
        let containerV2 = try ModelContainer(for: schemaV2, configurations: configV2)
        let ctxV2 = ModelContext(containerV2)

        // Escribimos UNA transacción nueva tras migrar (para distinguir "vacío porque no hay
        // nada nuevo" de "vacío porque el token se invalidó silenciosamente").
        ctxV2.insert(SpikeAdditiveV2.SpikeOutbox(syncID: "post", payload: "post", hlc: "hp", note: "n"))
        try ctxV2.save()

        let result: HistoryAfterMigration
        if let token = capturedToken {
            do {
                // Fetch de history ESTRICTAMENTE posterior al token pre-migración.
                let descriptor = HistoryDescriptor<DefaultHistoryTransaction>(
                    predicate: #Predicate { $0.token > token }
                )
                let after = try ctxV2.fetchHistory(descriptor)
                if after.isEmpty {
                    // Comprobamos que SÍ hay history nueva sin filtro (aisla "token roto" de
                    // "history entera reseteada por la migración").
                    let all = (try? ctxV2.fetchHistory(HistoryDescriptor<DefaultHistoryTransaction>())) ?? []
                    print("SPIKE-A1 Q2: after-token EMPTY; unfiltered history count = \(all.count)")
                    result = .silentEmpty
                } else {
                    result = .returnedTransactions(after.count)
                }
            } catch {
                result = .threw(String(describing: error))
            }
        } else {
            // No hubo token que capturar (history no disponible pre-migración).
            // Reportamos leyendo la history post-migración sin filtro.
            do {
                let all = try ctxV2.fetchHistory(HistoryDescriptor<DefaultHistoryTransaction>())
                result = all.isEmpty ? .silentEmpty : .returnedTransactions(all.count)
            } catch {
                result = .threw(String(describing: error))
            }
        }

        print("SPIKE-A1 Q2 VERDICT (additive): token=\(capturedToken != nil), result=\(result)")
        // Afirmación adaptativa: documentamos la realidad observada, sea cual sea.
        switch result {
        case .returnedTransactions, .threw, .silentEmpty:
            #expect(Bool(true), "history-after-migration outcome: \(result)")
        }
    }

    /// Peor caso para A31: el token pre-migración leído tras una migración que RECREA la
    /// tabla vacía (rename de la clase → entity name cambia, cf. Q1 escenario (e)).
    /// ¿El token sobrevive el reset del store, o se invalida / silencia?
    @Test("Token pre-migración → lectura de history tras migración DESTRUCTIVA (entity rename)")
    func historyToken_afterDestructiveMigration() throws {
        let url = freshStoreURL()
        defer { cleanup(url) }

        var capturedToken: DefaultHistoryToken?
        do {
            let schema = Schema([SpikeBaseV1.SpikeOutbox.self])
            let config = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: config)
            let ctx = ModelContext(container)
            for i in 0..<3 {
                ctx.insert(SpikeBaseV1.SpikeOutbox(syncID: "id-\(i)", payload: "d\(i)", hlc: "h\(i)"))
                try ctx.save()
            }
            capturedToken = (try? ctx.fetchHistory(HistoryDescriptor<DefaultHistoryTransaction>()))?.last?.token
        }

        // Reabrir con la CLASE renombrada (entity name distinto → Q1 mostró recreatedEmpty).
        let schemaV2 = Schema([SpikeEntityRenameV2.SpikeOutboxRenamed.self])
        let configV2 = ModelConfiguration(schema: schemaV2, url: url, cloudKitDatabase: .none)
        let containerV2 = try ModelContainer(for: schemaV2, configurations: configV2)
        let ctxV2 = ModelContext(containerV2)
        ctxV2.insert(SpikeEntityRenameV2.SpikeOutboxRenamed(syncID: "post", payload: "post", hlc: "hp"))
        try ctxV2.save()

        let result: HistoryAfterMigration
        if let token = capturedToken {
            do {
                let descriptor = HistoryDescriptor<DefaultHistoryTransaction>(
                    predicate: #Predicate { $0.token > token }
                )
                let after = try ctxV2.fetchHistory(descriptor)
                result = after.isEmpty ? .silentEmpty : .returnedTransactions(after.count)
            } catch {
                result = .threw(String(describing: error))
            }
        } else {
            result = .silentEmpty
        }
        print("SPIKE-A1 Q2 VERDICT (destructive/entity-rename): token=\(capturedToken != nil), result=\(result)")
        switch result {
        case .returnedTransactions, .threw, .silentEmpty:
            #expect(Bool(true), "history-after-destructive-migration outcome: \(result)")
        }
    }
}
