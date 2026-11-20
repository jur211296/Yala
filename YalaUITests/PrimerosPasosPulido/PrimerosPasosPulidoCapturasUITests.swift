//
//  PrimerosPasosPulidoCapturasUITests.swift
//  YalaUITests
//
//  El pulido de Primeros pasos (encargo del 2026-11-20), de punta a punta, con una captura por punto del encargo. Se
//  escribió ANTES de tocar la app y se corrió sobre la base para el «antes» (sin las aserciones de lo nuevo); con el
//  pulido, además fija lo que se ve: las intros como historias (tocar por mitades y mantener para pausar), el nombre
//  precargado, volver sin perder lo escrito, «No deseo crear…», «Entendido» en la guía y el paso 6 abriendo «Más». La
//  lógica la fijan los tests de `YalaTests/PrimerosPasosPulido/`.
//

import XCTest

final class PrimerosPasosPulidoCapturasUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    private func tapWhenSettled(_ app: XCUIApplication, _ id: String, timeout: TimeInterval = 10,
                                file: StaticString = #filePath, line: UInt = #line) {
        let target = element(app, id)
        XCTAssertTrue(target.waitForExistence(timeout: timeout), "No apareció «\(id)».", file: file, line: line)
        _ = app.waitForSettledLayout(of: target)
        target.tap()
    }

    private func type(_ app: XCUIApplication, _ text: String, into id: String) {
        tapWhenSettled(app, id)
        element(app, id).typeText(text)
    }

    /// Cierra la guía de Más con lo que tenga: «Omitir» (antes) o «Entendido» (después).
    private func closePlaceGuide(_ app: XCUIApplication) {
        for id in ["place_guide_close", "place_guide_skip", "place_guide_advance"] where element(app, id).exists {
            tapWhenSettled(app, id)
            return
        }
    }

    /// Paso 1: la intro, el nombre, un campo con texto, las dos cards vecinas, «Día» con su número y volver un paso.
    func test_capturas_paso1_cuenta() {
        let app = XCUIApplication()
        app.launchForUITest(seed: nil, extraArguments: ["-uitest-fresh-install", "-uitest-show-setup-deck"])
        XCTAssertTrue(app.waitForUITestReady())
        tapWhenSettled(app, "setup_deck_current")
        XCTAssertTrue(element(app, "first_account_start").waitForExistence(timeout: 10))
        attach(app, "p01-intro-cuenta")
        tapWhenSettled(app, "first_account_start")
        tapWhenSettled(app, "first_account_kind_creditCard")
        tapWhenSettled(app, "first_account_currency_continue")

        let name = element(app, "first_account_name_field")
        XCTAssertTrue(name.waitForExistence(timeout: 10))
        attach(app, "p02-nombre")
        XCTAssertEqual(name.value as? String, "Tarjeta de crédito", "El nombre llega con el del tipo.")
        XCTAssertFalse(element(app, "first_account_name_keep").exists, "Sin «Sí, así está bien».")
        tapWhenSettled(app, "first_account_send")

        type(app, "620", into: "first_account_amount")
        attach(app, "p03-campo-con-texto")
        tapWhenSettled(app, "first_account_send")

        XCTAssertTrue(element(app, "first_account_day_unknown").waitForExistence(timeout: 10))
        attach(app, "p04-cards-vecinas")
        type(app, "15", into: "first_account_day")
        attach(app, "p05-dia-y-numero")
        tapWhenSettled(app, "first_account_send")

        XCTAssertTrue(element(app, "first_account_day_unknown").waitForExistence(timeout: 10))
        tapWhenSettled(app, "first_account_back")
        let day = element(app, "first_account_day")
        XCTAssertTrue(day.waitForExistence(timeout: 10))
        attach(app, "p06-volver-un-paso")
        XCTAssertEqual(day.value as? String, "15", "Volver un paso conserva el día escrito.")
        tapWhenSettled(app, "first_account_back")
        XCTAssertEqual(element(app, "first_account_amount").value as? String, "620", "Y el saldo.")
    }

    /// Las intros como historias: la mitad derecha avanza, la izquierda vuelve y mantener el dedo pausa.
    func test_historias_tocarPorMitades_yMantenerPausa() {
        let app = XCUIApplication()
        app.launchForUITest(seed: nil, extraArguments: ["-uitest-fresh-install", "-uitest-show-setup-deck"])
        XCTAssertTrue(app.waitForUITestReady())
        tapWhenSettled(app, "setup_deck_current")
        let stage = element(app, "tutorial_story_stage")
        XCTAssertTrue(stage.waitForExistence(timeout: 10))
        let first = app.buttons["Parte 1 de 3"], second = app.buttons["Parte 2 de 3"]

        stage.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.3)).tap()
        XCTAssertTrue(second.isSelected, "La mitad derecha avanza.")
        stage.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.3)).tap()
        XCTAssertTrue(first.isSelected, "La mitad izquierda vuelve.")
        // Sola pasaría a la segunda a los 3,4 s; con el dedo puesto 5 s sigue en la primera.
        stage.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3)).press(forDuration: 5)
        XCTAssertTrue(first.isSelected, "Mantener el dedo pausa la historia.")
        XCTAssertFalse(element(app, "first_account_skip_step").exists)
        expectation(for: NSPredicate(format: "isSelected == true"), evaluatedWith: second)
        waitForExpectations(timeout: 6)
    }

    /// Pasos 3, 4, 5 y 6: la intro con o sin «Omitir», la primera pregunta, los finales, la guía de Más y el paso 6.
    func test_capturas_pasos3a6_planificacion() {
        let app = XCUIApplication()
        app.launchForUITest(
            seed: "cuenta-con-movimientos", extraArguments: ["-uitest-fresh-install", "-uitest-show-setup-deck"])
        XCTAssertTrue(app.waitForUITestReady())

        // Paso 3.
        tapWhenSettled(app, "setup_deck_current")
        XCTAssertTrue(element(app, "first_budget_start").waitForExistence(timeout: 10))
        attach(app, "p01-intro-presupuesto")
        tapWhenSettled(app, "first_budget_start")
        XCTAssertTrue(element(app, "first_budget_scope_all").waitForExistence(timeout: 10))
        attach(app, "p07-primera-pregunta-presupuesto")
        XCTAssertTrue(element(app, "first_budget_none").exists, "«No deseo crear ningún presupuesto».")
        tapWhenSettled(app, "first_budget_scope_all")
        tapWhenSettled(app, "first_budget_period_monthly")
        type(app, "600", into: "first_budget_limit")
        tapWhenSettled(app, "first_budget_limit_send")
        tapWhenSettled(app, "first_budget_name_yes")
        tapWhenSettled(app, "first_budget_alert_none")
        tapWhenSettled(app, "first_budget_panel_yes")
        XCTAssertTrue(element(app, "first_budget_done").waitForExistence(timeout: 10))
        attach(app, "p09-final-presupuesto")
        XCTAssertTrue(element(app, "first_budget_another").exists, "«Crear otro» con el límite libre.")
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "hasta 3 presupuestos"))
            .firstMatch.exists, "El límite gratis real.")
        tapWhenSettled(app, "first_budget_done")
        XCTAssertTrue(element(app, "place_guide_card").waitForExistence(timeout: 10))
        sleep(1)
        attach(app, "p11-guia-presupuestos")
        XCTAssertTrue(element(app, "place_guide_close").exists, "Un solo momento: «Entendido».")
        XCTAssertFalse(element(app, "place_guide_skip").exists, "Sin «Omitir».")
        closePlaceGuide(app)

        // Paso 4.
        tapWhenSettled(app, "setup_deck_current")
        XCTAssertTrue(element(app, "first_payment_start").waitForExistence(timeout: 10))
        attach(app, "p01-intro-pago")
        tapWhenSettled(app, "first_payment_start")
        XCTAssertTrue(element(app, "first_payment_kind_continue").waitForExistence(timeout: 10))
        attach(app, "p08-primera-pregunta-pago")
        XCTAssertTrue(element(app, "first_payment_none").exists, "«No deseo crear ningún pago planificado».")
        XCTAssertTrue(app.staticTexts["Elige un pago que hagas cada cierto tiempo"].exists)
        tapWhenSettled(app, "first_payment_kind_utilities")
        tapWhenSettled(app, "first_payment_kind_continue")
        type(app, "80", into: "first_payment_amount")
        app.swipeDown()
        tapWhenSettled(app, "first_payment_details_continue")
        tapWhenSettled(app, "first_payment_when_continue")
        tapWhenSettled(app, "first_payment_reminder_none")
        tapWhenSettled(app, "first_payment_panel_no")
        XCTAssertTrue(element(app, "first_payment_done").waitForExistence(timeout: 10))
        attach(app, "p10-final-pago")
        tapWhenSettled(app, "first_payment_done")
        XCTAssertTrue(element(app, "place_guide_card").waitForExistence(timeout: 10))
        sleep(1)
        attach(app, "p11-guia-pagos")
        closePlaceGuide(app)

        // Paso 5, omitido, y paso 6.
        tapWhenSettled(app, "setup_deck_current")
        tapWhenSettled(app, "groups_tutorial_skip_step")
        tapWhenSettled(app, "setup_deck_current")
        XCTAssertTrue(element(app, "place_guide_card").waitForExistence(timeout: 10))
        sleep(2)
        attach(app, "p12-paso6")
        XCTAssertTrue(app.tabBars.buttons["Más"].isSelected, "El paso 6 abre «Más» solo.")
        XCTAssertTrue(element(app, "place_guide_advance").exists, "Cierra con «Entendido».")
    }
}
