//
//  SettingsLote16UITests.swift
//  YalaUITests
//
//  Auditoría UX 2.2, lote 16 (Ajustes: perfil y preferencias). Bugs que se ven en pantalla:
//  - cerrar «Detalles personales» deslizando hacia abajo perdía el nombre recién escrito;
//  - «Contacta con nosotros» se cerraba sin app de correo y lo escrito se perdía;
//  - cerrar sin elegir el diálogo de variante de «Traslúcido» dejaba el tema puesto;
//  - el pie de Ajustes decía «Versión 1.0.0 (Build 1)» en cualquier versión.
//  Seed `minimal`, scheme Yala Dev.
//

import XCTest

final class SettingsLote16UITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func scrollTo(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        let element = app.buttons[identifier]
        var tries = 0
        while !(element.exists && element.isHittable) && tries < 14 {
            app.swipeUp()
            tries += 1
        }
        return element
    }

    /// Cerrar la hoja deslizando guarda el nombre, igual que el botón de atrás.
    func test_personalDetails_swipeDown_keepsTheNewName() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        app.openProfile()

        let edit = app.buttons["profile_edit_button"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5), "No apareció «Editar perfil».")
        edit.tap()

        let field = app.textFields["personal_details_name_field"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "No apareció el campo Nombre.")
        // El campo va alineado a la derecha: tocar su centro deja el cursor delante del texto. Se toca el final.
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.5)).tap()
        let current = (field.value as? String) ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count + 2))
        field.typeText("Lucia QA")
        XCTAssertEqual(field.value as? String, "Lucia QA", "El campo no tomó el nombre nuevo.")

        // Cierra la hoja deslizando desde su borde de arriba, sin pasar por el botón de atrás. No vale
        // `navigationBars.firstMatch`: es la barra de «Perfil», la hoja de debajo.
        let sheetTop = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.09))
        sheetTop.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.98)))

        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: field)
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 5), .completed, "La hoja de Detalles personales no se cerró.")
        XCTAssertTrue(app.buttons["profile_edit_button"].waitForHittable(timeout: 5), "No se volvió a Ajustes.")
        XCTAssertTrue(
            app.staticTexts["Lucia QA"].waitForExistence(timeout: 5),
            "El nombre escrito se perdió al cerrar la hoja deslizando."
        )
    }

    /// Sin app de correo, el formulario no se cierra: avisa, ofrece copiar y conserva lo escrito.
    func test_support_withoutMailApp_keepsTheMessage() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        app.openProfile()

        let contact = scrollTo(app, "profile_help_contact")
        XCTAssertTrue(contact.waitForExistence(timeout: 5), "No apareció «Contacta con nosotros».")
        contact.tap()

        let field = app.textFields["support_message_field"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "No apareció el campo del mensaje.")
        field.tap()
        field.typeText("La grafica no carga")

        let send = app.buttons["support_send_button"]
        XCTAssertTrue(send.waitForHittable(timeout: 5), "«Enviar» no se puede tocar.")
        send.tap()

        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "Sin app de correo no salió ningún aviso.")
        XCTAssertGreaterThanOrEqual(alert.buttons.count, 2, "El aviso no ofrece copiar el mensaje.")
        alert.buttons.element(boundBy: alert.buttons.count - 1).tap()

        XCTAssertTrue(field.waitForExistence(timeout: 5), "El formulario se cerró y lo escrito se perdió.")
        XCTAssertEqual(field.value as? String, "La grafica no carga", "El mensaje escrito no se conservó.")
    }

    /// Tocar «Traslúcido» abre el diálogo de variante; cerrarlo sin elegir deja el tema que había.
    func test_translucentTheme_closingTheVariantDialog_keepsThePreviousTheme() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        app.openProfile()

        let themeRow = scrollTo(app, "profile_theme")
        XCTAssertTrue(themeRow.waitForExistence(timeout: 5), "No apareció la fila Temas.")
        themeRow.tap()

        // El tema elegido antes de tocar nada (el que lleve la marca de seleccionado).
        let cards = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'theme_card_'"))
        XCTAssertTrue(cards.firstMatch.waitForExistence(timeout: 5), "No aparecieron los temas.")
        let selectedBefore = cards.allElementsBoundByIndex.first { $0.isSelected }?.identifier
        XCTAssertNotNil(selectedBefore, "Ningún tema sale marcado como elegido.")
        XCTAssertNotEqual(selectedBefore, "theme_card_7", "El escenario ya empieza en Traslúcido: no discrimina.")

        let translucent = app.buttons["theme_card_7"]
        var tries = 0
        while !(translucent.exists && translucent.isHittable) && tries < 6 {
            app.swipeUp()
            tries += 1
        }
        XCTAssertTrue(translucent.isHittable, "No se alcanza la tarjeta Traslúcido.")
        translucent.tap()

        // Cierra el diálogo tocando fuera, como haría la persona (iOS 26 no pinta «Cancelar» en un diálogo anclado).
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12)).tap()

        XCTAssertTrue(app.buttons[selectedBefore ?? ""].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["theme_card_7"].isSelected, "Cerrar el diálogo sin elegir dejó puesto Traslúcido.")
        XCTAssertTrue(app.buttons[selectedBefore ?? ""].isSelected, "El tema de antes dejó de estar elegido.")
    }

    /// El pie de Ajustes ya no es el texto fijo de 1.0.0.
    func test_versionFooter_isNotTheOldFixedText() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        app.openProfile()

        let footer = app.staticTexts["profile_version_footer"]
        var tries = 0
        while !footer.exists && tries < 14 {
            app.swipeUp()
            tries += 1
        }
        XCTAssertTrue(footer.waitForExistence(timeout: 5), "No apareció el pie con la versión.")
        XCTAssertFalse(footer.label.contains("1.0.0 (Build 1)"), "El pie sigue con el texto fijo: \(footer.label)")
    }
}
