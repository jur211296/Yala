//
//  PanelHealthCompactUITests.swift
//  YalaUITests
//
//  Lote 1 de la nota de salud (11-nov-2026): la tarjeta chata llega encendida en «Tus finanzas» del Panel, también
//  plegada, con un mensaje breve que dice qué hacer y la línea de lo que la nota no ve; tocarla abre el desglose.
//  Semilla `cuenta-con-movimientos`: solo Ritmo tiene datos, así que no hay nota y el paso es crear un presupuesto.
//

import XCTest

final class PanelHealthCompactUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_compactCard_isOnByDefault_saysTheNextStep_andOpensTheBreakdown() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "cuenta-con-movimientos")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        let card = app.buttons["panel_health_compact"]
        XCTAssertTrue(card.waitForExistence(timeout: 10), "La nota de salud no sale en «Tus finanzas» por defecto.")

        // Un botón expone su contenido unido: el mensaje y la línea de lo que no ve van en su etiqueta.
        XCTAssertTrue(card.label.contains("Crea un presupuesto para ver tu nota."), "Sin el paso breve: «\(card.label)».")
        XCTAssertTrue(card.label.contains("Efectivo QA"), "No nombra la cuenta en rojo: «\(card.label)».")

        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "panel-salud-chata"
        shot.lifetime = .keepAlways
        add(shot)

        card.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["health_breakdown"].waitForExistence(timeout: 5),
            "Tocar la tarjeta no abre el desglose."
        )
        let sheetShot = XCTAttachment(screenshot: app.screenshot())
        sheetShot.name = "panel-salud-hoja"
        sheetShot.lifetime = .keepAlways
        add(sheetShot)
    }

    /// Con datos de sobra (semilla `realista`) la tarjeta enseña la nota y un mensaje breve, sin «vas mal».
    func test_compactCard_withData_showsTheScore() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "realista")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        let card = app.buttons["panel_health_compact"]
        XCTAssertTrue(card.waitForExistence(timeout: 20), "La nota de salud no sale en «Tus finanzas» por defecto.")
        XCTAssertTrue(card.label.contains("de 100"), "Con datos, la tarjeta no da la nota: «\(card.label)».")
        XCTAssertFalse(card.label.lowercased().contains("vas mal"))

        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "panel-salud-chata-con-nota"
        shot.lifetime = .keepAlways
        add(shot)
    }
}
