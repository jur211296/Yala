//
//  Revision23FlujoComparativaUITests.swift
//  YalaUITests
//
//  Revisión 2.3, Reportes y Flujo de caja (decisiones 32 y 33 del 9-nov). Un caso por punto; los dos dejan capturas
//  (`XCTAttachment`) que sirven de evidencia de antes y después.
//  - La Comparativa abre desglosada por categoría, dice el tramo exacto y no enseña «N/A».
//  - El armado del plan, sin ingresos (semilla `minimal`, una semana), pregunta «¿Cuánto recibes al mes?» y con «Aún no
//    lo sé» no dice «Te faltan al mes».
//

import XCTest

final class Revision23FlujoComparativaUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id]
    }

    private func attach(_ name: String, _ app: XCUIApplication) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    // MARK: - 1 · Comparativa (decisión 32)

    func test_comparative_opensByCategory_saysTheExactRange_andNoNA() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "realista")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        app.openReport("comparativa")

        // La semilla arranca en «Todo el tiempo»: la tarjeta lleva a «Este mes».
        let thisMonth = app.buttons["report_all_time_thisMonth"]
        if thisMonth.waitForExistence(timeout: 10) { thisMonth.tap() }
        let heading = element(app, "report_comparison_heading")
        XCTAssertTrue(heading.waitForExistence(timeout: 10), "No apareció la frase de qué se compara.")
        XCTAssertTrue(element(app, "pivot_header_row").waitForExistence(timeout: 10), "No se pintó la tabla.")
        attach("comparativa-este-mes", app)

        let categoryRows = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'pivot_row_categoria_'"))
        XCTAssertGreaterThan(categoryRows.count, 0, "La Comparativa no abrió desglosada por categoría.")
        XCTAssertFalse(app.staticTexts["N/A"].exists, "La tabla sigue diciendo «N/A».")

        // Con el mes a medias, la frase dice un tramo a cada lado: «1–11 de noviembre comparado con el 1–11 de
        // octubre». El día 1 y el último del mes no hay tramo que nombrar.
        let calendar = Calendar.current
        let today = Date()
        let day = calendar.component(.day, from: today)
        let daysInMonth = calendar.range(of: .day, in: .month, for: today)?.count ?? 31
        if day > 1 && day < daysInMonth {
            let dashes = heading.label.filter { $0 == "–" }.count
            XCTAssertGreaterThanOrEqual(dashes, 2, "La frase no dice el tramo del mes en curso: «\(heading.label)».")
        }
    }

    // MARK: - 2 · Primera semana sin ingresos (decisión 33)

    func test_cashFlowSetup_withoutIncome_asksForIt_andDoesNotSayShortfall() {
        let app = XCUIApplication()
        app.launchForUITest(pro: true, seed: "minimal")
        XCTAssertTrue(app.waitForUITestReady(), "uitest_ready ausente — bootstrap/seed no completó.")
        app.openReport("flujoDeCaja")
        XCTAssertTrue(element(app, "cashflow_setup_view").firstMatch.waitForExistence(timeout: 15),
                      "La vista de Flujo de caja no montó.")
        let skip = app.buttons["coach_mark_skip"]
        if skip.waitForExistence(timeout: 3) { skip.tap(); _ = skip.waitForNonExistence(timeout: 5) }
        attach("armado-primera-semana-arriba", app)

        let question = element(app, "cashflow_setup_income_question")
        var drags = 0
        while !question.exists, drags < 6 { app.swipeUp(); drags += 1 }
        attach("armado-primera-semana-pregunta", app)
        XCTAssertTrue(question.exists, "Sin ingresos, el armado no pregunta «¿Cuánto recibes al mes?».")
        XCTAssertFalse(app.buttons["primary_button"].exists, "«Crear mi plan» sale antes de contestar el ingreso.")

        let unknown = app.buttons["cashflow_setup_income_unknown"]
        XCTAssertTrue(unknown.waitForExistence(timeout: 5), "Falta «Aún no lo sé».")
        unknown.tap()

        let missing = element(app, "cashflow_setup_summary_income_missing")
        drags = 0
        while !missing.exists || !app.buttons["primary_button"].isHittable, drags < 8 { app.swipeUp(); drags += 1 }
        attach("armado-primera-semana-aun-no-lo-se", app)
        XCTAssertTrue(missing.exists, "Con «Aún no lo sé», el resumen no dice que falta el ingreso.")
        let summary = element(app, "cashflow_setup_summary")
        let shortfall = summary.descendants(matching: .staticText).matching(
            NSPredicate(format: "label BEGINSWITH 'Te faltan' OR label BEGINSWITH 'Short'"))
        XCTAssertEqual(shortfall.count, 0, "El resumen sigue anunciando que faltan.")
        XCTAssertTrue(app.buttons["primary_button"].exists, "Con «Aún no lo sé» no se puede crear el plan.")

        // Con la cifra escrita, el resumen sale completo.
        let amountButton = app.buttons["cashflow_setup_income_amount"]
        drags = 0
        while !amountButton.isHittable, drags < 8 { app.swipeDown(); drags += 1 }
        amountButton.tap()
        let field = app.textFields["cashflow_starting_balance_field"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "No se abrió la hoja para escribir el ingreso.")
        let typed = (field.value as? String) ?? ""
        field.tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: typed.count + 2))
        field.typeText("3000")
        app.buttons["cashflow_starting_balance_save"].tap()
        XCTAssertTrue(field.waitForNonExistence(timeout: 5))
        XCTAssertTrue(missing.waitForNonExistence(timeout: 5), "Con el ingreso escrito sigue diciendo que falta.")
        drags = 0
        while !app.buttons["primary_button"].isHittable, drags < 8 { app.swipeUp(); drags += 1 }
        attach("armado-primera-semana-con-ingreso", app)
    }
}
