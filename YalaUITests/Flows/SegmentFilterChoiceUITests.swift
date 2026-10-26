//
//  SegmentFilterChoiceUITests.swift
//  YalaUITests
//
//  Ticket `stats-filter-segment-tap-should-ask-include-or-exclude` (propuesta A de Jürgen, 2026-10-25): tocar un
//  segmento de Distribución pregunta «Ver solo X / Ocultar X» con «Cancelar» a la vista, y los dos tipos de filtro
//  conviven en la barra. Hasta ese día el toque escribía en el modo activo sin preguntar.
//  Desde el 2026-10-26 (decisión de Jürgen, card kjzs) solo pregunta si hay algo oculto: sin nada oculto, tocar es «Ver
//  solo X» directo. Para tener algo oculto sin el diálogo, Filtros → «Ocultar» → una cuenta.
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

    /// Deja algo oculto sin pasar por el diálogo: Filtros → «Ocultar» → la cuenta de ahorros del seed → Aplicar.
    /// Devuelve las cápsulas que quedan en la barra.
    @discardableResult
    private func hideSavingsAccountFromFilters(_ app: XCUIApplication) -> [String] {
        let filters = app.buttons["filters_toolbar_button"]
        XCTAssertTrue(filters.waitForHittable(timeout: 10), "Distribución no enseña el botón de Filtros.")
        filters.tap()
        let picker = app.segmentedControls["filters_include_exclude_picker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5), "No se montó el selector Mostrar solo / Ocultar.")
        picker.buttons.element(boundBy: 1).tap()
        let savings = app.buttons["Ahorros USD"].firstMatch
        XCTAssertTrue(savings.waitForHittable(timeout: 5), "Filtros no ofrece la cuenta «Ahorros USD» del seed.")
        savings.tap()
        let apply = app.buttons["filters_apply_button"]
        XCTAssertTrue(apply.waitForExistence(timeout: 5), "No apareció «Aplicar».")
        apply.tap()
        XCTAssertTrue(apply.waitForNonExistence(timeout: 5), "«Aplicar» no cerró Filtros.")
        XCTAssertTrue(appliedChips(app).firstMatch.waitForExistence(timeout: 10), "No apareció la cápsula de lo oculto.")
        return appliedChips(app).allElementsBoundByIndex.map(\.label)
    }

    /// Sin nada oculto, tocar una categoría la ve sola sin preguntar. Tocar otra vez lo que se ve solo lo quita: eso lo
    /// fijan `SegmentFilterChoiceLogicTests` y el source-scan del host, porque aquí, al ver solo una categoría, la lista
    /// pasa a sus subcategorías y la fila ya no está.
    func test_withNothingHidden_tapShowsOnlyWithoutAsking() {
        let app = launchOnDistribution()
        let rows = app.buttons.matching(identifier: "distribution_category_row")
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 20), "No apareció la lista de categorías de Distribución.")

        func onlyChip(for name: String) -> Bool {
            appliedChips(app).allElementsBoundByIndex.contains { $0.label.contains(name) && $0.label != name }
        }

        // «Sin categoría» no se puede filtrar: la primera fila que deja su cápsula «Solo …» es la que vale.
        for index in 0..<min(rows.count, 4) {
            let row = rows.element(boundBy: index)
            XCTAssertTrue(row.waitForHittable(timeout: 5), "La fila \(index) no es alcanzable.")
            let name = row.label.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces) ?? ""
            row.tap()
            XCTAssertFalse(app.buttons["segment_filter_cancel"].waitForExistence(timeout: 2),
                           "Sin nada oculto, tocar «\(name)» preguntó en vez de verla sola.")
            let deadline = Date().addingTimeInterval(3)
            while !onlyChip(for: name), Date() < deadline {
                RunLoop.current.run(until: Date().addingTimeInterval(0.2))
            }
            if !name.isEmpty, onlyChip(for: name) { return }
        }
        XCTFail("Ninguna de las primeras categorías dejó su cápsula «Solo …»: "
                + "\(appliedChips(app).allElementsBoundByIndex.map(\.label))")
    }

    /// Con algo oculto, tocar una categoría pregunta; «Cancelar» se ve y deja el filtro como estaba.
    func test_withSomethingHidden_tapAsks_andCancelLeavesTheFilterAsIs() {
        let app = launchOnDistribution()
        let before = hideSavingsAccountFromFilters(app)
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
        let after = appliedChips(app).allElementsBoundByIndex.map(\.label)
        XCTAssertEqual(after, before, "«Cancelar» cambió los filtros: \(before) → \(after)")
    }

    /// Con algo oculto, «Ocultar» una categoría y «Ver solo» otra: la barra enseña «Sin …» y «Solo …» a la vez.
    func test_hideOne_thenShowOnlyAnother_bothInTheBar() {
        let app = launchOnDistribution()
        let hiddenAccount = hideSavingsAccountFromFilters(app)

        tapFirstFilterableCategory(app)
        let hide = app.buttons["segment_filter_hide"]
        XCTAssertTrue(hide.waitForExistence(timeout: 5), "No preguntó.")
        let hiddenName = app.staticTexts["segment_filter_title"].label.components(separatedBy: " · ").first ?? ""
        hide.tap()
        XCTAssertTrue(hide.waitForNonExistence(timeout: 5), "«Ocultar» no cerró la pregunta.")

        var deadline = Date().addingTimeInterval(10)
        while appliedChips(app).count < hiddenAccount.count + 1, Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        let hiddenLabels = appliedChips(app).allElementsBoundByIndex.map(\.label)
        XCTAssertTrue(hiddenLabels.contains { $0.contains(hiddenName) && $0 != hiddenName },
                      "Ninguna cápsula dice «Sin \(hiddenName)»: \(hiddenLabels)")

        // La oculta ya no está en la lista: la primera fila es otra categoría.
        tapFirstFilterableCategory(app)
        let showOnly = app.buttons["segment_filter_show_only"]
        XCTAssertTrue(showOnly.waitForExistence(timeout: 5), "La segunda categoría no preguntó.")
        let shownName = app.staticTexts["segment_filter_title"].label.components(separatedBy: " · ").first ?? ""
        XCTAssertNotEqual(shownName, hiddenName, "La categoría oculta seguía en la lista.")
        showOnly.tap()
        XCTAssertTrue(showOnly.waitForNonExistence(timeout: 5), "«Ver solo» no cerró la pregunta.")

        deadline = Date().addingTimeInterval(10)
        while appliedChips(app).count < hiddenAccount.count + 2, Date() < deadline {
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
