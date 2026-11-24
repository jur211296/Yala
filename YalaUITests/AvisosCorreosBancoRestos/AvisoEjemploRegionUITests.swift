//
//  AvisoEjemploRegionUITests.swift
//  YalaUITests
//
//  Restos de «Avisos del banco» (encargo del 24-nov-2026). El aviso de ejemplo de «Tu banco o app» decía
//  «S/ 25.00 en STARBUCKS LARCOMAR» también fuera de Perú. Ahora va en la moneda principal de Yala con un comercio
//  genérico, y en Perú sigue en soles. Con el arreglo fuera, el caso de Estados Unidos no encuentra «USD 25.00».
//  Cada caso deja una captura por tema (claro y oscuro) en el `.xcresult`.
//

import XCTest

final class AvisoEjemploRegionUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_fueraDePeru_elEjemploVaEnLaMonedaPrincipal() {
        for (tema, argumento) in [("claro", "1"), ("oscuro", "2")] {
            let app = XCUIApplication()
            app.launchForUITest(seed: "minimal", appleLocale: "es_US",
                                extraArguments: ["-defaultCurrencyCode", "USD", "-userTheme", argumento])
            XCTAssertTrue(app.waitForUITestReady(timeout: 90), "uitest_ready ausente — bootstrap/seed no completó.")
            let ejemplo = openOtherBankSample(app)
            capture(app, "ejemplo-eeuu-\(tema)")
            XCTAssertTrue(ejemplo.label.contains("USD 25.00"), "Fuera de Perú el ejemplo no va en dólares: \(ejemplo.label)")
            XCTAssertFalse(ejemplo.label.contains("S/"), "Fuera de Perú el ejemplo sigue en soles: \(ejemplo.label)")
            XCTAssertFalse(ejemplo.label.uppercased().contains("LARCOMAR"), "Sigue el comercio de Lima: \(ejemplo.label)")
            app.terminate()
        }
    }

    func test_enPeru_elEjemploSigueEnSoles() {
        for (tema, argumento) in [("claro", "1"), ("oscuro", "2")] {
            let app = XCUIApplication()
            app.launchForUITest(seed: "minimal", extraArguments: ["-defaultCurrencyCode", "PEN", "-userTheme", argumento])
            XCTAssertTrue(app.waitForUITestReady(timeout: 90), "uitest_ready ausente — bootstrap/seed no completó.")
            let ejemplo = openOtherBankSample(app)
            capture(app, "ejemplo-peru-\(tema)")
            XCTAssertTrue(ejemplo.label.contains("S/ 25.00"), "En Perú el ejemplo dejó de ir en soles: \(ejemplo.label)")
            app.terminate()
        }
    }

    // MARK: - Ayudantes

    /// Ajustes › Avisos del banco › «Tu banco o app» (u «Otro banco» en Perú), hasta el aviso de ejemplo.
    private func openOtherBankSample(_ app: XCUIApplication) -> XCUIElement {
        app.openProfile()
        XCTAssertTrue(app.buttons["profile_accounts"].waitForExistence(timeout: 10), "No se abrió Ajustes.")
        let row = app.buttons["profile_bank_notices"]
        scrollTo(row, in: app)
        row.tap()
        let other = app.buttons["bank_notices_bank_other"]
        XCTAssertTrue(app.staticTexts.firstMatch.waitForExistence(timeout: 10), "No se abrió «Avisos del banco».")
        scrollTo(other, in: app)   // en Perú va detrás de los seis bancos con reglas
        other.tap()
        let button = app.buttons["bank_notice_test_button"]
        scrollTo(button, in: app)
        let sample = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "con tu tarjeta ****3456")).firstMatch
        XCTAssertTrue(sample.waitForExistence(timeout: 5), "No se ve el aviso de ejemplo.")
        return sample
    }

    private func scrollTo(_ element: XCUIElement, in app: XCUIApplication) {
        var scrolls = 0
        while !(element.exists && element.isHittable) && scrolls < 12 {
            app.swipeUp()
            scrolls += 1
        }
        XCTAssertTrue(element.exists && element.isHittable, "No apareció \(element.identifier).")
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
