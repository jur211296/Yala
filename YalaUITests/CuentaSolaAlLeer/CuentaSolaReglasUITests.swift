//
//  CuentaSolaReglasUITests.swift
//  YalaUITests
//
//  Reglas de captura (parte 2 de la cuenta sola al leer, 2026-11-21). Semilla `ficha` + los perfiles `cuenta-sola-zip`,
//  `cuenta-sola-regla` y `cuenta-sola-reglas-choque` (crean «Zip» y «Zip Visa»; el medio de pago leído es «Zip»). La
//  cuenta la elige la escalera de producción; el perfil solo pone lo que diría la IA y, si toca, la regla en la cuenta.
//  Convenciones: ver CLAUDE.md (sin sleeps, scheme Yala Dev).
//

import XCTest

final class CuentaSolaReglasUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func openAndRead(_ profile: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(
            pro: true, seed: "ficha", aiConsent: true,
            extraArguments: [
                "-uitest-image-result", profile, "-uitest-image-autoclose-seconds", "4", "-cuentaSola.porqueVeces", "0",
            ])
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        if UIDevice.current.userInterfaceIdiom == .pad {
            let image = app.buttons["panel_action_image"]
            XCTAssertTrue(image.waitForHittable(timeout: 10))
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

    /// Criterio del ticket: la regla «zip» en «Zip Visa» manda «Zip» a Zip Visa aunque exista la cuenta «Zip», y la línea
    /// de «por qué» nombra la regla.
    func test_rule_sendsZipToZipVisa_overTheAccountCalledZip() {
        let app = openAndRead("cuenta-sola-regla")
        let chip = app.buttons["voice_draft_chip_account"]
        XCTAssertTrue(chip.waitForExistence(timeout: 5))
        XCTAssertTrue(chip.label.contains("Zip Visa"), "La regla elige Zip Visa; salió: \(chip.label)")
        let porque = app.staticTexts["cuenta_sola_porque"]
        XCTAssertTrue(porque.waitForExistence(timeout: 5), "Falta la línea de «por qué».")
        XCTAssertTrue(porque.label.contains("zip"), "La línea tiene que nombrar la regla: \(porque.label)")
    }

    /// Criterio del ticket: dos reglas igual de concretas hacia cuentas distintas no eligen, y el selector pone las dos
    /// arriba con su regla.
    func test_twoRulesTie_asksWithBothRules() {
        let app = openAndRead("cuenta-sola-reglas-choque")
        let save = app.buttons["image_save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        XCTAssertFalse(save.isEnabled, "Con dos reglas en choque, la cuenta se elige a mano.")
        app.buttons["voice_draft_chip_account"].tap()
        let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "account_selector_row_"))
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 10), "No abrió el selector de cuenta.")
        let top = rows.allElementsBoundByIndex.sorted { $0.frame.minY < $1.frame.minY }.prefix(2)
        XCTAssertEqual(Set(top.map(\.identifier)), ["account_selector_row_Zip", "account_selector_row_Zip Visa"],
                       "Arriba van las dos cuentas del choque.")
        XCTAssertTrue(top.allSatisfy { $0.label.contains("zip") }, "Cada fila dice su regla.")
    }

    /// Criterio del ticket: corregir la cuenta ofrece «Recordar», y tocarlo guarda la regla y lo confirma.
    func test_correctingTheAccount_offersRemember_andRemembers() {
        let app = openAndRead("cuenta-sola-zip")
        let chip = app.buttons["voice_draft_chip_account"]
        XCTAssertTrue(chip.waitForExistence(timeout: 5))
        XCTAssertTrue(chip.label.contains("Zip"), "Sin regla elige la cuenta «Zip» por su nombre.")
        XCTAssertFalse(app.buttons["cuenta_sola_recordar"].exists, "Sin corregir no se ofrece nada.")
        chip.tap()
        let zipVisa = app.buttons["account_selector_row_Zip Visa"]
        XCTAssertTrue(zipVisa.waitForExistence(timeout: 10), "Falta Zip Visa en el selector.")
        zipVisa.tap()
        let recordar = app.buttons["cuenta_sola_recordar"]
        XCTAssertTrue(recordar.waitForExistence(timeout: 8), "Tras corregir, falta «Recordar».")
        recordar.tap()
        let listo = app.staticTexts["cuenta_sola_recordada"]
        XCTAssertTrue(listo.waitForExistence(timeout: 5), "Falta la confirmación.")
        XCTAssertTrue(listo.label.contains("Zip Visa"), "La confirmación dice a qué cuenta irá: \(listo.label)")
        XCTAssertFalse(recordar.exists, "Recordada, la oferta se va.")
    }

    /// Editar cuenta › «Añadir regla»: el editor guarda la regla y sale como fila de «Reglas de captura».
    func test_editAccount_addRule_showsItsRow() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "ficha", extraArguments: ["-defaultPeriod", "last30Days"])
        XCTAssertTrue(app.waitForUITestReady())
        XCTAssertTrue(app.buttons["panel_action_new"].waitForExistence(timeout: 10))
        let first = app.buttons["panel_account_card_0"]
        if !first.waitForExistence(timeout: 3) { app.buttons["panel_panorama_header"].tap() }
        XCTAssertTrue(first.waitForExistence(timeout: 5), "No apareció la primera tarjeta.")
        first.tap()
        let edit = app.buttons["account_detail_edit"]
        XCTAssertTrue(edit.waitForExistence(timeout: 8), "No abrió la ficha.")
        edit.tap()
        let add = app.buttons["account_capture_rules_add"]
        // Por existencia y marco: `isHittable` lanza con el elemento entero fuera de pantalla (`testing.md`).
        var drags = 0
        while drags < 6 && (!add.exists || add.frame.maxY > app.frame.height * 0.85 || add.frame.minY < 0) {
            app.swipeUp(velocity: .slow)
            drags += 1
        }
        XCTAssertTrue(add.waitForExistence(timeout: 5), "Falta «Añadir regla» en Editar cuenta.")
        add.tap()
        let field = app.textFields["capture_rule_value"]
        XCTAssertTrue(field.waitForExistence(timeout: 8), "No abrió el editor de regla.")
        field.typeText("zip")
        let save = app.buttons["capture_rule_save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["capture_rule_preview"].firstMatch.label.contains("zip"),
                      "La vista previa enseña el ejemplo con lo escrito.")
        save.tap()
        let row = app.buttons["account_capture_rule_row"]
        XCTAssertTrue(row.waitForExistence(timeout: 8), "La regla no salió en la sección.")
        XCTAssertTrue(row.label.contains("zip"), "La fila dice la regla: \(row.label)")
    }
}
