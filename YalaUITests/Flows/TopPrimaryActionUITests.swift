//
//  TopPrimaryActionUITests.swift
//  YalaUITests
//
//  El patrón del Panel en las demás páginas principales (card kzhe, Jürgen 2026-10-24): la acción principal es un
//  botón arriba, bajo la cabecera, y el «+» flotante solo sale cuando el scroll se lleva ese botón. Lo decide
//  `revealsFloatingActionWhenScrolledAway` (`Views/Shared/TopPrimaryAction.swift`).
//
//  Cada caso afirma las dos mitades: arriba, botón alcanzable y SIN flotante; tras bajar, flotante alcanzable. La
//  primera cae si el flotante vuelve a ser fijo; la segunda, si el botón de arriba se queda sin quien encienda el
//  flotante. Seed `realista` y Pro: hace falta contenido para desplazar y que el límite de presupuestos no salte.
//

import XCTest

final class TopPrimaryActionUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Baja hasta que `top` deja de verse y devuelve si `floating` llegó a ser alcanzable.
    private func scrollUntilFloatingShows(_ app: XCUIApplication, top: XCUIElement, floating: XCUIElement) -> Bool {
        var swipes = 0
        while !floating.isHittable && swipes < 10 {
            app.swipeUp()
            swipes += 1
        }
        return floating.waitForHittable(timeout: 5)
    }

    func test_budgets_newButtonOnTop_floatingOnlyAfterScrolling() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "realista", deeplink: "budgets")
        XCTAssertTrue(app.waitForUITestReady(timeout: 90), "uitest_ready ausente — bootstrap/seed no completó.")

        let top = app.buttons["budgets_create_button"]
        XCTAssertTrue(top.waitForExistence(timeout: 15), "Falta «Nuevo presupuesto» arriba (budgets_create_button).")
        XCTAssertTrue(top.waitForHittable(timeout: 5), "«Nuevo presupuesto» no es alcanzable arriba.")
        let floating = app.buttons["budgets_create_fab"]
        XCTAssertFalse(floating.exists, "Con «Nuevo presupuesto» a la vista, el «+» flotante sobra: volvió a ser fijo.")

        // Jürgen, 2026-10-28 (card ca00): el selector de tipo (Semanal / Mensual / Anual / Único) es la píldora de
        // calendario de las demás pantallas, en la MISMA fila que «Nuevo presupuesto» y a su derecha; arranca en Mensual.
        // Debajo, el navegador del período.
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "presupuestos-nuevo-arriba"
        shot.lifetime = .keepAlways
        add(shot)
        let picker = app.buttons["budgets_period_type_picker"]
        let period = app.descendants(matching: .any)["period_navigation_label"].firstMatch
        XCTAssertTrue(picker.exists && period.exists, "Control: el selector de tipo y el período se ven.")
        XCTAssertFalse(app.segmentedControls["budgets_period_type_picker"].exists,
                       "Volvió el segmento de cuatro opciones a lo ancho.")
        XCTAssertEqual(picker.frame.midY, top.frame.midY, accuracy: 2,
                       "El selector de tipo no está a la altura de «Nuevo presupuesto».")
        XCTAssertGreaterThan(picker.frame.minX, top.frame.maxX, "El selector de tipo va a la derecha de «Nuevo presupuesto».")
        XCTAssertLessThan(picker.frame.maxY, period.frame.minY, "El selector de tipo va encima del navegador del período.")
        XCTAssertEqual(picker.value as? String, "Mensual", "El selector de tipo no arranca en Mensual.")

        XCTAssertTrue(
            scrollUntilFloatingShows(app, top: top, floating: floating),
            "Al bajar, el «+» flotante de Presupuestos no apareció.")
    }

    func test_statistics_actionsRowOnTop_floatingOnlyAfterScrolling() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "realista", deeplink: "statistics")
        XCTAssertTrue(app.waitForUITestReady(timeout: 90), "uitest_ready ausente — bootstrap/seed no completó.")

        let top = app.buttons["stats_action_new"]
        XCTAssertTrue(top.waitForExistence(timeout: 15), "Falta «Nuevo registro» bajo el hero (stats_action_new).")
        XCTAssertTrue(top.waitForHittable(timeout: 5), "«Nuevo registro» no es alcanzable bajo el hero.")
        let floating = app.buttons["fab_new_transaction"]
        XCTAssertFalse(floating.exists, "Con la fila a la vista, el «+» flotante sobra: volvió a ser fijo.")

        XCTAssertTrue(
            scrollUntilFloatingShows(app, top: top, floating: floating),
            "Al bajar, el «+» flotante de Estadísticas no apareció.")
    }
}
