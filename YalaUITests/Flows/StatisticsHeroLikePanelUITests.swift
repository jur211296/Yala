//
//  StatisticsHeroLikePanelUITests.swift
//  YalaUITests
//
//  El hero de Estadísticas es el del Panel en las cuatro pestañas y en todas las subvistas de Distribución, y lleva
//  los mismos flotantes (Yala IA y «+»). Ticket `distribution-subviews-miss-the-new-panel-hero`, decisión de Jürgen
//  del 2026-10-03.
//
//  Qué distingue el hero del Panel del de antes, en una medida: el rótulo de la cifra («Neto del período», «Saldo de
//  cuentas»…) va ARRIBA A LA IZQUIERDA, en el eje del resto de la pantalla, y no centrado bajo la cifra. Centrado, su
//  borde izquierdo caía a ~140 pt en un iPhone 17 Pro; alineado, a 16. El umbral de 40 pt separa los dos con margen
//  en cualquier iPhone y con el texto de accesibilidad.
//
//  Seed `minimal`, en Pro (los flotantes de voz e imagen no cambian nada aquí, pero así el chat no sale bloqueado).
//

import XCTest

final class StatisticsHeroLikePanelUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Lo que el hero tiene que cumplir en cada sitio: rótulo a la vista y a la izquierda, y los dos flotantes.
    private func assertPanelHero(_ app: XCUIApplication, in place: String, file: StaticString = #filePath, line: UInt = #line) {
        let caption = app.staticTexts["stats_hero_caption"]
        XCTAssertTrue(caption.waitForExistence(timeout: 15), "\(place): no se ve el rótulo del hero.", file: file, line: line)
        let leftEdge = app.windows.firstMatch.frame.minX
        XCTAssertLessThan(
            caption.frame.minX - leftEdge, 40,
            "\(place): el rótulo del hero (\(caption.frame)) no está a la izquierda como en el Panel: volvió la "
                + "cabecera centrada.",
            file: file, line: line)
        XCTAssertTrue(
            app.buttons["fab_new_transaction"].waitForExistence(timeout: 5),
            "\(place): falta «+» (fab_new_transaction), que en el Panel está siempre a mano.", file: file, line: line)
        XCTAssertTrue(
            app.buttons["fab_chat"].exists,
            "\(place): falta Yala IA (fab_chat) junto a «+».", file: file, line: line)
    }

    /// Una página del carrusel existe en el árbol aunque esté fuera de pantalla (el `LazyHStack` monta la vecina):
    /// lo que dice que el carrusel llegó a ella es que su centro caiga dentro de la ventana.
    private func waitUntilOnScreen(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            // Por el marco, no por `isHittable`: fuera de pantalla éste lanza en vez de contestar `false`.
            let window = XCUIApplication().windows.firstMatch.frame
            if element.exists, window.contains(CGPoint(x: element.frame.midX, y: element.frame.midY)) { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        return false
    }

    private func openChip(_ app: XCUIApplication, _ identifier: String) {
        let chip = app.buttons[identifier]
        XCTAssertTrue(chip.waitForExistence(timeout: 10), "No apareció el chip \(identifier).")
        // `isHittable` no vale aquí: con el chip fuera de pantalla no contesta `false`, lanza («Activation point
        // invalid»). Se mira el marco contra la ventana.
        let window = app.windows.firstMatch.frame
        if chip.frame.maxX > window.maxX || chip.frame.minX < window.minX {
            let chipsBar = app.scrollViews.containing(.button, identifier: "detail_chip_insights").firstMatch
            if chipsBar.exists { chipsBar.swipeLeft() }
        }
        chip.tap()
    }

    func test_statisticsHeroIsThePanelHero_inEveryTab() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        app.tabBars.buttons.element(boundBy: 1).tap()
        assertPanelHero(app, in: "Resumen")

        openChip(app, "detail_chip_tendencias")
        assertPanelHero(app, in: "Tendencias")

        openChip(app, "detail_chip_categorías")
        assertPanelHero(app, in: "Distribución")

        openChip(app, "detail_chip_registros")
        assertPanelHero(app, in: "Registros")
    }

    /// Distribución tiene un solo hero para el carrusel (categoría, subcategoría, etiquetas) y para Gráficas/Detalle:
    /// ninguna subvista lo sustituye ni lo oculta.
    func test_distributionSubviewsKeepThePanelHero() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true)
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        app.tabBars.buttons.element(boundBy: 1).tap()
        openChip(app, "detail_chip_categorías")
        assertPanelHero(app, in: "Distribución › categoría")

        let page: (String) -> XCUIElement = { id in
            app.descendants(matching: .any).matching(identifier: "distribution_page_\(id)").firstMatch
        }
        XCTAssertTrue(page("category").waitForExistence(timeout: 10), "No está la página de categorías del carrusel.")
        page("category").swipeLeft()
        XCTAssertTrue(waitUntilOnScreen(page("subcategory")), "El carrusel no pasó a subcategorías.")
        assertPanelHero(app, in: "Distribución › subcategoría")

        page("subcategory").swipeLeft()
        XCTAssertTrue(waitUntilOnScreen(page("tags")), "El carrusel no pasó a etiquetas.")
        assertPanelHero(app, in: "Distribución › etiquetas")

        // Los dos segmentos heredan el id del contenedor, en el orden Gráficas, Detalle.
        let modes = app.buttons.matching(identifier: "distribution_content_mode")
        XCTAssertEqual(modes.count, 2, "El selector Gráficas/Detalle no tiene dos segmentos.")
        modes.element(boundBy: 1).tap()
        assertPanelHero(app, in: "Distribución › Detalle")

        modes.element(boundBy: 0).tap()
        assertPanelHero(app, in: "Distribución › Gráficas")
    }
}
