//
//  CuentaSolaAlLeerUITests.swift
//  YalaUITests
//
//  «Esto leí» con la cuenta elegida sola (parte 1 del ticket `2026-11-20-captura-cuenta-automatica-y-reglas`). Semilla
//  `ficha` (tres cuentas en soles: la moneda sola no elige, y antes la foto salía con «Selecciona cuenta» y «Guardar»
//  apagado). Los perfiles `cuenta-sola*` de `-uitest-image-result` solo ponen lo que diría la IA; la cuenta la elige la
//  escalera de producción, sin `UITestDemoAccountLogic` (con él, este caso saldría verde sin la escalera).
//  Convenciones: ver CLAUDE.md (sin sleeps, scheme Yala Dev).
//

import XCTest

final class CuentaSolaAlLeerUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Abre la hoja de imagen y lee el perfil. `porqueVeces`: cuántas veces vio la persona la línea de «por qué».
    private func openAndRead(_ profile: String, porqueVeces: Int = 0) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(
            pro: true, seed: "ficha", aiConsent: true,
            extraArguments: [
                "-uitest-image-result", profile, "-uitest-image-autoclose-seconds", "4",
                "-cuentaSola.porqueVeces", "\(porqueVeces)",
            ])
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        if UIDevice.current.userInterfaceIdiom == .pad {
            let image = app.buttons["panel_action_image"]
            XCTAssertTrue(image.waitForHittable(timeout: 10), "Falta la acción de imagen del Panel (panel_action_image).")
            image.tap()
        } else {
            app.revealPanelFAB().tap()
            let image = app.buttons["fab_image"]
            XCTAssertTrue(image.waitForExistence(timeout: 5), "El menú del FAB no ofreció imagen (fab_image).")
            image.tap()
        }
        let photos = app.buttons["image_source_photos"]
        XCTAssertTrue(photos.waitForExistence(timeout: 15), "La hoja no abrió eligiendo (image_source_photos).")
        photos.tap()
        XCTAssertTrue(app.staticTexts["image_review_title"].waitForExistence(timeout: 15), "No apareció lo leído.")
        return app
    }

    /// La imagen dice «Tarjeta de crédito»: sale con esa cuenta, la línea de «por qué» y «Guardar» encendido.
    func test_paymentNamesAnAccount_choosesIt_withTheWhyLine() {
        let app = openAndRead("cuenta-sola")
        let save = app.buttons["image_save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5), "Falta Guardar (image_save).")
        XCTAssertTrue(save.isEnabled, "Con la cuenta elegida sola, el registro se puede guardar.")
        XCTAssertTrue(
            app.staticTexts["cuenta_sola_porque"].waitForExistence(timeout: 5),
            "La primera vez, la línea de «por qué» tiene que decir por qué se eligió la cuenta.")
        XCTAssertFalse(
            app.buttons["voice_draft_chip_account"].label.isEmpty, "El chip de cuenta tiene que decir qué cuenta es.")
    }

    /// Vista tres veces, la línea no sale; la cuenta se sigue eligiendo sola.
    func test_afterThreeTimes_theWhyLineIsGone_butTheAccountStaysChosen() {
        let app = openAndRead("cuenta-sola", porqueVeces: 3)
        let save = app.buttons["image_save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5), "Falta Guardar (image_save).")
        XCTAssertTrue(save.isEnabled, "La cuenta se sigue eligiendo sola aunque ya no salga la línea.")
        XCTAssertFalse(app.staticTexts["cuenta_sola_porque"].exists, "Desde la cuarta vez, solo la estrella.")
    }

    /// «Visa» con dos cuentas Visa: no elige, y el selector pone arriba las dos que coinciden.
    func test_twoAccountsMatch_asksAndListsThemFirst() {
        let app = openAndRead("cuenta-sola-varias")
        let save = app.buttons["image_save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5), "Falta Guardar (image_save).")
        XCTAssertFalse(save.isEnabled, "Con dos cuentas que coinciden, la cuenta se elige a mano.")

        let chip = app.buttons["voice_draft_chip_account"]
        XCTAssertTrue(chip.waitForExistence(timeout: 5), "Falta el chip de cuenta.")
        chip.tap()
        let interbank = app.buttons["account_selector_row_Interbank Visa"]
        XCTAssertTrue(interbank.waitForExistence(timeout: 10), "Falta Interbank Visa en el selector.")
        XCTAssertTrue(app.buttons["account_selector_row_BCP Visa"].exists, "Falta BCP Visa en el selector.")
        XCTAssertTrue(firstSelectorRows(app, 2).allSatisfy { $0.hasSuffix(" Visa") },
                      "Las dos que coinciden tienen que ir arriba del selector.")
        interbank.tap()
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == true"), object: save)
        XCTAssertEqual(XCTWaiter().wait(for: [enabled], timeout: 10), .completed, "Elegida la cuenta, se puede guardar.")
    }

    /// La imagen y Yala IA nombran cuentas distintas: no elige y el selector enseña las dos con su motivo.
    func test_imageAndAIDisagree_asksWithBothReasons() {
        let app = openAndRead("cuenta-sola-choque")
        let save = app.buttons["image_save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5), "Falta Guardar (image_save).")
        XCTAssertFalse(save.isEnabled, "Si la imagen y la IA discrepan, la cuenta se elige a mano.")
        app.buttons["voice_draft_chip_account"].tap()
        let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "account_selector_row_"))
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 10), "No abrió el selector de cuenta.")
        // El teléfono elige la de nombre más largo (la tarjeta) y la IA la otra: las dos arriba.
        XCTAssertEqual(Set(firstSelectorRows(app, 2)).count, 2)
        XCTAssertFalse(firstSelectorRows(app, 2).contains { $0.hasSuffix("USD") },
                       "Arriba van las dos del choque, no el resto.")
    }

    /// Los nombres de las `count` primeras filas del selector de cuenta, de arriba abajo.
    private func firstSelectorRows(_ app: XCUIApplication, _ count: Int) -> [String] {
        let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "account_selector_row_"))
            .allElementsBoundByIndex
        return rows.sorted { $0.frame.minY < $1.frame.minY }.prefix(count)
            .map { $0.identifier.replacingOccurrences(of: "account_selector_row_", with: "") }
    }

    /// Solo Yala IA propone (entre dos Visa): la cuenta sale preseleccionada como sugerida y con su línea.
    func test_onlyTheAISuggests_preselectsItAsSuggested() {
        let app = openAndRead("cuenta-sola-sugerida")
        let save = app.buttons["image_save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5), "Falta Guardar (image_save).")
        XCTAssertTrue(save.isEnabled, "La sugerida queda puesta.")
        XCTAssertTrue(
            app.staticTexts["cuenta_sola_porque"].waitForExistence(timeout: 5),
            "La sugerida dice siempre que la propone Yala IA.")
        XCTAssertTrue(app.buttons["voice_draft_chip_account"].label.contains("Interbank Visa"))
    }
}
