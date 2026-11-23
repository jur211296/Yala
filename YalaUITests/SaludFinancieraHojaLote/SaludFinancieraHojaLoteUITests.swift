//
//  SaludFinancieraHojaLoteUITests.swift
//  YalaUITests
//
//  Lote de la hoja «Tu salud financiera» (23-nov-2026). Con la muestra «excedido» (`-uitest-salud-estado`), cuyo
//  resumen de Yala IA trae negritas en markdown como las escribe el modelo: la hoja las pinta sin asteriscos, y las
//  cápsulas de arriba siguen siendo botones que bajan a su sección.
//

import XCTest

final class SaludFinancieraHojaLoteUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    private func abrirHoja(_ app: XCUIApplication) {
        app.launchForUITest(pro: true, seed: "minimal", extraArguments: ["-uitest-salud-estado", "excedido"])
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente.")
        let card = app.buttons["panel_health_compact"]
        XCTAssertTrue(card.waitForExistence(timeout: 30), "La nota de salud no sale en el Panel.")
        card.tap()
        XCTAssertTrue(app.descendants(matching: .any)["health_breakdown"].waitForExistence(timeout: 10))
    }

    func test_resumenIA_sinAsteriscos() {
        let app = XCUIApplication()
        abrirHoja(app)
        let ia = app.descendants(matching: .any)["health_improve_ai"].firstMatch
        let scroll = app.scrollViews.element(boundBy: app.scrollViews.count - 1)
        var intentos = 0
        while !ia.exists && intentos < 6 {
            scroll.swipeUp(velocity: .slow)
            intentos += 1
        }
        XCTAssertTrue(ia.waitForExistence(timeout: 5), "La fila de Yala IA no sale con la muestra «excedido».")
        XCTAssertTrue(ia.label.contains("38 %"), "La fila no trae el resumen: \(ia.label)")
        XCTAssertFalse(ia.label.contains("*"), "El resumen enseña los asteriscos del markdown: \(ia.label)")
    }

    func test_capsulas_sonBotonesQueBajanASuSeccion() {
        let app = XCUIApplication()
        abrirHoja(app)
        let capsula = app.buttons["health_capsule_ritmo"]
        XCTAssertTrue(capsula.waitForExistence(timeout: 10), "La cápsula de Ritmo no es un botón.")
        capsula.tap()
        let seccion = app.descendants(matching: .any)["health_section_ritmo"].firstMatch
        XCTAssertTrue(seccion.waitForExistence(timeout: 5))
        XCTAssertTrue(seccion.isHittable, "Tocar la cápsula no bajó a su sección.")
    }
}
