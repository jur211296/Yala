//
//  RecordsListSearchUITests.swift
//  YalaUITests
//
//  Jürgen, 20-nov-2026: en Registros (y en Estadísticas › Registros) se quita «Buscar en Registros», la barra que asomaba
//  al tirar de la lista, porque la pestaña Buscar ya cumple esa función. Lo que la barra hacía y Buscar no —buscar por
//  importe— se llevó a Buscar. Aquí: tirar de la lista ya no saca ningún campo, y Buscar encuentra un registro por su
//  importe. Fixture `-uitest-seed-records-search`: un «Almuerzo de trabajo» de 45,90 de hoy, cuya nota no tiene cifras
//  (solo lo encuentra el importe).
//

import XCTest

final class RecordsListSearchUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func rows(_ app: XCUIApplication) -> XCUIElementQuery {
        app.buttons.matching(identifier: "record_row")
    }

    private func waitUntil(timeout: TimeInterval = 8, _ condition: @escaping () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        return condition()
    }

    func test_records_pullingDown_noLongerRevealsASearchField() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "minimal", deeplink: "records", extraArguments: ["-uitest-seed-records-search"])
        XCTAssertTrue(app.waitForUITestReady(timeout: 90), "uitest_ready ausente — bootstrap/seed no completó.")
        XCTAssertTrue(rows(app).firstMatch.waitForExistence(timeout: 10), "Registros no enseñó filas.")

        let list = app.scrollViews.containing(.button, identifier: "record_row").firstMatch
        list.swipeDown()
        XCTAssertFalse(app.textFields["records_list_search_field"].waitForExistence(timeout: 3),
                       "Tirar de la lista vuelve a sacar «Buscar en Registros»; esa función es de la pestaña Buscar.")
    }

    func test_searchTab_findsARecordByItsAmount() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "minimal", extraArguments: ["-uitest-seed-records-search"])
        XCTAssertTrue(app.waitForUITestReady(timeout: 90), "uitest_ready ausente — bootstrap/seed no completó.")

        app.selectTab(.search)
        XCTAssertTrue(rows(app).firstMatch.waitForExistence(timeout: 10), "Buscar no enseñó los recientes.")
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Buscar no tiene su campo.")
        field.tap()
        field.typeText("45,90")

        // Solo el almuerzo: su nota no lleva cifras, así que lo encuentra el importe.
        XCTAssertTrue(waitUntil { self.rows(app).count == 1 },
                      "Buscar «45,90» no dejó una sola fila (hay \(rows(app).count)).")
        XCTAssertTrue(rows(app).firstMatch.label.contains("Almuerzo de trabajo"),
                      "La fila que quedó no es la del importe buscado: \(rows(app).firstMatch.label)")
    }
}
