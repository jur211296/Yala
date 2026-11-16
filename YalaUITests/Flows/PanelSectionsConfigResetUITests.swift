//
//  PanelSectionsConfigResetUITests.swift
//  YalaUITests
//
//  Mejoras necesarias 2.3 · Panel (PN-8 de la revisión por vistas): «Configurar Panel» abre con tres botones redondos
//  sin texto. ↻ devolvía las secciones a su orden original sin preguntar, y ✓ se anunciaba como «Guardar» aunque solo
//  cierra (los cambios ya se aplicaron al tocarlos). Desde el arreglo, los mismos iconos en el mismo sitio dicen lo que
//  hacen a VoiceOver, y ↻ pregunta antes: «Cancelar» deja el orden como estaba y «Restablecer» lo devuelve.
//
//  El orden de partida se cambia con la propia hoja ↕, como lo haría una persona: Planificación encima de Tendencias, al
//  revés que el original. Así «Cancelar» y «Restablecer» dan órdenes distintos y el caso discrimina. No vale fijarlo con
//  `-panelSectionsOrder` al lanzar: ese valor vive en el dominio de argumentos, y en cuanto la app escribe una
//  preferencia `AppPreferences` recarga de `UserDefaults` y el argumento vuelve a ganar (medido: el restablecer «no
//  hacía nada»).
//
//  Scheme Yala Dev.
//

import XCTest

final class PanelSectionsConfigResetUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_reset_asksFirst_cancelKeepsTheOrder_andConfirmRestoresIt() {
        let app = XCUIApplication()
        app.launchForUITest()
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")

        let config = app.buttons["panel_sections_config"].firstMatch
        XCTAssertTrue(config.waitForExistence(timeout: 15), "No aparece «Configurar Panel» (panel_sections_config).")
        config.tap()

        let reset = app.buttons["panel_sections_config_reset"].firstMatch
        let reorder = app.buttons["panel_sections_config_reorder"].firstMatch
        let done = app.buttons["toolbar_save_button"].firstMatch
        XCTAssertTrue(reset.waitForExistence(timeout: 10), "No aparece ↻ en «Configurar Panel».")
        XCTAssertTrue(reorder.exists && done.exists, "Faltan ↕ o ✓ en «Configurar Panel».")

        // Nombres accesibles: dicen lo que hace cada icono.
        XCTAssertEqual(reset.label, "Restablecer el orden original")
        XCTAssertEqual(reorder.label, "Reordenar")
        XCTAssertEqual(done.label, "Listo", "El ✓ cierra (los cambios ya se aplicaron): no es «Guardar».")

        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "configurar-panel"
        shot.lifetime = .keepAlways
        add(shot)

        // A media altura la lista solo monta las filas visibles y Planificación queda debajo: hoja grande (molde de
        // `PanelDashboardUITests`).
        app.swipeUp()
        XCTAssertEqual(planningIsAboveTrends(app), false, "De fábrica, Tendencias va encima de Planificación.")
        movePlanningAboveTrends(app, reorder: reorder)
        XCTAssertEqual(planningIsAboveTrends(app), true, "Tras ordenar con ↕, Planificación tenía que ir arriba.")

        // ↻ pregunta, y «Cancelar» no cambia nada.
        reset.tap()
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "↻ restableció sin preguntar.")
        let askShot = XCTAttachment(screenshot: app.screenshot())
        askShot.name = "configurar-panel-pregunta"
        askShot.lifetime = .keepAlways
        add(askShot)
        alert.buttons["Cancelar"].firstMatch.tap()
        XCTAssertTrue(alert.waitForNonExistence(timeout: 5), "La pregunta no se cerró con «Cancelar».")
        XCTAssertEqual(planningIsAboveTrends(app), true, "«Cancelar» restableció el orden igualmente.")

        // ↻ y «Restablecer»: el orden original vuelve (Tendencias arriba).
        reset.tap()
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "La segunda vez ↻ no preguntó.")
        alert.buttons["Restablecer"].firstMatch.tap()
        XCTAssertTrue(alert.waitForNonExistence(timeout: 5), "La pregunta no se cerró con «Restablecer».")
        let restored = NSPredicate { _, _ in self.planningIsAboveTrends(app) == false }
        XCTAssertEqual(XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: restored, object: nil)], timeout: 5),
                       .completed, "«Restablecer» no devolvió el orden original.")
    }

    /// Con la hoja ↕: arrastra el asa de Planificación hasta encima de Tendencias y vuelve a «Configurar Panel».
    private func movePlanningAboveTrends(_ app: XCUIApplication, reorder: XCUIElement) {
        reorder.tap()
        let planningRow = app.descendants(matching: .any)["panel_sections_reorder_row_planificacion"].firstMatch
        let trendsRow = app.descendants(matching: .any)["panel_sections_reorder_row_tendencias"].firstMatch
        XCTAssertTrue(planningRow.waitForExistence(timeout: 5) && trendsRow.exists, "No se abrió la hoja de ordenar.")
        // El asa va al final de la CELDA, fuera del contenido que lleva el id: se agarra junto a su borde derecho (en el
        // iPad la hoja va centrada y el borde de la ventana cae fuera).
        let window = app.windows.firstMatch
        let cell = app.cells.containing(.any, identifier: "panel_sections_reorder_row_planificacion").firstMatch
        XCTAssertTrue(cell.exists, "No aparece la celda de Planificación en la hoja de ordenar.")
        let handleX = cell.frame.maxX - 30
        func handle(_ row: XCUIElement, dy: CGFloat) -> XCUICoordinate {
            window.coordinate(withNormalizedOffset: .zero)
                .withOffset(CGVector(dx: handleX, dy: row.frame.minY + row.frame.height * dy))
        }
        handle(planningRow, dy: 0.5).press(forDuration: 0.8, thenDragTo: handle(trendsRow, dy: -0.4))
        let moved = NSPredicate { _, _ in planningRow.frame.minY < trendsRow.frame.minY }
        XCTAssertEqual(XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: moved, object: nil)], timeout: 5),
                       .completed, "El arrastre no subió Planificación encima de Tendencias.")
        let done = app.buttons["panel_sections_reorder_done"].firstMatch
        XCTAssertTrue(done.exists, "Falta el ✓ de la hoja de ordenar.")
        done.tap()
        XCTAssertTrue(done.waitForNonExistence(timeout: 5), "La hoja de ordenar no se cerró.")
    }

    /// `nil` si alguna de las dos filas no está: así un «no está encima» no puede salir de una fila que falta.
    private func planningIsAboveTrends(_ app: XCUIApplication) -> Bool? {
        let planning = app.descendants(matching: .any)["panel_section_toggle_planificacion"].firstMatch
        let trends = app.descendants(matching: .any)["panel_section_toggle_tendencias"].firstMatch
        guard planning.exists, trends.exists else { return nil }
        return planning.frame.minY < trends.frame.minY
    }
}
