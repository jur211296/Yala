//
//  TestSimulatorJanitorTests.swift
//  YalaTests
//
//  El pin de `TestSimulatorJanitor` y de los dos defaults que dejan de tocar el simulador. Dos mitades, como en
//  `TestProcessGuardTests`:
//
//   · Comportamiento — que un dominio apuntado se borra con su fichero, y que un directorio con un fichero
//     abierto NO se borra hasta que se cierra (la mitad que quita los avisos de integridad de SQLite).
//   · Cableado (source-scan) — que ningún test crea un dominio sin apuntarlo, que el conserje cuelga del
//     principal class, y que el espejo real de Grupos solo lo recibe el `.shared`.
//

import Foundation
import Testing

@testable import Yala

@Suite("Conserje del simulador · lo que la corrida deja", .serialized)
struct TestSimulatorJanitorTests {

    private static let testsDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    private static let repoDir = testsDir.deletingLastPathComponent()

    private static func codeOnly(_ url: URL) throws -> String {
        try String(contentsOf: url, encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    // MARK: - Comportamiento

    @Test func unDominioApuntadoSeBorraConSuFichero() throws {
        let name = "test.janitor.\(UUID().uuidString)"
        let defaults = try #require(testDefaults(suiteName: name))
        defaults.set("x", forKey: "k")
        defaults.synchronize()
        #expect(TestSimulatorJanitor.isRegistered(defaultsSuite: name))

        TestSimulatorJanitor.removeDefaultsDomain(name)

        #expect(try #require(UserDefaults(suiteName: name)).object(forKey: "k") == nil)
        #expect(!FileManager.default.fileExists(atPath: TestSimulatorJanitor.defaultsPlistURL(name).path),
                "el dominio se vació pero su `.plist` sigue en Library/Preferences: el disco se sigue llenando")
    }

    /// La mitad que carga el peso: con un fd abierto dentro, el directorio se QUEDA; al cerrarlo, se va. Con un
    /// `removeItem` directo (lo de antes) el control de abajo falla: el directorio desaparece con el fichero abierto.
    @Test func unDirectorioConUnFicheroAbiertoEsperaASuCierre() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("JanitorPin-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("store.sqlite")
        #expect(FileManager.default.createFile(atPath: file.path, contents: Data("x".utf8)))
        let handle = try FileHandle(forReadingFrom: file)

        #expect(TestSimulatorJanitor.hasOpenFiles(under: dir))
        discardTestStoreDirectory(dir)
        #expect(FileManager.default.fileExists(atPath: dir.path), "borró el directorio con un fichero abierto dentro")
        #expect(TestSimulatorJanitor.isPending(dir))

        try handle.close()
        #expect(!TestSimulatorJanitor.hasOpenFiles(under: dir))
        #expect(!TestSimulatorJanitor.isPending(dir), "cerrado el fichero, el siguiente intento lo retira")
        #expect(!FileManager.default.fileExists(atPath: dir.path))
    }

    /// Control del detector: un directorio hermano con el mismo prefijo de nombre no cuenta como «abierto».
    @Test func elDetectorNoConfundeUnDirectorioHermano() throws {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("JanitorPin-\(UUID().uuidString)", isDirectory: true)
        let sibling = URL(fileURLWithPath: base.path + "-hermano", isDirectory: true)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: sibling, withIntermediateDirectories: true)
        let file = sibling.appendingPathComponent("abierto")
        #expect(FileManager.default.createFile(atPath: file.path, contents: Data("x".utf8)))
        let handle = try FileHandle(forReadingFrom: file)
        defer {
            do { try handle.close() } catch { print("TestSimulatorJanitorTests: Error: \(error)") }
            discardTestStoreDirectory(sibling)
        }

        #expect(!TestSimulatorJanitor.hasOpenFiles(under: base))
        discardTestStoreDirectory(base)
        #expect(!FileManager.default.fileExists(atPath: base.path))
    }

    /// La red del onboarding: lo ausente vuelve a ausente (no a `false`) y lo presente a su valor. Sobre un almacén
    /// aislado, porque escribir en `.standard` para probarlo sería justo lo que esta red evita.
    @Test func elOnboardingVuelveAComoEstaba() throws {
        let store = try #require(testDefaults(suiteName: "test.janitor.onboarding.\(UUID().uuidString)"))
        store.set(true, forKey: AppPreferences.Keys.hasShownWelcomeChooser)
        let snapshot = TestSimulatorJanitor.captureOnboarding(from: store)

        store.set(true, forKey: AppPreferences.Keys.hasCompletedOnboarding)
        store.set(false, forKey: AppPreferences.Keys.hasShownWelcomeChooser)
        TestSimulatorJanitor.restoreOnboarding(snapshot, into: store)

        #expect(store.object(forKey: AppPreferences.Keys.hasCompletedOnboarding) == nil,
                "la bienvenida quedó marcada como vista tras la corrida")
        #expect(store.object(forKey: AppPreferences.Keys.hasShownWelcomeChooser) as? Bool == true)
        #expect(Set(TestSimulatorJanitor.onboardingKeys) == ["hasCompletedOnboarding", "hasShownWelcomeChooser"])
    }

    /// Y que la red esté puesta: foto en `startProcess`, restauración en `finishProcess`, las dos sobre `.standard`.
    @Test func laRedDelOnboardingCuelgaDelCicloDelProceso() throws {
        let janitor = try Self.codeOnly(Self.testsDir.appending(path: "TestSimulatorJanitor.swift"))
        func body(_ signature: String) throws -> Substring {
            let start = try #require(janitor.range(of: signature))
            let rest = janitor[start.upperBound...]
            let end = try #require(rest.range(of: "\n    }"))
            return rest[..<end.lowerBound]
        }
        #expect(try body("static func startProcess() {").contains("onboardingSnapshot = captureOnboarding(from: .standard)"))
        #expect(try body("static func finishProcess() {").contains("restoreOnboarding(onboardingSnapshot, into: .standard)"))
    }

    // MARK: - Cableado

    /// Ningún fichero de `YalaTests/` crea un `UserDefaults(suiteName:)` sin apuntarlo. Las únicas llamadas peladas
    /// que quedan son al App Group REAL (que no es de los tests y no se borra) y las del propio conserje. Las que van
    /// dentro de un literal (los source-scans de producción) no son llamadas.
    @Test func ningunTestCreaUnDominioSinApuntarlo() throws {
        let files = (FileManager.default.enumerator(at: Self.testsDir, includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" } ?? [])
        let selfName = URL(fileURLWithPath: #filePath).lastPathComponent
        let real = ["WidgetURLHelper.appGroupIdentifier", "SharedContainerService.appGroupIdentifier"]

        var apuntadas = 0
        var peladas: [String] = []
        for url in files where url.lastPathComponent != selfName {
            let lines = try Self.codeOnly(url).split(separator: "\n", omittingEmptySubsequences: false)
            // Dentro de un literal `"""` (los source-scans que comparan contra producción) no hay llamadas: esas
            // líneas no llevan comillas sueltas, así que el recuento por línea de abajo no las distingue.
            var insideMultiline = false
            for (number, line) in lines.enumerated() {
                let fences = line.components(separatedBy: "\"\"\"").count - 1
                if insideMultiline || fences > 0 {
                    if fences % 2 == 1 { insideMultiline.toggle() }
                    continue
                }
                apuntadas += line.components(separatedBy: "testDefaults(suiteName:").count - 1
                var rest = line[...]
                while let hit = rest.range(of: "UserDefaults(suiteName:") {
                    defer { rest = rest[hit.upperBound...] }
                    if line[..<hit.lowerBound].filter({ $0 == "\"" }).count % 2 == 1 { continue }
                    let arg = line[hit.upperBound...].drop(while: { $0 == " " })
                    if real.contains(where: { arg.hasPrefix($0) }) { continue }
                    if url.lastPathComponent == "TestSimulatorJanitor.swift" { continue }
                    peladas.append("\(url.lastPathComponent):\(number + 1)")
                }
            }
        }

        // Las subclases (`CountingDefaults(suiteName:)`) crean el mismo `.plist` y no pasan por el helper: cada fichero
        // que las construye apunta el nombre a mano, tantas veces como construcciones. Su `removePersistentDomain` del
        // `defer` NO basta: medido el 2026-11-04, vacía el dominio y deja el fichero.
        for url in files where url.lastPathComponent != selfName {
            let code = try Self.codeOnly(url)
            let subclases = code.components(separatedBy: "CountingDefaults(suiteName:").count - 1
            let apuntes = code.components(separatedBy: "TestSimulatorJanitor.registerDefaultsSuite(").count - 1
            if subclases > apuntes { peladas.append("\(url.lastPathComponent) (subclase sin apuntar)") }
        }

        #expect(apuntadas >= 100, "solo \(apuntadas) llamadas a `testDefaults`: el escáner dejó de ver la suite")
        #expect(peladas.isEmpty, """
            \(peladas.joined(separator: ", ")) crea(n) un `UserDefaults(suiteName:)` sin apuntarlo: su `.plist` se queda \
            en Library/Preferences del simulador tras la corrida. Usa `testDefaults(suiteName:)` o \
            `makeIsolatedDefaults()`.
            """)
    }

    @Test func makeIsolatedDefaultsPasaPorElConserje() throws {
        let helpers = try Self.codeOnly(Self.testsDir.appending(path: "TestHelpers.swift"))
        let start = try #require(helpers.range(of: "func makeIsolatedDefaults("))
        let body = helpers[start.upperBound...].prefix(400)
        #expect(body.contains("testDefaults(suiteName: suiteName)"),
                "`makeIsolatedDefaults` vuelve a crear el dominio sin apuntarlo")
    }

    /// El conserje lo arma el principal class: si `armForCurrentProcess` deja de llamarlo, no corre nunca y todo lo
    /// de arriba sigue en verde.
    @Test func elConserjeCuelgaDelPrincipalClass() throws {
        let guardSource = try Self.codeOnly(Self.testsDir.appending(path: "TestProcessGuard.swift"))
        let start = try #require(guardSource.range(of: "static func armForCurrentProcess() {"))
        let body = guardSource[start.upperBound...]
        let end = try #require(body.range(of: "\n    }"))
        let arm = body[..<end.lowerBound]
        #expect(arm.contains("TestSimulatorJanitor.startProcess()"))
        #expect(arm.contains("atexit { TestSimulatorJanitor.finishProcess() }"))
        // Antes del `guard` del App Group: si no resolviera, el conserje no se armaría.
        let janitor = try #require(arm.range(of: "TestSimulatorJanitor.startProcess()"))
        let appGroup = try #require(arm.range(of: "guard let appGroup"))
        #expect(janitor.lowerBound < appGroup.lowerBound)
    }

    /// El espejo real de Grupos solo lo recibe producción. El default del init es `nil` para que una construcción de
    /// test no escriba en el App Group del simulador; `.shared`, la única construcción de `Yala/`, lo pasa explícito.
    @Test func elEspejoRealDeGruposSoloLoRecibeElShared() throws {
        let client = try Self.codeOnly(Self.repoDir.appending(path: "Yala/Services/CloudSync/Groups/GroupsSyncClient.swift"))
        #expect(client.contains("outboxMirror: GroupsOutboxMirror? = nil,"),
                "el default de `outboxMirror` vuelve a ser el espejo real: los tests escriben en el App Group")
        let shared = try #require(client.range(of: "static let shared = GroupsSyncClient("))
        let sharedCall = client[shared.upperBound...].prefix(250)
        #expect(sharedCall.contains("outboxMirror: GroupsOutboxMirror()"),
                "el `.shared` no pasa el espejo: producción se quedaría sin él")

        // Y que no haya OTRA construcción en la app que caiga en el `nil`.
        let appDir = Self.repoDir.appending(path: "Yala")
        let files = (FileManager.default.enumerator(at: appDir, includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" } ?? [])
        var construcciones = 0
        for url in files {
            construcciones += try Self.codeOnly(url).components(separatedBy: "GroupsSyncClient(").count - 1
        }
        #expect(construcciones == 1, """
            \(construcciones) construcciones de `GroupsSyncClient(` en Yala/: una nueva cae en `outboxMirror = nil` y \
            pierde el espejo del App Group. Pásalo explícito y sube este conteo.
            """)
    }
}
