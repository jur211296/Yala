//
//  IPhoneLandscapeUITests.swift
//  YalaUITests
//
//  Yala gira con el iPhone (carril adaptativo, paso 11). Tres cosas fijan aquí:
//
//  - La app sigue al aparato: en horizontal la ventana es más ancha que alta, y se pasa de una página a otra.
//  - Girar con un registro abierto no lo cierra, ni al ir ni al volver.
//  - Girar con el formulario de nuevo registro a medias no pierde lo escrito.
//
//  En un iPhone grande girar cambia el ANCHO de la ventana (compacto ↔ regular), y es ahí donde lo abierto podría
//  perderse: la forma cambia y el estado tiene que vivir fuera de ella. Correr por UDID en `YalaLane-Adapt-iPhone-SE`
//  y `YalaLane-Adapt-iPhone-ProMax` (reglas del carril). En iPad también vale: el iPad ya giraba.
//

import XCTest

final class IPhoneLandscapeUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
        super.tearDown()
    }

    private func launch(deeplink: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "realista", deeplink: deeplink)
        XCTAssertTrue(app.waitForUITestReady(timeout: 90), "uitest_ready ausente — bootstrap/seed no completó.")
        return app
    }

    /// Gira el aparato y espera a que la ventana de la app tenga la forma pedida. Antes del paso 11 el iPhone se
    /// quedaba en vertical aunque el aparato girara: esta espera es la que cae en rojo.
    private func rotate(_ app: XCUIApplication, to orientation: UIDeviceOrientation) {
        XCUIDevice.shared.orientation = orientation
        let wantsLandscape = orientation.isLandscape
        let window = app.windows.firstMatch
        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline {
            let frame = window.frame
            if frame.width > 0, (frame.width > frame.height) == wantsLandscape { return }
            Thread.sleep(forTimeInterval: 0.25)
        }
        XCTFail("La ventana no giró a \(wantsLandscape ? "horizontal" : "vertical"): \(window.frame).")
    }

    /// Una página de la raíz, por su etiqueta: en la barra de pestañas si la hay, si no en la barra lateral.
    private func pageEntry(_ app: XCUIApplication, _ label: String) -> XCUIElement {
        let tab = app.tabBars.buttons[label]
        if tab.exists { return tab }
        return app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// En horizontal se navega entre las páginas de siempre; cada una monta su contenido. Solo las que están en la
    /// barra en los dos anchos: en compacto Registros y Grupos van dentro de «Más» (configuración por defecto).
    func test_appFollowsTheDeviceToLandscape_andNavigatesThePages() {
        let app = launch(deeplink: "panel")
        XCTAssertTrue(app.buttons["panel_action_new"].waitForExistence(timeout: 15), "El Panel no montó.")
        rotate(app, to: .landscapeLeft)

        let pages: [(label: String, content: String)] = [
            ("Estadísticas", "stats_tab_insights"),
            ("Planificación", "planning_chip_scheduledPayments"),
            ("Panel", "panel_action_new"),
        ]
        for page in pages {
            let entry = pageEntry(app, page.label)
            XCTAssertTrue(entry.waitForExistence(timeout: 10), "En horizontal no se ve la entrada «\(page.label)».")
            entry.tap()
            XCTAssertTrue(
                element(app, page.content).waitForExistence(timeout: 15),
                "En horizontal, «\(page.label)» no montó su contenido (\(page.content)).")
        }

        rotate(app, to: .portrait)
        XCTAssertTrue(app.buttons["panel_action_new"].waitForExistence(timeout: 10), "Al volver a vertical se perdió el Panel.")
    }

    /// Un registro abierto sigue abierto al girar a horizontal y al volver.
    func test_rotatingKeepsTheOpenRecordOpen() {
        let app = launch(deeplink: "records")
        let row = app.buttons.matching(identifier: "record_row").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 15), "No hay filas de registro.")
        row.tap()
        let edit = app.buttons["transaction_detail_edit"]
        XCTAssertTrue(edit.waitForExistence(timeout: 10), "No se abrió el detalle del registro.")

        rotate(app, to: .landscapeLeft)
        XCTAssertTrue(edit.waitForExistence(timeout: 10), "Al girar a horizontal se cerró el registro abierto.")

        rotate(app, to: .portrait)
        XCTAssertTrue(edit.waitForExistence(timeout: 10), "Al volver a vertical se cerró el registro abierto.")
    }

    /// Al revés: abierto en horizontal (en un iPhone grande, en la columna de al lado) y vuelto a vertical (la hoja).
    func test_recordOpenedInLandscape_staysOpenBackInPortrait() {
        let app = launch(deeplink: "records")
        let row = app.buttons.matching(identifier: "record_row").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 15), "No hay filas de registro.")
        rotate(app, to: .landscapeLeft)
        XCTAssertTrue(row.waitForExistence(timeout: 10), "En horizontal no se ven las filas de registro.")
        row.tap()
        let edit = app.buttons["transaction_detail_edit"]
        XCTAssertTrue(edit.waitForExistence(timeout: 10), "En horizontal no se abrió el detalle del registro.")

        rotate(app, to: .portrait)
        XCTAssertTrue(edit.waitForExistence(timeout: 10), "Al volver a vertical se cerró el registro abierto en horizontal.")
    }

    /// El formulario de nuevo registro a medias conserva lo escrito al girar y al volver.
    func test_rotatingKeepsAHalfWrittenNewRecord() {
        let app = launch(deeplink: "panel")
        let new = app.buttons["panel_action_new"]
        XCTAssertTrue(new.waitForExistence(timeout: 15), "El Panel no enseña «Nuevo registro».")
        new.tap()
        let amount = app.textFields["new_transaction_amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 10), "No se abrió el formulario de nuevo registro.")
        amount.tap()
        amount.typeText("123")

        func amountKeepsWhatWasTyped() -> Bool {
            amount.waitForExistence(timeout: 10) && ((amount.value as? String) ?? "").contains("123")
        }

        rotate(app, to: .landscapeLeft)
        XCTAssertTrue(amountKeepsWhatWasTyped(), "Al girar a horizontal el formulario perdió el importe: \(String(describing: amount.value)).")

        rotate(app, to: .portrait)
        XCTAssertTrue(amountKeepsWhatWasTyped(), "Al volver a vertical el formulario perdió el importe: \(String(describing: amount.value)).")
    }
}
