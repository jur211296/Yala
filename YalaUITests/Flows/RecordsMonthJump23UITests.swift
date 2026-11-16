//
//  RecordsMonthJump23UITests.swift
//  YalaUITests
//
//  Revisión 2.3, decisión 17 (T1 + T2, 9-nov): en «Todo el tiempo», el separador de mes va fijo arriba y lleva a otro
//  mes; los días de un año que no es el actual llevan el año en la cabecera. Semilla `realista` (dos años): sin el
//  arreglo no hay separador que tocar ni cabecera con año, y el caso cae en la primera espera.
//

import XCTest

final class RecordsMonthJump23UITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
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

    func test_monthSeparator_jumpsToAMonthOfLastYear_andItsDaysCarryTheYear() {
        let app = XCUIApplication()
        app.launchForUITest(seed: "realista", deeplink: "records", extraArguments: ["-defaultPeriod", "allTime"])
        XCTAssertTrue(app.waitForUITestReady(timeout: 120), "uitest_ready ausente — bootstrap/seed no completó.")
        XCTAssertTrue(app.buttons.matching(identifier: "record_row").firstMatch.waitForExistence(timeout: 15),
                      "Registros no enseñó filas.")

        // «Todo el tiempo» con dos años de registros: el separador del mes de arriba está a la vista.
        let separators = app.descendants(matching: .any).matching(identifier: "records_month_separator")
        XCTAssertTrue(separators.firstMatch.waitForExistence(timeout: 10),
                      "En «Todo el tiempo» no hay separador de mes que lleve a otro mes.")
        attach("despues-1-separador")

        // El menú de meses: uno del año pasado.
        let lastYear = Calendar.current.component(.year, from: .now) - 1
        separators.firstMatch.tap()
        let target = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", " \(lastYear)")).firstMatch
        XCTAssertTrue(target.waitForExistence(timeout: 5), "El menú no ofrece ningún mes de \(lastYear).")
        attach("despues-2-menu")
        target.tap()

        // La lista aterriza en ese mes: el separador fijo es el suyo y sus días llevan el año.
        let landed = separators.matching(NSPredicate(format: "value BEGINSWITH %@", "\(lastYear)-"))
        XCTAssertTrue(waitUntil { landed.firstMatch.exists }, "La lista no saltó a un mes de \(lastYear).")
        let yearHeaders = app.descendants(matching: .any).matching(identifier: "records_day_header")
            .matching(NSPredicate(format: "label CONTAINS %@", "\(lastYear)"))
        XCTAssertTrue(yearHeaders.firstMatch.waitForExistence(timeout: 5),
                      "Los días de \(lastYear) no llevan el año en la cabecera.")
        attach("despues-3-mes-del-ano-pasado")

        // Y los del año en curso no lo llevan: volver al primer mes del menú.
        let thisYear = lastYear + 1
        landed.firstMatch.tap()
        let current = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", " \(thisYear)")).firstMatch
        XCTAssertTrue(current.waitForExistence(timeout: 5), "El menú no ofrece ningún mes de \(thisYear).")
        current.tap()
        let headers = app.descendants(matching: .any).matching(identifier: "records_day_header")
        XCTAssertTrue(waitUntil { headers.firstMatch.exists && !headers.firstMatch.label.contains("\(thisYear)") },
                      "Un día del año en curso lleva el año: \(headers.firstMatch.label)")
    }
}
