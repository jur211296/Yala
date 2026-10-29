//
//  SiriShortcutsScreenUITests.swift
//  YalaUITests
//
//  Ajustes › Siri y Atajos tras la auditoría UX 2.2 (lote 15, L15-4): cada acción con el nombre que tiene en Atajos y un
//  botón al pie que abre la página de Yala en Atajos. Y el aviso de la Bandeja con su línea de Siri (L15-7).
//  El idioma lo fija `launchForUITest` (es_PE).
//

import XCTest

final class SiriShortcutsScreenUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_rowsUseTheShortcutsNames_andTheButtonOpensYalasPageInShortcuts() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "La app no señaló uitest_ready.")
        let profile = app.buttons["profile_avatar"]
        XCTAssertTrue(profile.waitForExistence(timeout: 20), "No apareció profile_avatar.")
        profile.tap()
        XCTAssertTrue(app.buttons["profile_accounts"].waitForExistence(timeout: 10), "No se abrió Ajustes.")
        scrollTo(app.buttons["Siri y Atajos"], in: app)
        app.buttons["Siri y Atajos"].tap()

        // Los nombres de Atajos, y ya no los de antes («Registro rápido», «Entrada por voz»).
        XCTAssertTrue(app.staticTexts["Nuevo registro"].waitForExistence(timeout: 5))
        for name in ["Registrar por voz", "Foto o archivo", "Registrar pago de Apple Pay"] {
            XCTAssertTrue(app.staticTexts[name].exists, "Falta «\(name)».")
        }
        // Las dos preguntas a Siri (card bthx), con su frase entre comillas, al final de «Otros atajos».
        for (name, phrase) in [("Cuánto gasté", "«Cuánto gasté en Yala»"), ("Mi saldo", "«Mi saldo en Yala»")] {
            let row = app.staticTexts[name]
            scrollTo(row, in: app)
            XCTAssertTrue(row.exists, "Falta «\(name)».")
            XCTAssertTrue(app.staticTexts[phrase].exists, "Falta la frase \(phrase).")
        }
        XCTAssertFalse(app.staticTexts["Registro rápido"].exists)
        XCTAssertFalse(app.staticTexts["Entrada por voz"].exists)

        let button = app.descendants(matching: .any)["siri_shortcuts_open_shortcuts"]
        scrollTo(button, in: app)
        XCTAssertEqual(button.label, "Abrir mis atajos de Yala")
        button.tap()

        let shortcuts = XCUIApplication(bundleIdentifier: "com.apple.shortcuts")
        XCTAssertTrue(shortcuts.wait(for: .runningForeground, timeout: 15), "El botón no abrió Atajos.")
        // La página de Yala, con sus acciones; no «Todos los atajos». Atajos rotula las acciones de Yala en el idioma del
        // SISTEMA, no en el que `launchForUITest` le pone a Yala: en el simulador del CI (inglés) es «Note with Siri», y
        // el caso caía todas las noches con el botón bien (reproducido en local con el simulador en `en-US`).
        let yalaAction = shortcuts.staticTexts.matching(
            NSPredicate(format: "label IN %@", ["Anotar con Siri", "Note with Siri"])
        ).firstMatch
        XCTAssertTrue(yalaAction.waitForExistence(timeout: 15), "Atajos no se abrió en la página de Yala.")
        shortcuts.terminate()
    }

    /// Solo borradores de Siri: el aviso genérico de la Bandeja y la línea «Borradores de Siri: 2».
    func test_inboxAlert_withOnlySiriDrafts_saysSoInItsOwnLine() {
        let app = XCUIApplication()
        app.launchForUITest(inboxAlertSiri: true)
        XCTAssertTrue(app.buttons["inbox_alert_dismiss"].waitForExistence(timeout: 30), "No salió el aviso de la Bandeja.")
        XCTAssertTrue(app.staticTexts["Borradores de Siri: 2"].exists, "Falta la línea de Siri.")
    }

    /// Con otros tipos, el mensaje de siempre y la línea de Siri debajo.
    func test_inboxAlert_mixed_keepsTheUsualMessage_andAddsTheSiriLine() {
        let app = XCUIApplication()
        app.launchForUITest(inboxAlert: true, inboxAlertSiri: true)
        XCTAssertTrue(app.buttons["inbox_alert_dismiss"].waitForExistence(timeout: 30), "No salió el aviso de la Bandeja.")
        let message = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Borradores de Siri: 2")).firstMatch
        XCTAssertTrue(message.exists, "Falta la línea de Siri.")
        XCTAssertTrue(message.label.contains("2 pagos"), "Se perdió el mensaje de siempre: «\(message.label)».")
    }

    private func scrollTo(_ element: XCUIElement, in app: XCUIApplication) {
        var attempts = 0
        while !(element.exists && element.isHittable) && attempts < 12 {
            app.swipeUp(velocity: .slow)
            attempts += 1
        }
        XCTAssertTrue(element.waitForExistence(timeout: 5), "No apareció \(element).")
    }
}
