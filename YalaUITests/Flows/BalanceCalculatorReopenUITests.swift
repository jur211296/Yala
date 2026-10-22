//
//  BalanceCalculatorReopenUITests.swift
//  YalaUITests
//
//  Ticket `reopened-balance-calculator-reads-a-grouped-amount-as-zero`: en el paso del saldo del onboarding, reabrir
//  la calculadora con un saldo de 1.000 o más enseñaba 0 y «Usar este saldo» dejaba la cuenta en 0. Este caso recorre
//  el camino entero: saldo a mano de 1.800, «Calcúlalo conmigo», «Editar», y la calculadora tiene que decir 1.800.
//  Con el prefijado de antes («1,800.00») el resultado sale en 0.
//  Convenciones: ver CLAUDE.md (sin sleeps, scheme Yala Dev).
//

import XCTest

final class BalanceCalculatorReopenUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func tapNext(_ app: XCUIApplication, _ paso: String) {
        let next = app.buttons["onboarding_next_button"]
        XCTAssertTrue(next.waitForExistence(timeout: 10), "No hay «Siguiente» en el paso \(paso).")
        let enabled = expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: next)
        wait(for: [enabled], timeout: 10)
        next.tap()
    }

    private func amountShows1800(_ label: String) -> Bool {
        label.contains("1,800") || label.contains("1.800") || label.contains("1800")
    }

    func test_reopeningTheCalculator_keepsAThousandsBalance() {
        let app = XCUIApplication()
        app.launchForUITest(skipOnboarding: false, seed: nil, onboarding: true)

        // Paso 1: nombre.
        let nameField = app.textFields["onboarding_name_field"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 30), "El onboarding no montó.")
        nameField.tap()
        nameField.typeText("QA")
        tapNext(app, "nombre")

        // Paso 2: propósito.
        let control = app.buttons["onboarding_purpose_control"]
        XCTAssertTrue(control.waitForExistence(timeout: 10), "No salió el paso del propósito.")
        control.tap()
        tapNext(app, "propósito")

        // Paso 3: «Todo junto» (la calculadora de «Todo junto» es la que enseña el resultado con su id).
        let single = app.buttons["onboarding_accounts_single"]
        XCTAssertTrue(single.waitForExistence(timeout: 10), "No salió el paso del tipo de cuenta.")
        single.tap()
        tapNext(app, "tipo de cuenta")

        // Paso 4: divisa y nombre (vienen puestos).
        XCTAssertTrue(app.descendants(matching: .any)["onboarding_currency_selector"].waitForExistence(timeout: 10),
                      "No salió el paso de divisa y nombre.")
        tapNext(app, "divisa")

        // Paso 5: saldo a mano, 1.800.
        let manual = app.buttons["onboarding_balance_manual"]
        XCTAssertTrue(manual.waitForExistence(timeout: 10), "No salió el paso del saldo.")
        manual.tap()
        let field = app.textFields["onboarding_balance"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "No salió el campo del saldo.")
        field.tap()
        field.typeText("1800")

        // «Calcúlalo conmigo» con un saldo ya escrito enseña la vista previa con «Editar», que reabre la calculadora.
        let guided = app.buttons["onboarding_balance_guided"]
        XCTAssertTrue(guided.waitForExistence(timeout: 5))
        guided.tap()
        let edit = app.buttons["onboarding_balance_edit"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5), "No salió «Editar» bajo «Calcúlalo conmigo».")
        edit.tap()

        let result = app.descendants(matching: .any)["balance_calculator_result"].firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 10), "La calculadora no se abrió.")
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "calculadora-reabierta"
        shot.lifetime = .keepAlways
        add(shot)
        XCTAssertTrue(amountShows1800(result.label),
                      "La calculadora reabierta dice «\(result.label)»: con el bug, 0.")

        // «Usar este saldo» conserva los 1.800.
        let use = app.buttons.matching(NSPredicate(format: "label IN %@", ["Usar este saldo", "Use this balance"])).firstMatch
        XCTAssertTrue(use.waitForExistence(timeout: 5), "No salió «Usar este saldo».")
        use.tap()
        XCTAssertTrue(edit.waitForExistence(timeout: 5), "La calculadora no se cerró tras «Usar este saldo».")
        let preview = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS '1,800' OR label CONTAINS '1.800'")).firstMatch
        let kept = preview.waitForExistence(timeout: 5)
        let previewShot = XCTAttachment(screenshot: app.screenshot())
        previewShot.name = "saldo-tras-usar-este-saldo"
        previewShot.lifetime = .keepAlways
        add(previewShot)
        XCTAssertTrue(kept, "Tras «Usar este saldo» la cuenta no se quedó con 1.800.")
    }
}
