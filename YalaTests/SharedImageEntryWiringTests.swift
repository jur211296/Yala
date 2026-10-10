//
//  SharedImageEntryWiringTests.swift
//  YalaTests
//
//  Ticket share-image-reading-does-not-always-start. El cableado, por source-scan: las piezas viven en el arranque y
//  en `ContentView`, que la suite no monta.
//

import Foundation
import Testing
@testable import Yala

@Suite("Entrada de foto compartida · cableado")
@MainActor
struct SharedImageEntryWiringTests {

    // MARK: - Cableado (source-scan)

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }

    /// Solo el código: los docblocks nombran a propósito las piezas, y un `contains` sobre el fichero crudo se cumpliría
    /// leyendo prosa.
    private static func code(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    private static func offset(of needle: String, in haystack: String) -> String.Index? {
        haystack.range(of: needle)?.lowerBound
    }

    /// Antes del arranque, `handleIncomingURL` aparta lo que decide con estado sin cargar, y lo hace ANTES del
    /// `switch` que trata `shared-image` (si fuera después, la puerta Pro ya habría decidido).
    @Test func incomingURL_setsAsideDecidingHostsBeforeTreatingThem() throws {
        let boot = try Self.code("Yala/App/AppBootstrapper.swift")
        let gate = try #require(Self.offset(of: "EntryReadinessLogic.waitsForBootstrap(host: url.host, isInitialized: isInitialized)", in: boot))
        let share = try #require(Self.offset(of: "case \"shared-image\":", in: boot))
        #expect(gate < share)
    }

    /// Lo apartado se trata al terminar el arranque: después de `isInitialized = true` y antes de la recuperación
    /// del paso 21 (que colapsa con él por `id`). La acción del Centro de Control, también después.
    @Test func bootstrap_replaysWhatWaitedAfterInitialization() throws {
        let boot = try Self.code("Yala/App/AppBootstrapper.swift")
        let initialized = try #require(Self.offset(of: "isInitialized = true", in: boot))
        let replay = try #require(Self.offset(of: "for url in awaiting { handleIncomingURL(url) }", in: boot))
        let recovery = try #require(Self.offset(of: "checkForPendingSharedImage(site: \"bootstrap\")", in: boot))
        #expect(initialized < replay)
        #expect(replay < recovery)
        // Dentro de `bootstrap`, no la llamada de `handleBecameActive` (que va más abajo en el fichero).
        let bootstrapEnd = try #require(Self.offset(of: "func applyUITestHooksEarly(", in: boot))
        #expect(boot[recovery..<bootstrapEnd].contains("checkForPendingControlAction()"),
                "El Centro de Control se vuelve a mirar al terminar el arranque.")
    }

    /// La acción del Centro de Control no se consume (se borra su clave) antes del arranque.
    @Test func controlAction_isNotConsumedBeforeBootstrap() throws {
        let boot = try Self.code("Yala/App/AppBootstrapper.swift")
        let gate = try #require(Self.offset(of: "EntryReadinessLogic.controlActionMayRun(isInitialized: isInitialized) else { return }", in: boot))
        let clear = try #require(Self.offset(of: "defaults.removeObject(forKey: \"pendingControlAction\")", in: boot))
        #expect(gate < clear)
    }

    /// Completar el onboarding saca lo aplazado sin esperar a un `.active`.
    @Test func onboardingCompletion_resumesDeferredEntries() throws {
        let content = try Self.code("Yala/App/ContentView.swift")
        // Dentro del `onChange(of: hasCompletedOnboarding)` y solo al pasar a `true`.
        let observer = try #require(Self.offset(of: ".onChange(of: hasCompletedOnboarding)", in: content))
        let call = try #require(content.range(of: "if newValue { AppBootstrapper.shared.resumeEntriesAfterOnboarding() }",
                                              range: observer..<content.endIndex))
        #expect(content[observer..<call.lowerBound].components(separatedBy: ".onChange(").count == 2,
                "La llamada tiene que estar en el observador del onboarding, no en otro posterior.")
        let boot = try Self.code("Yala/App/AppBootstrapper.swift")
        let body = try #require(boot.range(of: "func resumeEntriesAfterOnboarding()"))
        let tail = boot[body.upperBound...]
        let end = try #require(tail.range(of: "\n    }\n"))
        let resume = tail[..<end.lowerBound]
        #expect(resume.contains("checkForPendingSharedImage(site: \"onboardingCompleted\")"))
        #expect(resume.contains("RouterEntryGate.shared.drainDeferredBuffer()"))
    }
}
