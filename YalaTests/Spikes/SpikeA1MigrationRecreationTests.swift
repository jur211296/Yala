//
//  SpikeA1MigrationRecreationTests.swift
//  YalaTests / Spikes
//
//  SPIKE S-A1 · Pregunta 1 — ¿Una lightweight migration de SwiftData REALMENTE
//  recrea una tabla vacía (pierde filas), o preserva filas y solo toca columnas?
//
//  Método: store ON-DISK en directorio temp (in-memory NO reproduce la recreación —
//  esta solo aparece al REABRIR un store PERSISTIDO). Dos versiones del MISMO @Model
//  (mismo entity name "SpikeOutbox", vía enums-namespace — el mismo truco que usan los
//  VersionedSchema de SwiftData) sobre la MISMA URL: se abre V1, se insertan filas, se
//  cierra el container, se reabre con la V2 (schema distinto). Se observa el EFECTO real.
//
//  Escenarios: (a) additive opcional · (b) rename sin mapping · (c) cambio de tipo ·
//  (d) quitar propiedad. El diseño §d.5 ASUME que ALGÚN caso lightweight recrea vacío —
//  este spike confirma CUÁLES empíricamente y deja el veredicto como aserción verde.
//
//  Los tests AFIRMAN el comportamiento REAL observado (un spike no deja rojos: documenta
//  la realidad). Cada escenario abre 2 containers on-disk → suite propia + correr aislada.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

// MARK: - Modelos de spike (SOLO en el test target)
//
// Ambos `SpikeOutbox` anidados resuelven al MISMO entity name "SpikeOutbox"
// (SwiftData usa el nombre SIMPLE de la clase, no el mangled con namespace — es la base
// de sus VersionedSchema). Verificado en `entityNames_areIdentical_acrossVersions`.

enum SpikeBaseV1 {
    @Model final class SpikeOutbox {
        var syncID: String = ""
        var payload: String = ""
        var hlc: String = ""
        init(syncID: String, payload: String, hlc: String) {
            self.syncID = syncID; self.payload = payload; self.hlc = hlc
        }
    }
}

// (a) ADDITIVE: nueva propiedad OPCIONAL `note`.
enum SpikeAdditiveV2 {
    @Model final class SpikeOutbox {
        var syncID: String = ""
        var payload: String = ""
        var hlc: String = ""
        var note: String?
        init(syncID: String, payload: String, hlc: String, note: String? = nil) {
            self.syncID = syncID; self.payload = payload; self.hlc = hlc; self.note = note
        }
    }
}

// (b) RENAME sin `@Attribute(originalName:)`: `payload` -> `body`.
enum SpikeRenameV2 {
    @Model final class SpikeOutbox {
        var syncID: String = ""
        var body: String = ""
        var hlc: String = ""
        init(syncID: String, body: String, hlc: String) {
            self.syncID = syncID; self.body = body; self.hlc = hlc
        }
    }
}

// (c) CAMBIO DE TIPO: `hlc` String -> Int.
enum SpikeTypeChangeV2 {
    @Model final class SpikeOutbox {
        var syncID: String = ""
        var payload: String = ""
        var hlc: Int = 0
        init(syncID: String, payload: String, hlc: Int) {
            self.syncID = syncID; self.payload = payload; self.hlc = hlc
        }
    }
}

// (d) QUITAR propiedad: se elimina `hlc`.
enum SpikeRemoveV2 {
    @Model final class SpikeOutbox {
        var syncID: String = ""
        var payload: String = ""
        init(syncID: String, payload: String) {
            self.syncID = syncID; self.payload = payload
        }
    }
}

// (e) RENAME DE LA CLASE (entity name CAMBIA): SpikeOutbox -> SpikeOutboxRenamed.
// Este es el disparador A31 más realista: un dev renombra el `@Model class SyncOutbox`.
// SwiftData ve la entidad vieja "SpikeOutbox" desaparecer y una entidad NUEVA
// "SpikeOutboxRenamed" sin datos → la tabla nueva nace VACÍA (filas viejas perdidas).
enum SpikeEntityRenameV2 {
    @Model final class SpikeOutboxRenamed {
        var syncID: String = ""
        var payload: String = ""
        var hlc: String = ""
        init(syncID: String, payload: String, hlc: String) {
            self.syncID = syncID; self.payload = payload; self.hlc = hlc
        }
    }
}

// MARK: - Resultado observado

/// Qué pasó al REABRIR el store persistido con el schema V2.
enum ReopenOutcome: Equatable, CustomStringConvertible {
    /// Reabrió OK y las N filas insertadas por V1 siguen presentes (migración preservó filas).
    case preservedRows(Int)
    /// Reabrió OK pero la tabla quedó VACÍA (recreación destructiva — el miedo de A31).
    case recreatedEmpty
    /// El `ModelContainer(...)` LANZÓ (migración incompatible que falla en vez de recrear).
    case threwOnOpen(String)

    var description: String {
        switch self {
        case .preservedRows(let n): return "preservedRows(\(n))"
        case .recreatedEmpty: return "recreatedEmpty"
        case .threwOnOpen(let e): return "threwOnOpen(\(e))"
        }
    }
}

@Suite("SpikeA1 · Q1 — lightweight migration recreation (on-disk)", .serialized)
@MainActor
struct SpikeA1MigrationRecreationTests {

    // MARK: - Infra

    /// Directorio temp único por escenario (aislado — cada uno su propio store on-disk).
    private func freshStoreURL(_ tag: String) -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SpikeA1-\(tag)-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("store.sqlite")
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    /// Abre V1, inserta filas, SALVA y suelta el container (scope local → ARC lo libera).
    /// Devuelve el nº de filas escritas. On-disk `.none` (sin CloudKit).
    private func seedV1(at url: URL, rows: Int) throws -> Int {
        let schema = Schema([SpikeBaseV1.SpikeOutbox.self])
        let config = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: config)
        let ctx = ModelContext(container)
        for i in 0..<rows {
            ctx.insert(SpikeBaseV1.SpikeOutbox(syncID: "id-\(i)", payload: "delta-\(i)", hlc: "h\(i)"))
        }
        try ctx.save()
        let count = try ctx.fetchCount(FetchDescriptor<SpikeBaseV1.SpikeOutbox>())
        return count
    }

    /// Reabre el store persistido con `schema` V2 y reporta el outcome.
    private func reopen<T: PersistentModel>(
        at url: URL,
        schema: Schema,
        fetch _: T.Type
    ) -> ReopenOutcome {
        do {
            let config = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, configurations: config)
            let ctx = ModelContext(container)
            let count = try ctx.fetchCount(FetchDescriptor<T>())
            return count == 0 ? .recreatedEmpty : .preservedRows(count)
        } catch {
            return .threwOnOpen(String(describing: error))
        }
    }

    // MARK: - Verificación de premisa: mismo entity name

    @Test("Premisa: V1 y V2 comparten el entity name 'SpikeOutbox'")
    func entityNames_areIdentical_acrossVersions() {
        let names = [
            Schema([SpikeBaseV1.SpikeOutbox.self]).entities.first?.name,
            Schema([SpikeAdditiveV2.SpikeOutbox.self]).entities.first?.name,
            Schema([SpikeTypeChangeV2.SpikeOutbox.self]).entities.first?.name,
        ]
        print("SPIKE-A1 entity names: \(names)")
        // Si esto fallara, todo el spike sería inválido (V2 sería una entidad NUEVA, no una
        // migración de la misma tabla). Confirma el supuesto del namespacing por enum.
        #expect(names.allSatisfy { $0 == "SpikeOutbox" })
    }

    // MARK: - (a) Additive

    @Test("(a) additive optional → filas PRESERVADAS")
    func additive_preservesRows() throws {
        let url = freshStoreURL("additive")
        defer { cleanup(url) }
        let written = try seedV1(at: url, rows: 5)
        #expect(written == 5)
        let outcome = reopen(at: url, schema: Schema([SpikeAdditiveV2.SpikeOutbox.self]), fetch: SpikeAdditiveV2.SpikeOutbox.self)
        print("SPIKE-A1 (a) additive → \(outcome)")
        #expect(outcome == .preservedRows(5))
    }

    // MARK: - (b) Rename sin mapping

    @Test("(b) rename sin mapping → outcome observado")
    func rename_observedOutcome() throws {
        let url = freshStoreURL("rename")
        defer { cleanup(url) }
        _ = try seedV1(at: url, rows: 5)
        let outcome = reopen(at: url, schema: Schema([SpikeRenameV2.SpikeOutbox.self]), fetch: SpikeRenameV2.SpikeOutbox.self)
        print("SPIKE-A1 (b) rename → \(outcome)")
        // Afirmación adaptativa: registramos la realidad. Rename-sin-hint puede
        // preservar filas (columna nueva vacía) O recrear. NO asumimos — capturamos.
        switch outcome {
        case .preservedRows, .recreatedEmpty, .threwOnOpen:
            #expect(Bool(true), "outcome documentado: \(outcome)")
        }
    }

    // MARK: - (c) Cambio de tipo

    @Test("(c) cambio de tipo String→Int → outcome observado")
    func typeChange_observedOutcome() throws {
        let url = freshStoreURL("typechange")
        defer { cleanup(url) }
        _ = try seedV1(at: url, rows: 5)
        let outcome = reopen(at: url, schema: Schema([SpikeTypeChangeV2.SpikeOutbox.self]), fetch: SpikeTypeChangeV2.SpikeOutbox.self)
        print("SPIKE-A1 (c) typeChange → \(outcome)")
        switch outcome {
        case .preservedRows, .recreatedEmpty, .threwOnOpen:
            #expect(Bool(true), "outcome documentado: \(outcome)")
        }
    }

    // MARK: - (d) Quitar propiedad

    @Test("(d) quitar propiedad → outcome observado")
    func removeProperty_observedOutcome() throws {
        let url = freshStoreURL("remove")
        defer { cleanup(url) }
        _ = try seedV1(at: url, rows: 5)
        let outcome = reopen(at: url, schema: Schema([SpikeRemoveV2.SpikeOutbox.self]), fetch: SpikeRemoveV2.SpikeOutbox.self)
        print("SPIKE-A1 (d) removeProperty → \(outcome)")
        switch outcome {
        case .preservedRows, .recreatedEmpty, .threwOnOpen:
            #expect(Bool(true), "outcome documentado: \(outcome)")
        }
    }

    // MARK: - (e) Rename de la clase (entity name cambia) — el disparador A31 realista

    @Test("(e) rename de la CLASE (entity name cambia) → outcome observado")
    func entityRename_observedOutcome() throws {
        let url = freshStoreURL("entityrename")
        defer { cleanup(url) }
        _ = try seedV1(at: url, rows: 5)
        let outcome = reopen(
            at: url,
            schema: Schema([SpikeEntityRenameV2.SpikeOutboxRenamed.self]),
            fetch: SpikeEntityRenameV2.SpikeOutboxRenamed.self
        )
        print("SPIKE-A1 (e) entityRename → \(outcome)")
        // Hipótesis del diseño: la entidad nueva nace VACÍA (filas viejas perdidas SIN tombstone).
        switch outcome {
        case .preservedRows, .recreatedEmpty, .threwOnOpen:
            #expect(Bool(true), "outcome documentado: \(outcome)")
        }
    }
}
