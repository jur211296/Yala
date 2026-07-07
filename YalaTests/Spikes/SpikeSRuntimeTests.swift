//
//  SpikeSRuntimeTests.swift
//  YalaTests / Spikes
//
//  SPIKE I0 · S-runtime (parte SIM, diferidos #21). Tres preguntas de plataforma:
//   (a) `ModelConfiguration(cloudKitDatabase: .automatic)` en SIM SIN cuenta iCloud:
//       ¿el container ABRE? ¿lanza? ¿se comporta como local?
//   (b) ¿`.NSPersistentStoreRemoteChange` se dispara para un store `.none` cuando OTRO
//       ModelContainer escribe al MISMO store file? (detección de writes cross-container).
//   (c) Ubicación FÍSICA del SQLite bajo `.automatic` vs `.none` vs default (imprime URLs reales).
//
//  NOTA: aislado en su propia suite/archivo a PROPÓSITO — abrir `.automatic` puede adjuntar
//  NSPersistentCloudKitContainer y (en un sim sin iCloud) entrar en loop de recoverFromError;
//  si desestabilizara el proceso, solo cae ESTA suite, no S1/S3/S4. Los tests documentan la
//  realidad observada (afirmaciones adaptativas donde el resultado es incierto por plataforma).
//

import CloudKit
import CoreData
import Foundation
import SwiftData
import Testing

@testable import Yala

enum SpikeSRT {
    @Model final class Item {
        var name: String = ""
        init(name: String) { self.name = name }
    }
}

@Suite("SpikeS-runtime · .automatic sin iCloud / remote-change / URLs físicas", .serialized)
@MainActor
struct SpikeSRuntimeTests {

    private func freshStoreURL(_ tag: String) -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SpikeSRT-\(tag)-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("store.sqlite")
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    // MARK: - (a) .automatic en sim sin cuenta iCloud

    @Test("(a) ModelConfiguration(.automatic) en sim SIN iCloud → abre / lanza / local?")
    func automaticWithoutICloudAccount_openBehavior() throws {
        let icloud = FileManager.default.ubiquityIdentityToken != nil
        let ckStatus: String
        // No bloqueamos en la cuenta CloudKit real; solo registramos el token de iCloud del sim.
        ckStatus = "ubiquityIdentityToken != nil = \(icloud)"
        print("SPIKE-SRT (a) entorno: \(ckStatus)")

        let url = freshStoreURL("automatic")
        defer { cleanup(url) }
        let schema = Schema([SpikeSRT.Item.self])

        enum OpenResult: CustomStringConvertible {
            case openedLocalUsable(Int)
            case openedButUnusable(String)
            case threw(String)
            var description: String {
                switch self {
                case .openedLocalUsable(let n): return "openedLocalUsable(count=\(n))"
                case .openedButUnusable(let e): return "openedButUnusable(\(e))"
                case .threw(let e): return "threw(\(e))"
                }
            }
        }

        var result: OpenResult
        do {
            let config = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .automatic)
            let container = try ModelContainer(for: schema, configurations: config)
            let ctx = ModelContext(container)
            do {
                ctx.insert(SpikeSRT.Item(name: "local-write"))
                try ctx.save()
                let count = try ctx.fetchCount(FetchDescriptor<SpikeSRT.Item>())
                result = .openedLocalUsable(count)
            } catch {
                result = .openedButUnusable(String(describing: error))
            }
        } catch {
            result = .threw(String(describing: error))
        }

        print("SPIKE-SRT (a) VEREDICTO .automatic sin iCloud → \(result)")
        // Documenta la realidad. Esperado en sim sin iCloud: abre y se comporta como LOCAL
        // (escritura/lectura OK; el mirror CloudKit no puede subir sin cuenta pero no impide
        // el uso local). Afirmación adaptativa — cualquier outcome es un hallazgo válido.
        switch result {
        case .openedLocalUsable, .openedButUnusable, .threw:
            #expect(Bool(true), "outcome documentado: \(result)")
        }
    }

    // MARK: - (b) NSPersistentStoreRemoteChange cross-container sobre el mismo store `.none`

    @Test("(b) ¿.NSPersistentStoreRemoteChange se dispara cuando OTRO container escribe al mismo store .none?")
    func remoteChangeNotification_crossContainer_sameStore() async throws {
        let url = freshStoreURL("remotechange")
        defer { cleanup(url) }
        let schema = Schema([SpikeSRT.Item.self])

        // Container A (el "observador").
        let containerA = try ModelContainer(
            for: schema, configurations: ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        )
        // Semilla en A para materializar el store físico.
        let ctxA = ModelContext(containerA)
        ctxA.insert(SpikeSRT.Item(name: "seed"))
        try ctxA.save()

        final class Flag: @unchecked Sendable { var fired = false }
        let flag = Flag()
        let token = NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange, object: nil, queue: nil
        ) { _ in flag.fired = true }
        defer { NotificationCenter.default.removeObserver(token) }

        // Container B (el "escritor") sobre el MISMO archivo.
        let containerB = try ModelContainer(
            for: schema, configurations: ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        )
        let ctxB = ModelContext(containerB)
        ctxB.insert(SpikeSRT.Item(name: "written-by-B"))
        try ctxB.save()

        // Poll acotado (≤ ~2s, sleeps de 100ms — bajo el límite de 0.5s).
        for _ in 0..<20 {
            if flag.fired { break }
            try await Task.sleep(for: .milliseconds(100))
        }

        print("SPIKE-SRT (b) VEREDICTO: .NSPersistentStoreRemoteChange fired = \(flag.fired)")
        // Afirmación adaptativa: si NO se dispara para stores `.none`, el motor NO puede
        // confiar en esta notificación para detectar writes cross-container (App Group) →
        // debe usar otro mecanismo (p.ej. PendingIntentSaveSignal / polling del outbox).
        #expect(flag.fired || !flag.fired, "outcome documentado: fired=\(flag.fired)")
    }

    // MARK: - (c) URLs físicas .automatic vs .none vs default

    @Test("(c) ubicación física del SQLite: .automatic vs .none vs default")
    func physicalStoreURLs() throws {
        let schema = Schema([SpikeSRT.Item.self])

        let autoURL = freshStoreURL("phys-auto")
        let noneURL = freshStoreURL("phys-none")
        defer { cleanup(autoURL); cleanup(noneURL) }

        let autoCfg = ModelConfiguration(schema: schema, url: autoURL, cloudKitDatabase: .automatic)
        let noneCfg = ModelConfiguration(schema: schema, url: noneURL, cloudKitDatabase: .none)
        let defaultCfg = ModelConfiguration(schema: schema) // sin url → SwiftData elige (App Support)

        print("SPIKE-SRT (c) .automatic url = \(autoCfg.url.path)")
        print("SPIKE-SRT (c) .none     url = \(noneCfg.url.path)")
        print("SPIKE-SRT (c) default   url = \(defaultCfg.url.path)")

        // El default NO debe coincidir con nuestras URLs temp explícitas; las explícitas se respetan.
        #expect(autoCfg.url == autoURL)
        #expect(noneCfg.url == noneURL)
        #expect(defaultCfg.url != autoURL && defaultCfg.url != noneURL)
        print("SPIKE-SRT (c) default store dir = \(defaultCfg.url.deletingLastPathComponent().path)")
    }
}
