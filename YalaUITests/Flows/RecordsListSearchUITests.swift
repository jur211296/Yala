//
//  RecordsListSearchUITests.swift
//  YalaUITests
//
//  «Buscar en Registros» (decisión 14 de la revisión 2.3, opción B1): en Registros, tirar de la lista hacia abajo hace
//  asomar el campo; escribir un importe deja solo el registro de ese importe; sin resultados sale el vacío de búsqueda, y
//  la X lo vacía y lo esconde. Fixture `-uitest-seed-records-search`: un «Almuerzo de trabajo» de 45,90 de hoy, cuya nota
//  no tiene cifras (solo lo encuentra el importe).
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

    /// Captura para la evidencia del PR (se exporta del `.xcresult`).
    private func attach(_ name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func waitUntil(timeout: TimeInterval = 8, _ condition: @escaping () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        return condition()
    }

    func test_pullingDown_revealsTheField_andAnAmountFindsItsRecord() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "minimal", deeplink: "records", extraArguments: ["-uitest-seed-records-search"])
        XCTAssertTrue(app.waitForUITestReady(timeout: 90), "uitest_ready ausente — bootstrap/seed no completó.")
        XCTAssertTrue(rows(app).firstMatch.waitForExistence(timeout: 10), "Registros no enseñó filas.")
        let before = rows(app).count
        XCTAssertGreaterThan(before, 1, "La semilla tiene que dejar más de un registro para que buscar reduzca algo.")

        // En reposo el campo no está: asoma al tirar de la lista hacia abajo.
        let field = app.textFields["records_list_search_field"]
        XCTAssertFalse(field.exists, "El campo salió sin tirar de la lista.")
        let list = app.scrollViews.containing(.button, identifier: "record_row").firstMatch
        list.swipeDown()
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Tirar de la lista hacia abajo no hizo asomar «Buscar en Registros».")
        attach("despues-1-campo")

        // El importe, con coma: solo el almuerzo de 45,90 (su nota no tiene cifras).
        field.tap()
        field.typeText("45,90")
        XCTAssertTrue(waitUntil { self.rows(app).count == 1 },
                      "Buscar «45,90» no dejó una sola fila (hay \(rows(app).count)).")
        XCTAssertTrue(rows(app).firstMatch.label.contains("Almuerzo de trabajo"),
                      "La fila que quedó no es la del importe buscado: \(rows(app).firstMatch.label)")
        attach("despues-2-importe")

        // Sin resultados: el vacío de búsqueda, no «Sin registros».
        field.typeText("123")
        XCTAssertTrue(app.descendants(matching: .any)["records_list_search_empty"].waitForExistence(timeout: 5),
                      "Sin resultados no salió el vacío de búsqueda.")
        attach("despues-3-sin-resultados")

        // La X vacía el campo, lo esconde y la lista vuelve entera.
        app.buttons["records_list_search_clear"].tap()
        XCTAssertTrue(waitUntil { !field.exists }, "La X no escondió el campo.")
        XCTAssertTrue(waitUntil { self.rows(app).count > 1 }, "La lista no volvió entera tras borrar la búsqueda.")
    }
}
