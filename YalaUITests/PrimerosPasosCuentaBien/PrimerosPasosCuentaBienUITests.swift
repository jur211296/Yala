//
//  PrimerosPasosCuentaBienUITests.swift
//  YalaUITests
//
//  Primer lote de la observación del iPhone 14 (25-nov-2026): pasos de Primeros pasos que salían «para después» estando
//  hechos. El paso 5 (Grupos) con «Ahora no» tras ver la intro, y el paso 7 pasando las historias hasta «Terminar» sin
//  abrir ningún «Enséñame cómo». Con el bug, los dos quedaban «Omitido» en la fila de pasos.
//

import XCTest

final class PrimerosPasosCuentaBienUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launch(atStep step: Int) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(
            seed: "cuenta-con-movimientos",
            extraArguments: ["-uitest-fresh-install", "-uitest-show-setup-deck", "-uitest-setup-deck-at", "\(step)",
                             "-uitest-fake-prices", "eligible"])
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

    /// El estado del paso en la fila de los siete: «hecho», «Omitido», «paso actual»…
    private func expectStep(_ app: XCUIApplication, _ id: String, value: String,
                            file: StaticString = #filePath, line: UInt = #line) {
        let step = element(app, "setup_deck_step_\(id)")
        XCTAssertTrue(step.waitForExistence(timeout: 10), "No está el paso «\(id)» en la fila.", file: file, line: line)
        let matches = NSPredicate(format: "value ==[c] %@", value)
        let done = XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: matches, object: step)], timeout: 10)
        XCTAssertEqual(done, .completed, "El paso «\(id)» dice «\(step.value ?? "")», no «\(value)».",
                       file: file, line: line)
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// Paso 5: ver la intro, aceptar y «Ahora no» deja Grupos hecho y el mazo en el 6, sin el aviso «lo viste al entrar».
    func test_paso5_ahoraNoTrasLaIntro_dejaElPasoHecho() {
        let app = launch(atStep: 5)
        tapWhenSettled(app, "setup_deck_current")
        XCTAssertTrue(element(app, "groups_tutorial_skip_step").waitForExistence(timeout: 10), "No salió Grupos.")
        let accept = element(app, "groups_tutorial_accept")
        for _ in 0..<3 where !accept.exists {
            let next = element(app, "groups_tutorial_continue")
            guard next.exists else { break }
            next.tap()
        }
        XCTAssertTrue(accept.waitForExistence(timeout: 10), "No llegó al consentimiento.")
        tapWhenSettled(app, "groups_tutorial_accept")
        tapWhenSettled(app, "groups_tutorial_what_not_now")

        let deck = app.buttons["setup_deck_current"]
        XCTAssertTrue(deck.waitForExistence(timeout: 10), "No volvió el mazo.")
        let moved = NSPredicate(format: "label CONTAINS %@", "6 de 7")
        XCTAssertEqual(XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: moved, object: deck)], timeout: 10),
                       .completed, "El mazo no pasó al paso 6: «\(deck.label)».")
        expectStep(app, "groups", value: "hecho")
        XCTAssertFalse(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "al entrar")).firstMatch.exists,
                       "Salió el aviso «lo viste al entrar».")
        attach(app, "paso5-ahora-no-hecho")
    }

    /// Paso 4: un pago mensual cuyo día de este mes ya pasó vence el mes que viene. Con el bug el widget de Pagos
    /// planificados del Panel decía «Sin pagos próximos»; ahora enseña «Próximo pago» con ese pago.
    func test_paso4_pagoQueVenceElMesQueViene_saleEnElWidget() throws {
        let yesterday = Calendar.current.component(.day, from: .now) - 1
        guard yesterday >= 1 else { throw XCTSkip("Hoy es día 1: no hay un día de este mes que ya haya pasado.") }

        let app = launch(atStep: 4)
        tapWhenSettled(app, "setup_deck_current")
        tapWhenSettled(app, "first_payment_start")
        tapWhenSettled(app, "first_payment_kind_utilities")
        tapWhenSettled(app, "first_payment_kind_continue")
        tapWhenSettled(app, "first_payment_amount")
        element(app, "first_payment_amount").typeText("20")
        app.swipeDown()
        tapWhenSettled(app, "first_payment_details_continue")

        tapWhenSettled(app, "first_payment_day_other")
        tapWhenSettled(app, "first_payment_day_field")
        element(app, "first_payment_day_field").typeText("\(yesterday)")
        tapWhenSettled(app, "first_payment_day_send")

        tapWhenSettled(app, "first_payment_reminder_3")
        tapWhenSettled(app, "first_payment_panel_yes")
        tapWhenSettled(app, "first_payment_done")
        let close = element(app, "place_guide_close")
        if close.waitForExistence(timeout: 4) {
            _ = app.waitForSettledLayout(of: close)
            close.tap()
        }

        let next = element(app, "scheduled_widget_small_next")
        for _ in 0..<4 where !next.exists { app.swipeUp() }
        XCTAssertTrue(next.waitForExistence(timeout: 10), "El widget no enseña el próximo pago del mes que viene.")
        attach(app, "paso4-widget-proximo-pago")
    }

    /// Paso 7: pasar las historias con toques hasta «Terminar», sin abrir ningún «Enséñame cómo», deja el paso hecho.
    func test_paso7_historiasHastaTerminar_dejaElPasoHecho() {
        let app = launch(atStep: 7)
        tapWhenSettled(app, "setup_deck_current")
        let stage = element(app, "tutorial_story_stage")
        XCTAssertTrue(stage.waitForExistence(timeout: 10), "No salieron las historias del paso 7.")
        let finish = element(app, "tutorial_story_finish")
        for _ in 0..<8 where !finish.exists {
            _ = app.waitForSettledLayout(of: stage)
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.45)).tap()
        }
        XCTAssertTrue(finish.waitForExistence(timeout: 10), "No llegó a la última historia.")
        attach(app, "paso7-ultima-historia")
        tapWhenSettled(app, "tutorial_story_finish")

        XCTAssertTrue(element(app, "setup_deck_done_title").waitForExistence(timeout: 10),
                      "Con el paso 7 resuelto sale el final de Primeros pasos.")
        expectStep(app, "homeScreen", value: "hecho")
        attach(app, "paso7-final-hecho")
    }
}
