//
//  Bienvenida23PlanificacionUITests.swift
//  YalaUITests
//
//  Lote 04 de la bienvenida 2.3 (docs/onboarding-2-3/SPEC.md): los pasos 3, 4 y 5 de Primeros pasos recorridos desde el
//  mazo del Panel — el primer presupuesto preguntando (Y23-11), el primer pago planificado (Y23-12) y Grupos con el estilo
//  del tutorial (Y23-13). Cada caso termina con el mazo en el paso siguiente. Deja capturas de cada pantalla.
//
//  La semilla `cuenta-con-movimientos` trae cuentas y dos gastos y nada más: el mazo arranca en el paso 3.
//

import XCTest

final class Bienvenida23PlanificacionUITests: XCTestCase {

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

    private func launchAtStep3() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(
            seed: "cuenta-con-movimientos", extraArguments: ["-uitest-fresh-install", "-uitest-show-setup-deck"])
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap no completó.")
        return app
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

    /// El mazo pasa al paso `position` (y su título).
    private func expectDeck(_ app: XCUIApplication, at position: Int, title: String,
                            file: StaticString = #filePath, line: UInt = #line) {
        let deck = app.buttons["setup_deck_current"]
        XCTAssertTrue(deck.waitForExistence(timeout: 10), file: file, line: line)
        let moved = NSPredicate(format: "label CONTAINS %@", "\(position) de 7")
        expectation(for: moved, evaluatedWith: deck)
        waitForExpectations(timeout: 10)
        XCTAssertTrue(deck.label.contains(title), "El mazo pasa al paso \(position): «\(deck.label)».", file: file, line: line)
    }

    /// Cierra la guía «dónde vive cada cosa» si sale.
    private func dismissPlaceGuideIfShown(_ app: XCUIApplication) {
        let skip = element(app, "place_guide_skip")
        if skip.waitForExistence(timeout: 4) {
            _ = app.waitForSettledLayout(of: skip)
            skip.tap()
        }
    }

    private func skipStepFromDeck(_ app: XCUIApplication, skipID: String) {
        tapWhenSettled(app, "setup_deck_current")
        tapWhenSettled(app, skipID)
    }

    /// Y23-11: solo algunas categorías, quitando una subcategoría, mensual, tope, nombre propuesto, avisos al 75 % y al
    /// 100 % y en el Panel. Al terminar, la guía «Tus presupuestos viven en Más» y el mazo en el paso 4.
    func test_step3_budgetByCategories_withAlerts_inPanel_thenDeckMovesToStep4() {
        let app = launchAtStep3()
        expectDeck(app, at: 3, title: "presupuesto")
        tapWhenSettled(app, "setup_deck_current")

        XCTAssertTrue(element(app, "first_budget_start").waitForExistence(timeout: 10), "No salió la página corta.")
        attach(app, "paso3-1-pagina-corta")
        tapWhenSettled(app, "first_budget_start")

        attach(app, "paso3-2-que-gastos-cuenta")
        tapWhenSettled(app, "first_budget_scope_categories")
        tapWhenSettled(app, "first_budget_category")
        attach(app, "paso3-3-cuales")
        tapWhenSettled(app, "first_budget_categories_continue")

        // ¿Algo que no quieras contar?: todas marcadas; se quita una.
        let firstSub = element(app, "first_budget_subcategory")
        XCTAssertTrue(firstSub.waitForExistence(timeout: 10))
        XCTAssertTrue(firstSub.isSelected, "Las subcategorías llegan todas marcadas.")
        tapWhenSettled(app, "first_budget_subcategory")
        attach(app, "paso3-4-algo-que-no-quieras-contar")
        tapWhenSettled(app, "first_budget_subcategories_continue")

        tapWhenSettled(app, "first_budget_period_monthly")
        type(app, "600", into: "first_budget_limit")
        attach(app, "paso3-5-tope")
        tapWhenSettled(app, "first_budget_limit_send")

        tapWhenSettled(app, "first_budget_name_yes")
        attach(app, "paso3-6-avisos")
        tapWhenSettled(app, "first_budget_alert_75")
        attach(app, "paso3-7-en-tu-panel")
        tapWhenSettled(app, "first_budget_panel_yes")

        XCTAssertTrue(element(app, "first_budget_done").waitForExistence(timeout: 10), "No llegó a «¡Listo!».")
        XCTAssertTrue(element(app, "first_budget_card").label.contains("75"), "La tarjeta dice el aviso al 75 %.")
        attach(app, "paso3-8-listo")
        tapWhenSettled(app, "first_budget_done")

        // La guía de Más sale sobre el Panel.
        XCTAssertTrue(element(app, "place_guide_card").waitForExistence(timeout: 10), "No salió la guía de Más.")
        attach(app, "paso3-9-guia-presupuestos-en-mas")
        dismissPlaceGuideIfShown(app)
        expectDeck(app, at: 4, title: "pagos fijos")
        attach(app, "paso3-10-panel-con-el-presupuesto")
    }

    /// Y23-12: Servicios (nombre precargado, ejemplo «Luz», monto estimado), cada mes el día 15, aviso 3 días antes y en
    /// el Panel. El resumen del editor sale en la tarjeta y el mazo pasa al paso 5.
    func test_step4_paymentUtilities_monthly_reminder_thenDeckMovesToStep5() {
        let app = launchAtStep3()
        skipStepFromDeck(app, skipID: "first_budget_skip_step")
        expectDeck(app, at: 4, title: "pagos fijos")
        tapWhenSettled(app, "setup_deck_current")

        XCTAssertTrue(element(app, "first_payment_start").waitForExistence(timeout: 10), "No salió la página corta.")
        attach(app, "paso4-1-pagina-corta")
        tapWhenSettled(app, "first_payment_start")

        tapWhenSettled(app, "first_payment_kind_utilities")
        // Servicios no es suscripción.
        XCTAssertEqual(app.switches["first_payment_is_subscription"].value as? String, "0")
        attach(app, "paso4-2-que-pagas")
        tapWhenSettled(app, "first_payment_kind_continue")

        // Nombre precargado con el tipo; un ejemplo lo cambia.
        let name = element(app, "first_payment_name")
        XCTAssertTrue(name.waitForExistence(timeout: 10))
        XCTAssertEqual(name.value as? String, "Servicio", "El nombre llega precargado con el tipo.")
        // Servicios llega con «Cambia cada vez» encendido (monto estimado).
        XCTAssertEqual(app.switches["first_payment_variable"].value as? String, "1")
        tapWhenSettled(app, "first_payment_example")
        type(app, "80", into: "first_payment_amount")
        app.swipeDown()
        attach(app, "paso4-3-nombre-y-monto")
        tapWhenSettled(app, "first_payment_details_continue")

        tapWhenSettled(app, "first_payment_day_15")
        attach(app, "paso4-4-cuando")
        tapWhenSettled(app, "first_payment_when_continue")

        attach(app, "paso4-5-aviso")
        tapWhenSettled(app, "first_payment_reminder_3")
        tapWhenSettled(app, "first_payment_panel_yes")

        XCTAssertTrue(element(app, "first_payment_done").waitForExistence(timeout: 10), "No llegó a «¡Listo!».")
        XCTAssertTrue(element(app, "first_payment_another").exists, "«Anotar otro pago» a la vista.")
        XCTAssertTrue(element(app, "first_payment_summary").label.contains("15"), "El resumen dice el día 15.")
        attach(app, "paso4-6-listo")
        tapWhenSettled(app, "first_payment_done")

        XCTAssertTrue(element(app, "place_guide_card").waitForExistence(timeout: 10), "No salió la guía de Más.")
        attach(app, "paso4-7-guia-pagos-en-mas")
        dismissPlaceGuideIfShown(app)
        expectDeck(app, at: 5, title: "grupo")
        attach(app, "paso4-8-panel-con-el-pago")
    }

    /// Y23-13: sin haber visto el onboarding de Grupos, sale como página del tutorial; el consentimiento no avanza solo;
    /// tras aceptar, «¿Qué quieres hacer?» y «Ahora no» deja el mazo en el paso 6. Al volver a tocar el paso 5 ya no
    /// sale: el onboarding quedó marcado.
    func test_step5_groupsTutorial_acceptThenNotNow_thenDeckMovesToStep6() {
        let app = launchAtStep3()
        skipStepFromDeck(app, skipID: "first_budget_skip_step")
        expectDeck(app, at: 4, title: "pagos fijos")
        skipStepFromDeck(app, skipID: "first_payment_skip_step")
        expectDeck(app, at: 5, title: "grupo")
        tapWhenSettled(app, "setup_deck_current")

        XCTAssertTrue(element(app, "groups_tutorial_skip_step").waitForExistence(timeout: 10), "No salió Grupos.")
        attach(app, "paso5-1-comparte-gastos")
        // Las dos primeras partes avanzan solas cada 3,4 s: «Continuar» se toca mientras siga a la vista, sin contar con el
        // reloj. El consentimiento no avanza solo.
        let accept = element(app, "groups_tutorial_accept")
        for index in 0..<3 where !accept.exists {
            let next = element(app, "groups_tutorial_continue")
            guard next.exists else { break }
            if index == 1 { attach(app, "paso5-2-tres-pasos") }
            next.tap()
        }
        XCTAssertTrue(accept.waitForExistence(timeout: 10), "No llegó al consentimiento.")
        XCTAssertFalse(element(app, "groups_tutorial_continue").exists, "El consentimiento no lleva «Continuar».")
        attach(app, "paso5-3-consentimiento")
        tapWhenSettled(app, "groups_tutorial_accept")

        XCTAssertTrue(element(app, "groups_tutorial_create").waitForExistence(timeout: 10), "No salió «¿Qué quieres hacer?».")
        XCTAssertTrue(element(app, "groups_tutorial_link").exists)
        attach(app, "paso5-4-que-quieres-hacer")
        tapWhenSettled(app, "groups_tutorial_what_not_now")

        expectDeck(app, at: 6, title: "dinero")
        attach(app, "paso5-5-panel-paso-6")
    }
}
