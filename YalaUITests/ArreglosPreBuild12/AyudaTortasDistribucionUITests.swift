//
//  AyudaTortasDistribucionUITests.swift
//  YalaUITests
//
//  Estadísticas › Distribución › Gráficas: el «?» de las tortas de categorías, subcategorías y etiquetas (hallazgo del
//  PR «Textos del reparto», 27-nov-2026). Medido en la base ese día: el botón existía y abría su hoja, pero el
//  `accessibilityIdentifier` de la página del carrusel (`distribution_page_*`) pisaba el suyo, así que salía como
//  `distribution_page_category` y no como `widget_info_categoriesPie`: buscado por su id, «no estaba». Desde el arreglo,
//  cada página es un contenedor de accesibilidad con su id y lo de dentro conserva el suyo.
//
//  Lo que fija: el «?» de cada torta es un BOTÓN con su etiqueta y su id (lo que VoiceOver lee y lo que XCUITest
//  encuentra), se puede tocar, abre SU hoja de ayuda y no dispara el toque de la tarjeta ni el de la torta (ni el
//  detalle de la categoría ni un filtro). Y la página sigue encontrándose por su id, como la buscan otras pruebas.
//

import XCTest

final class AyudaTortasDistribucionUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func launchDistributionCharts() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(seed: "realista", deeplink: "statistics", extraArguments: ["-defaultPeriod", "thisYear"])
        XCTAssertTrue(app.waitForUITestReady(timeout: 90), "uitest_ready ausente — bootstrap/seed no completó.")
        let chip = app.buttons["detail_chip_categorías"]
        XCTAssertTrue(chip.waitForExistence(timeout: 10), "El chip Distribución no apareció.")
        chip.tap()
        let modes = app.buttons.matching(identifier: "distribution_content_mode")
        XCTAssertTrue(modes.element(boundBy: 1).waitForExistence(timeout: 10), "Falta «Gráficas».")
        modes.element(boundBy: 1).tap()
        XCTAssertTrue(element(app, "distribution_page_category").waitForExistence(timeout: 10),
                      "No está la página de categorías del carrusel.")
        return app
    }

    /// Espera a que el centro del elemento quede dentro de la ventana (el carrusel se desliza).
    private func waitUntilOnScreen(_ app: XCUIApplication, _ target: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let window = app.windows.firstMatch.frame
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if target.exists, window.contains(CGPoint(x: target.frame.midX, y: target.frame.midY)) { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return false
    }

    /// Sube la página hasta la franja central con arrastres cortos por el margen derecho (fuera de las tarjetas).
    private func bringToCenter(_ app: XCUIApplication, _ target: XCUIElement) {
        let window = app.windows.firstMatch.frame
        let band = (window.height * 0.25)...(window.height * 0.6)
        let low = app.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.7))
        let high = app.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.45))
        for _ in 0..<10 {
            if target.exists, band.contains(target.frame.midY) { return }
            if target.exists, target.frame.midY < band.lowerBound {
                high.press(forDuration: 0.05, thenDragTo: low, withVelocity: .slow, thenHoldForDuration: 0.2)
            } else {
                low.press(forDuration: 0.05, thenDragTo: high, withVelocity: .slow, thenHoldForDuration: 0.2)
            }
        }
    }

    /// El «?» de la torta: botón con etiqueta e id propios, se toca, abre su ayuda y nada más.
    private func assertHelpButton(_ app: XCUIApplication, id: String, page: String,
                                  file: StaticString = #filePath, line: UInt = #line) {
        let info = app.buttons[id].firstMatch
        XCTAssertTrue(info.waitForExistence(timeout: 5),
                      "El «?» de \(page) no está en el árbol con su id (\(id)).", file: file, line: line)
        XCTAssertEqual(info.elementType, .button, "El «?» de \(page) no es un botón para VoiceOver.", file: file, line: line)
        XCTAssertFalse(info.label.isEmpty, "El «?» de \(page) no tiene etiqueta.", file: file, line: line)
        XCTAssertNotEqual(info.label, "?", "El «?» de \(page) se lee como un signo suelto.", file: file, line: line)
        XCTAssertTrue(waitUntilOnScreen(app, info), "El «?» de \(page) no quedó a la vista: \(info.frame).",
                      file: file, line: line)
        XCTAssertTrue(info.isHittable, "El «?» de \(page) no se puede tocar.", file: file, line: line)

        info.tap()
        let close = app.buttons["widget_info_close"].firstMatch
        XCTAssertTrue(close.waitForExistence(timeout: 5), "Tocar el «?» de \(page) no abrió su ayuda.",
                      file: file, line: line)
        XCTAssertFalse(element(app, "stats_category_detail").exists,
                       "Tocar el «?» de \(page) abrió el detalle de una categoría.", file: file, line: line)
        close.tap()
        XCTAssertTrue(close.waitForNonExistence(timeout: 5), "La ayuda de \(page) no se cerró.", file: file, line: line)
        XCTAssertFalse(element(app, "stats_category_detail").exists,
                       "Tras cerrar la ayuda de \(page) quedó abierto el detalle de una categoría.", file: file, line: line)
        XCTAssertFalse(app.buttons["filter_band_remove_all"].exists,
                       "Tocar el «?» de \(page) puso un filtro.", file: file, line: line)
    }

    func test_distributionCharts_helpButtonOfEachPie_isAButtonThatOpensItsHelp() {
        let app = launchDistributionCharts()
        let category = element(app, "distribution_page_category")
        bringToCenter(app, category)
        assertHelpButton(app, id: "widget_info_categoriesPie", page: "categorías")

        // La página se sigue encontrando por su id (como la buscan otras pruebas) y el carrusel se desliza desde ella.
        category.swipeLeft()
        let subcategory = element(app, "distribution_page_subcategory")
        XCTAssertTrue(waitUntilOnScreen(app, subcategory), "El carrusel no pasó a subcategorías.")
        assertHelpButton(app, id: "widget_info_subcategoriesPie", page: "subcategorías")

        // En el iPad las etiquetas van fuera del carrusel, junto a Necesidades; en el iPhone, en su tercera página.
        if UIDevice.current.userInterfaceIdiom == .phone {
            subcategory.swipeLeft()
            XCTAssertTrue(waitUntilOnScreen(app, element(app, "distribution_page_tags")),
                          "El carrusel no pasó a etiquetas.")
        }
        assertHelpButton(app, id: "widget_info_tagsPie", page: "etiquetas")
    }
}
