//
//  LanguageSelectionUITests.swift
//  YalaUITests
//
//  «Elige tu idioma» cuando el idioma del iPhone no está entre los de Yala (auditoría UX 2.2, lote 1).
//
//  El bug que fija: la pantalla repartía el alto con `Spacer`s dentro de un `VStack`, sin scroll. Con los 14
//  idiomas seleccionables la columna medía más que la pantalla de un iPhone 17 Pro y el botón «Siguiente»
//  quedaba FUERA: ni se veía ni existía en el árbol de accesibilidad, así que quien tuviera el iPhone en
//  coreano, ruso o árabe no podía pasar de la primera pantalla. Medido en el simulador el 2026-10-13.
//
//  No usa `launchForUITest`: ese helper fija `-AppleLanguages (es)` para toda la suite, y aquí el sujeto es
//  justo un idioma que Yala no tiene. Y NO toca el botón: tocarlo guarda un idioma dentro de la app, que
//  sobreviviría a esta corrida. Que sea tocable es lo que el bug rompía.
//

import XCTest

final class LanguageSelectionUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testUnsupportedDeviceLanguage_nextButtonIsReachable() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uitest", "-uitest-reset",
            "-AppleLanguages", "(ko)", "-AppleLocale", "ko_KR"
        ]
        app.launch()

        // El último idioma de la lista: si la columna no cabe y no hay scroll, es el primero que se pierde.
        let lastLanguage = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "简体中文")).firstMatch
        XCTAssertTrue(lastLanguage.waitForExistence(timeout: 60),
                      "No apareció el selector de idioma con el iPhone en coreano.")

        let next = app.buttons["language_selection_next"]
        XCTAssertTrue(next.waitForExistence(timeout: 5),
                      "El botón «Siguiente» no existe: la lista de idiomas lo empujó fuera de la pantalla.")
        XCTAssertTrue(next.isHittable,
                      "El botón «Siguiente» existe pero no se puede tocar: la pantalla no tiene salida.")
    }
}
