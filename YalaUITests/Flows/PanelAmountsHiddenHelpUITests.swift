//
//  PanelAmountsHiddenHelpUITests.swift
//  YalaUITests
//
//  Mejoras necesarias 2.3 · Panel (PN-7 de la revisión por vistas): con el ojo del Panel puesto, la ayuda «?» de la
//  gráfica de saldo decía el saldo exacto en «Con tus datos» («Hoy tienes S/ 64,690.04 en tus cuentas»). Desde el
//  arreglo esa línea lleva la misma máscara que el resto del Panel, y VoiceOver dice «Monto oculto».
//
//  Se mira la etiqueta de accesibilidad del bloque (`widget_info_your_data`): sin el ojo lleva cifras —el control: si
//  no, el caso pasaría igual con una ayuda que nunca dice el saldo— y con el ojo no lleva ni un dígito.
//
//  Seed `realista` (cuentas con saldo) y scheme Yala Dev.
//

import XCTest

final class PanelAmountsHiddenHelpUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private let hiddenLabel = "Monto oculto"

    func test_eyeOn_trendHelpYourData_saysNoAmount() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "realista")
        XCTAssertTrue(app.waitForUITestReady(timeout: 90), "uitest_ready ausente — bootstrap/seed no completó.")

        // Control: con los montos a la vista, la ayuda dice el saldo.
        let visibleLine = openTrendHelpYourData(app)
        XCTAssertTrue(containsDigit(visibleLine.label),
                      "Sin el ojo, «Con tus datos» no dice ninguna cifra: «\(visibleLine.label)». El caso no discrimina.")
        closeHelp(app)

        let eye = app.buttons["panel_hero_amounts_visibility"].firstMatch
        if !eye.isHittable { app.swipeDown() }
        XCTAssertTrue(eye.waitForExistence(timeout: 10), "No aparece el ojo del Panel.")
        eye.tap()
        XCTAssertTrue(waitForLabel(of: eye, equalTo: "Mostrar montos"), "El ojo no pasó a «Mostrar montos».")

        let hiddenLine = openTrendHelpYourData(app)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "ayuda-saldo-con-el-ojo"
        shot.lifetime = .keepAlways
        add(shot)

        XCTAssertFalse(containsDigit(hiddenLine.label),
                       "Con el ojo puesto, la ayuda de la gráfica dice una cifra: «\(hiddenLine.label)».")
        XCTAssertTrue(hiddenLine.label.contains(hiddenLabel),
                      "Con el ojo puesto, VoiceOver no dice «\(hiddenLabel)» en la ayuda: «\(hiddenLine.label)».")
    }

    // MARK: - Ayudas

    private func openTrendHelpYourData(_ app: XCUIApplication) -> XCUIElement {
        let info = app.buttons["widget_info_trend"].firstMatch
        XCTAssertTrue(info.waitForExistence(timeout: 15), "Falta el «?» de la gráfica de saldo (widget_info_trend).")
        info.tap()
        let line = app.descendants(matching: .any)["widget_info_your_data"].firstMatch
        XCTAssertTrue(line.waitForExistence(timeout: 10), "La ayuda de la gráfica no trae «Con tus datos».")
        return line
    }

    private func closeHelp(_ app: XCUIApplication) {
        let close = app.buttons["widget_info_close"].firstMatch
        XCTAssertTrue(close.waitForExistence(timeout: 5), "No aparece la X de la ayuda.")
        close.tap()
        XCTAssertTrue(close.waitForNonExistence(timeout: 10), "La ayuda no se cerró.")
    }

    private func containsDigit(_ text: String) -> Bool {
        text.rangeOfCharacter(from: .decimalDigits) != nil
    }

    private func waitForLabel(of element: XCUIElement, equalTo text: String) -> Bool {
        let predicate = NSPredicate(format: "label == %@", text)
        return XCTWaiter().wait(for: [expectation(for: predicate, evaluatedWith: element)], timeout: 5) == .completed
    }
}
