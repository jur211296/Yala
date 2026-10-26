//
//  SegmentFilterChoiceUITests.swift
//  YalaUITests
//
//  Ticket `stats-filter-segment-tap-should-ask-include-or-exclude` (propuesta A de Jürgen, 2026-10-25): tocar un
//  segmento de Distribución pregunta «Ver solo X / Ocultar X» con «Cancelar» a la vista, y los dos tipos de filtro
//  conviven en la barra. Hasta ese día el toque escribía en el modo activo sin preguntar.
//  Entra por deeplink a Distribución (modo Detalle, la lista de categorías). Seed `realista`.
//

import XCTest

final class SegmentFilterChoiceUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launchOnDistribution() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "realista", deeplinkURL: "yaladev://statistics/categories")
        XCTAssertTrue(app.waitForUITestReady(timeout: 90), "uitest_ready ausente — bootstrap/seed no completó.")
        return app
    }

    /// Toca la primera fila que pregunta. «Sin categoría» no se puede filtrar y no pregunta: si está arriba, se salta.
    private func tapFirstFilterableCategory(_ app: XCUIApplication) {
        let rows = app.buttons.matching(identifier: "distribution_category_row")
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 20), "No apareció la lista de categorías de Distribución.")
        for index in 0..<min(rows.count, 4) {
            let row = rows.element(boundBy: index)
            XCTAssertTrue(row.waitForHittable(timeout: 5), "La fila \(index) no es alcanzable.")
            row.tap()
            if app.buttons["segment_filter_cancel"].waitForExistence(timeout: 3) { return }
        }
        XCTFail("Ninguna de las primeras categorías preguntó «Ver solo / Ocultar».")
    }

    private func appliedChips(_ app: XCUIApplication) -> XCUIElementQuery {
        app.buttons.matching(identifier: "applied_filter_chip")
    }

    /// Tocar una categoría pregunta; «Cancelar» se ve y no filtra nada.
    func test_tapCategory_asks_andCancelLeavesNoFilter() {
        let app = launchOnDistribution()
        tapFirstFilterableCategory(app)

        let showOnly = app.buttons["segment_filter_show_only"]
        let hide = app.buttons["segment_filter_hide"]
        let cancel = app.buttons["segment_filter_cancel"]
        XCTAssertTrue(showOnly.waitForExistence(timeout: 5), "Tocar la categoría no preguntó «Ver solo».")
        XCTAssertTrue(hide.exists, "La pregunta no ofrece «Ocultar».")
        XCTAssertTrue(cancel.exists, "La pregunta no tiene «Cancelar» a la vista.")
        XCTAssertTrue(app.staticTexts["segment_filter_title"].exists, "La pregunta no dice qué segmento es.")

        cancel.tap()
        XCTAssertTrue(showOnly.waitForNonExistence(timeout: 5), "«Cancelar» no cerró la pregunta.")
        XCTAssertFalse(appliedChips(app).firstMatch.waitForExistence(timeout: 2), "«Cancelar» dejó un filtro puesto.")
    }

    /// «Ocultar» una categoría y «Ver solo» otra: la barra enseña «Sin …» y «Solo …» a la vez.
    func test_hideOne_thenShowOnlyAnother_bothInTheBar() {
        let app = launchOnDistribution()

        tapFirstFilterableCategory(app)
        let hide = app.buttons["segment_filter_hide"]
        XCTAssertTrue(hide.waitForExistence(timeout: 5), "No preguntó.")
        let hiddenName = app.staticTexts["segment_filter_title"].label.components(separatedBy: " · ").first ?? ""
        hide.tap()
        XCTAssertTrue(hide.waitForNonExistence(timeout: 5), "«Ocultar» no cerró la pregunta.")

        let firstChip = appliedChips(app).firstMatch
        XCTAssertTrue(firstChip.waitForExistence(timeout: 10), "No apareció la cápsula de lo oculto.")
        XCTAssertTrue(firstChip.label.contains(hiddenName) && firstChip.label != hiddenName,
                      "La cápsula de lo oculto no dice «Sin \(hiddenName)»: \(firstChip.label)")

        // La oculta ya no está en la lista: la primera fila es otra categoría.
        tapFirstFilterableCategory(app)
        let showOnly = app.buttons["segment_filter_show_only"]
        XCTAssertTrue(showOnly.waitForExistence(timeout: 5), "La segunda categoría no preguntó.")
        let shownName = app.staticTexts["segment_filter_title"].label.components(separatedBy: " · ").first ?? ""
        XCTAssertNotEqual(shownName, hiddenName, "La categoría oculta seguía en la lista.")
        showOnly.tap()
        XCTAssertTrue(showOnly.waitForNonExistence(timeout: 5), "«Ver solo» no cerró la pregunta.")

        let deadline = Date().addingTimeInterval(10)
        while appliedChips(app).count < 2, Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        let labels = appliedChips(app).allElementsBoundByIndex.map(\.label)
        XCTAssertTrue(labels.contains { $0.contains(hiddenName) && $0 != hiddenName }, "Se perdió «Sin \(hiddenName)»: \(labels)")
        XCTAssertTrue(labels.contains { $0.contains(shownName) && $0 != shownName }, "Falta «Solo \(shownName)»: \(labels)")

        // Abrir Filtros y «Aplicar» sin tocar nada no puede cambiar el filtro: antes la hoja expandía las categorías a
        // sus subcategorías y «Sin Comida» volvía como N cápsulas de subcategorías.
        let chip = appliedChips(app).firstMatch
        XCTAssertTrue(chip.waitForHittable(timeout: 5), "La cápsula no es alcanzable.")
        chip.tap()
        let apply = app.buttons["filters_apply_button"]
        XCTAssertTrue(apply.waitForExistence(timeout: 5), "Tocar la cápsula no abrió Filtros.")
        apply.tap()
        XCTAssertTrue(apply.waitForNonExistence(timeout: 5), "«Aplicar» no cerró Filtros.")
        let after = appliedChips(app).allElementsBoundByIndex.map(\.label)
        XCTAssertEqual(Set(after), Set(labels), "Aplicar sin cambios alteró las cápsulas: \(labels) → \(after)")
    }
}
