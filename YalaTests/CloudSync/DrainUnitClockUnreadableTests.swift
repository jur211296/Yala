//
//  DrainUnitClockUnreadableTests.swift
//  YalaTests / CloudSync
//
//  Ticket `drain-duplicates-the-unit-clock-when-its-row-cannot-be-read`: si el drain no puede LEER el reloj por
//  unidad de una fila, no inserta un segundo reloj para el mismo `syncID` ni deja el del tombstone vivo; el drain
//  que no se completa deshace lo suyo (rollback) y el token no avanza. Cada caso con la lectura fallando lleva su
//  control positivo: sin el seam, la vuelta siguiente persiste lo que la fallida dejó pendiente.
//  Container ON-DISK temp con los 3 stores (el History es por-container). `.serialized`: el seam es ESTÁTICO.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("CloudSync · reloj por unidad ilegible en el drain", .serialized)
@MainActor
struct DrainUnitClockUnreadableTests {

    // MARK: - Infra

    private func freshDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("DrainClock-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    /// No borra el dir: mismo motivo que `IdentityRemapEmissionTests.cleanup` (IO errors de saves huérfanos).
    private func cleanup(_ dir: URL) { /* intencionalmente no-op */ }

    private func makeContext(_ dir: URL) throws -> ModelContext {
        let personalCfg = ModelConfiguration(
            "DUC-Personal", schema: SwiftDataConfiguration.personalSchema,
            url: dir.appendingPathComponent("personal.sqlite"), cloudKitDatabase: .none)
        let groupsCfg = ModelConfiguration(
            "DUC-Groups", schema: SwiftDataConfiguration.groupsSchema,
            url: dir.appendingPathComponent("groups.sqlite"), cloudKitDatabase: .none)
        let syncMetaCfg = ModelConfiguration(
            "DUC-SyncMeta", schema: SwiftDataConfiguration.syncMetaSchema,
            url: dir.appendingPathComponent("syncmeta.sqlite"), cloudKitDatabase: .none)
        let container = try ModelContainer(for: SwiftDataConfiguration.schema,
                                           configurations: personalCfg, groupsCfg, syncMetaCfg)
        return ModelContext(container)
    }

    private let epochDate = Date(timeIntervalSince1970: 1_700_000_000)
    private let node = "0123456789abcdef"
    private func hlc(_ c: Int) -> String { "2023-11-14T22:13:20.000Z-\(String(format: "%04x", c))-\(node)" }

    /// Lo PERSISTIDO, leído desde un contexto nuevo sobre el mismo container: lo que el contexto del drain
    /// tenga sucio no cuenta.
    private func persisted<T: PersistentModel>(_ type: T.Type, _ context: ModelContext) throws -> [T] {
        try ModelContext(context.container).fetch(FetchDescriptor<T>())
    }
    private func clocks(_ context: ModelContext) throws -> [SyncUnitClock] {
        try context.fetch(FetchDescriptor<SyncUnitClock>())
    }
    private func outbox(_ context: ModelContext) throws -> [SyncOutbox] {
        try context.fetch(FetchDescriptor<SyncOutbox>(sortBy: [SortDescriptor(\.createdAt)]))
    }
    private func token(_ context: ModelContext) throws -> Data? {
        try persisted(SyncCursor.self, context).first?.historyTokenData
    }
    private func money(_ clock: SyncUnitClock?) -> String? { unit("money", clock) }
    private func unit(_ name: String, _ clock: SyncUnitClock?) -> String? {
        SyncUnitClockStore.decodeMap(clock?.unitHlcsJSON)[name]
    }

    /// Una TX drenada: 1 fila de outbox y 1 reloj. Devuelve la TX y su `syncID`.
    private func drainedTx(_ context: ModelContext, _ engine: CloudSyncEngine) throws -> (TransactionItem, UUID) {
        let tx = TransactionItem(date: epochDate, amount: 10, currencyCode: "USD", note: "n")
        tx.createdAt = epochDate
        context.insert(tx)
        try context.save()
        engine.drainOnce(context: context)
        let syncID = try #require(tx.syncID)
        #expect(try clocks(context).count == 1)
        #expect(try outbox(context).count == 1)
        return (tx, syncID)
    }

    // MARK: - Upsert con el reloj ilegible

    /// Antes: `row` leía el fetch fallido como «no hay fila» e insertaba un SEGUNDO `SyncUnitClock` para el mismo
    /// `syncID`, que el reconciler de transferencias podía leer en lugar del bueno.
    @Test func drainUpsert_unreadableClock_insertsNoSecondClock_andTokenStays() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        defer { EntityApplyMap._testThrowOnFetchOf = [] }
        let (tx, syncID) = try drainedTx(context, engine)
        let firstHLC = try #require(try outbox(context).first?.hlc)
        let tokenBefore = try token(context)

        tx.amount = 20
        try context.save()
        EntityApplyMap._testThrowOnFetchOf = ["SyncUnitClock"]
        #expect(!engine.drainOnce(context: context))                 // la vuelta dice que no terminó

        #expect(try clocks(context).count == 1)                      // ni un segundo reloj…
        #expect(money(try clocks(context).first) == firstHLC)        // …ni el viejo tocado
        #expect(try outbox(context).count == 1)                      // la fila nueva no entró
        #expect(try persisted(SyncOutbox.self, context).count == 1)
        #expect(!context.hasChanges)                                 // nada a medias en el contexto
        #expect(try token(context) == tokenBefore)                   // el token no avanzó

        // Control positivo: la lectura vuelve y la MISMA edición se captura, con un solo reloj.
        EntityApplyMap._testThrowOnFetchOf = []
        #expect(engine.drainOnce(context: context))
        let rows = try outbox(context)
        #expect(rows.count == 2)
        #expect(try clocks(context).count == 1)
        #expect(money(SyncUnitClockStore.row(syncID: syncID, context: context)) == rows.last?.hlc)
        #expect(rows.last?.hlc != firstHLC)
        #expect(try token(context) != tokenBefore)
    }

    // MARK: - Tombstone con el reloj ilegible

    /// Antes: `delete` era no-op con el fetch fallido ⇒ el tombstone salía y el reloj se quedaba vivo.
    @Test func drainTombstone_unreadableClock_holdsTheTombstone_thenCleansTheClock() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        defer { EntityApplyMap._testThrowOnFetchOf = [] }
        let (tx, syncID) = try drainedTx(context, engine)
        let tokenBefore = try token(context)

        context.delete(tx)
        try context.save()
        EntityApplyMap._testThrowOnFetchOf = ["SyncUnitClock"]
        #expect(!engine.drainOnce(context: context))

        #expect(try outbox(context).filter { $0.opRaw == SyncOutboxOp.tombstone.rawValue }.isEmpty)
        #expect(try clocks(context).count == 1)
        #expect(!context.hasChanges)
        #expect(try token(context) == tokenBefore)

        // Control positivo: sin el seam, el tombstone sale y el reloj se borra en el MISMO save.
        EntityApplyMap._testThrowOnFetchOf = []
        engine.drainOnce(context: context)
        #expect(try outbox(context).filter { $0.opRaw == SyncOutboxOp.tombstone.rawValue }.map(\.syncID) == [syncID])
        #expect(try persisted(SyncUnitClock.self, context).isEmpty)
    }

    // MARK: - Save del outbox que falla: rollback

    /// Antes: el `catch` de `drainOnce` no hacía rollback ⇒ las filas de outbox y los relojes quedaban sucios en el
    /// contexto y un autosave los flusheaba bajo el autor por defecto. La edición del usuario sin guardar NO se
    /// pierde: el barrido del paso 2 la guarda antes de que el drain toque nada, y eso es lo que hace seguro el
    /// rollback.
    @Test func drainOutboxSaveFails_rollsBackItsRows_keepsTheUserEdit_andTokenStays() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        let (tx, syncID) = try drainedTx(context, engine)
        let firstHLC = try #require(try outbox(context).first?.hlc)
        let tokenBefore = try token(context)

        tx.note = "editada sin guardar"                             // pendiente en el contexto
        engine._testThrowOnDrainOutboxSave = true
        #expect(!engine.drainOnce(context: context))

        #expect(!context.hasChanges)                                 // ni filas ni relojes sucios
        #expect(try outbox(context).count == 1)
        #expect(try persisted(SyncOutbox.self, context).count == 1)
        // La unidad EDITADA es `note`: sin rollback, su reloj en memoria llevaría ya el HLC de la fila deshecha.
        #expect(unit("note", SyncUnitClockStore.row(syncID: syncID, context: context)) == firstHLC)
        #expect(try token(context) == tokenBefore)
        // La promesa al usuario: su edición está en disco. La cumple el barrido del paso 2, que guarda antes de que
        // el drain toque nada; lo que impide que el rollback cubra ese barrido lo fija el scan de abajo.
        #expect(try persisted(TransactionItem.self, context).first?.note == "editada sin guardar")

        // Control positivo: la vuelta siguiente sube la edición.
        engine._testThrowOnDrainOutboxSave = false
        engine.drainOnce(context: context)
        #expect(try persisted(SyncOutbox.self, context).count == 2)
        #expect(try clocks(context).count == 1)
        #expect(try token(context) != tokenBefore)
    }

    /// El espejo del App Group se escribe ANTES del save, a propósito. Si el save falla, sus entradas se retiran:
    /// si no, el diff incondicional de `rehydrateOutboxFromMirror` re-insertaba en el arranque siguiente unas filas
    /// que el rollback había deshecho. Las entradas de filas que SÍ están en disco se quedan.
    @Test func drainOutboxSaveFails_retiresItsMirrorEntries_keepsThePersistedOnes() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let mirrorDir = dir.appendingPathComponent("mirror", isDirectory: true)
        let mirror = SyncOutboxMirror(directoryURL: mirrorDir)
        let engine = CloudSyncEngine()
        engine.outboxMirror = mirror
        engine.currentUserID = "user-1"
        let (tx, _) = try drainedTx(context, engine)
        let persistedHLC = try #require(try outbox(context).first?.hlc)
        #expect(mirror.entriesForUser("user-1").map(\.hlc) == [persistedHLC])

        tx.note = "otra"
        try context.save()
        engine._testThrowOnDrainOutboxSave = true
        engine.drainOnce(context: context)
        #expect(mirror.entriesForUser("user-1").map(\.hlc) == [persistedHLC])

        // Control positivo: con el save bien, la entrada nueva se queda junto a la vieja.
        engine._testThrowOnDrainOutboxSave = false
        engine.drainOnce(context: context)
        #expect(Set(mirror.entriesForUser("user-1").map(\.hlc)) == Set(try outbox(context).map(\.hlc)))
        #expect(mirror.entriesForUser("user-1").count == 2)
    }

    // MARK: - Snapshot (la subida de la migración)

    private func snapshotInput(_ syncID: UUID) -> SnapshotRowInput {
        SnapshotRowInput(syncID: syncID, entityType: SyncEntityType.transactionItem) { hlc in
            (fieldsJSON: "{}", fieldHlcsJSON: #"{"money":"\#(hlc)"}"#)
        }
    }

    /// Sus llamadores no hacen rollback, y el contexto puede llevar ediciones del usuario: el fallo tiene que llegar
    /// ANTES de la primera inserción.
    @Test func enqueueSnapshot_unreadableClock_throwsBeforeInsertingAnything() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let engine = CloudSyncEngine()
        defer { EntityApplyMap._testThrowOnFetchOf = [] }
        let seeded = UUID()
        try SyncUnitClockStore.upsertChecked(syncID: seeded, entityTable: "tx_items",
                                             unitHlcs: ["money": hlc(1)], context: context)
        try context.save()

        EntityApplyMap._testThrowOnFetchOf = ["SyncUnitClock"]
        #expect(throws: EntityApplyFetchError.self) {
            try engine.enqueueSnapshotRows([snapshotInput(seeded), snapshotInput(UUID())],
                                           context: context, now: epochDate)
        }
        #expect(try outbox(context).isEmpty)
        #expect(try clocks(context).count == 1)
        #expect(!context.hasChanges)

        // Control positivo: sin el seam, dos filas y un reloj por `syncID` (el sembrado, actualizado).
        EntityApplyMap._testThrowOnFetchOf = []
        try engine.enqueueSnapshotRows([snapshotInput(seeded), snapshotInput(UUID())],
                                       context: context, now: epochDate)
        #expect(try persisted(SyncOutbox.self, context).count == 2)
        #expect(try persisted(SyncUnitClock.self, context).count == 2)
        #expect(money(SyncUnitClockStore.row(syncID: seeded, context: context)) != hlc(1))
    }

    // MARK: - El lote: lectura antes de escribir, y lo que ve una segunda escritura del mismo syncID

    @Test func prepareWrites_unreadable_throwsWithoutTouchingTheContext() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        defer { EntityApplyMap._testThrowOnFetchOf = [] }

        EntityApplyMap._testThrowOnFetchOf = ["SyncUnitClock"]
        #expect(throws: EntityApplyFetchError.self) {
            _ = try SyncUnitClockStore.prepareWrites(
                [.upsert(syncID: UUID(), entityTable: "tx_items", unitHlcs: ["money": hlc(1)])], context: context)
        }
        // Un upsert SIN unidades no se escribe, así que tampoco se lee: no puede tumbar el lote (con el seam puesto,
        // leerlo lanzaría), ni insertar un reloj vacío al aplicarlo.
        let empty = try SyncUnitClockStore.prepareWrites(
            [.upsert(syncID: UUID(), entityTable: "tx_items", unitHlcs: [:])], context: context)
        EntityApplyMap._testThrowOnFetchOf = []
        empty.apply(context: context)
        #expect(try clocks(context).isEmpty)
    }

    /// Dos escrituras del mismo `syncID` en un lote: la segunda ve la primera sin volver a leer, como la vería un
    /// fetch del contexto con los cambios pendientes. Un upsert repetido no duplica; un borrado seguido de un upsert
    /// deja una fila NUEVA con solo lo del upsert (la vieja se borra de verdad).
    @Test func preparedWrites_secondWriteOfTheSameSyncID_seesTheFirst() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let a = UUID(), b = UUID(), c = UUID(), d = UUID(), e = UUID()
        for existing in [b, d, e] {
            try SyncUnitClockStore.upsertChecked(syncID: existing, entityTable: "tx_items",
                                                 unitHlcs: ["money": hlc(5), "note": hlc(5)], context: context)
        }
        try context.save()

        let prepared = try SyncUnitClockStore.prepareWrites([
            .upsert(syncID: a, entityTable: "tx_items", unitHlcs: ["money": hlc(1)]),
            .upsert(syncID: a, entityTable: "tx_items", unitHlcs: ["money": hlc(3), "note": hlc(2)]),
            .delete(syncID: b),
            .upsert(syncID: b, entityTable: "tx_items", unitHlcs: ["money": hlc(2)]),
            .upsert(syncID: c, entityTable: "tx_items", unitHlcs: ["money": hlc(1)]),   // nuevo y borrado
            .delete(syncID: c),
            .upsert(syncID: d, entityTable: "tx_items", unitHlcs: ["money": hlc(9)]),   // existente y borrado
            .delete(syncID: d),
            .delete(syncID: e),                                                        // borrado dos veces
            .delete(syncID: e),
        ], context: context)
        prepared.apply(context: context)
        try context.save()

        let rows = try persisted(SyncUnitClock.self, context)
        #expect(rows.count == 2)
        let rowA = try #require(rows.first { $0.syncID == a })
        #expect(SyncUnitClockStore.decodeMap(rowA.unitHlcsJSON) == ["money": hlc(3), "note": hlc(2)])
        let rowB = try #require(rows.first { $0.syncID == b })
        #expect(SyncUnitClockStore.decodeMap(rowB.unitHlcsJSON) == ["money": hlc(2)])
    }

    // MARK: - Save del cursor que falla (paso 7): rollback del cursor, las filas y su espejo se quedan

    /// Las filas del outbox YA están en disco cuando falla el save del cursor: el rollback solo deshace el cursor
    /// (token y reloj), y su espejo no se retira. Es la semántica de un kill entre los pasos 6 y 7, y el re-drain
    /// la absorbe por el dedup (mismos HLC, porque el reloj vuelve al persistido).
    @Test func drainCursorSaveFails_rollsBackTheCursor_keepsRowsAndMirror() throws {
        let dir = freshDir(); defer { cleanup(dir) }
        let context = try makeContext(dir)
        let mirror = SyncOutboxMirror(directoryURL: dir.appendingPathComponent("mirror", isDirectory: true))
        let engine = CloudSyncEngine()
        engine.outboxMirror = mirror
        engine.currentUserID = "user-1"
        let (tx, _) = try drainedTx(context, engine)
        let tokenBefore = try token(context)

        tx.note = "otra"
        try context.save()
        engine._testThrowOnDrainCursorSave = true
        #expect(!engine.drainOnce(context: context))

        #expect(!context.hasChanges)                                 // el cursor no queda sucio
        #expect(try token(context) == tokenBefore)
        #expect(try persisted(SyncOutbox.self, context).count == 2)  // la fila ya estaba en disco
        #expect(mirror.entriesForUser("user-1").count == 2)          // y su espejo se queda

        engine._testThrowOnDrainCursorSave = false
        #expect(engine.drainOnce(context: context))
        #expect(try token(context) != tokenBefore)
        #expect(try persisted(SyncOutbox.self, context).count == 2)  // el dedup absorbe el replay
    }

    // MARK: - Cableado: el rollback vive en los pasos 6-7, no en el `catch` general

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/CloudSync/
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }
    private func source(_ path: String) throws -> String {
        try String(contentsOf: Self.repoRoot.appendingPathComponent(path), encoding: .utf8)
    }
    /// Solo código: sin líneas de comentario ni la cola `// …` de una línea (ningún literal de estas funciones
    /// lleva `//`). Las llaves de los comentarios no cuentan al emparejar.
    private func codeOnly(_ text: Substring) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false).map { line -> String in
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.hasPrefix("//") || t.hasPrefix("///") { return "" }
            if let r = line.range(of: " //") { return String(line[..<r.lowerBound]) }
            return String(line)
        }.joined(separator: "\n")
    }
    /// Cuerpo de la función que empieza en `signature`, por emparejado de llaves sobre el código.
    private func body(of signature: String, in text: String) throws -> String {
        let start = try #require(text.range(of: signature), "no está: \(signature)")
        let code = codeOnly(text[start.lowerBound...])
        let open = try #require(code.firstIndex(of: "{"))
        var depth = 0
        for idx in code[open...].indices {
            if code[idx] == "{" { depth += 1 }
            if code[idx] == "}" { depth -= 1; if depth == 0 { return String(code[open...idx]) } }
        }
        Issue.record("llaves sin cerrar en \(signature)"); return ""
    }
    /// Posición de la `{` que abre el bloque que contiene `index` (emparejado hacia atrás).
    private func enclosingOpen(of index: String.Index, in code: String) -> String.Index? {
        var depth = 0
        var idx = index
        while idx > code.startIndex {
            idx = code.index(before: idx)
            if code[idx] == "}" { depth += 1 }
            if code[idx] == "{" { if depth == 0 { return idx }; depth -= 1 }
        }
        return nil
    }

    /// Ningún test de comportamiento puede fallar el barrido del paso 2 a mitad (no hay seam), y es justo el caso
    /// en el que un rollback que lo cubriera borraría ediciones del usuario sin guardar. Se fija por estructura:
    /// un solo `rollback()`, en un `catch` cuyo `do` abre DESPUÉS del barrido y encierra los saves del outbox y
    /// del cursor; ninguno dentro del barrido; y el `catch` general sin rollback, con rastro y `return false`.
    @Test func performDrain_rollbackOnlyCoversTheStepsAfterTheSweep() throws {
        let file = try source("Yala/Services/CloudSync/CloudSyncEngine.swift")
        let drain = try body(of: "private func performDrain(context: ModelContext) -> Bool {", in: file)
        let sweep = try body(of: "private func sweepAndBuildLookups(_ context: ModelContext) throws -> Lookups {", in: file)
        #expect(!sweep.contains("rollback"))
        #expect(drain.components(separatedBy: "context.rollback()").count == 2)  // exactamente uno

        func at(_ needle: String) throws -> String.Index {
            try #require(drain.range(of: needle), "falta en performDrain: \(needle)").lowerBound
        }
        let sweepCall = try at("let lookups = try sweepAndBuildLookups(context)")
        let prepare = try at("let unitClocks = try prepareUnitClocks(for: rows, context: context)")
        let mirror = try at("writeMirror(rows: rows)")
        let insert = try at("for row in rows { context.insert(row.makeModel()) }")
        let unwrite = try at("unwriteMirror(rows: rows)")
        let cursorStep = try at("if !_testSuppressTokenAdvance {")
        let advance = try at("cursor.historyTokenData = try encodeToken(advancedToken)")
        let rollback = try at("context.rollback()")
        #expect(sweepCall < prepare && prepare < mirror && mirror < insert && insert < unwrite)
        #expect(unwrite < cursorStep)            // la retirada del espejo, en el save del OUTBOX (antes del paso 7)

        // El `catch` del rollback: `} catch { context.rollback() throw error }`, y su `do` —el bloque que cierra
        // ese `}`— abre después del barrido y contiene el save del outbox y el del cursor.
        let catchRange = try #require(drain.range(of: "} catch {", options: .backwards, range: drain.startIndex..<rollback))
        let afterCatch = drain[catchRange.upperBound...].split(whereSeparator: \.isWhitespace).prefix(4).joined(separator: " ")
        #expect(afterCatch == "context.rollback() throw error }")
        let doOpen = try #require(enclosingOpen(of: catchRange.lowerBound, in: drain))
        #expect(drain[drain.index(doOpen, offsetBy: -3)..<doOpen] == "do ")
        #expect(sweepCall < doOpen)
        #expect(doOpen < prepare && advance < catchRange.lowerBound)

        // El `catch` general: el último de la función, sin rollback, con rastro y `false`.
        let general = try #require(drain.range(of: "} catch {", options: .backwards))
        #expect(rollback < general.lowerBound)
        let generalBody = String(drain[general.upperBound...])
        #expect(!generalBody.contains("rollback"))
        #expect(generalBody.contains("CloudSyncBreadcrumb.drainAborted(errorType: String(describing: type(of: error)))"))
        #expect(generalBody.contains("return false"))
    }

    /// Todo llamador que DECIDE algo leyendo el outbox tras un drain comprueba que terminó (hallazgo de la review:
    /// con el rollback, un drain abortado ya no deja sus filas ni sucias, y el guard D-1 o «no queda nada que subir»
    /// se leerían sobre un outbox incompleto). Los tres que no lo comprueban, cada uno con su porqué.
    @Test func drainCallersThatReadTheOutbox_checkThatItFinished() throws {
        let guarded = [
            ("Yala/Services/CloudSync/SyncApplyEngine.swift", "guard drainOnce(context: context) else {", 1),
            ("Yala/Services/CloudSync/MigrationSnapshotUploader.swift",
             "guard engine.drainOnce(context: context) else { return .blocked(.localFailure) }", 2),
            ("Yala/Services/CloudSync/MigrationWorkExecutor.swift",
             "guard engine.drainOnce(context: context) else { return .blocked(.localFailure) }", 2),
            ("Yala/Services/CloudSync/MigrationWorkExecutor.swift", "guard engine.drainOnce(context: context) else {", 3),
            ("Yala/Services/CloudSync/CloudSyncRuntime.swift", "if engine.drainOnce(context: context) {", 1),
        ]
        for (path, needle, count) in guarded {
            let code = codeOnly(Substring(try source(path)))
            #expect(code.components(separatedBy: needle).count - 1 == count, "\(path): \(needle)")
        }
        // Sin comprobar, a propósito: la entrada del pull (lo cubre el re-drain previo al apply), la del ciclo del
        // runtime (su pull re-drena antes de aplicar) y la captura paralela del cutover (un ancla más atrás re-lee
        // de más, no pierde nada).
        let unguarded = [
            ("Yala/Services/CloudSync/SyncApplyEngine.swift", 2),
            ("Yala/Services/CloudSync/CloudSyncRuntime.swift", 2),
            ("Yala/Services/CloudSync/MigrationWorkExecutor.swift", 4),
            ("Yala/Services/CloudSync/MigrationSnapshotUploader.swift", 2),
        ]
        for (path, total) in unguarded {
            let code = codeOnly(Substring(try source(path)))
            #expect(code.components(separatedBy: "drainOnce(context: context)").count - 1 == total, "\(path)")
        }
        let quarantine = codeOnly(Substring(try source("Yala/Services/CloudSync/CloudSyncRuntime.swift")))
        let gate = try #require(quarantine.range(of: "if engine.drainOnce(context: context) {"))
        let apply = try #require(quarantine.range(of: "engine.drainQuarantineOnce(context: context)"))
        #expect(gate.upperBound < apply.lowerBound)
        #expect(!quarantine[gate.upperBound..<apply.lowerBound].contains("}"))  // DENTRO del `if`
    }
}
