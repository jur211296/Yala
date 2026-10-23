//
//  MigrationImportWaitLogicTests.swift
//  YalaTests / CloudSync
//
//  Ticket `cloud-activation-waits-for-icloud-with-no-way-out` (QA guiado del 2026-10-19): la pre-espera de «Activar la
//  nube» a que iCloud se asiente se podía alargar minutos con «Cancelar» apagado y la pantalla congelada.
//

import Foundation
import Testing

@testable import Yala

@Suite("Activar la nube · la espera a iCloud tiene salida")
struct MigrationImportWaitLogicTests {

    @Test("«Cancelar» se puede tocar aparcado y durante la pre-espera; con una pasada del runner en vuelo, no")
    func cancelEnabled_table() {
        #expect(MigrationImportWaitLogic.cancelEnabled(isWorking: false, waitingForImport: false, cancelling: false))
        #expect(MigrationImportWaitLogic.cancelEnabled(isWorking: true, waitingForImport: true, cancelling: false),
                "la pre-espera no ha tocado el runner: aquí estaba el botón apagado del QA")
        // Control: el comportamiento viejo era el correcto con una pasada en vuelo.
        #expect(!MigrationImportWaitLogic.cancelEnabled(isWorking: true, waitingForImport: false, cancelling: false))
        #expect(MigrationImportWaitLogic.cancelEnabled(isWorking: false, waitingForImport: true, cancelling: false))
        // Con una cancelación ya en marcha, un segundo toque cortaría su propia espera.
        #expect(!MigrationImportWaitLogic.cancelEnabled(isWorking: true, waitingForImport: true, cancelling: true))
    }

    @Test("El canario del tope dice qué tenía a iCloud sin asentarse")
    func stallDetail_namesTheCause() {
        #expect(MigrationImportWaitLogic.stallDetail(stillImporting: true, importsFinished: 0) == "importing|0")
        #expect(MigrationImportWaitLogic.stallDetail(stillImporting: false, importsFinished: 1) == "recentImport|1-10")
        #expect(MigrationImportWaitLogic.stallDetail(stillImporting: false, importsFinished: 10) == "recentImport|1-10")
        #expect(MigrationImportWaitLogic.stallDetail(stillImporting: false, importsFinished: 11) == "recentImport|11-50")
        #expect(MigrationImportWaitLogic.stallDetail(stillImporting: false, importsFinished: 51) == "recentImport|gt50")
    }
}

@Suite("Activar la nube · la espera a iCloud tiene salida (source-scan)")
struct MigrationImportWaitWiringTests {

    private static func body(of signature: String, in path: String) throws -> [String] {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        let text = try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
        let start = try #require(text.range(of: signature))
        var depth = 0
        var end = start.upperBound
        var opened = false
        for i in text[start.lowerBound...].indices {
            if text[i] == "{" { depth += 1; opened = true }
            if text[i] == "}" { depth -= 1; if opened && depth == 0 { end = text.index(after: i); break } }
        }
        return String(text[start.lowerBound..<end]).components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty && !$0.hasPrefix("//") }
    }

    private static let controller = "Yala/Services/CloudSync/CloudMigrationController.swift"

    @Test("cancelMigration pide el corte de la pre-espera antes de esperar a que se suelte el trabajo, y lo limpia después")
    func cancel_cutsThePreWait() throws {
        let body = try Self.body(of: "func cancelMigration() async {", in: Self.controller)
        #expect(Array(body.prefix(5)) == ["func cancelMigration() async {", "runner.requestMigrationCancel()",
                                          "guard !isCancellingMigration else { return }",
                                          "isCancellingMigration = true", "defer { isCancellingMigration = false }"],
                "un segundo toque no puede cortar la espera de la cancelación en marcha")
        let cut = try #require(body.firstIndex(of: "if isWorking && resumeWaitingForImport { preWaitCutRequested = true }"))
        let spin = try #require(body.firstIndex(of: "while isWorking {"))
        let reset = try #require(body.firstIndex(of: "preWaitCutRequested = false"))
        let ownWait = try #require(body.firstIndex(of: "guard await awaitImportQuiescenceForResume() else {"))
        #expect(body.firstIndex(of: "runner.requestMigrationCancel()").map { $0 < cut } == true, "el «sí» se apunta antes")
        #expect(cut < spin)
        #expect(spin < reset && reset < ownWait, "un corte pendiente no puede llevarse la espera de la propia cancelación")
    }

    @Test("La pre-espera mira el corte en cada sondeo")
    func preWait_honoursTheCut() throws {
        let body = try Self.body(of: "private func awaitImportQuiescenceForResume() async -> Bool {", in: Self.controller)
        let loop = try #require(body.firstIndex(of: "while waited < hardCap {"))
        #expect(body[loop + 1] == "if preWaitCutRequested {")
        #expect(body[loop + 2] == "preWaitCutRequested = false")
        // Desde `cloud-progress-shows-real-steps-and-counts` el corte deja también lo que duró la espera (canario
        // `cloudMigrationImportWaited`), y solo después sale.
        #expect(body[loop + 3] == "MetricsService.cloudMigrationImportWaited(stage: \"preWait\", outcome: \"cut\", seconds: waited)")
        #expect(body[loop + 4] == "return false")
    }

    @Test("El refresco de 1 s de Almacenamiento no espera al re-kick")
    func storageTick_doesNotAwaitTheRekick() throws {
        let path = "Yala/App/Views/Settings/StorageSettingsView.swift"
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        let text = try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
        // La cadencia la elige la fase desde `cloud-progress-shows-real-steps-and-counts` (5 s en las esperas locales de
        // iCloud, 30 s en el resto); lo que este test protege sigue igual: el re-kick va en un `Task`, sin `await`.
        #expect(text.contains(
            "if let controller, tick % controller.screenRekickSeconds == 0 { Task { await controller.rekickIfParked() } }"))
        #expect(!text.contains("await controller?.rekickIfParked() }"))
    }
}
