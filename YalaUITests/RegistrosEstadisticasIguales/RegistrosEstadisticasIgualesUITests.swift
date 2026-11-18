//
//  RegistrosEstadisticasIgualesUITests.swift
//  YalaUITests
//
//  Decisión de Jürgen del 17-nov: Estadísticas › Registros es idéntica a la pestaña Registros. Cae con el código de
//  antes: allí no estaban los chips rápidos (Cuenta · Categoría · Más filtros, con Lista/Calendario en su fila) ni
//  «Buscar en Registros» al tirar de la lista. Fixture `-uitest-seed-records-search`: un «Almuerzo de trabajo» de 45,90
//  de hoy, cuya nota no tiene cifras (solo lo encuentra el importe). Seed `minimal`, scheme Yala Dev.
//

import XCTest

final class RegistrosEstadisticasIgualesUITests: XCTestCase {
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

    private func openStatsRecords(_ app: XCUIApplication) {
        app.selectTab(.statistics)
        let chip = app.buttons["detail_chip_registros"].firstMatch
        XCTAssertTrue(chip.waitForExistence(timeout: 10), "No hay chip Registros en Estadísticas.")
        if !chip.isHittable {
            let chipsBar = app.scrollViews.containing(.button, identifier: "detail_chip_insights").firstMatch
            if chipsBar.exists { chipsBar.swipeLeft() }
        }
        chip.tap()
        XCTAssertTrue(app.descendants(matching: .any)["stats_tab_records"].waitForExistence(timeout: 10),
                      "El chip Registros no montó su página.")
    }

    func test_statsRecords_hasTheQuickFilters_andTheSearchFindsByAmount() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "minimal", deeplink: "statistics", extraArguments: ["-uitest-seed-records-search"])
        XCTAssertTrue(app.waitForUITestReady(timeout: 90), "uitest_ready ausente — bootstrap/seed no completó.")
        openStatsRecords(app)
        XCTAssertTrue(rows(app).firstMatch.waitForExistence(timeout: 15), "Estadísticas › Registros no enseñó filas.")

        // Los chips rápidos de Registros, con Lista/Calendario en su fila.
        for id in ["records_quick_account", "records_quick_more", "records_view_mode_calendar"] {
            XCTAssertTrue(app.descendants(matching: .any)[id].firstMatch.waitForExistence(timeout: 5),
                          "Estadísticas › Registros no tiene «\(id)», que sí tiene la pestaña Registros.")
        }

        // «Buscar en Registros»: asoma al tirar y el importe deja solo su registro.
        let field = app.textFields["records_list_search_field"]
        XCTAssertFalse(field.exists, "El campo salió sin tirar de la lista.")
        let list = app.scrollViews.containing(.button, identifier: "record_row").firstMatch
        list.swipeDown()
        XCTAssertTrue(field.waitForExistence(timeout: 5),
                      "Tirar de la lista de Estadísticas › Registros no hizo asomar «Buscar en Registros».")
        field.tap()
        field.typeText("45,90")
        XCTAssertTrue(waitUntil { self.rows(app).count == 1 },
                      "Buscar «45,90» en Estadísticas no dejó una sola fila (hay \(rows(app).count)).")
        XCTAssertTrue(rows(app).firstMatch.label.contains("Almuerzo de trabajo"),
                      "La fila que quedó no es la del importe buscado: \(rows(app).firstMatch.label)")

        // La X lo vacía y la lista vuelve entera.
        app.buttons["records_list_search_clear"].tap()
        XCTAssertTrue(waitUntil { self.rows(app).count > 1 }, "La lista no volvió entera tras borrar la búsqueda.")
    }
}
