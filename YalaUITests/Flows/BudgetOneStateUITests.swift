//
//  BudgetOneStateUITests.swift
//  YalaUITests
//
//  Planificación: un estado, una palabra, un color (decisión 23 de la revisión 2.3, Jürgen 2026-11-09). Con la semilla
//  `-uitest-seed-budget-states` (cuatro presupuestos de S/ 1.000 al 30, 90, 100 y 118 %, exactos el día que sea):
//
//  - la lista dice una palabra por estado, y el de 100 % justo va en «Activos» con «Llegaste al límite», no en
//    «Excedidos» con «Te quedan S/ 0.00» y el ánimo de pasarse;
//  - al 90 %, con lo de hoy por encima del cupo del día, el detalle ya no dice «Hoy te pasaste»: la línea es una guía
//    neutra («… S/ 90.00 más que eso»);
//  - al 100 % justo el detalle no enseña cupo ni ánimo de pasarse.
//
//  Con el código de antes, los tres casos caen: la palabra de 100 % no existía, la fila iba a «Excedidos» y la línea del
//  cupo decía «Hoy te pasaste por». `YALA_CAPTURES` (vía `TEST_RUNNER_YALA_CAPTURES`) guarda las capturas.
//  Scheme Yala Dev.
//

import XCTest

final class BudgetOneStateUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func test_list_saysOneWordPerState_andExactly100StaysInActive() {
        let app = launch()

        let at30 = row(app, "QA 30")
        let at90 = row(app, "QA 90")
        let at100 = row(app, "QA 100")
        let at118 = row(app, "QA 118")

        XCTAssertFalse(at30.label.contains("En el límite") || at30.label.contains("Llegaste") || at30.label.contains("Te pasaste"),
                       "Al 30 % la fila no debería decir ningún estado: \(at30.label)")
        XCTAssertTrue(at90.label.contains("En el límite"), "Al 90 % la fila no dice «En el límite»: \(at90.label)")
        XCTAssertTrue(at100.label.contains("Llegaste al límite"), "Al 100 % la fila no dice «Llegaste al límite»: \(at100.label)")
        XCTAssertFalse(at100.label.contains("Te pasaste"), "Al 100 % justo la fila dice «Te pasaste»: \(at100.label)")
        XCTAssertTrue(at118.label.contains("Te pasaste"), "Al 118 % la fila no dice «Te pasaste»: \(at118.label)")

        // «Excedidos» arriba con el de 118 %; el de 100 % debajo del título de «Activos».
        let active = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Activos")).firstMatch
        XCTAssertTrue(active.exists, "No está el título de la sección «Activos».")
        XCTAssertGreaterThan(at100.frame.minY, active.frame.minY,
                             "El presupuesto al 100 % justo sigue en «Excedidos» (encima de «Activos»).")
        XCTAssertLessThan(at118.frame.minY, active.frame.minY, "El de 118 % no está en «Excedidos».")

        scrollToMiddle(app, at100)
        capture(app, "despues-1-lista")
    }

    func test_detailAt90_dailyLineIsANeutralGuide() {
        let app = launch()
        row(app, "QA 90").tap()
        XCTAssertTrue(app.descendants(matching: .any)["budget_detail"].waitForExistence(timeout: 10),
                      "No se abrió el detalle del presupuesto.")

        XCTAssertTrue(app.staticTexts["En el límite"].waitForExistence(timeout: 5), "El detalle al 90 % no dice «En el límite».")
        let line = app.descendants(matching: .any)["budget_daily_allowance"]
        XCTAssertTrue(line.waitForExistence(timeout: 5), "El detalle al 90 % no enseña el cupo del día.")
        capture(app, "despues-3-detalle-90")
        XCTAssertFalse(line.label.contains("te pasaste"), "La línea del cupo sigue riñendo: \(line.label)")

        // La semilla pone 800 el día 1 y 100 hoy; el día 1 los 900 son de hoy. Lo de hoy pasa del cupo (200 entre los días
        // que faltan) con tres días o más por delante; los dos últimos días del mes no lo pasa, y la frase no lo dice.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let now = Date()
        let day = calendar.component(.day, from: now)
        let daysInMonth = calendar.range(of: .day, in: .month, for: now)?.count ?? 30
        let daysLeft = daysInMonth - day + 1
        let (startOfDay, today) = day == 1 ? ("S/ 1,000.00", "S/ 900.00") : ("S/ 200.00", "S/ 100.00")
        XCTAssertTrue(line.label.contains(startOfDay), "La línea no dice lo que quedaba al empezar el día: \(line.label)")
        XCTAssertTrue(line.label.contains(today), "La línea no dice lo gastado hoy: \(line.label)")
        if daysLeft >= 3 {
            XCTAssertTrue(line.label.contains("más que eso"), "La línea no dice cuánto pasa del cupo de hoy: \(line.label)")
        }
    }

    func test_detailAt100_saysReachedLimit_withoutDailyLineOrWentOverNote() {
        let app = launch()
        row(app, "QA 100").tap()
        XCTAssertTrue(app.descendants(matching: .any)["budget_detail"].waitForExistence(timeout: 10),
                      "No se abrió el detalle del presupuesto.")

        XCTAssertTrue(app.staticTexts["Llegaste al límite"].waitForExistence(timeout: 5),
                      "El detalle al 100 % justo no dice «Llegaste al límite».")
        capture(app, "despues-4-detalle-100")
        XCTAssertFalse(app.descendants(matching: .any)["budget_daily_allowance"].exists,
                       "Con el mes agotado la línea del cupo no debería salir.")
        let wentOverNote = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Pasaste tu presupuesto")).firstMatch
        XCTAssertFalse(wentOverNote.exists, "Al 100 % justo sale el ánimo de haberse pasado.")
    }

    // MARK: - Helpers

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, deeplink: "budgets", budgetStates: true)
        XCTAssertTrue(app.waitForUITestReady(timeout: 90), "uitest_ready ausente — bootstrap/seed no completó.")
        XCTAssertTrue(app.buttons["budget_row_QA 90"].waitForExistence(timeout: 15), "No se sembraron los presupuestos de QA.")
        return app
    }

    /// La fila del presupuesto. La lista no es perezosa: todas las filas existen con su marco aunque no se vean.
    private func row(_ app: XCUIApplication, _ name: String) -> XCUIElement {
        let element = app.buttons["budget_row_\(name)"]
        XCTAssertTrue(element.waitForExistence(timeout: 10), "No está la fila de «\(name)».")
        scrollToMiddle(app, element)
        return element
    }

    /// Baja la lista hasta dejar el elemento en la franja central (para tocarlo o capturarlo).
    private func scrollToMiddle(_ app: XCUIApplication, _ element: XCUIElement) {
        let window = app.windows.firstMatch.frame
        for _ in 0..<12 {
            if element.frame.minY > window.minY + 160, element.frame.maxY < window.maxY - 160 { return }
            if element.frame.midY > window.midY { app.swipeUp(velocity: .slow) } else { app.swipeDown(velocity: .slow) }
        }
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
        guard let dir = ProcessInfo.processInfo.environment["YALA_CAPTURES"], !dir.isEmpty else { return }
        let url = URL(fileURLWithPath: dir).appendingPathComponent("\(name).png")
        do {
            try app.screenshot().pngRepresentation.write(to: url)
        } catch {
            #if DEBUG
            print("BudgetOneStateUITests: Error: \(error)")
            #endif
        }
    }
}
