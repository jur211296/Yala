//
//  ExportFreePeriodsUITests.swift
//  YalaUITests
//
//  Desde el 2026-10-12 exportar es gratis entero: cualquier período, en CSV o Excel (decisión de Lola con la
//  delegación de Jürgen, PR #469). La política de privacidad promete la exportación completa sin pagar, así que esto es
//  lo que la sostiene en la app.
//
//  Desde el 2026-10-19 (lote decidido 2.2 · 03, L20-1/L20-2/L20-4) la exportación es UNA pantalla, «Llévate tus
//  registros»: período en fichas con «Todo» elegido, Excel recomendado, «Más opciones» plegado y la cifra encima del
//  botón. Este fichero fija esa pantalla para un usuario gratis (`launchForUITest` sin `pro`), seed `minimal` (trae
//  registros: sin ellos la fila de exportar sale desactivada).
//

import XCTest

final class ExportFreePeriodsUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_freeUser_exportsAnyPeriod_withoutTheProOffer() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        openExport(app)

        let all = app.buttons["export_period_all"]
        XCTAssertTrue(all.waitForExistence(timeout: 10), "No se abrió la pantalla de exportar.")
        XCTAssertTrue(all.isSelected, "La pantalla no arrancó con «Todo» elegido (L20-1).")
        XCTAssertTrue(app.buttons["export_format_xlsx"].isSelected, "Excel no sale elegido por defecto.")

        // La cifra encima del botón: «Saldrán N registros · del … a hoy».
        let countLine = element(app, "export_count_line")
        XCTAssertTrue(countLine.waitForExistence(timeout: 10), "Falta la línea de lo que saldrá.")
        XCTAssertTrue(waitForLabel(countLine, containing: "Saldrán"), "La línea no dice cuántos registros salen.")

        // Las fichas de período: cada una se elige sin la oferta de Pro.
        for id in ["thisYear", "thisMonth", "all"] {
            let chip = app.buttons["export_period_\(id)"]
            chip.tap()
            XCTAssertTrue(chip.isSelected, "La ficha \(id) no quedó elegida.")
            XCTAssertFalse(app.buttons["upgrade_prompt_cta"].exists, "Elegir \(id) abrió la oferta de Pro.")
        }

        // «Fechas…» abre su selector de fechas, no la oferta de Pro.
        app.buttons["export_period_dates"].tap()
        XCTAssertTrue(app.datePickers.firstMatch.waitForExistence(timeout: 5), "«Fechas…» no abrió el selector.")
        XCTAssertFalse(app.buttons["upgrade_prompt_cta"].exists, "«Fechas…» abrió la oferta de Pro.")
    }

    /// L20-2: un filtro olvidado se ve plegado, y con cero registros el botón se apaga ANTES de exportar.
    func test_aNoteThatMatchesNothing_isShown_andTheButtonTurnsOff() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        openExport(app)

        let button = app.buttons["export_button"]
        XCTAssertTrue(button.waitForExistence(timeout: 10), "Falta el botón de exportar.")
        XCTAssertTrue(waitForEnabled(button, true), "Con todo elegido el botón tiene que poder tocarse.")

        let more = app.buttons["export_more_options"]
        XCTAssertTrue(more.waitForExistence(timeout: 5), "Falta «Más opciones».")
        more.tap()

        let note = app.textFields["export_note_field"]
        var swipes = 0
        while !note.isHittable && swipes < 10 {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(note.isHittable, "No se llega al campo de la nota.")
        note.tap()
        note.typeText("zzz-no-existe")

        XCTAssertTrue(waitForLabel(element(app, "export_count_line"), containing: "Ninguno con estos filtros"),
                      "Con una nota que no casa, no dice «Ninguno con estos filtros».")
        XCTAssertTrue(waitForEnabled(button, false), "Con cero registros el botón sigue encendido.")

        let summary = element(app, "export_more_options_summary")
        XCTAssertTrue(waitForLabel(summary, containing: "zzz-no-existe"), "El resumen de «Más opciones» no enseña la nota.")
    }

    // MARK: - Ayudas

    /// La fila de Exportar no lleva identificador, y ponérselo tocaría `ProfileView`, que arrastra al gate 40 suites de
    /// interfaz. Se busca por su título: los XCUITest corren siempre en español (`launchForUITest` fija
    /// `-AppleLanguages (es)`). Desde L20-4 se llama «Exportar registros».
    private func openExport(_ app: XCUIApplication) {
        app.openProfile()
        let exportRow = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Exportar registros")).firstMatch
        XCTAssertTrue(exportRow.waitForExistence(timeout: 10), "No apareció la fila Exportar registros en el Perfil.")
        var swipes = 0
        while !exportRow.isHittable && swipes < 14 {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(exportRow.isHittable, "La fila Exportar registros no se puede tocar.")
        XCTAssertTrue(exportRow.isEnabled, "La fila Exportar registros está desactivada: ¿el seed no trajo registros?")
        exportRow.tap()
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func waitForLabel(_ element: XCUIElement, containing text: String, timeout: TimeInterval = 10) -> Bool {
        let predicate = NSPredicate(format: "label CONTAINS %@", text)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    private func waitForEnabled(_ element: XCUIElement, _ enabled: Bool, timeout: TimeInterval = 10) -> Bool {
        let predicate = NSPredicate(format: "isEnabled == %@", NSNumber(value: enabled))
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}
