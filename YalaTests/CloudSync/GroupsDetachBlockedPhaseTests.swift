//
//  GroupsDetachBlockedPhaseTests.swift
//  YalaTests / CloudSync
//
//  Ticket `detach-blocked-phase-is-stranded-when-the-storage-sheet-closes-mid-wait`. Tocas «Desasociar», la espera
//  arranca (subir cambios, esperar a que iCloud baje datos), cierras la hoja de Almacenamiento y el gesto acaba
//  bloqueado. Hasta el 2026-10-02 el bloqueo se quedaba en la fase COMPARTIDA del coordinador hasta que el aviso de la
//  sección lo reconociera, y con la hoja cerrada ese aviso se escribía en una vista ya desmontada: nadie llamaba a
//  `acknowledgeBlocked()`, «Cerrar sesión» no hacía nada y un desasociar nuevo devolvía `.busy` («Estás cerrando sesión»,
//  falso). Solo salía matando la app.
//
//  **Medido antes del arreglo** con el primer caso de comportamiento, sin reconocer nada (que es la hoja cerrada): la fase
//  quedaba `.blocked(pendingCount: Int.max, reason: .uploadRetryLater)` y el segundo desasociar devolvía `.busy`.
//
//  Dos suites:
//   1. **Comportamiento**, con el coordinador real. El bloqueo se provoca sin red ni sesión: la captura de salida del canal
//      (`GroupsExitWitness.capture`) dice «no terminé», y con el outbox vacío el push-all bloquea con
//      `.groupsCaptureUnfinished` (hasta el 2026-10-05, `.uploadRetryLater`), que se enseña al momento. Desde el 2026-10-05 la captura atascada cicla una vez para saber la causa, contra un ciclo
//      sustituido (`GroupsExitWitness.cycle`) que no toca la red. Nada del gesto
//      después del push-all llega a correr: ni teardown, ni `signOut()`, ni puente, ni borrado.
//   2. **Cableado**, source-scan: que TODO bloqueo del desasociar pase por el único sitio que suelta la fase, y que la
//      sección lea el motivo del retorno, el spinner del coordinador, y no reconozca una fase que ya no es suya.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Desasociar · un bloqueo sin pantalla no deja el coordinador cogido", .serialized)
struct GroupsDetachBlockedPhaseTests {

    private let coordinator = CloudSessionSignOut.shared

    private func reset() {
        coordinator.acknowledgeBlocked()
        coordinator.exitWitnessOverride = nil
        coordinator.exitCaptureDelayOverride = nil
    }

    /// La captura de salida no termina y lo que queda fuera es de esta sesión. Desde el 2026-10-05 la captura atascada cicla
    /// para saber la causa (`captureGroupsForExit`): el ciclo es el de un canal sano y no toca la red, y el desenlace es el
    /// del drain atascado en un teléfono sano, `.groupsCaptureUnfinished` (`stuckCaptureVerdict`; hasta el 2026-10-05,
    /// `.uploadRetryLater`).
    private func captureFails(observing: @escaping @MainActor () -> Void = {}) -> CloudSessionSignOut.GroupsExitWitness {
        coordinator.exitCaptureDelayOverride = .milliseconds(1)
        var witness = CloudSessionSignOut.GroupsExitWitness(
            capture: { _ in observing(); return false },
            mirrorPending: { _, _ in 0 }, mirrorPendingKeys: { _, _ in [] })
        witness.uncapturedChanges = { _ in [.init(key: "h1", heldForAnotherAccount: false)] }
        witness.cycle = { _ in
            CloudSessionSignOut.GroupsCycleReading(
                outcome: .completed, channelKilled: false, attestUnavailable: false, uploadFailed: false)
        }
        return witness
    }

    /// Con una fila viva el pre-check no corta y el push-all ciclaría contra el cliente real: se exige el outbox vacío.
    private func emptyOutboxContext() throws -> ModelContext {
        let context = try makeTestContext()
        for row in try context.fetch(FetchDescriptor<GroupSyncOutbox>()) { context.delete(row) }
        try context.save()
        try #require(CloudSessionSignOut.liveGroupsPendingCount(context: context) == 0)
        return context
    }

    @Test("MUTACIÓN: bloqueado y sin nadie que lo reconozca, el motivo sale por el retorno y la fase queda libre")
    func blockedWithNobodyWatching_releasesThePhase() async throws {
        reset(); defer { reset() }
        try #require(coordinator.phase == .idle, "el coordinador venía ocupado de otro test")
        let context = try emptyOutboxContext()
        coordinator.exitWitnessOverride = captureFails()

        // La hoja cerrada: nadie llama a `acknowledgeBlocked()` entre los dos gestos.
        let first = await coordinator.detachGroupsAccount(context: context, choice: .keep)

        #expect(first == .blockedBeforeWriting(reason: .groupsCaptureUnfinished), """
            el motivo del bloqueo no viaja por el retorno: la sección no tendría de dónde leerlo con la fase ya libre
            """)
        #expect(coordinator.phase == .idle, """
            el bloqueo del desasociar se quedó en la fase compartida (\(coordinator.phase)): con la hoja cerrada nadie lo \
            reconoce, «Cerrar sesión» no hace nada y el desasociar siguiente dice «Estás cerrando sesión»
            """)
        #expect(!coordinator.isDetaching, "el desasociar terminó y el coordinador sigue diciendo que desasocia")

        let second = await coordinator.detachGroupsAccount(context: context, choice: .keep)
        #expect(second == .blockedBeforeWriting(reason: .groupsCaptureUnfinished), """
            el segundo desasociar no volvió a intentarlo (\(second)): `.busy` es el «Estás cerrando sesión» falso del ticket
            """)
        #expect(coordinator.phase == .idle)
    }

    @Test("MUTACIÓN: mientras el gesto está en vuelo el coordinador dice que desasocia, y deja de decirlo al terminar")
    func isDetaching_coversTheWholeGesture() async throws {
        reset(); defer { reset() }
        try #require(coordinator.phase == .idle)
        try #require(!coordinator.isDetaching, "control: nadie desasocia antes del gesto")
        let context = try emptyOutboxContext()
        var seenInFlight: Bool?
        var phaseInFlight: CloudSessionSignOut.Phase?
        coordinator.exitWitnessOverride = captureFails(observing: {
            seenInFlight = CloudSessionSignOut.shared.isDetaching
            phaseInFlight = CloudSessionSignOut.shared.phase
        })

        _ = await coordinator.detachGroupsAccount(context: context, choice: .keep)

        #expect(phaseInFlight == .working, "control: la captura no corrió dentro del gesto, este test no mediría nada")
        #expect(seenInFlight == true, """
            a mitad de la espera el coordinador no dice que desasocia: la sección reabierta no pinta el spinner y un toque en \
            «Desasociar» choca con el gesto en vuelo y dice «Estás cerrando sesión»
            """)
        #expect(!coordinator.isDetaching)
    }
}

/// El arreglo vive en N sitios: los cinco `return .blockedBeforeWriting` del gesto y tres lecturas de la sección. El caso
/// de comportamiento solo recorre una rama; esto fija las demás.
@Suite("Desasociar · el bloqueo pasa por un solo sitio y la sección no depende de la fase (source-scan)")
struct GroupsDetachBlockedPhaseWiringTests {

    private static func code(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // CloudSync/
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    private static func body(of marker: String, in source: String) throws -> String {
        let start = try #require(source.range(of: marker), "no se encontró `\(marker)`")
        var depth = 1
        var out = ""
        for ch in source[start.upperBound...] {
            if ch == "{" { depth += 1 }
            if ch == "}" { depth -= 1; if depth == 0 { break } }
            out.append(ch)
        }
        return out
    }

    private static func slice(from start: String, to end: String, in source: String) throws -> String {
        let a = try #require(source.range(of: start), "no se encontró `\(start)`")
        let b = try #require(source.range(of: end, range: a.upperBound..<source.endIndex), "no se encontró `\(end)`")
        return String(source[a.lowerBound..<b.lowerBound])
    }

    private static let released = "return .blockedBeforeWriting(reason: releaseDetachBlock())"

    @Test("MUTACIÓN: todo bloqueo del desasociar suelta la fase por `releaseDetachBlock`, y nadie más lo devuelve")
    func everyDetachBlockReleasesThePhase() throws {
        let source = try Self.code("Yala/Services/CloudSync/CloudSessionSignOut.swift")
        let detach = try Self.slice(from: "func detachGroupsAccount(", to: "private func releaseDetachBlock()", in: source)
        let devueltos = detach.components(separatedBy: "return .blockedBeforeWriting(").count - 1
        let soltados = detach.components(separatedBy: Self.released).count - 1
        #expect(devueltos == 5, "el desasociar tiene \(devueltos) bloqueos; eran cinco (push-all, residual, sesión que sobrevive, sesión que vuelve, sin quietud)")
        #expect(soltados == devueltos, """
            \(devueltos - soltados) bloqueo(s) del desasociar devuelven su motivo sin soltar la fase: con la hoja cerrada a \
            mitad de la espera, ése se queda en `.blocked` para siempre
            """)
        #expect(source.components(separatedBy: "return .blockedBeforeWriting(").count - 1 == devueltos, """
            otro método del coordinador devuelve `.blockedBeforeWriting`: tendría que soltar la fase igual
            """)

        // El reintento del borrado también espera (hasta un minuto) y también pinta el spinner por el coordinador: sin
        // esto, «Terminar de soltar la cuenta» seguiría a la vista y un segundo toque diría «Estás cerrando sesión».
        let retry = try Self.slice(from: "func retryDetachPurge(", to: "private func finishDetach(", in: source)
        let guardBusy = try #require(retry.range(of: "else { return .busy }", options: .backwards))
        let on = try #require(retry.range(of: "isDetaching = true\n        defer { isDetaching = false }"),
                              "el reintento del borrado no publica `isDetaching` con su `defer`")
        #expect(guardBusy.upperBound <= on.lowerBound, "`isDetaching` se enciende antes de los guards de `.busy`")

        let release = try Self.body(of: "private func releaseDetachBlock() -> CloudSignOutFlowLogic.BlockReason {", in: source)
        #expect(release.contains("defer { phase = .idle }"), "`releaseDetachBlock` ya no devuelve la fase a `.idle`")
        #expect(!release.contains("await"), "`releaseDetachBlock` suspende: un lector de la fase vería el `.blocked`")
    }

    @Test("MUTACIÓN: la sección lee el motivo del retorno, el spinner del coordinador, y no reconoce la fase")
    func sectionDoesNotDependOnThePhase() throws {
        let section = try Self.code("Yala/App/Views/Settings/GroupsAssociationSection.swift")
        #expect(!section.contains("signOutCoordinator.phase"), """
            la sección vuelve a leer la fase del coordinador: el desasociar ya no deja su bloqueo ahí, y `.working` es \
            también la de un cierre de sesión
            """)
        #expect(section.contains("case .blockedBeforeWriting(let reason):"), "la sección no lee el motivo del retorno")
        #expect(try Self.slice(from: "case .blockedBeforeWriting(let reason):", to: "case .purgeFailed:", in: section)
            .contains("blockedReason = reason"), "el motivo devuelto no llega al aviso")
        #expect(section.contains("private var isWorking: Bool { signOutCoordinator.isDetaching }"), """
            el spinner de la sección ya no lo decide el coordinador: la hoja reabierta a mitad de la espera no lo pinta
            """)
        #expect(!section.contains("acknowledgeBlocked"), """
            la sección reconoce la fase del coordinador: la que encuentre ya no es suya, y le borraría a un cierre de \
            sesión el `blockedExit` que recuerda dónde retomarlo
            """)
    }
}
