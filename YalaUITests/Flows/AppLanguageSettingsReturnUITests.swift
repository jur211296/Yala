//
//  AppLanguageSettingsReturnUITests.swift
//  YalaUITests
//
//  UX 2.2 · L16-5 (opción B): con un solo idioma en el iPhone, «Idioma de la app» abre el selector de Yala. Al elegir
//  otro idioma la app se reconstruye y Ajustes tiene que volver a abrirse en Personalización, y después el botón de
//  Ajustes del Panel tiene que seguir abriendo la hoja.
//
//  Medido en el barrido de QA 2.2 (2026-10-24, card `tablero-tras-cambiar-el-idioma-desde-personaliza-6d71`): la app se
//  redibujaba en el idioma nuevo, Ajustes no volvía y el avatar del Panel ya no abría nada hasta cerrar Yala.
//
//  `launchForUITest` fija `-AppleLanguages (es)`: un solo idioma, así que la fila lleva al selector de Yala y no a iOS.
//

import XCTest

final class AppLanguageSettingsReturnUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_changingLanguage_reopensPersonalization_andSettingsButtonKeepsOpening() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "La app no señaló uitest_ready.")

        // Ida (español → inglés) y vuelta (inglés → español): el barrido lo reprodujo en las dos direcciones.
        app.openProfile()
        app.openSettingsSection("profile_personalization")
        changeLanguageFromPersonalization(app, to: "en", rowLabel: "App Language")
        closeSettingsAndReopenFromAvatar(app)
        app.openSettingsSection("profile_personalization")
        changeLanguageFromPersonalization(app, to: "es-419", rowLabel: "Idioma de la app")
        closeSettingsAndReopenFromAvatar(app)
    }

    /// Desde Personalización, elige `code` en el selector de Yala y comprueba que Ajustes vuelve solo, en
    /// Personalización y ya en el idioma nuevo.
    private func changeLanguageFromPersonalization(_ app: XCUIApplication, to code: String, rowLabel: String) {
        let row = app.buttons["personalization_row_app_language"]
        XCTAssertTrue(row.waitForExistence(timeout: 10), "No apareció «Idioma de la app» en Personalización.")
        row.tap()

        let option = app.buttons["app_language_option_\(code)"]
        XCTAssertTrue(option.waitForExistence(timeout: 10),
                      "Con un solo idioma en el iPhone, la fila no abrió el selector de Yala.")
        option.tap()

        // La reconstrucción cierra el selector y Ajustes; lo que tiene que quedar es Ajustes otra vez en Personalización,
        // con la fila ya traducida (prueba que es la hoja NUEVA y no la de antes del cambio).
        XCTAssertTrue(option.waitForNonExistence(timeout: 10), "El selector de idioma no se cerró tras elegir.")
        let translated = app.buttons.matching(NSPredicate(
            format: "identifier == 'personalization_row_app_language' AND label CONTAINS %@", rowLabel)).firstMatch
        XCTAssertTrue(translated.waitForExistence(timeout: 15),
                      "Tras elegir «\(code)», Ajustes no se reabrió en Personalización (queda el Panel).")
        XCTAssertTrue(translated.waitForHittable(timeout: 10),
                      "Personalización está en el árbol pero no delante: Ajustes no volvió a presentarse.")
    }

    /// Vuelve a la lista de Ajustes, la cierra con su X y vuelve a abrirla desde el avatar del Panel: es el botón que
    /// quedaba muerto. La X solo está en la raíz de Ajustes; desde Personalización se vuelve con «Atrás».
    private func closeSettingsAndReopenFromAvatar(_ app: XCUIApplication) {
        let close = app.buttons.matching(NSPredicate(format: "label IN %@", ["Cerrar", "Close"])).firstMatch
        let back = app.buttons["BackButton"].firstMatch
        for _ in 0..<3 where !close.waitForExistence(timeout: 2) {
            XCTAssertTrue(back.waitForExistence(timeout: 5), "Ni la X de Ajustes ni «Atrás» aparecieron.")
            back.tap()
        }
        XCTAssertTrue(close.waitForExistence(timeout: 10), "No apareció la X de Ajustes.")
        close.tap()

        let avatar = app.buttons["profile_avatar"]
        XCTAssertTrue(avatar.waitForExistence(timeout: 10))
        XCTAssertTrue(avatar.waitForHittable(timeout: 10), "Ajustes no se cerró: el avatar sigue tapado.")
        avatar.tap()
        XCTAssertTrue(app.buttons["profile_personalization"].waitForExistence(timeout: 10),
                      "El botón de Ajustes del Panel no abrió la hoja tras cambiar el idioma.")
    }
}
