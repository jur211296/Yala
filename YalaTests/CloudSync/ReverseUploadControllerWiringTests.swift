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

    /// La alerta de una salida del claim (ticket `reverse-claim-rejection-has-no-way-out-in-the-client`, D3 y D8) sale
    /// solo si la salida es NUEVA: la foto de `lastReverseClaimExit` se toma ANTES de llamar al runner y se compara
    /// después. Tomada después, la alerta no saldría nunca; sin comparar, saldría también por la nota de un intento
    /// anterior. Y el texto sale del motivo de la salida, no del journal releído, con la misma función que la nota de la
    /// tarjeta. Los dos caminos que conducen el claim la usan: el toque (`startReverse`, donde el aviso de la salida
    /// pendiente manda porque con él no hubo claim) y `resume`, que es «Retomar» y el re-kick.
    @Test func claimExitAlert_onlyForANewExit_fromTheTapAndFromResume() throws {
        let helper = try Self.body(of: "private func announceReverseClaimExit(since before: ReverseClaimExit?) {")
        let helperLines = helper.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        #expect(helperLines == [
            "guard let exit = _runner?.lastReverseClaimExit, exit != before else { return }",
            "lastError = L10n.Storage.ReverseAbort.note(for: exit.reason)",
        ], "el cuerpo entero: comparar con la foto y traducir el motivo de ESA salida")

        let start = try Self.body(of: "func startReverse() async {")
        let snapshot = try #require(start.range(of: "let claimExitBefore = r.lastReverseClaimExit"))
        let activated = try #require(start.range(of: "await r.submit(.reverseActivated)"))
        let confirmed = try #require(start.range(of: "await r.submit(.reverseConfirmed)"))
        let refreshed = try #require(start.range(of: "refresh()"))
        let pendingNotice = try #require(start.range(
            of: "if hasPendingReverseExit, MigrationRuntimeGate.isDomainStablePhase(journaledPhase) {"))
        let otherwise = try #require(start.range(of: "} else {"))
        let announce = try #require(start.range(of: "announceReverseClaimExit(since: claimExitBefore)"))
        #expect(snapshot.lowerBound < activated.lowerBound, "la foto va antes de emitir nada")
        #expect(activated.lowerBound < confirmed.lowerBound)
        #expect(confirmed.lowerBound < refreshed.lowerBound)
        #expect(refreshed.lowerBound < pendingNotice.lowerBound)
        #expect(pendingNotice.lowerBound < otherwise.lowerBound, "el aviso de la salida pendiente manda")
        #expect(otherwise.lowerBound < announce.lowerBound)
        #expect(Self.occurrences(of: "lastReverseClaimExit", in: start) == 1, "una foto; la lectura es del helper")

        let resume = try Self.body(of: "func resume(clearingError: Bool = true) async {")
        let preWait = try #require(resume.range(of: "awaitImportQuiescenceForResume()"))
        let resumeSnapshot = try #require(resume.range(of: "let claimExitBefore = runner.lastReverseClaimExit"))
        let cancelCall = try #require(resume.range(of: "await runner.cancelReverseUpload()"))
        let resumeCall = try #require(resume.range(of: "await runner.resume()"))
        let resumeRefresh = try #require(resume.range(of: "refresh()", range: resumeCall.upperBound..<resume.endIndex))
        let resumeAnnounce = try #require(resume.range(of: "announceReverseClaimExit(since: claimExitBefore)"))
        #expect(preWait.lowerBound < resumeSnapshot.lowerBound, "tras la pre-espera: nada del runner corre antes")
        #expect(resumeSnapshot.lowerBound < cancelCall.lowerBound, "la foto va antes de cualquier llamada al runner")
        #expect(resumeCall.lowerBound < resumeRefresh.lowerBound)
        #expect(resumeRefresh.lowerBound < resumeAnnounce.lowerBound)
    }

    /// Los dos cuerpos ENTEROS, normalizados (segunda pasada de review). El orden de arriba no caza dos mutantes que
    /// dejan la alerta muda con todo en verde: envolver el aviso de `resume` en `if clearingError { … }` —el re-kick con
    /// la pantalla delante ya no avisaría— y bajar un `lastError = nil` por debajo del aviso —se asigna y se borra en el
    /// mismo turno, y `onChange` solo ve `nil`—. Cambiar cualquiera de las dos funciones obliga a mirar este test.
    @Test func startReverseAndResume_wholeBodiesArePinned() throws {
        func lines(_ body: String) -> [String] {
            body.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        }
        #expect(lines(try Self.body(of: "func startReverse() async {")) == [
            "isWorking = true",
            "defer { isWorking = false }",
            "lastError = nil",
            "cancelReverseRequested = false",
            "let r = runner",
            "let claimExitBefore = r.lastReverseClaimExit",
            "await r.submit(.reverseActivated)    // done/notStarted → reverseConfirm(origin)",
            "await r.submit(.reverseConfirmed)    // → reverseClaimLeader → drive",
            "refresh()",
            "if hasPendingReverseExit, MigrationRuntimeGate.isDomainStablePhase(journaledPhase) {",
            "lastError = L10n.Storage.Errors.reversePendingExit",
            "} else {",
            "announceReverseClaimExit(since: claimExitBefore)",
            "}",
        ])
        #expect(lines(try Self.body(of: "func resume(clearingError: Bool = true) async {")) == [
            "guard !isWorking else { return }",
            "isWorking = true",
            "defer { isWorking = false }",
            "if clearingError { lastError = nil }",
            "guard await awaitImportQuiescenceForResume() else {",
            "refresh()",
            "return",
            "}",
            "let claimExitBefore = runner.lastReverseClaimExit",
            "if cancelReverseRequested {",
            "cancelReverseRequested = false",
            "await runner.cancelReverseUpload()",
            "}",
            "await runner.resume()",
            "refresh()",
            "announceReverseClaimExit(since: claimExitBefore)",
            "startRuntimeIfStable()",
        ])
    }

    /// La nota de la tarjeta, la de relanzar y la alerta dicen lo mismo porque salen de UNA función. La vista ya no
    /// tiene su propia traducción del motivo.
    @Test func reverseAbortNote_hasASingleTranslation() throws {
        let view = try String(
            contentsOf: Self.repoRoot.appendingPathComponent("Yala/App/Views/Settings/StorageSettingsView.swift"),
            encoding: .utf8)
        #expect(Self.occurrences(of: "L10n.Storage.ReverseAbort.note(for: reason)", in: view) == 2,
                "la nota de «Volver a iCloud» y la de relanzar")
        for stray in ["L10n.Storage.ReverseAbort.icloudFull", "L10n.Storage.ReverseAbort.icloudUnavailable",
                      "L10n.Storage.ReverseAbort.stalled", "L10n.Storage.ReverseAbort.claim",
                      "L10n.Storage.ReverseAbort.otherDeviceReverting"] {
            #expect(!view.contains(stray), "la vista no traduce motivos por su cuenta: \(stray)")
        }
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
