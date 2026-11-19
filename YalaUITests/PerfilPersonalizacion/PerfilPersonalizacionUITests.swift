//
//  PerfilPersonalizacionUITests.swift
//  YalaUITests
//
//  Perfil con personalización de verdad (2026-11-18): en «Detalles personales» la tarjeta de perfil enseña lo que se
//  elige (emoji, color del avatar y fondo), se guarda al cerrar y vuelve al abrir otra vez; «Volver al perfil de siempre»
//  lo deshace; las iniciales salen del nombre. Seed `minimal`, scheme Yala Dev, ids y no textos.
//
//  Con la pantalla de antes (icono en un círculo y una rejilla de 12 símbolos) cae en el primer `waitForExistence` de la
//  tarjeta.
//

import XCTest

final class PerfilPersonalizacionUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func openPersonalDetails(extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(extraArguments: extraArguments)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        app.openProfile()
        // Ajustes enseña el perfil como tarjeta (decisión de Jürgen del 18-nov).
        XCTAssertTrue(app.descendants(matching: .any)["profile_header_card"].waitForExistence(timeout: 5),
                      "La cabecera de Ajustes no es la tarjeta de perfil.")
        reopen(app)
        return app
    }

    private func reopen(_ app: XCUIApplication) {
        let edit = app.buttons["profile_edit_button"]
        XCTAssertTrue(edit.waitForHittable(timeout: 5), "No apareció «Editar perfil» en Ajustes.")
        edit.tap()
        XCTAssertTrue(app.buttons["personal_details_done"].waitForExistence(timeout: 5), "No se abrió «Detalles personales».")
        XCTAssertTrue(app.descendants(matching: .any)["profile_card"].waitForExistence(timeout: 5),
                      "«Detalles personales» no enseña la tarjeta de perfil.")
    }

    private func close(_ app: XCUIApplication) {
        app.buttons["personal_details_done"].tap()
        XCTAssertTrue(app.buttons["profile_edit_button"].waitForHittable(timeout: 5), "«Listo» no volvió a Ajustes.")
    }

    /// Sube el contenido hasta que el elemento quede a media pantalla, donde ningún toque cae bajo la barra.
    private func bringIntoView(_ element: XCUIElement, in app: XCUIApplication) {
        let window = app.windows.firstMatch.frame
        for _ in 0..<8 {
            if element.exists, element.frame.midY < window.maxY - 160, element.frame.midY > window.minY + 200 { return }
            app.swipeUp(velocity: .slow)
        }
    }

    private func tapSelecting(_ element: XCUIElement, in app: XCUIApplication, _ what: String) {
        bringIntoView(element, in: app)
        XCTAssertTrue(element.waitForExistence(timeout: 5), "No está \(what).")
        element.tap()
        XCTAssertTrue(element.isSelected, "Tocar \(what) no lo eligió.")
    }

    /// El recorrido entero: emoji + color + fondo → «Listo» → al volver a abrir está todo como se dejó. Y «Volver al
    /// perfil de siempre» lo deshace también tras cerrar.
    func test_personalize_emojiColorAndBackground_isKeptAfterReopening() {
        let app = openPersonalDetails()

        tapSelecting(app.buttons["profile_tab_emoji"], in: app, "la pestaña Emoji")
        tapSelecting(app.buttons["profile_emoji_2"], in: app, "el tercer emoji")
        tapSelecting(app.buttons["profile_color_0"], in: app, "el primer color del avatar")
        XCTAssertFalse(app.buttons["profile_color_theme"].isSelected, "«Del tema» siguió elegido con otro color.")
        tapSelecting(app.buttons["profile_card_template_aurora"], in: app, "el fondo «Aurora»")
        XCTAssertFalse(app.buttons["profile_card_template_account"].isSelected, "«Tu color» siguió elegido.")

        close(app)
        reopen(app)

        XCTAssertTrue(app.buttons["profile_tab_emoji"].isSelected, "No volvió a abrir en la pestaña del emoji.")
        XCTAssertTrue(app.buttons["profile_emoji_2"].isSelected, "No se guardó el emoji.")
        let color = app.buttons["profile_color_0"]
        bringIntoView(color, in: app)
        XCTAssertTrue(color.isSelected, "No se guardó el color del avatar.")
        let aurora = app.buttons["profile_card_template_aurora"]
        bringIntoView(aurora, in: app)
        XCTAssertTrue(aurora.isSelected, "No se guardó el fondo de la tarjeta.")

        let reset = app.buttons["profile_reset"]
        bringIntoView(reset, in: app)
        XCTAssertTrue(reset.waitForExistence(timeout: 5), "No aparece «Volver al perfil de siempre» con algo cambiado.")
        reset.tap()
        XCTAssertFalse(reset.waitForExistence(timeout: 1), "«Volver al perfil de siempre» sigue con todo de serie.")

        close(app)
        reopen(app)
        XCTAssertTrue(app.buttons["profile_tab_symbol"].isSelected, "Tras volver al de siempre no abrió en Símbolo.")
        XCTAssertTrue(app.buttons["profile_symbol_person.fill"].isSelected, "El símbolo de siempre no está elegido.")
        let theme = app.buttons["profile_color_theme"]
        bringIntoView(theme, in: app)
        XCTAssertTrue(theme.isSelected, "El color no volvió al del tema.")
    }

    /// Sin nombre no hay iniciales: la pestaña lo dice. Con nombre, las ofrece y se pueden elegir.
    func test_initials_comeFromTheName() {
        let sinNombre = openPersonalDetails()
        sinNombre.buttons["profile_tab_initials"].tap()
        XCTAssertTrue(sinNombre.descendants(matching: .any)["profile_initials_need_name"].waitForExistence(timeout: 5),
                      "Sin nombre no dice que hay que escribirlo.")
        XCTAssertFalse(sinNombre.buttons["profile_initials_choice"].exists)
        sinNombre.terminate()

        let conNombre = openPersonalDetails(extraArguments: ["-userName", "Ada Lovelace"])
        conNombre.buttons["profile_tab_initials"].tap()
        let choice = conNombre.buttons["profile_initials_choice"]
        XCTAssertTrue(choice.waitForExistence(timeout: 5), "Con nombre no ofrece las iniciales.")
        XCTAssertEqual(choice.label, "AL")
        choice.tap()
        XCTAssertTrue(choice.isSelected, "Tocar las iniciales no las eligió.")
    }
}
