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

        // Jürgen, 2026-10-28 (card 91in): «Nuevo presupuesto» va ENCIMA del selector de tipo (Semanal / Mensual / Anual /
        // Único), no entre él y el navegador del período (Nuevo › selector de tipo › período).
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "presupuestos-nuevo-arriba"
        shot.lifetime = .keepAlways
        add(shot)
        let picker = app.descendants(matching: .any)["budgets_period_type_picker"].firstMatch
        let period = app.descendants(matching: .any)["period_navigation_label"].firstMatch
        XCTAssertTrue(picker.exists && period.exists, "Control: el selector de tipo y el período se ven.")
        XCTAssertLessThan(top.frame.maxY, picker.frame.minY, "«Nuevo presupuesto» va encima del selector de tipo.")
        XCTAssertLessThan(picker.frame.maxY, period.frame.minY, "El selector de tipo va encima del navegador del período.")

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
