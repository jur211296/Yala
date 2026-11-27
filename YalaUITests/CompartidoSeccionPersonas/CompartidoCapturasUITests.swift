//
//  CompartidoCapturasUITests.swift
//  YalaUITests
//
//  Capturas de la pestaña «Compartido» (lote 1 de Compartido, 26-nov-2026): la lista de Grupos arriba y al bajar, y con
//  los chips, la lista de Personas con sus liquidadas abiertas, en claro y en oscuro. Se escribió ANTES de tocar las
//  vistas y se corrió sobre la base para el «antes»: sin chips, solo salen las de Grupos. No afirma nada del diseño;
//  las aserciones del lote viven en `CompartidoSeccionPersonasUITests`.
//

import XCTest

final class CompartidoCapturasUITests: XCTestCase {

    /// Oscuro es el tema por defecto; claro va con `-userTheme 1`.
    private let variants: [(name: String, args: [String])] = [("oscuro", []), ("claro", ["-userTheme", "1"])]

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        Thread.sleep(forTimeInterval: 1.0)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// Sobre la app y no sobre `scrollViews.firstMatch`: con los chips, el primer scroll es su fila horizontal.
    private func scrollDown(_ app: XCUIApplication) {
        app.swipeUp(velocity: .slow)
    }

    func test_capturas() {
        for variant in variants {
            let app = XCUIApplication()
            app.launchForUITest(
                pro: true, seed: "grupos", deeplink: "groups",
                extraArguments: ["-uitest-seed-group-cross-debts"] + variant.args)
            XCTAssertTrue(app.waitForUITestReady())

            let card = app.descendants(matching: .any).matching(identifier: "group_card").firstMatch
            XCTAssertTrue(card.waitForExistence(timeout: 15))
            attach(app, "grupos-\(variant.name)")
            scrollDown(app)
            attach(app, "grupos-abajo-\(variant.name)")

            let personas = app.buttons["compartido_chip_personas"]
            if personas.waitForExistence(timeout: 3) {
                app.swipeDown(velocity: .fast)
                personas.tap()
                let personCard = app.descendants(matching: .any)
                    .matching(identifier: "compartido_person_card").firstMatch
                XCTAssertTrue(personCard.waitForExistence(timeout: 10))
                attach(app, "personas-\(variant.name)")
                scrollDown(app)
                attach(app, "personas-abajo-\(variant.name)")
            }
            app.terminate()
        }
    }

    /// Con todo saldado (`grupos-saldado`): nadie con pendientes y las liquidadas plegadas al pie, y abiertas.
    func test_capturasLiquidadas() {
        for variant in variants {
            let app = XCUIApplication()
            app.launchForUITest(pro: true, seed: "grupos-saldado", deeplink: "groups", extraArguments: variant.args)
            XCTAssertTrue(app.waitForUITestReady())
            let personas = app.buttons["compartido_chip_personas"]
            guard personas.waitForExistence(timeout: 15) else { app.terminate(); continue }
            personas.tap()
            let toggle = app.buttons["compartido_settled_toggle"]
            XCTAssertTrue(toggle.waitForExistence(timeout: 10))
            scrollDown(app)
            attach(app, "liquidadas-plegadas-\(variant.name)")
            toggle.tap()
            let settled = app.descendants(matching: .any).matching(identifier: "compartido_settled_card").firstMatch
            XCTAssertTrue(settled.waitForExistence(timeout: 5))
            scrollDown(app)
            attach(app, "liquidadas-abiertas-\(variant.name)")
            app.terminate()
        }
    }
}
