//
//  Bienvenida23FinalUITests.swift
//  YalaUITests
//
//  Lote 05 de la bienvenida 2.3 (docs/onboarding-2-3/SPEC.md): el paso 6 (Y23-14), el paso 7 (Y23-16, como historias
//  desde el 20-nov-2026) y el final con la oferta de Pro (Y23-18), recorridos de punta a punta. El mazo arranca en el paso que toca con `-uitest-setup-deck-at`
//  (los anteriores omitidos) y los precios son los de mentira de `-uitest-fake-prices` (StoreKit no contesta en XCUITest).
//

import XCTest

final class Bienvenida23FinalUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launch(atStep step: Int, extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(
            seed: "cuenta-con-movimientos",
            extraArguments: ["-uitest-fresh-install", "-uitest-show-setup-deck", "-uitest-setup-deck-at", "\(step)",
                             "-uitest-fake-prices", "eligible"] + extra)
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

    /// La historia a la vista, por su rótulo «Tutorial · N de M · Nombre»: el escenario de la página de historias pisa
    /// los ids de su contenido (medido con axe el 2026-11-20), así que el rótulo, que va fuera, es lo que la distingue.
    private func waitForStory(_ app: XCUIApplication, _ position: Int, of count: Int, _ name: String,
                              timeout: TimeInterval = 10) -> Bool {
        let eyebrow = element(app, "tutorial_story_eyebrow")
        let predicate = NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "\(position) de \(count)", name)
        return XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: eyebrow)],
                                timeout: timeout) == .completed
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// Y23-14 y pulido del 2026-11-20: el paso 6 abre «Más» solo, la guía enseña Estadísticas con «Entendido» y el mazo
    /// pasa al paso 7.
    func test_step6_opensMore_understood_movesTheDeckToStep7() {
        let app = launch(atStep: 6)
        let deck = app.buttons["setup_deck_current"]
        XCTAssertTrue(deck.waitForExistence(timeout: 10))
        XCTAssertTrue(deck.label.contains("6 de 7"), "El mazo empieza en el paso 6: «\(deck.label)».")
        tapWhenSettled(app, "setup_deck_current")
        // El paso 6 abre «Más» solo.
        expectation(for: NSPredicate(format: "isSelected == true"), evaluatedWith: app.tabBars.buttons["Más"])
        waitForExpectations(timeout: 10)
        XCTAssertFalse(element(app, "place_guide_skip").exists, "Sin «Omitir».")
        tapWhenSettled(app, "place_guide_advance")
        app.tabBars.buttons["Panel"].tap()
        expectation(for: NSPredicate(format: "label CONTAINS %@", "7 de 7"), evaluatedWith: deck)
        waitForExpectations(timeout: 10)
    }

    /// Y23-16, opción B de Jürgen (20-nov-2026): cuatro historias (sin el correo), cada una con su ejemplo y «Enséñame
    /// cómo». Terminar un mini tutorial pasa a la siguiente historia; tocar a la derecha pasa sin verlo; «Terminar» en la
    /// última cierra el paso, que queda hecho (se vio uno) y el mazo se completa (Y23-18).
    func test_step7_fourStories_howToAndTapThrough_thenTheDeckCompletes() {
        let app = launch(atStep: 7)
        tapWhenSettled(app, "setup_deck_current")
        XCTAssertTrue(waitForStory(app, 1, of: 4, "Widget"), "La primera historia: el widget, «Tutorial · 1 de 4».")
        XCTAssertFalse(element(app, "home_tutorial_skip_step").exists, "Sin «Omitir este paso».")
        attach(app, "paso7-historia-widget")

        // «Enséñame cómo» abre el mini tutorial del widget; «Listo» lo da por hecho y pasa a Apple Pay.
        tapWhenSettled(app, "home_tutorial_how_to")
        XCTAssertTrue(element(app, "home_tutorial_step_4").waitForExistence(timeout: 10), "El widget va en 4 pasos.")
        tapWhenSettled(app, "home_tutorial_method_done")
        XCTAssertTrue(waitForStory(app, 2, of: 4, "Apple Pay"), "Sigue Apple Pay.")
        attach(app, "paso7-historia-apple-pay")

        // Tocar a la derecha pasa sin abrir el mini tutorial: Compartir y luego Siri.
        _ = app.waitForSettledLayout(of: element(app, "tutorial_story_stage"))
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.45)).tap()
        XCTAssertTrue(waitForStory(app, 3, of: 4, "Compartir"), "Sigue Compartir.")
        attach(app, "paso7-historia-compartir")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.45)).tap()
        XCTAssertTrue(waitForStory(app, 4, of: 4, "Siri"), "Sigue Siri.")
        attach(app, "paso7-historia-siri")

        tapWhenSettled(app, "tutorial_story_finish")
        XCTAssertTrue(element(app, "setup_deck_done_title").waitForExistence(timeout: 10),
                      "Con el paso 7 resuelto, el mazo desaparece y queda «¡Primeros pasos completos!».")
        attach(app, "final-tarjeta")
    }

    /// La ✕ cierra el paso 7 sin tocar el mazo, y al volver sigue en la misma historia.
    func test_step7_close_keepsTheDeckAndTheStory() {
        let app = launch(atStep: 7)
        tapWhenSettled(app, "setup_deck_current")
        let stage = element(app, "tutorial_story_stage")
        XCTAssertTrue(stage.waitForExistence(timeout: 10))
        _ = app.waitForSettledLayout(of: stage)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.45)).tap()
        XCTAssertTrue(waitForStory(app, 2, of: 4, "Apple Pay"))
        tapWhenSettled(app, "tutorial_story_back")

        let deck = app.buttons["setup_deck_current"]
        XCTAssertTrue(deck.waitForExistence(timeout: 10))
        XCTAssertTrue(deck.label.contains("7 de 7"), "La ✕ no resuelve el paso: «\(deck.label)».")
        tapWhenSettled(app, "setup_deck_current")
        XCTAssertTrue(waitForStory(app, 2, of: 4, "Apple Pay"), "Al volver, sigue en la historia donde se cerró.")
    }

    /// Y23-19: con los datos en la cuenta de Yala (la dirección fingida de `-uitest-bank-email`) hay seis historias y la
    /// cuarta es el correo; su mini tutorial enseña «Tu dirección de Yala» con «Copiar» y los tres pasos del filtro. La
    /// sexta, desde el 23-nov, es «Tu IA» («Conecta tu IA», decisión D7), con la misma regla que el correo.
    func test_step7_withTheYalaAccount_theMailIsTheFourthOfSixStories_andYourAIIsTheLast() {
        let app = launch(atStep: 7, extra: ["-uitest-bank-email"])
        tapWhenSettled(app, "setup_deck_current")
        let stage = element(app, "tutorial_story_stage")
        XCTAssertTrue(waitForStory(app, 1, of: 6, "Widget"), "Seis historias.")
        for _ in 0..<3 {
            _ = app.waitForSettledLayout(of: stage)
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.45)).tap()
        }
        XCTAssertTrue(waitForStory(app, 4, of: 6, "Correo"), "La cuarta es el correo.")
        tapWhenSettled(app, "home_tutorial_how_to")
        let address = element(app, "home_tutorial_mail_address")
        XCTAssertTrue(address.waitForExistence(timeout: 10), "El mini tutorial del correo enseña la dirección.")
        XCTAssertEqual(address.label, "auto+k7m2xq9wpb@yalainbox.com")
        XCTAssertTrue(element(app, "home_tutorial_step_3").exists, "Los tres pasos del filtro.")
        XCTAssertTrue(element(app, "home_tutorial_mail_copy").exists, "«Copiar».")
        attach(app, "paso7-correo")
        tapWhenSettled(app, "home_tutorial_method_done")
        XCTAssertTrue(waitForStory(app, 5, of: 6, "Siri"), "Después del correo, Siri.")
        _ = app.waitForSettledLayout(of: stage)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.45)).tap()
        XCTAssertTrue(waitForStory(app, 6, of: 6, "Tu IA"), "La última es Tu IA.")
        attach(app, "paso7-tu-ia-historia")
        tapWhenSettled(app, "home_tutorial_how_to")
        XCTAssertTrue(element(app, "conecta_ia_address").waitForExistence(timeout: 10),
                      "El mini tutorial de Tu IA enseña la dirección del conector.")
        XCTAssertTrue(element(app, "conecta_ia_step_3").exists, "Los tres pasos de conectar.")
        attach(app, "paso7-tu-ia-guia")
        // Terminar el mini tutorial de la última manera termina el paso (`HomeScreenTutorialFlowView.done`).
        tapWhenSettled(app, "home_tutorial_method_done")
        XCTAssertTrue(element(app, "setup_deck_done_title").waitForExistence(timeout: 10))
    }

    /// Y23-18: la oferta sube sola tras el final con el anual preseleccionado y la línea de tiempo; «Seguir con la versión
    /// gratis» la cierra sin dar Pro.
    func test_final_offer_keepFree_closesWithoutPro() {
        let app = launch(atStep: 8)
        let title = element(app, "setup_offer_title")
        XCTAssertTrue(title.waitForExistence(timeout: 15), "La oferta del final sube sola.")
        XCTAssertTrue(title.label.contains("1"), "La prueba de un mes se anuncia como «1 mes»: «\(title.label)».")
        XCTAssertTrue(element(app, "setup_offer_plans").exists)
        // El botón de empezar, solo y fijo abajo, a la vista sin desplazar (opción B del 20-nov-2026).
        XCTAssertTrue(element(app, "setup_offer_cta").isHittable, "«Empezar mi mes gratis» se ve sin bajar.")
        attach(app, "oferta")
        app.swipeUp()
        XCTAssertTrue(element(app, "setup_offer_timeline").waitForExistence(timeout: 5))
        tapWhenSettled(app, "setup_offer_close")
        XCTAssertTrue(title.waitForNonExistence(timeout: 10), "«Ahora no» cierra la oferta.")
        XCTAssertFalse(element(app, "setup_offer_success_title").exists, "Sin confirmar en la hoja de pago no hay Pro.")
        XCTAssertTrue(element(app, "setup_deck_done_title").waitForExistence(timeout: 5))
    }

    /// Y23-18: con la compra confirmada (fingida), «¡Listo! Tienes Pro» con la fecha real del fin de la prueba.
    func test_final_offer_confirmedPurchase_showsProIsOn() {
        // La compra fingida deja Pro con la prueba de un mes en curso, como la confirma Apple.
        let app = launch(atStep: 8, extra: ["-uitest-fake-purchase", "-uitest-pro-trial-days", "30"])
        XCTAssertTrue(element(app, "setup_offer_title").waitForExistence(timeout: 15))
        app.swipeUp()
        tapWhenSettled(app, "setup_offer_cta")
        XCTAssertTrue(element(app, "setup_offer_success_title").waitForExistence(timeout: 10))
        XCTAssertTrue(element(app, "setup_offer_success_line").exists, "Dice hasta cuándo va la prueba y cuándo avisamos.")
        // Sin tour Pro: «Pruébalo ahora» con los tres accesos (opción B del 20-nov-2026).
        XCTAssertTrue(element(app, "pro_try_now_voice").exists, "«Dicta un gasto».")
        XCTAssertTrue(element(app, "pro_try_now_photo").exists, "«Lee un recibo».")
        XCTAssertTrue(element(app, "pro_try_now_yalaAI").exists, "«Pregúntale a Yala IA».")
        attach(app, "listo-tienes-pro")
        tapWhenSettled(app, "setup_offer_start_using")
        XCTAssertTrue(element(app, "setup_offer_success_title").waitForNonExistence(timeout: 10))
    }

    /// Oferta Pro con todos los beneficios (opción A, 20-nov-2026): «Ver todos los beneficios» empuja «Qué incluye Yala
    /// Pro» en la misma hoja, con el botón de empezar fijo abajo, y «‹» vuelve con el plan que se eligió antes.
    func test_final_offer_seeAllBenefits_pushesAndComesBack() {
        let app = launch(atStep: 8)
        XCTAssertTrue(element(app, "setup_offer_title").waitForExistence(timeout: 15))
        XCTAssertTrue(element(app, "setup_offer_block_capture").exists, "«Anota sin teclear».")
        XCTAssertTrue(element(app, "setup_offer_block_style").exists, "«A tu estilo».")
        // El mensual, elegido antes de ir a la página (el anual llega preseleccionado).
        let monthly = app.buttons["pro_plan_monthly"].firstMatch
        XCTAssertTrue(monthly.waitForExistence(timeout: 5))
        _ = app.waitForSettledLayout(of: monthly)
        monthly.tap()
        XCTAssertTrue(monthly.isSelected, "No quedó elegido el mensual.")

        tapWhenSettled(app, "setup_offer_see_all")
        XCTAssertTrue(element(app, "setup_offer_all_benefits").waitForExistence(timeout: 10),
                      "«Ver todos los beneficios» no empujó «Qué incluye Yala Pro».")
        XCTAssertTrue(element(app, "setup_offer_all_benefits_row_accounts").exists, "La fila de cuentas.")
        XCTAssertTrue(element(app, "setup_offer_cta").isHittable, "«Empezar mi mes gratis» fijo abajo en la página.")
        XCTAssertFalse(element(app, "setup_offer_plans").exists, "La página no repite los planes.")
        attach(app, "que-incluye-yala-pro")

        let back = app.navigationBars.buttons["BackButton"].firstMatch.exists
            ? app.navigationBars.buttons["BackButton"].firstMatch
            : app.navigationBars.buttons.element(boundBy: 0)
        back.tap()
        XCTAssertTrue(element(app, "setup_offer_all_benefits").waitForNonExistence(timeout: 10), "«‹» no volvió.")
        XCTAssertTrue(app.buttons["pro_plan_monthly"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["pro_plan_monthly"].firstMatch.isSelected, "Al volver se perdió el plan elegido.")
        XCTAssertFalse(app.buttons["pro_plan_yearly"].firstMatch.isSelected)
    }

    /// Desde «Qué incluye Yala Pro», «Empezar mi mes gratis» compra el plan de la oferta y queda «¡Listo! Tienes Pro».
    func test_final_offer_purchaseFromAllBenefits_showsProIsOn() {
        let app = launch(atStep: 8, extra: ["-uitest-fake-purchase", "-uitest-pro-trial-days", "30"])
        XCTAssertTrue(element(app, "setup_offer_title").waitForExistence(timeout: 15))
        tapWhenSettled(app, "setup_offer_see_all")
        XCTAssertTrue(element(app, "setup_offer_all_benefits").waitForExistence(timeout: 10))
        tapWhenSettled(app, "setup_offer_cta")
        XCTAssertTrue(element(app, "setup_offer_success_title").waitForExistence(timeout: 10),
                      "Comprar desde la página no dejó «¡Listo! Tienes Pro».")
        XCTAssertFalse(element(app, "setup_offer_all_benefits").exists, "La página no se retiró tras la compra.")
        attach(app, "listo-desde-la-pagina")
    }
}
