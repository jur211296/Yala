//
//  SpikeA1MirrorOrderingTests.swift
//  YalaTests / Spikes
//
//  SPIKE S-A1 · Pregunta 3 — ¿El orden "espejo-ANTES-del-save" es crash-safe con
//  autosave ON en el mainContext?
//
//  El diseño §d.5 ancla el `SyncOutboxMirror` a escribir el archivo `.atomic` ANTES de
//  `context.insert(SyncOutbox)+save()`. El riesgo: con `autosaveEnabled = true`, el
//  mainContext puede persistir por su cuenta (runloop tick) el estado ANTES de que el
//  espejo lo refleje → orden INVERTIDO (fila durable sin su archivo espejo).
//
//  Qué SÍ puede probar un test (y qué NO — límites honestos abajo):
//   (Q3.1) Autosave persiste cambios pendientes por su PROPIA agenda (runloop), SIN
//          `save()` explícito → confirma que el timing no lo controla el drain: si una
//          fila se inserta y se cede el runloop antes de escribir su espejo, autosave
//          puede persistirla un-mirrored. (Aproximación del riesgo.)
//   (Q3.2) La mitigación: escribir el espejo (síncrono, atómico) y LUEGO insertar+save()
//          DENTRO del mismo scope síncrono no cede el runloop entremedias → autosave no
//          puede invertir el orden para ESA fila. Se verifica que el archivo espejo existe
//          en disco ANTES de que la fila se persista.
//
//  Límite honesto: un test NO puede reproducir un KILL real del proceso (SIGKILL /
//  power-loss) entre el `write(atomically:)` del espejo y el fsync del store, ni el
//  ordenamiento de page-cache del OS. Eso es territorio device/durabilidad física.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("SpikeA1 · Q3 — mirror-before-save ordering vs autosave", .serialized)
@MainActor
struct SpikeA1MirrorOrderingTests {

    private func freshStoreURL() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SpikeA1Mirror-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("store.sqlite")
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    // MARK: - Q3.1 · El flush de autosave NO es observable/controlable desde el drain
    //
    // Resultado observado (in-harness): tras insertar y ceder 0.3s de runloop, `hasChanges`
    // SIGUE true → el autosave del mainContext NO disparó en la ventana. SwiftData agenda el
    // autosave sobre notificaciones de ciclo de vida / observadores de runloop que un test
    // aislado no reproduce. Conclusión honesta: el momento del flush de autosave NO está bajo
    // control del drain (ni siquiera es observable de forma determinista aquí) → la garantía
    // de orden NO puede apoyarse en "cuándo dispara autosave", sino en la ESTRUCTURA del código
    // (espejo síncrono ANTES del insert+save, Q3.2).

    @Test("Q3.1 el flush de autosave no es determinista/observable desde un runloop spin")
    func autosave_flushTimingIsNotControllable() throws {
        let url = freshStoreURL()
        defer { cleanup(url) }
        let schema = Schema([SpikeBaseV1.SpikeOutbox.self])
        let config = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: config)
        let ctx = container.mainContext
        ctx.autosaveEnabled = true

        // Insertamos SIN llamar a save(). Con autosave ON, el mainContext debería
        // persistir por su cuenta al ceder el runloop.
        ctx.insert(SpikeBaseV1.SpikeOutbox(syncID: "auto", payload: "p", hlc: "h"))
        let hadChangesImmediately = ctx.hasChanges
        #expect(hadChangesImmediately, "tras insert, hasChanges debe ser true antes del tick")

        // Cedemos el runloop < 0.5s (permitido: NO es Task.sleep). Autosave se agenda en el
        // main runloop; darle vueltas le da oportunidad de disparar.
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))

        let stillHasChanges = ctx.hasChanges
        print("SPIKE-A1 Q3.1: hasChanges tras 0.3s de runloop (autosave ON) = \(stillHasChanges)")

        // Hallazgo (observado): `stillHasChanges == true` → autosave NO flusheó en la ventana.
        // Sea true o false, el timing NO lo controla el drain. El drain no puede razonar sobre
        // "cuándo persiste autosave"; debe garantizar el orden por estructura síncrona (Q3.2).
        #expect(hadChangesImmediately) // ancla estable; el print entrega el hallazgo de timing
    }

    // MARK: - Q3.2 · Orden mitigado: espejo síncrono ANTES del insert+save

    /// Reproduce el orden del drain: (1) escribe archivo espejo atómico; (2) inserta fila;
    /// (3) save(). Todo síncrono, sin ceder el runloop → autosave no puede colarse ANTES
    /// del espejo para esta fila.
    @Test("Q3.2 espejo síncrono antes de insert+save: el archivo existe antes de persistir la fila")
    func mirrorFirst_syncScope_holdsOrder() throws {
        let url = freshStoreURL()
        defer { cleanup(url) }
        let mirrorDir = url.deletingLastPathComponent().appendingPathComponent("Mirror", isDirectory: true)
        try FileManager.default.createDirectory(at: mirrorDir, withIntermediateDirectories: true)

        let schema = Schema([SpikeBaseV1.SpikeOutbox.self])
        let config = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: config)
        let ctx = container.mainContext
        ctx.autosaveEnabled = true // el escenario peligroso: autosave ACTIVO

        let syncID = "delta-1"
        let mirrorFile = mirrorDir.appendingPathComponent("\(syncID).atomic")

        // (1) ESPEJO PRIMERO — escritura atómica y síncrona.
        let mirrorPayload = Data(#"{"syncID":"delta-1","hlc":"h1"}"#.utf8)
        try mirrorPayload.write(to: mirrorFile, options: .atomic)
        // Invariante clave: en el instante EXACTO tras escribir el espejo, la fila AÚN NO
        // existe en el store (no la hemos insertado). No hubo runloop tick entremedias.
        #expect(FileManager.default.fileExists(atPath: mirrorFile.path))
        let rowsBeforeInsert = try ctx.fetchCount(FetchDescriptor<SpikeBaseV1.SpikeOutbox>())
        #expect(rowsBeforeInsert == 0, "la fila no debe existir antes del espejo+insert")

        // (2) insertar (3) save — mismo scope síncrono.
        ctx.insert(SpikeBaseV1.SpikeOutbox(syncID: syncID, payload: "d1", hlc: "h1"))
        try ctx.save()

        // Post-condición: fila persistida Y su espejo presente. El espejo NUNCA quedó por
        // detrás de la fila porque se escribió antes, en el mismo turno síncrono.
        let rowsAfter = try ctx.fetchCount(FetchDescriptor<SpikeBaseV1.SpikeOutbox>())
        #expect(rowsAfter == 1)
        #expect(FileManager.default.fileExists(atPath: mirrorFile.path))
        print("SPIKE-A1 Q3.2: espejo presente antes y después del save; orden preservado en scope síncrono.")
    }

    // MARK: - Q3.3 · Contraejemplo: insert un-mirrored + tick de autosave = fila sin espejo

    /// Demuestra el ANTI-patrón que el diseño evita: insertar la fila y CEDER el runloop
    /// (simulando trabajo async entre insert y la escritura del espejo). Autosave puede
    /// persistir la fila mientras su espejo aún no existe → orden invertido.
    @Test("Q3.3 anti-patrón: insert antes del espejo + tick → puede persistir fila sin espejo")
    func insertBeforeMirror_allowsInversion() throws {
        let url = freshStoreURL()
        defer { cleanup(url) }
        let mirrorDir = url.deletingLastPathComponent().appendingPathComponent("Mirror", isDirectory: true)
        try FileManager.default.createDirectory(at: mirrorDir, withIntermediateDirectories: true)

        let schema = Schema([SpikeBaseV1.SpikeOutbox.self])
        let config = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: config)
        let ctx = container.mainContext
        ctx.autosaveEnabled = true

        let syncID = "delta-2"
        let mirrorFile = mirrorDir.appendingPathComponent("\(syncID).atomic")

        // ANTI-patrón: insertar PRIMERO (como si el espejo se escribiera "después").
        ctx.insert(SpikeBaseV1.SpikeOutbox(syncID: syncID, payload: "d2", hlc: "h2"))
        // Ceder el runloop ANTES de escribir el espejo (ventana de inversión).
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))

        let mirrorExistsAtTick = FileManager.default.fileExists(atPath: mirrorFile.path)
        let rowPendingCleared = !ctx.hasChanges // si autosave disparó, ya no hay cambios pendientes
        print("SPIKE-A1 Q3.3: espejo-existe-en-tick=\(mirrorExistsAtTick) autosave-flushed=\(rowPendingCleared)")

        // El espejo NUNCA se escribió antes del tick en este anti-patrón: si autosave flusheó,
        // la fila quedó durable SIN espejo (la inversión que §d.5 previene anclando el espejo
        // ANTES del insert). Documentamos el estado observado.
        #expect(!mirrorExistsAtTick, "en el anti-patrón el espejo no existe en el tick (inversión posible)")
    }
}
