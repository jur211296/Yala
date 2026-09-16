//
//  ReverseUploadControllerWiringTests.swift
//  YalaTests / CloudSync
//
//  Cableado de `CloudMigrationController` para la espera de «Volver a iCloud» (ticket
//  `reverse-upload-has-no-ceiling-and-no-exit`, segunda pasada de review). Va por source-scan, como
//  `AdoptEngineInSessionTests`: el controller tiene `init` privado, vive como singleton sobre el `mainContext` y su
//  pre-espera lee `iCloudSyncService.shared`, así que ninguno de estos tres comportamientos se puede observar desde
//  un test de unidad. Lo que decide cada uno —`ReverseExitPending` y el runner— sí tiene tests de comportamiento;
//  estos fijan que el controller los consulta donde toca.
//

import Foundation
import Testing

@testable import Yala

@Suite("Vuelta a iCloud: cableado del controller (source-scan)")
struct ReverseUploadControllerWiringTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/CloudSync/
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }

    private static func controllerSource() throws -> String {
        try String(
            contentsOf: repoRoot.appendingPathComponent("Yala/Services/CloudSync/CloudMigrationController.swift"),
            encoding: .utf8)
    }

    /// Cuerpo de un `func`, de su llave de apertura a la de cierre, sin líneas de comentario: nombrar un símbolo en
    /// un comentario no puede pintar el test de verde.
    private static func body(of marker: String) throws -> String {
        let source = try controllerSource()
        let start = try #require(source.range(of: marker), "la firma de `\(marker)` cambió")
        let chars = Array(source[start.upperBound...])
        var depth = 1
        var i = 0
        while i < chars.count {
            if chars[i] == "{" { depth += 1 }
            if chars[i] == "}" { depth -= 1; if depth == 0 { break } }
            i += 1
        }
        return String(chars[0..<min(i, chars.count)])
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    private static func occurrences(of needle: String, in text: String) -> Int {
        text.components(separatedBy: needle).count - 1
    }

    /// El aviso «Aún no podemos volver a iCloud» sale justo con un efecto pendiente, que es lo que dispara el re-kick
    /// de 30 s de la pantalla. Si ese re-kick borra `lastError`, el aviso se cierra solo entre 0 y 30 s después de
    /// aparecer. Solo lo borra una acción de la persona.
    @Test func backgroundRekick_doesNotClearTheError() throws {
        let rekick = try Self.body(of: "func rekickIfParked() async {")
        #expect(rekick.contains("resumeIfNeeded(clearingError: false)"))
        #expect(Self.occurrences(of: "resumeIfNeeded(", in: rekick) == 1, "ninguna otra llamada que borre el aviso")

        let ifNeeded = try Self.body(of: "func resumeIfNeeded(clearingError: Bool = true) async {")
        #expect(ifNeeded.contains("resume(clearingError: clearingError)"))
        #expect(ifNeeded.contains("pollLeader(clearingError: clearingError)"))

        for marker in ["func resume(clearingError: Bool = true) async {",
                       "func pollLeader(clearingError: Bool = true) async {"] {
            let fn = try Self.body(of: marker)
            #expect(fn.contains("if clearingError { lastError = nil }"), "\(marker)")
            #expect(Self.occurrences(of: "lastError = nil", in: fn) == 1, "\(marker): sin otro borrado incondicional")
        }
    }

    /// El aviso habla de reactivar la nube, así que solo sale con ESA salida pendiente. Con otro pendiente el runner
    /// empieza la vuelta igual, y el aviso mentiría.
    @Test func pendingExitNotice_onlyWithTheExitPending() throws {
        let start = try Self.body(of: "func startReverse() async {")
        #expect(start.contains("if hasPendingReverseExit, MigrationRuntimeGate.isDomainStablePhase(journaledPhase) {"))
        #expect(!start.contains("pendingEffectCount"), "el recuento de pendientes no distingue la salida")

        let snapshot = try Self.body(of: "private func readJournalSnapshot() -> (phase: MigrationPhase, pendingCount: Int) {")
        #expect(snapshot.contains("hasPendingReverseExit = ReverseExitPending.isPending(pending)"))
        #expect(Self.occurrences(of: "hasPendingReverseExit = false", in: snapshot) == 2,
                "sin fila y con el fetch fallido no queda un aviso de la lectura anterior")
    }

    /// Un «sí» de «Cancelar» que la pre-espera no deja pasar queda apuntado, y lo ejecuta el siguiente `resume()`
    /// ANTES de retomar: al revés, el runner podía observar, drenar y terminar la vuelta que la persona canceló.
    @Test func queuedCancel_runsBeforeTheResume() throws {
        let cancel = try Self.body(of: "func cancelReverseUpload() async {")
        let flagged = try #require(cancel.range(of: "cancelReverseRequested = true"))
        let preWait = try #require(cancel.range(of: "awaitImportQuiescenceForResume()"))
        #expect(flagged.lowerBound < preWait.lowerBound, "se apunta antes de que la pre-espera pueda vencer")

        let resume = try Self.body(of: "func resume(clearingError: Bool = true) async {")
        let resumePreWait = try #require(resume.range(of: "awaitImportQuiescenceForResume()"))
        let queued = try #require(resume.range(of: "if cancelReverseRequested {"))
        let cancelCall = try #require(resume.range(of: "await runner.cancelReverseUpload()"))
        let resumeCall = try #require(resume.range(of: "await runner.resume()"))
        #expect(resumePreWait.lowerBound < queued.lowerBound, "solo tras la pre-espera")
        #expect(queued.lowerBound < cancelCall.lowerBound)
        #expect(cancelCall.lowerBound < resumeCall.lowerBound, "cancela antes de retomar")

        let start = try Self.body(of: "func startReverse() async {")
        #expect(start.contains("cancelReverseRequested = false"), "una vuelta nueva no hereda un «Cancelar» viejo")
    }
}
