//
//  BandejaChipGrupoCapturasUITests.swift
//  YalaUITests
//
//  Capturas del editor de la Bandeja con el chip de grupo y del texto de la barra en primary (encargo del 22-nov-2026).
//  No fija nada. Se corre a mano con `TEST_RUNNER_CAPTURA_DIR=<carpeta>`; opcionales `TEST_RUNNER_CAPTURA_TEMA=claro`,
//  `TEST_RUNNER_CAPTURA_TEXTO` (categoría de texto) y `TEST_RUNNER_CAPTURA_PREFIJO`. Sin la carpeta, se salta.
//

import XCTest

final class BandejaChipGrupoCapturasUITests: XCTestCase {

    private var folder: String?

    override func setUpWithError() throws {
        continueAfterFailure = true
        folder = ProcessInfo.processInfo.environment["CAPTURA_DIR"]
        try XCTSkipIf(folder == nil, "Solo a mano, con TEST_RUNNER_CAPTURA_DIR.")
    }

    func test_capturas() {
        let env = ProcessInfo.processInfo.environment
        var extra: [String] = ["-uitest-undo-notice-seconds", "30"]
        if let size = env["CAPTURA_TEXTO"] { extra += ["-UIPreferredContentSizeCategoryName", size] }
        if env["CAPTURA_TEMA"] == "claro" { extra += ["-userTheme", "1"] }
        let prefijo = env["CAPTURA_PREFIJO"] ?? "despues"

        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "grupos-invitado", extraArguments: extra)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente.")

        let inbox = app.buttons["panel_inbox_button"]
        XCTAssertTrue(inbox.waitForExistence(timeout: 15), "La app no llegó al Panel.")
        inbox.tap()

        let row = app.buttons["inbox_draft_row_Almuerzo equipo"]
        XCTAssertTrue(row.waitForExistence(timeout: 8), "No apareció el borrador.")

        // El editor: abajo solo «Dejar para después» y «Guardar»; el chip de grupo en la fila.
        row.tap()
        XCTAssertTrue(app.buttons["inbox_approve_button"].waitForExistence(timeout: 8), "No abrió el editor.")
        pause(1)
        shot(app, "\(prefijo)-editor")

        // El menú «…» con «Guardar y hacer recurrente».
        let more = app.buttons["draft_editor_more"]
        XCTAssertTrue(more.waitForExistence(timeout: 5))
        more.tap()
        XCTAssertTrue(app.buttons["inbox_approve_and_make_recurring_button"].waitForExistence(timeout: 5),
                      "El menú «…» no ofrece «Guardar y hacer recurrente».")
        pause(0.8)
        shot(app, "\(prefijo)-editor-menu-mas")
        app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)).tap()
        pause(0.8)

        // El chip: su menú de grupos y, elegido, el nombre del grupo.
        let chip = app.buttons["draft_editor_group_chip"]
        XCTAssertTrue(chip.waitForExistence(timeout: 5), "No está el chip de grupo.")
        chip.tap()
        let group = app.buttons["Viaje a Cusco"].firstMatch
        XCTAssertTrue(group.waitForExistence(timeout: 5), "El menú del chip no ofrece el grupo.")
        pause(0.8)
        shot(app, "\(prefijo)-editor-menu-grupo")
        group.tap()
        pause(1)
        shot(app, "\(prefijo)-editor-con-grupo")
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        guard let folder else { return }
        let url = URL(fileURLWithPath: folder).appendingPathComponent("\(name).png")
        do {
            try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
            try app.screenshot().pngRepresentation.write(to: url)
        } catch {
            XCTFail("No se pudo guardar \(name): \(error)")
        }
    }

    private func pause(_ seconds: TimeInterval) {
        _ = XCTWaiter().wait(for: [XCTestExpectation(description: "pausa")], timeout: seconds)
    }
}
