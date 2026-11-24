//
//  PresupuestoGuiadoSubcategoriasUITests.swift
//  YalaUITests
//
//  «Nuevo presupuesto» por pasos, paso «¿Cuáles?» (pedido de Jürgen del 23-nov): al tocar una categoría salen debajo sus
//  subcategorías, todas marcadas; desmarcar una la quita y desmarcarlas todas desmarca la categoría. Deja una foto del
//  paso con una categoría tocada y una subcategoría quitada, en oscuro (el tema de siempre) y en claro.
//

import XCTest

final class PresupuestoGuiadoSubcategoriasUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_tocarCategoria_muestraSusSubcategorias_yDesmarcarlasTodasLaDesmarca() {
        let app = abrirCuales()
        let circulos = app.buttons.matching(identifier: "asistente_presupuesto_subcategoria")
        XCTAssertEqual(circulos.count, 0, "Sin categoría elegida no hay subcategorías debajo.")

        let tile = app.buttons.matching(identifier: "asistente_presupuesto_categoria").firstMatch
        tile.tap()
        XCTAssertTrue(circulos.firstMatch.waitForExistence(timeout: 5), "Al tocar la categoría no salieron sus subcategorías.")
        subirLasSubcategorias(app)
        let total = circulos.count
        XCTAssertGreaterThan(total, 0)
        for indice in 0..<total {
            XCTAssertTrue(circulos.element(boundBy: indice).isSelected, "La subcategoría \(indice) no llega marcada.")
        }
        XCTAssertTrue(app.buttons["asistente_next"].isEnabled)

        // Desmarcar una: se queda a la vista, sin marcar, y la categoría sigue elegida.
        circulos.element(boundBy: 0).tap()
        XCTAssertFalse(circulos.element(boundBy: 0).isSelected, "Tocar la subcategoría no la desmarcó.")
        XCTAssertTrue(tile.isSelected, "Con subcategorías marcadas, la categoría tiene que seguir elegida.")

        // Desmarcar las demás: la categoría se desmarca y sus subcategorías se van.
        for indice in 1..<total { circulos.element(boundBy: indice).tap() }
        XCTAssertTrue(esperar(circulos, cuenta: 0), "Sin subcategorías marcadas, el bloque no se fue.")
        XCTAssertFalse(tile.isSelected, "Sin subcategorías marcadas, la categoría siguió elegida.")
        XCTAssertFalse(app.buttons["asistente_next"].isEnabled, "Sin nada elegido, «Siguiente» va apagado.")
    }

    func test_capturas_unaCategoriaConUnaSubcategoriaQuitada() {
        for (nombre, extra) in [("oscuro", [String]()), ("claro", ["-userTheme", "1"])] {
            let app = abrirCuales(extra: extra)
            app.buttons.matching(identifier: "asistente_presupuesto_categoria").firstMatch.tap()
            let circulos = app.buttons.matching(identifier: "asistente_presupuesto_subcategoria")
            XCTAssertTrue(circulos.firstMatch.waitForExistence(timeout: 5))
            subirLasSubcategorias(app)
            if circulos.count > 1 { circulos.element(boundBy: 1).tap() }
            Thread.sleep(forTimeInterval: 0.45)
            let shot = XCTAttachment(screenshot: app.screenshot())
            shot.name = "cuales-\(nombre)"
            shot.lifetime = .keepAlways
            add(shot)
            app.terminate()
        }
    }

    // MARK: - Ayudas

    private func abrirCuales(extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "realista", deeplink: "budgets", extraArguments: extra)
        XCTAssertTrue(app.waitForUITestReady(timeout: 90), "uitest_ready ausente — bootstrap/seed no completó.")
        let crear = app.buttons["budgets_create_button"]
        XCTAssertTrue(crear.waitForExistence(timeout: 15), "No apareció «Nuevo presupuesto».")
        crear.tap()
        let categorias = app.buttons["asistente_presupuesto_alcance_categorias"]
        XCTAssertTrue(categorias.waitForExistence(timeout: 5), "«Nuevo presupuesto» no abrió el asistente.")
        categorias.tap()
        app.buttons["asistente_next"].tap()
        XCTAssertTrue(app.buttons.matching(identifier: "asistente_presupuesto_categoria").firstMatch
            .waitForExistence(timeout: 5), "No llegó «¿Cuáles?».")
        return app
    }

    /// Las subcategorías salen debajo de la rejilla y pueden quedar bajo la barra de «Siguiente», donde el toque caería en
    /// ella (`testing.md`): se sube el scroll hasta el final antes de tocarlas.
    private func subirLasSubcategorias(_ app: XCUIApplication) {
        let scroll = app.scrollViews.firstMatch
        for _ in 0..<3 { scroll.swipeUp(velocity: .slow) }
        Thread.sleep(forTimeInterval: 0.4)
    }

    private func esperar(_ consulta: XCUIElementQuery, cuenta: Int) -> Bool {
        let predicado = NSPredicate(format: "count == %d", cuenta)
        let espera = expectation(for: predicado, evaluatedWith: consulta)
        return XCTWaiter.wait(for: [espera], timeout: 5) == .completed
    }
}
