//
//  PanelTwoNeedsFilterUITests.swift
//  YalaUITests
//
//  Con dos necesidades filtradas, el Panel enseña las dos (card `tablero-con-dos-necesidades-filtradas-desde-regi-2y7e`,
//  lote P2). Hasta el 2026-11-04 el chip leía `selectedNeeds.first`: con «Esencial» y «Opcional» salía un solo chip, y
//  cuál no era estable.
//
//  Es también el conductor de las capturas de antes y después: con `YALA_CAPTURE_DIR` en el entorno del runner
//  (`TEST_RUNNER_YALA_CAPTURE_DIR=<carpeta>`) escribe ahí `panel-dos-necesidades.png`.
//

import XCTest

final class PanelTwoNeedsFilterUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func test_twoNeedsFiltered_panelShowsAChipForEach() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "realista")
        XCTAssertTrue(app.waitForUITestReady(timeout: 120), "uitest_ready ausente — la semilla no terminó.")

        let filters = app.buttons["panel_filters_button"]
        XCTAssertTrue(filters.waitForExistence(timeout: 20), "El Panel no montó.")
        filters.tap()

        // Las necesidades de la hoja de filtros, por su nombre (el idioma lo fija `launchForUITest`).
        for need in ["Esencial", "Opcional"] {
            let chip = app.buttons[need].firstMatch
            XCTAssertTrue(reveal(chip, in: app), "La hoja de filtros no ofrece «\(need)».")
            chip.tap()
        }
        app.buttons["filters_apply_button"].tap()
        XCTAssertTrue(filters.waitForExistence(timeout: 10), "La hoja de filtros no se cerró.")

        let needChips = app.buttons.matching(identifier: "applied_filter_chip")
            // La etiqueta es la del chip incluido: «Solo Esencial».
            .matching(NSPredicate(format: "label CONTAINS %@ OR label CONTAINS %@", "Esencial", "Opcional"))
        let deadline = Date().addingTimeInterval(10)
        while needChips.count < 2 && Date() < deadline {
            _ = app.buttons["__nunca__"].waitForExistence(timeout: 0.5)
        }
        capture(app)
        XCTAssertEqual(needChips.count, 2, "Con dos necesidades filtradas, el Panel enseña un chip por cada una.")
    }

    /// Arrastres cortos dentro de la hoja hasta que el elemento esté a la vista.
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        for _ in 0..<8 {
            if element.waitForExistence(timeout: 1), element.isHittable { return true }
            let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
            from.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)))
        }
        return element.exists && element.isHittable
    }

    private func capture(_ app: XCUIApplication) {
        let shot = app.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = "panel-dos-necesidades"
        attachment.lifetime = .keepAlways
        add(attachment)
        guard let dir = ProcessInfo.processInfo.environment["YALA_CAPTURE_DIR"] else { return }
        let url = URL(fileURLWithPath: dir).appendingPathComponent("panel-dos-necesidades.png")
        do {
            try shot.pngRepresentation.write(to: url)
        } catch {
            print("PanelTwoNeedsFilterUITests: Error: \(error)")
        }
    }
}
