//
//  StatisticsCategoryDetailUITests.swift
//  YalaUITests
//
//  Decisión 25 de la revisión 2.3 (B1, 9-nov): en Distribución, tocar una categoría abre su detalle (lo gastado y su
//  comparación, subcategorías, últimos registros y «Ver en Registros») y «atrás» vuelve sin tocar ningún filtro. Hasta
//  ese día el toque ponía «Solo X» en toda la app y no había «atrás». Entra por enlace a Distribución (modo Detalle, la
//  lista de categorías). Seed `realista`.
//

import XCTest

final class StatisticsCategoryDetailUITests: XCTestCase {
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

    private func appliedChips(_ app: XCUIApplication) -> XCUIElementQuery {
        app.buttons.matching(identifier: "applied_filter_chip")
    }

    private func detail(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)["stats_category_detail"]
    }

    private func attachScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Toca la primera categoría que se pueda abrir y devuelve su nombre. «Sin categoría» no abre nada: si está arriba,
    /// se pasa a la siguiente. La captura «tras-tocar» se toma antes de afirmar nada (con el código de antes enseña el
    /// filtro puesto).
    private func openFirstCategory(_ app: XCUIApplication) -> String {
        let rows = app.buttons.matching(identifier: "distribution_category_row")
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 20), "No apareció la lista de categorías de Distribución.")
        attachScreenshot("distribucion-antes-de-tocar")
        for index in 0..<min(rows.count, 3) {
            let row = rows.element(boundBy: index)
            guard row.exists else { break }
            XCTAssertTrue(row.waitForHittable(timeout: 5), "La fila \(index) no es alcanzable.")
            let name = row.label.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces) ?? ""
            row.tap()
            let opened = detail(app).waitForExistence(timeout: 6)
            attachScreenshot("tras-tocar-\(index)")
            if opened { return name }
            // Con el código de antes el toque filtra y la lista pasa a subcategorías: no hay más filas que probar.
            guard appliedChips(app).count == 0 else { break }
        }
        XCTFail("Tocar una categoría no abrió su detalle. Cápsulas: \(appliedChips(app).allElementsBoundByIndex.map(\.label))")
        return ""
    }

    /// Tocar abre el detalle sin poner filtros; «atrás» vuelve a la lista de categorías, también sin filtros.
    func test_tapCategory_opensItsDetail_andBackLeavesNoFilter() {
        let app = launchOnDistribution()
        let chipsBefore = appliedChips(app).count
        let name = openFirstCategory(app)

        XCTAssertEqual(appliedChips(app).count, chipsBefore, "Abrir el detalle de «\(name)» puso filtros.")
        XCTAssertTrue(app.staticTexts[name].firstMatch.exists, "El detalle no dice qué categoría es (\(name)).")
        XCTAssertTrue(app.buttons["stats_category_detail_see_in_records"].waitForExistence(timeout: 5),
                      "El detalle no ofrece «Ver en Registros».")

        let back = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(back.waitForHittable(timeout: 5), "El detalle no tiene «atrás».")
        back.tap()
        XCTAssertTrue(detail(app).waitForNonExistence(timeout: 5), "«Atrás» no cerró el detalle.")
        XCTAssertTrue(app.buttons.matching(identifier: "distribution_category_row").firstMatch.waitForExistence(timeout: 10),
                      "Al volver, Distribución no enseña la lista de categorías.")
        XCTAssertEqual(appliedChips(app).count, chipsBefore,
                       "Al volver quedaron filtros: \(appliedChips(app).allElementsBoundByIndex.map(\.label))")
        attachScreenshot("vuelta-a-distribucion")
    }

    /// «Ver en Registros» es el único gesto del detalle que filtra: pasa a Registros con «Solo <categoría>».
    func test_seeInRecords_opensRecordsWithOnlyThatCategory() {
        let app = launchOnDistribution()
        let name = openFirstCategory(app)

        let seeInRecords = app.buttons["stats_category_detail_see_in_records"]
        XCTAssertTrue(seeInRecords.waitForHittable(timeout: 5), "El detalle no ofrece «Ver en Registros».")
        seeInRecords.tap()

        XCTAssertTrue(detail(app).waitForNonExistence(timeout: 5), "«Ver en Registros» no salió del detalle.")
        XCTAssertTrue(app.descendants(matching: .any)["stats_tab_records"].waitForExistence(timeout: 10),
                      "«Ver en Registros» no llevó al chip Registros.")
        let deadline = Date().addingTimeInterval(5)
        func onlyChip() -> Bool {
            appliedChips(app).allElementsBoundByIndex.contains { $0.label.contains(name) && $0.label != name }
        }
        while !onlyChip(), Date() < deadline { RunLoop.current.run(until: Date().addingTimeInterval(0.2)) }
        XCTAssertTrue(onlyChip(), "Registros no enseña «Solo \(name)»: \(appliedChips(app).allElementsBoundByIndex.map(\.label))")
        attachScreenshot("ver-en-registros")
    }
}
