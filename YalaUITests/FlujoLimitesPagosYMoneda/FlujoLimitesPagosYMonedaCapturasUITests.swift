//
//  FlujoLimitesPagosYMonedaCapturasUITests.swift
//  YalaUITests
//
//  Capturas de los límites con pagos y monedas (encargo del 2026-11-20): una línea en «Monto fijo» de 500 USD (la hoja,
//  el detalle con su cápsula, «Cómo se convierte» y la fila del mes con la nota del resumen) y otra con dos pagos y un
//  extra («Elige los pagos» y «Pagos de esta línea»). No fija nada. Se corre a mano con `TEST_RUNNER_CAPTURA_DIR=<carpeta>`;
//  opcionales `TEST_RUNNER_CAPTURA_TEXTO` (categoría de texto), `TEST_RUNNER_CAPTURA_TEMA=claro` y
//  `TEST_RUNNER_CAPTURA_PREFIJO`. Sin la carpeta, se salta.
//

import XCTest

final class FlujoLimitesPagosYMonedaCapturasUITests: XCTestCase {

    private var folder: String?

    override func setUpWithError() throws {
        continueAfterFailure = true
        folder = ProcessInfo.processInfo.environment["CAPTURA_DIR"]
        try XCTSkipIf(folder == nil, "Solo a mano, con TEST_RUNNER_CAPTURA_DIR.")
    }

    func test_capturas() {
        let env = ProcessInfo.processInfo.environment
        var extra: [String] = ["-tabBarConfiguration", #""{\"activeTabs\":[\"panel\",\"statistics\",\"reports\"]}""#]
        if let size = env["CAPTURA_TEXTO"] { extra += ["-UIPreferredContentSizeCategoryName", size] }
        if env["CAPTURA_TEMA"] == "claro" { extra += ["-userTheme", "1"] }
        let p = env["CAPTURA_PREFIJO"] ?? "despues"

        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "realista", extraArguments: extra)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente.")
        app.selectTab(.reports)
        let chip = app.buttons["report_chip_flujoDeCaja"]
        XCTAssertTrue(chip.waitForExistence(timeout: 10))
        // Con texto grande el chip queda fuera, a la derecha: se arrastra la fila de chips.
        if chip.frame.maxX > app.frame.width {
            let fila = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: app.frame.width * 0.8,
                                                                                          dy: chip.frame.midY))
            fila.press(forDuration: 0.05, thenDragTo: fila.withOffset(CGVector(dx: -app.frame.width * 0.6, dy: 0)))
        }
        chip.tap()
        skipCoachMark(app)
        let create = app.buttons["primary_button"]
        XCTAssertTrue(create.waitForExistence(timeout: 10))
        create.tap()
        XCTAssertTrue(app.staticTexts["cashflow_month_title"].waitForExistence(timeout: 15))
        skipCoachMark(app)

        // 1 · Monto fijo de 500 USD en la primera línea de gasto.
        openCalculo(app, index: 2)
        app.buttons["cashflow_method_manual"].tap()
        app.buttons["cashflow_method_currency"].tap()
        let usd = app.buttons["currency_selector_row_USD"].firstMatch
        if usd.waitForExistence(timeout: 5) { usd.tap() }
        _ = usd.waitForNonExistence(timeout: 5)
        let campo = app.textFields["cashflow_method_manual_amount"]
        campo.tap()
        let actual = (campo.value as? String) ?? ""
        campo.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: actual.count + 2))
        campo.typeText("500")
        pause(0.8)
        shot(app, "\(p)-1-fijo-usd")
        // «Guardar» va en la barra, encima del teclado: se toca con el teclado puesto y se afirma que guardó.
        app.buttons["cashflow_method_save"].tap()
        let capsula = app.buttons["cashflow_detail_conversion_capsule"]
        XCTAssertTrue(capsula.waitForExistence(timeout: 8), "No se guardó el monto en USD.")
        pause(0.8)
        shot(app, "\(p)-2-detalle-capsula")
        capsula.tap()
        _ = app.descendants(matching: .any)["cashflow_how_converted_sheet"].waitForExistence(timeout: 5)
        pause(0.8)
        shot(app, "\(p)-3-como-se-convierte")
        app.navigationBars.buttons.firstMatch.tap()
        pause(0.8)
        app.buttons["cashflow_cell_detail_close"].tap()
        pause(1)
        shot(app, "\(p)-4-mes-fila")

        // 2 · Dos pagos y un extra en la segunda línea de gasto.
        openCalculo(app, index: 3)
        app.buttons["cashflow_method_scheduled"].tap()
        _ = app.descendants(matching: .any)["cashflow_pick_payments_sheet"].waitForExistence(timeout: 5)
        for nombre in ["Netflix", "Spotify"] {
            let fila = app.buttons.matching(identifier: "cashflow_pick_payment_row")
                .matching(NSPredicate(format: "label BEGINSWITH %@", nombre)).firstMatch
            if fila.waitForExistence(timeout: 3) { fila.tap() }
        }
        pause(0.6)
        shot(app, "\(p)-5-elige-los-pagos")
        app.buttons["cashflow_pick_payments_done"].tap()
        pause(0.8)
        let interruptor = app.switches["cashflow_line_extra_toggle"].firstMatch
        var tries = 0
        while !interruptor.isHittable, tries < 6 { app.swipeUp(velocity: .slow); tries += 1 }
        interruptor.switches.firstMatch.tap()
        let extraCampo = app.textFields["cashflow_line_extra_amount"]
        if extraCampo.waitForExistence(timeout: 5) {
            extraCampo.tap()
            extraCampo.typeText("30")
        }
        // Sin arrastrar: en una hoja, el arrastre es el gesto de cerrarla. La captura sale con el teclado.
        pause(0.8)
        shot(app, "\(p)-6-pagos-de-la-linea")
        XCTAssertTrue(app.descendants(matching: .any)["cashflow_method_sheet"].exists, "La hoja se cerró antes de guardar.")
        app.buttons["cashflow_method_save"].tap()
        // El detalle está debajo y sigue en el árbol: lo que prueba el guardado es que la hoja se fue.
        XCTAssertTrue(app.descendants(matching: .any)["cashflow_method_sheet"].waitForNonExistence(timeout: 8),
                      "No se guardaron los pagos.")
        pause(1)
        shot(app, "\(p)-7-detalle-pagos")
        app.buttons["cashflow_cell_detail_close"].tap()
        pause(0.8)
        // La nota del resumen va bajo las líneas: se baja hasta ella.
        let nota = app.descendants(matching: .any)["cashflow_month_converted_note"]
        tries = 0
        while !nota.isHittable, tries < 12 { app.swipeUp(velocity: .slow); tries += 1 }
        pause(0.6)
        shot(app, "\(p)-8-mes-nota")
    }

    private func openCalculo(_ app: XCUIApplication, index: Int) {
        app.swipeDown()
        app.swipeDown()
        let row = app.buttons.matching(identifier: "cashflow_detail_line").element(boundBy: index)
        XCTAssertTrue(row.waitForExistence(timeout: 10), "No hay fila \(index) en el mes.")
        var tries = 0
        while row.frame.maxY > app.frame.height * 0.8, tries < 8 {
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -120)))
            tries += 1
        }
        _ = app.waitForSettledLayout(of: row)
        row.tap()
        let detail = app.scrollViews["cashflow_cell_detail"]
        if !detail.waitForExistence(timeout: 4) { row.tap() }
        XCTAssertTrue(detail.waitForExistence(timeout: 5), "No se abrió el detalle de la línea \(index).")
        let adjust = app.buttons["cashflow_adjust_amount"]
        tries = 0
        while !adjust.isHittable, tries < 6 { detail.swipeUp(); tries += 1 }
        adjust.tap()
        _ = app.descendants(matching: .any)["cashflow_method_sheet"].waitForExistence(timeout: 5)
    }

    private func skipCoachMark(_ app: XCUIApplication) {
        let skip = app.buttons["coach_mark_skip"]
        if skip.waitForExistence(timeout: 4) {
            skip.tap()
            _ = skip.waitForNonExistence(timeout: 5)
        }
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
