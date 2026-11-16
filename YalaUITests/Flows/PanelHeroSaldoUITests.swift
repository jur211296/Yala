//
//  PanelHeroSaldoUITests.swift
//  YalaUITests
//
//  Encargo del 2026-11-16 («el saldo en grande, tu dinero en chico»): el hero del Panel enseña «Tu saldo hoy» y, debajo,
//  «Tu dinero hoy» (sin la tarjeta de crédito). El «?» abre la hoja que explica los dos y lleva a elegir qué cuentas
//  suman; encender la tarjeta iguala las dos cifras y la línea chica se va.
//
//  Seed `tarjeta-dos-lineas`: una tarjeta en soles con su línea en dólares, ahorros en soles y una cuenta en dólares.
//  Sin tarjeta las dos cifras serían la misma y el caso no podría distinguir nada.
//

import XCTest

final class PanelHeroSaldoUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_moneyLine_infoSheet_andTurningTheCardOnHidesTheLine() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "tarjeta-dos-lineas")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        let figure = app.descendants(matching: .any)["panel_hero_figure"].firstMatch
        let moneyLine = app.descendants(matching: .any)["panel_hero_money_line"].firstMatch
        XCTAssertTrue(figure.waitForExistence(timeout: 10), "No aparece «Tu saldo hoy».")
        XCTAssertTrue(moneyLine.waitForExistence(timeout: 10), "Con una tarjeta en el saldo falta «Tu dinero hoy».")
        XCTAssertTrue(moneyLine.label.contains("Tu dinero hoy"), "La línea chica dice «\(moneyLine.label)».")
        // La línea del mes y sus píldoras salieron del hero.
        XCTAssertFalse(app.buttons["panel_hero_expense_pill"].exists, "Las píldoras de ingresos y gastos volvieron al hero.")

        // El «?» abre la hoja con las dos cifras y el ejemplo.
        let info = app.buttons["panel_hero_saldo_info"]
        XCTAssertTrue(info.waitForHittable(timeout: 5), "No aparece el «?» junto a «Tu saldo hoy».")
        info.tap()
        XCTAssertTrue(app.descendants(matching: .any)["panel_saldo_info_example"].firstMatch.waitForExistence(timeout: 5),
                      "La hoja del «?» no enseña el ejemplo.")
        attach(app, "1-hoja-del-saldo")

        // Elegir qué cuentas suman: la tarjeta viene apagada; su línea en dólares no tiene interruptor propio.
        app.buttons["panel_saldo_info_choose_accounts"].tap()
        let card = app.switches["panel_saldo_account_toggle_Visa QA"]
        XCTAssertTrue(card.waitForExistence(timeout: 5), "La lista no enseña la tarjeta.")
        XCTAssertEqual(card.value as? String, "0", "La tarjeta de crédito debía venir apagada.")
        XCTAssertEqual(app.switches["panel_saldo_account_toggle_Ahorros QA"].value as? String, "1")
        XCTAssertFalse(app.switches["panel_saldo_account_toggle_Visa QA · USD"].exists, "La línea de la tarjeta tiene interruptor propio.")
        card.switches.firstMatch.tap()
        XCTAssertTrue(waitForValue(of: card, "1"), "La tarjeta no se encendió.")
        attach(app, "2-lista-de-cuentas")

        // Con todo encendido las dos cifras coinciden: la línea chica se va.
        app.buttons["BackButton"].firstMatch.tap()
        app.buttons["panel_saldo_info_close"].tap()
        XCTAssertTrue(moneyLine.waitForNonExistence(timeout: 5), "Con la tarjeta encendida «Tu dinero hoy» repite la cifra grande.")

        // Y vuelve al apagarla otra vez.
        info.tap()
        app.buttons["panel_saldo_info_choose_accounts"].tap()
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        XCTAssertEqual(card.value as? String, "1", "La tarjeta encendida no se guardó.")
        card.switches.firstMatch.tap()
        XCTAssertTrue(waitForValue(of: card, "0"))
        app.buttons["BackButton"].firstMatch.tap()
        app.buttons["panel_saldo_info_close"].tap()
        XCTAssertTrue(moneyLine.waitForExistence(timeout: 5), "Al apagar la tarjeta no volvió «Tu dinero hoy».")
    }

    // MARK: - Ayudas

    private func waitForValue(of element: XCUIElement, _ value: String) -> Bool {
        let predicate = NSPredicate(format: "value == %@", value)
        return XCTWaiter().wait(for: [expectation(for: predicate, evaluatedWith: element)], timeout: 5) == .completed
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
