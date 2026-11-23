//
//  ImportarLote1UITests.swift
//  YalaUITests
//
//  Importar registros, lote 1 (22-nov-2026), de punta a punta en la app: importar, volver a importar el mismo archivo
//  (la vista previa dice que ya estaban y no los cuenta) y «Deshacer importación» desde el aviso del resultado. El
//  selector de Archivos es del sistema: el archivo llega por `-uitest-import-records-file` (`ImportarLote1UITestSeams`).
//

import XCTest

final class ImportarLote1UITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    private static let csv = """
    date,amount,currency,account,category,subcategory,tags,note
    2026-10-03,-10.00,PEN,Cuenta importada,Café de prueba,Café,,Café
    2026-10-03,-10.00,PEN,Cuenta importada,Café de prueba,Café,,Café
    2026-10-04,-25.50,PEN,Cuenta importada,Café de prueba,Postre,,
    """

    private func writeCSV() throws -> String {
        let dir = URL(fileURLWithPath: "/tmp").appendingPathComponent("yala-uitest-importar-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("extracto.csv")
        try Self.csv.write(to: url, atomically: true, encoding: .utf8)
        return url.path
    }

    /// Capturas para la evidencia del encargo, si se pide (`TEST_RUNNER_YALA_EVIDENCIA_DIR`).
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        guard let dir = ProcessInfo.processInfo.environment["YALA_EVIDENCIA_DIR"] else { return }
        let url = URL(fileURLWithPath: dir).appendingPathComponent("\(name).png")
        do {
            try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            try app.screenshot().pngRepresentation.write(to: url)
        } catch {
            XCTFail("No se pudo guardar la captura \(name): \(error)")
        }
    }

    private func scrollTo(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        let element = app.buttons[identifier]
        var tries = 0
        while !(element.exists && element.isHittable) && tries < 14 {
            app.swipeUp()
            tries += 1
        }
        return element
    }

    private func openImport(_ app: XCUIApplication) {
        if !app.buttons["profile_import"].exists { app.openProfile(timeout: 30) }
        let row = scrollTo(app, "profile_import")
        XCTAssertTrue(row.waitForExistence(timeout: 10), "No apareció la fila de Importar en Ajustes.")
        row.tap()
        XCTAssertTrue(app.buttons["import_select_file"].waitForExistence(timeout: 10), "No se abrió Importar.")
    }

    /// Un interruptor se toca en su lado derecho: con título, la fila entera es el interruptor.
    private func flip(_ toggle: XCUIElement) {
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
    }

    private func pickFile(_ app: XCUIApplication, createCategories: Bool) {
        if createCategories {
            let toggle = app.switches["import_create_categories_toggle"]
            XCTAssertTrue(toggle.waitForExistence(timeout: 5))
            if (toggle.value as? String) != "1" { flip(toggle) }
        }
        app.buttons["import_select_file"].tap()
    }

    func test_import_reimportSaysTheyWereAlreadyThere_andUndoRemovesThem() throws {
        let path = try writeCSV()
        let app = XCUIApplication()
        app.launchForUITest(pro: true, extraArguments: ["-uitest-import-records-file", path])
        app.waitForUITestReady()

        // 1. Importar: tres registros, dos cafés iguales incluidos.
        openImport(app)
        pickFile(app, createCategories: true)
        let confirm = app.buttons["import_preview_confirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 20), "No salió la vista previa.")
        XCTAssertFalse(app.descendants(matching: .any)["import_preview_duplicates"].exists,
                       "Un archivo nuevo no tiene duplicados: dos cafés iguales entran los dos.")
        confirm.tap()

        // El aviso del resultado ofrece deshacer.
        let undoFromAlert = app.alerts.buttons["Deshacer importación"]
        XCTAssertTrue(undoFromAlert.waitForExistence(timeout: 20), "El aviso del resultado no ofrece deshacer.")
        capture(app, "despues-1-aviso-con-deshacer")
        app.alerts.buttons["OK"].firstMatch.tap()

        // 2. Volver a importar el mismo archivo: los tres ya estaban.
        openImport(app)
        XCTAssertTrue(app.buttons["import_undo_last"].waitForExistence(timeout: 5),
                      "Importar no ofrece deshacer el último import.")
        pickFile(app, createCategories: false)
        let duplicates = app.descendants(matching: .any)["import_preview_duplicates"]
        XCTAssertTrue(duplicates.waitForExistence(timeout: 20), "La vista previa no dice que ya estaban.")
        XCTAssertTrue(app.descendants(matching: .any)["import_preview_nothing"].exists,
                      "Con todo duplicado no queda nada que importar por defecto.")
        capture(app, "despues-2-reimportar-duplicados")
        // «Importarlos igual» los vuelve a contar.
        flip(app.switches["import_preview_duplicates_toggle"])
        XCTAssertTrue(app.buttons["import_preview_confirm"].waitForExistence(timeout: 5))
        app.buttons["import_preview_cancel"].tap()

        // 3. Deshacer desde Importar: pregunta, borra y lo dice.
        let undo = app.buttons["import_undo_last"]
        XCTAssertTrue(undo.waitForExistence(timeout: 10))
        capture(app, "despues-3-importar-con-deshacer")
        undo.tap()
        let confirmUndo = app.alerts.buttons["Deshacer"]
        XCTAssertTrue(confirmUndo.waitForExistence(timeout: 5), "No preguntó antes de deshacer.")
        confirmUndo.tap()
        XCTAssertTrue(app.alerts["Importación deshecha"].waitForExistence(timeout: 30), "No dijo que se deshizo.")
        capture(app, "despues-4-deshecho")
        app.alerts.buttons["OK"].firstMatch.tap()

        // Ya no se ofrece.
        openImport(app)
        XCTAssertFalse(app.buttons["import_undo_last"].waitForExistence(timeout: 2))
    }
}
